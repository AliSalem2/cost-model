-- Direkte Kosten im Szenariojahr je Kunde, mit und ohne Bundeszuschuss zu den Netzentgelten.
-- Korn: eine Zeile je Kunde und Szenario. Basis ist MIT_BUNDESZUSCHUSS.
-- Der Zuschusswert ist illustrativ, und die Umlagen 2027 sind eine Annahme (ist_annahme).
{% set stichtag = var('szenario_stichtag') %}

with basis as (

    {{ direkte_kosten("date '" ~ stichtag ~ "'") }}

),

berechnet as (

    select
        z.szenario_code,
        b.stichtag,
        b.kunden_id,
        b.ort,
        b.netzbetreiber_id,
        b.jahresverbrauch_kwh,
        b.arbeitspreis_ct_pro_kwh + z.netzentgelt_aufschlag_ct_pro_kwh    as arbeitspreis_ct_pro_kwh,
        b.variable_kosten_ct_pro_kwh + z.netzentgelt_aufschlag_ct_pro_kwh as variable_kosten_ct_pro_kwh,
        b.grundpreis_eur_pro_jahr,
        (b.variable_kosten_ct_pro_kwh + z.netzentgelt_aufschlag_ct_pro_kwh)
            * b.jahresverbrauch_kwh / 100 + b.grundpreis_eur_pro_jahr     as gesamtkosten_eur_ungerundet,
        b.gesamtkosten_eur_pro_jahr                                       as basis_eur_pro_jahr,
        z.quelle = 'Beispielwert'                                         as ist_illustrativ,
        b.ist_vorlaeufig,
        b.ist_annahme,
        b.ist_vollstaendig
    from basis b
    cross join {{ ref('stg_szenarien') }} z

)

select
    szenario_code,
    stichtag,
    kunden_id,
    ort,
    netzbetreiber_id,
    jahresverbrauch_kwh,
    arbeitspreis_ct_pro_kwh,
    variable_kosten_ct_pro_kwh,
    grundpreis_eur_pro_jahr,
    cast(gesamtkosten_eur_ungerundet as decimal(12, 2))                 as gesamtkosten_eur_pro_jahr,
    cast(gesamtkosten_eur_ungerundet * 100 / nullif(jahresverbrauch_kwh, 0) as decimal(10, 4)) as gesamtkosten_ct_pro_kwh,
    cast(gesamtkosten_eur_ungerundet as decimal(12, 2)) - basis_eur_pro_jahr as differenz_zur_basis_eur_pro_jahr,
    ist_illustrativ,
    ist_vorlaeufig,
    ist_annahme,
    ist_vollstaendig
from berechnet
