{#
  Direkte Kosten je Kunde an einem Stichtag. Gemeinsame Berechnung fuer den Mart und die Szenarien.
  stichtag_sql: SQL-Ausdruck fuer das Datum, z. B. date '2026-06-15' oder current_date.
#}
{% macro direkte_kosten(stichtag_sql) %}

with stichtag as (

    select {{ stichtag_sql }} as stichtag

),

umlagen as (

    select
        s.stichtag,
        max(u.ct_pro_kwh) filter (where u.umlage_code = 'KWKG')                  as kwkg_ct_pro_kwh,
        max(u.ct_pro_kwh) filter (where u.umlage_code = 'OFFSHORE')              as offshore_ct_pro_kwh,
        max(u.ct_pro_kwh) filter (where u.umlage_code = 'BESONDERE_NETZNUTZUNG') as besondere_netznutzung_ct_pro_kwh,
        coalesce(bool_or(u.ist_annahme), false)                                  as ist_annahme
    from stichtag s
    left join {{ ref('int_umlagen') }} u
        on s.stichtag between u.gueltig_ab and u.gueltig_bis
    group by s.stichtag

),

komponenten as (

    select
        s.stichtag,
        k.kunden_id,
        k.plz,
        k.ort,
        k.netzbetreiber_id,
        k.jahresverbrauch_kwh,
        n.arbeitspreis_ct_pro_kwh,
        u.kwkg_ct_pro_kwh,
        u.offshore_ct_pro_kwh,
        u.besondere_netznutzung_ct_pro_kwh,
        ka.ct_pro_kwh as konzessionsabgabe_ct_pro_kwh,
        st.ct_pro_kwh as stromsteuer_ct_pro_kwh,
        n.grundpreis_eur_pro_jahr,
        coalesce(n.ist_vorlaeufig, false) as ist_vorlaeufig,
        u.ist_annahme
    from {{ ref('stg_kunden') }} k
    cross join stichtag s
    cross join umlagen u
    left join {{ ref('stg_netzentgelte') }} n
        on n.netzbetreiber_id = k.netzbetreiber_id
       and s.stichtag between n.gueltig_ab and n.gueltig_bis
    left join {{ ref('stg_konzessionsabgabe') }} ka
        -- Alle Kunden im Modell sind Haushalte und damit Tarifkunden nach KAV.
        on ka.kundengruppe = 'Tarifkunde'
       and k.einwohner_ort between ka.einwohner_von and ka.einwohner_bis
       and s.stichtag between ka.gueltig_ab and ka.gueltig_bis
    left join {{ ref('stg_stromsteuer') }} st
        on st.steuersatz_name = 'Regelsatz'
       and s.stichtag between st.gueltig_ab and st.gueltig_bis
    where k.vertragsbeginn <= s.stichtag

),

summiert as (

    select
        *,
        -- NULL in einem Bestandteil macht bewusst die ganze Summe NULL.
        arbeitspreis_ct_pro_kwh
            + kwkg_ct_pro_kwh
            + offshore_ct_pro_kwh
            + besondere_netznutzung_ct_pro_kwh
            + konzessionsabgabe_ct_pro_kwh
            + stromsteuer_ct_pro_kwh as variable_kosten_ct_pro_kwh
    from komponenten

),

berechnet as (

    select
        *,
        variable_kosten_ct_pro_kwh * jahresverbrauch_kwh / 100 + grundpreis_eur_pro_jahr as gesamtkosten_eur_ungerundet
    from summiert

)

select
    stichtag,
    kunden_id,
    plz,
    ort,
    netzbetreiber_id,
    jahresverbrauch_kwh,
    arbeitspreis_ct_pro_kwh,
    kwkg_ct_pro_kwh,
    offshore_ct_pro_kwh,
    besondere_netznutzung_ct_pro_kwh,
    konzessionsabgabe_ct_pro_kwh,
    stromsteuer_ct_pro_kwh,
    variable_kosten_ct_pro_kwh,
    grundpreis_eur_pro_jahr,
    cast(gesamtkosten_eur_ungerundet as decimal(12, 2)) as gesamtkosten_eur_pro_jahr,
    -- Inklusive anteiligem Grundpreis, deshalb je nach Verbrauch unterschiedlich.
    cast(gesamtkosten_eur_ungerundet * 100 / nullif(jahresverbrauch_kwh, 0) as decimal(10, 4)) as gesamtkosten_ct_pro_kwh,
    ist_vorlaeufig,
    ist_annahme,
    gesamtkosten_eur_ungerundet is not null as ist_vollstaendig
from berechnet

{% endmacro %}
