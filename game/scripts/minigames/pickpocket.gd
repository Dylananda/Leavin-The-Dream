class_name Pickpocket
extends Minigame
## Robar al descuido, en primer plano: la víctima en plano medio y tus dos manos. Con WASD,
## una mano le distrae (un plano, un mechero) y le hace mirar hacia ella; con el ratón, la
## otra va al bolsillo y, con el botón pulsado, saca el botín. Si te ve la mano metida,
## sospecha («?» amarillo) y, llena la sospecha, te pilla («!» rojo).
## La víctima mira a su aire: a los lados, a ti de frente o, si es desconfiada, se palpa el
## bolsillo. La cartera en la mochila solo se alcanza cuando se gira del todo.
## También sirve para robar en una tienda: con `loot` "litrona" (el estante del súper, con el
## dependiente vigilando) o "propina" (el platito de la barra, con el camarero), el botín no
## está en un bolsillo sino en un sitio fijo junto a quien vigila.
## Resultados: "ok" (lo sacas), "pillado" o "nada" (se va o lo dejas).

const YAW_MAX := 80.0  ## grados que gira la víctima a cada lado
const SIGHT := 0.6  ## anchura de su mirada (en unidades de `_look`, de -1 a 1)
const HAND_SPEED := 520.0  ## píxeles por segundo de la mano que distrae (WASD)
const HAND_R := 22.0
const REACH := 34.0  ## píxeles del bolsillo dentro de los que la mano lo alcanza
const NEAR := 150.0  ## píxeles: más cerca del bolsillo, la mano ya es sospechosa si la ve
const C_WALLET := Color("6b4226")
const C_PHONE := Color("1c1c22")
const C_MAP := Color("efe6c8")
const C_BOTTLE := Color("3a7a3a")
const C_COINS := Color("e0b040")
## Lo que se dice de cada botín: [título, nombre en el marcador, lo que te llevas, lo que dice
## la mano que distrae].
const LOOT := {
	"cartera": ["Robarle la cartera a %s", "Cartera", "la cartera", "Excuse me... ¿Sagrada Familia?"],
	"movil": ["Robarle el móvil a %s", "Móvil", "el móvil", "Bro, ¿tienes fuego?"],
	"litrona": ["Robar una litrona en el súper", "Litrona", "la litrona", "Perdona, ¿tenéis tabaco?"],
	"propina": ["Robar la propina del platito", "Propina", "la propina", "¿Me cobras? ¿Cuánto es?"],
}

var _npc: Npc
var _loot := "cartera"  ## "cartera" o "movil"
var _victim: Actor
var _in_backpack := false
var _fixed := false  ## el botín está en un sitio fijo (tienda), no en un bolsillo
var _target := Vector3.ZERO  ## (fijo) dónde está, en la escena
var _side := 1.0  ## bolsillo en el lado +X (izquierda de la víctima) o -X
var _look := 0.0  ## hacia dónde mira: -1 izquierda de la pantalla, 0 a ti, 1 derecha
var _look_target := 0.0
var _wander := 1.0
var _pat := 0.0  ## segundos que le quedan palpándose el bolsillo
var _interest := 0.0  ## lo que le llama la mano que distrae (1 = la mira)
var _suspicion := 0.0
var _progress := 0.0  ## lo que has sacado del botín (1 = fuera)
var _left := Defs.PICK_SECONDS
var _hand_l := Vector2.ZERO  ## mano que distrae (WASD)
var _hand_r := Vector2.ZERO  ## mano que roba (ratón)
var _wasd := Vector2.ZERO
var _talk := 0.0  ## segundos que le queda al bocadillo de lo que le dices


func _init(npc: Npc, loot: String) -> void:
	_npc = npc
	_loot = loot
	title = LOOT[loot][0] % npc.display_name if "%s" in LOOT[loot][0] else LOOT[loot][0]
	_fixed = loot in ["litrona", "propina"]
	if _fixed:
		help = "WASD: la mano que distrae   ·   Ratón: la otra mano   ·   Mantén el clic en %s para cogerla" % ("el estante" if loot == "litrona" else "el platito")
	help = "WASD: la mano que distrae   ·   Ratón: la otra mano   ·   Mantén el clic en el bolsillo para sacarlo"
	give_up_result = "nada"


func auto_result(chance: float) -> String:
	return "ok" if randf() < chance else "pillado"


func _setup_stage() -> void:
	_victim = puppet_of(_npc)
	_stage.add_child(_victim)
	_side = [-1.0, 1.0].pick_random()
	if _loot == "litrona":
		_lighting(Color("d8dce0"))
		_box(Vector3(8, 3.4, 0.3), Color("c8ccd0"), Vector3(0, 2.4, -13.6))  # la pared del súper
		_box(Vector3(1.2, 1.9, 0.5), Color("8a9098"), Vector3(_side * 1.5, 0.95, -0.2))  # el estante
		_target = Vector3(_side * 1.5, 1.35, 0.1)
	elif _loot == "propina":
		_lighting(Color("c08a50"))
		_box(Vector3(8, 3.4, 0.3), Color("4a3020"), Vector3(0, 2.4, -13.6))  # el fondo del bar
		_box(Vector3(3.6, 1.1, 0.6), Color("6a4a30"), Vector3(0, 0.55, 0.7))  # la barra
		_target = Vector3(_side * 0.9, 1.15, 0.75)
	else:
		_lighting(Color("b98a5e"))
		_box(Vector3(5, 3.2, 0.3), Color("2a3a44"), Vector3(-4.5, 2.4, -13.6))  # escaparate
		_box(Vector3(3, 2.4, 0.3), Color("ffd890") if GameState.is_night() else Color("4a5a64"), Vector3(4, 2.0, -13.6))
	_in_backpack = _loot == "cartera" and _victim.accessory == "mochila" and randf() < 0.5
	_camera.fov = 40.0
	_camera.look_at_from_position(Vector3(0.5, 2.25, 3.5), Vector3(0, 2.05, 0), Vector3.UP)
	_hand_l = Vector2(FRAME.x * 0.2, FRAME.y * 0.62)
	_hand_r = Vector2(FRAME.x * 0.8, FRAME.y * 0.85)
	_left = Defs.PICK_SECONDS * (1.1 - 0.3 * difficulty)
	stats = {"loot": _loot}


func _tick(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		finish("nada", "%s se va. No ha habido ocasión." % _npc.display_name, Color(0.85, 0.85, 0.85))
		return
	var head := _head()
	# mano que distrae: WASD (con retraso si vas borracho)
	var v := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	_wasd = _wasd.lerp(v.normalized(), minf(1.0, delta * lerpf(30.0, 3.0, clampf(fx.get("lag", 0.0), 0.0, 1.0))))
	var before := _hand_l
	_hand_l = (_hand_l + _wasd * HAND_SPEED * delta).clamp(Vector2(30, 30), FRAME - Vector2(30, 30))
	var moved := _hand_l.distance_to(before)
	if moved > 1.0:
		_talk = 1.2
	_talk = maxf(0.0, _talk - delta)
	# le llama la atención si se mueve a la altura de los ojos, y más si ya la ve
	if _hand_l.y < FRAME.y * 0.7:
		_interest += moved * Defs.PICK_INTEREST * (0.4 + 0.6 * _sees(_hand_l))
	_interest = clampf(_interest - Defs.PICK_BORED * delta, 0.0, 1.3)
	# demasiado cerca de la cara molesta
	if _hand_l.distance_to(head) < 70.0:
		_suspicion += 0.25 * delta
	# mano que roba: el ratón, con el temblor y el retraso
	var r_before := _hand_r
	_hand_r = _hand_r.lerp(shaky_mouse().clamp(Vector2.ZERO, FRAME), minf(1.0, delta * lerpf(30.0, 5.0, clampf(fx.get("lag", 0.0), 0.0, 1.0))))
	var speed := _hand_r.distance_to(r_before) / maxf(delta, 0.001)
	_update_look(delta)
	# lo que ve de tu mano cerca de su bolsillo
	var pocket := _pocket()
	var near := _hand_r.distance_to(pocket) < NEAR
	var inside := _hand_r.distance_to(pocket) < REACH and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var seen := _sees(_hand_r) if _pat <= 0.0 else 1.0
	if near:
		var gain := Defs.PICK_SUSPICION * seen * (0.35 + 0.65 * float(inside)) * (0.6 + 0.8 * difficulty)
		gain += seen * minf(speed / 900.0, 1.0) * 0.5
		if _pat > 0.0 and inside:
			gain += 2.0  # se palpa el bolsillo y encuentra tu mano
		_suspicion += gain * delta
	if seen < 0.1 or not near:
		_suspicion -= 0.12 * delta
	_suspicion = maxf(0.0, _suspicion)
	if _suspicion >= 1.0:
		finish("pillado", "¡Te ha pillado!", C_HUNTER)
		return
	if inside and _reachable():
		_progress += delta / (Defs.PICK_EXTRACT * (0.8 + 0.5 * difficulty))
		if _progress >= 1.0:
			finish("ok", "¡Fuera! Te llevas %s." % LOOT[_loot][2], C_GOOD)
			return
	_status.text = "Sospecha %d %%   ·   %s %d %%   ·   Se va en %d s" % [
		roundi(_suspicion * 100.0), LOOT[_loot][1], roundi(_progress * 100.0), ceili(_left)]


## A dónde mira: a la mano que distrae si le interesa; si no, a su aire (y, cuanto más
## desconfiada, más a ti o a su bolsillo).
func _update_look(delta: float) -> void:
	_pat = maxf(0.0, _pat - delta)
	_wander -= delta
	if _interest >= 0.6:
		_look_target = _dir_of(_hand_l)
	elif _wander <= 0.0:
		_wander = randf_range(0.9, 2.2) * (1.3 - 0.6 * difficulty)
		var r := randf()
		if r < 0.12 + 0.2 * difficulty:
			_pat = 0.8
			_look_target = _dir_of(_pocket())
		elif r < 0.4 + 0.25 * difficulty:
			_look_target = 0.0  # a ti, de frente
		else:
			_look_target = randf_range(-1.0, 1.0)
	_look = move_toward(_look, _look_target, delta * (1.8 + 2.2 * difficulty))
	_victim.rotation.y = deg_to_rad(_look * YAW_MAX)
	var arm := 0 if _side < 0.0 else 1  # el brazo derecho de la marioneta está en -X
	_victim.arm_pose[arm] = -0.35 * absf(sin(_time * 14.0)) if _pat > 0.0 else 0.0


## Cuánto ve la víctima el punto `p` de la vista (0..1).
func _sees(p: Vector2) -> float:
	return clampf(1.0 - absf(_look - _dir_of(p)) / SIGHT, 0.0, 1.0)


## La dirección (como `_look`) en la que la víctima tiene que mirar para ver `p`.
func _dir_of(p: Vector2) -> float:
	return clampf((p.x - _head().x) / (FRAME.x * 0.4), -1.0, 1.0)


func _head() -> Vector2:
	return to_frame(_victim.position + Vector3(0, 1.9 * Actor.SCALE * _victim.body_size, 0))


func _pocket_local() -> Vector3:
	var p := Vector3(0, 1.15, -0.32) if _in_backpack else Vector3(_side * 0.36, 0.95, 0.06)
	return p * Actor.SCALE * _victim.body_size


func _pocket() -> Vector2:
	if _fixed:
		return to_frame(_target)
	return to_frame(_victim.transform * _pocket_local())


## El bolsillo (o la mochila) queda a tu alcance: no está del todo de espaldas a ti.
func _reachable() -> bool:
	if _fixed:
		return true
	var normal := Vector3(0, 0, -1) if _in_backpack else Vector3(_side, 0, 0)
	return (_victim.basis * normal).z > -0.45


func _draw_overlay(c: Control) -> void:
	var skin: Color = GameState.profile.get("look", {}).get("skin", Color("d9a77c"))
	var sleeve: Color = GameState.profile.get("look", {}).get("shirt", Color.GRAY)
	# el botín asomando del bolsillo (sale según lo que lo has sacado)
	if _reachable() and _progress < 1.0:
		var p := _pocket() + Vector2(0, -_progress * 22.0)
		if _loot == "propina":
			for i in 4:
				c.draw_circle(p + Vector2(-9 + i * 6, -i % 2 * 3), 7.0, Color.BLACK)
				c.draw_circle(p + Vector2(-9 + i * 6, -i % 2 * 3), 5.0, C_COINS)
		else:
			var col: Color = {"cartera": C_WALLET, "movil": C_PHONE, "litrona": C_BOTTLE}[_loot]
			var size: Vector2 = {"cartera": Vector2(22, 16), "movil": Vector2(14, 24), "litrona": Vector2(14, 36)}[_loot]
			var r := Rect2(p - size / 2.0, size)
			c.draw_rect(r.grow(2.0), Color.BLACK)
			c.draw_rect(r, col)
	if _pat > 0.0:
		_icon(c, _pocket() + Vector2(0, 34), "*mira el estante*" if _loot == "litrona" else ("*mira el platito*" if _loot == "propina" else "*se palpa*"), Color(1, 1, 1, 0.85), 16)
	# sospecha sobre la cabeza
	var head := _head() + Vector2(0, -95)
	if _suspicion > 0.7:
		_icon(c, head, "!", C_HUNTER, 40)
	elif _suspicion > 0.2:
		_icon(c, head, "?", C_SUSPECT, 36)
	# tus manos, que salen de abajo
	_arm(c, Vector2(FRAME.x * 0.12, FRAME.y + 60), _hand_l, skin, sleeve)
	_arm(c, Vector2(FRAME.x * 0.9, FRAME.y + 60), _hand_r, skin, sleeve)
	# lo que lleva la mano que distrae
	if _loot == "cartera":
		var m := Rect2(_hand_l + Vector2(-34, -52), Vector2(60, 40))
		c.draw_rect(m.grow(2.0), Color.BLACK)
		c.draw_rect(m, C_MAP)
		for i in 3:
			c.draw_line(m.position + Vector2(6, 10 + i * 10), m.position + Vector2(54, 6 + i * 12), Color("c05a4a"), 2.0)
	else:
		c.draw_rect(Rect2(_hand_l + Vector2(-6, -40), Vector2(12, 22)), Color("e04040"))
		if fmod(_time, 0.3) < 0.2:
			c.draw_circle(_hand_l + Vector2(0, -48), 6.0, Color("ffb030"))
	_hand(c, _hand_l, skin, false)
	var pinch := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	_hand(c, _hand_r, skin, pinch)
	if _progress > 0.0 and pinch and _hand_r.distance_to(_pocket()) < REACH:
		var col: Color = {"cartera": C_WALLET, "movil": C_PHONE, "litrona": C_BOTTLE, "propina": C_COINS}[_loot]
		c.draw_rect(Rect2(_hand_r - Vector2(9, 14), Vector2(18, 12)), col)
	if _talk > 0.0:
		var line: String = LOOT[_loot][3]
		_icon(c, _hand_l + Vector2(10, -78), line, Color("fffbe8"), 16)


func _arm(c: Control, from: Vector2, to: Vector2, skin: Color, sleeve: Color) -> void:
	var wrist := to + (from - to).normalized() * HAND_R * 0.8
	c.draw_line(from, wrist, Color.BLACK, 34.0)
	c.draw_line(from, wrist, sleeve, 28.0)
	c.draw_line(wrist, to, Color.BLACK, 22.0)
	c.draw_line(wrist, to, skin, 17.0)


func _hand(c: Control, at: Vector2, skin: Color, pinch: bool) -> void:
	var r := HAND_R * (0.8 if pinch else 1.0)
	c.draw_circle(at, r + 3.0, Color.BLACK)
	c.draw_circle(at, r, skin)
	# dedos: abiertos o en pinza
	for i in 4:
		var a := deg_to_rad(-140.0 + i * 30.0) if not pinch else deg_to_rad(-100.0 + i * 8.0)
		var tip := at + Vector2(cos(a), sin(a)) * r * (1.7 if not pinch else 1.3)
		c.draw_line(at + Vector2(cos(a), sin(a)) * r * 0.6, tip, Color.BLACK, 11.0)
		c.draw_line(at + Vector2(cos(a), sin(a)) * r * 0.6, tip, skin, 7.0)
