-- Gesetzliche Umlagen pro kWh mit Gueltigkeitszeitraum.
select
    umlage_code,
    umlage_name,
    cast(gueltig_ab as date)                                   as gueltig_ab,
    coalesce(cast(gueltig_bis as date), date '{{ var("offenes_ende") }}') as gueltig_bis,
    cast(ct_pro_kwh as decimal(10, 4))                         as ct_pro_kwh,
    quelle
from {{ ref('umlagen') }}
