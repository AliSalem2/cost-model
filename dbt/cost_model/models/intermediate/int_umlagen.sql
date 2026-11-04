-- Umlagen inklusive Annahme fuer das Jahr ohne veroeffentlichte Werte (Var umlagen_annahme_jahr).
-- Annahme = ungewichteter Mittelwert aller frueheren Werte je Umlage.
-- Sobald ein echter Wert im Seed steht, entfaellt die Annahme fuer diese Umlage automatisch.
{% set jahr = var('umlagen_annahme_jahr') %}

with bekannt as (

    select *, false as ist_annahme
    from {{ ref('stg_umlagen') }}

),

annahme as (

    select
        umlage_code,
        any_value(umlage_name)                                 as umlage_name,
        date '{{ jahr }}-01-01'                                as gueltig_ab,
        date '{{ jahr }}-12-31'                                as gueltig_bis,
        cast(avg(ct_pro_kwh) as decimal(10, 4))                as ct_pro_kwh,
        'Annahme: Mittelwert der Vorjahre'                     as quelle,
        true                                                   as ist_annahme
    from bekannt
    where gueltig_ab < date '{{ jahr }}-01-01'
      and umlage_code not in (
          select umlage_code
          from bekannt
          where gueltig_bis >= date '{{ jahr }}-01-01'
            and gueltig_ab <= date '{{ jahr }}-12-31'
      )
    group by umlage_code

)

select * from bekannt
union all
select * from annahme
