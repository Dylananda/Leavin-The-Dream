class_name Defs
## Datos fijos del juego: perfiles de yonki, sustancias, objetos y títulos.
## Para equilibrar el juego, casi todo se toca aquí. Las tablas `static var ... Equilibrio.aplicar`
## (sustancias, objetos, clientes, lo que consumen los bots, precios y receta) también se
## retocan con el diseñador de sustancias (editor_sustancias.cmd): sus cambios se guardan en
## data/equilibrio.json y mandan sobre lo de aquí (ver Equilibrio).

## Minutos de juego que pasan por cada segundo real.
const GAME_MINUTES_PER_SECOND := 2.0

## Ritmo del cuerpo, en puntos por minuto de juego (un día son 1440 minutos).
const HUNGER_RATE := 0.05  ## el hambre llega a 100 en un día y medio sin comer
const FATIGUE_RATE := 0.065  ## el sueño, en algo menos de un día despierto
const SLEEP_RECOVERY := 0.25  ## sueño que se recupera durmiendo con calidad 1
const HEAT_DECAY := 0.08  ## lo rápido que la policía se olvida de ti
## Tope de lo que llamas la atención solo por tu aspecto: se queda por debajo
## del umbral de persecución (40) para que sea la gota que colma el vaso.
const MAX_EXPOSURE := 35.0
## A partir de esta búsqueda (heat), la policía va a por ti... si te ve.
const CHASE_HEAT := 40.0

## Visión de los personajes, en cono como en *Commandos*: largo en casillas (2 m) y apertura
## en grados. La tapan los edificios. De noche se ve menos (NIGHT_SIGHT) y, con la discreción
## vacía (heat >= 90), te ven desde más lejos (EXPOSED_SIGHT). A NEAR_SIGHT casillas te notan
## aunque estés a su espalda.
const VISION := {
	"urbano": {"range": 14.0, "angle": 70.0},
	"mosso": {"range": 14.0, "angle": 70.0},
	# los de paisano miran como cualquiera, pero algo más lejos: es su oficio
	"urbano_secreta": {"range": 12.0, "angle": 90.0},
	"mosso_secreta": {"range": 12.0, "angle": 90.0},
	"estatua": {"range": 8.0, "angle": 60.0},  # no puede girar la cabeza
	"_": {"range": 10.0, "angle": 90.0},
}
const NIGHT_SIGHT := 0.72
const EXPOSED_SIGHT := 1.5
const NEAR_SIGHT := 2.0
## Segundos que tienen que verte (en el borde del cono) para darse cuenta; de cerca, la
## tercera parte. Sin verte, la sospecha baja a ALERT_DECAY por segundo.
const ALERT_TIME := 1.4
const ALERT_DECAY := 0.35
## Persecución: segundos sin verte antes de ir al último sitio donde te vieron, y lo que
## buscan allí antes de rendirse.
const LOSE_SIGHT_TIME := 2.5
const SEARCH_TIME := 8.0
## Si te escapas de la policía, o nadie de uniforme oye el escándalo, quedas fichado: el
## agente que te vea en este tiempo (minutos de juego) te persigue aunque no hagas nada.
const WANTED_MINUTES := 24.0 * 60.0
## Los dos cuerpos de policía y lo que le toca a cada uno (fuentes en docs/ideas.md). La
## Guàrdia Urbana es la policía local del Ajuntament: convivencia, ordenanza de civismo, venta
## ambulante, y también los hurtos en la Rambla y el metro. Los Mossos d'Esquadra (Generalitat)
## llevan el orden público y los delitos: robos con violencia, peleas, drogas, y las detenciones
## acaban en su comisaría. Por cada delito, qué cuerpos acuden si los llaman y te persiguen si
## te fichan por él (ver GameState.mark_wanted y World.scandal). Uno que te ve en flagrante
## interviene sea del cuerpo que sea.
const CRIME_CORPS := {
	"civismo": ["urbana"],  # beber en la calle, dormir a la vista, trile, manta, latas
	"hurto": ["urbana", "mossos"],  # carteras, móviles, bicis: sin violencia
	"violencia": ["mossos"],  # peleas y robos con violencia
	"drogas": ["urbana", "mossos"],  # vender, camellos, narcopisos (la Urbana, contra el menudeo: Plan Druida)
}
## Multas de la Urbana por la ordenanza (euros). La de convivencia de 2026 pone de 30 a 100 €
## por beber en lata o botella donde no se puede, y más si molesta o hay niños cerca.
const FINE_DRINKING := 60
const FINE_INSULT := 100  ## faltarle al respeto a un agente (Ley de Seguridad Ciudadana)
## Dormir en la calle (World.sleep): la Urbana te despierta y te echa si te ve. Probabilidad
## de que pase una patrulla y te vea según dónde duermes; un agente que ya te ve casi seguro.
## Escondido (un rincón con poca calle alrededor, ver World.hidden_spot) es mucho más seguro.
const SLEEP_WAKE := {"calle": 0.45, "banco": 0.5, "cajero": 0.3}
const SLEEP_WAKE_SEEN := 0.9
const SLEEP_WAKE_PER_AGENT := 0.1  ## cada agente de la Urbana de patrulla cerca suma esto
const SLEEP_PATROL_CELLS := 80  ## casillas a las que cuenta un agente como «de patrulla cerca»
const SLEEP_HIDDEN_FACTOR := 0.25  ## escondido, la probabilidad se queda en esta parte
const HIDDEN_OPEN_CELLS := 16  ## un rincón tiene menos de estas casillas de calle en 7x7 (un 7 % de la calle)
## Ronda de la policía por el barrio (World._police_event): cada cuánto (probabilidad por evento
## del barrio) la Urbana va a por un mantero, latero o trilero y los Mossos a por un camello, y
## la probabilidad de que los de paisano se lleven a un carterista que están vigilando.
const URBANA_SWEEP := 0.25
const MOSSOS_SWEEP := 0.12
const UNDERCOVER_CATCH := 0.35
## El grupo de un free tour: turistas que siguen al guía (en Ciutat Vella, máximo 15).
const GUIDE_GROUP := Vector2i(4, 8)
const PARTY_GROUP := Vector2i(2, 4)
## Variedad de cuerpos de los bots (Npc.init_kind): delgados, gruesos y altura.
const BUILD_THIN := 0.2
const BUILD_HEAVY := 0.2
const HEIGHT_RANGE := Vector2(0.93, 1.07)
const RIDER_BIKE := 0.75  ## repartidores que van en bici (el resto, a pie y con prisa)  ## los que van detrás de cada despedida de soltero
## Vecinos y abuelos que van con niños (de la mano: los niños les siguen), y cuántos.
const KIDS_WITH := {"vecino": 0.12, "anciano": 0.15}
const KIDS_GROUP := Vector2i(1, 2)
## Cuántas veces más gente de cada tipo hay en el censo que en World.BASE_NPCS, ahora que los
## lejanos están latentes (scripts/censo.gd) y no cuestan. Sube sobre todo la gente corriente:
## el Raval tiene unos 47.000 vecinos y así hay en el censo uno de cada treinta y tantos. La
## policía, los camellos y los que hacen el juego más difícil no cambian (los tipos que no
## están aquí, x1). El límite lo pone la tarjeta gráfica con los que se ven a la vez: con esto,
## unos 1.400 en el censo y 50-150 con cuerpo alrededor, a 60 FPS en una GTX 1060 (tests/paseo.gd).
const CROWD := {
	"vecino": 15.0, "anciano": 10.0, "nino": 6.0, "turista": 6.0, "pudiente": 4.0, "mensajero": 4.0,
	"fiestero": 1.5, "skater": 3.0, "yonki": 2.0, "mendigo": 2.0, "chaval": 2.0, "musico": 2.0,
	"rosero": 2.0, "chatarrero": 2.0,
}
## Estadísticas de los personajes del editor (scripts/personajes.gd), de 0 a 10; con 5 son
## como un bot corriente de su tipo.
const STAT_FIGHT := 0.06  ## probabilidad de ganarle una pelea que quita cada punto de fuerza por encima de 5
const STAT_BRAVE := 0.05  ## lo que suma cada punto de valor sobre 5 a que se enfrente en un escándalo...
const STAT_AVENGE := 0.06  ## ... y cada punto de valor o agresividad a que vaya a por ti si le robas
const STAT_HOTHEAD := 7  ## desde esta agresividad, al que pegas o pides demasiado va a por ti en vez de apartarse
## Vitalidad: el aguante para correr y pelear (GameState.vitality). Se gasta en segundos reales.
const BIKE_SPEED := 1.8
## Yendo en una bici robada, la probabilidad de que alguien que te ve (de estos tipos) sea su dueño.
const BIKE_OWNER_CHANCE := 0.03
const BIKE_OWNERS := ["vecino", "pudiente", "turista", "mensajero", "skater"]  ## en bici (B, si llevas una): multiplicador de velocidad, sin gastar vitalidad
const VITALITY_RUN_COST := 11.0  ## por segundo corriendo (con el máximo lleno, unos 9 s seguidos)
const VITALITY_REGEN_STILL := 9.0  ## por segundo parado...
const VITALITY_REGEN_WALK := 4.0  ## ... y andando
const VITALITY_RECOVER := 30.0  ## agotado, no vuelves a correr hasta tener esto
const VITALITY_FIGHT := 30.0  ## lo que gasta una pelea...
const VITALITY_FIGHT_CHANCE := 0.25  ## ... y lo que baja la probabilidad de ganarla ir sin nada de vitalidad
## Lo que baja el máximo: cada punto de hambre y de sueño por encima de 50, cada punto de mono
## y cada punto de salud perdido. El máximo nunca baja de VITALITY_MIN_MAX.
const VITALITY_HUNGER := 0.7
const VITALITY_FATIGUE := 0.7
const VITALITY_MONO := 0.4
const VITALITY_HEALTH := 0.4
const VITALITY_MIN_MAX := 15.0
## Inanición: con el hambre por encima de STARVE_FROM se acumulan horas sin comer de verdad
## (GameState.starving). Cuantas más, más rápido baja la salud: se muere de hambre en unos
## días, no de golpe. Al comer se recupera el doble de deprisa.
const STARVE_FROM := 90.0
const STARVE_HEALTH := 0.006  ## salud por minuto con hambre de más de 85...
const STARVE_WORSEN := 36.0  ## ... que se dobla cada tantas horas de inanición
const STARVE_SANITY := 0.01  ## salud mental por minuto y día de inanición
const VITALITY_STARVE := 0.8  ## vitalidad máxima que quita cada hora de inanición
const FAINT_RESCUE := 0.5  ## al desmayarte de hambre, probabilidad de que alguien llame a una ambulancia
## Redención (perder, el más difícil): con esta dignidad, sin enganche a nada (como mucho
## esto en cada sustancia) y con al menos estos amigos en el barrio (a los que has ayudado
## estas veces), te echas pareja y sales del pozo.
const REDEMPTION_DIGNITY := 90.0
const REDEMPTION_ADDICTION := 1.0
const REDEMPTION_FRIENDS := 4
const REDEMPTION_HELPS := 2
const PARTNER_KINDS := ["vecino", "educador", "musico", "mensajero"]  ## de quién te enamoras
## Leyenda del barrio: con esta caída (el último título de TITLES) se gana la partida.
const LEGEND_CAIDA := 800.0
## Te llevan a casa (Borja, el niño bien): con la dignidad por debajo de esto, cada día puede
## aparecer su familia a recogerlo.
const HOME_RESCUE_DIGNITY := 15.0
const HOME_RESCUE_CHANCE := 0.3
## La cárcel: con estas detenciones entras en prisión (fin de la partida); con una menos, aviso.
const PRISON_ARRESTS := 5
## Relevo (World.relevo): al acabar con un yonki sigues con otro de los perfiles en el mismo
## barrio, unos días después. El anterior se queda según cómo acabó (DESTINOS) y el barrio
## está algo más enganchado cada vez.
const RELEVO_DIAS := Vector2i(2, 5)  ## días que pasan entre uno y otro
const RELEVO_CONTAGIOS := 4  ## gente corriente que se ha enganchado en ese tiempo (va con los yonkis)
const RELEVO_YONKIS := 0.15  ## yonkis de más por la calle en cada relevo (proporción de los de siempre)
const RELEVO_ENGANCHE := 5.0  ## enganche que suma a los bots en cada relevo
## Y también día a día: cada día, probabilidad de que alguien de la gente corriente se enganche
## (sube un poco con cada relevo: el barrio va a peor).
const CONTAGIO_DIARIO := 0.35
const CONTAGIO_DIARIO_RELEVO := 0.1
## Quién se puede enganchar entre relevo y relevo (los personajes del editor, no).
const RELEVO_CONTAGIABLES := ["vecino", "mendigo", "punki", "latero", "chatarrero", "skater", "musico", "anciano"]
## Qué fue del yonki: cómo se dice y qué queda de él en el barrio ("altar": donde murió;
## un tipo de bot: sigue en el censo, de ese tipo; "": no vuelve).
const DESTINOS := {
	"muerto": {"texto": "murió en la calle", "queda": "altar"},
	"leyenda": {"texto": "se hizo leyenda del barrio", "queda": "yonki"},
	"redimido": {"texto": "rehízo su vida (y perdió)", "queda": "vecino"},
	"preso": {"texto": "entró en Brians", "queda": ""},
	"deportado": {"texto": "fue expulsado del país", "queda": ""},
	"psiquiatrico": {"texto": "se quedó en el psiquiátrico", "queda": ""},
	"fuera": {"texto": "volvió con su familia", "queda": ""},
	"cumplido": {"texto": "consiguió lo que buscaba", "queda": "vecino"},
}
## Lo que dice de sí mismo el que se queda en el barrio («Escuchar su historia»).
const DESTINO_BIO := {
	"leyenda": "Lleva en el Raval más que las palomas. Los guías de los free tours paran delante de su portal y cuentan su historia; él les pide un euro.",
	"redimido": "Hace nada estaba como tú. Ahora descarga en la Boqueria, tiene pareja y un crío, y cruza de acera cuando ve a los de antes.",
}
const ALTAR_VELA := 1  ## € que cuesta una vela en el altar de un yonki anterior
const ALTAR_MONEDAS := Vector2i(2, 12)  ## lo que la gente ha dejado entre las flores
## Ajuste de cuentas: con estos enemigos en el barrio (a los que robaste, pegaste o timaste),
## a veces te esperan entre varios. Probabilidad en cada evento del barrio.
const AMBUSH_ENEMIES := 6
const AMBUSH_CHANCE := 0.15
## Lo que lleva una cartera robada: casi siempre poco efectivo (se paga con tarjeta) y, alguna
## vez, una buena (los primeros días, el dinero del viaje).
const WALLET_CASH := Vector2i(0, 35)
const WALLET_FAT_CHANCE := 0.1
const WALLET_FAT := Vector2i(60, 140)
## Bots latentes (scripts/censo.gd): lo que se pone al día al volver a verlos.
const LATENT_ROBBED_FORGET := 24.0 * 60.0  ## minutos tras los que al que robaron vuelve a llevar dinero
const LATENT_MEMORY_FADE := 3.0 * 24.0 * 60.0  ## minutos latente por cada vez que olvida algo que le hiciste...
const LATENT_GRUDGES := ["robado", "pegado", "timado", "pisado", "oido_mal"]  ## ... y esto lo olvida a la mitad de ritmo

## Escándalo al robar: quién oye el grito (casillas) y lo lejos que llega una llamada a la policía.
const SCANDAL_HEAR := 20
const SCANDAL_CALL := 60
## Carácter de los transeúntes ante un escándalo (tirada fija por nombre): intentan pararte,
## llaman a la policía o pasan. Los que viven de la calle nunca se meten.
const BRAVE_CHANCE := 0.2
const CALLER_CHANCE := 0.45
const NEVER_INTERVENE := ["yonki", "camello", "mantero", "latero", "trilero", "carterista", "chaval", "nino", "perro",
	"mendigo", "punki", "rosero", "chatarrero", "trabajadora_sexual", "captador", "skater", "estatua"]
## Turistas (y despedidas) robados que te reconocen: probabilidad de que vayan a por ti en vez
## de buscar a un policía, según su género (fija por nombre).
const AVENGER_CHANCE := {"m": 0.6, "f": 0.3}
## Veces que le tienes que pedir a alguien para que se aparte al verte.
const BEG_ANNOY := 2
## Horas que te da un camello para pagar lo fiado antes de venir a por ti.
const DEBT_GRACE_HOURS := 12.0
## Despertadores (scripts/censo.gd): el que tiene que cobrarte viene a buscarte aunque esté lejos.
const DEBT_VISIT_EVERY := 6.0  ## horas de juego entre una visita y la siguiente si no le pagas
const HUNT_SECONDS := 90.0  ## segundos reales que te busca antes de dejarlo para otra vez

## look: colores y rasgos del muñeco (ver Actor.look).
const PROFILES := [
	{
		"id": "sin_papeles",
		"name": "Youssef",
		"title": "Sin papeles",
		"desc": "Llegó en patera con un sueño. El sueño se quedó en Tarifa. Sin paro, sin pensión, sin nada que perder... salvo el país.",
		"money": 15, "health": 85, "dignity": 70, "sanity": 60,
		"knows": {"porro": 20, "tabaco": 30},
		"income": {},
		"perk": "Sabe ganarse la vida en la calle: los manteros le dan curro. Pero tres detenciones y lo deportan.",
		"items": {"movil_roto": 1},
		"look": {"skin": Color("8d5a3b"), "shirt": Color("2f6b4f"), "pants": Color("3a3a48"), "hair": Color("1b1410"),
			"gender": "m", "hair_style": "rapado", "facial": "barba"},
	},
	{
		"id": "parado",
		"name": "Paco",
		"title": "Parado de larga duración",
		"desc": "52 años, 30 cotizando en una fábrica que ahora es un hotel boutique. Le queda el paro y la litrona de las once.",
		"money": 60, "health": 65, "dignity": 60, "sanity": 55,
		"knows": {"litrona": 45, "porro": 5, "tabaco": 40},
		"income": {"amount": 120, "every_days": 7, "label": "el paro"},  # subsidio: unos 500 € al mes
		"perk": "Cobra el paro cada semana en el cajero.",
		"items": {"litrona": 1},
		"look": {"skin": Color("d9a77c"), "shirt": Color("8a8f5a"), "pants": Color("4a3f35"), "hair": Color("6b6b6b"),
			"gender": "m", "hair_style": "calvo", "facial": "bigote", "jacket": Color("2e3e6e")},  # chaqueta de chándal
	},
	{
		"id": "jubilado",
		"name": "Don Ramón",
		"title": "Jubilado",
		"desc": "Viudo, 71 años. Descubrió las tragaperras, después los carajillos, después lo demás. Los nietos ya no llaman.",
		"money": 120, "health": 45, "dignity": 85, "sanity": 50,
		"knows": {"litrona": 35, "ansioliticos": 25},  # los carajillos y el Orfidal de la viudez
		"income": {"amount": 140, "every_days": 7, "label": "la pensión"},  # no contributiva: unos 600 € al mes
		"perk": "La policía no sospecha de un abuelo. Da mucha pena pidiendo.",
		"items": {"bocadillo": 1, "ansioliticos": 1},
		"look": {"skin": Color("e8bfa0"), "shirt": Color("5b4a3a"), "pants": Color("6e6658"), "hair": Color("e8e8e8"),
			"gender": "m", "hair_style": "calvo", "glasses": true, "jacket": Color("4a3a2a")},  # americana de los domingos
	},
	{
		"id": "divorciado",
		"name": "Jordi",
		"title": "Divorciado",
		"desc": "Ella se quedó la casa, el perro y los amigos. Él se quedó un estudio en la calle del Carme y mucho tiempo libre.",
		"money": 350, "health": 80, "dignity": 95, "sanity": 55,
		"knows": {"litrona": 25, "ansioliticos": 15, "tabaco": 20},  # lo volvió a coger con el divorcio
		"income": {"amount": -80, "every_days": 4, "label": "la pensión alimenticia"},
		"perk": "Empieza con ahorros y un anillo de boda que vender. Cada 4 días le cobran la pensión alimenticia.",
		"items": {"anillo": 1, "movil": 1},
		"look": {"skin": Color("e0b08a"), "shirt": Color("3d5a8a"), "pants": Color("2b2b33"), "hair": Color("4a3020"),
			"gender": "m", "hair_style": "corto", "facial": "barba"},  # barba de tres semanas
	},
	{
		"id": "psiquiatrico",
		"name": "Mari Loli",
		"title": "Recién salida del psiquiátrico",
		"desc": "Le dieron el alta, una receta y un 'cuídate, Loli'. Las voces dicen que el Raval es un buen sitio para empezar.",
		"money": 30, "health": 70, "dignity": 50, "sanity": 35,
		"knows": {"pastillas": 35, "ansioliticos": 30, "porro": 10, "tabaco": 40},
		"income": {},
		"perk": "Recoge pastillas gratis en la farmacia cada 2 días. Oye voces.",
		"items": {"pastillas": 2},
		"look": {"skin": Color("efc7a8"), "shirt": Color("a04a7a"), "pants": Color("5a4a6a"), "hair": Color("c45a2a"),
			"gender": "f", "hair_style": "rizos", "skirt": true},
	},
	{
		"id": "nino_bien",
		"name": "Borja",
		"title": "Niño bien de Pedralbes",
		"desc": "Bajó al Raval 'a conocer la Barcelona auténtica'. Papá le pasa una paga. Tiene muchísima dignidad que perder.",
		"money": 600, "health": 95, "dignity": 100, "sanity": 85,
		"knows": {"farlopa": 15, "mdma": 5, "litrona": 0},  # de las fiestas de Pedralbes
		"income": {"amount": 150, "every_days": 4, "label": "la paga de papá"},
		"perk": "Papá le ingresa dinero... hasta que su dignidad baje de 40 y alguien se lo cuente.",
		"items": {"movil": 1},
		"look": {"skin": Color("f0cfb0"), "shirt": Color("e8e2d0"), "pants": Color("2a3a5a"), "hair": Color("d8b060"),
			"gender": "m", "hair_style": "tupe"},
	},
]

## Efectos en el juego (no son datos reales):
## high = colocón, addiction = enganche, health/dignity/sanity = cambios al tomarla,
## od = riesgo de sobredosis, decay = colocón que se pierde por minuto,
## hunger_rate/fatigue_rate = cómo cambian el hambre y el sueño mientras dura,
## visible = cuánto se te nota (resta discreción), crash = bajón al acabarse,
## relieves = sustancia cuyo mono calma (y "mono" lo que le quita).
## fx = efectos en cámara y movimiento con el colocón al máximo; fx_text los explica en el HUD:
##   speed (+ rápido / − lento), sway (la cámara oscila), shake (tiembla), zoom (+ cerca / − lejos),
##   drift (eses al andar), lag (respondes tarde), double (visión doble), saturate (colores chillones),
##   slowmo (el tiempo se estira), glow (todo brilla), drowsy (párpados), tunnel (bordes oscuros),
##   clumsy (tropiezos), paranoia (aberración cromática).
static var SUBSTANCES := Equilibrio.aplicar("sustancias", {
	"litrona": {"name": "Litrona", "price": 2, "high": 25, "addiction": 1.5, "health": -1, "dignity": -1, "sanity": 2, "od": 0.0,
		"decay": 0.1, "fatigue_rate": 1.5, "visible": 0.3, "color": Color("d8b040"),
		"resaca": {"dosis": 0.35, "horas": 6, "mente": -0.5, "fx": {"resaca": 1.0, "speed": -0.15, "tunnel": 0.2}, "text": "dolor de cabeza, sed y la luz te mata", "se_quita": true},
		"fx": {"drift": 1.0, "lag": 0.8, "double": 0.7, "sway": 0.25}, "fx_text": "andas haciendo eses y reaccionas tarde"},
	"porro": {"name": "Porro", "price": 4, "high": 25, "addiction": 1, "health": -1, "dignity": 0, "sanity": 2, "od": 0.0,
		"decay": 0.12, "hunger_rate": 2.0, "fatigue_rate": 1.4, "visible": 0.2, "color": Color("6ab04a"),
		"resaca": {"dosis": 0.2, "horas": 4, "mente": 0.0, "fx": {"slowmo": 0.15, "drowsy": 0.3}, "text": "niebla en la cabeza"},
		"fx": {"zoom": 0.35, "slowmo": 1.0, "speed": -0.1}, "fx_text": "todo va más lento y lo ves de cerca"},
	"pastillas": {"name": "Pastillas", "price": 3, "high": 25, "addiction": 3, "health": -3, "dignity": -1, "sanity": 3, "od": 0.2,
		"decay": 0.1, "fatigue_rate": 1.3, "visible": 0.1, "color": Color("e06ab0"),
		"resaca": {"dosis": 0.3, "horas": 6, "mente": -0.3, "fx": {"drowsy": 0.5, "clumsy": 0.4}, "text": "torpe y adormilado"},
		"fx": {"saturate": 1.0, "speed": -0.15}, "fx_text": "colores chillones y piernas de goma"},
	"farlopa": {"name": "Farlopa", "price": 30, "high": 35, "addiction": 4, "health": -4, "dignity": -2, "sanity": 4, "od": 0.3,
		"decay": 0.2, "hunger_rate": 0.2, "fatigue_rate": 0.2, "visible": 0.3, "color": Color("e8e8f0"),
		"crash": {"minutes": 30, "sanity": -4, "mono": 8, "fatigue": 10},
		"resaca": {"dosis": 0.4, "horas": 8, "mente": -1.0, "fx": {"resaca": 0.6, "shake": 0.2}, "text": "ansiedad, la mandíbula dolorida y ganas de más", "se_quita": true},
		"fx": {"speed": 0.4, "shake": 0.5}, "fx_text": "vas a toda leche y la vista te tiembla"},
	"base": {"name": "Base", "price": 10, "high": 40, "addiction": 9, "health": -6, "dignity": -6, "sanity": 6, "od": 0.5,
		"decay": 0.5, "hunger_rate": 0.2, "fatigue_rate": 0.3, "visible": 0.5, "color": Color("f0a040"),
		"crash": {"minutes": 60, "sanity": -10, "mono": 20, "fatigue": 15},
		"resaca": {"dosis": 0.5, "horas": 8, "mente": -1.5, "fx": {"resaca": 0.5, "tunnel": 0.4}, "text": "un vacío enorme y ganas de más", "se_quita": true},
		"fx": {"speed": 0.3, "glow": 1.0, "zoom": -0.15}, "fx_text": "euforia: todo brilla (dura muy poco)"},
	"caballo": {"name": "Caballo", "price": 15, "high": 55, "addiction": 8, "health": -8, "dignity": -5, "sanity": 3, "od": 1.0,
		"decay": 0.1, "hunger_rate": 0.6, "fatigue_rate": 2.5, "visible": 0.3, "color": Color("c89a6a"),
		"fx": {"speed": -0.45, "sway": 1.0, "drowsy": 0.35}, "fx_text": "vas lento y todo oscila"},
	"metadona": {"name": "Metadona", "price": 0, "high": 8, "addiction": 1, "health": 0, "dignity": 0, "sanity": 2, "od": 0.0,
		"decay": 0.02, "visible": 0.0, "color": Color("60a0c0"),
		"relieves": "caballo", "mono": -60, "relief_addiction": 2,
		"fx": {"speed": -0.1}, "fx_text": "te calma el mono del caballo"},
	# anfetamina: más barata y larga que la farlopa, y el bajón dura (la «bajona» del día siguiente)
	"speed": {"name": "Speed", "price": 8, "high": 30, "addiction": 4, "health": -3, "dignity": -2, "sanity": 2, "od": 0.15,
		"decay": 0.06, "hunger_rate": 0.1, "fatigue_rate": 0.1, "visible": 0.3, "color": Color("e8e070"),
		"crash": {"minutes": 120, "sanity": -6, "mono": 6, "fatigue": 25},
		"resaca": {"dosis": 0.4, "horas": 10, "mente": -1.0, "fx": {"resaca": 0.7, "drowsy": 0.5}, "text": "la bajona: hecho polvo y de mala leche", "se_quita": true},
		"fx": {"speed": 0.25, "shake": 0.2, "sharp": 1.0}, "fx_text": "horas acelerado, los ojos como platos y la mandíbula apretada"},
	# éxtasis: no engancha tanto, te pone cariñoso y el bajón de días después es de la cabeza
	"mdma": {"name": "MDMA", "price": 10, "high": 45, "addiction": 2, "health": -4, "dignity": 1, "sanity": 6, "od": 0.25,
		"decay": 0.12, "hunger_rate": 0.3, "fatigue_rate": 0.4, "visible": 0.4, "color": Color("80c8f0"),
		"crash": {"minutes": 240, "sanity": -14, "mono": 4, "fatigue": 10},
		"resaca": {"dosis": 0.6, "horas": 24, "mente": -2.5, "fx": {"tunnel": 0.3, "drowsy": 0.3}, "text": "el martes negro: todo es triste y nadie te quiere"},
		"fx": {"love": 1.0, "speed": 0.1, "sway": 0.2}, "fx_text": "todo es cálido y late, y quieres a todo el mundo"},
	# psicodélicos: casi no enganchan, pero con la cabeza mal el viaje puede ser malo (`malviaje`)
	"setas": {"name": "Setas", "price": 10, "high": 40, "addiction": 0.5, "health": -1, "dignity": -1, "sanity": 3, "od": 0.0,
		"decay": 0.08, "hunger_rate": 0.7, "fatigue_rate": 1.0, "visible": 0.3, "color": Color("c8a070"),
		"malviaje": {"cordura": 45.0, "chance": 0.4, "sanity": -12, "minutes": 90},
		"resaca": {"dosis": 0.2, "horas": 6, "mente": 0.0, "fx": {"drowsy": 0.3}, "text": "agotado, como después de un viaje largo"},
		"fx": {"psico": 0.7, "slowmo": 0.3, "drift": 0.3}, "fx_text": "las paredes respiran y los colores se mueven"},
	"lsd": {"name": "LSD", "price": 10, "high": 50, "addiction": 0.3, "health": -1, "dignity": -1, "sanity": 2, "od": 0.0,
		"decay": 0.045, "hunger_rate": 0.6, "fatigue_rate": 0.2, "visible": 0.3, "color": Color("f070d0"),
		"malviaje": {"cordura": 45.0, "chance": 0.5, "sanity": -18, "minutes": 150},
		"resaca": {"dosis": 0.2, "horas": 8, "mente": -0.3, "fx": {"drowsy": 0.4}, "text": "agotado y con la cabeza en otra parte"},
		"fx": {"psico": 1.0, "saturate": 0.5, "speed": 0.05}, "fx_text": "todo late, se funde y tiene un sentido que no sabrías explicar"},
	# disociativo: el «agujero K», corto e intenso
	"ketamina": {"name": "Ketamina", "price": 15, "high": 35, "addiction": 3, "health": -3, "dignity": -3, "sanity": 1, "od": 0.3,
		"decay": 0.25, "hunger_rate": 1.0, "fatigue_rate": 1.2, "visible": 0.5, "color": Color("a0b8d0"),
		"mezcla": ["litrona", "caballo", "ansioliticos", "tramadol"],
		"resaca": {"dosis": 0.4, "horas": 6, "mente": -0.8, "fx": {"drift": 0.3, "clumsy": 0.4}, "text": "te cuesta enhebrar las ideas"},
		"fx": {"disocia": 1.0, "speed": -0.4, "drift": 0.6, "slowmo": 0.4}, "fx_text": "el cuerpo va por un lado y tú por otro"},
	# de farmacia: con receta del CAP (Interactions, "farmacia") o de estraperlo
	"ansioliticos": {"name": "Ansiolíticos", "price": 2, "high": 20, "addiction": 4, "health": -1, "dignity": 0, "sanity": 4, "od": 0.25,
		"decay": 0.06, "fatigue_rate": 1.8, "visible": 0.05, "color": Color("b0a0e0"),
		"mezcla": ["litrona", "caballo", "tramadol", "ketamina"],
		"resaca": {"dosis": 0.3, "horas": 8, "mente": -0.3, "fx": {"drowsy": 0.6, "lag": 0.3}, "text": "lento y en una nube"},
		"fx": {"paranoia": -1.0, "drowsy": 0.4, "speed": -0.15, "lag": 0.3}, "fx_text": "nada te da miedo ni prisa"},
	# antidepresivos: casi no se notan, pero tomados cada día suben la cabeza (`sanity_rate`, por
	# minuto a tope); dejarlos de golpe da su síndrome (el mono)
	"antidepresivos": {"name": "Antidepresivos", "price": 1, "high": 12, "addiction": 1.5, "health": 0, "dignity": 0, "sanity": 1, "od": 0.0,
		"decay": 0.008, "visible": 0.0, "color": Color("90d0b0"), "sanity_rate": 0.012,
		"fx": {}, "fx_text": "no se nota nada, pero la cabeza aguanta un poco más"},
	"tramadol": {"name": "Tramadol", "price": 3, "high": 25, "addiction": 5, "health": -2, "dignity": -1, "sanity": 2, "od": 0.4,
		"decay": 0.07, "hunger_rate": 0.8, "fatigue_rate": 1.6, "visible": 0.1, "color": Color("d0a0a0"),
		"relieves": "caballo", "mono": -25, "relief_addiction": 0,
		"mezcla": ["litrona", "caballo", "ansioliticos", "ketamina"],
		"resaca": {"dosis": 0.3, "horas": 6, "mente": -0.3, "fx": {"drowsy": 0.4}, "text": "pesado y con náuseas"},
		"fx": {"speed": -0.2, "sway": 0.4, "drowsy": 0.2}, "fx_text": "un algodón por dentro: se apagan el dolor y el mono"},
	# un cigarro: casi nada, pero engancha y calma las manos (el temblor en negativo)
	"tabaco": {"name": "Tabaco", "price": 1, "high": 8, "addiction": 2, "health": -1, "dignity": 0, "sanity": 1, "od": 0.0,
		"decay": 0.15, "hunger_rate": 0.8, "visible": 0.0, "color": Color("b0b0a0"),
		"fx": {"shake": -0.25}, "fx_text": "las manos dejan de temblar un rato"},
	# solo mientras dura el suceso «Llega el fentanilo» (`suceso`): parches baratísimos; cada
	# dosis tiene su riesgo de sobredosis aunque no vayas colocado (`od_base`)
	"fentanilo": {"name": "Fentanilo", "price": 3, "high": 60, "addiction": 10, "health": -8, "dignity": -5, "sanity": 3, "od": 1.5,
		"od_base": 0.12, "suceso": "fentanilo",
		"decay": 0.08, "hunger_rate": 0.6, "fatigue_rate": 2.5, "visible": 0.3, "color": Color("c06060"),
		"relieves": "caballo", "mono": -60, "relief_addiction": 0,
		"mezcla": ["litrona", "caballo", "ansioliticos", "tramadol", "ketamina"],
		"fx": {"speed": -0.5, "sway": 1.2, "drowsy": 0.6}, "fx_text": "un peso enorme: todo se apaga, también tú"},
})
## Mal viaje (las que tienen `malviaje`: con la salud mental por debajo de `cordura`, o a veces
## sin más, el viaje se tuerce): sus efectos durante sus `minutes`.
const MALVIAJE_FX := {"paranoia": 1.0, "tunnel": 0.5, "shake": 0.3, "psico": 0.5}
const MALVIAJE_FX_TEXT := "todo se vuelve contra ti: caras que miran, paredes que se cierran"
const MALVIAJE_SIEMPRE := 0.08  ## probabilidad de mal viaje aunque tengas la cabeza bien
## Mezclar depresores (`mezcla`: si alguna de esas va fuerte, por encima de 0,3) multiplica el
## riesgo de sobredosis: se suma esta probabilidad (por la `od` de la sustancia).
const MEZCLA_OD := 0.25
## Resaca (las que tienen `resaca`): cada dosis suma `dosis` de resaca pendiente; al dormir
## (al menos RESACA_SUENO minutos) se convierte en resaca de verdad, de nivel hasta RESACA_MAX
## y que dura `horas` (por el nivel), con sus efectos (`fx`) y lo que te baja la mente por
## hora (`mente`). Con `se_quita`, meterte otra vez lo mismo te la quita a medias (la del perro).
const RESACA_SUENO := 90.0
const RESACA_MAX := 1.5
const RESACA_VITALIDAD := 20.0  ## vitalidad máxima que quita una resaca a tope
## Lo que te dan en la farmacia con la receta del médico del CAP: [unidades, euros]. El médico
## te hace una cada RECETA_DIAS días (de estraperlo, a los yonkis: Defs.YONKI_STASH).
static var RECETA := Equilibrio.aplicar("receta", {
	"antidepresivos": {"cantidad": 14, "precio": 3},
	"ansioliticos": {"cantidad": 10, "precio": 3},
	"tramadol": {"cantidad": 10, "precio": 4},
})
const RECETA_DIAS := 7
## Salud mental de Mari Loli al tomarse sus pastillas: para ella son medicación.
const MEDS_SANITY := 10

## Efectos del mono (de cualquier sustancia) y del bajón de las que tienen `crash`.
const MONO_FX := {"shake": 0.35, "clumsy": 1.0, "speed": -0.2}
const MONO_FX_TEXT := "temblores, viñeta roja y torpeza"
const CRASH_FX := {"speed": -0.35, "tunnel": 1.0}
const CRASH_FX_TEXT := "todo pesa y se oscurece"

## Efectos del cuerpo cuando una barra pasa de `from` hacia `to` (intensidad 0..1).
const BODY_FX := {
	"fatigue": {"from": 60.0, "to": 100.0, "name": "Sueño", "text": "se te cierran los ojos y vas torpe",
		"fx": {"drowsy": 1.0, "speed": -0.25}},
	"hunger": {"from": 70.0, "to": 100.0, "name": "Hambre", "text": "flojera y visión de túnel",
		"fx": {"speed": -0.2, "tunnel": 0.6}},
	"sanity": {"from": 30.0, "to": 0.0, "name": "Salud mental", "text": "la realidad se descuadra y oyes cosas",
		"fx": {"paranoia": 1.0}},
	# horas pasando hambre de verdad (GameState.starving)
	"starving": {"from": 4.0, "to": 48.0, "name": "Inanición", "text": "te fallan las piernas, tiemblas y todo se apaga",
		"fx": {"speed": -0.35, "tunnel": 0.8, "shake": 0.35, "drowsy": 0.5, "clumsy": 0.6}},
}

## Lo que vende cada camello (el resto se consigue por otras vías).
const DEALER_STOCK := ["porro", "pastillas", "setas", "lsd", "speed", "mdma", "ketamina", "farlopa", "base", "caballo", "fentanilo"]

## Precios de lo que se compra o se cobra en las acciones (scripts/interactions.gd), en euros:
## `precio` y, si va por unidades, `cantidad`; `que` lo explica en el diseñador de sustancias.
## Lo que vende el camello va por `price` de cada sustancia, y el compraventa por `sell` de cada objeto.
static var PRECIOS := Equilibrio.aplicar("precios", {
	"super_bocadillo": {"precio": 3, "que": "Súper: un bocadillo"},
	"super_litrona": {"precio": 2, "que": "Súper: una litrona"},
	"farmacia_ibuprofeno": {"precio": 3, "que": "Farmacia: ibuprofeno (+5 salud)"},
	"bar_carajillo": {"precio": 2, "que": "Bar: un carajillo (como una litrona)"},
	"bar_tabaco": {"precio": 6, "cantidad": 20, "que": "Bar: paquete de tabaco de la máquina (cigarros)"},
	"kebab_durum": {"precio": 4, "que": "Kebab: un dürüm"},
	"yonki_movil": {"precio": 8, "que": "Yonki: comprarle un móvil robado"},
	"mantero_gafas": {"precio": 5, "que": "Mantero: comprarle unas gafas"},
	"vender_gafas": {"precio": 10, "que": "Despedida: venderles unas gafas de mantero (te pagan)"},
	"latero_lata": {"precio": 1, "que": "Latero: comprarle una lata"},
	"latero_alijo": {"precio": 5, "que": "Latero: ayudarle a esconder el alijo (te paga)"},
	"trilero_apuesta": {"precio": 10, "que": "Trilero: lo que apuestas a la bolita"},
	"carterista_clase": {"precio": 20, "que": "Carterista: que te enseñe"},
	"carterista_cartera": {"precio": 12, "que": "Carterista: venderle la cartera con papeles (te paga)"},
	"estatua_moneda": {"precio": 1, "que": "Estatua humana: la moneda del platillo"},
	"club_cannabico": {"precio": 10, "cantidad": 2, "que": "Captador: que te lleve al club cannábico (porros)"},
	"rosa": {"precio": 2, "que": "Vendedor de rosas: una rosa"},
	"caricatura": {"precio": 5, "que": "Caricaturista: que te haga una caricatura"},
	"club_cuota": {"precio": 20, "que": "Asociación cannábica: la cuota de socio"},
	"club_porro": {"precio": 5, "que": "Asociación cannábica: un porro (solo a socios)"},
})

static var ITEMS := Equilibrio.aplicar("objetos", {
	"movil": {"name": "Móvil", "sell": 18},  # robado y bloqueado: el compraventa paga poco
	"movil_roto": {"name": "Móvil con la pantalla rota", "sell": 6},
	"cartera": {"name": "Cartera ajena", "sell": 0},
	"anillo": {"name": "Anillo de boda", "sell": 60},
	"cobre": {"name": "Cable de cobre", "sell": 8},
	"gafas": {"name": "Gafas de sol de mantero", "sell": 1},
	## food = hambre que quita (y un poco de salud)
	"bocadillo": {"name": "Bocadillo", "sell": 0, "food": 35},
	"durum": {"name": "Dürüm", "sell": 0, "food": 50},
	"sobras": {"name": "Sobras", "sell": 0, "food": 20},
	# de los encargos (scripts/errands.gd)
	"paquete": {"name": "Paquete del camello", "sell": 0},
	"cartera_caliente": {"name": "Cartera caliente", "sell": 0},
	"papeles_albergue": {"name": "Papeles del albergue", "sell": 0},  # de la cita en el CAS
	"receta": {"name": "Receta del médico de cabecera", "sell": 0},
	"naloxona": {"name": "Naloxona (para una sobredosis)", "sell": 0},  # la reparten las educadoras cuando llega el fentanilo  # del CAP: ansiolíticos, antidepresivos o tramadol en la farmacia
	# de las misiones de los personajes (scripts/misiones.gd)
	"pasaporte": {"name": "Pasaporte de Grzegorz", "sell": 0},
	"acordeon": {"name": "Acordeón", "sell": 25},  # el compraventa también lo quiere
	"pruebas_piso": {"name": "Pruebas del piso de Sant Ramon", "sell": 0},
	# de la calle (scripts/street_items.gd)
	"chatarra": {"name": "Chatarra", "sell": 3},
	"bici": {"name": "Bici ajena", "sell": 15},
	"patinete": {"name": "Patinete eléctrico", "sell": 28},
})

## Objetos tirados por la calle (scripts/street_items.gd). `weight` = lo a menudo que aparece;
## `night` multiplica ese peso de noche; `near` = tipo de lugar junto al que suele estar (se
## pierden móviles a la salida de los bares); `minutes` = lo que tardas en llevártelo; `risk` =
## probabilidad de que quien te vea llevártelo (con su cono de visión) monte un escándalo; `fake` = lo que era en
## realidad cuando, ido, confundes basura con ese objeto (sin `fake`, nunca se confunde).
const STREET_ITEMS := {
	"movil": {"weight": 2.0, "night": 3.0, "near": "bar", "minutes": 1,
		"found": "Un móvil en el suelo. Alguien de fiesta lo va a echar de menos.",
		"fake": "una piedra negra y lisa"},
	"movil_roto": {"weight": 2.0, "minutes": 1,
		"found": "Un móvil con la pantalla hecha añicos, tirado junto a un alcorque.",
		"fake": "un trozo de baldosa"},
	"cartera": {"weight": 0.7, "night": 2.0, "near": "bar", "minutes": 1,
		"found": "¡Una cartera perdida!",
		"fake": "un cartón doblado"},
	"cobre": {"weight": 2.0, "minutes": 10,
		"found": "Un rollo de cable de una obra. Lo pelas en un portal.",
		"fake": "un trozo de manguera"},
	"chatarra": {"weight": 3.0, "minutes": 5,
		"found": "Chatarra: un somier, dos tuberías y una sartén sin mango."},
	"bici": {"weight": 1.2, "minutes": 8, "risk": 0.5,
		"found": "Una bici con un candado de risa. Dos tirones y es tuya."},
	"patinete": {"weight": 0.6, "night": 1.5, "minutes": 8, "risk": 0.7,
		"found": "Un patinete eléctrico apoyado en una persiana. Sin candado."},
	"sobras": {"weight": 1.5, "night": 1.5, "near": "kebab", "minutes": 1,
		"found": "Media pizza en su caja, encima de un contenedor. Aún templada."},
}
const STREET_JUNK_WEIGHT := 9.0  ## basura (bolsas, cartones): lo que más hay por el suelo
const STREET_ITEMS_COUNT := 45  ## objetos tirados a la vez por el barrio
const STREET_ITEM_HOURS := 10.0  ## horas que dura algo en el suelo antes de que se lo lleve otro
const STREET_SPAWN_AWAY := 18  ## casillas: los nuevos aparecen lejos, no delante de tus narices
## Confundir lo que ves (GameState.befuddlement() de 0 a 1): probabilidad, del todo ido, de que
## un objeto te parezca otra cosa (basura que parece un móvil, o un móvil que parece basura).
const MISSEE_PER_BEFUDDLEMENT := 0.6
## Por debajo de esta cabeza ida, miras bien lo que llevas y descubres las piedras.
const FAKE_REVEAL_BELOW := 0.12

## Trapicheo (scripts/trade.gd): revender a otros lo que compras al camello. Por tipo de
## cliente: `wants` = lo que te compra; `markup` = cuánto paga sobre el precio del camello.
## Solo compra si lleva bastante dinero encima (los yonkis, para poco más que unas pastillas).
static var CLIENTS := Equilibrio.aplicar("clientes", {
	"fiestero": {"wants": ["farlopa", "mdma", "ketamina", "speed", "porro", "pastillas", "tabaco"], "markup": 1.7},
	"turista": {"wants": ["porro", "setas"], "markup": 2.5},
	"yonki": {"wants": ["pastillas", "ansioliticos", "tramadol", "porro", "litrona", "speed", "tabaco"], "markup": 1.5},
	"pudiente": {"wants": ["farlopa", "mdma", "ketamina", "lsd", "porro"], "markup": 2.0},
})
const REGULAR_BONUS := 0.1  ## lo que paga de más un cliente por cada vez que ya te compró...
const REGULAR_MAX := 3  ## ... hasta este número de veces
## Cortarla: vendes al mismo precio, pero solo gastas tu dosis con esta probabilidad (de media
## sacas más). El cliente se da cuenta y no se le olvida.
const CUT_KEEPS := 0.5
## Guiris que en realidad son secretas (tirada fija por nombre): venderles es acabar detenido.
const UNDERCOVER_CHANCE := 0.07
## Vender delante de un camello (casillas, y que te vea) es pisarle el terreno: viene a cobrárselo.
const TURF_CELLS := 25
## Trueque con otros yonkis: lo que llevan encima (una sustancia, fija por nombre, 1-2 dosis al
## día) y cuánto valoran tus objetos respecto a lo que te da el compraventa (los revenden ellos).
const YONKI_STASH := ["caballo", "base", "pastillas", "porro", "litrona", "speed", "ansioliticos", "tramadol"]

## Lo que consumen los bots (scripts/consumo.gd). Por tipo: `usa` = probabilidad de cada
## sustancia (tirada fija por nombre; lo que falta hasta 1, nada) y `enganche` = [mín, máx] del
## que tiene. Los niños, los chavales, la policía, los perros y quien trabaja en lo social no
## están: no se les simula consumo (con los chavales solo se puede ayudar).
static var NPC_HABITS := Equilibrio.aplicar("habitos", {
	"yonki": {"usa": {"caballo": 0.3, "base": 0.25, "pastillas": 0.1, "litrona": 0.1, "speed": 0.1, "tramadol": 0.1, "ansioliticos": 0.05}, "enganche": [40.0, 90.0]},
	"mendigo": {"usa": {"litrona": 0.4, "caballo": 0.1, "tramadol": 0.05, "tabaco": 0.15}, "enganche": [25.0, 70.0]},
	"punki": {"usa": {"litrona": 0.35, "speed": 0.2, "porro": 0.15, "setas": 0.1, "lsd": 0.1, "tabaco": 0.1}, "enganche": [20.0, 60.0]},
	"camello": {"usa": {"farlopa": 0.3, "porro": 0.2, "tabaco": 0.2}, "enganche": [10.0, 40.0]},
	"fiestero": {"usa": {"litrona": 0.4, "farlopa": 0.15, "mdma": 0.2, "ketamina": 0.1, "speed": 0.05, "lsd": 0.05, "tabaco": 0.05}, "enganche": [5.0, 30.0]},
	"pudiente": {"usa": {"farlopa": 0.25, "mdma": 0.1, "ketamina": 0.1, "ansioliticos": 0.1}, "enganche": [5.0, 40.0]},
	"turista": {"usa": {"litrona": 0.3, "porro": 0.15, "setas": 0.05}, "enganche": [0.0, 15.0]},
	"vecino": {"usa": {"tabaco": 0.25, "litrona": 0.12, "ansioliticos": 0.08, "antidepresivos": 0.08, "pastillas": 0.05, "porro": 0.05}, "enganche": [5.0, 35.0]},
	"anciano": {"usa": {"ansioliticos": 0.15, "antidepresivos": 0.1, "pastillas": 0.1, "tabaco": 0.1, "litrona": 0.1}, "enganche": [10.0, 40.0]},
	"latero": {"usa": {"litrona": 0.2, "tabaco": 0.2}, "enganche": [5.0, 30.0]},
	"trilero": {"usa": {"porro": 0.2, "farlopa": 0.1, "tabaco": 0.2}, "enganche": [5.0, 30.0]},
	"carterista": {"usa": {"speed": 0.15, "porro": 0.15, "tabaco": 0.1}, "enganche": [10.0, 40.0]},
	"chatarrero": {"usa": {"litrona": 0.2, "tabaco": 0.3}, "enganche": [10.0, 40.0]},
	"mensajero": {"usa": {"speed": 0.1, "porro": 0.1, "tabaco": 0.2}, "enganche": [5.0, 30.0]},
	"skater": {"usa": {"porro": 0.4, "tabaco": 0.1, "lsd": 0.05}, "enganche": [5.0, 30.0]},
	"captador": {"usa": {"porro": 0.25, "speed": 0.1, "tabaco": 0.1}, "enganche": [5.0, 30.0]},
	"musico": {"usa": {"porro": 0.2, "litrona": 0.15, "tabaco": 0.15}, "enganche": [5.0, 30.0]},
	"caricaturista": {"usa": {"porro": 0.1, "litrona": 0.1, "tabaco": 0.2}, "enganche": [5.0, 25.0]},
})
const NPC_PERSONAJE_ENGANCHE := [30.0, 70.0]  ## el de los personajes del editor que quieren algo
const NPC_STEP := 15.0  ## minutos de cada tramo al simular (también al despertar a un latente)
const NPC_MONO_RATE := 0.004  ## mono por minuto y punto de enganche sin colocón (como el jugador)
const NPC_ADDICTION_GAIN := 0.3  ## parte del enganche de la sustancia que le suma cada dosis
const NPC_USE_AT := 30.0  ## mono a partir del cual se mete lo que lleva (o sale a pillar)
const NPC_SCORE_PER_HOUR := 0.35  ## probabilidad por hora de conseguir algo si no lleva nada
const NPC_ASK_AT := 55.0  ## mono (sin nada encima) a partir del cual viene a pedirte o a comprarte...
const NPC_ROB_AT := 85.0  ## ... y a partir del cual, si no tiene con qué pagar, te da el tirón
const NPC_MONO_PAYS := 0.6  ## lo que paga de más por lo suyo con el mono a tope
const NPC_NOD := 0.7  ## colocón (0..1) de caballo, pastillas o alcohol desde el que cabecea
const NPC_NOD_SECONDS := Vector2(8.0, 25.0)  ## lo que se queda dormido en un portal
const NPC_BRONCA := 0.6  ## colocón (0..1) de farlopa, base o speed desde el que busca bronca...
const NPC_BRONCA_TRAIT := 0.4  ## ... solo una parte de ellos (fija por nombre), y con agresividad
const NPC_TIRON_MAX := 12  ## euros que te quita como mucho de un tirón si no llevas nada suyo
const NPC_FIGHT_UPPER := 0.15  ## lo que baja ganarle una pelea si va a tope de farlopa, base o speed...
const NPC_FIGHT_DOWNER := 0.2  ## ... lo que sube si va a tope de caballo, pastillas o alcohol...
const NPC_FIGHT_MONO := 0.1  ## ... y si tiene el mono a tope
## Lo que dicen al pasar colocados (por sustancia) o con mono.
const NPC_DRUG_LINES := {
	"litrona": ["¡Otra ronda!", "Tú eres mi amigo, ¿eh?", "¿Dónde está el bar?"],
	"porro": ["Qué bien se está aquí...", "Tengo un hambre...", "Jajaja, ¿has visto eso?"],
	"pastillas": ["Estoy... bien, estoy bien.", "Mmm...", "¿Qué día es hoy?"],
	"farlopa": ["¿Qué miras?", "Yo controlo, yo controlo.", "¡Vamos, vamos, vamos!"],
	"base": ["¿Tienes más? ¿Tienes más?", "Ahora vuelvo.", "Esto es lo mejor del mundo."],
	"caballo": ["...", "Déjame aquí un rato.", "Estoy bien, tío..."],
	"speed": ["Tengo mil cosas que hacer.", "¡No paro, no paro!", "¿Hablamos? Hablamos."],
	"mdma": ["¡Te quiero, tío!", "Todo está bien...", "Qué bonito es todo."],
	"metadona": ["Voy tirando.", "Mañana, al CAS.", "Ni fu ni fa."],
	"setas": ["¿Tú también ves eso?", "Jajaja... los árboles...", "Todo está conectado, tío."],
	"lsd": ["Los colores... ¿los oyes?", "Llevo diez horas despierto.", "La ciudad respira."],
	"ketamina": ["¿Dónde... estoy?", "Mis piernas no son mías.", "Mmmmm..."],
	"ansioliticos": ["Todo bien, todo tranquilo.", "Me da igual, la verdad.", "Mmm..."],
	"antidepresivos": ["Ahí vamos.", "Hoy no es un mal día.", "Tirando."],
	"tramadol": ["Ya no me duele nada.", "Voy despacito.", "Qué bien se está..."],
	"tabaco": ["¿Tienes fuego?", "Uno y lo dejo.", "*fuma*"],
	"mono": ["Estoy fatal...", "¿Tienes algo? Lo que sea.", "Me duelen hasta los huesos."],
}
const YONKI_ITEM_VALUE := 1.5

## Encargos de los personajes (scripts/errands.gd). `giver` = tipo de bot que lo ofrece;
## `place` = tipo de lugar del mapa al que hay que ir; `window` = [desde, hasta] en horas desde
## que lo aceptas (desde 0: vale en cuanto llegues); `at` = cita a horas fijas del día siguiente.
## Una hora de juego son 30 s reales: los plazos son cortos para que se pisen.
const ERRANDS := {
	"paquete": {"giver": "camello", "place": "bar", "window": [0.0, 1.5],
		"money": 25, "debt": 40, "debt_opened": 60, "heat": 20},
	"cartera": {"giver": "carterista", "place": "compraventa", "window": [0.0, 1.0],
		"money": 20, "heat": 40},
	"juerga": {"giver": "fiestero", "place": "bar", "window": [1.0, 2.0], "money": 40},
	"cita": {"giver": "educador", "place": "cas", "at": [10, 11],
		"dignity": 8, "sanity": 10, "mono": 15, "dignity_fail": -3, "sanity_fail": -5},
	# peticiones de la gente corriente; `share` = parte de los de ese tipo que te la piden
	# (siempre los mismos), para que la calle no se llene de «!»
	"receta": {"giver": "anciano", "place": "farmacia", "window": [0.0, 1.5], "share": 0.25,
		"money": 6, "dignity": 4, "dignity_fail": -2},
	"camino": {"giver": "turista", "place": "iglesia", "window": [0.0, 1.0], "share": 0.15,
		"money": 8, "dignity": 1},
	"compra": {"giver": "vecino", "place": "super", "window": [0.0, 1.5], "share": 0.15,
		"advance": 20, "money": 5, "dignity": 3, "dignity_fail": -4},
	"perro": {"giver": "vecino", "place": "kebab", "window": [0.0, 2.0], "share": 0.1,
		"money": 10, "dignity": 3},
	"pelota": {"giver": "nino", "place": "bar", "window": [0.0, 1.0], "share": 0.3,
		"money": 0, "dignity": 2, "sanity": 4},
	"direccion": {"giver": "mensajero", "place": "farmacia", "window": [0.0, 0.5], "share": 0.3,
		"money": 3, "dignity": 1},
}
const ERRAND_MIN_DISTANCE := 60  ## casillas: el sitio del encargo no está a la vuelta de la esquina
const ERRAND_MAX_DISTANCE := 300  ## ... ni más lejos de lo que se anda en hora y media

## Memoria poco fiable (libreta y reloj del HUD). Casi siempre es fiable: los fallos dependen
## de lo ido que vas (GameState.befuddlement(), de 0 sobrio y descansado a 1 del todo ido).
const SLIP_BASE := 0.03  ## probabilidad de apuntar mal un encargo estando sereno
const SLIP_PER_BEFUDDLEMENT := 0.45  ## lo que suma a esa probabilidad ir del todo ido
const FORGET_PER_HOUR := 0.04  ## probabilidad por hora y entrada (del todo ido) de que se borre un dato
const BLUR_FROM := 0.25  ## por debajo, la libreta se lee bien
const BLUR_MAX := 0.4  ## proporción máxima de palabras que no se leen
const MONEY_LIE_FROM := 0.6  ## ido de aquí para arriba, el HUD solo dice «¿unos X?» € (y a veces se equivoca)
const MONEY_LIE := 0.4  ## lo que se puede desviar esa cuenta (proporción)
const STREET_LIE := 0.6  ## (del todo ido) probabilidad de que la placa diga otra calle al cambiar de calle
## Pistas de las conversaciones en la libreta: las que se ven y cuánto duran (la policía se mueve).
const PISTAS_SHOWN := 5
const PISTA_HOURS := 6.0
const CLOCK_LIE_PER_HOUR := 0.3  ## probabilidad por hora (del todo ido) de que el reloj mienta un rato

## Los bots fuera de la pantalla que no tienen nada contigo se actualizan cada tantos frames
## (con el tiempo acumulado): andan y piensan igual, pero cuestan una fracción.
const OFFSCREEN_EVERY := 6

## Minijuegos de habilidad (scripts/minigames/). La dificultad (0..1) sale de la probabilidad
## que tenía la acción (1 - p): lo que antes era una tirada ahora se juega, con las mismas
## circunstancias a favor y en contra (agentes mirando, la noche, el colocón, el oficio).
## Robar al descuido (Pickpocket): una mano (WASD) le distrae, la otra (ratón) le saca el botín.
const PICK_SECONDS := 15.0  ## lo que tarda en irse la víctima
const PICK_EXTRACT := 1.6  ## segundos con el botón pulsado en el bolsillo para sacarlo (más si es difícil)
const PICK_SUSPICION := 0.9  ## sospecha por segundo si te ve de lleno la mano en su bolsillo
const PICK_INTEREST := 0.004  ## interés por píxel que mueves la mano que distrae (llena = te mira a ella)
const PICK_BORED := 0.4  ## interés que pierde por segundo (se aburre de la misma mano)
## Hacer de vigía (Lookout): pasa gente por la calle; clic izquierdo a la policía (¡agua!) y
## clic derecho a los clientes. Las secretas van de paisano: se tocan el pinganillo y miran.
const LOOKOUT_SECONDS := 40.0
const LOOKOUT_SPAWN := Vector2(1.4, 2.8)  ## segundos entre uno que pasa y el siguiente
const LOOKOUT_THREATS := 0.22  ## proporción de agentes entre los que pasan (más con dificultad)
const LOOKOUT_UNDERCOVER := 0.5  ## de los agentes, los que van de paisano (más con dificultad)
const LOOKOUT_CLIENTS := 0.25  ## proporción de clientes
const LOOKOUT_FALSE_PENALTY := 0.25  ## lo que se descuenta de la paga cada falsa alarma
const LOOKOUT_CLIENT_TIP := 2  ## euros por cada cliente que atraes
## Pelea (Fight): cara a cara, esquivar con A/D hacia el lado contrario del puño y pegar con el
## clic cuando falla. Las medidas de los golpes están en fight.gd.
const BEATING_FIGHT_CHANCE := 0.25  ## quitarte de encima a quien te viene a dar una paliza

## Títulos finales según la caída acumulada.
const TITLES := [
	[0, "Turista accidental"],
	[60, "Habitual del barrio"],
	[150, "Carne de cajero"],
	[300, "Fauna del Raval"],
	[500, "Leyenda de Ciutat Vella"],
	[800, "Patrimonio inmaterial de la Humanidad"],
]

## Hitos de la caída: se cuentan una sola vez.
const MILESTONES := {
	"primera_calle": ["Primera noche al raso", 15],
	"cajero": ["Dormir en un cajero", 10],
	"primer_robo": ["Primer palo", 10],
	"primera_detencion": ["Primera noche en el calabozo", 20],
	"sobras": ["Comer sobras ajenas", 5],
	"rebuscar": ["Rebuscar en la basura", 5],
	"sobredosis": ["Sobrevivir a una sobredosis", 25],
	"anillo": ["Empeñar el anillo de boda", 20],
	"chivato": ["Chivarse a la policía", 15],
	"papa_corta": ["Papá te corta el grifo", 25],
	"pelea_perdida": ["Perder una pelea con otro yonki", 10],
	"fondo": ["Tocar fondo (dignidad 0)", 50],
	"deuda": ["Deber dinero a un camello", 10],
	"desmayo": ["Desmayarte de hambre", 10],
	"frito": ["Quedarte frito en plena calle", 10],
	"psiquiatrico": ["Ingreso en el psiquiátrico", 30],
	"trile": ["Picar en el trile", 5],
	"aprendiz": ["Aprender el oficio de carterista", 10],
	"despedida": ["Colarte en una despedida de soltero", 5],
	"paquete": ["Meterte la mercancía de un camello", 10],
	"bici": ["Llevarte una bici ajena", 5],
	"piedra": ["Intentar vender una piedra", 5],
	"camello": ["Pasar tu primera papela", 10],
	"cortar": ["Vender mercancía cortada", 5],
	"secreta": ["Venderle un porro a un secreta", 15],
	"multa": ["Primera multa de la Urbana", 5],
	"desalojo": ["Que la Urbana te despierte en la calle", 10],
	"estatua": ["Hacer reír a una estatua", 3],
	"flyers": ["Repartir flyers por la Rambla", 5],
	"socio_club": ["Hacerte socio de un club cannábico", 3],
	"redada_club": ["Caer en una redada de un club cannábico", 6],
	"relevo": ["Tomar el relevo de otro yonki", 5],
	"proposito_perdido": ["Perder para siempre lo que buscabas", 20],
	"altar_monedas": ["Coger las monedas del altar de un compañero", 12],
	# conocer una sustancia nueva (las que ya conoce el perfil no cuentan)
	"probar_litrona": ["Empezar a beber en la calle", 3],
	"probar_porro": ["Probar los porros", 3],
	"probar_pastillas": ["Probar las pastillas", 5],
	"probar_farlopa": ["Probar la farlopa", 8],
	"probar_base": ["Probar la base", 10],
	"probar_caballo": ["Probar el caballo", 10],
	"probar_metadona": ["Entrar en el programa de metadona", 5],
	"probar_speed": ["Probar el speed", 6],
	"probar_mdma": ["Probar el MDMA", 5],
	"probar_setas": ["Probar las setas", 3],
	"probar_lsd": ["Tu primer tripi", 4],
	"probar_ketamina": ["Probar la ketamina", 6],
	"probar_ansioliticos": ["Ansiolíticos para tirar", 4],
	"probar_antidepresivos": ["Empezar con los antidepresivos", 2],
	"probar_tramadol": ["Probar el tramadol", 6],
	"probar_tabaco": ["Volver a fumar", 1],
	"probar_fentanilo": ["Probar el fentanilo", 15],
	"naloxona": ["Que te salve la naloxona", 10],
	"salvar_vida": ["Salvarle la vida a alguien con naloxona", 5],
	"malviaje": ["Un mal viaje", 8],
	"mezcla": ["Mezclar depresores", 8],
}


static func profile(id: String) -> Dictionary:
	for p in PROFILES:
		if p["id"] == id:
			return p
	return PROFILES[0]


## Asociaciones cannábicas (Interactions._club): clubs privados en las direcciones del Raval
## que salen en los directorios (tools/clubs_cannabicos.json). Sin rótulo: hasta que llamas,
## o te lleva un captador, son una puerta más. Solo venden a socios, con un tope por día.
const CLUB_DIGNIDAD := 30.0  ## por debajo, en la mirilla no te dejan ni hablar
const CLUB_AVAL := 0.35  ## sin captador, probabilidad de que algún socio te avale al pedirlo
const CLUB_LIMITE_DIA := 3  ## porros que te venden al día
## Redadas: probabilidad cada vez que compras o fumas dentro (en 2024 el Ayuntamiento ordenó
## cerrar 30 clubs); te identifican, se llevan lo que llevas y precintan el local unos días.
const CLUB_REDADA := 0.04
const CLUB_PRECINTO_DIAS := Vector2i(3, 12)

## Lo que cuesta (o te pagan por) una acción de PRECIOS.
static func precio(id: String) -> int:
	return PRECIOS[id]["precio"]


static func item_name(id: String) -> String:
	if SUBSTANCES.has(id):
		return SUBSTANCES[id]["name"]
	if ITEMS.has(id):
		return ITEMS[id]["name"]
	return id


## Si un objeto del inventario se puede usar (meterse, comer, vaciar).
static func usable(id: String) -> bool:
	return SUBSTANCES.has(id) or ITEMS.get(id, {}).has("food") or id in ["cartera", "paquete", "bici"]


static func title_for(caida: float) -> String:
	var t: String = TITLES[0][1]
	for entry in TITLES:
		if caida >= entry[0]:
			t = entry[1]
	return t


## Convierte un índice de criminalidad (1.0 = barrio mediano) en un multiplicador suave.
static func crime_factor(index: float) -> float:
	return clampf(1.0 + 0.3 * log(maxf(index, 0.01)) / log(2.0), 0.5, 3.5)


# ------------------------------------------------------------------ propósitos

## Lo que quiere conseguir cada perfil, además de pasar un día más (scripts/proposito.gd).
## Por pasos, en orden; cada paso es de un tipo:
##   "enviar": mandar `total` € (de `minimo` en `minimo` como poco) desde un sitio de `lugar`
##     (tipos de Interactions.POI_LABELS), con la acción `accion`.
##   "ir": ir a un sitio de `lugar` entre las `desde` y las `hasta` h, `veces` días distintos,
##     con la acción `accion` (dura `minutos`). Con `sobrio`, no cuenta si vas colocado (por
##     encima de PROPOSITO_SOBRIO) y, si además `estricto`, lo pierdes para siempre. `efecto`:
##     algo que pasa al hacerlo ("sin_paga": papá deja de ingresarte).
##   "tener": tener el objeto `objeto` en el inventario.
##   "barra": aguantar `dias` días seguidos (empezando por el de hoy) sin que falle ninguna
##     condición de `cond`: {"stat": campo de GameState, "min"/"max"}, {"limpio": sustancia}
##     (sin pasar de PROPOSITO_LIMPIO de colocón) o {"no_fichado": true}.
## `falla` = lo que lo pierde para siempre (es un hito): "detenido" (otra detención desde que
## empezó), "ingreso" (otro ingreso en el psiquiátrico) o {"dignidad": mínimo}. `final` = el
## texto del final «CUMPLIDO»; `perdido` = lo que dice al perderlo.
const PROPOSITOS := {
	"sin_papeles": {
		"titulo": "Mandar dinero a casa y conseguir los papeles",
		"pasos": [
			{"tipo": "enviar", "texto": "mandar 150 € a casa", "lugar": ["cajero"], "total": 150, "minimo": 20,
				"accion": "Mandar dinero a casa (envío)"},
			{"tipo": "ir", "texto": "ir dos días a la asesoría de extranjería del servicio social (9 a 14 h) a por el informe de arraigo",
				"lugar": ["albergue"], "desde": 9, "hasta": 14, "veces": 2, "minutos": 90,
				"accion": "Pedir el informe de arraigo"},
			{"tipo": "barra", "texto": "pasar tres días seguidos sin que te fichen, mientras resuelven",
				"dias": 3, "cond": [{"no_fichado": true}]},
		],
		"falla": "detenido",
		"perdido": "Con una detención más en el expediente, el arraigo se ha ido a la basura. Los papeles ya no llegarán.",
		"final": "Una carta certificada: permiso de residencia y trabajo. Llamas a tu madre desde el locutorio y no sabes qué decir; ella llora por las dos. El lunes empiezas en una obra en Badalona. El Raval te ha visto llegar y te ve irte.",
	},
	"parado": {
		"titulo": "Recuperar a su hija, Laia",
		"pasos": [
			{"tipo": "barra", "texto": "tres días seguidos sin emborracharte y con la dignidad por encima de 40",
				"dias": 3, "cond": [{"limpio": "litrona"}, {"stat": "dignity", "min": 40.0}]},
			{"tipo": "enviar", "texto": "ingresar 100 € de la pensión de Laia que debes", "lugar": ["cajero"], "total": 100, "minimo": 10,
				"accion": "Ingresar para la pensión de Laia"},
			{"tipo": "ir", "texto": "comer con Laia en un kebab (13 a 15 h), sereno", "lugar": ["kebab"],
				"desde": 13, "hasta": 15, "veces": 1, "minutos": 90, "sobrio": true, "estricto": true,
				"accion": "Comer con Laia"},
		],
		"falla": {"dignidad": 15.0},
		"perdido": "Laia te ha visto en la calle, tirado. Su madre te llama esa noche: que no vuelvas a acercarte.",
		"final": "Laia se pide un dürüm sin cebolla, como cuando tenía ocho años. Hablan de todo menos de lo importante, y al despedirse te dice «hasta el sábado». Dejas la litrona en el portal. Ya no caes: subes, despacio.",
	},
	"jubilado": {
		"titulo": "Que los nietos vuelvan a llamar",
		"pasos": [
			{"tipo": "tener", "texto": "conseguir un móvil que funcione", "objeto": "movil"},
			{"tipo": "enviar", "texto": "mandarle 60 € a Marc por su cumpleaños", "lugar": ["cajero"], "total": 60, "minimo": 10,
				"accion": "Mandar el regalo de cumpleaños de Marc"},
			{"tipo": "barra", "texto": "dos días seguidos con la dignidad por encima de 70, que cuando llamen no te noten nada",
				"dias": 2, "cond": [{"stat": "dignity", "min": 70.0}]},
		],
		"falla": {"dignidad": 30.0},
		"perdido": "Tu hija ha hablado con alguien del barrio. Los nietos ya no van a llamar.",
		"final": "Suena el móvil un domingo: es Marc, que quiere enseñarte el patinete que le compró con tu dinero. Luego se pone Anna. Te invitan a comer a Sabadell. Te pones la americana de los domingos y coges el tren.",
	},
	"divorciado": {
		"titulo": "Ver otra vez a Kira, el perro",
		"pasos": [
			{"tipo": "enviar", "texto": "pagar 160 € de la pensión atrasada", "lugar": ["cajero"], "total": 160, "minimo": 20,
				"accion": "Pagar la pensión atrasada"},
			{"tipo": "barra", "texto": "tres días seguidos con la dignidad por encima de 60 y sin que te fichen",
				"dias": 3, "cond": [{"stat": "dignity", "min": 60.0}, {"no_fichado": true}]},
			{"tipo": "ir", "texto": "quedar con ella y con Kira en la terraza de un bar (18 a 20 h), sereno", "lugar": ["bar"],
				"desde": 18, "hasta": 20, "veces": 1, "minutos": 60, "sobrio": true,
				"accion": "Esperar a Kira en la terraza"},
		],
		"falla": "detenido",
		"perdido": "Se ha enterado de lo de la comisaría. Te ha bloqueado en todo. A Kira no la vas a volver a ver.",
		"final": "Kira te reconoce desde la otra punta de la plaza y casi tira a tu ex al suelo. Ella se sienta, pide un café y te deja pasear al perro cada domingo. No es volver. Pero es algo.",
	},
	"psiquiatrico": {
		"titulo": "Que callen las voces",
		"pasos": [
			{"tipo": "ir", "texto": "ir a la cita con la psiquiatra del CAP (9 a 13 h)", "lugar": ["cap"],
				"desde": 9, "hasta": 13, "veces": 1, "minutos": 60, "accion": "Ir a la cita con la psiquiatra"},
			{"tipo": "barra", "texto": "tres días seguidos con la salud mental por encima de 60",
				"dias": 3, "cond": [{"stat": "sanity", "min": 60.0}]},
			{"tipo": "ir", "texto": "ir dos tardes al grupo de apoyo del servicio social (17 a 19 h)", "lugar": ["albergue"],
				"desde": 17, "hasta": 19, "veces": 2, "minutos": 90, "accion": "Ir al grupo de apoyo"},
		],
		"falla": "ingreso",
		"perdido": "Otra vez dentro. Cuando sales, las voces han ganado: ya no intentas que se callen.",
		"final": "Una mañana te das cuenta de que llevas días sin oírlas. La psiquiatra lo apunta sin levantar la vista. En el grupo te piden que cuentes cómo lo has hecho y no sabes qué decir. Te dan un piso tutelado en Sants.",
	},
	"nino_bien": {
		"titulo": "Demostrarle a papá que es alguien",
		"pasos": [
			{"tipo": "ir", "texto": "llamar a papá desde un cajero y decirle que no te ingrese más la paga", "lugar": ["cajero"],
				"desde": 0, "hasta": 0, "veces": 1, "minutos": 10, "efecto": "sin_paga",
				"accion": "Llamar a papá: que no te pase más la paga"},
			{"tipo": "barra", "texto": "cuatro días seguidos por tu cuenta: con 30 € encima al menos y la dignidad por encima de 60",
				"dias": 4, "cond": [{"stat": "money", "min": 30.0}, {"stat": "dignity", "min": 60.0}]},
			{"tipo": "ir", "texto": "cenar con papá en un bar (20 a 22 h), sereno", "lugar": ["bar"],
				"desde": 20, "hasta": 22, "veces": 1, "minutos": 90, "sobrio": true, "estricto": true,
				"accion": "Cenar con papá"},
		],
		"falla": {"dignidad": 30.0},
		"perdido": "Alguien le ha enseñado a papá una foto tuya en la Rambla del Raval. Ya no hay nada que demostrar.",
		"final": "Papá pide la cuenta y, por primera vez, te deja pagar a ti. No dice nada, pero en el coche le cuenta a mamá que has «madurado». Vuelves a Pedralbes con una historia que nadie te va a creer.",
	},
}
const PROPOSITO_SOBRIO := 30.0  ## colocón por encima del cual vas «colocado» a una cita del propósito
const PROPOSITO_LIMPIO := 0.4  ## colocón (0..1) de una sustancia que rompe un «limpio de»
const PROPOSITO_PASO_CAIDA := 10.0  ## lo que baja la caída cada paso: acercarte a lo tuyo te aleja del fondo
const PROPOSITO_PASO_DIGNIDAD := 5.0  ## ... y lo que sube la dignidad
const PROPOSITO_PASO_MENTE := 5.0  ## ... y la salud mental


# ------------------------------------------------------------------ sucesos del barrio

## Calendario: el día 1 de la partida es esta fecha [mes, día] (el resto se cuenta desde aquí).
const CALENDARIO_INICIO := [7, 10]
const MESES := ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto",
	"septiembre", "octubre", "noviembre", "diciembre"]
const DIAS_MES := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
## Cosas que le pasan al Raval durante unos días y lo cambian para todos (scripts/sucesos.gd).
## Empiezan en una `fecha` [mes, día] o, cada día, con probabilidad `prob_dia` (no antes del
## día `desde_dia` ni otra vez hasta `pausa` días después de acabar) y duran `dias` [mín, máx].
## `anuncio` sale en el registro al empezar, `fin` al acabar, `rumor` en la libreta y `frases`
## lo dice la gente al pasar mientras dura. `gente` multiplica cuántos hay de cada tipo de bot;
## `precio` multiplica lo que cuesta la droga; `pedir` suma a lo que te dan pidiendo.
const SUCESOS := {
	"fentanilo": {"titulo": "Llega el fentanilo", "prob_dia": 0.05, "desde_dia": 4, "pausa": 10, "dias": [3, 5],
		"anuncio": "Ha llegado al barrio una cosa nueva: parches de fentanilo, baratísimos. Y dicen que hay caballo cortado con lo mismo.",
		"rumor": "Ojo con el caballo de estos días: viene cortado con fentanilo. Las educadoras reparten naloxona.",
		"fin": "Ya no se ven parches de fentanilo por el barrio. Los que quedan, quedan.",
		"frases": ["¿Has visto lo de los parches?", "Ayer encontraron a otro en un portal.", "Con el caballo de ahora, cuidado."]},
	"redadas": {"titulo": "Redadas fuertes", "prob_dia": 0.07, "desde_dia": 3, "pausa": 6, "dias": [2, 3],
		"gente": {"urbano": 3.0, "mosso": 3.0, "urbano_secreta": 2.0, "mosso_secreta": 2.0}, "precio": 1.6,
		"anuncio": "Furgones de los Mossos en cada esquina y la Urbana pidiendo papeles: hay operación en el barrio. Los camellos se esconden y lo poco que hay, sale caro.",
		"rumor": "Hay redadas: los camellos no salen y lo que hay está carísimo. Mejor no llevar nada encima.",
		"fin": "Se van los furgones. Los camellos vuelven a sus esquinas como si nada.",
		"frases": ["Hoy está la calle llena de lecheras.", "Ni se te ocurra pillar hoy.", "Me han pedido los papeles tres veces."]},
	"fiesta_mayor": {"titulo": "Fiesta Mayor del Raval", "fecha": [7, 17], "dias": [4, 4],
		"gente": {"turista": 1.6, "vecino": 1.6, "nino": 1.6, "anciano": 1.3, "musico": 2.5, "fiestero": 1.5, "rosero": 1.5},
		"pedir": 0.15,
		"anuncio": "Empieza la Fiesta Mayor del Raval: gigantes, cuerpos de baile, conciertos en la Rambla del Raval y mesas largas por la calle. Hay gente por todas partes, y de buen humor.",
		"rumor": "Es la Fiesta Mayor: hay gente por todas partes, y la gente de fiesta da más.",
		"fin": "Se acaba la Fiesta Mayor. Las barrenderas recogen los vasos y el barrio vuelve a lo suyo.",
		"frases": ["¡Visca la Festa Major!", "¿Vas a los gigantes?", "Esta noche hay concierto en la Rambla del Raval."]},
	"obras": {"titulo": "Obras en la calle", "prob_dia": 0.1, "desde_dia": 2, "pausa": 3, "dias": [2, 4],
		"anuncio": "Han vallado un tramo de %s por obras. Hay que dar la vuelta.",
		"rumor": "%s está cortada por obras unos días.",
		"fin": "Quitan las vallas de %s. Huele a asfalto nuevo.",
		"frases": ["Otra vez obras, y en verano.", "Por ahí no se puede pasar, están las vallas."]},
}
## Obras: el tramo cortado (casillas alrededor de un punto de la calle) y lo lejos que tiene que
## quedar de ti al empezar (para no encerrarte).
const REDADA_ESCONDIDOS := 0.7  ## parte de los camellos que se esconden durante las redadas
const OBRAS_RADIO := 3
const OBRAS_LEJOS := 30
## Fentanilo (suceso): lo que vale y lo arriesgado que es (ver SUBSTANCES["fentanilo"]); la
## parte del caballo que viene cortada sin avisar (y su riesgo de sobredosis en cada dosis), la
## de los bots que se meten algo de eso y caen, los latentes que mueren cada día y los segundos
## que aguanta uno caído delante de ti hasta que llega la naloxona... o no.
const FENTA_CORTE := 0.3
const FENTA_CORTE_OD := 0.12
const FENTA_BOT_OD := 0.12
const FENTA_MUERTOS_DIA := Vector2i(1, 3)
const FENTA_CAIDO_SEGUNDOS := 45.0
const AMBULANCIA_A_TIEMPO := 0.4  ## sin naloxona, que la ambulancia llegue a tiempo
const NALOXONA_SALUD := 15.0  ## la salud que te quita una sobredosis si llevas naloxona (sin ella, 45)
## Opiáceos: lo que la naloxona revierte.
const OPIACEOS := ["caballo", "fentanilo", "tramadol", "metadona"]


# ------------------------------------------------------------------ amistades y fama

## Amistades y enemistades entre bots (scripts/vinculos.gd): de -100 (enemigo a muerte) a 100
## (uña y carne). Lo que suma o resta cada cosa que pasa entre ellos; desde VINCULO_AMIGO son
## amigos y hasta VINCULO_ENEMIGO enemigos. Cada uno recuerda como mucho VINCULOS_MAX y se va
## olvidando VINCULO_OLVIDO por día; los amigos del agredido se enteran (VINCULO_SE_CUENTA).
const VINCULO_PELEA := -45.0
const VINCULO_ROBO := -35.0
const VINCULO_TIRON := -35.0
const VINCULO_DOSIS := 35.0
const VINCULO_AMIGO := 25.0
const VINCULO_ENEMIGO := -25.0
const VINCULOS_MAX := 6
const VINCULO_OLVIDO := 8.0
const VINCULO_SE_CUENTA := 0.5
const VINCULO_CRUCE := 7  ## casillas a las que dos que se conocen se ven y reaccionan al cruzarse
const VINCULO_CRUCE_PAUSA := 60.0  ## segundos antes de que vuelvan a reaccionar
const VINCULO_BRONCA := 0.35  ## probabilidad de que dos enemigos que se cruzan acaben a golpes
## Tu fama por zonas del barrio (scripts/fama.gd): cuadrados de FAMA_ZONA casillas, con fama
## «buena» y «mala» de 0 a 100. Lo que suma cada cosa que haces (`FAMA_HECHOS`, por lo que
## recuerda la víctima: Npc.remember), multiplicado por cada testigo que te ve
## (FAMA_TESTIGO); cada día se olvida FAMA_OLVIDO y corre a las zonas de al lado (FAMA_CORRE).
const FAMA_ZONA := 40
const FAMA_HECHOS := {"ayudado": ["buena", 6.0], "robado": ["mala", 8.0], "pegado": ["mala", 8.0], "timado": ["mala", 6.0]}
const FAMA_TESTIGO := 0.5
const FAMA_SOLO := 0.5  ## sin testigos, solo lo cuenta la víctima: esta parte
const FAMA_OLVIDO := 4.0
const FAMA_CORRE := 0.25
## Cómo te trata quien no te conoce según tu fama en su zona: te evita (mala), no te vende ni
## te compra (mala), viene a pedirte (buena, los de la calle) o te avisa de la policía (buena).
const FAMA_EVITA := 40.0
const FAMA_NO_VENDE := 55.0
const FAMA_PIDEN := 40.0
const FAMA_PEDIGUENOS := ["yonki", "mendigo", "punki", "chaval"]
const FAMA_AVISA := 30.0
const FAMA_AVISO_PAUSA := 90.0  ## segundos entre dos avisos de la policía
## Al relevo, quien vivía donde el de antes tenía fama (por encima de esto) se acuerda de él
## de oídas («recuerda_a»).
const FAMA_RECUERDO := 30.0
