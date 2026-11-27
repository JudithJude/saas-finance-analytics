"""One extract-and-load DAG per source: extract_stripe, extract_hubspot, extract_app_db, extract_heap.

Each DAG runs hourly, loads only records changed since the last run, and then
marks its raw tables as updated (an Airflow Asset). dbt_finance waits for those.
"""

from __future__ import annotations

from datetime import datetime, timedelta

from airflow.sdk import Asset, dag, task

from include.alerts import notify_failure
from include.extract.sources import SOURCES

DEFAULT_ARGS = {
    "owner": "data",
    "retries": 3,
    "retry_delay": timedelta(minutes=5),
    "on_failure_callback": notify_failure,
}


def raw_asset(source: str) -> Asset:
    return Asset(f"postgres://warehouse/raw/{source}")


def make_extract_dag(source: str):
    @dag(
        dag_id=f"extract_{source}",
        schedule="@hourly",
        start_date=datetime(2026, 1, 1),
        catchup=False,
        max_active_runs=1,
        default_args=DEFAULT_ARGS,
        tags=["extract", source],
        doc_md=f"Extract {source} incrementally and load it untouched into the `raw` schema.",
    )
    def extract():
        @task(outlets=[raw_asset(source)])
        def extract_and_load() -> dict[str, int]:
            from include.extract.load import run

            return run(source)

        extract_and_load()

    return extract()


for _source in SOURCES:
    globals()[f"extract_{_source}"] = make_extract_dag(_source)
