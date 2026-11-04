{#
  Ein Zeitraum muss vor seinem Ende beginnen.
  Schlaegt fehl fuer jede Zeile mit von > bis.
#}
{% test zeitraum_gueltig(model, von='gueltig_ab', bis='gueltig_bis') %}

select *
from {{ model }}
where {{ von }} > {{ bis }}

{% endtest %}
