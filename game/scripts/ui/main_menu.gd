extends Control
## Pantalla de inicio: elegir qué yonki vas a ser.

var _selected := 0
var _detail: RichTextLabel
var _buttons: Array[Button] = []
var _partidas: VBoxContainer  ## una fila por partida guardada
var _borrar: ConfirmationDialog
var _por_borrar := ""  ## ruta de la partida que se va a borrar si se confirma


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.06, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	var title := Label.new()
	title.text = "YONKILAND"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color("e07a30"))
	root.add_child(title)
	var sub := Label.new()
	sub.text = "El Raval, Barcelona. El objetivo: caer lo más bajo posible.  Elige quién eres."
	sub.add_theme_color_override("font_color", Color(0.8, 0.75, 0.7))
	root.add_child(sub)
	# las partidas guardadas (ver Partida): seguir una o borrarla
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 170
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_partidas = VBoxContainer.new()
	_partidas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_partidas)
	_borrar = ConfirmationDialog.new()
	_borrar.ok_button_text = "Borrar"
	_borrar.cancel_button_text = "No"
	_borrar.confirmed.connect(func():
		Partida.borrar(_por_borrar)
		_rehacer_partidas())
	add_child(_borrar)
	_rehacer_partidas()
	scroll.visible = _partidas.get_child_count() > 0

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 24)
	root.add_child(cols)

	var list := VBoxContainer.new()
	list.custom_minimum_size.x = 320
	cols.add_child(list)
	for i in Defs.PROFILES.size():
		var p: Dictionary = Defs.PROFILES[i]
		var b := Button.new()
		b.text = "%s — %s" % [p["name"], p["title"]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		b.custom_minimum_size.y = 40
		b.pressed.connect(_select.bind(i))
		list.add_child(b)
		_buttons.append(b)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_theme_font_size_override("normal_font_size", 16)
	right.add_child(_detail)
	var start := Button.new()
	start.text = "Bajar a la calle"
	start.custom_minimum_size = Vector2(220, 48)
	start.size_flags_horizontal = Control.SIZE_SHRINK_END
	start.pressed.connect(_start)
	right.add_child(start)

	var credits := Label.new()
	credits.text = "Mapa © OpenStreetMap contributors (ODbL) · Datos de incidentes: Open Data BCN, Guàrdia Urbana 2024 (CC BY 4.0)"
	credits.add_theme_font_size_override("font_size", 13)
	credits.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	root.add_child(credits)

	_select(0)


## Una fila por partida guardada, de la más reciente a la más vieja: quién va, qué día, la
## caída, quiénes vinieron antes, y los botones de seguir (si sigue viva) y borrar.
func _rehacer_partidas() -> void:
	for c in _partidas.get_children():
		c.queue_free()
	var lista := Partida.lista()
	if lista.is_empty():
		return
	var t := Label.new()
	t.text = "Partidas guardadas"
	t.add_theme_color_override("font_color", Color("e0a070"))
	_partidas.add_child(t)
	for p in lista:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var info := Label.new()
		info.text = _texto_partida(p)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not p.get("vivo", false):
			info.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		row.add_child(info)
		if p.get("vivo", false) and int(p.get("version", 0)) <= Partida.VERSION:
			var seguir := Button.new()
			seguir.text = "Seguir"
			var ruta: String = p["ruta"]
			seguir.pressed.connect(func():
				if Partida.cargar(ruta):
					get_tree().change_scene_to_file("res://scenes/world.tscn"))
			row.add_child(seguir)
		var borrar := Button.new()
		borrar.text = "Borrar"
		var r: String = p["ruta"]
		var quien: String = p.get("nombre", "?")
		borrar.pressed.connect(func():
			_por_borrar = r
			_borrar.dialog_text = "¿Borrar la partida de %s? No se puede deshacer." % quien
			_borrar.popup_centered())
		row.add_child(borrar)
		_partidas.add_child(row)


## «Paco, día 5, 14:20 · caída 230 · antes: Youssef (murió en la calle) · guardada el ...».
static func _texto_partida(p: Dictionary) -> String:
	var t := "%s, día %d, %s · caída %d" % [p.get("nombre", "?"), int(p.get("dia", 1)), p.get("hora", ""), int(p.get("caida", 0))]
	var antes: Array = p.get("historia", [])
	if not p.get("vivo", false) and not antes.is_empty():
		antes = antes.slice(0, -1)  # (el último es el que acaba de terminar)
	if not antes.is_empty():
		t += " · antes: " + ", ".join(antes.map(func(h): return "%s (%s)" % [h["nombre"], Defs.DESTINOS.get(h["destino"], {}).get("texto", "")]))
	if not p.get("vivo", false):
		t += " · terminada"
	return t + " · guardada el %s" % str(p.get("guardada", "")).left(16)


func _select(i: int) -> void:
	_selected = i
	for j in _buttons.size():
		_buttons[j].button_pressed = j == i
	var p: Dictionary = Defs.PROFILES[i]
	var income: Dictionary = p["income"]
	var income_text := "Ninguno"
	if income:
		income_text = "%s: %+d € cada %d días" % [income["label"], income["amount"], income["every_days"]]
	var knows := []
	for id in p["knows"]:
		knows.append("%s (enganche %d)" % [Defs.item_name(id), p["knows"][id]])
	_detail.text = "[font_size=26][b]%s[/b][/font_size]\n[color=#e0a070]%s[/color]\n\n%s\n\n[color=#a0c0e0]%s[/color]\n\n" % [
		p["name"], p["title"], p["desc"], p["perk"]] + \
		"Dinero: [b]%d €[/b]    Salud: [b]%d[/b]    Dignidad: [b]%d[/b]    Salud mental: [b]%d[/b]\nIngresos: %s\nYa conoce: %s" % [
		p["money"], p["health"], p["dignity"], p["sanity"], income_text, ", ".join(knows)]


func _start() -> void:
	Partida.pendiente = {}
	GameState.new_game(Defs.PROFILES[_selected]["id"])
	get_tree().change_scene_to_file("res://scenes/world.tscn")
