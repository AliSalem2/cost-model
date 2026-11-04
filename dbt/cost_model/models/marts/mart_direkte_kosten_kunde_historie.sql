-- Alle bisher gesicherten Stichtage aus den lokalen Parquet-Dateien.
-- Korn: eine Zeile je Kunde und Stichtag. Der Pfad ist relativ zum dbt-Projektordner.
-- depends_on: {{ ref('mart_direkte_kosten_kunde') }}
select * replace (cast(stichtag as date) as stichtag)
from read_parquet('{{ var("historie_pfad") }}/*/*.parquet', hive_partitioning = true, union_by_name = true)
