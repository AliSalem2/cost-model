-- Kundenstamm (fiktive Beispielkunden).
select
    kunden_id,
    kundentyp,
    lpad(plz, 5, '0')                                          as plz,
    ort,
    cast(einwohner_ort as bigint)                              as einwohner_ort,
    netzbetreiber_id,
    cast(jahresverbrauch_kwh as integer)                       as jahresverbrauch_kwh,
    cast(vertragsbeginn as date)                               as vertragsbeginn
from {{ ref('kunden') }}
