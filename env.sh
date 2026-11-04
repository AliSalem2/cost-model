# Load this in every new terminal (bash or zsh):  source env.sh
if [ -n "${BASH_SOURCE[0]:-}" ]; then
  _ENV_FILE="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION:-}" ]; then
  eval '_ENV_FILE="${(%):-%x}"'
else
  _ENV_FILE="./env.sh"
fi
PROJECT_DIR="$(cd "$(dirname "${_ENV_FILE}")" && pwd)"
unset _ENV_FILE

export AIRFLOW_HOME="${PROJECT_DIR}/airflow"
export AIRFLOW__CORE__DAGS_FOLDER="${PROJECT_DIR}/airflow/dags"
export AIRFLOW__CORE__LOAD_EXAMPLES=False

# The DAG calls dbt from its own environment, so the two never share dependencies.
export DBT_PROJECT_DIR="${PROJECT_DIR}/dbt/cost_model"
export DBT_BIN="${PROJECT_DIR}/.venv-dbt/bin/dbt"

source "${PROJECT_DIR}/.venv-airflow/bin/activate"
echo "Airflow env loaded (AIRFLOW_HOME=${AIRFLOW_HOME})"
