extends Control
## Pantalla de inicio: elegir qué yonki vas a ser.

var _selected := 0
var _detail: RichTextLabel
var _buttons: Array[Button] = []


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
	# la última partida guardada que sigue viva (ver Partida)
	var ultima := Partida.ultima()
	if not ultima.is_empty():
		var cont := Button.new()
		cont.text = "Continuar: %s, día %d, %s (guardada el %s)" % [ultima.get("nombre", "?"), int(ultima.get("dia", 1)),
			ultima.get("hora", ""), str(ultima.get("guardada", "")).replace("T", " a las ").left(-3)]
		cont.custom_minimum_size = Vector2(0, 48)
		cont.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		cont.pressed.connect(func():
			if Partida.cargar(ultima["ruta"]):
				get_tree().change_scene_to_file("res://scenes/world.tscn"))
		root.add_child(cont)

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
