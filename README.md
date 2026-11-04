# Energy cost model (practice project)

A small pipeline that turns German electricity cost components (Umlagen, Netzentgelte, Konzessionsabgabe, Stromsteuer) into tested dbt models, orchestrated by Airflow. Built to practise the Analytics Engineer – Cost Modelling stack: dbt, Airflow, effective-dated data.

**Stack:** Airflow 3.3, dbt Core 1.x with DuckDB, Python 3.10–3.13. Runs fully local, no cloud account. All table and column names are German (umlauts as ae/oe/ue).

## Run it

```bash
bash setup.sh          # first time only: both environments + dbt connection check
source env.sh          # in every new terminal (bash or zsh)
airflow standalone     # UI on http://localhost:8080
```

Without the UI: `airflow dags test cost_model 2026-10-25`. Only dbt: `cd dbt/cost_model && ../../.venv-dbt/bin/dbt build --profiles-dir .`

## Data model (Step 2)

| Seed / staging model | Content | Source |
| --- | --- | --- |
| `umlagen` | KWKG-Umlage, Offshore-Netzumlage, Aufschlag fuer besondere Netznutzung, 2025–2026, ct/kWh | netztransparenz.de (real values) |
| `netzbetreiber` | 5 distribution network operators | master data |
| `netzentgelte` | Grundpreis (EUR/year) and Arbeitspreis (ct/kWh) per operator, 2025–2026 final, 2027 `vorlaeufig` | **illustrative values** |
| `konzessionsabgabe` | Rate by municipality size, open-ended validity | KAV § 2 (real values) |
| `stromsteuer` | Regelsatz 2.05 ct/kWh, open-ended | StromStG § 3 |
| `kunden` | 8 fictional household customers with postcode, operator, annual consumption | fictional |

Every component carries `gueltig_ab` / `gueltig_bis`. An empty end date means "valid until further notice" and is resolved to the project variable `offenes_ende` (9999-12-31) in staging.

## Tests worth talking about

- **`keine_ueberlappenden_zeitraeume`** (generic, `tests/generic/`): a cost component can have only one value per key on any day. Reused for levies, grid fees, tax, and even for population bands of the Konzessionsabgabe.
- **`zeitraum_gueltig`**: a period must start before it ends.
- **`relationships`**: every customer and every grid fee points to a known network operator.
- **Postcode as text**: `plz` is forced to `varchar` in `dbt_project.yml`, otherwise Dresden's 01067 silently becomes 1067.

## Mart (Step 3)

`mart_direkte_kosten_kunde` has one row per customer whose contract has started by the `stichtag`: every cost component in ct/kWh, plus total cost per year and per kWh. Yearly values apply the rates valid on that date to the annual consumption. Costs are net and exclude energy procurement.

```bash
cd dbt/cost_model && ../../.venv-dbt/bin/dbt run --profiles-dir . --select mart_direkte_kosten_kunde --vars '{stichtag: 2026-06-15}'
```

Without `stichtag`, the model uses today's date. The table holds the latest run only.

**History:** each run also writes its date to `dbt/cost_model/historie/stichtag=YYYY-MM-DD/` as Parquet, and re-running a date replaces its file. `mart_direkte_kosten_kunde_historie` reads all dates. Query that view from `dbt/cost_model`, because the path is relative. The files are local and not in git; they can be rebuilt from the seeds.

**2027 Umlagen are an assumption:** `int_umlagen` uses the plain average of each levy's earlier values, and the mart marks those rows with `ist_annahme`. Adding a real 2027 value to `seeds/umlagen.csv` replaces the assumption for that levy.

**Missing components:** if a component has no value for the date, the totals stay `NULL` and `ist_vollstaendig` is false, so a partial sum can't pass as a real cost.

**Unit tests** (`models/marts/_marts.yml`, `models/intermediate/_intermediate.yml`) cover a hand-calculated total, both sides of a rate change, customers before contract start, missing components, and the 2027 assumption.

## Pipeline (Step 4)

The `cost_model` DAG runs `ingest_umlagen >> dbt_seed >> dbt_run >> dbt_test` once a day, for the Berlin calendar day of the run.

**Ingestion:** put a file with the same columns as `seeds/umlagen.csv` in `data/eingang/umlagen.csv`. The next run validates it, merges it into the seed by `umlage_code` and `gueltig_ab`, and moves it to `data/eingang/archiv/`. An invalid file fails the task and leaves the seed unchanged. Nothing is downloaded from the web. Tests: `cd scripts && python3 -m unittest test_ingest_umlagen`.

**Backfill:** Airflow must be running. Runs start at midnight in Berlin, which is the previous day in UTC, and backfill dates are read as UTC. So `--from-date` must be one day before the first date you want:

```bash
airflow backfill create --dag-id cost_model --from-date 2024-12-31 --to-date 2025-12-31 --max-active-runs 1
```

Each date takes about 30 seconds, and results land in `historie/`. The `mart_direkte_kosten_kunde` table holds whichever run finished last, so read `mart_direkte_kosten_kunde_historie` after a backfill. Add `--reprocess-behavior failed` to retry failed dates.

**One writer at a time:** DuckDB allows a single writer, so all dbt tasks use the one-slot pool `duckdb_schreiber`, created by `setup.sh`. Without that pool, the tasks will not be scheduled.

**2027 scenario:** `mart_szenario_bundeszuschuss` has one row per customer and scenario, with and without the federal grid subsidy. Both use the 2027 rates, including the Umlagen assumption. The subsidy value in `seeds/szenarien.csv` is **illustrative**: its removal adds 1.60 ct/kWh to the Arbeitspreis. The model also assumes the provisional 2027 Netzentgelte already include the subsidy.
