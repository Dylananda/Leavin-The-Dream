# Yonkiland — notas para Claude

Juego isométrico 3D en Godot 4.7 (GDScript, renderer Compatibility) en el que eres un yonki
en el Raval de Barcelona, construido con datos reales. Lee `README.md` para la estructura
del código y `docs/ideas.md` para las ideas y la hoja de ruta (y márcalas al terminarlas).

## Convenciones

- Todo en español: textos del juego, comentarios, docstrings, mensajes de commit.
- Sigue el estilo del código existente: comentarios `##` de documentación en GDScript,
  tipos explícitos (`var x := ...`), constantes en MAYÚSCULAS con su explicación.
- La interfaz se construye por código (`game/scripts/ui/hud.gd`), no con escenas.
- El equilibrio del juego (perfiles, sustancias, objetos, hitos) está en `game/scripts/defs.gd`.
- Personajes basados en fenómenos documentados del barrio: con nombre, historia y motivos,
  nunca reducidos a un estereotipo por nacionalidad.
- El usuario tiene una pantalla 4K; el HUD se escala con `canvas_items`.

## Git

- Trabaja en una rama por mejora; no subas nada a GitHub
  (`origin` = github.com/Dylananda/Leavin-The-Dream) sin preguntar.
- La rama del colaborador se llama `ftgy`.

## Godot

Ejecutables en
`%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\`:

- `Godot_v4.7.2-stable_win64_console.exe` para pruebas sin ventana (`--headless`) o capturas.
- `Godot_v4.7.2-stable_win64.exe` para abrir el juego al usuario, lanzado con `Start-Process`.
  La versión `_console` lanzada con ventana en segundo plano se queda colgada sin abrir nada.
- El log de cada partida queda en `%APPDATA%\Godot\app_userdata\Yonkiland\logs\`.

Comprobaciones antes de dar algo por terminado:

```
Godot_v4.7.2-stable_win64_console.exe --headless --path game --script res://tests/smoke.gd
Godot_v4.7.2-stable_win64_console.exe --path game --resolution 1600x900 --script res://tests/screenshot.gd -- res://scenes/world.tscn <salida.png> [perfil] [texto de un rótulo] [hora]
```

El test de humo ejecuta todas las acciones con los 6 perfiles; no debe haber `SCRIPT ERROR`.
Redirige la entrada desde `/dev/null` al lanzarlo desde Bash.

## En la nube (sesiones desde el móvil)

Si `CLAUDE_CODE_REMOTE` es `true`, estás en una sesión en la nube (Linux, sin pantalla):

- Godot es `godot` (lo instala `tools/cloud_setup.sh`, el script de preparación del entorno).
  Antes de la primera prueba: `godot --headless --path game --import`.
- Solo se puede pasar el test de humo (`godot --headless --path game --script res://tests/smoke.gd`);
  las capturas necesitan pantalla: déjalas para cuando el usuario esté en su PC y díselo.
- Trabaja en una rama nueva y súbela a GitHub al terminar (en la nube es como llega el
  trabajo al usuario); no toques `main`.

## Mapa (datos de OpenStreetMap)

- `python tools/fetch_osm.py` descarga por partes y se niega a guardar si falta algo
  (los servidores de Overpass se saturan a menudo; reintenta más tarde).
- `python tools/build_map.py` genera `game/data/raval_map.json` y `game/assets/ground.png`.
  Se pueden ejecutar sin `-I`: necesitan Pillow y requests del entorno del usuario.
- La cuadrícula de navegación es de 2 m (`CELL_M`). Tipos de casilla en `CityMap.Cell`.
