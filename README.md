# Yonkiland

Juego isométrico 3D (Godot 4.7, cámara ortográfica) en el que eres un yonki en el Raval de Barcelona.
El objetivo es caer lo más bajo posible sin morirte antes de tiempo.

## Jugar

Abre `game/project.godot` con Godot 4.7 y pulsa F5.

- WASD o flechas: andar (Shift: correr)
- Clic: ir a un sitio, o hablar con un bot / entrar en un lugar
- I: inventario · R: rebuscar en la basura · Z: dormir donde estés
- Q/E: girar la cámara · Rueda: zoom

## Datos reales

| Qué | De dónde | Script |
|---|---|---|
| Calles, huellas y alturas de edificios, plazas, árboles, monumentos, lugares (bares, farmacias, cajeros, CAS Baluard...) y rótulos de comercios con los colores de su marca (`BRAND_STYLE`) | OpenStreetMap (Overpass API) | `tools/fetch_osm.py` → `tools/build_map.py` |
| Incidentes de la Guàrdia Urbana por barrio (2024) | Open Data BCN, dataset `incidents-gestionats-gub` | `tools/build_crime.py` |

Los índices de criminalidad (relativos a la mediana de los 73 barrios) regulan cuántos
policías, yonkis, camellos y manteros hay, y la frecuencia de peleas.

Regenerar todo:

```
python tools/fetch_osm.py
python tools/build_map.py
python tools/build_crime.py
python tools/make_textures.py
```

## Estructura

- `game/scripts/defs.gd` — perfiles, sustancias, objetos, hitos y títulos (aquí se equilibra el juego)
- `game/scripts/game_state.gd` — estadísticas, tiempo y puntuación de caída (autoload)
- `game/scripts/interactions.gd` — qué se puede hacer con cada bot y en cada lugar
- `game/scripts/world.gd` — escena de juego, entrada, eventos del barrio
- `game/scripts/city/` — mapa 3D: suelo, edificios extruidos (`building_mesher.gd`), monumentos, placas de calle y árboles (`city_props.gd`), carteles
- `game/shaders/building.gdshader` — fachadas caricaturizadas, ventanas encendidas de noche y rayos X
- Los monumentos con modelo propio se configuran en `LANDMARKS` (`tools/build_map.py`) y `CityProps.building_extra`
- `game/scripts/actors/` — personajes (jugador y bots comparten `Actor`)
- `game/tests/smoke.gd` — ejecuta todas las acciones con los 6 perfiles:
  `godot --headless --path game --script res://tests/smoke.gd`

Al exportar el juego, añade `*.json` al filtro de recursos que no son de Godot
para que se incluyan los datos de `game/data/`.

Mapa © OpenStreetMap contributors (ODbL). Datos de incidentes: Ajuntament de Barcelona (CC BY 4.0).
