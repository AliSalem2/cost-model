"""Cost model pipeline: ingest new levies, load reference data, build models, test them.

Each run calculates costs for the Berlin calendar day of its logical date, so a backfill
fills past dates. Backfill dates are read as UTC while runs start at midnight in Berlin
(22:00 or 23:00 UTC the day before), so --from-date is the day before the first wanted date.
This fills all of 2025:

    airflow backfill create --dag-id cost_model --from-date 2024-12-31 --to-date 2025-12-31

The 2027 scenario table is rebuilt by dbt_run on every run and does not depend on the date.
"""

import os
import sys
from pathlib import Path

import pendulum
from airflow.providers.standard.operators.bash import BashOperator
from airflow.sdk import DAG

PROJECT_ROOT = Path(__file__).resolve().parents[2]
DBT_PROJECT_DIR = os.environ.get("DBT_PROJECT_DIR", str(PROJECT_ROOT / "dbt" / "cost_model"))
DBT_BIN = os.environ.get("DBT_BIN", str(PROJECT_ROOT / ".venv-dbt" / "bin" / "dbt"))
TIMEZONE = "Europe/Berlin"

# Every dbt call runs inside the dbt project with the project's own profiles.yml.
DBT = f"cd {DBT_PROJECT_DIR} && {DBT_BIN}"
DBT_FLAGS = "--profiles-dir ."

# Airflow pool with one slot, created by setup.sh. DuckDB allows one writer at a time, and
# max_active_runs does not stop a backfill and a scheduled run from overlapping.
DUCKDB_POOL = "duckdb_schreiber"


def stichtag(dag_run):
    """Berlin calendar day of a run.

    Not {{ ds }}: that is the UTC date, and midnight in Berlin is still the previous day in UTC.
    Runs triggered by hand have no logical date, so they use the time they were requested to run.
    """
    zeitpunkt = dag_run.logical_date or dag_run.run_after
    return pendulum.instance(zeitpunkt).in_timezone(TIMEZONE).to_date_string()


DBT_VARS = "--vars '{stichtag: {{ stichtag(dag_run) }}}'"

with DAG(
    dag_id="cost_model",
    description="Direct cost components (levies, grid fees) into tested dbt models",
    # The cost data starts here, and a backfill cannot go further back than start_date.
    start_date=pendulum.datetime(2025, 1, 1, tz=TIMEZONE),
    schedule="@daily",
    catchup=False,
    max_active_runs=1,
    user_defined_macros={"stichtag": stichtag},
    tags=["cost-model", "dbt"],
) as dag:
    ingest_umlagen = BashOperator(
        task_id="ingest_umlagen",
        bash_command=f"{sys.executable} {PROJECT_ROOT / 'scripts' / 'ingest_umlagen.py'}",
    )

    dbt_seed = BashOperator(
        task_id="dbt_seed",
        bash_command=f"{DBT} seed {DBT_FLAGS}",
        pool=DUCKDB_POOL,
    )

    dbt_run = BashOperator(
        task_id="dbt_run",
        bash_command=f"{DBT} run {DBT_FLAGS} {DBT_VARS}",
        pool=DUCKDB_POOL,
    )

    dbt_test = BashOperator(
        task_id="dbt_test",
        bash_command=f"{DBT} test {DBT_FLAGS} {DBT_VARS}",
        pool=DUCKDB_POOL,
    )

    ingest_umlagen >> dbt_seed >> dbt_run >> dbt_test
