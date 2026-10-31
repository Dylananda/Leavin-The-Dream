class_name Npc
extends Actor
## Bot del barrio. Cada tipo tiene su forma de moverse y sus frases;
## las interacciones con el jugador están en interactions.gd.

signal caught_player(npc: Npc)

## speed en metros por segundo; wander en casillas (2 m)
const KINDS := {
	"turista": {
		"label": "Turista", "speed": 10.4, "wander": 80, "accessory": "mochila",
		"names": ["Kevin", "Sven", "Giulia", "Brad", "Ingrid", "Pierre", "Hannah"],
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
		"lines": ["Circulen.", "Documentación.", "¿Todo bien por aquí?"],
	},
	"yonki": {
		"label": "Yonki", "speed": 8.8, "wander": 50, "accessory": "",
		"names": ["El Lolo", "Manoli", "El Cuervo", "Toni Calcetines", "La Yoli", "El Pirata"],
		"lines": ["¿Tienes un euro, primo?", "Ayer vi a Dios en un cajero", "Esto antes era otra cosa", "¿Fuego?"],
	},
	"educador": {
		"label": "Educadora social", "speed": 11.2, "wander": 60, "accessory": "chaleco",
		"names": ["Núria", "Marc", "Laia", "Oriol"],
		"lines": ["¿Has pasado por el Baluard?", "Si necesitas algo, aquí estamos", "¿Has comido hoy?"],
	},
	"vecino": {
		"label": "Vecino", "speed": 9.6, "wander": 30, "accessory": "",
		"names": ["Sra. Pepita", "Sr. Antonio", "Fatima", "Rajesh", "Montse"],
		"lines": ["¡Esto es una vergüenza!", "Que no se puede vivir", "Voy al mercado", "¡Ese portal no es un baño!"],
	},
	"mantero": {
		"label": "Mantero", "speed": 12.8, "wander": 20, "accessory": "",
		"names": ["Moussa", "Ibrahima", "Lamine", "Cheikh"],
		"lines": ["Gafas, bolsos, barato", "Amigo, mira", "¡Agua! ¡Water!"],
	},
}

const SKINS := [Color("f0cfb0"), Color("e0b08a"), Color("c68c5e"), Color("8d5a3b"), Color("5a3a26")]

var kind := "turista"
var home := Vector2i.ZERO
var wander_radius := 20
var money := 0
var debt := 0  ## Lo que le debe el jugador (camellos)
var player: Actor
var chasing := false
var robbed := false  ## Ya le han robado (turistas)
var last_interaction_day := -1

var _idle := 0.0
var _think := 0.0
var _chatter := randf_range(8.0, 30.0)


func init_kind(p_kind: String) -> void:
	kind = p_kind
	var k: Dictionary = KINDS[kind]
	display_name = k["names"].pick_random()
	speed = k["speed"]
	wander_radius = k["wander"]
	accessory = k["accessory"]
	look = {
		"skin": SKINS.pick_random(),
		"shirt": Color.from_hsv(randf(), randf_range(0.2, 0.7), randf_range(0.35, 0.85)),
		"pants": Color.from_hsv(randf(), 0.2, randf_range(0.2, 0.5)),
		"hair": Color.from_hsv(0.08, 0.6, randf_range(0.1, 0.6)),
	}
	match kind:
		"policia":
			look["shirt"] = Color("2a3d7a")
			look["pants"] = Color("1d2a5a")
		"turista":
			money = randi_range(20, 160)
			look["skin"] = SKINS[randi_range(0, 1)]
			look["shirt"] = Color.from_hsv(randf(), 0.6, 0.95)
		"yonki":
			money = randi_range(0, 6)
			look["shirt"] = look["shirt"].darkened(0.4)
		"educador":
			look["shirt"] = Color("e07a30")
	_idle = randf_range(0.0, 3.0)


func label() -> String:
	return "%s (%s)" % [display_name, KINDS[kind]["label"]]


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
	var sees := d < (12 if GameState.is_night() else 18)
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
