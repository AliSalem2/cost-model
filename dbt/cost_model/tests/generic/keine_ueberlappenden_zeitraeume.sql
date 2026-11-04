{#
  Ein Wert darf fuer denselben Schluessel nur einmal pro Zeitpunkt gelten.
  Schlaegt fehl, sobald sich zwei Zeitraeume desselben Schluessels ueberschneiden.

  Beispiel:
    - keine_ueberlappenden_zeitraeume:
        schluessel: [netzbetreiber_id]
        von: gueltig_ab      # optional, Standard gueltig_ab
        bis: gueltig_bis     # optional, Standard gueltig_bis
#}
{% test keine_ueberlappenden_zeitraeume(model, schluessel=[], von='gueltig_ab', bis='gueltig_bis') %}

select
    {% for spalte in schluessel %}a.{{ spalte }}, {% endfor %}
    a.{{ von }} as zeitraum_a_von,
    a.{{ bis }} as zeitraum_a_bis,
    b.{{ von }} as zeitraum_b_von
from {{ model }} a
join {{ model }} b
  on a.{{ von }} < b.{{ von }}
 and b.{{ von }} <= a.{{ bis }}
 {% for spalte in schluessel %}
 and a.{{ spalte }} = b.{{ spalte }}
 {% endfor %}

{% endtest %}
