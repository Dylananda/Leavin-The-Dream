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
5. **Compromisos con plazo y memoria poco fiable** → base de las misiones — hecha la primera prueba jugable (rama `feat/encargos`)
6. **Ver y moverse bien** (lo que salió de la primera partida de verdad, ver «7. Lo que sale de
   jugar»): encontrar a los personajes aunque estén tras los edificios, que cada uno se
   distinga (género, rasgos) y que el muñeco se maneje bien por calles que no siguen la
   cuadrícula. Va primero porque sin esto lo demás no se puede jugar. — hecho (rama `feat/ver-y-moverse`)
7. **Personajes que recuerdan y ven**: memoria de lo que has hecho con cada uno, visión en
   cono tapada por los edificios, escándalos al robar y una policía que solo te persigue si
   te ve. — hecho lo básico (rama `feat/recuerdan-y-ven`)
8. **Trapicheo**: comprar y vender a más personajes, no solo a los camellos.
9. **Minijuegos de habilidad** para las acciones (robar, distinguir a la gente).
10. **Ciudad más grande y metro**
11. **Diseñador de personajes**: herramienta aparte para crear personajes únicos con su
    historia, aspecto, zona, rutina, estadísticas, ficha de IA y misiones, que el juego carga
    solo. — hecha la fase 1 (rama `feat/editor-personajes`)
    - [x] Fase 1: identidad, aspecto con el muñeco, zona (barrio, zona hecha o polígono),
      casa y lugares con horas, estadísticas, ficha de conversación y frases; el juego los
      saca a la calle y se puede hablar con ellos; botón «Probar en el juego»
    - [ ] Que el juego use lo que se guarda y aún no usa (◌): fuerza en las peleas, valor,
      agresividad, si llama a la policía, qué quiere, qué lleva y qué vende
    - [ ] Fase 2: misiones en el editor (condiciones, objetivo con los encargos y minijuegos
      que ya hay, plazo y resultados al cumplir o fallar)
    - [ ] Fase 3: relaciones entre personajes y esquema de las cadenas de misiones

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
- [x] Que la policía requise latas y desmonte mesas de trile por su cuenta: hecho (la ronda de la
  Urbana y de los Mossos, rama `feat/policia-y-fauna`, ver abajo).
- [ ] Pendiente: grupos de despedida que se muevan juntos (los free tours ya lo hacen); más
  personajes (after hours, narcopisos, aluminosis...).

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

## 5. Compromisos con plazo y memoria poco fiable

Primera prueba jugable hecha (rama `feat/encargos`, `game/scripts/errands.gd`; el equilibrio
está en `Defs.ERRANDS` y en las constantes de memoria de `defs.gd`):

- [x] **Cuatro encargos de personajes que ya existen**, que se aceptan en su menú («Encargo: ...»)
  y se cumplen en el menú de un lugar real del mapa. El sitio se elige lejos de los otros
  encargos en marcha, así que los plazos (una hora de juego son 30 s) se pisan:
  - Camello: llevar un paquete a un bar antes de 1 h 30 → 25 € y una raya. Si no llegas, le
    debes 40 €. Si lo abres, te quedas dos rayas y le debes 60 €.
  - Carterista: dejar una cartera caliente en un compraventa antes de 1 h → 20 €. Si no, da tu
    descripción a la Urbana (−40 de discreción) y ya no trata contigo.
  - Despedida: llevarlos de fiesta a un bar de 1 h a 2 h más tarde → 40 € y una lata (si llegas
    pronto, puedes esperar). Si no apareces, solo pierdes la ocasión.
  - Educadora: cita al día siguiente de 10 a 11 en el CAS Baluard → dignidad, salud mental,
    menos mono y un bocadillo. Choca con dormir y con la resaca; plantarla duele.
- [x] **Libreta** (tecla L): una entrada por encargo, con quién, qué, dónde y cuándo, y un botón
  para marcar en el mapa el sitio *apuntado*. Es fiable casi siempre: los fallos son
  ocasionales y su probabilidad crece con lo ido que vas (`GameState.befuddlement()`:
  colocón, mono, sueño y salud mental baja). Puede fallar de tres maneras:
  - Al apuntar (3 % sereno, hasta un 48 % del todo ido): con caballo, pastillas o sueño se te
    escapa la hora o el sitio («¿?»); con farlopa, base o la cabeza mal lo apuntas cambiado
    (otra hora u otro sitio del mismo tipo) sin ninguna marca de duda.
  - Con las horas, ido, se borra a veces algún dato de lo que llevas apuntado.
  - Al leer, muy ido, algunas palabras no se distinguen (borrosas o, con mono, temblando).
- [x] **El reloj del HUD miente** a ratos cuando vas ido: con porro se atrasa, con farlopa o base
  se adelanta, y con mono o sueño fuertes a veces ni lo lees («Día ? · --:--»).
- [ ] Pendiente: que el **log de conversaciones** se apunte también en la libreta (pistas de
  los personajes, tratos) y se degrade igual.
- [ ] Pendiente: que mientan también los nombres de calles y otros datos del HUD.
- [ ] Pendiente: más encargos, también encadenados (misiones de rol), y otras situaciones que
  compitan entre sí: las fiestas de otro barrio a las que va a ir una yonki que te gusta.
- [ ] Pendiente: que los encargos a medias, las deudas y las enemistades pasen al siguiente
  yonki (legado).
- [ ] Pendiente: jugarlo y ajustar plazos, premios y probabilidades.

## 6. Ciudad más grande y metro

- Pasar de un barrio a varios (o a toda la ciudad).
- **Metro**: opinión — vale la pena *cuando haya más de un barrio*; antes no aporta.
  Forma razonable de hacerlo: cada barrio es una zona que se carga por separado y el metro
  es el viaje entre zonas (estaciones reales de OSM, el viaje cuesta tiempo y dinero o
  colarse, con eventos dentro: revisores, carteristas, gente durmiendo). Evita cargar la
  ciudad entera a la vez y da sentido a los plazos.

## 7. Lo que sale de jugar (1 de noviembre de 2026)

Primera partida de verdad con los encargos. Problemas y propuestas, en el orden de la hoja
de ruta:

**Ver y moverse (punto 6 de la hoja de ruta)**
- [x] **Encontrar a los personajes** es muy difícil: casi todos se parecen y quedan tapados
  por los edificios en la vista isométrica. Hecho:
  - Siluetas a través de las paredes (`shaders/silhouette.gdshader`): las piezas de cada
    personaje marcan el stencil y una pasada sin prueba de profundidad pinta su silueta solo
    donde algo lo tapa. Tú en amarillo, quien tiene un encargo para ti en su color, la policía
    en azul y el resto en blanco tenue.
  - Icono flotante: «!» sobre quien te puede dar un encargo ahora (los carteristas
    disfrazados no se delatan hasta que les hablas) y «★» sobre quien te dio uno en marcha.
  - Flechas en el borde de la pantalla (o un triángulo encima, si se ve) hacia el sitio de cada
    encargo en marcha, con su nombre y la distancia. Llevan al sitio **apuntado en la libreta**:
    si lo apuntaste mal, te llevan al sitio equivocado; si se borró, no hay flecha.
- [x] **Género y rasgos**: ahora Mari Loli es un señor calvo. Hecho: el género sale del nombre
  (`women` y `either` en `Npc.KINDS`; los nombres que no lo dicen, como «Agente Puig», «Pecas»
  o «La Sombra», se echan a suertes, pero siempre igual para ese nombre). Las mujeres tienen
  otro talle, pelo largo más a menudo y a veces falda; todos tienen peinado (corto, rapado,
  calvo, tupé, rizos, coleta, melena, moño, media melena), barba o bigote, gafas y chaqueta
  según tiradas que dependen del nombre: el mismo personaje sale siempre igual, para que lo
  reconozcas. Algunos tienen rasgos fijos por su historia (`looks`: la peluca rosa de Dani, la
  americana de Don Ramón...). Etiquetas en femenino (Vecina, Educadora social, Trilera).
  Los perfiles del jugador también (`look` en `Defs.PROFILES`). `tests/retratos.gd` saca a
  todos en fila para revisarlos.
  - [ ] Pendiente: forma de andar propia; más variedad de cuerpos (edad, altura, gordura).
- [x] **Moverse con WASD** choca con las paredes porque las calles no siguen las direcciones
  de las teclas y no se ven bien. Hecho: si de frente hay pared, el muñeco sigue la dirección
  libre más parecida a la pedida (hasta 70° a cada lado; `Actor._steer`), así que toma la
  calle en vez de pararse; si aun así roza, se desliza por la pared. Los rayos X se agrandan al
  andar con WASD. La cámara no gira sola (decidido: las teclas siempre significan lo mismo en
  pantalla; Q/E para girarla). Las eses del alcohol desvían la dirección *antes* de buscar la
  calle, así que siguen notándose. En 120 recorridos al azar, el muñeco se atasca en 3 (antes,
  15) y anda de media 28 m en 2 s (antes, 20).
  - [ ] Pendiente: jugarlo y ver si hace falta bajar los edificios cercanos además de los rayos X.

**Personajes que recuerdan y ven (punto 7)**
- [x] **Memoria por personaje** de lo que ha pasado contigo: si le has pedido, se aparta al
  verte; si le has robado, busca a un policía; si le has ayudado, se acerca. Hecho:
  `Npc.memory` cuenta las veces que le has pedido, robado, ayudado o pegado (lo apuntan las
  acciones de `interactions.gd`) y `Npc.grudge()` decide qué hace al verte. Pedirle dos veces
  (`Defs.BEG_ANNOY`) o pegarle hace que se aparte; ayudarle (compartir, dar comida, vigilar,
  esconder el alijo...), que se acerque a saludarte; robarle, que vaya a por ti o a por un
  agente. Los que viven de la calle no van con cuentos a la policía: se apartan.
- [x] **Visión en cono** para los personajes y la policía, de un largo y un ancho dados y
  tapada por los edificios, como en *Commandos*. Hecho: policía 14 casillas (28 m) y 70°; el
  resto, 10 casillas y 90°; de noche, un 28 % menos; con la discreción vacía, ×1,5; a 2
  casillas te notan aunque estés a su espalda (`Defs.VISION` y siguientes). La línea de visión
  se traza sobre la cuadrícula (`CityMap.line_of_sight`). Miran hacia donde andan y, parados,
  giran la cabeza. Mientras te ven se llena la sospecha («?» amarillo, más rápido de cerca) y,
  llena, reaccionan («!» rojo y silueta roja). Los conos se dibujan en el suelo recortados por
  las paredes: los de la policía y los de quien sospecha o va a por ti, y con **V** los de
  todos los cercanos (azul tranquilo, amarillo sospecha, rojo persecución). Consumir a la vista
  y las probabilidades de los robos dependen de qué agentes te ven, no de cuántos hay cerca.
- [x] **Escándalo al robar**: si te pillan, la víctima grita; algunos transeúntes intentan
  pararte y otros no; varios llaman a la policía. Si lo oye un agente cercano, te persigue;
  si no, quedas fichado y te buscan más tarde. Pero solo te persiguen si te ven. Hecho
  (`World.scandal`): una onda roja muestra hasta dónde llega el grito (20 casillas). Cada
  transeúnte tiene un carácter fijo por nombre (`Npc.temper()`): el valiente corre a pararte
  y, si te alcanza, te agarra 1,5 s; otro llama a la policía (llega al agente más cercano a
  60 casillas); el resto pasa. Si te pillan robando, o un testigo te ve robar, hay escándalo;
  si nadie lo ve, la víctima quizá se da cuenta al rato y se queda con tu cara. Si no viene
  ningún agente, quedas **FICHADO** un día (en el HUD); también si te escapas de una
  persecución: el agente que te pierde de vista va al último sitio donde te vio, busca y se
  rinde. La policía solo te persigue si te ve y estás fichado o muy buscado (`heat` > 40).
- [x] **Camellos a los que debes dinero**: si te ven, te persiguen y te roban o se pelean
  contigo. Hecho: lo fiado te da 12 horas (`Defs.DEBT_GRACE_HOURS`); el paquete que no
  llega, ninguna. Si te alcanza, se cobra lo que lleves; si no llevas nada, paliza.
- [x] **Turistas robados que te reconocen**: algunos van a por ti para recuperar lo suyo;
  otros buscan a un policía. Hecho: van a por ti el 60 % de los hombres y el 30 % de las
  mujeres (más en las despedidas), siempre los mismos; si te alcanzan te quitan la cartera o
  el móvil, o dinero, o te dan un puñetazo. Los demás van hasta el agente más cercano, se lo
  cuentan y quedas fichado.
  - [ ] Pendiente: jugarlo y ajustar medidas y tiempos; que la memoria pase a los que vuelven
    a salir con el mismo nombre. Peleas de verdad (minijuego `Fight`): hecho para la pelea
    con un yonki y las palizas del camello y del de la esquina (rama `feat/minijuegos`).

**Más gente y más variada** (rama `feat/mas-gente`)
- [x] Niños (en las plazas, de 9 a 21), abuelos y abuelas (con bastón, lentos), perros que van
  con su dueño (vecinos, abuelos, yonkis y pijos), repartidores y gente con pasta. Cada uno con
  sus acciones: jugar a la pelota (si tienes mala pinta, una madre se los lleva), ayudar con la
  compra, robarle el monedero a una abuela (minijuego), acariciar o dar de comer a un perro,
  pedirle un pedido cancelado a un repartidor o robárselo, pedirle a un pijo o robarle
  (minijuego, más difícil que a un guiri). Los pijos compran farlopa y porros (trapicheo).
  Gracias a la optimización (rama `feat/optimiza-bots`), unos 225 bots a mediodía a 60 FPS.
  Fuentes:
  - Repartidores que alquilan la cuenta de otro, a menudo sin papeles: [Ara](https://es.ara.cat/economia/tecnologia/gran-problema-riders-papeles_1_5220622.html),
    [Qué!](https://www.que.es/2024/02/05/glovo-inmigrantes-ilegales/), [El Salto](https://www.elsaltodiario.com/repartidores/ley-rider-no-funcionando-repartidores-organizan-huelgas-critican-irregularidades-glovo).
  - Fondos que compran bloques del Raval y vecinos mayores que resisten: [El Salto, Hospital 99](https://www.elsaltodiario.com/barcelona/el-raval-planta-cara-a-blackstone-para-defender-el-bloque-hospital-99),
    [Ara](https://es.ara.cat/economia/inmobiliario/veintena-vecinos-seis-fincas-barcelona-pie-guerra-fondo-quiere-colojamientos_1_5410764.html).
  - Residentes temporales, expats y alquiler de temporada en el Raval: [Papers (UAB)](https://ddd.uab.cat/pub/papers/papers_a2024v109n3/papers_a2024v109n3ae2353.info),
    [Ara](https://es.ara.cat/economia/efecto-expat-vivienda-alquileres-caros-temporales_1_4809421.amp.html).
  - [ ] Pendiente: que los niños vayan con un adulto; repartidores en bici; que los perros
    ladren al que les cae mal; jugarlo y ajustar cuántos hay de cada.

**Policía dividida: Guàrdia Urbana y Mossos d'Esquadra** (rama `feat/policia-y-fauna`)
- [x] El tipo `policia` se separa en dos cuerpos con sus competencias (`Npc.POLICE`,
  `Defs.CRIME_CORPS`), cada uno con su uniforme (la gorra con la banda de cuadros blancos de la
  Urbana, la roja de los Mossos) y agentes de paisano:
  - `urbano` (Guàrdia Urbana, policía local): convivencia y ordenanza. Si te ve dormir en la
    calle, en un banco o en un cajero te despierta con la linterna y te echa (`World.urbana_wakes`;
    dormir en un rincón escondido, con poca calle alrededor, es mucho más seguro). Multa por
    beber en la calle (`Defs.FINE_DRINKING`), requisa las latas a los lateros, la manta a los
    manteros y la mesa a los trileros en su ronda (`World.police_event`), y es la que viene si
    haces de vigía del mantero o del trilero. No lleva las drogas: si te chivas de un camello,
    te manda a los Mossos. Si te alcanza por la ordenanza, te multa; si te buscaban por un
    delito, te retiene y llama a los Mossos.
  - `mosso` (Mossos d'Esquadra, policía de la Generalitat): delitos y orden público. Peleas y
    robos con violencia, tráfico de drogas (la redada cuando haces de aguador del camello, el
    chivatazo), detenciones y comisaría.
  - `urbano_secreta`: de paisano, vestido de guiri por la Rambla (y el metro de Liceu) a por los
    carteristas; se lleva a alguno en `World.pickpocket_event`. `mosso_secreta`: de paisano,
    como un vecino más, por Robadors y Sant Ramon, a por los camellos. Parecen lo que no son
    (`disguise`) hasta que actúan: hablarles no los descubre, intentar robarles o venderles sí.
    En el minijuego del vigía, las secretas son de la Urbana o de los Mossos según para quién vigiles.
  - Fichado: se apunta por qué (`GameState.wanted_crime`) y solo te persigue el cuerpo al que le
    toca (por civismo la Urbana, por drogas o violencia los Mossos, por hurto los dos); si lo que
    pasa es que llamas mucho la atención (heat alto), cualquiera. La llamada de un escándalo llega
    al agente más cercano del cuerpo que toca; quien lo ve en flagrante interviene sea del que sea.
  - Hitos nuevos: primera multa, que la Urbana te despierte en la calle.
  - Fuentes: la Urbana no tiene competencias de orden público, que son de los Mossos
    ([betevé](https://beteve.cat/politica/ciutadans-pp-guardia-urbana-aldarulls/)); funciones de la
    Urbana: tráfico, convivencia, incivismo ([Equinox](https://www.equinoxmagazine.fr/2024/10/19/polices-differentes-en-espagne/));
    la ordenanza de convivencia de 2026 y sus multas por beber en la calle (de 30 a 100 €, más si
    molesta o hay menores) ([Ara](https://es.ara.cat/sociedad/barcelona/claves-nueva-ordenanza-convivencia-barcelona_1_5649264.html),
    [NacióDigital](https://naciodigital.cat/societat/la-lletra-petita-de-les-noves-multes-a-barcelona-anar-sense-samarreta-pagar-un-massatge-o-beure-al-carrer.html),
    [Barcelona Secreta](https://barcelonasecreta.com/multas-ordenanza-civismo-barcelona/));
    un tercio de las denuncias de la primera semana fueron por beber ([Ara](https://es.ara.cat/sociedad/barcelona/claves-nueva-ordenanza-convivencia-barcelona_1_5649264.html)).
    La unidad de paisano de la Urbana que detiene a captadores y carteristas en la Rambla:
    [3Cat](https://www.3cat.cat/3catinfo/preocupacio-a-ciutat-vella-per-la-presencia-de-captadors-de-clubs-cannabics/noticia/3254458/),
    [betevé](https://beteve.cat/societat/operacio-contra-captadors-associacions-cannabiques/).
  - [ ] Pendiente: comprobar con el texto oficial de la ordenanza qué sanciona cada cuerpo (las
    cifras de las multas varían según el medio); que los Mossos vayan en pareja; la comisaría de
    los Mossos frente a la de la Urbana en el mapa; que la Urbana pida el permiso a músicos y
    estatuas; jugarlo y ajustar `Defs.SLEEP_WAKE` y las rondas.

**Fauna de la calle** (rama `feat/policia-y-fauna`). Once tipos nuevos, con nombres, historias,
zona, horario, frases, sus acciones y ficha para hablar con ellos (menos la estatua). Los
identificadores (`musico`, `estatua`, `mendigo`, `skater`, `captador`, `rosero`, `chatarrero`,
`trabajadora_sexual`, `guia`, `caricaturista`, `punki`) son los mismos que usa el editor de
personajes como tipo base. Zonas nuevas en `World.ZONE_STREETS` y `World.ZONE_LANDMARKS`
(calles de OpenStreetMap y edificios con rótulo del mapa, sin datos nuevos).
- [x] **Músicos callejeros** (10–23 h): un punto fijo cada uno (la Rambla, las plazas del Pi y
  de Sant Josep Oriol, la puerta del Liceu, el MACBA, el CCCB). Echarles un euro, escucharles (calma
  el mono) o pasar la gorra. Fuentes: el programa Música al Carrer del ICUB, con puntos de
  actuación por toda la ciudad ([Ajuntament](https://www.barcelona.cat/barcelonacultura/en/recomanem/call-proposals-musica-carrer));
  la asociación de músicos de calle y de metro AMUC y la prueba para tener licencia ([Diari de Tarragona](https://www.diaridetarragona.com/reus/192255/reus-segueix-sense-regular-els-musics-de-carrer-i-els-artistes-abandonen-la-ciutat-ni22198207.html)).
- [x] **Estatuas humanas** (10–20 h, en el tramo de abajo de la Rambla, junto a Colom): quietas,
  sin girar la cabeza (`still`), hasta que les echas una moneda; se les puede intentar hacer
  reír o robarles el platillo. Fuentes: el traslado al tramo de abajo ([Catalan News](https://www.catalannews.com/life-style/item/human-statues-will-move-to-the-lowest-part-of-barcelonas-rambla)),
  las licencias por concurso y su queja ([betevé](https://beteve.cat/societat/les-estatues-de-la-rambla-volen-que-es-revisin-les-llicencies-i-demanen-tornar-on-eren-abans/)),
  el decreto de 2019 ([BOPB](https://bcnroc.ajuntament.barcelona.cat/jspui/bitstream/11703/112540/5/BOPB_2019_estatues_humanes.pdf)).
- [x] **Sin techo** (`mendigo`, a todas horas): piden en la puerta de una iglesia o un súper y de
  noche se van a su sitio (`bed`): un cajero o un portal escondido. Compartir comida, un euro,
  pedir a su lado o preguntarles dónde se puede dormir sin que te levante la Urbana. Fuentes: el
  recuento de Arrels (al menos 1.384 personas durmiendo en la calle en 2023, algunas en cajeros)
  y las muertes en la calle ([Ara](https://es.ara.cat/sociedad/emergencia-social/cuatro-horas-peinando-calles-barcelona-personas-duermen-raso_130_5582284.html),
  [Ara](https://es.ara.cat/sociedad/84-personas-hogar-murieron-calles-barcelona-pasado-ano_1_5251011.amp.html)).
- [x] **Skaters del MACBA** (12–22 h, plaça dels Àngels): mirarles, pedirles el skate (te la
  pegas o no) o un cigarro. Fuentes: la plaza como meca mundial del skate ([betevé](https://beteve.cat/societat/placa-macba-meca-skaters-arreu-mon-no-volem-perdre/)),
  la prohibición de patinar de 22 a 9 h por el ruido ([Catalan News](https://www.catalannews.com/life-style/item/barcelona-s-world-famous-unofficial-skate-park-faces-controversial-nighttime-curfew)),
  la reforma para acabar con el «monopolio» de los skaters ([3Cat](https://www.3cat.cat/3catinfo/la-nova-placa-dels-angels-de-barcelona-vol-posar-fi-al-monopoli-dels-skaters/noticia/3280065/)).
- [x] **Captadores** (17–3 h, en la Rambla): discotecas, rutas de bares y clubs cannábicos.
  Ayudarles a repartir flyers (pagan según los guiris que haya cerca) o que te lleven al club
  (dos porros; si te ve la Urbana, te ficha). Fuentes: captadores cada 200 metros y la Urbana
  de paisano que los detiene ([3Cat](https://www.3cat.cat/3catinfo/preocupacio-a-ciutat-vella-per-la-presencia-de-captadors-de-clubs-cannabics/noticia/3254458/)),
  el cierre de 30 clubs en 2024 ([Ara](https://es.ara.cat/sociedad/barcelona/barcelona-ordena-cerrar-30-clubs-cannabicos_1_5084612.html)),
  las rutas de bares prohibidas (ver las despedidas, arriba).
- [x] **Roseros** (20–3 h, por los bares y las terrazas): comprarles una rosa o preguntarles qué
  bar cierra tarde. Fuentes: la Urbana decomisa las rosas de los vendedores sin licencia y multa
  por encima de 150 € ([betevé](https://beteve.cat/economia/floristes-critiquen-intrusisme-sant-jordi-2026-menys-venda-roses-prevista/)).
  - [ ] Pendiente: buscar fuentes sobre la venta de rosas de noche por los bares (lo encontrado es de Sant Jordi).
- [x] **Chatarreros** (7–22 h, por todo el barrio), con su carro de supermercado: venderles la
  chatarra o el cobre sin ir al compraventa, o ayudarles a empujar. Fuentes: los asentamientos de
  chatarreros del Poblenou y su papel en el reciclaje ([Público](https://www.publico.es/especiales/el-quinze/malvivir-chatarra-barcelona.html)),
  el desalojo de las naves en 2013 ([La Marea](https://lamarea.com/2013/07/25/300-persones-se-quedan-sin-casa-despues-del-desalojo-de-dos-fabricas-en-poblenou),
  [La Marea](https://lamarea.com/2013/08/07/los-desalojados-de-la-nave-de-poblenou-no-logran-el-arraigo-prometido)).
- [x] **Trabajadoras sexuales** (11–5 h, calle d'en Robador, Sant Ramon y Sant Pau): darles
  conversación, preguntarles por los camellos o avisarles de que viene la Urbana. Nunca un
  servicio: se las trata como a vecinas que saben mucho de la calle. Fuentes: la ordenanza que
  multa ofrecer servicios en la calle y la organización de las trabajadoras ([eldiario.es](https://www.eldiario.es/catalunya/solo-queremos-dejen-trabajar_1_5717565.html),
  [eldiario.es](https://www.eldiario.es/catalunya/prostitutas-barcelona-organizan_1_5709876.amp.html)),
  el estigma usado para justificar la reforma urbana del barrio ([Quaderns-e, UAB](https://ddd.uab.cat/pub/artpub/2012/157746/quaderns-e_a2012v17n2p82.pdf)),
  las amenazas y el acoso de 2016 ([NacióDigital](https://naciodigital.cat/societat/les-prostitutes-del-raval-es-queixen-duna-onada-damenaces-i-assetjament.html)),
  los pisos precintados en Robadors ([betevé](https://beteve.cat/societat/precintats-set-pisos-al-raval-que-presumptament-funcionaven-com-a-prostibuls-il%C2%B7legals/)).
- [x] **Guías de free tour** (10–19 h, desde la Rambla) con su grupo de 4 a 8 turistas detrás
  (`World._spawn_follower`, como los perros): pegarte al grupo o pedirle. Fuentes: grupos de
  15 como máximo y sin megáfono en Ciutat Vella ([NacióDigital](https://naciodigital.cat/societat/grups-de-maxim-15-turistes-i-sense-megafon-barcelona-vol-reduir-limpacte-al-centre_251100_102.html)),
  los free tours, en un vacío legal ([Ara](https://en.ara.cat/society/one-way-system-barcelona-old-town-tourist-groups-good-practices-limits_1_4410574.html)),
  el decreto prorrogado hasta 2028 ([Ajuntament](https://ajuntament.barcelona.cat/turisme/en/noticia/el-decret-de-limitacio-de-grups-turistics-a-ciutat-vella-es-prorroga-un-any-mes_1308739)).
  - [ ] Pendiente: confirmar con una fuente que las plataformas de free tours cobran a los guías por turista.
- [x] **Caricaturistas** (10–20 h, la Rambla y las plazas del Pi y de Sant Josep Oriol): que te
  hagan una caricatura o posar de modelo. Fuentes: la Mostra de Pintors, Caricaturistes i
  Retratistes de les Rambles ([Ajuntament](https://www.barcelona.cat/barcelonacultura/en/detail/99400322599)),
  la normativa de la Mostra d'Art de Sant Josep Oriol ([Ajuntament](https://bcnroc.ajuntament.barcelona.cat/jspui/bitstream/11703/86394/1/normregpap_2015.pdf)).
- [x] **Punkis con perros** (11–4 h, en las plazas): llevan siempre un perro y a menudo dos
  (`DOG_OWNERS` por encima de 1). Compartir el litro (si te ve la Urbana, multa), pedirles un
  cigarro o dar de comer a los perros. Que los albergues no admitan perros es una de las razones
  por las que hay quien prefiere la calle.
  - [ ] Pendiente: buscar fuentes sobre los albergues y los perros en Barcelona.

**Trapicheo (punto 8)**
- [x] Un sistema de tráfico: comprar y vender a más personajes (yonkis, fiesteros, turistas,
  vecinos...), con precios, riesgo y clientes que se acuerdan de ti. Hecho (rama
  `feat/trapicheo`, `scripts/trade.gd`; equilibrio en `Defs.CLIENTS` y lo que le sigue): lo que
  compras al camello se revende en el menú de cada cliente. Las despedidas pagan el doble por
  farlopa, porros o pastillas; los guiris, el triple por un porro, pero alguno (un 7 %, fijo por
  nombre) es un secreta y acabas en el calabozo; los yonkis, poco y solo por lo barato. Solo
  compra quien lleva bastante dinero. Los clientes se acuerdan: pagan un 10 % más por cada
  compra (hasta un 30 %) y se te acercan al verte («¿Tienes algo?»). **Cortarla** da más de media
  (la mitad de las veces no gastas la dosis), pero el cliente lo nota: no te vuelve a comprar y
  las despedidas van a por ti. Vender a la vista de un agente sube mucho la búsqueda; de un
  vecino o un guiri, un poco; y si te ve un camello, le has pisado la esquina: te persigue y
  se queda con tu mercancía (o con tu dinero, o te pega).
- [x] **Trapichear con otros yonkis** para conseguir sustancias: cambiar objetos, favores o
  dinero. Hecho: cada yonki lleva encima una o dos dosis de algo (siempre lo mismo para el mismo
  nombre, se repone cada día) y te lo cambia por tus objetos, que valora un 50 % por encima de lo
  que paga el compraventa. Si le cuelas una piedra, se da cuenta y no te lo perdona.
  - [ ] Pendiente: favores (vigilar mientras pilla, guardarte algo), que los yonkis también te
    vendan fiado y que los vecinos (algunos) también compren; jugarlo y ajustar precios.
- [x] **Objetos por la calle** con los que trapichear (cables, móviles, bicis, cosas tiradas).
  Se ven poco y, si vas colocado o borracho, se confunden: lo que parecía un móvil es una
  piedra, o pasas de largo de algo que valía la pena. Hecho (rama `feat/objetos-calle`,
  `scripts/street_items.gd`; equilibrio en `Defs.STREET_ITEMS`): 45 cosas tiradas a la vez,
  casi todo basura; móviles y carteras perdidos a la salida de los bares (más de noche), cable
  de obra, chatarra, sobras junto a los kebabs, bicis y patinetes mal atados (tardan en soltarse
  y, si te ve un vecino o un agente, sube la búsqueda). Los pequeños destellan de vez en cuando.
  Ido, una tirada fija por objeto decide si lo confundes: la basura parece un móvil, una cartera
  o un cable y te la guardas (en el inventario sale como tal: `GameState.fakes`), o un móvil
  parece basura. Las piedras se descubren al venderlas en el compraventa (hito), al vaciar la
  «cartera» o al volver a estar sereno. Lo que nadie recoge desaparece a las 10 h.
  - [ ] Pendiente: más compradores (otros yonkis, chatarreros) y que los dueños de las bicis
    las reconozcan; que la bici sirva para moverse más rápido.

**Minijuegos (punto 9)**
- [x] Las acciones de habilidad pasan a un minijuego con otra vista (primer plano del
  personaje en plano medio) y otros controles. Robar a un turista: una mano con WASD le
  distrae y la otra, con el ratón, le saca la cartera mientras no mira. Hecho
  (`Pickpocket`, rama `feat/minijuegos`) para la cartera del guiri y el móvil de la
  despedida: la víctima es una marioneta con su mismo aspecto en una vista 3D propia; la
  probabilidad de antes es ahora la dificultad (y, sin pantalla, la tirada de siempre).
- [x] Tiro de feria: pasan personajes variados y hay que distinguir a policías, secretas,
  camellos, vecinos y posibles compradores. Hecho como el trabajo de vigía (`Lookout`) del
  mantero, el trilero y el camello: clic izquierdo a los agentes, derecho a los clientes;
  las secretas se delatan por el pinganillo.
- [x] Peleas como minijuego (`Fight`): esquivar con A/D el puño que se ve venir y pegar
    cuando se queda abierto. Con un yonki y cuando te alcanzan para darte una paliza.
  - [ ] Pendiente: jugarlos y ajustar tiempos y dificultad; más acciones (robar la litrona,
    el platito de propinas, el alijo del latero; el puñetazo del turista robado).

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
