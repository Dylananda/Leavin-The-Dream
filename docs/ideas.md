# Yonkiland — ideas y hoja de ruta

Documento vivo: aquí se apuntan las ideas a medida que surgen, se ordenan y se marca
qué está decidido, qué está en debate y qué está hecho.

## Visión (provisional)

Vida de yonki en una ciudad real (empezando por el Raval), construida con datos abiertos
(mapa de OpenStreetMap, estadísticas de criminalidad, prensa sobre el barrio) y poblada
por personajes que conversan con el jugador mediante una IA local. Se progresa hablando
con la gente y cumpliendo (o no) compromisos con plazo, mientras las drogas distorsionan
lo que ves, recuerdas y sabes. Objetivo de partida: caer lo más bajo posible sin morir
antes de tiempo (pendiente de concretar).

**Pregunta abierta clave:** ¿qué consigues hablando con la gente? Las conversaciones solo
interesan si cambian algo en la partida (pistas, tratos, sitios marcados, enemistades).

## Hoja de ruta propuesta

1. **Mapa fiel** — hecho (rama `fix/mapa-calles-edificios`)
   - [x] Aceras sin bloques de relleno; esquinas achaflanadas en manzanas sin mapear
   - [x] Descargar los 546 edificios con patio interior (multipolígonos) que faltaban
   - [x] Recuperar las calles frontera (Rambla, Paral·lel, Rondas) que la descarga perdía
   - [x] Trazado de calles fiel (Carrer de Lancaster y similares, ya conectadas)
   - [x] Medianeras y paredes de patio ciegas (sin ventanas sueltas sobre los tejados)
   - [ ] Pendiente de valorar: con el barrio completo, desde la cámara se ven sobre todo
     tejados; quizá bajar más la altura de los edificios (`LEVEL_SCALE`)
2. **Estado del personaje** (barras y efectos de las sustancias) — siguiente
3. **Personajes nuevos** basados en lo que se documenta del barrio, según hora y zona
4. **Prototipo de conversación con IA local** (Ollama, 3–4 personajes)
5. **Compromisos con plazo y memoria poco fiable** → base de las misiones
6. **Ciudad más grande y metro**

## 2. Estado del personaje

- Barras nuevas:
  - **Hambre**
  - **Discreción** (cuánto llamas la atención; quizá unificar con la de Policía actual)
- **Una barra por sustancia con dos indicadores: consumo (colocón) y mono.**
  - Aparecen a medida que el personaje conoce cada sustancia; según el perfil, algunas
    vienen ya activas desde el principio (y con mono si procede).
  - Conocer una sustancia nueva es un hito de la caída.
- **Cada sustancia afecta a la cámara y al movimiento** de forma distinta, y el mono también:
  - Caballo: la cámara oscila (ya existe) y vas lento.
  - Ideas por desarrollar: farlopa → aceleras y la cámara tiembla; porro → todo más lento
    y con zoom; alcohol → andas haciendo eses y tarda en responder; pastillas → colores
    saturados; base → euforia corta y bajón brusco.
  - Mono: temblor de cámara, viñeta, torpeza al andar.
- **Sueño**: muy afectada por el consumo y, claro, por dormir.
- **Salud mental**: afectada por las experiencias, la dignidad, el consumo...
- Las barras deben explicar por qué la cámara y el movimiento cambian.
- **El núcleo del juego podría ser este malabarismo**: buscarse la vida para mantener un
  equilibrio casi imposible entre las barras. Los desequilibrios fuertes llevan a situaciones
  cada vez más difíciles: detenciones largas, ingresos en el psiquiátrico, lesiones por peleas...

## Personajes que viven (y relevo)

- **Al perder a tu personaje** (muerte, ingreso, cárcel) pasas a ser otro de los yonkis con
  los que has tratado.
- Los perfiles que no eliges al empezar también están en el juego como NPCs y van
  evolucionando por su cuenta de formas variopintas.
- Los demás personajes tienen su propio desarrollo con el tiempo.
- **Los turistas se van** al cabo de unos días (a Hannah ya le has robado la cartera varias veces).
- **Reputación por barrio**: la gente te conoce por lo que has hecho con ella y por tu fama
  (o mala fama) en cada zona.

## 3. Personajes nuevos (basados en fuentes reales)

Investigar en prensa y estudios sobre el barrio y anotar las fuentes. Personajes con
nombre, historia y motivos, no estereotipos por nacionalidad.

- Gente de fiesta por la noche (despedidas, guiris, after hours)
- Lateros que venden cerveza por la calle y esconden el alijo en alcantarillas o portales
- Carteristas y trileros en la Rambla
- Chavales que esnifan cola por las calles del Raval
- (más por investigar)

## 4. Conversación con IA local

- Motor: Ollama en el propio PC (GTX 1060 de 6 GB → modelos de 3–8 mil millones de parámetros).
  Diseñado para poder cambiar a un modelo en la nube si el local se queda corto.
- Cada personaje tiene una ficha: personalidad, forma de hablar, qué sabe y qué no, qué quiere.
- Memoria corta de lo hablado con cada uno.
- La IA puede hacer cosas en el juego: dar una pista, marcar un sitio, ofrecer un trato,
  enfadarse, llamar a la policía...
- Entre todos los personajes van tejiendo una historia.

## 5. Compromisos con plazo y memoria poco fiable

- Situaciones que compiten entre sí: llevarle un pedido a un camello a cambio de una parte
  *y a la vez* las fiestas de otro barrio a las que va a ir una yonki que te gusta. Hay que elegir.
- Muchas a la vez, y no te acuerdas bien de todas.
- **Log de conversaciones** además del inventario, pero según lo que te hayas metido algunas
  entradas se difuminan, desaparecen o se alteran.
- **El HUD también miente** según el estado: hora, fecha, nombres de calles y otros datos
  se vuelven borrosos o engañosos. Vida de yonki que no sabe ni en qué día vive.

## 6. Ciudad más grande y metro

- Pasar de un barrio a varios (o a toda la ciudad).
- **Metro**: opinión — vale la pena *cuando haya más de un barrio*; antes no aporta.
  Forma razonable de hacerlo: cada barrio es una zona que se carga por separado y el metro
  es el viaje entre zonas (estaciones reales de OSM, el viaje cuesta tiempo y dinero o
  colarse, con eventos dentro: revisores, carteristas, gente durmiendo). Evita cargar la
  ciudad entera a la vez y da sentido a los plazos.

## Más adelante

- Misiones largas e intrincadas
- Minijuegos para dar variedad
- Concretar la idea central y el objetivo final

## Juegos de referencia

- *Hobo: Tough Life* — supervivencia como sin techo en una ciudad
- *Cart Life* — vida diaria de gente pobre con negocios callejeros
- *Disco Elysium* — rol de conversación en un barrio degradado
- *Generative Agents* (Stanford, 2023) — pueblo simulado con personajes de IA
- *Vaudeville*, *Suck Up!*, mod *Mantella* de Skyrim — NPCs con IA conversacional
