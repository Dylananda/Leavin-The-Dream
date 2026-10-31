"""Descarga de OpenStreetMap (Overpass API) los datos del barrio del Raval.

Guarda la respuesta cruda en data/raw/raval_osm.json; build_map.py la convierte
en la cuadrícula que carga el juego.

Uso: python tools/fetch_osm.py
"""
import json
import pathlib
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

# El Raval es un barrio oficial de Barcelona (admin_level 10).
QUERY = """
[out:json][timeout:120];
area["name"="Barcelona"]["admin_level"="8"]->.bcn;
rel(area.bcn)["boundary"="administrative"]["admin_level"="10"]["name"="el Raval"]->.raval;
.raval out geom;
.raval map_to_area->.a;
// Interior del barrio más una franja de 40 m alrededor del contorno,
// para tener las calles frontera (Rambla, Paral·lel, Rondas) y la acera de enfrente.
(
  way(area.a)["highway"];
  way(around.raval:40)["highway"];
  way(area.a)["building"];
  way(around.raval:40)["building"];
  way(area.a)["leisure"~"park|playground"];
  way(area.a)["place"="square"];
  way(around.raval:40)["place"="square"];
  node(area.a)["amenity"];
  node(area.a)["shop"];
  way(area.a)["amenity"];
  // monumentos, obras de arte y árboles para que el barrio se reconozca
  nwr(area.a)["tourism"~"artwork|museum|attraction|hotel"];
  nwr(area.a)["historic"];
  way(area.a)["building"]["name"];
  node(area.a)["natural"="tree"];
  way(area.a)["natural"="tree_row"];
);
out geom;
"""


def fetch() -> dict:
    last_error: Exception | None = None
    for attempt in range(2):
        for url in OVERPASS_URLS:
            try:
                resp = requests.post(
                    url,
                    data={"data": QUERY},
                    headers={"User-Agent": "yonkiland-prototype/0.1"},
                    timeout=180,
                )
                resp.raise_for_status()
                return resp.json()
            except requests.RequestException as e:
                print(f"Fallo en {url}: {e}")
                last_error = e
        time.sleep(10 * (attempt + 1))
    raise RuntimeError("Ningún servidor Overpass respondió") from last_error


def main() -> None:
    data = fetch()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(data), encoding="utf-8")
    kinds: dict[str, int] = {}
    for el in data["elements"]:
        kinds[el["type"]] = kinds.get(el["type"], 0) + 1
    print(f"Guardado {OUT} -> {kinds}")


if __name__ == "__main__":
    main()
