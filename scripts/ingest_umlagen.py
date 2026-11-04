"""Uebernimmt neue Umlagen aus data/eingang/umlagen.csv in den dbt-Seed.

Die Datei hat dieselben Spalten wie seeds/umlagen.csv. Ohne Datei passiert nichts.
Vorhandene Zeilen werden je (umlage_code, gueltig_ab) ersetzt, neue ergaenzt.
Ist auch nur eine Zeile ungueltig, bricht der Lauf ab und der Seed bleibt unveraendert.
Danach wandert die Datei ins Archiv, damit sie spaetere Korrekturen nicht ueberschreibt.
"""

import argparse
import csv
import os
import shutil
import sys
from datetime import date, datetime, timezone
from decimal import Decimal, InvalidOperation
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPALTEN = ["umlage_code", "umlage_name", "gueltig_ab", "gueltig_bis", "ct_pro_kwh", "quelle"]
CODES = {"KWKG", "OFFSHORE", "BESONDERE_NETZNUTZUNG"}


class UngueltigeDatei(ValueError):
    pass


def lesen(pfad):
    with open(pfad, newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        if reader.fieldnames != SPALTEN:
            raise UngueltigeDatei(f"{pfad}: Spalten {reader.fieldnames}, erwartet {SPALTEN}")
        return list(reader)


def datum(wert):
    return date.fromisoformat(wert)


def pruefen(zeilen):
    fehler = []
    schluessel = set()
    for nr, z in enumerate(zeilen, start=2):
        if None in z or None in z.values():
            fehler.append(f"Zeile {nr}: falsche Spaltenzahl")
            continue
        if z["umlage_code"] not in CODES:
            fehler.append(f"Zeile {nr}: unbekannter umlage_code {z['umlage_code']!r}")
        try:
            if datum(z["gueltig_ab"]) > datum(z["gueltig_bis"]):
                fehler.append(f"Zeile {nr}: gueltig_ab liegt nach gueltig_bis")
        except ValueError:
            fehler.append(f"Zeile {nr}: Datum nicht im Format JJJJ-MM-TT")
        try:
            if not Decimal(z["ct_pro_kwh"]).is_finite():
                raise InvalidOperation
        except InvalidOperation:
            fehler.append(f"Zeile {nr}: ct_pro_kwh {z['ct_pro_kwh']!r} ist keine Zahl (Dezimalpunkt verwenden)")
        k = (z["umlage_code"], z["gueltig_ab"])
        if k in schluessel:
            fehler.append(f"Zeile {nr}: {k} kommt doppelt vor")
        schluessel.add(k)
    if fehler:
        raise UngueltigeDatei("\n".join(fehler))


def zusammenfuehren(bestand, neu):
    zeilen = {(z["umlage_code"], z["gueltig_ab"]): z for z in bestand}
    zeilen.update({(z["umlage_code"], z["gueltig_ab"]): z for z in neu})
    reihenfolge = {}
    for z in bestand + neu:
        reihenfolge.setdefault(z["umlage_code"], len(reihenfolge))
    ergebnis = sorted(zeilen.values(), key=lambda z: (reihenfolge[z["umlage_code"]], z["gueltig_ab"]))

    # Dieselbe Regel wie der dbt-Test, aber bevor der Seed geaendert wird.
    for a, b in zip(ergebnis, ergebnis[1:]):
        if a["umlage_code"] == b["umlage_code"] and datum(b["gueltig_ab"]) <= datum(a["gueltig_bis"]):
            raise UngueltigeDatei(
                f"{a['umlage_code']}: Zeitraeume ab {a['gueltig_ab']} und {b['gueltig_ab']} ueberschneiden sich"
            )
    return ergebnis


def schreiben(pfad, zeilen):
    tmp = pfad.with_name(pfad.name + ".tmp")
    with open(tmp, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=SPALTEN, lineterminator="\n")
        writer.writeheader()
        writer.writerows(zeilen)
    os.replace(tmp, pfad)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--eingang", type=Path, default=ROOT / "data" / "eingang" / "umlagen.csv")
    parser.add_argument("--seed", type=Path, default=ROOT / "dbt" / "cost_model" / "seeds" / "umlagen.csv")
    args = parser.parse_args(argv)

    if not args.eingang.exists():
        print(f"Keine Datei in {args.eingang}, nichts zu tun.")
        return 0

    try:
        neu = lesen(args.eingang)
        pruefen(neu)
        bestand = lesen(args.seed)
        ergebnis = zusammenfuehren(bestand, neu)
    except UngueltigeDatei as e:
        print(f"Datei abgelehnt, Seed unveraendert:\n{e}", file=sys.stderr)
        return 1

    if ergebnis != bestand:
        schreiben(args.seed, ergebnis)
    archiv = args.eingang.parent / "archiv"
    archiv.mkdir(exist_ok=True)
    stempel = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%f")
    shutil.move(args.eingang, archiv / f"{args.eingang.stem}_{stempel}{args.eingang.suffix}")
    print(f"{len(neu)} Zeilen uebernommen, Seed hat jetzt {len(ergebnis)} Zeilen.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
