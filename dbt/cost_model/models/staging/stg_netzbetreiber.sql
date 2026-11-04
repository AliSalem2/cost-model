-- Stammdaten der Verteilnetzbetreiber.
select
    netzbetreiber_id,
    netzbetreiber_name,
    bundesland
from {{ ref('netzbetreiber') }}
