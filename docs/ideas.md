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
    solo. — hechas las fases 1 (rama `feat/editor-personajes`), 2 (misiones) y 3 (relaciones y cadenas)
    - [x] Fase 1: identidad, aspecto con el muñeco, zona (barrio, zona hecha o polígono),
      casa y lugares con horas, estadísticas, ficha de conversación y frases; el juego los
      saca a la calle y se puede hablar con ellos; botón «Probar en el juego»
    - [x] El juego usa las estadísticas (`Npc.stat`, `Defs.STAT_*`): la fuerza en las peleas,
      el valor y la agresividad en cómo reacciona (enfrentarse, ir a por ti), si siempre llama
      a la policía; qué quiere (te lo compra), qué lleva (lo cambia) y qué vende (se lo compras)
    - [x] Perros del editor con su dueño («Va con»): salen y se duermen con él
    - [x] Fase 2: misiones en el editor (`scripts/misiones.gd`, pestaña «Misiones y notas»).
      Cada personaje guarda las suyas: **condiciones** (horas, desde qué día, dignidad mínima,
      después de qué otra misión, repetible), **objetivo** con lo que ya hay (llevar algo a un
      sitio o a otro personaje, conseguirle algo, una cita mañana, convencer a alguien con
      pruebas o mintiendo, y los minijuegos de robar, vigilar y pelear), **plazo** y
      **resultados** al cumplirla o fallarla (dinero, objetos, deudas con plazo o ya, saldar lo
      que le debes, favores, amigo o enemigo, dignidad, mente, salud, búsqueda, fichado).
      En la partida es un encargo más: se apunta (mal) en la libreta, vence, ancla al que la da
      en el censo y lleva la «!» y la «★» (también el otro personaje del objetivo).
      - Favores: curarte una vez al día, contarte por dónde anda la policía y, la policía, hacer
        la vista gorda (no te persigue, no te multa, no te despierta) unos días.
      - «Le debes» en las estadísticas: lo que debes a un personaje al empezar; se le paga en su
        menú y una misión lo puede saldar.
      - Hechas: **«El paquete para Txell»** (Quique te da un paquete para Txell, a la que debes
        40 €: si se lo llevas, se lo queda por tu deuda, te cura cuando lo necesites y Quique te
        lo cobra a ti; si no llega o lo abres, Quique viene a cobrar 60 €) y **«El cajero de
        Antonio»** (convencer a la agente Mas de que Antonio tiene plaza en el albergue: con los
        papeles de la cita en el CAS, seguro; mintiendo, según tu dignidad y tu cabeza, y si no
        cuela te ficha. Si sale bien, hace la vista gorda tres días y Antonio te cuenta lo que ve).
      - [ ] Pendiente: pasar a misiones las demás notas de los personajes de ejemplo; probarlas
        jugando y ajustar plazos y premios; capturas de la pestaña en el PC (en la nube no hay pantalla).
    - [x] Fase 3: relaciones entre personajes y esquema de las cadenas de misiones
      - **Relaciones** (pestaña «Relaciones», `scripts/relaciones.gd`): se lleva bien o mal con,
        familia, pareja, trabaja para, le debe dinero a. Valen en los dos sentidos. Lo que le haces
        a uno (ayudarle, robarle, pegarle, timarle, chivarte) lo saben los suyos y, al revés, sus
        enemigos (`oido_bien` y `oido_mal` en su memoria, también latentes): se acercan a
        saludarte, se apartan o, los de mala sangre, van a por ti, y no te dan misiones.
      - **Esquema de misiones** (pestaña nueva, `editor/esquema.gd`): una caja por misión de todos
        los personajes, en columnas por «después de», con flechas para las cadenas, líneas rojas
        entre las excluyentes y amarillas entre las que comparten personajes, y lo que pasa al
        cumplirla o fallarla. Clic en una caja: abre su personaje.
      - Lo nuevo en las misiones: condición «si no has hecho» (elegir entre dos), objetivos
        **espiar** (consigues algo; si te pillan, falla) y **acompañar** (va contigo hasta el
        sitio; alguien os puede acechar), y en «conseguirle algo», **quién lo tiene** (te lo vende o
        se lo robas, minijuego) y **a qué policía chivarte** (se lo quita, te lo da y al otro lo
        detienen dos días). Resultados nuevos: lo detienen (sale del barrio unos días o para
        siempre; los suyos se enteran), va a por ti, y el riesgo de ir a comisaría con antecedentes.
      - Hechas, cruzadas entre ellas: **el pasaporte de Grzegorz** (lo tiene Vera: comprarlo,
        robarlo o chivarte a Xavi), **el acordeón de Vasile** (El Mudo, amigo de Vera: si te chivaste
        de ella, ya no te lo vende), **«Que Joy no trabaje sola»** (Rosi, vigilar) → **«La denuncia
        de Joy»** → **«Testigo en comisaría»** (Agent Ortega), **el Sr. Feliu o Pol** (una u otra;
        traicionar a Feliu te cierra a la Sra. Encarna), **las pruebas del piso** (espiar a Quique
        para la Sra. Encarna) → **«El piso de Quique»** (Serra lo detiene, tu deuda se va y La
        Rubia va a por ti) y **«El bar de 1979»** (acompañar a Margit; Vera os acecha si no está detenida).
      - [ ] Pendiente: que el acordeón pueda acabar en la compraventa; la multa que te borra Xavi;
        la bolsa de Mari Carmen; capturas de las pestañas nuevas en el PC; jugarlas y ajustar.
12. **Bots latentes (censo)**: todos los del barrio en un registro de datos y cuerpo solo para
    los que tienes cerca; al volver a verlos se ponen al día. — hecho lo básico (rama `feat/editor-personajes`)
    - [x] Dormir y despertar según la distancia, con lo que les pasó; no se duermen los que
      tienen asuntos contigo; olvidan con el tiempo (el rencor, más despacio)
    - [x] Medido: 2.600 en el censo a 60 FPS (unos 40–60 con cuerpo alrededor)
    - [x] Más población: unos 1.400 en el censo a mediodía (`Defs.CROWD`: sobre todo vecinos,
      abuelos, niños y turistas; la policía y los camellos no cambian), 60 FPS estables
    - [x] Montar un cuerpo cuesta unos 3 ms: al llegar a una zona llena se notaba algún tirón.
      Hecho: las mallas se guardan por aspecto (`Actor._mesh_cache`) y los bots repetidos
      salen casi gratis. Con el triple de gente (unos 4.200 en el censo, hasta 370 con
      cuerpo), 60 FPS; el repaso del censo, 1,5–4 ms.
    - [x] «Despertadores»: el que tiene que cobrarte (deuda vencida) viene a buscarte aunque
      esté latente o lejos: aparece fuera de la vista y va hacia ti (`Censo.despertadores`,
      `Npc.come_for`); si no pagas, vuelve cada `Defs.DEBT_VISIT_EVERY` horas. Las deudas ya
      no tienen al acreedor siempre con cuerpo.
    - [x] Guardar el censo en la partida guardada (hecho con las partidas guardadas, abajo)
13. **Partidas guardadas** — hecho (`scripts/partida.gd`)
    - [x] Un archivo JSON por partida en `user://partidas/`, con número de versión y una cabecera
      legible (perfil, día, hora, cuándo se guardó, si sigue viva); los datos van con sus tipos
      (`JSON.from_native`). Se guarda todo `GameState` por nombre de campo (`Partida.CAMPOS`):
      al cargar se empieza una partida nueva del mismo perfil y se ponen los campos que haya,
      así que añadir campos no rompe las partidas viejas (se quedan como en una nueva).
    - [x] El censo entero, con lo que recuerda cada uno y lo que consume, también los personajes
      del editor (por su id); los que tienen cuerpo, como si se durmieran (`Censo.foto`). Los
      encargos y misiones en marcha vuelven con quien te los dio; la libreta, con sus encargos.
    - [x] Lo hablado con la IA, dónde estás y si vas en bici.
    - [x] Se guarda sola al dormir y al empezar un día; a mano, «Guardar la partida» en la pausa.
      En el menú de inicio, «Continuar» carga la última que sigue viva (al acabar una partida
      queda como terminada).
    - [ ] Pendiente: elegir entre varias partidas guardadas y borrarlas; guardar los objetos de
      la calle y los marcadores de los sitios; el relevo y el legado (otro yonki con lo que dejó
      el anterior) tirarán de aquí.

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

### La partida como una historia de relevos (hablado el 4 de noviembre de 2026)

- [x] **Relevo en cada final**: al acabar con un yonki (muera, entre en prisión, se redima...)
  sigues con otro, y el anterior se queda en el mundo: su tumba, su celda con visitas, la
  pareja con la que se fue o su leyenda en los free tours. Es la forma de avanzar del juego.
  Hecho, primer paso (`World.relevo`, `Defs.RELEVO_*` y `Defs.DESTINOS`):
  - La pantalla final ofrece seguir con uno de los perfiles que aún no han salido; pasan de
    2 a 5 días en el mismo barrio y la misma partida guardada. Lo tuyo empieza de cero; el
    censo, los clubs precintados y los detenidos de las misiones se quedan.
  - Cada final dice qué fue del yonki (`GameState.destino`) y se apunta en `GameState.historia`.
    Si murió, deja un **altar** en la calle (cartón, velas, flores y una litrona): leer el
    cartón, encenderle una vela o coger las monedas de entre las flores (hito). La leyenda se
    queda en su portal como yonki y el redimido, de vecino limpio; los dos cuentan su historia.
  - Quien le conocía se acuerda de él (amigo, enemigo o conocido) y se le puede preguntar
    («Preguntarle por Paco»), pero a ti no te conoce: sin memoria, sin deudas, sin rencor.
  - La pantalla final lista a los de antes.
  - [ ] Pendiente: visitas a la cárcel y al psiquiátrico; que se pueda repetir perfil cuando
    se acaben (otro «Paco» distinto); legado (contactos, escondites, deudas que heredas);
    que el de antes salga en las conversaciones con IA; jugarlo y ajustar.
- [x] **La ciudad se vuelve más yonki con el tiempo**: en cada relevo, unos cuantos de la gente
  corriente se han enganchado (pasan a ser yonkis con su aspecto de siempre, y lo cuentan),
  hay un 15 % más de yonkis por la calle y todos los bots tienen algo más de enganche.
  - [x] También día a día: cada día, a veces, alguien más se engancha y corre el rumor
    (`Defs.CONTAGIO_DIARIO`, más probable con cada relevo).
  - [ ] Pendiente: que se note quién engancha a quién (ver «Contagio»), y el camino de vuelta.
- [x] **Un propósito para cada yonki**, más allá de pasar un día más. Ideas por valorar:
  Youssef, mandar dinero a casa y conseguir los papeles; Paco, recuperar a su hija o
  pagar una deuda vieja; Don Ramón, que los nietos vuelvan a llamar o dejar algo en herencia;
  Jordi, ver al perro o volver con ella (o vengarse); Mari Loli, que las voces callen o
  encontrar a alguien del psiquiátrico; Borja, demostrar a papá que es alguien (o lo contrario).
  Cumplirlo podría ser otro final, o lo que se lleva el siguiente.
  Hecho, primer paso (`scripts/proposito.gd`, `Defs.PROPOSITOS` y `Defs.PROPOSITO_*`): uno por
  perfil, en tres pasos de cuatro tipos (mandar dinero desde un sitio, ir a un sitio a ciertas
  horas, a veces sereno; tener algo; aguantar unos días seguidos con una barra o sin colocarte
  de algo o sin que te fichen):
  - Youssef: mandar 150 € a casa (el Western Union o un cajero), ir dos días a la asesoría de
    extranjería a por el informe de arraigo y pasar tres días sin que te fichen. Se pierde con
    otra detención.
  - Paco: tres días sin emborracharse, ingresar 100 € de la pensión de Laia y comer con ella en
    un kebab, sereno (si llega colocado, se acabó). Se pierde si la dignidad toca fondo.
  - Don Ramón: un móvil que funcione, 60 € para el cumpleaños de su nieto y dos días con la
    dignidad alta. Si baja mucho, los nietos dejan de llamar.
  - Jordi: la pensión atrasada, tres días dignos y sin fichar, y ver a Kira en una terraza. Se
    pierde con otra detención.
  - Mari Loli: la psiquiatra del CAP, tres días con la mente bien y dos tardes en el grupo de
    apoyo. Se pierde con otro ingreso.
  - Borja: decirle a papá que no le pase más la paga, cuatro días por su cuenta (con algo de
    dinero y dignidad) y cenar con papá, sereno.
  Sale en la libreta (arriba, con su progreso), en el registro al avanzar y al empezar. Cada
  paso baja la caída y sube la dignidad y la mente: lo que te acerca a lo tuyo te aleja del
  fondo. Cumplirlo es un final («CUMPLIDO», destino `cumplido`: se queda de vecino y deja
  relevo) y queda en `GameState.historia`; perderlo para siempre es un hito.
  - [ ] Pendiente: que los pasos tengan más que ver con la gente del barrio (personajes del
    editor, misiones); que el siguiente yonki herede algo del propósito del de antes; un segundo
    propósito «oscuro» por perfil (vengarse, hundirse a propósito); jugarlo y ajustar.
- [x] **Amistades y enemistades entre los NPC**, por lo que se hacen, lo que ven y lo que les
  cuentan, con **niveles de fama**; de ahí pueden salir **bandas**.
  Hecho, primer paso:
  - **Entre bots** (`scripts/vinculos.gd`, `Defs.VINCULO*`): cada registro del censo tiene un
    número fijo (`uid`) y sus amistades y enemistades (de -100 a 100, como mucho seis, que se
    olvidan con los días). Se hacen enemigos al pelearse (las peleas de yonkis), al robarse (el
    carterista al que pilla el guiri) o al darse el tirón (un yonki con mono y sin dinero a otro
    que lleva algo); amigos, al pasarse una dosis cuando el otro está fatal. Lo que le hacen a
    uno lo saben sus amigos. Al cruzarse, los enemigos discuten (y a veces se pegan) y los
    amigos se saludan y van juntos un rato. Se guardan en el censo y siguen tras un relevo.
  - **Tu fama por zonas** (`scripts/fama.gd`, `Defs.FAMA_*`): cuadrados de 80 m con fama buena
    (ayudar) y mala (robar, pegar, timar), más cuanta más gente te ve; cada día corre a las
    zonas de al lado y se va olvidando. Quien no te conoce te trata según tu fama: con mala te
    evita y, con muy mala, los camellos no te venden ni los clientes te compran; con buena, los
    de la calle vienen a pedirte y alguien te avisa cuando viene la policía. Sale en la libreta.
  - **El de antes**: al relevo, su fama se va con él (a la historia) y quien vive donde la tenía
    se acuerda de él de oídas («Preguntarle por Paco»: «dicen que robaba a quien podía»).
  - [ ] Pendiente: que se vean las amistades (grupos que andan juntos), venganzas entre bots que
    duran, que los amigos de un bot que has ayudado te defiendan; jugarlo y ajustar.
  - **Bandas** (por hacer, ideas): con las amistades ya hay grupos; una banda sería un grupo de
    tres o más que son amigos entre sí (sobre todo yonkis, carteristas, camellos) con un
    cabecilla (el de más fama o más fuerza) y una zona (donde duermen o venden). Se defenderían
    entre ellos (al pegar a uno van todos), tendrían enemistades con otras bandas por las
    esquinas y la mercancía, harían cosas juntos (robos con pantalla, vigilar al camello) y
    podrías entrar en una (te piden algo para fiarse: una misión) o enfrentarte a ella. Con el
    tiempo, una banda de yonkis organizada es el camino hacia el final de la revolución.
- [x] **Sucesos de la historia del barrio**: llega el fentanilo, redadas fuertes de la
  policía, fiestas de barrio, manifestaciones, obras que cortan calles.
  Hecho, primer paso (`scripts/sucesos.gd`, `Defs.SUCESOS` y lo que le sigue): cada día se
  mira si acaba alguno y si empieza otro, por fecha (hay calendario: el día 1 es el 10 de julio,
  `Defs.CALENDARIO_INICIO`) o al azar; duran días. Se anuncian en el registro, corren como
  rumor en la libreta y en lo que dice la gente al pasar, y la IA de las conversaciones lo sabe.
  Se guardan en la partida y sobreviven al relevo (son del barrio).
  - **Llega el fentanilo**: parches baratísimos con riesgo de sobredosis en cada dosis; el
    caballo puede venir cortado sin avisar; los bots que se meten opiáceos caen (delante de ti
    se les puede salvar con naloxona o llamando al 112, que llega tarde a menudo) y cada día
    aparece alguno muerto en un portal; las educadoras reparten naloxona, que te salva a ti.
  - **Redadas fuertes**: el triple de Urbana y Mossos (y más de paisano), la mayoría de los
    camellos se esconden y la droga sale un 60 % más cara.
  - **Fiesta Mayor del Raval** (17 de julio, cuatro días): más turistas, vecinos, niños,
    músicos, despedidas y roseros, y la gente de fiesta da más.
  - **Obras**: un tramo de una calle vallado unos días (casillas que no se pueden pisar,
    `CityMap.bloquear`, y vallas rojas y blancas).
  - [ ] Pendiente: manifestaciones; que la Fiesta Mayor tenga gigantes, conciertos y mesas en la
    calle de verdad (ahora es más gente); que cada suceso cambie más cosas (precios por zona,
    sitios cerrados); comprobar la fecha real de la Fiesta Mayor del Raval y buscar fuentes
    sobre el fentanilo en Barcelona; capturas de las vallas en el PC; jugarlo y ajustar.
- [x] **Empezar más enganchados** (4 de noviembre): todos los perfiles empiezan con más
  enganche y algo más de lo de siempre (tabaco, ansiolíticos; en `Defs.PROFILES`, `knows`).
- El tono: **denuncia de situaciones reales con humor**, que sale de mostrar las cosas como son
  o suelen ser; los estereotipos tienen su parte de verdad, pero cada personaje tiene nombre,
  historia y motivos.

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
- [x] Más personajes con ficha: camellos, yonkis, educadoras, chavales, vecinos, abuelos, manteros,
  repartidores, pijos, turistas, estatuas, Urbana y Mossos (y sus secretas, que fingen ser lo que
  parecen). Se puede hablar con la IA con 29 tipos; los niños y los perros, no.
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
- [x] Hecho: las **pistas** de las conversaciones (lo que te cuentan y los sitios que te
  señalan) se apuntan en la libreta, caducan a las `Defs.PISTA_HOURS` y se leen peor ido.
- [ ] Pendiente: que el **log de conversaciones** se apunte también en la libreta (pistas de
  los personajes, tratos) y se degrade igual.
- [x] La placa de la calle también miente cuando vas ido (`Defs.STREET_LIE`).
- [x] Muy ido, el dinero del HUD es una cuenta a ojo («¿unos 45?», `Defs.MONEY_LIE*`).
- [ ] Pendiente: que mientan otros datos del HUD.
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
  - [x] Más variedad de cuerpos: complexión (delgados y gruesos, con barriga) y algo de altura
    (`Defs.BUILD_*`, `HEIGHT_RANGE`; `Actor.BUILDS`).
  - [ ] Pendiente: forma de andar propia.
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
  - [x] Niños con un adulto (algunos vecinos y abuelos, `Defs.KIDS_WITH`) y despedidas en
    grupo (`Defs.PARTY_GROUP`).
  - [x] Repartidores en bici (tres de cada cuatro, `Defs.RIDER_BIKE`).
  - [ ] Pendiente: que los perros
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
  - [x] Comprobado (3 de noviembre de 2026), sin el texto oficial del BOPB:
    - **Dormir en la calle**: no he encontrado que la ordenanza de 2026 lo multe. Lo documentado
      es que se ha denunciado a la Urbana por levantar y multar a gente sin hogar con la excusa
      de la limpieza ([Ara](https://es.ara.cat/sociedad/emergencia-social/guardia-urbana-robado-tienda-campana-vivo-cinco-veces-anos_1_5059654.html)).
      El juego ya hace eso: te despierta y te echa, sin multa.
    - **Drogas en la calle**: en la práctica actúan los dos cuerpos juntos. La Urbana tiene su
      propio plan contra el menudeo (Plan Druida) y las operaciones contra narcopisos son conjuntas,
      con la investigación en manos de los Mossos ([betevé](https://beteve.cat/societat/7-detinguts-punt-venda-drogues-consum-raval/),
      [El Debate, 2026](https://www.eldebate.com/espana/cataluna/barcelona/20260804/barcelona-aumenta-presion-policial-contra-menudeo-droga-calle-preocupante_446629.html)).
      En el juego, cualquier agente que te vea vender interviene, pero fichado por drogas solo te
      persiguen los Mossos (`Defs.CRIME_CORPS`). Decidido (3 de noviembre): ahora te persiguen
      los dos cuerpos.
    - La ordenanza nueva entró en vigor en febrero de 2026 y se centra en beber y orinar en la
      calle ([Ara](https://es.ara.cat/sociedad/barcelona/claves-nueva-ordenanza-convivencia-barcelona_1_5649264.html)).

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
  - [x] **Asociaciones cannábicas en el mapa** (4 de noviembre de 2026): 16 clubs, sitio `club`.
    OSM no tiene ninguno (solo tres tiendas de CBD); las direcciones son las de los directorios
    ([coffeeshopdirect](https://www.coffeeshopdirect.com/barcelona/BarcaPcode.html),
    [cannabisinbarcelona](https://cannabisinbarcelona.com/club/carme-66-barcelona/)), situadas con
    Nominatim, en `tools/clubs_cannabicos.json` (`build_map.py` las añade); los nombres, inventados.
    No hizo falta inventar direcciones: la densidad cuadra con los 37 clubs de Ciutat Vella en 2019
    ([Metrópoli Abierta](https://metropoliabierta.elespanol.com/el-pulso-de-la-ciudad/20191020/barcelona-tiene-clubs-cannabicos/438206230_0.html))
    y los cierres de 2024 ([Ara](https://es.ara.cat/sociedad/barcelona/barcelona-ordena-cerrar-30-clubs-cannabicos_1_5084612.html)).
    Sin rótulo: son una puerta más hasta que llamas o te lleva un captador (te hace socio del
    más cercano). Socio con la cuota y un aval (o el captador), con dignidad mínima; venden con
    tope diario, dentro fumas sin que te vea la policía y, a veces, redada: te identifican, se
    llevan lo que llevas y precintan el local unos días (`Defs.CLUB_*`, precios en el diseñador).
    - [ ] Pendiente: verlos por dentro (ahora es un menú en la puerta), socios con cuerpo
      que entran y salen, que los porreros del barrio te digan dónde hay uno, y precintos
      que también lleguen sin que estés tú (el Ayuntamiento cerrando clubs).
- [x] **Roseros** (20–3 h, por los bares y las terrazas): comprarles una rosa o preguntarles qué
  bar cierra tarde. Fuentes: la Urbana decomisa las rosas de los vendedores sin licencia y multa
  por encima de 150 € ([betevé](https://beteve.cat/economia/floristes-critiquen-intrusisme-sant-jordi-2026-menys-venda-roses-prevista/)).
  - [ ] Pendiente: buscar fuentes sobre la venta de rosas de noche por los bares (lo encontrado es de Sant Jordi).
    Buscado otra vez el 3 de noviembre de 2026: sigue sin salir nada concreto de la venta
    nocturna; solo Sant Jordi y que los vendedores de la calle se surten en Mercabarna-flor
    ([betevé](https://beteve.cat/economia/floristes-critiquen-intrusisme-sant-jordi-2026-menys-venda-roses-prevista/),
    en un comentario de lector, no verificado). Habría que buscar en hemeroteca o preguntar en el barrio.
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
  - [x] Las plataformas de free tours cobran comisiones a los guías, no a los turistas, y quien
    paga sale mejor colocado y recibe más clientes
    ([Hosteltur, 2019, sobre GuruWalk](https://www.hosteltur.com/133244_guruwalk-startup-espanola-de-free-tours-capta-1-m-de-inversores.html)).
    Que sea una cantidad fija por turista (se habla de unos 2 €) solo aparece en un comentario de
    lector: no confirmado. Estudio académico: [Ara, revista de la UB](https://revistes.ub.edu/index.php/ara/article/view/47538).
- [x] **Caricaturistas** (10–20 h, la Rambla y las plazas del Pi y de Sant Josep Oriol): que te
  hagan una caricatura o posar de modelo. Fuentes: la Mostra de Pintors, Caricaturistes i
  Retratistes de les Rambles ([Ajuntament](https://www.barcelona.cat/barcelonacultura/en/detail/99400322599)),
  la normativa de la Mostra d'Art de Sant Josep Oriol ([Ajuntament](https://bcnroc.ajuntament.barcelona.cat/jspui/bitstream/11703/86394/1/normregpap_2015.pdf)).
- [x] **Punkis con perros** (11–4 h, en las plazas): llevan siempre un perro y a menudo dos
  (`DOG_OWNERS` por encima de 1). Compartir el litro (si te ve la Urbana, multa), pedirles un
  cigarro o dar de comer a los perros. Que los albergues no admitan perros es una de las razones
  por las que hay quien prefiere la calle.
  - [x] Albergues y perros: una mujer sin hogar entrevistada en 2025 lo da como una de sus razones
    para no ir («tampoco me dejan entrar con mis perras»,
    [Ara](https://es.ara.cat/sociedad/emergencia-social/albergues-prefiero-calle_1_5426926.html));
    desde 2016 los perros han ganado sitio en albergues y pisos sociales, los gatos no
    ([El Español, 2026](https://www.elespanol.com/mascotario/20260416/espana-da-paso-historico-centro-residencial-acoge-primera-vez-persona-tercera-edad-gato/1003744207794_0.amp.html)).
    No hay una norma de Barcelona que diga qué centros los admiten hoy.

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
  - [x] La bici sirve para moverse: con una en el inventario, B (o «Usar») para montar; vas
    mucho más rápido (`Defs.BIKE_SPEED`) sin gastar vitalidad, y llamas algo la atención.
  - [x] Los dueños reconocen su bici: yendo en una robada, quien te ve puede ser su dueño
    (`Defs.BIKE_OWNER_*`) y va a por ti o a por un agente; si te alcanza, se la lleva.
  - [x] Los chatarreros ya compran la chatarra y el cobre (algo menos que el compraventa).
  - [ ] Pendiente: que otros yonkis también compren objetos.

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
  - [x] Robar la litrona del súper y la propina del platito de un bar también se juegan: el
    minijuego de robar al descuido con el botín en el estante o en la barra y el dependiente o
    el camarero vigilando (`Pickpocket` con `loot` "litrona" o "propina").
  - [x] Robarle el alijo al latero también: sacar las latas de la reja de la alcantarilla con él
    al lado (`loot` "alijo"); si te pilla, va a por ti.
  - [x] El robado que te alcanza sin que lleves nada que devolverle se cobra a golpes con una
    pelea (minijuego), no con un puñetazo automático.
  - [ ] Pendiente: jugarlos y ajustar tiempos y dificultad.

## 8. Todo el mundo está yonki a su manera (3 de noviembre de 2026)

La idea de fondo: no hay «yonkis» y «gente normal», todo el mundo está enganchado a algo.
El barrio entero tiende a engancharse, también el jugador, y salir de ahí es lo más difícil.

- [x] **Los bots también consumen**: cada uno con sus sustancias, su colocón, su mono y su
  enganche, y se nota en cómo se comportan (el de farlopa va acelerado y busca bronca, el de
  caballo se duerme en un portal, el de pastillas está ido...). Encaja con el censo: al
  despertar a un latente se calcula cómo le ha ido desde la última vez.
  Hecho, primer paso (`scripts/consumo.gd`, equilibrio en `Defs.NPC_HABITS` y `Defs.NPC_*`):
  - Cada tipo tiene sus sustancias más probables y un enganche; cada bot, una sustancia de
    cabecera fija por su nombre (los personajes del editor, la primera que quieren). Los
    niños, los chavales, la policía y quien trabaja en lo social no consumen.
  - Colocón, mono y enganche simplificados (`Npc.consumo`): el colocón baja como el del
    jugador, sin él sube el mono y, con mono, se mete lo que lleva o sale a pillar (y lo paga).
  - Se nota: anda más rápido o más lento y hace eses según la sustancia (y el mono le frena);
    colocado de caballo, pastillas o alcohol cabecea, dormido en un portal; acelerado de
    farlopa, base o speed, algunos buscan bronca (pelea de verdad, minijuego) y pegan más
    fuerte; con mono y nada encima viene a pedirte o a comprarte (paga más cuanto peor está)
    y, sin dinero y a tope, te da el tirón (se lleva una dosis o unos euros). Se le puede dar
    una dosis (se acuerda). Dicen frases según cómo van.
  - El censo lo guarda al dormirlos y, al despertarlos, simula el tiempo latente a tramos de
    15 minutos (`Consumo.avanzar`): el colocón pasado, el mono acumulado y si ha pillado.
  - [ ] Pendiente: que se vean colocados (posturas, tumbados en el suelo), que se pasen
    cosas entre ellos, sobredosis de bots, y el contagio (ver abajo); jugarlo y ajustar.
- [ ] **Adicciones sin sustancia**: yonkis de pantalla (a los que es más fácil venderles un
  móvil, que no lo sueltan y no ven que les robas), del juego (tragaperras de los bares),
  del trabajo, de las compras...
- [ ] **Más sustancias**, cada una con sus efectos visuales, de manejo y de enganche:
  ~~speed, MDMA, LSD, setas, ketamina~~ (hechas), DMT; de farmacia: benzodiacepinas y otros ansiolíticos,
  antidepresivos, opioides de receta (tramadol, fentanilo en parches), y el alcohol y el tabaco
  de todos los días. Las de farmacia, con receta (médico del CAP) o de estraperlo.
  - [x] **Speed** (8 €): dura horas, acelera, la cámara tiembla un poco y la pantalla se ve
    con bordes duros y contraste (`sharp` en el shader de viñeta); bajón largo y con sueño.
    **MDMA** (10 €): engancha poco, sube la mente y la dignidad, todo cálido con un halo que
    late a 128 golpes por minuto (`love`), y el bajón de días después es de la cabeza. Los
    venden los camellos (y La Rubia, el MDMA); los compran las despedidas, los pijos (MDMA)
    y los yonkis (speed). Cada una con su hito de la caída.
  - [x] **Setas** y **LSD** (10 €): casi no enganchan; la imagen ondula y los colores respiran
    (`psico` en el shader), el tiempo se estira; el LSD dura unas diez horas y no te deja dormir.
    Con la salud mental baja (o, a veces, sin más) el viaje se tuerce: **mal viaje** (paranoia,
    túnel, temblor y un golpe a la mente; `malviaje` en `Defs.SUBSTANCES`).
    **Ketamina** (15 €): corta e intensa, todo se aleja y se desdobla (`disocia`), vas lento y
    a la deriva. Las tres las venden los camellos; las compran despedidas, pijos y guiris (setas).
  - [x] **De farmacia**, con **receta** (el médico de cabecera del CAP, una vez por semana; con
    ella, una caja en la farmacia: `Defs.RECETA`) o de estraperlo (los yonkis las llevan y las
    cambian): **ansiolíticos** (quitan la paranoia y el miedo, dan sueño, enganchan bastante),
    **antidepresivos** (casi no se notan, pero tomados cada día sostienen la mente;
    `sanity_rate`; dejarlos de golpe da su síndrome) y **tramadol** (opioide: calma el mono del
    caballo, da sueño, puede dar sobredosis).
  - [x] **Tabaco**: un cigarro casi no hace nada, pero engancha y calma el temblor de las manos.
    Paquetes de 20 en la máquina del bar (6 €); los skaters y los punkis te dan alguno.
  - [x] **Mezclar depresores** (ansiolíticos, tramadol o ketamina con alcohol o caballo, `mezcla`)
    sube mucho el riesgo de sobredosis (`Defs.MEZCLA_OD`) y es un hito.
  - [x] Los bots también: fuman (vecinos, chatarreros, camellos...), los vecinos y los abuelos
    toman ansiolíticos y antidepresivos, las despedidas ketamina y LSD, los punkis setas.
- [x] **Resacas** (las sustancias que la dan en la vida real: alcohol, porros, pastillas,
  farlopa, base, speed, MDMA, ketamina, ansiolíticos, tramadol, setas, LSD; no el caballo, la
  metadona, el tabaco ni los antidepresivos). Cada dosis suma resaca pendiente y, **al dormir**,
  se convierte en resaca de verdad, más larga y fuerte cuanto más consumiste
  (`Defs.RESACA_*`, `resaca` en `Defs.SUBSTANCES`). Cada una con sus efectos (la de alcohol:
  luz que molesta y cabeza que late, `resaca` en el shader; la de speed, hecho polvo; la del MDMA,
  el martes negro que te baja la mente durante un día), te quita vitalidad máxima y sale en la
  lista de efectos. Con las que lo permiten, «la del perro» (volver a meterte lo mismo) te la
  quita a medias.
  - [ ] Pendiente: DMT, fentanilo en parches; que las del médico tengan efectos con el tiempo
    (los antidepresivos tardan semanas); jugarlo y ajustar duraciones y precios.
- [ ] **Contagio y conversiones** entre yonki y «no yonki», en los dos sentidos, con una
  tendencia general a engancharse (ver «Contagio» en «Personajes que viven»).
- [ ] **Equilibrio**: consumo, enganche, precios y premios de las misiones. Ahora mismo es
  demasiado fácil hacer mucho dinero (lo ha notado el usuario jugando): repasar lo que dan
  pedir, robar, trapichear, los encargos y las misiones, y lo que cuesta vivir.
  - [x] Primer ajuste (3 de noviembre): carteras con poco efectivo (`Defs.WALLET_*`: 0–35 €,
    una de cada diez 60–140 €), reventa más barata (móvil 18 €, patinete 28 €, bici 15 €),
    menos margen al trapichear (despedidas ×1,7, guiris ×2,5, pijos ×2) y pagas de los
    perfiles más realistas (paro 120 € y pensión 140 € por semana; papá, 150 € cada 4 días).
  - [x] **Diseñador de sustancias** (`editor_sustancias.cmd`, 4 de noviembre): tablas con
    precios y efectos de sustancias, objetos, clientes, consumo de los bots, precios de las
    acciones (`Defs.PRECIOS`, antes escritos a mano en `interactions.gd`) y receta. Los
    retoques van a `data/equilibrio.json` y mandan sobre `defs.gd` (`Equilibrio`).
    - [ ] Pendiente: los premios de los encargos y misiones, las multas, las carteras y las
      demás constantes sueltas de `defs.gd`; ordenar por columna y fijar la columna de nombres.
  - [ ] Jugarlo y seguir: comida, precio de la droga según la hora y el barrio, premios.

### Lo que sale de jugar las misiones (3 de noviembre de 2026)

- [x] Los plazos de «El paquete para Txell» y «El cajero de Antonio» parecen bien.
- [x] **Barra de vitalidad**: correr no puede salir gratis. Se gasta al correr (y pelear) y
  se recupera parado; su máximo y lo que tarda en volver dependen del hambre, el sueño, el
  colocón, el mono y la salud.
- [x] **Mapa** del barrio (una tecla): calles, dónde estás, los sitios que conoces y los de
  la libreta.
- [x] **Pausa** (botón y tecla). Hechas las tres (rama `feat/vitalidad-mapa-pausa`): medidas en
  `Defs.VITALITY_*`; el mapa, en `ui/mapa_barrio.gd`.
- [ ] **Más gente con la que vale la pena tratar**: ahora hay mucho bot de relleno; que
  los personajes con historia, misiones o trato se encuentren más a menudo.
  - [x] Primer paso: **peticiones** de la gente corriente (solo algunos de cada tipo, con
    «!»): la receta de un abuelo en la farmacia, llevar a un turista perdido a una iglesia y
    la compra de una vecina, que te da 20 € por adelantado y no olvida si te los quedas.
    En `Defs.ERRANDS` (`share`, tirada por persona y no por nombre). Luego tres más: el
    perro escapado de un vecino, la pelota de los niños en la terraza de un bar y el
    repartidor que no encuentra la dirección.

### Finales

- [x] **Redención (perder, el más difícil)**: subir tanto la dignidad y bajar el enganche a 0
  que la gente te empieza a apreciar, te echas pareja (un vecino o una vecina) y formas una
  familia. Has salido... y has perdido.
  Hecho: con la dignidad a 90 o más, sin enganche (`Defs.REDEMPTION_*`) y al menos cuatro
  personas en el censo a las que has ayudado dos veces, una de ellas (vecina, educador,
  música, repartidor) te propone quedarte. Pantalla final «REDENCIÓN», en verde.
- [ ] **Revolución (difícil)**: comandas un ejército de yonkis, os organizáis y tomáis el
  poder de un barrio (ver «Legado»).
- [x] **Morir de hambre, pero de verdad**: no al vaciarse la barra, sino días después; con la
  barra vacía se nota mucho en la fuerza, la salud mental, la vista y el manejo. Hecho: las
  horas con el hambre al límite se acumulan (`GameState.starving`, «Inanición» en los efectos:
  túnel, temblor, torpeza, sueño), bajan la vitalidad y la salud cada vez más deprisa, y al
  desmayarte solo a veces te recoge una ambulancia (`Defs.STARVE_*`, `FAINT_RESCUE`). Sin
  comer nada, se muere en unos cuatro días de juego.
- [ ] **Sobredosis** (común): el enganche puede subir muy deprisa, por consumo o por las
  putadas que te pasan en la partida (te roban la metadona, te cortan la droga, un susto...).
- [x] **A palos** (eventual): si enfadas a demasiada gente. Hecho: con `Defs.AMBUSH_ENEMIES`
  enemigos en el censo (robados, pegados, timados), a veces te esperan entre varios
  (`World.ambush`); y cada paliza mortal dice quién y por qué.
- [x] **La cárcel**: a la quinta detención, dos años en Brians (`Defs.PRISON_ARRESTS`); a la
  cuarta, el juez avisa.
- [x] **Leyenda del barrio** (ganar): con la caída máxima (`Defs.LEGEND_CAIDA`, el último
  título), tu historia la cuentan los guías de los free tours.
- [x] **Te llevan a casa** (Borja): con la dignidad por los suelos, cada día puede aparecer su
  familia a recogerlo (`Defs.HOME_RESCUE_*`). Para él, eso es perder.
- [ ] Propuestas de Claude, por valorar: **el psiquiátrico** (la salud mental a cero), **el capo** (te haces con el
  menudeo del barrio y dejas de consumir: has caído hacia arriba), **te llevan de vuelta a
  casa** (un familiar te encuentra y te saca del barrio) y **leyenda del barrio** (la caída más
  honda: tu historia la cuentan los guías de los free tours).

## Más adelante

- Misiones largas e intrincadas
- Minijuegos para dar variedad
- Concretar la idea central y el objetivo final
- **Mapa del juego**: un esquema de todas las mecánicas y cómo se relacionan (para el usuario).

## Juegos de referencia

- *Hobo: Tough Life* — supervivencia como sin techo en una ciudad
- *Cart Life* — vida diaria de gente pobre con negocios callejeros
- *Disco Elysium* — rol de conversación en un barrio degradado
- *Generative Agents* (Stanford, 2023) — pueblo simulado con personajes de IA
- *Vaudeville*, *Suck Up!*, mod *Mantella* de Skyrim — NPCs con IA conversacional
