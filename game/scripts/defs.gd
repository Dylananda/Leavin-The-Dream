class_name Defs
## Datos fijos del juego: perfiles de yonki, sustancias, objetos y títulos.
## Para equilibrar el juego, casi todo se toca aquí.

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
	"drogas": ["mossos"],  # vender, camellos, narcopisos
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
## Leyenda del barrio: con esta caída (el último título de TITLES) se gana la partida.
const LEGEND_CAIDA := 800.0
## Te llevan a casa (Borja, el niño bien): con la dignidad por debajo de esto, cada día puede
## aparecer su familia a recogerlo.
const HOME_RESCUE_DIGNITY := 15.0
const HOME_RESCUE_CHANCE := 0.3
## La cárcel: con estas detenciones entras en prisión (fin de la partida); con una menos, aviso.
const PRISON_ARRESTS := 5
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
const LATENT_GRUDGES := ["robado", "pegado", "timado", "pisado"]  ## ... y esto lo olvida a la mitad de ritmo

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
		"knows": {"porro": 10},
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
		"knows": {"litrona": 25, "porro": 5},
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
		"knows": {"litrona": 15},
		"income": {"amount": 140, "every_days": 7, "label": "la pensión"},  # no contributiva: unos 600 € al mes
		"perk": "La policía no sospecha de un abuelo. Da mucha pena pidiendo.",
		"items": {"bocadillo": 1},
		"look": {"skin": Color("e8bfa0"), "shirt": Color("5b4a3a"), "pants": Color("6e6658"), "hair": Color("e8e8e8"),
			"gender": "m", "hair_style": "calvo", "glasses": true, "jacket": Color("4a3a2a")},  # americana de los domingos
	},
	{
		"id": "divorciado",
		"name": "Jordi",
		"title": "Divorciado",
		"desc": "Ella se quedó la casa, el perro y los amigos. Él se quedó un estudio en la calle del Carme y mucho tiempo libre.",
		"money": 350, "health": 80, "dignity": 95, "sanity": 55,
		"knows": {"litrona": 5},
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
		"knows": {"pastillas": 20, "porro": 5},
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
		"knows": {"farlopa": 3, "litrona": 0},
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
const SUBSTANCES := {
	"litrona": {"name": "Litrona", "price": 2, "high": 25, "addiction": 1.5, "health": -1, "dignity": -1, "sanity": 2, "od": 0.0,
		"decay": 0.1, "fatigue_rate": 1.5, "visible": 0.3, "color": Color("d8b040"),
		"fx": {"drift": 1.0, "lag": 0.8, "double": 0.7, "sway": 0.25}, "fx_text": "andas haciendo eses y reaccionas tarde"},
	"porro": {"name": "Porro", "price": 4, "high": 25, "addiction": 1, "health": -1, "dignity": 0, "sanity": 2, "od": 0.0,
		"decay": 0.12, "hunger_rate": 2.0, "fatigue_rate": 1.4, "visible": 0.2, "color": Color("6ab04a"),
		"fx": {"zoom": 0.35, "slowmo": 1.0, "speed": -0.1}, "fx_text": "todo va más lento y lo ves de cerca"},
	"pastillas": {"name": "Pastillas", "price": 3, "high": 25, "addiction": 3, "health": -3, "dignity": -1, "sanity": 3, "od": 0.2,
		"decay": 0.1, "fatigue_rate": 1.3, "visible": 0.1, "color": Color("e06ab0"),
		"fx": {"saturate": 1.0, "speed": -0.15}, "fx_text": "colores chillones y piernas de goma"},
	"farlopa": {"name": "Farlopa", "price": 30, "high": 35, "addiction": 4, "health": -4, "dignity": -2, "sanity": 4, "od": 0.3,
		"decay": 0.2, "hunger_rate": 0.2, "fatigue_rate": 0.2, "visible": 0.3, "color": Color("e8e8f0"),
		"crash": {"minutes": 30, "sanity": -4, "mono": 8, "fatigue": 10},
		"fx": {"speed": 0.4, "shake": 0.5}, "fx_text": "vas a toda leche y la vista te tiembla"},
	"base": {"name": "Base", "price": 10, "high": 40, "addiction": 9, "health": -6, "dignity": -6, "sanity": 6, "od": 0.5,
		"decay": 0.5, "hunger_rate": 0.2, "fatigue_rate": 0.3, "visible": 0.5, "color": Color("f0a040"),
		"crash": {"minutes": 60, "sanity": -10, "mono": 20, "fatigue": 15},
		"fx": {"speed": 0.3, "glow": 1.0, "zoom": -0.15}, "fx_text": "euforia: todo brilla (dura muy poco)"},
	"caballo": {"name": "Caballo", "price": 15, "high": 55, "addiction": 8, "health": -8, "dignity": -5, "sanity": 3, "od": 1.0,
		"decay": 0.1, "hunger_rate": 0.6, "fatigue_rate": 2.5, "visible": 0.3, "color": Color("c89a6a"),
		"fx": {"speed": -0.45, "sway": 1.0, "drowsy": 0.35}, "fx_text": "vas lento y todo oscila"},
	"metadona": {"name": "Metadona", "price": 0, "high": 8, "addiction": 1, "health": 0, "dignity": 0, "sanity": 2, "od": 0.0,
		"decay": 0.02, "visible": 0.0, "color": Color("60a0c0"),
		"relieves": "caballo", "mono": -60, "relief_addiction": 2,
		"fx": {"speed": -0.1}, "fx_text": "te calma el mono del caballo"},
}
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
const DEALER_STOCK := ["porro", "pastillas", "farlopa", "base", "caballo"]

const ITEMS := {
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
	# de la calle (scripts/street_items.gd)
	"chatarra": {"name": "Chatarra", "sell": 3},
	"bici": {"name": "Bici ajena", "sell": 15},
	"patinete": {"name": "Patinete eléctrico", "sell": 28},
}

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
const CLIENTS := {
	"fiestero": {"wants": ["farlopa", "porro", "pastillas"], "markup": 1.7},
	"turista": {"wants": ["porro"], "markup": 2.5},
	"yonki": {"wants": ["pastillas", "porro", "litrona"], "markup": 1.5},
	"pudiente": {"wants": ["farlopa", "porro"], "markup": 2.0},
}
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
const YONKI_STASH := ["caballo", "base", "pastillas", "porro", "litrona"]
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
	# conocer una sustancia nueva (las que ya conoce el perfil no cuentan)
	"probar_litrona": ["Empezar a beber en la calle", 3],
	"probar_porro": ["Probar los porros", 3],
	"probar_pastillas": ["Probar las pastillas", 5],
	"probar_farlopa": ["Probar la farlopa", 8],
	"probar_base": ["Probar la base", 10],
	"probar_caballo": ["Probar el caballo", 10],
	"probar_metadona": ["Entrar en el programa de metadona", 5],
}


static func profile(id: String) -> Dictionary:
	for p in PROFILES:
		if p["id"] == id:
			return p
	return PROFILES[0]


static func item_name(id: String) -> String:
	if SUBSTANCES.has(id):
		return SUBSTANCES[id]["name"]
	if ITEMS.has(id):
		return ITEMS[id]["name"]
	return id


## Si un objeto del inventario se puede usar (meterse, comer, vaciar).
static func usable(id: String) -> bool:
	return SUBSTANCES.has(id) or ITEMS.get(id, {}).has("food") or id in ["cartera", "paquete"]


static func title_for(caida: float) -> String:
	var t: String = TITLES[0][1]
	for entry in TITLES:
		if caida >= entry[0]:
			t = entry[1]
	return t


## Convierte un índice de criminalidad (1.0 = barrio mediano) en un multiplicador suave.
static func crime_factor(index: float) -> float:
	return clampf(1.0 + 0.3 * log(maxf(index, 0.01)) / log(2.0), 0.5, 3.5)
