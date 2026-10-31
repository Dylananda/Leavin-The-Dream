extends Node
## Estado de la partida del yonki que controla el jugador (autoload "GameState").
##
## Todas las estadísticas van de 0 a 100 salvo el dinero y la caída.
## La caída es la puntuación: sube al perder dignidad y al alcanzar hitos.

signal changed
signal message(text: String, color: Color)
signal game_over(reason: String)

const C_INFO := Color(0.85, 0.85, 0.8)
const C_GOOD := Color(0.55, 0.85, 0.5)
const C_BAD := Color(0.95, 0.45, 0.4)
const C_FALL := Color(0.85, 0.55, 0.95)
const C_VOICE := Color(0.6, 0.8, 1.0)

var profile: Dictionary = {}
var money := 0
var bank := 0
var health := 100.0
var mono := 0.0
var high := 0.0
var addiction := 0.0
var dignity := 100.0
var heat := 0.0  ## Lo buscada que te tiene la policía
var caida := 0.0
var debt := 0  ## Lo que debes a los camellos
var inventory: Dictionary = {}
var milestones: Array[String] = []
var arrests := 0

var day := 1
var minute_of_day := 9.0 * 60.0  ## Se empieza a las 9:00
var alive := true
var papa_cut := false
var _next_income_day := 0
var _last_meds_day := -99
var _last_methadone_day := -99
var _voice_timer := 0.0


func new_game(profile_id: String) -> void:
	profile = Defs.profile(profile_id)
	money = profile["money"]
	bank = 0
	health = profile["health"]
	dignity = profile["dignity"]
	addiction = profile["addiction"]
	mono = addiction * 0.5
	high = 0.0
	heat = 0.0
	caida = 0.0
	debt = 0
	inventory = profile["items"].duplicate()
	milestones = []
	arrests = 0
	day = 1
	minute_of_day = 9.0 * 60.0
	alive = true
	papa_cut = false
	_next_income_day = 1 + int(profile["income"].get("every_days", 0)) if profile["income"] else 0
	_last_meds_day = -99
	_last_methadone_day = -99
	changed.emit()


func hour() -> int:
	return int(minute_of_day / 60.0)


func clock_text() -> String:
	return "Día %d · %02d:%02d" % [day, hour(), int(minute_of_day) % 60]


func is_night() -> bool:
	return hour() >= 22 or hour() < 7


## Avanza el reloj `minutes` minutos de juego aplicando el desgaste del cuerpo.
func advance(minutes: float) -> void:
	if not alive:
		return
	var m := minutes
	high = maxf(0.0, high - 0.12 * m)
	if high < 10.0:
		mono = minf(100.0, mono + addiction * 0.004 * m)
	else:
		mono = maxf(0.0, mono - 0.05 * m)
	heat = maxf(0.0, heat - 0.08 * m)
	if mono > 70.0:
		health -= 0.03 * m
	if high > 90.0:
		health -= 0.04 * m
	if mono < 30.0 and high < 30.0:
		health = minf(100.0, health + 0.004 * m)

	var prev_hour := hour()
	minute_of_day += m
	while minute_of_day >= 24.0 * 60.0:
		minute_of_day -= 24.0 * 60.0
		_new_day()
	if OS.is_debug_build() and hour() != prev_hour:
		print(debug_status())

	if profile.get("id") == "psiquiatrico":
		_voice_timer -= m
		if _voice_timer <= 0.0:
			_voice_timer = randf_range(90.0, 240.0)
			say_voice()

	_check_death("El mono te ha consumido")
	changed.emit()


func _new_day() -> void:
	day += 1
	if dignity < 20.0:
		add_caida(5.0)
		log_msg("Otro día más en lo más hondo. (+5 de caída)", C_FALL)
	var income: Dictionary = profile["income"]
	if income and day >= _next_income_day:
		_next_income_day = day + int(income["every_days"])
		if profile["id"] == "nino_bien" and papa_cut:
			return
		bank += int(income["amount"])
		if income["amount"] > 0:
			log_msg("Te han ingresado %s: %d €. Ve a un cajero." % [income["label"], income["amount"]], C_GOOD)
		else:
			log_msg("Te han cobrado %s: %d €." % [income["label"], -income["amount"]], C_BAD)
			if bank < 0:
				change_dignity(-5, "Números rojos por no pagar a tu ex.")


func say_voice() -> void:
	var voices := [
		"Las voces: «Ese turista lleva la cartera en el bolsillo de atrás».",
		"Las voces: «La paloma te está juzgando».",
		"Las voces: «Deberías llamar a tu madre. No, mejor no».",
		"Las voces: «El de la farmacia sabe lo que hiciste».",
		"Las voces: «Hoy es buen día para tocar fondo».",
	]
	log_msg(voices.pick_random(), C_VOICE)


func log_msg(text: String, color: Color = C_INFO) -> void:
	if OS.is_debug_build():
		print("[%s] %s" % [clock_text(), text])
	message.emit(text, color)


## Línea de estado para la consola de depuración.
func debug_status() -> String:
	return "[%s] salud=%d mono=%d colocón=%d dignidad=%d enganche=%d policía=%d dinero=%d banco=%d caída=%d inv=%s" % [
		clock_text(), health, mono, high, dignity, addiction, heat, money, bank, caida, inventory]


func add_money(amount: int) -> void:
	money = maxi(0, money + amount)
	changed.emit()


func add_item(id: String, count := 1) -> void:
	inventory[id] = inventory.get(id, 0) + count
	changed.emit()


func has_item(id: String) -> bool:
	return inventory.get(id, 0) > 0


func remove_item(id: String, count := 1) -> void:
	var n: int = inventory.get(id, 0) - count
	if n <= 0:
		inventory.erase(id)
	else:
		inventory[id] = n
	changed.emit()


func add_caida(points: float) -> void:
	caida += points
	changed.emit()


## Perder dignidad es caer: cada punto perdido suma un punto de caída.
func change_dignity(amount: float, reason := "") -> void:
	if amount < 0.0:
		add_caida(-amount)
	dignity = clampf(dignity + amount, 0.0, 100.0)
	if reason != "":
		log_msg("%s (%+d dignidad)" % [reason, int(amount)], C_FALL if amount < 0 else C_GOOD)
	if dignity <= 0.0:
		milestone("fondo")
	if profile.get("id") == "nino_bien" and not papa_cut and dignity < 40.0:
		papa_cut = true
		log_msg("Un amigo de papá te ha visto por el Raval. Se acabó la paga.", C_BAD)
		milestone("papa_corta")
	changed.emit()


func change_health(amount: float, cause := "") -> void:
	health = clampf(health + amount, 0.0, 100.0)
	_check_death(cause)
	changed.emit()


func milestone(id: String) -> void:
	if id in milestones:
		return
	milestones.append(id)
	var m: Array = Defs.MILESTONES[id]
	add_caida(m[1])
	log_msg("★ Hito de la caída: %s (+%d)" % [m[0], m[1]], C_FALL)


## Consume una sustancia o comida del inventario.
func consume(id: String, safe := false) -> void:
	if not has_item(id):
		return
	remove_item(id)
	if Defs.ITEMS.has(id) and Defs.ITEMS[id].has("food"):
		change_health(Defs.ITEMS[id]["food"])
		log_msg("Te comes: %s." % Defs.item_name(id), C_GOOD)
		if id == "sobras":
			change_dignity(-3)
			milestone("sobras")
		return
	var s: Dictionary = Defs.SUBSTANCES[id]
	high += s["high"]
	addiction = clampf(addiction + s["addiction"], 0.0, 100.0)
	mono = maxf(0.0, mono - s["high"] * 1.2 + s.get("mono", 0))
	change_dignity(s["dignity"])
	log_msg("Te metes: %s." % s["name"], C_INFO)
	if id == "caballo":
		milestone("primer_caballo")
	elif id == "base":
		milestone("primera_base")
	if not safe and high > 100.0 and randf() < (high - 100.0) * 0.02 * s["od"] + 0.05 * s["od"]:
		log_msg("Sobredosis. Te despiertas en el suelo con un desconocido encima.", C_BAD)
		change_health(-45.0, "Sobredosis en un portal")
		if alive:
			milestone("sobredosis")
			advance(120.0)
			return
	change_health(s["health"], "Tu cuerpo dijo basta")


func can_get_methadone() -> bool:
	return _last_methadone_day != day


func got_methadone() -> void:
	_last_methadone_day = day


func can_get_meds() -> bool:
	return profile.get("id") == "psiquiatrico" and day - _last_meds_day >= 2


func got_meds() -> void:
	_last_meds_day = day


func arrest() -> void:
	arrests += 1
	var lost: Array = []
	for id in inventory.keys():
		if Defs.SUBSTANCES.has(id) or id in ["movil", "cartera", "cobre"]:
			lost.append(id)
	for id in lost:
		inventory.erase(id)
	heat = 0.0
	log_msg("Detenido. Te quitan lo que llevabas encima y pasas la noche en el calabozo.", C_BAD)
	milestone("primera_detencion")
	add_caida(8.0)
	advance(12.0 * 60.0)
	mono = minf(100.0, mono + 25.0)
	if profile.get("id") == "sin_papeles" and arrests >= 3 and alive:
		_end("Orden de expulsión. Te deportan. El Raval no se acuerda de ti.")


func _check_death(cause: String) -> void:
	if alive and health <= 0.0:
		_end(cause if cause != "" else "Tu cuerpo dijo basta")


func _end(reason: String) -> void:
	alive = false
	changed.emit()
	game_over.emit(reason)
