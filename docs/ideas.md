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

**Hacia dónde va (1 de noviembre de 2026, provisional):** ahora mismo es «un Pacman con más
miga, y más birra»: supervivencia de recursos (pasta → sustancia → evitar el mono y a la poli).
La dirección elegida para crecer es la del punto 5: **encargos con plazo que compiten entre
sí y una memoria poco fiable**, que puede ir creciendo hacia misiones de rol encadenadas.
- La IA en vivo queda aparcada (ver punto 4): el modelo local da poco y los de la nube cuestan
  dinero. Los diálogos y encargos se escriben con ayuda de Claude *mientras se hace el juego*
  y quedan fijos, sin coste ni esperas. Se mantiene la idea de que el juego propone lo que
  puede pasar y los personajes solo eligen y lo cuentan.
- **Partidas largas, no cortas:** a un yonki se le puede mantener mucho tiempo, hasta dejar
  un **legado** a los siguientes (ver «Personajes que viven (y relevo)»).
- **Finales posibles** a largo plazo: los yonkis montan una **revolución**, o un **partido
  político**. Otras direcciones que se valoraron: rol de conversación escrita a mano (estilo
  Disco Elysium), partidas cortas rejugables y retrato documental del barrio.

## Hoja de ruta propuesta

1. **Mapa fiel** — hecho (rama `fix/mapa-calles-edificios`)
   - [x] Aceras sin bloques de relleno; esquinas achaflanadas en manzanas sin mapear
   - [x] Descargar los 546 edificios con patio interior (multipolígonos) que faltaban
   - [x] Recuperar las calles frontera (Rambla, Paral·lel, Rondas) que la descarga perdía
   - [x] Trazado de calles fiel (Carrer de Lancaster y similares, ya conectadas)
   - [x] Medianeras y paredes de patio ciegas (sin ventanas sueltas sobre los tejados)
   - [ ] Pendiente de valorar: con el barrio completo, desde la cámara se ven sobre todo
     tejados; quizá bajar más la altura de los edificios (`LEVEL_SCALE`)
2. **Estado del personaje** (barras y efectos de las sustancias) — hecho lo básico (rama `feat/estado-personaje`)
3. **Personajes nuevos** basados en lo que se documenta del barrio, según hora y zona — hecho lo básico (rama `feat/personajes-nuevos`)
4. **Prototipo de conversación con IA local** (Ollama, 3–4 personajes) — hecho el prototipo (rama `feat/conversacion-ia`)
5. **Compromisos con plazo y memoria poco fiable** → base de las misiones
6. **Ciudad más grande y metro**

## 2. Estado del personaje

- [x] Barras nuevas:
  - [x] **Hambre**: sube con las horas (el porro la acelera; farlopa y base la frenan). Al 100, desmayo y urgencias.
  - [x] **Discreción**: unificada con la de Policía (es su inverso). Motivo: las dos medían
    lo mismo para el jugador ("cuánto me mira la poli") y dos barras casi iguales estorban
    en el malabarismo. Lo nuevo es que tu aspecto (colocón a la vista, mono, mala pinta,
    hablar solo) pone un suelo a lo que llamas la atención, por debajo del umbral de
    persecución: basta un pequeño desliz para que vayan a por ti. Vacía, te ven desde lejos.
- [x] **Una barra por sustancia con dos indicadores: consumo (colocón) y mono** (más el enganche en cifra).
  - [x] Aparecen a medida que el personaje conoce cada sustancia; según el perfil, algunas
    vienen ya activas desde el principio (y con mono si procede).
  - [x] Conocer una sustancia nueva es un hito de la caída.
- [x] **Cada sustancia afecta a la cámara y al movimiento** de forma distinta, y el mono también:
  - [x] Caballo: la cámara oscila y vas lento (y te entra sueño).
  - [x] Farlopa → aceleras y la cámara tiembla; porro → el tiempo se estira y la cámara se
    acerca; alcohol → eses (también andando por clic), respuesta con retraso y visión doble;
    pastillas → colores saturados; base → euforia corta (brillo, velocidad) y bajón brusco.
  - [x] Mono: temblor de cámara, viñeta roja, tropiezos.
- [x] **Sueño**: muy afectado por el consumo (caballo y alcohol dan sueño; con farlopa o base
  no pegas ojo) y por dónde duermes (albergue > cajero > banco > suelo). Al 100 te quedas frito en la calle.
- [x] **Salud mental**: baja al perder dignidad, con mono, hambre, sueño y bajones; sube con
  trato humano y descanso. Por debajo de 30 oyes voces; por debajo de 15 estallas (gritos,
  peleas); a 0, ingreso de dos días en el psiquiátrico (al tercero, o al segundo de Mari Loli, no sales).
  Las pastillas de Mari Loli son su medicación: le suben la salud mental.
- [x] Las barras explican por qué la cámara y el movimiento cambian: lista de efectos activos
  con su causa en el panel de sustancias, etiquetas en rojo en zona de peligro y explicación al pasar el ratón.
- [ ] Pendiente: probar y ajustar el equilibrio jugando de verdad; que los extremos lleven a
  situaciones más elaboradas (lesiones que duran, detenciones largas, peleas con bots reales).
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
- **Legado**: lo que hace un yonki (contactos, deudas, fama, escondites, encargos a medias)
  pasa al siguiente. Con el tiempo, la comunidad yonki puede organizarse: de ahí los finales
  de la revolución o el partido político.
- **Contagio**: los yonkis NPC pueden enganchar a otros NPC y convertirlos en yonkis. Cuantos
  más yonkis hay, menos resaltas: una forma de ganar dignidad (o discreción) es que el barrio
  se llene de gente como tú.

## 3. Personajes nuevos (basados en fuentes reales)

Investigar en prensa y estudios sobre el barrio y anotar las fuentes. Personajes con
nombre, historia y motivos, no estereotipos por nacionalidad.

- [x] **Horarios y zonas**: cada tipo de bot tiene sus horas (`hours` en `Npc.KINDS`) y su
  zona (`zone`: la Rambla, la Rambla del Raval y Sant Pau, o junto a los bares). Fuera de
  su horario se van cuando no los ves. Los vecinos salen de 7 a 23 y las educadoras de calle de 9 a 21.
- [x] Cada personaje nuevo tiene nombre e historia («Escuchar su historia»).
- [x] **Despedidas de soltero** (22–5 h, junto a los bares): piden poco y dan mucho, te puedes unir
  a la juerga, venderles gafas de mantero o robarles el móvil (si te pillan, paliza de grupo).
  Las rutas de borrachera están prohibidas en Ciutat Vella desde 2012, pero siguen viniendo.
  Fuentes: [Ara](https://es.ara.cat/sociedad/barcelona/noche-rutas-borrachera-prohibidas-barcelona-vegas-bro_130_5466856.html),
  [The Local](https://www.thelocal.es/20250307/barcelona-keeps-banning-pub-crawls-but-is-it-really-working),
  [betevé](https://beteve.cat/politica/barcelona-endurira-lluita-contra-ruta-turisme-borratxera/).
- [x] **Lateros** (20–5 h, junto a los bares): latas a 1 €; puedes ayudarles a esconder el
  alijo en una alcantarilla (y luego robárselo, con lo que te ganas un enemigo) o avisarles
  de que viene la Urbana. Fuentes: [eldiario.es](https://www.eldiario.es/catalunya/xavier-trias-reconoce-obsesion-lateros_1_5782404.html)
  (más de 700.000 latas requisadas), [Libertad Digital](https://www.libertaddigital.com/opinion/2009-12-18/david-jimenez-torres-lateros-5121488/) (las alcantarillas).
- [x] **Trileros** (10–20 h, en la Rambla): apostar es perder (casi siempre); se gana algo
  haciendo de gancho o de vigía. Fuentes: [betevé](https://beteve.cat/societat/mes-pressio-de-la-guardia-urbana-contra-els-trilers-a-la-rambla/),
  [betevé, plan inspector](https://beteve.cat/societat/el-pla-inspector-de-la-rambla-nescombra-els-trilers-i-multa-mig-miler-de-motoristes/).
- [x] **Carteristas** (9–21 h, en la Rambla): parecen turistas hasta que hablas con ellos
  (`disguise`). Vacían por su cuenta los bolsillos de los guiris cercanos (luego a ti ya no te
  queda nada que robarles); puedes hacerles de pantalla, pagarles para que te enseñen
  (robas mejor a los turistas) o venderles carteras. Fuentes: [3Cat](https://www.3cat.cat/3catinfo/100-carteristes-actuen-cada-dia-al-metro-i-alguns-els-han-enxampat-fins-a-1000-cops/noticia/2935115/),
  [NacióDigital](https://naciodigital.cat/societat/identificada-394-vegades-detinguda-27-i-denunciada-45-.html).
- [x] **Chavales que esnifan cola** (15–3 h, Rambla del Raval y Sant Pau): menores; solo se les
  puede ayudar (darles comida o un euro, llevarles con una educadora de calle cercana) o
  preguntarles por la Urbana, nunca aprovecharse de ellos. Fuentes: [3Cat](https://www.3cat.cat/3catinfo/preocupacio-per-menors-que-esnifen-cola-des-de-fa-mesos-al-centre-de-barcelona/noticia/2726885/),
  [eldiario.es](https://www.eldiario.es/catalunya/barcelona/jovenes-migrados-inhalan-plataforma-vecinal_1_3482411.html),
  [betevé](https://beteve.cat/societat/ciutat-vella-nens-cola-dgaia-pla-pilot/).
- [ ] Pendiente: las fuentes son en buena parte de hace años; comprobar cómo está hoy cada fenómeno.
- [ ] Pendiente: que la policía requise latas y desmonte mesas de trile por su cuenta; grupos de
  despedida que se muevan juntos; más personajes (after hours, narcopisos, aluminosis...).

## 4. Conversación con IA local

- [x] Motor: Ollama en el propio PC (GTX 1060 de 6 GB → modelos de 3–8 mil millones de parámetros;
  por defecto `qwen2.5:7b`, que habla buen castellano y respeta el formato JSON).
  Se puede cambiar de modelo o pasar a uno en la nube (API compatible con OpenAI) con
  `user://ia.cfg` (ver `scripts/ai/llm_client.gd`). Las peticiones no bloquean el juego y,
  si la IA no responde, se avisa en el registro y todo lo demás sigue igual.
- [x] Prototipo con 4 personajes: **lateros**, **trileros**, **carteristas** y **despedidas**
  («Hablar» en su menú). Cada tipo tiene su ficha (`scripts/ai/fichas.gd`): quién es, su
  historia (la de su nombre en `Npc.KINDS`), cómo habla, qué no sabe, qué quiere y qué datos
  de la partida conoce.
- [x] **El juego propone y la IA habla.** En cada frase el juego calcula lo que puede pasar de
  verdad, con un id para cada cosa, y el esquema de la respuesta solo admite esos ids:
  - **ofrecer** una de las acciones de su menú (`interactions.gd`): vender una lata, hacerle
    de gancho, enseñarte el oficio... Sale un botón y, si lo aceptas, se hace la acción de
    siempre, con sus precios y consecuencias. Nunca inventa tratos ni cifras.
  - **contar** un dato cierto: dónde están ahora los agentes (y si no hay ninguno), o qué
    guiris sin robar hay cerca y por dónde (trileros y carteristas). Se apunta en el registro.
  - **señalar** el sitio más cercano de cada tipo (bar, comisaría, CAS...): se marca en el mapa.
  - **reaccionar**: enfadarse (no vuelve a hablarte), llamar a la policía (sube mucho la
    búsqueda) o despedirse.
- [x] Memoria corta de lo hablado con cada uno (12 frases) y de lo que ha pasado de verdad (lo
  que te ofreció, lo que hicisteis, lo que te contó); se le dice que no hay nada más, para que
  no se invente encargos pasados. Se acuerda de ti si vuelve a salir alguien con su nombre.
- Lo aprendido con `qwen2.5:7b` en la GTX 1060 (13–18 s por respuesta):
  - Dejando que la IA inventara los tratos (cifras, objetos, minutos), salían disparates: un
    trilero vendiendo latas, «vigilar una hora (15 min)», encargos que nunca se hicieron.
    Con opciones cerradas por el juego, lo que ofrece siempre encaja.
  - Si los campos son opcionales, ofrece cosas de palabra sin apuntarlas: todos son obligatorios
    (con "" para «nada»). Nombres ambiguos («policia») los usaba para hablar de la policía.
  - Sigue escribiendo regular (repite los datos al pie de la letra, se inventa detalles
    sueltos) y tarda. Un modelo en la nube lo haría mucho mejor: el cliente ya habla con
    Claude por la API de Anthropic (`proveedor="anthropic"` en `ia.cfg`, con structured
    outputs para el esquema, esfuerzo bajo y reintento con otro modelo si lo rechazan los
    filtros). Pendiente: probarlo con una clave y comparar con el local.
- [ ] Pendiente: más personajes con ficha (camellos, educadoras, chavales: con estos, solo ayudar).
- [ ] Pendiente: que las pistas sirvan de algo más (p. ej. un log de conversaciones para el punto 5)
  y que los tratos tengan consecuencias más allá del momento (deudas, encargos con plazo).
- [ ] Pendiente: que lo que se cuentan entre ellos circule (si te chivas de uno, los demás lo saben).
- [ ] Entre todos los personajes van tejiendo una historia.

## 5. Compromisos con plazo y memoria poco fiable (siguiente paso)

Primer paso propuesto: una prueba jugable con tres o cuatro encargos de personajes que ya
existen, con plazos que se pisan, y una libreta que se emborrona según lo que te metes.

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
