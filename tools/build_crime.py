"""Resume los incidentes de la Guàrdia Urbana de un barrio para ajustar el juego.

Entrada:  data/raw/2024_incidents_gub.csv
          (Open Data BCN, dataset "incidents-gestionats-gub", CC BY 4.0)
Salida:   game/data/raval_crime.json

Cada categoría se expresa como índice relativo a la mediana de los 73 barrios
(1.0 = barrio típico). El juego usa esos índices para la densidad de policía,
de otros yonkis, de peleas, etc.

Uso: python tools/build_crime.py [barrio]
"""
import csv
import json
import pathlib
import statistics
import sys
from collections import defaultdict

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "data" / "raw" / "2024_incidents_gub.csv"
OUT = ROOT / "game" / "data" / "raval_crime.json"

# Categoría del juego -> descripciones de incidente de la GUB que la componen
CATEGORIES = {
    "vulnerables": ["COL·LECTIUS VULNERABLES", "ASSISTÈNCIA A PERSONES EN ESPAIS PÚBLICS"],
    "peleas": ["BARALLES"],
    "molestias": ["ACTIVITATS MOLESTES EN ESPAIS PÚBLICS", "CONVIVÈNCIA VEINAL"],
    "venta_ambulante": ["VENDA AMBULANT"],
    "locales": ["INCIDÈNCIES DE LOCALS", "INFRACCIONS EN LOCALS"],
}


def main() -> None:
    barrio = sys.argv[1] if len(sys.argv) > 1 else "el Raval"
    per_barri: dict[str, dict[str, int]] = defaultdict(lambda: defaultdict(int))
    with SRC.open(encoding="utf-8-sig") as f:
        for row in csv.DictReader(f):
            name = row["Nom_barri"]
            if not name:
                continue
            n = int(row["Numero_incidents_GUB"] or 0)
            per_barri[name]["total"] += n
            for cat, descs in CATEGORIES.items():
                if row["Descripcio_Incident"].strip() in descs:
                    per_barri[name][cat] += n

    if barrio not in per_barri:
        raise SystemExit(f"Barrio desconocido: {barrio}")

    ranking = sorted(per_barri, key=lambda b: per_barri[b]["total"], reverse=True)
    out = {
        "barrio": barrio,
        "year": 2024,
        "source": "Open Data BCN - Incidents gestionats per la Guàrdia Urbana (CC BY 4.0)",
        "total_incidents": per_barri[barrio]["total"],
        "rank": ranking.index(barrio) + 1,
        "barrios": len(ranking),
        "counts": {},
        "index": {},
    }
    for cat in ["total", *CATEGORIES]:
        median = statistics.median(per_barri[b][cat] for b in per_barri) or 1
        out["counts"][cat] = per_barri[barrio][cat]
        out["index"][cat] = round(per_barri[barrio][cat] / median, 2)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(out, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
