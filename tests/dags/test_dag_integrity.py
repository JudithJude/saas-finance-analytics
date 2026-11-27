"""Checks every DAG loads before anything is deployed.

Run: pytest tests/dags
"""

from pathlib import Path

import pytest
from airflow.models import DagBag

DAGS_DIR = Path(__file__).resolve().parents[2] / "dags"
EXPECTED = {"extract_stripe", "extract_hubspot", "extract_app_db", "extract_heap", "dbt_finance"}


@pytest.fixture(scope="session")
def dagbag() -> DagBag:
    return DagBag(dag_folder=str(DAGS_DIR), include_examples=False)


def test_no_import_errors(dagbag):
    assert dagbag.import_errors == {}, f"DAG import errors: {dagbag.import_errors}"


def test_expected_dags_exist(dagbag):
    assert EXPECTED <= set(dagbag.dag_ids)


@pytest.mark.parametrize("dag_id", sorted(EXPECTED))
def test_every_dag_has_retries_and_alerts(dagbag, dag_id):
    dag = dagbag.get_dag(dag_id)
    for t in dag.tasks:
        assert t.retries >= 1, f"{dag_id}.{t.task_id} has no retries"
        assert t.on_failure_callback, f"{dag_id}.{t.task_id} has no failure alert"


def test_dbt_dag_has_a_task_per_model(dagbag):
    task_ids = " ".join(dagbag.get_dag("dbt_finance").task_ids)
    for model in ["stg_stripe__invoices", "int_invoice_months", "fct_mrr", "rpt_mrr_monthly"]:
        assert model in task_ids, f"{model} is missing from dbt_finance"
