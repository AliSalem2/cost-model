-- Netzentgelte fuer Haushaltskunden (Niederspannung) je Netzbetreiber und Jahr.
-- Status 'vorlaeufig' = Preisblatt noch nicht endgueltig veroeffentlicht.
select
    netzbetreiber_id,
    cast(gueltig_ab as date)                                   as gueltig_ab,
    coalesce(cast(gueltig_bis as date), date '{{ var("offenes_ende") }}') as gueltig_bis,
    cast(grundpreis_eur_pro_jahr as decimal(10, 2))            as grundpreis_eur_pro_jahr,
    cast(arbeitspreis_ct_pro_kwh as decimal(10, 4))            as arbeitspreis_ct_pro_kwh,
    status,
    status = 'vorlaeufig'                                      as ist_vorlaeufig,
    quelle
from {{ ref('netzentgelte') }}
