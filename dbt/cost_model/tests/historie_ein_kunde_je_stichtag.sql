-- Ein erneuter Lauf fuer denselben Stichtag muss die Dateien ersetzen, nicht ergaenzen.
select stichtag, kunden_id, count(*) as anzahl
from {{ ref('mart_direkte_kosten_kunde_historie') }}
group by stichtag, kunden_id
having count(*) > 1
