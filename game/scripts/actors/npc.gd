class_name Npc
extends Actor
## Bot del barrio. Cada tipo tiene su forma de moverse y sus frases;
## las interacciones con el jugador están en interactions.gd.

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

var kind := "turista"
var gender := "m"  ## "m" o "f", según el nombre (ver KINDS)
var home := Vector2i.ZERO
var wander_radius := 20
var money := 0
var debt := 0  ## Lo que le debe el jugador (camellos)
var player: Actor
var chasing := false
var robbed := false  ## Ya le han robado (turistas)
var last_interaction_day := -1
var known := false  ## Ya has hablado con él (los disfrazados dejan de parecer lo que no son)

var _idle := 0.0
var _think := 0.0
var _chatter := randf_range(8.0, 30.0)


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


func _process(delta: float) -> void:
	super._process(delta)
	if not GameState.alive:
		return
	_think -= delta
	_chatter -= delta
	if _chatter <= 0.0:
		_chatter = randf_range(15.0, 45.0)
		if player and distance_to_cell(player.cell) < 20:
			say(KINDS[kind]["lines"].pick_random())
	if kind == "policia":
		_police_ai()
	if chasing:
		return
	if not is_moving():
		_idle -= delta
		if _idle <= 0.0:
			_idle = randf_range(1.0, 5.0) if kind != "camello" else randf_range(4.0, 12.0)
			walk_to(city.random_walkable_near(home, wander_radius))


func _police_ai() -> void:
	if not player or _think > 0.0:
		return
	_think = 0.4
	var d := distance_to_cell(player.cell)
	var sight := (12.0 if GameState.is_night() else 18.0) * (2.5 if GameState.heat >= 90.0 else 1.0)
	var sees := d < sight
	if not chasing and sees and GameState.heat > 40.0:
		chasing = true
		say("¡Alto! ¡Policía!")
		speed = KINDS["policia"]["speed"] * 1.3
	if chasing:
		if GameState.heat <= 10.0 or d > 50:
			chasing = false
			speed = KINDS["policia"]["speed"]
			say("Se ha escapado...")
			walk_to(city.random_walkable_near(home, wander_radius))
		elif d <= 2:
			chasing = false
			speed = KINDS["policia"]["speed"]
			stop()
			caught_player.emit(self)
		else:
			walk_to(player.cell)
