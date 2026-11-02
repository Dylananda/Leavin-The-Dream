class_name Lookout
extends Minigame
## Hacer de vigía (del mantero, del trilero o del camello), como un tiro de feria: pasa gente
## por la calle y hay que distinguirla. Clic izquierdo («¡Agua!») a la policía antes de que
## llegue a la manta; clic derecho para llamar a un cliente. Los de uniforme se ven venir;
## las secretas van de paisano, más despacio, se paran a mirar y se tocan el pinganillo, igual
## que un cliente se para a mirar el género (pero sin pinganillo). Con paranoia, cualquiera
## parece que se toca la oreja.
## Resultados: "ok" (acabas el turno; en `stats`, avisos, falsas alarmas y clientes) o "redada"
## (se te cuela un agente, o llamas a un secreta como si fuera un cliente).

const EDGE_X := 13.0  ## metros: por dónde entran y salen de la vista
const DANGER_X := 1.3  ## metros a cada lado de la manta: un agente sin avisar aquí es redada
const FOLD_SECONDS := 3.0  ## lo que tarda en volver a extender la manta tras un aviso
const C_WARNED := Color("6ab0ff")

var _host: Npc  ## el mantero, el trilero o el camello
var _client_kind := "turista"
var _left := Defs.LOOKOUT_SECONDS
var _spawn := 0.6
var _people: Array[Dictionary] = []  ## {actor, role, speed, dir, z, stop, stopped, warned, called, tell, done}
var _fold := 0.0  ## segundos que le quedan con la manta recogida
var _shout := ""  ## lo que se dice ahora (aviso, cliente...)
var _shout_time := 0.0
var _goods: Array[MeshInstance3D] = []


func _init(host: Npc) -> void:
	_host = host
	_client_kind = "yonki" if host.kind == "camello" else "turista"
	title = "De vigía para %s" % host.display_name
	help = "Clic izquierdo: «¡Agua!» a la policía (también de paisano)   ·   Clic derecho: llamar a un cliente"
	give_up_result = "nada"
	stats = {"avisos": 0, "falsas": 0, "clientes": 0}


func auto_result(chance: float) -> String:
	return "ok" if randf() < chance else "redada"


func _setup_stage() -> void:
	_lighting(Color("a9876a"))
	# fachadas del otro lado de la calle, con portales y escaparates
	for i in 7:
		var x := -15.0 + i * 5.0
		_box(Vector3(1.6, 2.6, 0.3), Color("3a2c24"), Vector3(x, 1.3, -13.6))
		_box(Vector3(2.0, 1.4, 0.3), Color("ffd890") if GameState.is_night() else Color("5a6a74"), Vector3(x + 2.4, 2.4, -13.6))
	var host := puppet_of(_host)
	_stage.add_child(host)
	match _host.kind:
		"mantero":
			# la manta con el género (gafas, bolsos, camisetas), en primer plano
			_box(Vector3(3.2, 0.04, 1.6), Color("f2f2ea"), Vector3(0, 0.02, -0.6))
			for i in 6:
				var g := _box(Vector3(0.4, 0.12, 0.3), Color.from_hsv(i / 6.0, 0.6, 0.8), Vector3(-1.2 + i * 0.48, 0.08, -0.6 + (i % 2) * 0.4))
				_goods.append(g)
			host.position = Vector3(4.2, 0, 1.6)
		"trilero":
			_box(Vector3(0.9, 0.7, 0.6), Color("b08850"), Vector3(0, 0.35, -0.6))
			host.position = Vector3(0, 0, 0.2)
		_:
			host.position = Vector3(3.8, 0, 1.6)
	host.rotation.y = PI  # de espaldas, mirando la calle como tú
	_camera.fov = 50.0
	_camera.look_at_from_position(Vector3(0, 3.6, 7.5), Vector3(0, 1.6, -5.0), Vector3.UP)


func _input(event: InputEvent) -> void:
	super(event)
	if _over or not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		return
	get_viewport().set_input_as_handled()
	var who := _person_at(shaky_mouse())
	if event.button_index == MOUSE_BUTTON_LEFT:
		_alarm(who)
	else:
		_call(who)


## «¡Agua!»: el de la manta recoge. Bien si era un agente; si no, una falsa alarma.
func _alarm(who: Dictionary) -> void:
	_fold = FOLD_SECONDS
	_say(["¡Agua!", "¡Agua, agua!", "¡Recoge!"].pick_random())
	if who.is_empty() or who["role"] not in ["poli", "secreta"]:
		stats["falsas"] += 1
		if not who.is_empty() and who["role"] == "cliente":
			who["done"] = true  # se asusta y se va
		return
	if not who["warned"]:
		who["warned"] = true
		stats["avisos"] += 1


## Llamar a alguien para que se acerque a comprar. A un secreta, es llamar a la policía.
func _call(who: Dictionary) -> void:
	if who.is_empty():
		return
	match who["role"]:
		"cliente":
			if not who["called"] and _fold <= 0.0:
				who["called"] = true
				_say(["¡Amigo, mira!", "¡Barato, barato!", "Psst, ¿qué buscas?"].pick_random())
		"poli", "secreta":
			finish("redada", "¡Era un secreta! Le has llamado tú." if who["role"] == "secreta" else "¿Llamas a la Urbana?", C_HUNTER)
		_:
			_say("...")


func _say(text: String) -> void:
	_shout = text
	_shout_time = 1.4


func _tick(delta: float) -> void:
	_left -= delta
	_fold = maxf(0.0, _fold - delta)
	_shout_time = maxf(0.0, _shout_time - delta)
	for g in _goods:
		g.visible = _fold <= 0.0
	if _left <= 0.0:
		finish("ok", "Fin del turno.", C_GOOD)
		return
	_spawn -= delta
	if _spawn <= 0.0 and _left > 3.0:
		_spawn = randf_range(Defs.LOOKOUT_SPAWN.x, Defs.LOOKOUT_SPAWN.y) * (1.15 - 0.3 * difficulty)
		_add_person()
	var paranoia := clampf(fx.get("paranoia", 0.0), 0.0, 1.0)
	for p in _people:
		if p["done"] and not p["called"]:
			p["speed"] = maxf(p["speed"], 6.0)  # se va deprisa
		_move(p, delta, paranoia)
		if p["role"] in ["poli", "secreta"] and not p["warned"] and absf(p["actor"].position.x) < DANGER_X:
			finish("redada", "¡Redada! No los has visto venir.", C_HUNTER)
			return
	for p in _people.duplicate():
		if absf(p["actor"].position.x) > EDGE_X + 0.5:
			p["actor"].queue_free()
			_people.erase(p)
	_status.text = "Avisos %d   ·   Falsas alarmas %d   ·   Clientes %d   ·   Quedan %d s" % [
		stats["avisos"], stats["falsas"], stats["clientes"], ceili(_left)]


## Uno que pasa: agente (de uniforme o de paisano), cliente o nadie.
func _add_person() -> void:
	var d := difficulty
	var r := randf()
	var threat := Defs.LOOKOUT_THREATS * (0.7 + 0.8 * d)
	var role := "nadie"
	var actor: Actor
	if r < threat:
		var corps := "mosso" if _host.kind == "camello" else "urbano"
		if randf() < clampf(Defs.LOOKOUT_UNDERCOVER * (0.6 + 0.8 * d), 0.0, 0.9):
			role = "secreta"
			actor = puppet_of_kind(corps + "_secreta")
		else:
			role = "poli"
			actor = puppet_of_kind(corps)
	elif r < threat + Defs.LOOKOUT_CLIENTS:
		role = "cliente"
		actor = puppet_of_kind(_client_kind)
	else:
		actor = puppet_of_kind(["vecino", "vecino", "turista", "fiestero", "yonki", "chaval"].pick_random())
	var dir: float = [-1.0, 1.0].pick_random()
	var z := randf_range(-9.0, -2.5)
	var speed := randf_range(3.6, 5.2)
	match role:
		"poli": speed = randf_range(4.2, 5.0) * (0.9 + 0.3 * d)
		"secreta": speed = randf_range(2.6, 3.4) * (0.9 + 0.3 * d)
		"cliente": speed = randf_range(2.8, 3.8)
	actor.puppet_walk = true
	actor.position = Vector3(-dir * EDGE_X, 0, z)
	actor.rotation.y = atan2(dir, 0.0)
	_stage.add_child(actor)
	_people.append({"actor": actor, "role": role, "speed": speed, "dir": dir, "z": z,
		# las secretas y los clientes se paran una vez a mirar, a unos metros de la manta
		"stop_at": randf_range(3.0, 6.5) if role in ["secreta", "cliente"] else -1.0, "stopped": 0.0,
		"warned": false, "called": false, "tell": randf_range(0.5, 2.0), "done": false, "fake": randf() < 0.35})


func _move(p: Dictionary, delta: float, paranoia: float) -> void:
	var a: Actor = p["actor"]
	var x := a.position.x
	a.arm_pose[0] = 0.0
	# un cliente llamado se acerca a la manta, compra y se va
	if p["called"] and not p["done"]:
		var to := Vector3(0.0, 0.0, -2.2) - a.position
		if to.length() < 0.4:
			p["done"] = true
			stats["clientes"] += 1
			_say("+%d €" % Defs.LOOKOUT_CLIENT_TIP)
		else:
			a.position += to.normalized() * minf(p["speed"] * delta, to.length())
			a.rotation.y = atan2(to.x, to.z)
			a.puppet_walk = true
		return
	# pararse a mirar (hacia ti y la manta) cuando llega a su sitio
	var ahead: float = -p["dir"] * x  # metros que le faltan para llegar a la manta (negativo: ya pasó)
	if p["stop_at"] > 0.0 and ahead > 0.0 and ahead < p["stop_at"] and p["stopped"] < 1.8:
		p["stopped"] += delta
		a.puppet_walk = false
		a.rotation.y = sin(_time * 2.4) * 0.7 if p["role"] == "secreta" else 0.2
	else:
		a.puppet_walk = true
		a.rotation.y = atan2(p["dir"], 0.0)
		a.position.x += p["dir"] * p["speed"] * delta
	# el pinganillo: la mano a la oreja de vez en cuando (y, con paranoia, cualquiera)
	p["tell"] -= delta
	if p["tell"] <= 0.0:
		p["tell"] = randf_range(1.6, 3.0)
	var touches: bool = p["role"] == "secreta" or (paranoia > 0.3 and p["fake"] and p["role"] == "nadie")
	if touches and p["tell"] < 0.6:
		a.arm_pose[0] = -2.7


## El que hay bajo el punto `at` de la vista (el más cercano a la cámara), o {}.
func _person_at(at: Vector2) -> Dictionary:
	var best := {}
	var best_z := -INF
	for p in _people:
		var a: Actor = p["actor"]
		var feet := to_frame(a.position)
		var top := to_frame(a.position + Vector3(0, 3.0 * a.body_size, 0))
		var h := feet.y - top.y
		var rect := Rect2(top.x - h * 0.28, top.y, h * 0.56, h)
		if rect.has_point(at) and a.position.z > best_z:
			best = p
			best_z = a.position.z
	return best


func _draw_overlay(c: Control) -> void:
	for p in _people:
		var a: Actor = p["actor"]
		var head := to_frame(a.position + Vector3(0, 3.4 * a.body_size, 0))
		if p["warned"]:
			_icon(c, head, "!", C_WARNED, 26)
		elif p["called"] and not p["done"]:
			_icon(c, head, "€", C_GOOD, 26)
	var host := to_frame(Vector3(0, 3.6, 0))
	if _shout_time > 0.0:
		_icon(c, host + Vector2(0, -30), _shout, Color("fffbe8"), 22)
	# punto de mira
	var m := shaky_mouse()
	c.draw_arc(m, 16.0, 0.0, TAU, 24, Color.BLACK, 4.0)
	c.draw_arc(m, 16.0, 0.0, TAU, 24, Color("fffbe8"), 2.0)
	c.draw_line(m - Vector2(24, 0), m - Vector2(8, 0), Color("fffbe8"), 2.0)
	c.draw_line(m + Vector2(8, 0), m + Vector2(24, 0), Color("fffbe8"), 2.0)
	c.draw_line(m - Vector2(0, 24), m - Vector2(0, 8), Color("fffbe8"), 2.0)
	c.draw_line(m + Vector2(0, 8), m + Vector2(0, 24), Color("fffbe8"), 2.0)
