-- Jeder Kunde genau einmal je Szenario, und jeder Kunde in allen Szenarien.
select kunden_id, count(*) as anzahl, count(distinct szenario_code) as szenarien
from {{ ref('mart_szenario_bundeszuschuss') }}
group by kunden_id
having count(*) <> (select count(*) from {{ ref('stg_szenarien') }})
    or count(distinct szenario_code) <> (select count(*) from {{ ref('stg_szenarien') }})
