"""python3 -m unittest discover -s scripts"""

import tempfile
import unittest
from pathlib import Path

from ingest_umlagen import main

KOPF = "umlage_code,umlage_name,gueltig_ab,gueltig_bis,ct_pro_kwh,quelle\n"
KWKG_2026 = "KWKG,KWKG-Umlage,2026-01-01,2026-12-31,0.446,alt\n"
OFF_2026 = "OFFSHORE,Offshore-Netzumlage,2026-01-01,2026-12-31,0.941,alt\n"


class IngestTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.dir = Path(tmp.name)
        self.seed = self.dir / "seed.csv"
        self.eingang = self.dir / "umlagen.csv"
        self.seed.write_text(KOPF + KWKG_2026 + OFF_2026)

    def lauf(self, inhalt=None):
        if inhalt is not None:
            self.eingang.write_text(inhalt)
        return main(["--eingang", str(self.eingang), "--seed", str(self.seed)])

    def assert_abgelehnt(self, inhalt):
        vorher = self.seed.read_text()
        self.assertEqual(self.lauf(inhalt), 1)
        self.assertEqual(self.seed.read_text(), vorher)
        self.assertTrue(self.eingang.exists(), "abgelehnte Datei bleibt zum Korrigieren liegen")

    def test_ohne_datei_passiert_nichts(self):
        vorher = self.seed.read_text()
        self.assertEqual(self.lauf(), 0)
        self.assertEqual(self.seed.read_text(), vorher)

    def test_neues_jahr_landet_sortiert_und_datei_im_archiv(self):
        neu = "KWKG,KWKG-Umlage,2027-01-01,2027-12-31,0.5,neu\n"
        self.assertEqual(self.lauf(KOPF + neu), 0)
        self.assertEqual(self.seed.read_text(), KOPF + KWKG_2026 + neu + OFF_2026)
        self.assertFalse(self.eingang.exists())
        self.assertEqual(len(list((self.dir / "archiv").iterdir())), 1)

    def test_gleicher_zeitraum_wird_ersetzt_und_zweiter_lauf_aendert_nichts(self):
        neu = "KWKG,KWKG-Umlage,2026-01-01,2026-12-31,0.450,korrigiert\n"
        erwartet = KOPF + neu + OFF_2026
        self.assertEqual(self.lauf(KOPF + neu), 0)
        self.assertEqual(self.seed.read_text(), erwartet)
        self.assertEqual(self.lauf(KOPF + neu), 0)
        self.assertEqual(self.seed.read_text(), erwartet)

    def test_dezimalkomma_wird_abgelehnt(self):
        self.assert_abgelehnt(KOPF + 'KWKG,KWKG-Umlage,2027-01-01,2027-12-31,"0,5",neu\n')

    def test_falsche_spalten_werden_abgelehnt(self):
        self.assert_abgelehnt("code,wert\nKWKG,0.5\n")

    def test_unbekannter_code_wird_abgelehnt(self):
        self.assert_abgelehnt(KOPF + "EEG,EEG,2027-01-01,2027-12-31,0.5,neu\n")

    def test_ueberlappung_mit_bestand_wird_abgelehnt(self):
        self.assert_abgelehnt(KOPF + "KWKG,KWKG-Umlage,2026-07-01,2027-06-30,0.5,neu\n")

    def test_eine_schlechte_zeile_verwirft_die_ganze_datei(self):
        self.assert_abgelehnt(
            KOPF + "KWKG,KWKG-Umlage,2027-01-01,2027-12-31,0.5,neu\n" + "OFFSHORE,Offshore,2027-13-01,2027-12-31,0.5,neu\n"
        )


if __name__ == "__main__":
    unittest.main()
