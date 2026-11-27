# Astro Runtime = Airflow 3.1 packaged by Astronomer.
# Check https://www.astronomer.io/docs/runtime/runtime-release-notes for the latest 3.1 tag.
FROM astrocrpublic.azurecr.io/runtime:3.1-8

# dbt gets its own virtualenv so its packages never clash with Airflow's.
# dags/dbt_finance.py points Cosmos at this dbt executable.
RUN python -m venv dbt_venv && \
    dbt_venv/bin/pip install --no-cache-dir dbt-core==1.12.7 dbt-postgres==1.11.0
