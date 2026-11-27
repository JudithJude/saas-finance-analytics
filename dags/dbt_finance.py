"""Run the dbt project once fresh data has landed.

Cosmos turns every dbt model, seed, snapshot and test into its own Airflow task,
so a failure shows exactly which model broke. The DAG is scheduled on the raw
assets, so it starts only after every extract DAG has updated its tables.
"""

from __future__ import annotations

import os
from datetime import datetime, timedelta
from pathlib import Path

from cosmos import DbtDag, ExecutionConfig, ProfileConfig, ProjectConfig, RenderConfig
from cosmos.constants import TestBehavior

from include.alerts import notify_failure
from include.extract.sources import SOURCES

try:  # Airflow 3
    from airflow.sdk import Asset
except ImportError:  # pragma: no cover - Airflow 2 fallback
    from airflow.datasets import Dataset as Asset

DBT_PROJECT = Path(__file__).resolve().parent.parent / "dbt"
# On Astro, dbt is installed in its own virtualenv (see Dockerfile) so its
# dependencies never clash with Airflow's.
DBT_EXECUTABLE = os.getenv("DBT_EXECUTABLE", f"{os.getenv('AIRFLOW_HOME', '/usr/local/airflow')}/dbt_venv/bin/dbt")

profile_config = ProfileConfig(
    profile_name="saas_finance",
    target_name=os.getenv("DBT_TARGET", "prod"),
    profiles_yml_filepath=DBT_PROJECT / "profiles.yml",
)

dbt_finance = DbtDag(
    dag_id="dbt_finance",
    project_config=ProjectConfig(DBT_PROJECT),
    profile_config=profile_config,
    execution_config=ExecutionConfig(dbt_executable_path=DBT_EXECUTABLE),
    # Run each model's tests right after it builds, so a bad model stops
    # everything downstream before finance sees a wrong number.
    # Tests that read several models (like the MRR-to-invoices reconciliation) get
    # their own task that waits for all of those models, not just the first.
    render_config=RenderConfig(
        test_behavior=TestBehavior.AFTER_EACH,
        should_detach_multiple_parents_tests=True,
    ),
    schedule=[Asset(f"postgres://warehouse/raw/{source}") for source in SOURCES],
    start_date=datetime(2026, 1, 1),
    catchup=False,
    max_active_runs=1,
    default_args={"retries": 1, "retry_delay": timedelta(minutes=5), "on_failure_callback": notify_failure},
    tags=["dbt", "finance"],
)
