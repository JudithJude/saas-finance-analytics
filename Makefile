# Run everything from your laptop without Airflow:
#   make setup up all
# Then open Metabase on http://localhost:3000.

# Talk to the local warehouse container from your laptop (port 5433).
export WAREHOUSE_HOST ?= localhost
export WAREHOUSE_PORT ?= 5433
export WAREHOUSE_DB ?= warehouse
export WAREHOUSE_USER ?= postgres
export WAREHOUSE_PASSWORD ?= postgres
export USE_FAKE_API ?= true

PY := .venv/bin/python
DBT := cd dbt && ../.venv/bin/dbt
DBT_FLAGS := --profiles-dir .

.PHONY: setup up down data extract erase build test freshness lint docs all airflow clean

setup:            ## Create the virtualenv and install dbt, sqlfluff and pytest
	python3 -m venv .venv
	.venv/bin/pip install -r requirements-dev.txt

up:               ## Start the warehouse (Postgres) and Metabase
	docker compose -f docker-compose.override.yml up -d --wait

down:             ## Stop them
	docker compose -f docker-compose.override.yml down

data:             ## Make fresh fake API data
	$(PY) -m include.generate_fake_data

extract:          ## Load every source into the raw schema (incremental)
	$(PY) -m include.run_extract

erase:            ## Strip personal fields from raw for customers on the erasure list
	$(PY) -m include.privacy.erase_raw

build:            ## dbt seed, run, snapshot and test, in dependency order
	$(DBT) build $(DBT_FLAGS)

freshness:        ## Check each source was loaded recently
	$(DBT) source freshness $(DBT_FLAGS)

lint:             ## Lint the SQL
	.venv/bin/sqlfluff lint dbt/models dbt/tests

docs:             ## Browse the dbt docs and lineage graph on http://localhost:8080
	$(DBT) docs generate $(DBT_FLAGS) && $(DBT) docs serve $(DBT_FLAGS)

all: data extract erase build   ## The whole pipeline, end to end

airflow:          ## Run the real thing: Airflow + warehouse + Metabase (needs the Astro CLI)
	astro dev start

test:             ## DAG integrity tests, inside the Astro image
	astro dev pytest tests/dags

clean:
	rm -rf dbt/target dbt/logs .venv
