-- Szenarien fuer den Bundeszuschuss zu den Netzentgelten.
-- Die vorlaeufigen Netzentgelte 2027 enthalten den Zuschuss bereits (Annahme),
-- sein Wegfall ist deshalb ein Aufschlag auf den Arbeitspreis. Der Wert ist illustrativ.
select
    szenario_code,
    szenario_name,
    cast(netzentgelt_aufschlag_ct_pro_kwh as decimal(10, 4))   as netzentgelt_aufschlag_ct_pro_kwh,
    quelle
from {{ ref('szenarien') }}
