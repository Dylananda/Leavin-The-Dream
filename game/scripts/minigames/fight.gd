class_name Fight
extends Minigame
## Pelea de verdad, cara a cara: el otro en plano medio y tus puños abajo. Antes de pegar,
## levanta un brazo («!» sobre la cabeza): esquiva hacia el otro lado con A o D (si el puño
## viene por la izquierda de la pantalla, a la derecha). Cuando falla se queda abierto:
## pégale con el clic. Si le pegas con la guardia puesta apenas le haces nada; si le cortas
## mientras levanta el brazo, algo. Gana quien deja sin aguante al otro.
## El alcohol retrasa la esquiva, el colocón da fuerza y el mono la quita; el sueño cierra
## los párpados (y no ves venir el golpe).
## Resultados: "ok" (ganas) o "mal" (pierdes, o te rindes con Esc).

const WINDUP := Vector2(0.95, 0.45)  ## segundos que tarda en soltar el puño (fácil, difícil)
const PAUSE := Vector2(1.6, 0.7)  ## segundos entre un ataque suyo y el siguiente (fácil, difícil)
const OPEN_SECONDS := 0.8  ## lo que se queda abierto tras fallar
const DODGE_SECONDS := 0.45  ## lo que dura una esquiva
const PUNCH_SECONDS := 0.4  ## entre un puñetazo tuyo y el siguiente
const HIT_TAKEN := 0.22  ## aguante que te quita un golpe suyo
const HIT_OPEN := 0.3  ## lo que le quitas con un golpe cuando está abierto
const HIT_CUT := 0.12  ## ... cuando le cortas mientras levanta el brazo
const HIT_GUARD := 0.04  ## ... cuando tiene la guardia puesta
const DODGE_SHIFT := 0.9  ## metros que se aparta la cámara al esquivar

var _npc: Npc
var _rival: Actor
var _me := 1.0  ## tu aguante
var _him := 1.0  ## el suyo
var _state := "guardia"  ## "guardia", "carga" (levanta el brazo), "abierto"
var _state_left := 1.0
var _side := 0  ## brazo con el que pega: 0 viene por la izquierda de la pantalla, 1 por la derecha
var _dodge := 0.0  ## -1 a la izquierda, 1 a la derecha (mientras dura)
var _dodge_left := 0.0
var _dodge_queue: Array = []  ## esquivas pedidas que llegan con el retraso del alcohol: [segundos, lado]
var _punch_left := 0.0
var _punch_hand := 0
var _flash := 0.0  ## destello rojo cuando te pegan
var _flinch := 0.0  ## lo que se dobla él cuando le pegas
var _strength := 1.0
var _cam_x := 0.0


func _init(npc: Npc) -> void:
	_npc = npc
	title = "Pelea con %s" % npc.display_name
	help = "A / D: esquivar hacia ese lado   ·   Clic: pegar (mejor cuando falla y se queda abierto)"
	give_up_result = "mal"


func _setup_stage() -> void:
	_lighting(Color("8a7a6a"))
	_box(Vector3(4, 3.0, 0.3), Color("3a3a40"), Vector3(-5, 2.0, -13.6))  # una persiana bajada
	_rival = puppet_of(_npc)
	_stage.add_child(_rival)
	_camera.fov = 42.0
	_place_camera()
	var gs := GameState
	_strength = clampf(0.6 + gs.health / 200.0 + gs.high * 0.003 - gs.mono * 0.004, 0.4, 1.4)
	_state_left = lerpf(PAUSE.x, PAUSE.y, difficulty)


func _place_camera() -> void:
	_camera.look_at_from_position(Vector3(_cam_x, 2.3, 4.0), Vector3(_cam_x * 0.4, 2.0, 0), Vector3.UP)


func _input(event: InputEvent) -> void:
	super(event)
	if _over:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_A, KEY_D, KEY_LEFT, KEY_RIGHT]:
		var side := -1.0 if event.physical_keycode in [KEY_A, KEY_LEFT] else 1.0
		_dodge_queue.append([clampf(fx.get("lag", 0.0), 0.0, 1.0) * 0.3, side])
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_punch()


func _punch() -> void:
	if _punch_left > 0.0 or _dodge_left > 0.0:
		return
	_punch_left = PUNCH_SECONDS
	_punch_hand = 1 - _punch_hand
	var hit := HIT_GUARD
	match _state:
		"abierto": hit = HIT_OPEN
		"carga":
			hit = HIT_CUT
			_state = "guardia"  # le cortas: se le va el golpe
			_state_left = lerpf(PAUSE.x, PAUSE.y, difficulty) * 0.6
		"guardia":
			_state_left = minf(_state_left, 0.3)  # pegarle a la guardia le pica a contestar
	_him -= hit * _strength / (0.8 + 0.5 * difficulty)
	_flinch = 0.25 if hit > HIT_GUARD else 0.1
	if _him <= 0.0:
		_rival.rotation.x = -0.3
		finish("ok", "%s se rinde." % _npc.display_name, C_GOOD)


func _tick(delta: float) -> void:
	# esquivas con su retraso
	for q in _dodge_queue.duplicate():
		q[0] -= delta
		if q[0] <= 0.0:
			_dodge_queue.erase(q)
			if _dodge_left <= 0.0:
				_dodge = q[1]
				_dodge_left = DODGE_SECONDS
	_dodge_left = maxf(0.0, _dodge_left - delta)
	if _dodge_left <= 0.0:
		_dodge = 0.0
	_cam_x = lerpf(_cam_x, _dodge * DODGE_SHIFT, minf(1.0, delta * 14.0))
	_place_camera()
	_punch_left = maxf(0.0, _punch_left - delta)
	_flash = maxf(0.0, _flash - delta)
	_flinch = maxf(0.0, _flinch - delta)
	# lo que hace él
	_state_left -= delta
	if _state_left <= 0.0:
		match _state:
			"guardia":
				_state = "carga"
				_side = randi() % 2
				_state_left = lerpf(WINDUP.x, WINDUP.y, difficulty)
			"carga":
				_strike()
			"abierto":
				_state = "guardia"
				_state_left = lerpf(PAUSE.x, PAUSE.y, difficulty) * randf_range(0.7, 1.3)
	# el cuerpo: guardia, brazo levantado o abierto, y se dobla si le pegas
	var guard := -1.4 if _state == "guardia" else -0.6
	_rival.arm_pose[0] = guard
	_rival.arm_pose[1] = guard
	if _state == "carga":
		_rival.arm_pose[_side] = -2.6
	_rival.rotation.y = sin(_time * 1.7) * 0.12
	_rival.rotation.x = -_flinch * 1.2
	_status.text = "Tu aguante %d %%   ·   El suyo %d %%" % [roundi(maxf(_me, 0.0) * 100.0), roundi(maxf(_him, 0.0) * 100.0)]


## Suelta el puño: te da si no te has apartado hacia el otro lado.
func _strike() -> void:
	var away := 1.0 if _side == 0 else -1.0  # del puño que viene por la izquierda se esquiva a la derecha
	if _dodge == away:
		_state = "abierto"
		_state_left = OPEN_SECONDS * (1.2 - 0.4 * difficulty)
		return
	_me -= HIT_TAKEN * (0.8 + 0.5 * difficulty)
	_flash = 0.3
	_state = "guardia"
	_state_left = lerpf(PAUSE.x, PAUSE.y, difficulty)
	if _me <= 0.0:
		finish("mal", "Al suelo.", C_HUNTER)


func _draw_overlay(c: Control) -> void:
	var skin: Color = GameState.profile.get("look", {}).get("skin", Color("d9a77c"))
	var head := to_frame(_rival.position + Vector3(0, 1.9 * Actor.SCALE * _rival.body_size, 0))
	if _state == "carga":
		_icon(c, head + Vector2(0, -75), "!", C_HUNTER, 44)
	elif _state == "abierto":
		_icon(c, head + Vector2(0, -75), "¡Ahora!", C_GOOD, 26)
	# tus puños: uno sale hacia su cara al pegar
	for i in 2:
		var rest := Vector2(FRAME.x * (0.3 if i == 0 else 0.7), FRAME.y - 40)
		var at := rest
		if _punch_left > 0.0 and i == _punch_hand:
			at = rest.lerp(head + Vector2(0, 40), sin(_punch_left / PUNCH_SECONDS * PI))
		at += Vector2(-_cam_x * 60.0, 0)
		c.draw_circle(at, 44.0, Color.BLACK)
		c.draw_circle(at, 40.0, skin)
		for k in 4:
			c.draw_line(at + Vector2(-24 + k * 16, -20), at + Vector2(-24 + k * 16, -6), skin.darkened(0.3), 3.0)
	# aguantes arriba
	_bar(c, Vector2(20, 18), _me, "Tú")
	_bar(c, Vector2(FRAME.x - 300, 18), _him, _npc.display_name)
	if _flash > 0.0:
		c.draw_rect(Rect2(Vector2.ZERO, FRAME), Color(0.8, 0.0, 0.0, _flash))


func _bar(c: Control, at: Vector2, value: float, label: String) -> void:
	c.draw_rect(Rect2(at, Vector2(280, 18)), Color(0, 0, 0, 0.7))
	c.draw_rect(Rect2(at + Vector2(2, 2), Vector2(276 * clampf(value, 0.0, 1.0), 14)), C_HUNTER.lerp(C_GOOD, clampf(value, 0.0, 1.0)))
	_icon(c, at + Vector2(140, 34), label, Color("fffbe8"), 16)
