class_name Hud
extends CanvasLayer
## Interfaz de la partida: barras, reloj, caída, registro de mensajes, sustancias con su
## colocón y su mono, efectos activos, menú de acciones, inventario y pantalla final.
## Se construye por código.

signal menu_closed
signal restart_requested
signal use_item_requested(id: String)

## [variable de GameState, etiqueta, color, si es mala cuando sube, explicación]
const BARS := [
	["health", "Salud", Color("4fbf5a"), false,
		"Baja con el mono, el hambre, las peleas y los excesos. A 0 te mueres."],
	["hunger", "Hambre", Color("d0a040"), true,
		"Sube con las horas (el porro abre el apetito; la farlopa y la base lo quitan). Baja comiendo. Al 100 te desmayas."],
	["fatigue", "Sueño", Color("8a7ad8"), true,
		"Sube despierto (el caballo y el alcohol dan sueño; la farlopa lo esconde y luego pasa factura). Baja durmiendo, mejor en una cama. Al 100 te quedas frito donde estés."],
	["sanity", "Mente", Color("5ac0c0"), false,
		"Salud mental. Baja al perder dignidad, con el mono, el hambre, el sueño y los bajones; sube con trato humano y descanso. A 0, ingreso en el psiquiátrico."],
	["dignity", "Dignidad", Color("4a8ad0"), false,
		"Cada punto perdido es un punto de caída. Por debajo de 30 llamas más la atención."],
	["discretion", "Discreción", Color("7a8ab8"), false,
		"Lo poco que llamas la atención. Baja al robar, pelear o consumir a la vista, y con tu aspecto (colocón, mono, mala pinta). Vacía, la policía va a por ti."],
]
const DANGER := 75.0  ## a partir de aquí (en el lado malo) la etiqueta se pone roja
const C_DANGER := Color("ff6a5a")
const MAX_LOG := 9

var _bars := {}
var _bar_labels := {}
var _subs_panel: PanelContainer
var _subs_box: VBoxContainer
var _sub_rows := {}  ## id -> {"row", "label", "high" (barra), "mono" (barra), "addiction" (cifra)}
var _fx_label: RichTextLabel
var _fx_text := ""
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
var _chat: PanelContainer  ## Conversación libre con un bot (IA)
var _chat_title: Label
var _chat_log: RichTextLabel
var _chat_deals: VBoxContainer
var _chat_input: LineEdit
var _chat_send: Button
var _chat_npc: Npc
var _chat_conv: Conversation


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
	_build_subs()
	_build_log()
	_build_help()
	_build_street()
	_build_menu()
	_build_inventory()
	_build_chat()
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
		row.tooltip_text = b[4]
		var l := Label.new()
		l.text = b[1]
		l.custom_minimum_size.x = 84
		l.add_theme_font_size_override("font_size", 15)
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(l)
		var bar := _bar(b[2], Vector2(160, 12))
		bar.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(bar)
		v.add_child(row)
		_bars[b[0]] = bar
		_bar_labels[b[0]] = l
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


func _bar(color: Color, min_size: Vector2) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = min_size
	bar.show_percentage = false
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.2, 0.2, 0.2)
	bar.add_theme_stylebox_override("background", bg)
	return bar


## Panel de abajo a la derecha: una fila por sustancia conocida (colocón arriba, mono abajo,
## enganche en cifra) y la lista de efectos activos con su causa.
func _build_subs() -> void:
	_subs_panel = _panel(Vector2(330, 0))
	_subs_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_subs_panel)
	var v := VBoxContainer.new()
	_subs_panel.add_child(v)
	var head := Label.new()
	head.text = "Sustancias · colocón / mono · enganche"
	head.add_theme_font_size_override("font_size", 14)
	head.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	v.add_child(head)
	_subs_box = VBoxContainer.new()
	_subs_box.add_theme_constant_override("separation", 3)
	v.add_child(_subs_box)
	_fx_label = RichTextLabel.new()
	_fx_label.bbcode_enabled = true
	_fx_label.fit_content = true
	_fx_label.scroll_active = false
	_fx_label.custom_minimum_size = Vector2(314, 0)
	_fx_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_label.add_theme_font_size_override("normal_font_size", 14)
	v.add_child(_fx_label)


func _add_sub_row(id: String) -> void:
	var d: Dictionary = Defs.SUBSTANCES[id]
	var row := HBoxContainer.new()
	row.tooltip_text = "%s. Arriba, el colocón: %s. Abajo, el mono: sube sin tomarla si estás enganchado (%s)." % [
		d["name"], d["fx_text"], Defs.MONO_FX_TEXT]
	var l := Label.new()
	l.text = d["name"]
	l.custom_minimum_size.x = 84
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", d["color"])
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(l)
	var bars := VBoxContainer.new()
	bars.add_theme_constant_override("separation", 2)
	bars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var high := _bar(d["color"], Vector2(180, 7))
	var mono := _bar(Color("d0443a"), Vector2(180, 7))
	for bar in [high, mono]:
		bar.mouse_filter = Control.MOUSE_FILTER_PASS
		bars.add_child(bar)
	row.add_child(bars)
	var a := Label.new()
	a.custom_minimum_size.x = 34
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	a.add_theme_font_size_override("font_size", 13)
	a.add_theme_color_override("font_color", Color("d08a3a"))
	a.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(a)
	_subs_box.add_child(row)
	_sub_rows[id] = {"row": row, "high": high, "mono": mono, "addiction": a, "label": l}


func _place_subs() -> void:
	_subs_panel.reset_size()
	var screen := get_viewport().get_visible_rect().size
	_subs_panel.position = screen - _subs_panel.size - Vector2(10, 10)


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
	for b in BARS:
		var value: float = gs.get(b[0])
		_bars[b[0]].value = value
		var bad := value if b[3] else 100.0 - value
		_bar_labels[b[0]].add_theme_color_override("font_color", C_DANGER if bad >= DANGER else Color.WHITE)
	_refresh_subs()
	var money_text := "Dinero: %d €   Banco: %d €" % [gs.money, gs.bank]
	if gs.debt > 0:
		money_text += "   Debes: %d €" % gs.debt
	_money_label.text = money_text
	_caida_label.text = "CAÍDA: %d" % int(gs.caida)
	_title_label.text = Defs.title_for(gs.caida)
	# refresh() se llama cada frame; reconstruir los botones siempre impediría pulsarlos
	if _inventory.visible and str(gs.inventory) != _inventory_shown:
		_fill_inventory()


func _refresh_subs() -> void:
	var gs := GameState
	var added := false
	for id in Defs.SUBSTANCES:  # en el orden de Defs, no en el de descubrimiento
		if gs.knows(id) and not _sub_rows.has(id):
			_add_sub_row(id)
			added = true
	if added:
		for id in Defs.SUBSTANCES:
			if _sub_rows.has(id):
				_subs_box.move_child(_sub_rows[id]["row"], -1)
	for id in _sub_rows:
		var s: Dictionary = gs.subs.get(id, {})
		if s.is_empty():  # partida nueva con otro perfil
			continue
		var r: Dictionary = _sub_rows[id]
		r["high"].value = s["high"]
		r["mono"].value = s["mono"]
		r["addiction"].text = "%d" % s["addiction"]
		r["label"].add_theme_color_override("font_color",
			C_DANGER if s["mono"] >= DANGER else Defs.SUBSTANCES[id]["color"])
	_subs_panel.visible = not _sub_rows.is_empty()
	_place_subs()


## Efectos en pantalla (shader) y lista de lo que te está pasando y por qué.
func show_effects(effects: Dictionary) -> void:
	var fx: Dictionary = effects["fx"]
	var mat := _vignette.material as ShaderMaterial
	mat.set_shader_parameter("mono", clampf(fx.get("mono", 0.0), 0.0, 1.0))
	mat.set_shader_parameter("high", fx.get("high", 0.0))
	mat.set_shader_parameter("saturate", clampf(fx.get("saturate", 0.0), 0.0, 1.5))
	mat.set_shader_parameter("drowsy", clampf(fx.get("drowsy", 0.0), 0.0, 1.0))
	mat.set_shader_parameter("tunnel", clampf(fx.get("tunnel", 0.0), 0.0, 1.0))
	mat.set_shader_parameter("paranoia", clampf(fx.get("paranoia", 0.0), 0.0, 1.0))
	mat.set_shader_parameter("double_vision", clampf(fx.get("double", 0.0), 0.0, 1.0))
	mat.set_shader_parameter("glow", clampf(fx.get("glow", 0.0), 0.0, 1.0))
	var lines := []
	for c in effects["causes"]:
		lines.append("[color=#%s]• %s[/color]" % [c[1].to_html(false), c[0]])
	var text := "\n".join(lines) if not lines.is_empty() else "[color=#808080]Ahora mismo estás sobrio. Más o menos.[/color]"
	if text != _fx_text:
		_fx_text = text
		_fx_label.text = text
		_place_subs()


func add_message(text: String, color: Color) -> void:
	_log_lines.append("[color=#%s]%s[/color]" % [color.to_html(false), text])
	while _log_lines.size() > MAX_LOG:
		_log_lines.pop_front()
	_log.text = "\n".join(_log_lines)


func set_hover(text: String, screen_pos: Vector2) -> void:
	_hover.text = text
	_hover.position = screen_pos + Vector2(14, 8)


func is_menu_open() -> bool:
	return _menu.visible or _chat.visible or (_game_over != null and _game_over.visible)


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
	close_chat()


# ------------------------------------------------------------- conversación

func _build_chat() -> void:
	_chat = _panel(Vector2(640, 0))
	_chat.visible = false
	add_child(_chat)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_chat.add_child(v)
	_chat_title = Label.new()
	_chat_title.add_theme_font_size_override("font_size", 16)
	v.add_child(_chat_title)
	_chat_log = RichTextLabel.new()
	_chat_log.bbcode_enabled = true
	_chat_log.scroll_following = true
	_chat_log.selection_enabled = true
	_chat_log.custom_minimum_size = Vector2(620, 340)
	_chat_log.add_theme_font_size_override("normal_font_size", 16)
	v.add_child(_chat_log)
	_chat_deals = VBoxContainer.new()
	v.add_child(_chat_deals)
	var row := HBoxContainer.new()
	v.add_child(row)
	_chat_input = LineEdit.new()
	_chat_input.placeholder_text = "Escribe lo que le dices y pulsa Intro"
	_chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_input.max_length = 300
	_chat_input.text_submitted.connect(func(_t): _chat_say())
	_chat_input.gui_input.connect(func(e: InputEvent):
		if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
			close_chat())
	row.add_child(_chat_input)
	_chat_send = Button.new()
	_chat_send.text = "Decir"
	_chat_send.pressed.connect(_chat_say)
	row.add_child(_chat_send)
	var bye := Button.new()
	bye.text = "Irse"
	bye.pressed.connect(close_chat)
	row.add_child(bye)


## Abre la conversación libre con `npc`; la partida queda en pausa hasta cerrarla.
func open_chat(npc: Npc, conv: Conversation) -> void:
	if _chat_conv != conv:
		if _chat_conv:
			_chat_conv.replied.disconnect(_on_chat_reply)
			_chat_conv.failed.disconnect(_on_chat_failed)
		_chat_conv = conv
		conv.replied.connect(_on_chat_reply)
		conv.failed.connect(_on_chat_failed)
	_chat_npc = npc
	_chat_title.text = "Hablando con %s" % npc.label()
	_chat_log.clear()
	var past := conv.history(npc)
	if past.is_empty():
		_chat_line("[color=#808080](%s te mira. Di algo.)[/color]" % npc.display_name)
	for line in past:
		_chat_said(line[0] == "tu", line[1])
	_clear_deals()
	_chat_set_waiting(conv.busy)
	_chat.visible = true
	_chat.reset_size()
	# arriba, bajo la placa de la calle, para no tapar el registro (ahí salen pistas y tratos)
	_chat.position = Vector2((get_viewport().get_visible_rect().size.x - _chat.size.x) / 2.0, 80)
	get_tree().paused = true
	_chat_input.grab_focus()


func close_chat() -> void:
	if _chat.visible:
		_chat.visible = false
		_chat_npc = null
		menu_closed.emit()


func _chat_say() -> void:
	var text := _chat_input.text.strip_edges()
	if text == "" or _chat_npc == null or _chat_conv.busy:
		return
	_chat_input.clear()
	_clear_deals()
	_chat_said(true, text)
	_chat_conv.say(_chat_npc, text)
	_chat_set_waiting(_chat_conv.busy)


func _chat_line(bbcode: String) -> void:
	_chat_log.append_text(bbcode + "\n")


func _chat_said(mine: bool, text: String) -> void:
	var who := "Tú" if mine else _chat_npc.display_name
	var color := "f0d890" if mine else "a8d0ff"
	_chat_line("[color=#%s][b]%s:[/b][/color] %s" % [color, who, text.replace("[", "[lb]")])


func _chat_set_waiting(waiting: bool) -> void:
	_chat_send.disabled = waiting
	_chat_input.editable = not waiting
	_chat_input.placeholder_text = "%s está pensando..." % _chat_npc.display_name if waiting else "Escribe lo que le dices y pulsa Intro"
	if not waiting:
		_chat_input.grab_focus()


func _clear_deals() -> void:
	for c in _chat_deals.get_children():
		c.queue_free()


func _on_chat_reply(npc: Npc, text: String, deals: Array, ended: bool) -> void:
	if npc != _chat_npc or not _chat.visible:
		return
	_chat_said(false, text if text != "" else "...")
	for deal in deals:
		var b := Button.new()
		b.text = Conversation.deal_label(deal)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func():
			if _chat_conv.accept_deal(npc, deal):
				_chat_line("[color=#8fd080](Aceptas el trato.)[/color]")
				_clear_deals())
		_chat_deals.add_child(b)
	_chat_set_waiting(false)
	if ended:
		_chat_line("[color=#808080](%s da la conversación por terminada.)[/color]" % npc.display_name)
		_chat_input.editable = false
		_chat_send.disabled = true
	_chat.reset_size()


func _on_chat_failed(npc: Npc, error: String) -> void:
	if npc != _chat_npc or not _chat.visible:
		return
	_chat_line("[color=#e07060](No te contesta: se queda mirándote. La IA %s.)[/color]" % error)
	_chat_set_waiting(false)


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
		if Defs.usable(id):
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
