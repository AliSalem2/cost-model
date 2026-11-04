#!/usr/bin/env bash
# Step 1 setup: Airflow and dbt (DuckDB) in two separate virtual environments.
# Run from the project root:  bash setup.sh
set -euo pipefail

AIRFLOW_VERSION="3.3.2"
DBT_DUCKDB_VERSION="1.11.0"

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

PY_VERSION="$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
echo "Using Python ${PY_VERSION}"

# Airflow pins its dependencies through a constraints file per Python version.
CONSTRAINTS_URL="https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-${PY_VERSION}.txt"

echo "1/3  Creating Airflow environment (.venv-airflow)"
python3 -m venv .venv-airflow
.venv-airflow/bin/pip install -q --upgrade pip
.venv-airflow/bin/pip install -q "apache-airflow==${AIRFLOW_VERSION}" --constraint "${CONSTRAINTS_URL}"

echo "2/3  Creating dbt environment (.venv-dbt)"
python3 -m venv .venv-dbt
.venv-dbt/bin/pip install -q --upgrade pip
.venv-dbt/bin/pip install -q "dbt-duckdb==${DBT_DUCKDB_VERSION}"

echo "3/3  Checking dbt connection"
(cd dbt/cost_model && ../../.venv-dbt/bin/dbt debug --profiles-dir . --quiet && echo "dbt connection OK")

echo "Creating the Airflow pool that serialises DuckDB writes"
export AIRFLOW_HOME="${PROJECT_DIR}/airflow"
.venv-airflow/bin/airflow db migrate >/dev/null
.venv-airflow/bin/airflow pools set duckdb_schreiber 1 "DuckDB allows one writer at a time" >/dev/null

echo
echo "Done. Next:  source env.sh  then  airflow standalone"
