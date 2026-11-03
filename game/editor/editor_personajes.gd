extends Control
## Editor de personajes: una herramienta aparte del juego para crear personajes únicos con su
## historia, aspecto, zona, rutina, estadísticas y ficha para hablar con la IA. Cada uno se
## guarda en data/personajes/<id>.json (ver Personajes) y el juego los saca a la calle.
## Se abre con editor_personajes.cmd (en la raíz del repositorio) o con
## godot --path game res://editor/editor_personajes.tscn
##
## Los campos marcados con ◌ se guardan, pero el juego todavía no los usa (Personajes.USADO).

const TAMANO_BASE := Vector2i(1600, 900)  ## más sitio que el juego: hay formulario, mapa y muñeco
const NO_USADO := " ◌"
const C_TITULO := Color("e07a30")
const C_AVISO := Color("f0c060")
const C_ERROR := Color("ff6050")
const C_SUAVE := Color(1, 1, 1, 0.55)

var _def: Dictionary = Personajes.nuevo()
var _id_cargado := ""  ## id del archivo que se está editando ("" si es nuevo)
var _sucio := false
var _cargando := false  ## mientras se rellenan los controles, no cuenta como cambio
var _refrescos: Array[Callable] = []  ## leen _def y ponen su valor en cada control

var _lista: OptionButton
var _guardados: Array[Dictionary] = []
var _tipo: OptionButton
var _tipo_desc: Label
var _amo: OptionButton  ## (perros) con quién va
var _amo_label: Label
var _muneco: VistaMuneco
var _resumen: RichTextLabel
var _avisos: RichTextLabel
var _estado: Label
var _mapa: MapaZona
var _mapa_info: Label
var _lugares_box: VBoxContainer
var _horas_box: HBoxContainer
var _misiones_box: VBoxContainer
var _descartar: ConfirmationDialog
var _pendiente: Callable  ## lo que se hará si se aceptan descartar los cambios


func _ready() -> void:
	get_tree().root.content_scale_size = TAMANO_BASE
	get_window().title = "Yonkiland · Diseñador de personajes"
	theme = _tema()
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.06, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	root.add_child(_barra())
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)
	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(tabs)
	tabs.add_child(_pestana(_tab_identidad()))
	tabs.add_child(_pestana(_tab_aspecto()))
	tabs.add_child(_pestana(_tab_zona()))
	tabs.add_child(_pestana(_tab_stats()))
	tabs.add_child(_pestana(_tab_conversacion()))
	tabs.add_child(_pestana(_tab_notas()))
	tabs.tab_changed.connect(func(i): if tabs.get_tab_control(i).name == "Zona y rutina": _mapa.enfocar.call_deferred())
	split.add_child(_panel_derecho())

	_estado = Label.new()
	_estado.add_theme_color_override("font_color", C_SUAVE)
	root.add_child(_estado)

	_descartar = ConfirmationDialog.new()
	_descartar.dialog_text = "Hay cambios sin guardar en este personaje. ¿Descartarlos?"
	_descartar.ok_button_text = "Descartar"
	_descartar.cancel_button_text = "Seguir editando"
	_descartar.confirmed.connect(func(): _pendiente.call())
	add_child(_descartar)

	_leer_guardados()
	_editar(Personajes.nuevo(), "")
	_azar()
	_sucio = false
	_actualizar()


## Tema: el de Godot, pero con las casillas sin marcar visibles sobre el fondo oscuro.
func _tema() -> Theme:
	var t := Theme.new()
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var c := Color(1, 1, 1, 0.6)
	for i in 16:
		for w in 2:
			img.set_pixel(i, w, c)
			img.set_pixel(i, 15 - w, c)
			img.set_pixel(w, i, c)
			img.set_pixel(15 - w, i, c)
	t.set_icon("unchecked", "CheckBox", ImageTexture.create_from_image(img))
	return t


# ------------------------------------------------------------------ barra y panel

func _barra() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	var title := Label.new()
	title.text = "DISEÑADOR DE PERSONAJES"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", C_TITULO)
	bar.add_child(title)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(gap)
	_lista = OptionButton.new()
	_lista.custom_minimum_size.x = 300
	_lista.item_selected.connect(_on_lista)
	bar.add_child(_lista)
	for b in [["Nuevo", _nuevo], ["Duplicar", _duplicar], ["Guardar", _guardar], ["Borrar", _borrar], ["Probar en el juego", _probar]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.pressed.connect(b[1])
		bar.add_child(btn)
	return bar


func _panel_derecho() -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 380
	box.add_theme_constant_override("separation", 8)
	_muneco = VistaMuneco.new()
	_muneco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_muneco)
	var opts := HBoxContainer.new()
	for o in [["Girar", true, func(v): _muneco.girar = v], ["Andar", false, func(v): _muneco.andar = v], ["De noche", false, func(v): _muneco.noche = v]]:
		var c := CheckBox.new()
		c.text = o[0]
		c.button_pressed = o[1]
		c.toggled.connect(o[2])
		opts.add_child(c)
	box.add_child(opts)
	_resumen = RichTextLabel.new()
	_resumen.bbcode_enabled = true
	_resumen.fit_content = true
	box.add_child(_resumen)
	var head := Label.new()
	head.text = "Avisos"
	head.add_theme_color_override("font_color", C_SUAVE)
	box.add_child(head)
	_avisos = RichTextLabel.new()
	_avisos.bbcode_enabled = true
	_avisos.custom_minimum_size.y = 160
	_avisos.add_theme_font_size_override("normal_font_size", 14)
	box.add_child(_avisos)
	return box


# ------------------------------------------------------------------ pestañas

func _tab_identidad() -> Control:
	var tab := _pagina("Identidad")
	var g := _rejilla(tab)
	_line(g, "Nombre", ["nombre"], "Como lo llaman en la calle: «La Paqui», «Sr. Ramon»...")
	_line(g, "Apodo", ["apodo"], "Otro nombre por el que lo conocen")
	_spin(g, "Edad", ["edad"], 4, 100, 1)
	_option(g, "Género", ["genero"], {"m": "Hombre", "f": "Mujer"}, func(): _actualizar_tipos())
	_etiqueta(g, "Tipo base")
	_tipo = OptionButton.new()
	_tipo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tipo.item_selected.connect(func(i):
		if _cargando:
			return
		_def["tipo"] = _tipo.get_item_metadata(i)
		_aplicar_tipo()
		_cambio())
	g.add_child(_tipo)
	_refrescos.append(func():
		_actualizar_tipos()
		for i in _tipo.item_count:
			if _tipo.get_item_metadata(i) == _def["tipo"]:
				_tipo.select(i))
	g.add_child(Control.new())
	_tipo_desc = Label.new()
	_tipo_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tipo_desc.add_theme_color_override("font_color", C_SUAVE)
	_tipo_desc.custom_minimum_size.x = 300
	g.add_child(_tipo_desc)
	# perros: con qué personaje van
	_amo_label = _lbl("Va con")
	g.add_child(_amo_label)
	_amo = OptionButton.new()
	_amo.tooltip_text = "Sale a la calle y se va con este personaje"
	_amo.item_selected.connect(func(i):
		if not _cargando:
			_def["amo"] = _amo.get_item_metadata(i)
			_cambio())
	g.add_child(_amo)
	_refrescos.append(_rehacer_amos)
	_text(g, "Historia", ["historia"], "Quién es, de dónde viene, qué le pasó, qué quiere. Es lo que te cuenta si le preguntas (y lo que sabe la IA).", 150)
	_text(g, "Fuentes", ["fuentes"], "En qué fenómeno documentado del barrio se basa: noticias, informes, entrevistas (enlaces).", 70)
	return tab


func _tab_aspecto() -> Control:
	var tab := _pagina("Aspecto")
	var azar := Button.new()
	azar.text = "Al azar según el tipo"
	azar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	azar.pressed.connect(func():
		_azar()
		_cambio())
	tab.get_child(0).add_child(azar)
	var g := _rejilla(tab)
	_color(g, "Piel", ["aspecto", "skin"], Npc.SKINS)
	_color(g, "Pelo (y barba)", ["aspecto", "hair"], Npc.HAIR_COLORS + [Color("d8d8d8"), Color("ff7ac0")])
	_option(g, "Peinado", ["aspecto", "hair_style"], TiposPersonaje.PEINADOS)
	_option(g, "Barba", ["aspecto", "facial"], TiposPersonaje.VELLO)
	_check(g, "Gafas", ["aspecto", "glasses"])
	_color(g, "Camiseta (o pelaje)", ["aspecto", "shirt"])
	_color(g, "Pantalón o falda", ["aspecto", "pants"])
	_check(g, "Falda", ["aspecto", "skirt"])
	# chaqueta: color o nada
	_etiqueta(g, "Chaqueta")
	var row := HBoxContainer.new()
	var con := CheckBox.new()
	con.text = "Lleva"
	var pick := ColorPickerButton.new()
	pick.custom_minimum_size = Vector2(120, 32)
	con.toggled.connect(func(v):
		if _cargando:
			return
		_def["aspecto"]["jacket"] = pick.color.to_html(false) if v else ""
		pick.disabled = not v
		_cambio())
	pick.color_changed.connect(func(c):
		if not _cargando and con.button_pressed:
			_def["aspecto"]["jacket"] = c.to_html(false)
			_cambio())
	row.add_child(con)
	row.add_child(pick)
	g.add_child(row)
	_refrescos.append(func():
		var j: String = _def["aspecto"]["jacket"]
		con.button_pressed = j != ""
		pick.disabled = j == ""
		if j != "":
			pick.color = Color(j))
	_option(g, "Accesorio", ["aspecto", "accesorio"], TiposPersonaje.ACCESORIOS)
	_spin(g, "Tamaño", ["aspecto", "tamano"], 0.5, 1.3, 0.02)
	return tab


func _tab_zona() -> Control:
	var tab := HBoxContainer.new()
	tab.name = "Zona y rutina"
	tab.add_theme_constant_override("separation", 12)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 400
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab.add_child(scroll)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	scroll.add_child(left)

	var g := _rejilla(left)
	_option(g, "Zona", ["zona", "tipo"], Personajes.ZONAS, func(): _mapa.queue_redraw())
	# horario
	_etiqueta(g, "Horario")
	var hbox := VBoxContainer.new()
	var todo := CheckBox.new()
	todo.text = "A todas horas"
	hbox.add_child(todo)
	_horas_box = HBoxContainer.new()
	var desde := _hora_spin()
	var hasta := _hora_spin()
	for c in [_lbl("de"), desde, _lbl("a"), hasta]:
		_horas_box.add_child(c)
	hbox.add_child(_horas_box)
	g.add_child(hbox)
	var poner_horas := func():
		_def["horario"] = [] if todo.button_pressed else [int(desde.value), int(hasta.value)]
		_horas_box.visible = not todo.button_pressed
		_cambio()
	todo.toggled.connect(func(_v): if not _cargando: poner_horas.call())
	desde.value_changed.connect(func(_v): if not _cargando: poner_horas.call())
	hasta.value_changed.connect(func(_v): if not _cargando: poner_horas.call())
	_refrescos.append(func():
		var h: Array = _def["horario"]
		todo.button_pressed = h.size() < 2
		_horas_box.visible = h.size() >= 2
		if h.size() >= 2:
			desde.value = h[0]
			hasta.value = h[1])

	# herramientas del mapa
	left.add_child(_titulo("En el mapa"))
	var modos := ButtonGroup.new()
	var tools := GridContainer.new()
	tools.columns = 2
	for m in [["Mover y mirar", MapaZona.Modo.VER], ["Dibujar zona", MapaZona.Modo.POLIGONO], ["Poner casa", MapaZona.Modo.CASA], ["Añadir lugar", MapaZona.Modo.LUGAR]]:
		var b := Button.new()
		b.text = m[0]
		b.toggle_mode = true
		b.button_group = modos
		b.button_pressed = m[1] == MapaZona.Modo.VER
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): _mapa.modo = m[1])
		tools.add_child(b)
	left.add_child(tools)
	var tl := HBoxContainer.new()
	tl.add_child(_lbl("Lugar nuevo:"))
	var tipo_l := OptionButton.new()
	for k in Personajes.LUGARES:
		tipo_l.add_item(Personajes.LUGARES[k]["label"])
		tipo_l.set_item_metadata(tipo_l.item_count - 1, k)
	tipo_l.item_selected.connect(func(i): _mapa.tipo_lugar = tipo_l.get_item_metadata(i))
	tl.add_child(tipo_l)
	left.add_child(tl)
	var limpiar := HBoxContainer.new()
	for b in [["Borrar zona", func(): _def["zona"]["poligono"].clear()], ["Quitar casa", func(): _def["zona"]["casa"].clear()]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.pressed.connect(func():
			b[1].call()
			_mapa.queue_redraw()
			_cambio())
		limpiar.add_child(btn)
	var pois := CheckBox.new()
	pois.text = "Ver sitios"
	pois.button_pressed = true
	pois.tooltip_text = "Comisarías (azul), CAS y albergues (verde), bares (rosa), súper (celeste), cajeros (blanco), iglesias"
	pois.toggled.connect(func(v):
		_mapa.ver_pois = v
		_mapa.queue_redraw())
	limpiar.add_child(pois)
	left.add_child(limpiar)
	var ayuda := _lbl("Zona: clic para poner vértices; clic derecho quita el último. Los puntos se arrastran. Rueda: zoom; arrastrar con el derecho: mover el mapa.")
	ayuda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ayuda.add_theme_color_override("font_color", C_SUAVE)
	ayuda.add_theme_font_size_override("font_size", 13)
	left.add_child(ayuda)

	left.add_child(_titulo("Rutina (lugares y horas)"))
	_lugares_box = VBoxContainer.new()
	left.add_child(_lugares_box)
	_refrescos.append(_rehacer_lugares)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.add_child(right)
	_mapa = MapaZona.new()
	_mapa.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_mapa.cambiado.connect(_cambio)
	_mapa.lugar_anadido.connect(func(_l): _rehacer_lugares())
	right.add_child(_mapa)
	_mapa_info = _lbl("")
	_mapa_info.add_theme_color_override("font_color", C_SUAVE)
	_mapa.info.connect(func(t): _mapa_info.text = t)
	right.add_child(_mapa_info)
	_refrescos.append(func():
		_mapa.poligono = _def["zona"]["poligono"]
		_mapa.casa = _def["zona"]["casa"]
		_mapa.lugares = _def["lugares"]
		_mapa.queue_redraw())
	return tab


## Una fila por lugar de la rutina: tipo, horas, nota y quitar.
func _rehacer_lugares() -> void:
	for c in _lugares_box.get_children():
		c.queue_free()
	if _def["lugares"].is_empty():
		var l := _lbl("Sin lugares: se mueve por su zona. Añade sitios donde duerme, pide o toca, con sus horas.")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_color_override("font_color", C_SUAVE)
		_lugares_box.add_child(l)
		return
	for lugar in _def["lugares"]:
		var box := VBoxContainer.new()
		var row := HBoxContainer.new()
		var tipo := OptionButton.new()
		for k in Personajes.LUGARES:
			tipo.add_item(Personajes.LUGARES[k]["label"])
			tipo.set_item_metadata(tipo.item_count - 1, k)
			if k == lugar["tipo"]:
				tipo.select(tipo.item_count - 1)
		tipo.item_selected.connect(func(i):
			lugar["tipo"] = tipo.get_item_metadata(i)
			_mapa.queue_redraw()
			_cambio())
		row.add_child(tipo)
		var desde := _hora_spin()
		var hasta := _hora_spin()
		desde.value = lugar["desde"]
		hasta.value = lugar["hasta"]
		desde.value_changed.connect(func(v):
			lugar["desde"] = int(v)
			_mapa.queue_redraw()
			_cambio())
		hasta.value_changed.connect(func(v):
			lugar["hasta"] = int(v)
			_mapa.queue_redraw()
			_cambio())
		for c in [desde, _lbl("a"), hasta]:
			row.add_child(c)
		var quitar := Button.new()
		quitar.text = "✕"
		quitar.tooltip_text = "Quitar este lugar"
		quitar.pressed.connect(func():
			_def["lugares"].erase(lugar)
			_rehacer_lugares()
			_mapa.queue_redraw()
			_cambio())
		row.add_child(quitar)
		box.add_child(row)
		var nota := LineEdit.new()
		nota.text = lugar.get("nota", "")
		nota.placeholder_text = "Dónde es (portal, cajero, esquina...)"
		nota.text_changed.connect(func(t):
			lugar["nota"] = t
			_cambio())
		box.add_child(nota)
		_lugares_box.add_child(box)
	var hint := _lbl("Horas de 0 a 24; «de 22 a 8» pasa la medianoche; iguales = todo el día.")
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", C_SUAVE)
	_lugares_box.add_child(hint)


func _tab_stats() -> Control:
	var tab := _pagina("Estadísticas")
	var g := _rejilla(tab)
	_spin(g, "Dinero encima", ["stats", "dinero"], 0, 5000, 1, " €")
	_spin(g, "Velocidad", ["stats", "velocidad"], 3, 20, 0.1, " m/s", "Un abuelo va a 5,5; un vecino, a 9,6; un camello, a 12; un repartidor en bici, a 17.")
	_slider(g, "Fuerza", ["stats", "fuerza"], "Cuánto pega en una pelea.")
	_slider(g, "Valor", ["stats", "valor"], "Si se enfrenta o huye cuando ve algo.")
	_slider(g, "Agresividad", ["stats", "agresividad"], "Lo fácil que es que empiece él la pelea.")
	_check(g, "Llama a la policía", ["stats", "llama_policia"])
	_spin(g, "Le debes", ["stats", "le_debes"], 0, 1000, 1, " €", "Lo que le debes al empezar la partida. Se le paga en su menú; una misión puede saldarlo.")
	tab.add_child(_titulo("Qué quiere" + NO_USADO))
	var quiere := HFlowContainer.new()
	for id in Defs.SUBSTANCES:
		var c := CheckBox.new()
		c.text = Defs.item_name(id)
		c.toggled.connect(func(v):
			if _cargando:
				return
			var q: Array = _def["stats"]["quiere"]
			if v and id not in q:
				q.append(id)
			elif not v:
				q.erase(id)
			_cambio())
		quiere.add_child(c)
		_refrescos.append(func(): c.button_pressed = id in _def["stats"]["quiere"])
	tab.add_child(quiere)
	tab.add_child(_titulo("Lo que lleva y lo que vende" + NO_USADO))
	var t := GridContainer.new()
	t.columns = 3
	t.add_theme_constant_override("h_separation", 16)
	for h in ["", "Lleva (unidades)", "Lo vende a (€, 0 = no)"]:
		var l := _lbl(h)
		l.add_theme_color_override("font_color", C_SUAVE)
		t.add_child(l)
	for id in Defs.SUBSTANCES.keys() + Defs.ITEMS.keys():
		t.add_child(_lbl(Defs.item_name(id)))
		for key in ["lleva", "vende"]:
			var s := SpinBox.new()
			s.max_value = 999
			s.value_changed.connect(func(v):
				if _cargando:
					return
				if v > 0:
					_def["stats"][key][id] = int(v)
				else:
					_def["stats"][key].erase(id)
				_cambio())
			t.add_child(s)
			_refrescos.append(func(): s.value = _def["stats"][key].get(id, 0))
	tab.add_child(t)
	return tab


func _tab_conversacion() -> Control:
	var tab := _pagina("Conversación")
	var intro := _lbl("La ficha que recibe la IA cuando hablas con este personaje. Lo que deje en blanco lo toma de la ficha de su tipo, si la tiene. Los tratos y sus cifras los pone el juego, no la IA.")
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_color_override("font_color", C_SUAVE)
	tab.add_child(intro)
	var g := _rejilla(tab)
	_text(g, "Quién es", ["ficha", "quien"], "En segunda persona: «Vendes rosas por las terrazas. Eres simpático, pero estás cansado...»", 80)
	_text(g, "Cómo habla", ["ficha", "habla"], "Idioma, muletillas, cómo llama al otro, si dice palabrotas...", 70)
	_text(g, "Qué sabe", ["ficha", "sabe"], "Lo que puede contar del barrio (calles, horarios, quién es quién).", 70)
	_text(g, "Qué no sabe", ["ficha", "no_sabe"], "De qué no tiene ni idea o no quiere hablar.", 60)
	_text(g, "Qué quiere", ["ficha", "quiere"], "Sus objetivos: lo que le interesa del jugador.", 60)
	_etiqueta(g, "Frases sueltas")
	var frases := TextEdit.new()
	frases.placeholder_text = "Una por línea: lo que dice al pasar («¡Rosas, rosas!»)"
	frases.custom_minimum_size.y = 110
	frases.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frases.text_changed.connect(func():
		if _cargando:
			return
		var out: Array = []
		for l in frases.text.split("\n"):
			if l.strip_edges() != "":
				out.append(l.strip_edges())
		_def["frases"] = out
		_cambio())
	g.add_child(frases)
	_refrescos.append(func(): frases.text = "\n".join(_def["frases"]))
	return tab


func _tab_notas() -> Control:
	var tab := _pagina("Misiones y notas")
	var intro := _lbl("Misiones que da este personaje: cuándo te la ofrece, qué hay que hacer (con los encargos y minijuegos que ya tiene el juego), en cuánto tiempo y qué pasa al cumplirla o al fallarla. En la partida sale en su menú («Misión «...»»), se apunta en la libreta y quien te la da lleva la «!» (y la «★» mientras está en marcha, igual que el otro personaje del objetivo).")
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_color_override("font_color", C_SUAVE)
	tab.add_child(intro)
	_misiones_box = VBoxContainer.new()
	_misiones_box.add_theme_constant_override("separation", 12)
	tab.add_child(_misiones_box)
	var add := Button.new()
	add.text = "Añadir misión"
	add.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add.pressed.connect(func():
		var m := Misiones.nueva()
		m["exito"]["efectos"].append(Misiones.efecto("dinero"))
		_def["misiones"].append(m)
		_rehacer_misiones()
		_cambio())
	tab.add_child(add)
	_refrescos.append(_rehacer_misiones)
	tab.add_child(_titulo("Notas"))
	var nota := _lbl("Lo que el editor aún no sabe expresar (relaciones, cadenas de misiones, cosas que solo hace este personaje...): Claude lo lee y lo programa a mano.")
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nota.add_theme_color_override("font_color", C_SUAVE)
	tab.add_child(nota)
	var notas := TextEdit.new()
	notas.custom_minimum_size.y = 200
	notas.placeholder_text = "Le debe un carro de supermercado a Kofi. Choca con la Sra. Encarna..."
	notas.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	notas.text_changed.connect(func():
		if not _cargando:
			_def["notas"] = notas.text
			_cambio())
	tab.add_child(notas)
	_refrescos.append(func(): notas.text = _def["notas"])
	return tab


## Un panel por misión (ver Misiones.nueva()). Se rehace entero al cambiar el tipo de objetivo
## o de un resultado, porque cambian los campos que se ven.
func _rehacer_misiones() -> void:
	for c in _misiones_box.get_children():
		c.queue_free()
	if _def["misiones"].is_empty():
		var l := _lbl("Sin misiones.")
		l.add_theme_color_override("font_color", C_SUAVE)
		_misiones_box.add_child(l)
		return
	for m in _def["misiones"]:
		_misiones_box.add_child(_panel_mision(m))


func _panel_mision(m: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.05)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var head := HBoxContainer.new()
	var titulo := LineEdit.new()
	titulo.text = m["titulo"]
	titulo.placeholder_text = "Título: «El paquete para Txell»"
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titulo.add_theme_font_size_override("font_size", 18)
	titulo.text_changed.connect(func(t):
		m["titulo"] = t
		m["id"] = Personajes.slug(t)
		_cambio())
	head.add_child(titulo)
	var quitar := Button.new()
	quitar.text = "Quitar misión"
	quitar.pressed.connect(func():
		_def["misiones"].erase(m)
		_rehacer_misiones()
		_cambio())
	head.add_child(quitar)
	box.add_child(head)
	var resumen := _lbl("→ " + Misiones.resumen(m, _nombres()))
	resumen.add_theme_color_override("font_color", Color("e0a070"))
	box.add_child(resumen)

	var g := _rejilla(box)
	_etiqueta(g, "Te dice")
	g.add_child(_m_line(m, "dice", "Lo que te dice al dártela: «Llévale esto a Txell, y ni se te ocurra abrirlo»"))

	# cuándo la ofrece
	var c: Dictionary = m["condiciones"]
	_etiqueta(g, "Te la ofrece")
	var cuando := HFlowContainer.new()
	for w in [_lbl("de"), _m_spin(c, "desde", 0, 24, 1, " h"), _lbl("a"), _m_spin(c, "hasta", 0, 24, 1, " h"),
			_lbl("  desde el día"), _m_spin(c, "dia", 1, 99, 1), _lbl("  con dignidad de"), _m_spin(c, "dignidad", 0, 100, 1),
			_m_check(c, "repetible", "Repetible (una vez al día)")]:
		cuando.add_child(w)
	g.add_child(cuando)
	_etiqueta(g, "Después de")
	var tras := {"": "nada: se puede hacer de entrada"}
	for d in _guardados + [_def]:
		var este := is_same(d, _def)
		if not este and d["id"] == _id_cargado:
			continue  # el guardado de este mismo: vale lo que se está editando
		var pid: String = Personajes.slug(_def["nombre"]) if este else d["id"]
		for otra in d.get("misiones", []):
			if not is_same(otra, m) and otra["id"] != "":
				tras[Misiones.clave(pid, otra)] = "%s · %s" % [d["nombre"], otra["titulo"]]
	g.add_child(_m_option(c, "tras", tras))

	# objetivo
	var o: Dictionary = m["objetivo"]
	_etiqueta(g, "Objetivo")
	var tipos := {}
	for k in Misiones.OBJETIVOS:
		tipos[k] = Misiones.OBJETIVOS[k]["label"]
	g.add_child(_m_option(o, "tipo", tipos, true))
	var campos: Array = Misiones.OBJETIVOS[o["tipo"]]["campos"]
	if "objeto" in campos:
		_etiqueta(g, "Objeto")
		var row := HBoxContainer.new()
		row.add_child(_m_option(o, "objeto", _objetos()))
		if "lo_da" in campos:
			row.add_child(_m_check(o, "lo_da", "Te lo da él al aceptarla"))
		g.add_child(row)
	if "lugar" in campos:
		_etiqueta(g, "Sitio")
		var lugares := {}
		for k in Misiones.LUGARES:
			lugares[k] = Interactions.POI_LABELS.get(k, k)
		var row := HBoxContainer.new()
		row.add_child(_m_option(o, "lugar", lugares))
		row.add_child(_suave("El juego elige uno de ese tipo, lejos de los otros encargos en marcha."))
		g.add_child(row)
	if "personaje" in campos:
		_etiqueta(g, "Personaje")
		g.add_child(_m_option(o, "personaje", _personajes_opciones("— elige —")))
	if "prueba" in campos:
		_etiqueta(g, "Con pruebas")
		var row := HBoxContainer.new()
		var pruebas := {"": "ninguna: hay que mentir"}
		pruebas.merge(_objetos())
		row.add_child(_m_option(o, "prueba", pruebas))
		row.add_child(_suave("Con este objeto le convences seguro; sin él, mientes. Si no cuela, no vuelve a tratar contigo (la policía, además, te ficha)."))
		g.add_child(row)
	if "desde" in campos:
		_etiqueta(g, "Mañana")
		var row := HBoxContainer.new()
		for w in [_lbl("de"), _m_spin(o, "desde", 0, 23, 1, " h"), _lbl("a"), _m_spin(o, "hasta", 1, 24, 1, " h")]:
			row.add_child(w)
		g.add_child(row)
	if "minutos" in campos:
		_etiqueta(g, "Cuánto rato")
		g.add_child(_m_spin(o, "minutos", 15, 480, 15, " min"))
	if "dificultad" in campos:
		_etiqueta(g, "Dificultad")
		var row := HBoxContainer.new()
		row.add_child(_m_spin(o, "dificultad", 0.0, 1.0, 0.05))
		row.add_child(_suave("De 0 (fácil) a 1 (casi imposible): la del minijuego, o la de colar la mentira (la ayudan tu dignidad y tu cabeza)."))
		g.add_child(row)
	if o["tipo"] != "cita":
		_etiqueta(g, "Plazo")
		var row := HBoxContainer.new()
		row.add_child(_m_spin(m, "plazo", 0.0, 168.0, 0.5, " h"))
		row.add_child(_suave("Horas de juego desde que la aceptas (una hora son 30 s); 0 = sin plazo."))
		g.add_child(row)

	for lado in [["exito", "Al cumplirla"], ["fallo", "Al fallarla (se pasa el plazo, pierdes el minijuego o no cuela)"]]:
		box.add_child(_titulo(lado[1]))
		box.add_child(_m_line(m[lado[0]], "texto", "Lo que pasa, en una frase para el registro"))
		box.add_child(_resultados(m[lado[0]]["efectos"]))
	return panel


## Filas de resultados: tipo, cifra, qué y a quién.
func _resultados(efectos: Array) -> Control:
	var box := VBoxContainer.new()
	var tipos := {}
	for k in Misiones.EFECTOS:
		tipos[k] = Misiones.EFECTOS[k]["label"]
	for ef in efectos:
		var row := HBoxContainer.new()
		var spec: Dictionary = Misiones.EFECTOS.get(ef["tipo"], {})
		var tipo := _m_option(ef, "tipo", tipos, true)
		tipo.item_selected.connect(func(_i):
			# (después de que _m_option cambie el tipo) lo que tenía del tipo anterior ya no vale
			var nuevo: Dictionary = Misiones.EFECTOS[ef["tipo"]]
			ef["que"] = _que_de(nuevo).keys()[0] if nuevo.has("que") else ""
			if not nuevo.has("quien"):
				ef["quien"] = "")
		row.add_child(tipo)
		if spec.has("valor"):
			row.add_child(_m_spin(ef, "valor", -500, 500, 1, " " + spec["valor"]))
		if spec.has("que"):
			row.add_child(_m_option(ef, "que", _que_de(spec)))
		if spec.has("quien"):
			row.add_child(_lbl("a"))
			row.add_child(_m_option(ef, "quien", _personajes_opciones("quien la da")))
		var quitar := Button.new()
		quitar.text = "✕"
		quitar.pressed.connect(func():
			efectos.erase(ef)
			_rehacer_misiones()
			_cambio())
		row.add_child(quitar)
		box.add_child(row)
	var add := Button.new()
	add.text = "Añadir resultado"
	add.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add.pressed.connect(func():
		efectos.append(Misiones.efecto())
		_rehacer_misiones()
		_cambio())
	box.add_child(add)
	return box


## Las opciones de "qué" de un tipo de resultado: objetos, favores o delitos.
func _que_de(spec: Dictionary) -> Dictionary:
	match spec.get("que", ""):
		"favor": return Misiones.FAVORES
		"delito": return Misiones.DELITOS
	return _objetos()


func _objetos() -> Dictionary:
	var out := {}
	for id in Defs.ITEMS.keys() + Defs.SUBSTANCES.keys():
		out[id] = Defs.item_name(id)
	return out


## {id: nombre} de los personajes guardados (sin los perros), con `vacio` para "".
func _personajes_opciones(vacio: String) -> Dictionary:
	var out := {"": vacio}
	for d in _guardados:
		if d["tipo"] != "perro":
			out[d["id"]] = d["nombre"]
	return out


func _nombres() -> Dictionary:
	var out := {}
	for d in _guardados:
		out[d["id"]] = d["nombre"]
	return out


func _suave(text: String) -> Label:
	var l := _lbl(text)
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", C_SUAVE)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 200
	return l


# Controles atados a una clave de un diccionario de la misión (no a una ruta de _def, como
# los de más abajo): se crean con su valor ya puesto, así que no hace falta _cargando.

func _m_line(d: Dictionary, key: String, hint: String) -> LineEdit:
	var e := LineEdit.new()
	e.text = d[key]
	e.placeholder_text = hint
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.text_changed.connect(func(t):
		d[key] = t
		_cambio())
	return e


func _m_spin(d: Dictionary, key: String, lo: float, hi: float, step: float, suffix := "") -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.suffix = suffix
	s.value = d[key]
	s.value_changed.connect(func(v):
		d[key] = int(v) if step >= 1 else v
		_cambio())
	return s


func _m_check(d: Dictionary, key: String, text: String) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = d[key]
	c.toggled.connect(func(v):
		d[key] = v
		_cambio())
	return c


## Desplegable con `items` ({valor: texto}). Con `rehacer`, al cambiar se rehacen los paneles
## (cambian los campos que se ven).
func _m_option(d: Dictionary, key: String, items: Dictionary, rehacer := false) -> OptionButton:
	var o := OptionButton.new()
	if not items.has(d[key]):
		o.add_item("%s (no existe)" % d[key])
		o.set_item_metadata(0, d[key])
	for k in items:
		o.add_item(items[k])
		o.set_item_metadata(o.item_count - 1, k)
		if k == d[key]:
			o.select(o.item_count - 1)
	o.item_selected.connect(func(i):
		d[key] = o.get_item_metadata(i)
		if rehacer:
			_rehacer_misiones.call_deferred()
		_cambio())
	return o


# ------------------------------------------------------------------ campos

## Página con scroll para una pestaña; devuelve la caja donde van sus cosas.
func _pagina(nombre: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = nombre
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	var top := HBoxContainer.new()
	box.add_child(top)
	# la pestaña es el scroll; quien la llama añade cosas a la caja
	box.set_meta("scroll", scroll)
	return box


## Lo que va en el TabContainer: el scroll de una página, o la propia pestaña si no tiene.
func _pestana(c: Control) -> Control:
	return c.get_meta("scroll", c)


func _rejilla(parent: Control) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 8)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(g)
	return g


func _lbl(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l


func _titulo(text: String) -> Label:
	var l := _lbl(text)
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", C_TITULO)
	return l


## Etiqueta de la columna izquierda; con ◌ si el juego aún no usa ese dato.
func _etiqueta(g: GridContainer, text: String, path: Array = []) -> void:
	var l := _lbl(text + (NO_USADO if not path.is_empty() and not _usado(path) else ""))
	l.custom_minimum_size.x = 150
	if not path.is_empty() and not _usado(path):
		l.tooltip_text = "Se guarda, pero el juego todavía no lo usa"
		l.mouse_filter = Control.MOUSE_FILTER_STOP
	g.add_child(l)


func _usado(path: Array) -> bool:
	var key: String = path[-1] if path[0] == "stats" else path[0]
	return key in Personajes.USADO


func _valor(path: Array) -> Variant:
	var d: Variant = _def
	for k in path:
		d = d[k]
	return d


func _poner(path: Array, v: Variant) -> void:
	var d: Variant = _def
	for k in path.slice(0, -1):
		d = d[k]
	d[path[-1]] = v


func _line(g: GridContainer, label: String, path: Array, hint := "") -> LineEdit:
	_etiqueta(g, label, path)
	var e := LineEdit.new()
	e.placeholder_text = hint
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.text_changed.connect(func(t):
		if not _cargando:
			_poner(path, t)
			_cambio())
	g.add_child(e)
	_refrescos.append(func(): e.text = str(_valor(path)))
	return e


func _text(g: GridContainer, label: String, path: Array, hint: String, height: int) -> TextEdit:
	_etiqueta(g, label, path)
	var e := TextEdit.new()
	e.placeholder_text = hint
	e.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	e.custom_minimum_size.y = height
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.text_changed.connect(func():
		if not _cargando:
			_poner(path, e.text)
			_cambio())
	g.add_child(e)
	_refrescos.append(func(): e.text = str(_valor(path)))
	return e


func _spin(g: GridContainer, label: String, path: Array, lo: float, hi: float, step: float, suffix := "", hint := "") -> SpinBox:
	_etiqueta(g, label, path)
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.suffix = suffix
	s.tooltip_text = hint
	s.value_changed.connect(func(v):
		if not _cargando:
			_poner(path, int(v) if step >= 1 else v)
			_cambio())
	if hint != "":
		var row := HBoxContainer.new()
		row.add_child(s)
		var h := _lbl(hint)
		h.add_theme_font_size_override("font_size", 13)
		h.add_theme_color_override("font_color", C_SUAVE)
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(h)
		g.add_child(row)
	else:
		g.add_child(s)
	_refrescos.append(func(): s.value = _valor(path))
	return s


## Valor de 0 a 10 con su número al lado.
func _slider(g: GridContainer, label: String, path: Array, hint: String) -> void:
	_etiqueta(g, label, path)
	var row := HBoxContainer.new()
	var s := HSlider.new()
	s.max_value = 10
	s.step = 1
	s.tick_count = 11
	s.custom_minimum_size.x = 200
	s.tooltip_text = hint
	var n := _lbl("")
	n.custom_minimum_size.x = 24
	var h := _lbl(hint)
	h.add_theme_font_size_override("font_size", 13)
	h.add_theme_color_override("font_color", C_SUAVE)
	s.value_changed.connect(func(v):
		n.text = str(int(v))
		if not _cargando:
			_poner(path, int(v))
			_cambio())
	for c in [s, n, h]:
		row.add_child(c)
	g.add_child(row)
	_refrescos.append(func():
		s.value = _valor(path)
		n.text = str(int(s.value)))


func _check(g: GridContainer, label: String, path: Array) -> CheckBox:
	_etiqueta(g, label, path)
	var c := CheckBox.new()
	c.toggled.connect(func(v):
		if not _cargando:
			_poner(path, v)
			_cambio())
	g.add_child(c)
	_refrescos.append(func(): c.button_pressed = _valor(path))
	return c


## Desplegable con las opciones `items` ({valor: texto}). `after` se llama al cambiar.
func _option(g: GridContainer, label: String, path: Array, items: Dictionary, after := Callable()) -> OptionButton:
	_etiqueta(g, label, path)
	var o := OptionButton.new()
	for k in items:
		o.add_item(items[k])
		o.set_item_metadata(o.item_count - 1, k)
	o.item_selected.connect(func(i):
		if _cargando:
			return
		_poner(path, o.get_item_metadata(i))
		if after.is_valid():
			after.call()
		_cambio())
	g.add_child(o)
	_refrescos.append(func():
		for i in o.item_count:
			if o.get_item_metadata(i) == _valor(path):
				o.select(i))
	return o


## Color en hexadecimal, con los colores del juego como muestras rápidas.
func _color(g: GridContainer, label: String, path: Array, muestras: Array = []) -> void:
	_etiqueta(g, label, path)
	var row := HBoxContainer.new()
	var pick := ColorPickerButton.new()
	pick.custom_minimum_size = Vector2(120, 32)
	pick.edit_alpha = false
	pick.color_changed.connect(func(c):
		if not _cargando:
			_poner(path, c.to_html(false))
			_cambio())
	row.add_child(pick)
	for m in muestras:
		var b := Button.new()
		b.custom_minimum_size = Vector2(26, 26)
		var sb := StyleBoxFlat.new()
		sb.bg_color = m
		sb.set_corner_radius_all(4)
		for state in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(state, sb)
		b.pressed.connect(func():
			pick.color = m
			_poner(path, (m as Color).to_html(false))
			_cambio())
		row.add_child(b)
	g.add_child(row)
	_refrescos.append(func(): pick.color = Color(_valor(path)))


func _hora_spin() -> SpinBox:
	var s := SpinBox.new()
	s.max_value = 24
	s.suffix = " h"
	return s


# ------------------------------------------------------------------ estado

## El desplegable de dueño (solo para perros): nadie o uno de los personajes guardados.
func _rehacer_amos() -> void:
	var perro: bool = _def["tipo"] == "perro"
	_amo_label.visible = perro
	_amo.visible = perro
	var was := _cargando
	_cargando = true
	_amo.clear()
	_amo.add_item("Nadie (va solo)")
	_amo.set_item_metadata(0, "")
	for d in _guardados:
		if d["tipo"] != "perro":
			_amo.add_item(d["nombre"])
			_amo.set_item_metadata(_amo.item_count - 1, d["id"])
			if d["id"] == _def.get("amo", ""):
				_amo.select(_amo.item_count - 1)
	_cargando = was


## Rellena la lista de tipos, agrupados, con su nombre en el género del personaje.
func _actualizar_tipos() -> void:
	var was := _cargando
	_cargando = true
	_tipo.clear()
	for grupo in TiposPersonaje.GRUPOS:
		_tipo.add_separator(grupo)
		for id in TiposPersonaje.del_grupo(grupo):
			var text := TiposPersonaje.label(id, _def["genero"])
			if not TiposPersonaje.en_juego(id):
				text += "   (aún no en el juego)"
			_tipo.add_item(text)
			_tipo.set_item_metadata(_tipo.item_count - 1, id)
			if id == _def["tipo"]:
				_tipo.select(_tipo.item_count - 1)
	_cargando = was


## Al cambiar de tipo: su accesorio, su uniforme, su velocidad y sus horas de partida.
func _aplicar_tipo() -> void:
	var id: String = _def["tipo"]
	var t: Dictionary = TiposPersonaje.TIPOS.get(id, {})
	var a: Dictionary = _def["aspecto"]
	a["accesorio"] = Npc.KINDS[id]["accessory"] if Npc.KINDS.has(id) else t.get("accesorio", "")
	a["tamano"] = Npc.KINDS[id].get("size", 1.0) if Npc.KINDS.has(id) else t.get("tamano", 1.0)
	for k in t.get("look", {}):
		a[k] = t["look"][k]
	if Npc.KINDS.has(id):
		var k: Dictionary = Npc.KINDS[id]
		_def["stats"]["velocidad"] = k["speed"]
		_def["horario"] = k.get("hours", []).duplicate()
		if k.has("zone") and _def["zona"]["poligono"].is_empty():
			_def["zona"]["tipo"] = k["zone"]
	_rellenar()


## Aspecto al azar con las mismas tiradas que los bots del juego (Npc.init_kind), con los
## colores de su oficio si el juego ya tiene el tipo.
func _azar() -> void:
	if Npc.KINDS.has(_def["tipo"]):
		var bot := _de_bot(_def["tipo"], "azar %d" % randi(), _def["genero"])
		_def["aspecto"] = bot["aspecto"]
		_aplicar_tipo()
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var g: String = _def["genero"]
	var look := {
		"gender": g,
		"skin": Npc.SKINS[rng.randi_range(0, Npc.SKINS.size() - 1)],
		"shirt": Color.from_hsv(rng.randf(), rng.randf_range(0.2, 0.7), rng.randf_range(0.35, 0.85)),
		"pants": Color.from_hsv(rng.randf(), 0.2, rng.randf_range(0.2, 0.5)),
		"hair": Npc.HAIR_COLORS[rng.randi_range(0, Npc.HAIR_COLORS.size() - 1)],
	}
	if _def["edad"] >= 65:
		look["hair"] = [Color("d8d8d8"), Color("b8b8b8"), Color("f0f0f0")][rng.randi_range(0, 2)]
	var styles: Array = Actor.HAIR_STYLES[g]
	look["hair_style"] = styles[rng.randi_range(0, (2 if rng.randf() < 0.5 else styles.size()) - 1)]
	look["facial"] = ""
	if g == "m" and _def["edad"] >= 16:
		var r := rng.randf()
		look["facial"] = "barba" if r < Npc.P_BEARD else ("bigote" if r < Npc.P_BEARD + Npc.P_MOUSTACHE else "")
	look["glasses"] = rng.randf() < Npc.P_GLASSES
	if rng.randf() < Npc.P_JACKET:
		look["jacket"] = Color.from_hsv(rng.randf(), rng.randf_range(0.1, 0.5), rng.randf_range(0.15, 0.45))
	look["skirt"] = g == "f" and rng.randf() < Npc.P_SKIRT
	_def["aspecto"] = Personajes.aspecto_de(look, "", 1.0)
	_aplicar_tipo()


## Un personaje sacado de un bot del juego: el tipo `kind` con el nombre `nombre`, con su
## aspecto (sale del nombre, como en el juego), su historia, su horario, su zona y su dinero.
## Con `genero`, se le cambia el género si no es el suyo (y se vuelven a tirar los rasgos).
func _de_bot(kind: String, nombre: String, genero := "") -> Dictionary:
	var npc := Npc.new()
	npc.init_kind(kind, nombre)
	if genero != "" and genero != npc.gender:
		npc.gender = genero
		npc.look["gender"] = genero
		npc.look["facial"] = ""
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(nombre)
		npc._roll_traits(rng)
	var k: Dictionary = Npc.KINDS[kind]
	var d := Personajes.nuevo(kind)
	d["nombre"] = nombre
	d["genero"] = npc.gender
	d["aspecto"] = Personajes.aspecto_de(npc.look, npc.accessory, npc.body_size)
	d["historia"] = k.get("bios", {}).get(nombre, "")
	d["horario"] = k.get("hours", []).duplicate()
	if k.has("zone"):
		d["zona"]["tipo"] = k["zone"]
	d["stats"]["velocidad"] = k["speed"]
	d["stats"]["dinero"] = npc.money
	npc.free()
	return d


func _editar(d: Dictionary, id_cargado: String) -> void:
	_def = d
	_id_cargado = id_cargado
	_rellenar()
	_sucio = false
	_actualizar()


func _rellenar() -> void:
	_cargando = true
	for r in _refrescos:
		r.call()
	_cargando = false
	_actualizar()


func _cambio() -> void:
	if _cargando:
		return
	_sucio = true
	_actualizar()


## Muñeco, resumen, avisos y título de la ventana.
func _actualizar() -> void:
	_muneco.mostrar(Personajes.look_de(_def), _def["aspecto"]["accesorio"], _def["aspecto"]["tamano"])
	var id: String = _def["tipo"]
	_tipo_desc.text = TiposPersonaje.TIPOS.get(id, {}).get("desc", "")
	var nombre: String = _def["nombre"] if _def["nombre"] != "" else "(sin nombre)"
	_resumen.text = "[font_size=22][b]%s[/b][/font_size]\n[color=#e0a070]%s, %d años[/color]" % [
		nombre, TiposPersonaje.label(id, _def["genero"]), _def["edad"]]
	var avisos := _comprobar()
	var lines := []
	for a in avisos:
		lines.append("[color=#%s]%s %s[/color]" % [(C_ERROR if a[0] else C_AVISO).to_html(false), "✖" if a[0] else "•", a[1]])
	_avisos.text = "\n".join(lines) if not lines.is_empty() else "[color=#80d080]Todo en orden.[/color]"
	get_window().title = "Yonkiland · Diseñador de personajes · %s%s" % [nombre, " *" if _sucio else ""]
	_estado.text = ("Cambios sin guardar." if _sucio else "Guardado.") if _id_cargado != "" else "Personaje nuevo, sin guardar."
	_estado.text += "   ◌ = se guarda, pero el juego todavía no lo usa."


## Lo que está mal o falta: [[es_error, texto], ...]. Con errores no se puede guardar.
func _comprobar() -> Array:
	var out := []
	var id := Personajes.slug(_def["nombre"])
	if id == "":
		out.append([true, "Falta el nombre."])
	elif id != _id_cargado and FileAccess.file_exists(Personajes.DIR + id + ".json"):
		out.append([true, "Ya hay otro personaje guardado con un nombre igual (%s)." % id])
	if not TiposPersonaje.en_juego(_def["tipo"]):
		out.append([false, "El tipo «%s» aún no existe en el juego: se guarda, pero no saldrá a la calle hasta que lo haya." % TiposPersonaje.label(_def["tipo"])])
	var zona: Dictionary = _def["zona"]
	if zona["tipo"] == "poligono" and zona["poligono"].size() < 3:
		out.append([true, "La zona dibujada necesita al menos 3 vértices (pestaña Zona y rutina)."])
	elif zona["tipo"] != "poligono" and zona["poligono"].size() >= 3:
		out.append([false, "Hay una zona dibujada, pero la zona elegida es «%s»: no se usará." % Personajes.ZONAS[zona["tipo"]]])
	if zona["casa"].size() == 2 and not _mapa.es_calle(Vector2i(zona["casa"][0], zona["casa"][1])):
		out.append([false, "La casa está dentro de un edificio: saldrá en la calle más cercana."])
	for l in _def["lugares"]:
		if not _mapa.es_calle(Vector2i(l["x"], l["y"])):
			out.append([false, "El lugar «%s» está dentro de un edificio: irá a la calle más cercana." % Personajes.LUGARES[l["tipo"]]["label"]])
		if not Personajes.activo(_def, l["desde"]):
			out.append([false, "A las %d h (lugar «%s») no está en la calle según su horario." % [l["desde"], Personajes.LUGARES[l["tipo"]]["label"]]])
	for h in 24:
		var n: int = _def["lugares"].filter(func(l): return Personajes._entre(h, l["desde"], l["hasta"])).size()
		if n > 1:
			out.append([false, "A las %d h le tocan dos lugares a la vez: irá al primero de la lista." % h])
			break
	var con_id := _def.duplicate()
	con_id["id"] = id
	out.append_array(Misiones.comprobar(con_id, _guardados.map(func(d): return d["id"])))
	if _def["historia"].strip_edges() == "":
		out.append([false, "Sin historia: es lo que cuenta si le preguntas."])
	if _def["fuentes"].strip_edges() == "" and _def["tipo"] != "perro":
		out.append([false, "Sin fuentes: los personajes se basan en fenómenos documentados del barrio."])
	if _def["ficha"]["quien"].strip_edges() == "" and not Fichas.has(_def["tipo"]) and _def["tipo"] != "perro":
		out.append([false, "Sin ficha de conversación y su tipo no tiene: no se podrá hablar con él con la IA."])
	return out


# ------------------------------------------------------------------ archivos

func _leer_guardados() -> void:
	_guardados = Personajes.cargar_todos()
	_lista.clear()
	_lista.add_item("— personaje nuevo —")
	_lista.set_item_metadata(0, "")
	var tuyos := {}
	if not _guardados.is_empty():
		_lista.add_separator("Personajes guardados")
	for d in _guardados:
		_lista.add_item("%s (%s)" % [d["nombre"], TiposPersonaje.label(d["tipo"], d["genero"])])
		_lista.set_item_metadata(_lista.item_count - 1, d["id"])
		tuyos[d["tipo"] + "|" + d["nombre"]] = true
		if d["id"] == _id_cargado:
			_lista.select(_lista.item_count - 1)
	# los bots del juego, para partir de ellos (al guardarlos, sustituyen al bot)
	for grupo in TiposPersonaje.GRUPOS:
		var ids := TiposPersonaje.del_grupo(grupo).filter(func(id): return Npc.KINDS.has(id))
		if ids.is_empty():
			continue
		_lista.add_separator("Bots del juego · " + grupo)
		for kind in ids:
			for n in Npc.KINDS[kind]["names"]:
				if tuyos.has(kind + "|" + n):
					continue
				_lista.add_item("%s (%s)" % [n, TiposPersonaje.label(kind)])
				_lista.set_item_metadata(_lista.item_count - 1, "bot:%s:%s" % [kind, n])


## Hace `what` ya o, si hay cambios sin guardar, después de preguntar.
func _si_descarta(what: Callable) -> void:
	if not _sucio:
		what.call()
		return
	_pendiente = what
	_descartar.popup_centered()


func _on_lista(i: int) -> void:
	var id: String = _lista.get_item_metadata(i)
	_lista.select(_lista_indice(_id_cargado))
	_si_descarta(func():
		if id == "":
			_nuevo_ya()
		elif id.begins_with("bot:"):
			var parts := id.split(":", true, 2)
			_editar(_de_bot(parts[1], parts[2]), "")
			_estado.text = "Plantilla del juego. Si lo guardas con el mismo nombre, sustituye a ese bot."
		else:
			_editar(Personajes.cargar(Personajes.DIR + id + ".json"), id)
		_lista.select(_lista_indice(id)))


func _lista_indice(id: String) -> int:
	for i in _lista.item_count:
		if _lista.get_item_metadata(i) == id:
			return i
	return 0


func _nuevo() -> void:
	_si_descarta(_nuevo_ya)


func _nuevo_ya() -> void:
	_editar(Personajes.nuevo(_def["tipo"]), "")
	_azar()
	_sucio = false
	_lista.select(0)
	_actualizar()


func _duplicar() -> void:
	var d := _def.duplicate(true)
	d["nombre"] += " (copia)"
	_editar(d, "")
	_sucio = true
	_lista.select(0)
	_actualizar()


func _guardar() -> bool:
	var errores := _comprobar().filter(func(a): return a[0])
	if not errores.is_empty():
		_estado.text = "No se puede guardar: " + errores[0][1]
		return false
	var id := Personajes.slug(_def["nombre"])
	_def["id"] = id
	_def["version"] = Personajes.VERSION
	var err := Personajes.guardar(_def)
	if err != OK:
		_estado.text = "Error al guardar (%s)." % error_string(err)
		return false
	# si se ha cambiado el nombre, el archivo viejo sobra
	if _id_cargado != "" and _id_cargado != id:
		Personajes.borrar(_id_cargado)
	_id_cargado = id
	_sucio = false
	_leer_guardados()
	_actualizar()
	_estado.text = "Guardado en data/personajes/%s.json" % id
	return true


func _borrar() -> void:
	if _id_cargado == "":
		_nuevo_ya()
		return
	var dlg := ConfirmationDialog.new()
	dlg.dialog_text = "¿Borrar a %s? Se elimina su archivo." % _def["nombre"]
	dlg.ok_button_text = "Borrar"
	dlg.confirmed.connect(func():
		Personajes.borrar(_id_cargado)
		_id_cargado = ""
		_leer_guardados()
		_nuevo_ya()
		dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered()


## Guarda y abre el juego con este personaje al lado del jugador.
func _probar() -> void:
	if not _guardar():
		return
	if not TiposPersonaje.en_juego(_def["tipo"]):
		_estado.text = "Guardado, pero su tipo aún no existe en el juego: no se puede probar todavía."
		return
	# la versión _console abierta con ventana desde otro proceso se queda colgada
	var exe := OS.get_executable_path().replace("_console.exe", ".exe")
	if not FileAccess.file_exists(exe):
		exe = OS.get_executable_path()
	OS.create_process(exe, ["--path", ProjectSettings.globalize_path("res://"), "res://scenes/world.tscn", "--", "--probar=" + _def["id"]])
	_estado.text = "Abriendo el juego con %s al lado..." % _def["nombre"]
