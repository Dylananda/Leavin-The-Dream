# Yonkiland

Juego isométrico 3D (Godot 4.7, cámara ortográfica) en el que eres un yonki en el Raval de Barcelona.
El objetivo es caer lo más bajo posible sin morirte antes de tiempo.

## Jugar

Abre `game/project.godot` con Godot 4.7 y pulsa F5.

- WASD o flechas: andar (Shift: correr)
- Clic: ir a un sitio, o hablar con un bot / entrar en un lugar
- I: inventario · L: libreta · R: rebuscar en la basura · Z: dormir donde estés
- Q/E: girar la cámara · Rueda: zoom

Con WASD el muñeco sigue la calle aunque no vaya en la dirección de la tecla, y se desliza
por las paredes. Los personajes tapados por un edificio se ven como silueta: tú en amarillo,
la policía en azul y quien tiene un encargo para ti en su color, con un «!» si te puede dar
uno o una «★» si ya te lo dio. Las flechas del borde de la pantalla llevan a los sitios de los
encargos en marcha... según lo que apuntaste en la libreta.

### El estado del personaje

Arriba a la izquierda, las barras del cuerpo (pasa el ratón por encima para ver qué las mueve):
**Salud**, **Hambre**, **Sueño**, **Mente** (salud mental), **Dignidad** y **Discreción**
(lo poco que llamas la atención; vacía, la policía va a por ti). La etiqueta se pone roja
cuando una barra está en zona de peligro. En los extremos pasan cosas: con el hambre al
máximo te desmayas y despiertas en urgencias, con el sueño al máximo te quedas frito en la
calle (y te pueden robar), con la mente a 0 te ingresan en el psiquiátrico.

Abajo a la derecha, una fila por cada sustancia que conoces: colocón (arriba), mono (abajo,
en rojo) y enganche (cifra). Cada perfil empieza conociendo alguna; probar una nueva es un
hito de la caída. Debajo se listan los efectos que tienes ahora y su causa: el caballo te
hace lento y balancea la cámara, la farlopa te acelera y la hace temblar, el porro estira
el tiempo y acerca la cámara, el alcohol te hace andar en eses y responder tarde, las
pastillas saturan los colores, la base da una euforia corta y un bajón brusco, y el mono
trae temblores, viñeta roja y tropiezos.

### Quién anda por la calle

Cada tipo de bot sale a sus horas y en su zona: de día, trileros y carteristas (vestidos
de guiri) en la Rambla; por la tarde y la noche, chavales que esnifan cola por la Rambla
del Raval y Sant Pau; de noche, despedidas de soltero y lateros junto a los bares. Los
personajes nuevos tienen nombre e historia propia; las fuentes están en `docs/ideas.md`.

### Encargos y libreta

Algunos personajes te hacen encargos con plazo («Encargo: ...» en su menú): el camello, que
lleves un paquete a un bar; la carterista, que dejes una cartera caliente en un compraventa;
la despedida, que los lleves de fiesta; la educadora, una cita al día siguiente en el CAS
Baluard. Se cumplen en el menú del sitio, que es un lugar real del mapa. Los sitios están
lejos unos de otros y los plazos se pisan, así que no llegas a todo. Si fallas, hay
consecuencias: deudas, la Urbana detrás o alguien que deja de fiarse de ti.

Cada encargo se apunta en la **libreta** (L), con un botón para marcar el sitio en el mapa.
Casi siempre es fiable, pero cuanto más ido vas (colocón, mono, sueño, mente baja) más fácil
es que hayas apuntado mal la hora o el sitio, que se te borre un dato o que no entiendas tu
propia letra. El reloj de arriba también miente a ratos: con porro se atrasa, con farlopa se
adelanta.

### Hablar con ellos (IA local)

A los lateros, trileros, carteristas y despedidas se les puede hablar libremente («Hablar»
en su menú): escribes lo que dices y contesta un modelo de lenguaje que hace de ese personaje.
El juego propone y la IA habla: en cada frase solo puede elegir entre lo que el juego le
deja (las acciones de su menú, datos ciertos como dónde están los agentes o los guiris, los
sitios cercanos), así que lo que te ofrece aparece como botón y hace exactamente lo mismo que
en el menú. También pueden enfadarse o echarte a la policía, y se acuerdan de lo hablado.

Por defecto usa [Ollama](https://ollama.com) en el propio PC con el modelo `qwen2.5:7b`
(`ollama pull qwen2.5:7b`; unos 4,7 GB, cabe en una GPU de 6 GB). Si la descarga falla porque
no llega a Cloudflare (en España pasa durante los partidos de fútbol), el mismo modelo se baja
de Hugging Face: `ollama pull hf.co/bartowski/Qwen2.5-7B-Instruct-GGUF:Q4_K_M` y luego
`ollama cp hf.co/bartowski/Qwen2.5-7B-Instruct-GGUF:Q4_K_M qwen2.5:7b`. Cada respuesta tarda
unos 15 s (la primera, más: carga el modelo). Sin IA, el juego funciona igual y lo dice en el
registro.

Para usar **Claude** (API de Anthropic, de pago por uso; hace falta una clave de
[platform.claude.com](https://platform.claude.com), no vale la suscripción de claude.ai), crea
`%APPDATA%\Godot\app_userdata\Yonkiland\ia.cfg`:

```
[ia]
proveedor="anthropic"
modelo="claude-opus-5-5"    ; o "claude-haiku-5-5", mucho más barato y rápido
clave="sk-ant-..."          ; o la variable de entorno ANTHROPIC_API_KEY
```

Con `proveedor="ollama"` se puede poner otro `modelo` local; con `proveedor="openai"` (y `url`),
cualquier API compatible con OpenAI. Para comparar sin tocar el archivo, `tests/charla.gd`
también lee las variables `YONKILAND_IA_PROVEEDOR` y `YONKILAND_IA_MODELO`.

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
- `game/scripts/game_state.gd` — estadísticas, sustancias (colocón, mono, enganche), consecuencias
  de los extremos, efectos activos (`effects()`), tiempo y puntuación de caída (autoload)
- `game/scripts/interactions.gd` — qué se puede hacer con cada bot y en cada lugar
- `game/scripts/errands.gd` — encargos con plazo (ofrecer, cumplir, fallar) y la libreta que
  se apunta y se lee peor cuanto más ido vas (equilibrio en `Defs.ERRANDS`)
- `game/scripts/world.gd` — escena de juego, entrada, eventos del barrio y cómo los efectos
  cambian la cámara y el movimiento
- `game/scripts/ui/hud.gd` — barras, panel de sustancias y efectos, registro, menús, libreta, conversación
- `game/scripts/ai/` — conversación con IA: cliente HTTP (`llm_client.gd`, Ollama o API tipo
  OpenAI), fichas de los personajes (`fichas.gd`) y contexto, memoria y acciones de juego
  (`conversation.gd`)
- `game/shaders/vignette.gdshader` — filtro de pantalla con los efectos (mono, pastillas, sueño, túnel...)
- `game/scripts/city/` — mapa 3D: suelo, edificios extruidos (`building_mesher.gd`), monumentos, placas de calle y árboles (`city_props.gd`), carteles
- `game/shaders/building.gdshader` — fachadas caricaturizadas, ventanas encendidas de noche y rayos X
- Los monumentos con modelo propio se configuran en `LANDMARKS` (`tools/build_map.py`) y `CityProps.building_extra`
- `game/scripts/actors/` — personajes (jugador y bots comparten `Actor`: modelo con género y
  rasgos, silueta, icono flotante y el andar con WASD que sigue la calle); en `Npc.KINDS`,
  cada tipo de bot con su horario, zona, disfraz, historias y el género de cada nombre
- `game/shaders/silhouette.gdshader` — silueta de los personajes a través de los edificios (stencil)
- `game/tests/smoke.gd` — ejecuta todas las acciones con los 6 perfiles, cada sustancia,
  los extremos de hambre, sueño y salud mental, y los encargos con la libreta, el género de los personajes y los iconos de encargo; termina con `OK` o el número de fallos:
  `godot --headless --path game --script res://tests/smoke.gd`
- `game/tests/charla.gd` — conversación real con la IA sin abrir el juego (necesita Ollama):
  `godot --headless --path game --script res://tests/charla.gd -- latero "Hola" "¿Viene la Urbana?"`
- `game/tests/retratos.gd` — captura de los perfiles (o de los bots de un tipo, o `todos`) en fila
  y de cerca, para revisar género y rasgos: `godot --path game --script res://tests/retratos.gd -- out.png todos`
- `game/tests/screenshot.gd` — capturas sin abrir el editor; el sexto argumento consume
  sustancias antes (p. ej. `... -- res://scenes/world.tscn shot.png parado "" 12 caballo,litrona`)

Al exportar el juego, añade `*.json` al filtro de recursos que no son de Godot
para que se incluyan los datos de `game/data/`.

Mapa © OpenStreetMap contributors (ODbL). Datos de incidentes: Ajuntament de Barcelona (CC BY 4.0).
