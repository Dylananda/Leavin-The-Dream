"""Descarga de OpenStreetMap (Overpass API) los datos del barrio del Raval.

Guarda la respuesta cruda en data/raw/raval_osm.json; build_map.py la convierte
en la cuadrícula que carga el juego.

La descarga se parte en varias consultas pequeñas (calles, edificios, lugares...)
que se combinan al final: una sola consulta grande tarda tanto que los servidores
a veces la cortan o devuelven resultados incompletos sin avisar. Si alguna parte
trae muchos menos elementos que la descarga anterior, no se sobrescribe nada
(se puede forzar con --force).

Uso: python tools/fetch_osm.py [--force]
"""
import json
import math
import pathlib
import sys
import time

import requests

# El servidor principal suele saturarse; se prueban espejos por orden.
OVERPASS_URLS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://overpass.private.coffee/api/interpreter",
]
ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "data" / "raw" / "raval_osm.json"
MARGIN_M = 40.0
MIN_RATIO = 0.75  ## una parte con menos de este porcentaje de la descarga anterior se da por incompleta

# El Raval es un barrio oficial de Barcelona (admin_level 10).
HEADER = """
[out:json][timeout:120];
area["name"="Barcelona"]["admin_level"="8"]->.bcn;
rel(area.bcn)["boundary"="administrative"]["admin_level"="10"]["name"="el Raval"]->.raval;
.raval map_to_area->.a;
"""
# Calles y edificios: rectángulo que envuelve el contorno más MARGIN_M, para tener las calles
# frontera (Rambla, Paral·lel, Rondas) y la acera de enfrente; build_map.py recorta lo que sobra.
# ("around" sobre el contorno ya no devuelve esas calles en los servidores de Overpass.)
# {bbox} se rellena con el rectángulo calculado a partir del contorno descargado.
PARTS = {
    "contorno": ".raval out geom;",
    "calles": """(
  way({bbox})["highway"];
  way({bbox})["place"="square"];
  way({bbox})["leisure"~"park|playground"];
); out geom;""",
    "edificios": """(
  way({bbox})["building"];
); out geom;""",
    # edificios con patio interior (multipolígonos): son muchas manzanas enteras
    "edificios_patio": """(
  rel({bbox})["building"];
); out geom;""",
    "lugares": """(
  node(area.a)["amenity"];
  node(area.a)["shop"];
  way(area.a)["amenity"];
  nwr(area.a)["tourism"~"artwork|museum|attraction|hotel"];
  nwr(area.a)["historic"];
); out geom;""",
    "arboles": """(
  node(area.a)["natural"="tree"];
  way(area.a)["natural"="tree_row"];
); out geom;""",
}


def fetch(query: str) -> list[dict]:
    last_error: Exception | None = None
    for attempt in range(3):
        for url in OVERPASS_URLS:
            try:
                resp = requests.post(
                    url,
                    data={"data": query},
                    headers={"User-Agent": "yonkiland-prototype/0.1"},
                    timeout=180,
                )
                resp.raise_for_status()
                data = resp.json()
                if data.get("remark"):  # p. ej. "runtime error: Query timed out": resultado parcial
                    raise requests.RequestException(data["remark"])
                return data["elements"]
            except (requests.RequestException, ValueError) as e:
                print(f"  fallo en {url}: {e}")
                last_error = e
        time.sleep(15 * (attempt + 1))
    raise RuntimeError("Ningún servidor Overpass respondió") from last_error


def bbox_around(boundary: dict, margin_m: float) -> str:
    """Rectángulo "sur,oeste,norte,este" que envuelve el contorno con un margen en metros."""
    pts = [p for m in boundary["members"] if m["type"] == "way" for p in m.get("geometry", [])]
    lat0 = sum(p["lat"] for p in pts) / len(pts)
    dlat = margin_m / 110540.0
    dlon = margin_m / (111320.0 * math.cos(math.radians(lat0)))
    return "%.6f,%.6f,%.6f,%.6f" % (
        min(p["lat"] for p in pts) - dlat, min(p["lon"] for p in pts) - dlon,
        max(p["lat"] for p in pts) + dlat, max(p["lon"] for p in pts) + dlon)


def part_of(e: dict) -> str:
    """A qué parte pertenece un elemento ya descargado (para comparar con la descarga anterior)."""
    t = e.get("tags", {})
    if t.get("boundary") == "administrative":
        return "contorno"
    if "highway" in t or t.get("place") == "square" or "leisure" in t:
        return "calles"
    if "building" in t:
        return "edificios_patio" if e["type"] == "relation" else "edificios"
    if t.get("natural") in ("tree", "tree_row"):
        return "arboles"
    return "lugares"


def main() -> None:
    previous: dict[str, int] = {}
    if OUT.exists():
        for e in json.loads(OUT.read_text(encoding="utf-8"))["elements"]:
            previous[part_of(e)] = previous.get(part_of(e), 0) + 1
    merged: dict[tuple[str, int], dict] = {}
    short = []
    bbox = ""
    for name, body in PARTS.items():
        print(f"Descargando {name}...")
        elements = fetch(HEADER + body.replace("{bbox}", bbox))
        if name == "contorno":
            bbox = bbox_around(elements[0], MARGIN_M)
        before = previous.get(name, 0)
        print(f"  {len(elements)} elementos (antes {before})")
        if before and len(elements) < before * MIN_RATIO:
            short.append(name)
        for e in elements:
            merged[(e["type"], e["id"])] = e
    if short and "--force" not in sys.argv:
        print(f"Parece incompleto ({', '.join(short)}); no se guarda. Prueba más tarde o usa --force.")
        sys.exit(1)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"elements": list(merged.values())}), encoding="utf-8")
    kinds: dict[str, int] = {}
    for el in merged.values():
        kinds[el["type"]] = kinds.get(el["type"], 0) + 1
    print(f"Guardado {OUT} -> {kinds}")


if __name__ == "__main__":
    main()
