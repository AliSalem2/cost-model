-- Direkte Kosten je Kunde an einem Stichtag (netto, ohne Energiebeschaffung, Marge und Umsatzsteuer).
-- Korn: eine Zeile je Kunde mit Vertragsbeginn bis zum Stichtag.
-- Jahreswerte rechnen die am Stichtag gueltigen Saetze auf den Jahresverbrauch hoch.
--
-- Stichtag: dbt run --vars '{stichtag: 2026-06-15}' (ohne Angabe: heutiges Datum).
-- Fehlt fuer den Stichtag ein Kostenbestandteil, bleiben die Summen NULL und
-- ist_vollstaendig = false. So entsteht keine zu niedrige Summe und kein Kunde faellt still weg.
--
-- Nach jedem Lauf wird das Ergebnis je Stichtag als Parquet-Datei gesichert. Ein erneuter
-- Lauf fuer denselben Stichtag ersetzt dessen Datei (siehe ..._historie).
{{ config(post_hook="
    copy (select * from {{ this }})
    to '{{ var(\"historie_pfad\") }}'
    (format parquet, partition_by (stichtag), overwrite_or_ignore, filename_pattern 'daten_{i}')
") }}
{% set stichtag = var('stichtag', none) %}


{{ direkte_kosten("date '" ~ stichtag ~ "'" if stichtag else "current_date") }}
