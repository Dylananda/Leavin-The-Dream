class_name Npc
extends Actor
## Bot del barrio. Cada tipo tiene su forma de moverse y sus frases;
## las interacciones con el jugador están en interactions.gd.
## Ven en un cono tapado por los edificios y se acuerdan de lo que les has hecho: según eso
## te persiguen, te denuncian, se apartan o se acercan (ver grudge() y react()).

signal caught_player(npc: Npc)

## speed en metros por segundo; wander en casillas (2 m).
## hours = [desde, hasta) en horas del día (puede pasar de medianoche); sin hours, a todas horas.
## zone = dónde viven: "rambla", "rambla_raval", "bares" (ver World._spawn_npc).
## disguise = cómo se le ve hasta que hablas con él; bios = historia de cada nombre.
## women = nombres que son de mujer; either = nombres que no dicen el género (se elige al
## azar, pero siempre el mismo para ese nombre); el resto son hombres. label_f = etiqueta en
## femenino si cambia. looks = rasgos fijos de algún nombre (ver Actor.look).
## Los tipos nuevos se basan en fenómenos documentados del barrio (fuentes en docs/ideas.md).
const KINDS := {
	"turista": {
		"label": "Turista", "speed": 10.4, "wander": 80, "accessory": "mochila",
		"names": ["Kevin", "Sven", "Giulia", "Brad", "Ingrid", "Pierre", "Hannah"],
		"women": ["Giulia", "Ingrid", "Hannah"],
		"lines": ["Is this the real Barcelona?", "Where is the Sagrada Familia?", "So authentic!", "Una cerveza, please"],
	},
	"camello": {
		"label": "Camello", "speed": 12.0, "wander": 8, "accessory": "capucha",
		"names": ["El Rata", "Chino", "El Tuerto", "Nene", "Boli", "El Primo"],
		"lines": ["Chocolate, maría...", "¿Qué buscas, amigo?", "Sssst, ven aquí", "Aquí no, muévete"],
	},
	"policia": {
		"label": "Agente", "speed": 14.4, "wander": 120, "accessory": "gorra_poli",
		"names": ["Agente Puig", "Agente Soler", "Agente Romero", "Agente Vidal"],
		"either": ["Agente Puig", "Agente Soler", "Agente Romero", "Agente Vidal"],
		"lines": ["Circulen.", "Documentación.", "¿Todo bien por aquí?"],
	},
	"yonki": {
		"label": "Yonki", "speed": 8.8, "wander": 50, "accessory": "",
		"names": ["El Lolo", "Manoli", "El Cuervo", "Toni Calcetines", "La Yoli", "El Pirata"],
		"women": ["Manoli", "La Yoli"],
		"lines": ["¿Tienes un euro, primo?", "Ayer vi a Dios en un cajero", "Esto antes era otra cosa", "¿Fuego?"],
	},
	"educador": {
		"label": "Educador social", "label_f": "Educadora social", "speed": 11.2, "wander": 60, "accessory": "chaleco", "hours": [9, 21],
		"names": ["Núria", "Marc", "Laia", "Oriol"],
		"women": ["Núria", "Laia"],
		"lines": ["¿Has pasado por el Baluard?", "Si necesitas algo, aquí estamos", "¿Has comido hoy?"],
	},
	"vecino": {
		"label": "Vecino", "label_f": "Vecina", "speed": 9.6, "wander": 30, "accessory": "", "hours": [7, 23],
		"names": ["Sra. Pepita", "Sr. Antonio", "Fatima", "Rajesh", "Montse"],
		"women": ["Sra. Pepita", "Fatima", "Montse"],
		"looks": {
			"Sra. Pepita": {"hair": Color("d8d8d8"), "hair_style": "moño", "skirt": true, "glasses": true},
			"Sr. Antonio": {"hair": Color("c8c8c8"), "hair_style": "calvo", "facial": "bigote", "jacket": Color("5a4a3a")},
		},
		"lines": ["¡Esto es una vergüenza!", "Que no se puede vivir", "Voy al mercado", "¡Ese portal no es un baño!"],
	},
	"mantero": {
		"label": "Mantero", "speed": 12.8, "wander": 20, "accessory": "",
		"names": ["Moussa", "Ibrahima", "Lamine", "Cheikh"],
		"lines": ["Gafas, bolsos, barato", "Amigo, mira", "¡Agua! ¡Water!"],
	},
	"fiestero": {
		"label": "De despedida", "speed": 9.0, "wander": 25, "accessory": "despedida",
		"hours": [22, 5], "zone": "bares",
		"names": ["Dani", "Tom", "Lukas", "Chloe", "Marco", "Aitor", "Jess"],
		"women": ["Chloe", "Jess"],
		"looks": {
			"Dani": {"hair": Color("ff7ac0"), "hair_style": "melena"},  # la peluca rosa
			"Chloe": {"skirt": true, "hair_style": "melena", "hair": Color("e8c860")},
		},
		"lines": ["¡Que se casa! ¡Que se casa!", "One more beer!", "¿Dónde está la fiesta?", "¡Uno más y nos vamos!", "*vomita en un portal*"],
		"bios": {
			"Dani": "Se casa el sábado en Valladolid. Sus amigos le han puesto una peluca rosa y le han hecho prometer que no llamará a su novia hasta el domingo.",
			"Chloe": "Vuelo low cost desde Mánchester por 19 libras. Lleva una banda de «Bride to be» y no ha visto la Sagrada Familia ni de lejos.",
			"Aitor": "Es el único sobrio del grupo: le toca devolverlos al apartamento turístico. Cuenta las horas.",
		},
	},
	"latero": {
		"label": "Latero", "speed": 10.0, "wander": 15, "accessory": "bolsa",
		"hours": [20, 5], "zone": "bares",
		"names": ["Shahid", "Imran", "Bilal", "Rafiq", "Nasir"],
		"lines": ["¡Cerveza, beer!", "Un euro, amigo", "Fría, fría", "¿Cervezabeer?"],
		"bios": {
			"Shahid": "Estudió contabilidad. Lleva ocho años en Barcelona esperando papeles; manda a casa lo que saca y duerme cuatro horas.",
			"Imran": "Fue cocinero en un restaurante del Born hasta que cerró. Las latas las guarda en una alcantarilla para que no se las requisen... ni se calienten.",
			"Bilal": "Tiene diecinueve años y paga 150 € al mes por un colchón en un piso de la calle del Hospital. Su madre cree que trabaja en una tienda.",
			"Rafiq": "Vino con un contrato de temporero en Lleida que nunca existió. Las latas son lo único que le salió.",
			"Nasir": "La Guàrdia Urbana le ha quitado tantas latas que ya no las cuenta. Vuelve a por más al súper de enfrente.",
		},
	},
	"trilero": {
		"label": "Trilero", "label_f": "Trilera", "speed": 12.0, "wander": 2, "accessory": "caja",
		"hours": [10, 20], "zone": "rambla",
		"names": ["El Profesor", "Pecas", "Ciri", "Manolo Cubiletes"],
		"either": ["Pecas", "Ciri"],
		"looks": {"El Profesor": {"glasses": true, "hair": Color("9a9a9a"), "facial": "barba"}},
		"lines": ["¿Dónde está la bolita?", "¡Mira, mira, que gana!", "Cincuenta, doble o nada", "¡Agua! ¡Recoge!"],
		"bios": {
			"El Profesor": "Treinta años moviendo cubiletes en la Rambla. Dice que el truco no está en las manos, sino en los ganchos que fingen ganar.",
			"Pecas": "Empezó de vigía con catorce años. Ahora tiene la mesa y dos chavales que le avisan de la Urbana.",
		},
	},
	"carterista": {
		"label": "Carterista", "speed": 11.5, "wander": 40, "accessory": "mochila", "disguise": "turista",
		"hours": [9, 21], "zone": "rambla",
		"names": ["Sandra", "Dedos", "Nico", "La Sombra", "Manu"],
		"women": ["Sandra"],
		"either": ["La Sombra", "Manu"],
		"lines": ["Excuse me, the map...", "Perdona, ¿la Boqueria?", "Sorry, sorry"],
		"bios": {
			"Sandra": "Treinta y tantas detenciones y ninguna condena larga: robar menos de 400 € es delito leve. Lo sabe y lo cuenta riéndose.",
			"Dedos": "Trabaja la Rambla por la mañana y el metro por la tarde. Va vestido de guiri, con mapa y todo.",
			"La Sombra": "Le han prohibido entrar en el metro. Desde entonces se ha mudado a la Boqueria.",
		},
	},
	"chaval": {
		"label": "Chaval", "speed": 12.0, "wander": 30, "accessory": "gorra", "size": 0.8,
		"hours": [15, 3], "zone": "rambla_raval",
		"names": ["Anas", "Yassin", "Hamza", "Ilyas", "Omar"],
		"lines": ["¿Tienes un cigarro?", "Un euro, hermano", "*huele a disolvente*", "No pasa nada, no pasa nada"],
		"bios": {
			"Anas": "Quince años. Se escapó de un centro de acogida y duerme en un portal de Sant Pau. Dice que la cola le quita el hambre y el frío.",
			"Yassin": "Cruzó escondido bajo un camión para trabajar y mandar dinero a casa. Aquí nadie contrata a un menor.",
			"Hamza": "Tiene un cuaderno donde apunta palabras en castellano. Va por la página doce.",
			"Ilyas": "Las educadoras de calle le conocen por su nombre. Algunos días va con ellas; otros, no.",
			"Omar": "Dieciséis años. Quiere ser mecánico. Cuando habla de motos se le olvida la bolsa.",
		},
	},
}

const SKINS := [Color("f0cfb0"), Color("e0b08a"), Color("c68c5e"), Color("8d5a3b"), Color("5a3a26")]
const HAIR_COLORS := [Color("1b1410"), Color("3a2418"), Color("5a3a20"), Color("8a5a30"), Color("c8a060"), Color("7a7a7a")]
## Probabilidades de cada rasgo. Las tiradas dependen del nombre: el mismo personaje
## sale siempre igual, para que lo reconozcas al volver a verlo.
const P_BEARD := 0.3
const P_MOUSTACHE := 0.12
const P_GLASSES := 0.15
const P_JACKET := 0.35
const P_SKIRT := 0.35
## Tipos que van de uniforme (sin chaqueta ni falda).
const UNIFORMED := ["policia", "educador"]
const THINK_TIME := 0.25  ## cada cuánto miran y deciden (segundos)
## Colores del cono de visión: tranquilo, con sospecha y persiguiéndote.
const C_CONE_CALM := Color(0.6, 0.9, 1.0, 0.16)
const C_CONE_ALERT := Color(1.0, 0.85, 0.2, 0.3)
const C_CONE_CHASE := Color(1.0, 0.25, 0.2, 0.34)
const CONE_RAYS := 16  ## rayos del abanico (más, mejor recorte contra las esquinas)

var kind := "turista"
var gender := "m"  ## "m" o "f", según el nombre (ver KINDS)
var home := Vector2i.ZERO
var wander_radius := 20
var money := 0
var debt := 0  ## Lo que le debe el jugador (camellos)
var player: Actor
var world: World
var robbed := false  ## Ya le han robado (turistas), tú o un carterista
var last_interaction_day := -1
var known := false  ## Ya has hablado con él (los disfrazados dejan de parecer lo que no son)
## Lo que ha pasado contigo: "pedido", "robado", "ayudado", "pegado", y del trapicheo
## (scripts/trade.gd) "cliente", "timado" (le vendiste cortado o una piedra) y "pisado" (un
## camello que te vio vender en su esquina) -> veces. Decide cómo
## reacciona al verte (ver grudge()).
var memory := {}
## Lo que está haciendo por ti: "" (su vida), "persigue", "busca" (donde te vio por última
## vez), "aparta" (se quita de en medio), "denuncia" (va a por un policía), "acerca" (a saludar).
var mode := ""
var chase_reason := ""  ## por qué te persigue: "policia", "deuda", "venganza", "parar"
var alert := 0.0  ## 0..1: la sospecha mientras te ve; llena, reacciona
var sees_player := false
var last_seen := Vector2i.ZERO  ## casilla donde te vio por última vez
var debt_due := 0.0  ## now() a partir del cual el camello viene a cobrar lo fiado
## Si se dibuja su cono de visión en el suelo (lo decide World según la distancia y la tecla V).
var cone_visible := false
var on_screen := true  ## lo pone World: fuera de la pantalla se actualiza menos (ver _process)
var _offscreen_dt := 0.0
var _offscreen_frame := randi()  ## desfasado para que no les toque a todos en el mismo frame
var chasing: bool:
	get:
		return mode == "persigue"

var _idle := 0.0
var _think := 0.0
var _chatter := randf_range(8.0, 30.0)
var _lost := 0.0  ## segundos persiguiéndote sin verte
var _search := 0.0  ## segundos que le quedan buscándote
var _calm_until := 0.0  ## (segundos de reloj) hasta entonces no vuelve a reaccionar
var _look_yaw := 0.0  ## hacia dónde gira la cabeza cuando está parado
var _look_timer := 0.0
var _cone: MeshInstance3D
var _cone_mesh: ImmediateMesh
var _cone_timer := 0.0
var _denounce_to: Npc  ## el agente al que va a contarle lo que le hiciste

static var _cone_material: StandardMaterial3D


## Prepara un bot del tipo `p_kind`; sin `p_name`, con uno de sus nombres al azar.
func init_kind(p_kind: String, p_name := "") -> void:
	kind = p_kind
	var k: Dictionary = KINDS[kind]
	display_name = p_name if p_name != "" else k["names"].pick_random()
	speed = k["speed"]
	wander_radius = k["wander"]
	accessory = k["accessory"]
	body_size = k.get("size", 1.0)
	# el aspecto sale del nombre: quien vuelve a salir con el mismo nombre se ve igual
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind + "|" + display_name)
	gender = "f" if display_name in k.get("women", []) else "m"
	if display_name in k.get("either", []):
		gender = "f" if rng.randf() < 0.5 else "m"
	look = {
		"gender": gender,
		"skin": SKINS[rng.randi_range(0, SKINS.size() - 1)],
		"shirt": Color.from_hsv(rng.randf(), rng.randf_range(0.2, 0.7), rng.randf_range(0.35, 0.85)),
		"pants": Color.from_hsv(rng.randf(), 0.2, rng.randf_range(0.2, 0.5)),
		"hair": HAIR_COLORS[rng.randi_range(0, HAIR_COLORS.size() - 1)],
	}
	_roll_traits(rng)
	match kind:
		"policia":
			look["shirt"] = Color("2a3d7a")
			look["pants"] = Color("1d2a5a")
		"turista":
			money = randi_range(20, 160)
			look["skin"] = SKINS[rng.randi_range(0, 1)]
			look["shirt"] = Color.from_hsv(rng.randf(), 0.6, 0.95)
		"yonki":
			money = randi_range(0, 6)
			look["shirt"] = look["shirt"].darkened(0.4)
		"educador":
			look["shirt"] = Color("e07a30")
		"fiestero":
			money = randi_range(30, 120)
			look["shirt"] = [Color("ff5fa0"), Color("f0f0f0"), Color("40c0f0")][rng.randi_range(0, 2)]
		"latero", "trilero":
			money = randi_range(5, 30)
		"carterista":
			money = randi_range(20, 80)
			look["shirt"] = Color.from_hsv(rng.randf(), 0.6, 0.95)  # de guiri, como los turistas
		"chaval":
			money = randi_range(0, 3)
			look["shirt"] = look["shirt"].darkened(0.3)
			look["facial"] = ""
	look.merge(k.get("looks", {}).get(display_name, {}), true)
	_idle = randf_range(0.0, 3.0)


## Peinado, barba, gafas, chaqueta y falda, con las tiradas de `rng`.
func _roll_traits(rng: RandomNumberGenerator) -> void:
	var styles: Array = Actor.HAIR_STYLES[gender]
	# la mitad de las veces, uno de los dos peinados más corrientes
	var n := 2 if rng.randf() < 0.5 else styles.size()
	look["hair_style"] = styles[rng.randi_range(0, n - 1)]
	if gender == "m":
		var r := rng.randf()
		look["facial"] = "barba" if r < P_BEARD else ("bigote" if r < P_BEARD + P_MOUSTACHE else "")
	look["glasses"] = rng.randf() < P_GLASSES
	if kind not in UNIFORMED:
		if rng.randf() < P_JACKET:
			look["jacket"] = Color.from_hsv(rng.randf(), rng.randf_range(0.1, 0.5), rng.randf_range(0.15, 0.45))
		look["skirt"] = gender == "f" and rng.randf() < P_SKIRT


func label() -> String:
	var k: Dictionary = KINDS[kind]
	if not known and k.has("disguise"):
		return "%s (%s)" % [display_name, kind_label(k["disguise"], gender)]
	return "%s (%s)" % [display_name, kind_label(kind, gender)]


## Nombre del tipo de bot `p_kind` en el género `p_gender`.
static func kind_label(p_kind: String, p_gender: String) -> String:
	var k: Dictionary = KINDS[p_kind]
	return k.get("label_f", k["label"]) if p_gender == "f" else k["label"]


## Historia de este personaje, si la tiene.
func bio() -> String:
	return KINDS[kind].get("bios", {}).get(display_name, "")


## Si los de este tipo andan por la calle a la hora `h`.
static func active_at(p_kind: String, h: int) -> bool:
	var hours: Array = KINDS[p_kind].get("hours", [])
	if hours.is_empty():
		return true
	var from: int = hours[0]
	var to: int = hours[1]
	return (h >= from and h < to) if from < to else (h >= from or h < to)




# --------------------------------------------------------- memoria y visión

## Apunta algo que ha pasado contigo ("pedido", "robado", "ayudado", "pegado").
func remember(what: String) -> void:
	memory[what] = memory.get(what, 0) + 1


func remembers(what: String) -> int:
	return memory.get(what, 0)


## Te fía `amount` € y te da `hours` horas para pagar antes de venir a cobrar.
func add_debt(amount: int, hours: float) -> void:
	debt += amount
	debt_due = GameState.now() + hours * 60.0


## Lo que le toca hacer si te ve, según quién es y lo que recuerda de ti; "" si le da igual.
## "persigue" (la policía, si estás fichado o muy buscado), "cobrar" (un camello al que
## debes), "venganza" (le robaste y va a por lo suyo), "denuncia" (le robaste y busca a un
## agente), "territorio" (un camello en cuya esquina vendiste), "aparta" (le has pedido
## demasiado, le pegaste o le timaste) o "acerca" (le ayudaste o te compra).
func grudge() -> String:
	var gs := GameState
	if kind == "policia":
		return "persigue" if gs.is_wanted() or gs.heat > Defs.CHASE_HEAT else ""
	if kind == "camello" and debt > 0 and gs.now() >= debt_due:
		return "cobrar"
	if kind == "camello" and remembers("pisado") > 0:
		return "territorio"
	if remembers("timado") > 0:
		# a la policía no le vas a contar que te vendieron yeso
		return "venganza" if avenger() else "aparta"
	if remembers("robado") > 0:
		if avenger():
			return "venganza"
		# los que viven de la calle no van con cuentos a la policía
		return "aparta" if kind in Defs.NEVER_INTERVENE else "denuncia"
	if remembers("pegado") > 0 or remembers("pedido") >= Defs.BEG_ANNOY:
		return "aparta"
	if remembers("ayudado") > 0 or remembers("cliente") > 0:
		return "acerca"
	return ""


## Si, robado, va a por ti en vez de buscar a un agente (tirada fija por nombre).
func avenger() -> bool:
	var p: float = Defs.AVENGER_CHANCE[gender]
	if kind == "fiestero":
		p += 0.2  # van en grupo y van ciegos
	return _trait("venganza") < p


## Cómo reacciona ante un escándalo: "valiente" (intenta pararte), "llama" (a la policía) o
## "pasa". Los que viven de la calle siempre pasan.
func temper() -> String:
	if kind in Defs.NEVER_INTERVENE or kind == "policia":
		return "pasa"
	var r := _trait("caracter")
	if r < Defs.BRAVE_CHANCE:
		return "valiente"
	return "llama" if r < Defs.BRAVE_CHANCE + Defs.CALLER_CHANCE else "pasa"


## Tirada 0..1 que depende solo del personaje y de `salt`: el mismo siempre hace lo mismo.
func _trait(salt: String) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind + "|" + display_name + "|" + salt)
	return rng.randf()


## Alcance (metros, en x) y media apertura (radianes, en y) de su cono de visión ahora.
func vision() -> Vector2:
	var v: Dictionary = Defs.VISION.get(kind, Defs.VISION["_"])
	var r: float = v["range"] * city.cell_m
	if GameState.is_night():
		r *= Defs.NIGHT_SIGHT
	if GameState.heat >= 90.0:
		r *= Defs.EXPOSED_SIGHT
	return Vector2(r, deg_to_rad(v["angle"]) / 2.0)


## Si ve a `who`: dentro del cono (o pegado a él) y sin edificios en medio.
func can_see(who: Actor) -> bool:
	if who == null or city == null:
		return false
	var v := vision()
	var to := who.position - position
	to.y = 0.0
	var dist := to.length()
	if dist > v.x:
		return false
	if dist > Defs.NEAR_SIGHT * city.cell_m and facing().dot(to / dist) < cos(v.y):
		return false
	return city.line_of_sight(cell, who.cell)


## Deja de hacer lo que hacía por ti y vuelve a lo suyo.
func calm_down() -> void:
	mode = ""
	chase_reason = ""
	alert = 0.0
	_denounce_to = null
	speed = KINDS[kind]["speed"]


## Empieza a perseguirte por `reason` ("policia", "deuda", "venganza", "parar").
func start_chase(reason: String) -> void:
	mode = "persigue"
	chase_reason = reason
	alert = 1.0
	_lost = 0.0
	last_seen = player.cell
	speed = KINDS[kind]["speed"] * (1.3 if reason == "policia" else 1.2)
	walk_to(player.cell)


## Va a mirar a `at` (ha oído un escándalo o se lo han contado); si te ve allí, te persigue.
func investigate(at: Vector2i) -> void:
	if mode == "persigue":
		return
	mode = "busca"
	if kind == "policia":
		chase_reason = "policia"
	last_seen = at
	_search = Defs.SEARCH_TIME * 1.5
	speed = KINDS[kind]["speed"] * 1.3
	walk_to(at)


## Te ha visto y reacciona según grudge(); sin motivo, nada.
func react(why: String) -> void:
	_calm_until = _clock() + 25.0
	match why:
		"persigue":
			say("¡Alto! ¡Policía!")
			start_chase("policia")
		"cobrar":
			say("¡Eh, tú! ¡Mi dinero!", 3.0)
			start_chase("deuda")
		"territorio":
			say("¡Eh! ¡Esta esquina es mía!", 3.0)
			start_chase("territorio")
		"venganza":
			say("You! ¡Tú! ¡Devuélvemelo!" if kind in ["turista", "fiestero"] else "¡Tú! ¡Ladrón!", 3.0)
			start_chase("venganza")
		"denuncia":
			alert = 0.0
			_denounce_to = _nearest_police()
			say("¡Ese! ¡Ese me robó!", 3.0)
			if _denounce_to:
				mode = "denuncia"
				walk_to(_denounce_to.cell)
			else:
				GameState.mark_wanted("%s te ha reconocido y ha llamado a la policía" % display_name)
		"aparta":
			alert = 0.0
			mode = "aparta"
			say(["Otra vez tú no...", "Ni me mires", "Uf, este otra vez"].pick_random())
			var away := Vector2(cell - player.cell).normalized() * 10.0
			walk_to(city.nearest_walkable(cell + Vector2i(roundi(away.x), roundi(away.y))))
		"acerca":
			alert = 0.0
			mode = "acerca"
			walk_to(player.cell)


func _process(delta: float) -> void:
	# fuera de la pantalla y sin nada contigo, a trompicones: cada OFFSCREEN_EVERY frames, con
	# el tiempo acumulado (no se ve, y con muchos bots es casi todo el trabajo)
	if not on_screen and mode == "":
		_offscreen_dt += delta
		_offscreen_frame += 1
		if _offscreen_frame % Defs.OFFSCREEN_EVERY != 0:
			return
		delta = _offscreen_dt
	_offscreen_dt = 0.0
	super._process(delta)
	if not GameState.alive:
		return
	_think -= delta
	_chatter -= delta
	if _chatter <= 0.0:
		_chatter = randf_range(15.0, 45.0)
		if player and distance_to_cell(player.cell) < 20:
			say(KINDS[kind]["lines"].pick_random())
	if player and _think <= 0.0:
		_think = THINK_TIME
		perceive(THINK_TIME)
		_follow_mode(THINK_TIME)
	_cone_timer -= delta
	if _cone_timer <= 0.0:
		_cone_timer = 0.1
		_update_cone()
	if mode != "":
		if mode == "busca" and not is_moving():
			_look_around(delta, 2.5)
		return
	if not is_moving():
		_look_around(delta, 1.0)
		_idle -= delta
		if _idle <= 0.0:
			_idle = randf_range(1.0, 5.0) if kind != "camello" else randf_range(4.0, 12.0)
			walk_to(city.random_walkable_near(home, wander_radius))


## Mira (cono de visión) y sube o baja la sospecha. Llena, reacciona si tiene motivo.
func perceive(dt: float) -> void:
	var far: float = Defs.VISION["policia"]["range"] * Defs.EXPOSED_SIGHT
	sees_player = distance_to_cell(player.cell) <= far and can_see(player)
	if mode in ["aparta", "denuncia", "acerca"]:
		return
	var why := grudge() if sees_player else ""
	if sees_player:
		last_seen = player.cell
		_lost = 0.0
	if why != "" or (sees_player and mode == "persigue"):
		var closeness := clampf(position.distance_to(player.position) / vision().x, 0.0, 1.0)
		alert = minf(1.0, alert + dt / Defs.ALERT_TIME * lerpf(3.0, 1.0, closeness))
	elif mode != "persigue":
		alert = maxf(0.0, alert - dt * Defs.ALERT_DECAY)
	if alert >= 1.0 and mode in ["", "busca"] and why != "" and _clock() >= _calm_until:
		react(why)


## Sigue con lo que esté haciendo por ti: perseguir, buscar, apartarse, denunciar, saludar.
func _follow_mode(dt: float) -> void:
	match mode:
		"persigue":
			if chase_reason == "policia" and GameState.heat <= 10.0 and not GameState.is_wanted():
				say("Bah, déjalo.")
				calm_down()
				return
			if distance_to_cell(player.cell) <= 2:
				stop()
				var why := chase_reason
				calm_down()
				_calm_until = _clock() + 30.0
				chase_reason = why
				caught_player.emit(self)
				chase_reason = ""
				return
			if sees_player:
				walk_to(player.cell)
			else:
				_lost += dt
				if _lost >= Defs.LOSE_SIGHT_TIME:
					if chase_reason == "parar":
						calm_down()  # un transeúnte no sigue a nadie por las esquinas
						return
					mode = "busca"
					_search = Defs.SEARCH_TIME
					say("¿Dónde se ha metido?")
					walk_to(last_seen)
		"busca":
			if not is_moving():
				_search -= dt
				if _search <= 0.0:
					if chase_reason == "policia":
						say("Se ha escapado...")
						GameState.mark_wanted("te has escapado de la policía")
					calm_down()
					walk_to(city.random_walkable_near(home, wander_radius))
		"denuncia":
			if not is_instance_valid(_denounce_to):
				_denounce_to = _nearest_police()
				if _denounce_to == null:
					GameState.mark_wanted("%s ha llamado a la policía" % display_name)
					calm_down()
					return
			if distance_to_cell(_denounce_to.cell) <= 4:
				say("¡Agente! ¡Ese me ha robado!", 3.0)
				_denounce_to.say("¿Cuál? Vale, vamos.")
				_denounce_to.investigate(last_seen)
				GameState.mark_wanted("%s te ha denunciado a %s" % [display_name, _denounce_to.display_name])
				calm_down()
			elif not is_moving() or randf() < 0.2:
				walk_to(_denounce_to.cell)
		"aparta":
			if not is_moving():
				calm_down()
		"acerca":
			if distance_to_cell(player.cell) <= 3:
				stop()
				if remembers("cliente") > 0:
					say(["¿Tienes algo?", "Hey, my friend! Same as yesterday?", "¿Me pasas lo de siempre?"].pick_random(), 3.0)
				else:
					say(["¡Eh, colega!", "¡Hombre! ¿Qué tal?", "Gracias por lo del otro día"].pick_random(), 3.0)
				calm_down()
			elif not is_moving():
				calm_down()


## Parado, gira la cabeza a un lado y a otro (para que el cono barra la calle).
func _look_around(delta: float, pace: float) -> void:
	_look_timer -= delta * pace
	if _look_timer <= 0.0:
		_look_timer = randf_range(1.5, 4.0)
		_look_yaw = atan2(facing().x, facing().z) + randf_range(-1.6, 1.6)
	_face(Vector3(sin(_look_yaw), 0, cos(_look_yaw)), delta * 0.25 * pace)


func _nearest_police() -> Npc:
	if world == null:
		return null
	var best: Npc = null
	for n in world.npcs:
		if n.kind == "policia" and is_instance_valid(n) and (best == null or n.distance_to_cell(cell) < best.distance_to_cell(cell)):
			best = n
	return best


func _clock() -> float:
	return Time.get_ticks_msec() / 1000.0


## Dibuja en el suelo lo que ve, recortado por los edificios, como en *Commandos*.
## El color dice qué piensa: tranquilo, con sospecha o persiguiéndote.
func _update_cone() -> void:
	if not cone_visible or city == null:
		if _cone:
			_cone.visible = false
		return
	if _cone == null:
		if _cone_material == null:
			_cone_material = StandardMaterial3D.new()
			_cone_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_cone_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_cone_material.vertex_color_use_as_albedo = true
			_cone_material.cull_mode = BaseMaterial3D.CULL_DISABLED
			_cone_material.render_priority = 1
		_cone_mesh = ImmediateMesh.new()
		_cone = MeshInstance3D.new()
		_cone.mesh = _cone_mesh
		_cone.material_override = _cone_material
		_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_cone.top_level = true
		add_child(_cone)
	_cone.visible = true
	_cone.global_transform = Transform3D.IDENTITY
	var color := C_CONE_CALM
	if mode in ["persigue", "busca"]:
		color = C_CONE_CHASE
	elif alert > 0.05:
		color = C_CONE_CALM.lerp(C_CONE_ALERT, minf(1.0, alert * 2.0))
	var edge := Color(color, color.a * 0.35)
	var v := vision()
	var origin := global_position + Vector3(0, 0.08, 0)
	var ahead := facing()
	_cone_mesh.clear_surfaces()
	_cone_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var prev := Vector3.ZERO
	for i in CONE_RAYS + 1:
		var dir := ahead.rotated(Vector3.UP, lerpf(-v.y, v.y, float(i) / CONE_RAYS))
		var p := origin + dir * city.clear_distance(global_position, dir, v.x)
		if i > 0:
			_cone_mesh.surface_set_color(color)
			_cone_mesh.surface_add_vertex(origin)
			_cone_mesh.surface_set_color(edge)
			_cone_mesh.surface_add_vertex(prev)
			_cone_mesh.surface_set_color(edge)
			_cone_mesh.surface_add_vertex(p)
		prev = p
	_cone_mesh.surface_end()
