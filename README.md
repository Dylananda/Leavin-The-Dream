# Yonkiland

Juego isométrico 3D (Godot 4.7, cámara ortográfica) en el que eres un yonki en el Raval de Barcelona.
El objetivo es caer lo más bajo posible sin morirte antes de tiempo.

## Jugar

Abre `game/project.godot` con Godot 4.7 y pulsa F5.

- WASD o flechas: andar (Shift: correr)
- Clic: ir a un sitio, o hablar con un bot / entrar en un lugar
- I: inventario · L: libreta · M: mapa del barrio · P: pausa (también con los botones de arriba a la derecha)
- R: rebuscar en la basura · Z: dormir donde estés · B: montar en la bici (si llevas una)
- V: ver los conos de visión de todos los que tienes cerca
- Q/E: girar la cámara · Rueda: zoom

Con WASD el muñeco sigue la calle aunque no vaya en la dirección de la tecla, y se desliza
por las paredes. Los personajes tapados por un edificio se ven como silueta: tú en amarillo,
la policía en azul y quien tiene un encargo para ti en su color, con un «!» si te puede dar
uno o una «★» si ya te lo dio. Las flechas del borde de la pantalla llevan a los sitios de los
encargos en marcha... según lo que apuntaste en la libreta.

### Lo que ven y lo que recuerdan

Cada personaje ve en un cono, como en *Commandos*, que tapan los edificios: la policía, más
lejos y más estrecho. Los conos de los agentes y de quien sospecha de ti o va a por ti se
dibujan en el suelo (con V, los de todos): azul si están tranquilos, amarillo si te están
viendo («?») y rojo si van a por ti («!»). Se acuerdan de lo que les has hecho: si les pides
mucho se apartan, si les ayudaste se acercan a saludar, si les robaste van a por ti o a por
un agente, y el camello al que debes viene a cobrar en cuanto te ve.

La policía solo te persigue si te ve y estás muy buscado o **fichado**. Si te pillan robando
se monta un escándalo: la víctima grita, algún valiente intenta pararte, otros llaman a la
policía. Si no viene ningún agente, o si te escapas, quedas fichado un día (lo dice el HUD).
Escapar es salir de su vista: tras una esquina te buscan un rato donde te vieron por última vez.

### Minijuegos

Algunas acciones ya no son una tirada de dados: se juegan en otra vista, con el barrio en
pausa. Lo que antes subía o bajaba la probabilidad (agentes mirando, la noche, el colocón, el
oficio de carterista) ahora sube o baja la dificultad. Esc: dejarlo.

- **Robar al descuido** (la cartera a un guiri, el móvil a una despedida): la víctima en
  primer plano y tus dos manos. Con WASD, una le distrae con un plano o un mechero y le hace
  mirar hacia ella; con el ratón, la otra va al bolsillo y, con el botón pulsado, saca el
  botín. Si te ve la mano metida sospecha («?») y te pilla («!»). Mira a su aire: a los lados,
  a ti, o se palpa el bolsillo; la cartera de la mochila solo se alcanza si se gira del todo.
  Si se va sin que haya ocasión, se queda mosca y no se deja intentar otra vez.
  Robar una litrona en el súper o la propina del platito de un bar es igual, pero el botín
  está en el estante o en la barra y quien vigila es el dependiente o el camarero.
- **Hacer de vigía** (del mantero, del trilero o de aguador del camello): pasa gente por la
  calle. Clic izquierdo («¡Agua!») a la policía antes de que llegue a la manta; clic derecho
  para llamar a un cliente. Las secretas van de paisano, más despacio, se paran a mirar y se
  tocan el pinganillo, como un cliente que se para a ver el género (pero sin pinganillo).
  Cada falsa alarma resta paga, cada cliente suma, y un agente sin avisar es redada.

- **Pelear** (con otro yonki, o cuando te alcanza el camello al que debes o el de la esquina
  y no llevas nada): cara a cara. Cuando levanta un brazo («!»), esquiva con A o D hacia el
  otro lado; si falla se queda abierto («¡Ahora!») y es cuando más daño le hace tu clic. Pegarle
  a la guardia apenas sirve; cortarle mientras carga, algo. A los que vienen a darte una
  paliza cuesta mucho quitárselos de encima, pero se puede.

El mono y la farlopa hacen temblar las manos, el alcohol retrasa la mano de WASD, el sueño
cierra los párpados y, con paranoia, cualquiera parece que se toca la oreja.

### El estado del personaje

Arriba a la izquierda, las barras del cuerpo (pasa el ratón por encima para ver qué las mueve):
**Salud**, **Vitalidad** (el aguante para correr y pelear: se gasta corriendo y peleando, se
recupera andando o parado, y su máximo baja con el hambre, el sueño, el mono y la salud
perdida; vacía, estás agotado y no corres hasta recuperarte), **Hambre**, **Sueño**, **Mente** (salud mental), **Dignidad** y **Discreción**
(lo poco que llamas la atención; con poca, la policía va a por ti si te ve). La etiqueta se pone roja
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
del Raval y Sant Pau; de noche, despedidas de soltero y lateros junto a los bares. De día
también hay niños jugando en las plazas, gente mayor con bastón (y algunos con perro),
repartidores con la mochila cúbica a toda prisa y gente con pasta que viene al Liceu, al MACBA
o a ver un piso que comprar. Algunos vecinos, abuelos, yonkis y pijos sacan al perro, que va
detrás de ellos y se va cuando se van. Por la Rambla hay músicos en su punto fijo, estatuas
humanas (en el tramo de Colom) que no se mueven hasta que les echas una moneda, captadores de
discotecas y clubs cannábicos, caricaturistas y guías de free tour con su grupo detrás; en el
MACBA, skaters; en Robadors, trabajadoras sexuales; de noche, roseros por los bares; y a todas
horas, chatarreros con su carro, punkis con sus perros y gente sin techo que pide en la puerta
de una iglesia y de noche se va a su cajero o a su portal.

La policía son dos cuerpos. La **Guàrdia Urbana** lleva la convivencia: te despierta y te echa
si te ve dormir en la calle (en un rincón escondido es más difícil), multa por beber, requisa la
manta, las latas y la mesa del trile, y te manda a los Mossos si te chivas de un camello. Los
**Mossos d'Esquadra** llevan los delitos: peleas, drogas, detenciones y comisaría. Con las drogas
en la calle actúan los dos (la Urbana tiene su plan contra el menudeo), y si te alcanza la Urbana
llama a los Mossos. Los dos tienen
agentes de paisano (de guiri en la Rambla, de vecino en Robadors) que no se descubren hasta que
actúan. Si te fichan, te persigue el cuerpo al que le toca lo que hiciste. Los
personajes nuevos tienen nombre e historia propia; las fuentes están en `docs/ideas.md`.

### Cosas por la calle

Por el suelo hay de todo, casi siempre basura: móviles y carteras que se pierden a la salida
de los bares, cable de obra, chatarra, sobras, bicis y patinetes mal atados. Con un clic vas
y te lo llevas, y luego se vende en el compraventa. Llevarse una bici con un vecino o un agente
delante sube la búsqueda. Ido, no te fíes de tus ojos: la basura puede parecerte un móvil (y
no lo descubres hasta que intentas venderlo o se te pasa) o un móvil puede parecerte basura.

### Trapicheo

Lo que compras al camello se puede revender («Venderle...» en el menú de cada uno): las
despedidas pagan el doble, los guiris un dineral por un porro (cuidado: alguno es secreta) y
los yonkis poco. Los clientes que repiten pagan más y te buscan; si se la vendes cortada, sacas
más pero no se les olvida. Que no te vea un agente, ni un camello: vender en su esquina se paga.
Con los otros yonkis también se hace trueque: te cambian lo que llevan encima por tus objetos.

### Encargos y libreta

Algunos personajes te hacen encargos con plazo («Encargo: ...» en su menú): el camello, que
lleves un paquete a un bar; la carterista, que dejes una cartera caliente en un compraventa;
la despedida, que los lleves de fiesta; la educadora, una cita al día siguiente en el CAS
Baluard. Se cumplen en el menú del sitio, que es un lugar real del mapa. Los sitios están
lejos unos de otros y los plazos se pisan, así que no llegas a todo. Si fallas, hay
consecuencias: deudas, la Urbana detrás o alguien que deja de fiarse de ti.

Los personajes con nombre propio tienen además **misiones** («Misión «...»» en su menú, con
una «!» encima): Quique el Nano te pide que le lleves un paquete a Txell, a la que debes 40 €
(si se lo llevas, se lo queda por tu deuda y Quique te lo cobra a ti; si no, viene a por ti);
Antonio, que convenzas a la agente Mas de que tiene plaza en el albergue (con los papeles de la
cita en el CAS, o mintiendo, que si no cuela te ficha). Van a la libreta como los encargos, y
quien está en una misión en marcha lleva una «★». Algunas acaban en un favor: que te curen,
que te cuenten por dónde anda la policía o que una agente haga la vista gorda unos días.

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

## Diseñar personajes

`editor_personajes.cmd` (o `godot --path game res://editor/editor_personajes.tscn`) abre el
diseñador de personajes, una herramienta aparte del juego para crear personajes únicos:

- **Identidad**: nombre, edad, género, tipo base (de él hereda cómo se mueve y qué se puede
  hacer con él), historia y fuentes. Hay tipos que el juego aún no tiene (Guàrdia Urbana y
  Mossos, músicos, estatuas, mendigos...): se pueden diseñar ya y saldrán cuando existan.
- **Aspecto**, con el muñeco del juego al lado (se gira arrastrando, puede andar y verse de noche).
- **Zona y rutina** en el mapa: un barrio o zona hecha, o un polígono dibujado; su casa; y los
  lugares a los que va a ciertas horas (dormir, pedir, tocar...). Avisa si un punto cae en un edificio.
- **Estadísticas**, **ficha de conversación** para la IA y frases sueltas.
- **Misiones**: cuándo te la ofrece (horas, día, dignidad mínima, después de otra misión,
  repetible), qué hay que hacer con lo que ya tiene el juego (llevar algo a un sitio o a otro
  personaje, conseguirle algo, una cita, convencer a alguien con pruebas o mintiendo, y los
  minijuegos de robar, vigilar y pelear), el plazo y lo que pasa al cumplirla o al fallarla
  (dinero, objetos, deudas, favores, amigos y enemigos, las barras, la búsqueda, que te fichen).
  En el juego salen en su menú, se apuntan en la libreta como los encargos y quien te la da lleva la «!».
- **Notas**: lo que el editor aún no sabe expresar, en texto libre, para programarlo a mano.

Cada personaje se guarda en `game/data/personajes/<id>.json` y el juego lo saca a la calle en
su zona y a sus horas. Los campos marcados con ◌ se guardan pero el juego aún no los usa.
«Probar en el juego» guarda y abre una partida con el personaje al lado.

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
- `game/scripts/interactions.gd` — qué se puede hacer con cada bot y en cada lugar, lo que
  recuerdan de ello y los robos que acaban en escándalo
- `game/scripts/street_items.gd` — objetos tirados por la calle (móviles, carteras, cable, bicis,
  basura...) que se recogen con un clic y se confunden cuanto más ido vas; cada uno se dibuja
  con `scripts/city/street_item.gd` según lo que *te parece* que es (equilibrio en `Defs.STREET_ITEMS`)
- `game/scripts/trade.gd` — trapicheo: revender a despedidas, guiris y yonkis (clientes que se
  acuerdan, mercancía cortada, secretas, la esquina del camello) y trueque con otros yonkis
- `game/scripts/errands.gd` — encargos con plazo (ofrecer, cumplir, fallar) y la libreta que
  se apunta y se lee peor cuanto más ido vas (equilibrio en `Defs.ERRANDS`)
- `game/scripts/misiones.gd` — misiones de los personajes del editor: formato (`Misiones.nueva()`,
  objetivos, resultados y favores), ofrecerlas, cumplirlas con quien toca y sus consecuencias.
  En la partida son encargos con la clave `mision`
- `game/scripts/world.gd` — escena de juego, entrada, eventos del barrio y cómo los efectos
  cambian la cámara y el movimiento
- `game/scripts/ui/hud.gd` — barras, panel de sustancias y efectos, registro, menús, libreta,
  conversación y pausa; el mapa del barrio, en `ui/mapa_barrio.gd`
- `game/scripts/minigames/` — minijuegos de habilidad: la base (`minigame.gd`: vista 3D propia
  con marionetas de los personajes y capa 2D encima), robar al descuido (`pickpocket.gd`) y
  hacer de vigía (`lookout.gd`) y pelear (`fight.gd`). Se lanzan con `World.play_minigame`; sin pantalla (test de
  humo) se resuelven con la probabilidad de siempre. Medidas en `Defs` (`PICK_*`, `LOOKOUT_*`)
- `game/scripts/ai/` — conversación con IA: cliente HTTP (`llm_client.gd`, Ollama o API tipo
  OpenAI), fichas de los personajes (`fichas.gd`) y contexto, memoria y acciones de juego
  (`conversation.gd`)
- `game/shaders/vignette.gdshader` — filtro de pantalla con los efectos (mono, pastillas, sueño, túnel...)
- `game/scripts/city/` — mapa 3D: suelo, edificios extruidos (`building_mesher.gd`), monumentos, placas de calle y árboles (`city_props.gd`), carteles
- `game/shaders/building.gdshader` — fachadas caricaturizadas, ventanas encendidas de noche y rayos X
- Los monumentos con modelo propio se configuran en `LANDMARKS` (`tools/build_map.py`) y `CityProps.building_extra`
- `game/scripts/actors/` — personajes (jugador y bots comparten `Actor`: modelo con género y
  rasgos, silueta, icono flotante y el andar con WASD que sigue la calle); en `Npc.KINDS`,
  cada tipo de bot con su horario, zona, disfraz, historias y el género de cada nombre; en
  `Npc`, la visión en cono, la memoria y las reacciones (perseguir, buscar, denunciar, apartarse).
  Las medidas de la visión y del escándalo están en `Defs`
- Rendimiento: al montar cada personaje, sus piezas se juntan en cinco mallas con el color en
  los vértices (`Actor._merge_parts`: cuerpo y extremidades, con un solo material) y los bots
  fuera de la pantalla que no tienen nada contigo se actualizan cada `Defs.OFFSCREEN_EVERY`
  frames. En una GTX 1060 a 1600×900: unos 1.000 bots a 60 FPS (54 con todo el zoom)
- `game/scripts/censo.gd` — el censo del barrio: cada bot es un registro de datos y solo los
  que andan a menos de `Censo.RADIO_ACTIVO` casillas tienen cuerpo; los demás están latentes y,
  al acercarte, aparecen donde les toca por su casa, su rutina y la hora, con lo que les pasó
  y lo que han olvidado desde entonces (`Defs.LATENT_*`). No se duermen los que tienen asuntos
  contigo (te persiguen, les debes, te dieron un encargo). Gracias a esto el barrio tiene unos
  1.400 en el censo (`Defs.CROWD` multiplica la gente corriente) y 50–150 con cuerpo alrededor,
  a 60 FPS. `game/tests/paseo.gd [multiplica]` lo mide.
- `game/editor/` — diseñador de personajes (`editor_personajes.gd`): formulario, muñeco
  (`muneco.gd`), mapa para zona y rutina (`mapa_zona.gd`) y catálogo de tipos base (`tipos.gd`)
- `game/scripts/personajes.gd` — formato de los personajes del diseñador, compartido por el
  editor y el juego (`World._spawn_personajes`, `Npc.init_personaje`, `Fichas.of_npc`)
- `game/shaders/silhouette.gdshader` — silueta de los personajes a través de los edificios (stencil)
- `game/tests/smoke.gd` — ejecuta todas las acciones con los 6 perfiles, cada sustancia,
  los extremos de hambre, sueño y salud mental, los encargos con la libreta, el género de los personajes,
  los iconos de encargo, las misiones del editor (y su pestaña), y la visión, la memoria, el escándalo, los camellos y los turistas
  que te reconocen; termina con `OK` o el número de fallos:
  `godot --headless --path game --script res://tests/smoke.gd`
- `game/tests/charla.gd` — conversación real con la IA sin abrir el juego (necesita Ollama):
  `godot --headless --path game --script res://tests/charla.gd -- latero "Hola" "¿Viene la Urbana?"`
- `game/tests/retratos.gd` — captura de los perfiles (o de los bots de un tipo, o `todos`) en fila
  y de cerca, para revisar género y rasgos: `godot --path game --script res://tests/retratos.gd -- out.png todos`
- `game/tests/conos.gd` — captura de los conos de visión y de un escándalo:
  `godot --path game --resolution 1600x900 --script res://tests/conos.gd -- out.png [hora]`
- `game/tests/minijuego.gd` — captura de un minijuego a medias:
  `godot --path game --resolution 1600x900 --script res://tests/minijuego.gd -- out.png robo|movil|vigia|aguador|pelea [hora] [sustancias]`
- `game/tests/editor_captura.gd` — captura de cada pestaña del diseñador de personajes:
  `godot --path game --resolution 1600x900 --script res://tests/editor_captura.gd -- out.png [id]`
- `game/tests/hud_captura.gd` — captura del mapa del barrio o de la pausa:
  `godot --path game --resolution 1600x900 --script res://tests/hud_captura.gd -- out.png mapa|pausa [rótulo]`
- `game/tests/screenshot.gd` — capturas sin abrir el editor; el sexto argumento consume
  sustancias antes (p. ej. `... -- res://scenes/world.tscn shot.png parado "" 12 caballo,litrona`)

Al exportar el juego, añade `*.json` al filtro de recursos que no son de Godot
para que se incluyan los datos de `game/data/`.

Mapa © OpenStreetMap contributors (ODbL). Datos de incidentes: Ajuntament de Barcelona (CC BY 4.0).
