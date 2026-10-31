class_name Hud
extends CanvasLayer
## Interfaz de la partida: barras, reloj, caída, registro de mensajes,
## menú de acciones, inventario y pantalla final. Se construye por código.

signal menu_closed
signal restart_requested
signal use_item_requested(id: String)

const BARS := [
	["health", "Salud", Color("4fbf5a")],
	["mono", "Mono", Color("d0443a")],
	["high", "Colocón", Color("b05ad0")],
	["dignity", "Dignidad", Color("4a8ad0")],
	["addiction", "Enganche", Color("d08a3a")],
	["heat", "Policía", Color("5a6ab0")],
]
const MAX_LOG := 9

var _bars := {}
var _name_label: Label
var _money_label: Label
var _clock_label: Label
var _caida_label: Label
var _title_label: Label
var _log: RichTextLabel
var _log_lines: Array[String] = []
var _menu: PanelContainer
var _menu_box: VBoxContainer
var _inventory: PanelContainer
var _inventory_box: VBoxContainer
var _inventory_shown := ""  ## Inventario que muestra ahora el panel, para no reconstruirlo sin cambios
var _game_over: PanelContainer
var _hover: Label
var _vignette: ColorRect
var _street: PanelContainer
var _street_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/vignette.gdshader")
	_vignette.material = mat
	add_child(_vignette)

	_build_stats()
	_build_log()
	_build_help()
	_build_street()
	_build_menu()
	_build_inventory()
	_hover = Label.new()
	_hover.add_theme_color_override("font_outline_color", Color.BLACK)
	_hover.add_theme_constant_override("outline_size", 4)
	_hover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hover)

	GameState.changed.connect(refresh)
	GameState.message.connect(add_message)
	refresh()


func _panel(min_size := Vector2.ZERO) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.08, 0.86)
	sb.border_color = Color(0.4, 0.3, 0.25)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(8)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = min_size
	return p


func _build_stats() -> void:
	var p := _panel(Vector2(250, 0))
	p.position = Vector2(10, 10)
	add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 15)
	v.add_child(_name_label)
	_clock_label = Label.new()
	v.add_child(_clock_label)
	for b in BARS:
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = b[1]
		l.custom_minimum_size.x = 84
		l.add_theme_font_size_override("font_size", 15)
		row.add_child(l)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(160, 12)
		bar.show_percentage = false
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var fill := StyleBoxFlat.new()
		fill.bg_color = b[2]
		bar.add_theme_stylebox_override("fill", fill)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.2, 0.2, 0.2)
		bar.add_theme_stylebox_override("background", bg)
		row.add_child(bar)
		v.add_child(row)
		_bars[b[0]] = bar
	_money_label = Label.new()
	v.add_child(_money_label)
	_caida_label = Label.new()
	_caida_label.add_theme_font_size_override("font_size", 18)
	_caida_label.add_theme_color_override("font_color", Color("d08ae8"))
	v.add_child(_caida_label)
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 15)
	_title_label.add_theme_color_override("font_color", Color("b8a0c8"))
	v.add_child(_title_label)


func _build_log() -> void:
	var p := _panel(Vector2(520, 0))
	p.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.position = Vector2(10, -10)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.fit_content = true
	_log.scroll_active = false
	_log.custom_minimum_size = Vector2(500, 0)
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log.add_theme_font_size_override("normal_font_size", 16)
	p.add_child(_log)


func _build_help() -> void:
	var l := Label.new()
	l.text = "WASD: andar (Shift: correr)  ·  Clic: ir / interactuar  ·  I: inventario  ·  R: rebuscar  ·  Z: dormir aquí  ·  Q/E: girar cámara  ·  Rueda: zoom"
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 10)


## Placa con el nombre de la calle en la que estás, imitando las de mármol de Barcelona.
func _build_street() -> void:
	_street = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("f2efe6")
	sb.border_color = Color("2c3a5a")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	_street.add_theme_stylebox_override("panel", sb)
	_street.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_street_label = Label.new()
	_street_label.add_theme_font_size_override("font_size", 18)
	_street_label.add_theme_color_override("font_color", Color("1d2a48"))
	_street.add_child(_street_label)
	_street.visible = false
	add_child(_street)


func set_street(name: String) -> void:
	_street.visible = name != ""
	if name == _street_label.text:
		return
	_street_label.text = name
	_street.reset_size()
	_street.position = Vector2((get_viewport().get_visible_rect().size.x - _street.size.x) / 2.0, 34)


func _build_menu() -> void:
	_menu = _panel(Vector2(340, 0))
	_menu.set_anchors_preset(Control.PRESET_CENTER)
	_menu.visible = false
	add_child(_menu)
	_menu_box = VBoxContainer.new()
	_menu.add_child(_menu_box)


func _build_inventory() -> void:
	_inventory = _panel(Vector2(300, 0))
	_inventory.visible = false
	add_child(_inventory)
	_inventory_box = VBoxContainer.new()
	_inventory.add_child(_inventory_box)


func refresh() -> void:
	var gs := GameState
	if gs.profile.is_empty():
		return
	_name_label.text = "%s · %s" % [gs.profile["name"], gs.profile["title"]]
	_clock_label.text = gs.clock_text() + ("  (noche)" if gs.is_night() else "")
	for key in _bars:
		_bars[key].value = gs.get(key)
	var money_text := "Dinero: %d €   Banco: %d €" % [gs.money, gs.bank]
	if gs.debt > 0:
		money_text += "   Debes: %d €" % gs.debt
	_money_label.text = money_text
	_caida_label.text = "CAÍDA: %d" % int(gs.caida)
	_title_label.text = Defs.title_for(gs.caida)
	var mat := _vignette.material as ShaderMaterial
	mat.set_shader_parameter("mono", clampf((gs.mono - 50.0) / 50.0, 0.0, 1.0))
	mat.set_shader_parameter("high", clampf((gs.high - 30.0) / 70.0, 0.0, 1.0))
	# refresh() se llama cada frame; reconstruir los botones siempre impediría pulsarlos
	if _inventory.visible and str(gs.inventory) != _inventory_shown:
		_fill_inventory()


func add_message(text: String, color: Color) -> void:
	_log_lines.append("[color=#%s]%s[/color]" % [color.to_html(false), text])
	while _log_lines.size() > MAX_LOG:
		_log_lines.pop_front()
	_log.text = "\n".join(_log_lines)


func set_hover(text: String, screen_pos: Vector2) -> void:
	_hover.text = text
	_hover.position = screen_pos + Vector2(14, 8)


func is_menu_open() -> bool:
	return _menu.visible or (_game_over != null and _game_over.visible)


## Muestra un menú con acciones {"label", "do"}; al elegir una se ejecuta y se cierra.
func show_menu(title: String, actions: Array) -> void:
	for c in _menu_box.get_children():
		c.queue_free()
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 16)
	_menu_box.add_child(t)
	for a in actions:
		var b := Button.new()
		b.text = a["label"]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var fn: Callable = a["do"]
		var label: String = a["label"]
		b.pressed.connect(func():
			if OS.is_debug_build():
				print(">> %s: %s" % [title, label])
			close_menu()
			fn.call())
		_menu_box.add_child(b)
	var cancel := Button.new()
	cancel.text = "Nada, déjalo"
	cancel.pressed.connect(close_menu)
	_menu_box.add_child(cancel)
	_menu.visible = true
	_menu.reset_size()
	_menu.position = (get_viewport().get_visible_rect().size - _menu.size) / 2.0


func close_menu() -> void:
	if _menu.visible:
		_menu.visible = false
		menu_closed.emit()


func toggle_inventory() -> void:
	_inventory.visible = not _inventory.visible
	if _inventory.visible:
		_fill_inventory()


func _fill_inventory() -> void:
	_inventory_shown = str(GameState.inventory)
	for c in _inventory_box.get_children():
		c.queue_free()
	var t := Label.new()
	t.text = "Inventario (I para cerrar)"
	t.add_theme_font_size_override("font_size", 15)
	_inventory_box.add_child(t)
	if GameState.inventory.is_empty():
		var e := Label.new()
		e.text = "Bolsillos vacíos."
		_inventory_box.add_child(e)
	for id in GameState.inventory:
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = "%s ×%d" % [Defs.item_name(id), GameState.inventory[id]]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var verb := ""
		if Defs.SUBSTANCES.has(id):
			verb = "Meterse"
		elif Defs.ITEMS.get(id, {}).has("food"):
			verb = "Comer"
		elif id == "cartera":
			verb = "Vaciar"
		if verb != "":
			var b := Button.new()
			b.text = verb
			var item_id: String = id
			b.pressed.connect(func(): use_item_requested.emit(item_id))
			row.add_child(b)
		_inventory_box.add_child(row)
	_inventory.reset_size()
	var screen := get_viewport().get_visible_rect().size
	_inventory.position = Vector2(screen.x - _inventory.size.x - 10, 60)


func show_game_over(reason: String) -> void:
	var gs := GameState
	_game_over = _panel(Vector2(520, 0))
	_game_over.set_anchors_preset(Control.PRESET_CENTER)
	add_child(_game_over)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_game_over.add_child(v)
	var lines := [
		["FIN DE LA PARTIDA", 26, Color("e05a4a")],
		[reason, 15, Color.WHITE],
		["%s aguantó %d días en el Raval." % [gs.profile["name"], gs.day], 14, Color(0.8, 0.8, 0.8)],
		["Caída total: %d" % int(gs.caida), 22, Color("d08ae8")],
		["Título: %s" % Defs.title_for(gs.caida), 16, Color("d0b0e8")],
	]
	for line in lines:
		var l := Label.new()
		l.text = line[0]
		l.add_theme_font_size_override("font_size", line[1])
		l.add_theme_color_override("font_color", line[2])
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 500
		v.add_child(l)
	if not gs.milestones.is_empty():
		var m := Label.new()
		m.text = "Hitos: " + ", ".join(gs.milestones.map(func(id): return Defs.MILESTONES[id][0]))
		m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		m.custom_minimum_size.x = 500
		v.add_child(m)
	var b := Button.new()
	b.text = "Otra vida"
	b.pressed.connect(func(): restart_requested.emit())
	v.add_child(b)
	_game_over.reset_size()
	_game_over.position = (get_viewport().get_visible_rect().size - _game_over.size) / 2.0
