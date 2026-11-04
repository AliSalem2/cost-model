-- Konzessionsabgabe nach Gemeindegroesse (KAV § 2), offene Grenzen aufgeloest.
select
    kundengruppe,
    cast(einwohner_von as bigint)                              as einwohner_von,
    coalesce(cast(einwohner_bis as bigint), 999999999)         as einwohner_bis,
    cast(ct_pro_kwh as decimal(10, 4))                         as ct_pro_kwh,
    cast(gueltig_ab as date)                                   as gueltig_ab,
    coalesce(cast(gueltig_bis as date), date '{{ var("offenes_ende") }}') as gueltig_bis,
    quelle
from {{ ref('konzessionsabgabe') }}
