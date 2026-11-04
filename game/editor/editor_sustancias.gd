extends Control
## Diseñador de sustancias: una herramienta aparte del juego para ver de un vistazo, en tablas,
## los precios y efectos de todas las sustancias, objetos y acciones, y retocarlos. Lo que se
## cambia se guarda en data/equilibrio.json (ver Equilibrio), solo lo que difiere de Defs, y el
## juego lo pone encima al arrancar. Se abre con editor_sustancias.cmd (en la raíz del
## repositorio) o con godot --path game res://editor/editor_sustancias.tscn
##
## Cada casilla es un valor. Con el borde amarillo, está retocada; vaciarla la devuelve a lo de
## Defs. El fondo compara la columna: más intenso cuanto más grande (azul) o más negativo (rojo).

const TAMANO_BASE := Vector2i(1600, 900)
const C_TITULO := Color("e07a30")
const C_CAMBIADO := Color("f0c060")
const C_SUAVE := Color(1, 1, 1, 0.55)
const C_MAS := Color("3a7ad0")
const C_MENOS := Color("d04a3a")
const C_CELDA := Color(1, 1, 1, 0.04)
const ANCHO_NUMERO := 78
const ANCHO_TEXTO := 380

## Los efectos de pantalla y manejo (`fx`), en el orden en que salen en las tablas.
const FX := ["speed", "sway", "shake", "zoom", "drift", "lag", "double", "saturate", "slowmo", "glow",
	"drowsy", "tunnel", "clumsy", "paranoia", "sharp", "love", "psico", "disocia", "resaca"]

## Rótulo y explicación de cada columna, por su ruta completa o por su último nombre.
const COLUMNAS := {
	"price": ["Precio €", "Lo que cobra el camello por una dosis. Al revender, cada cliente paga esto por su recargo (pestaña Clientes)."],
	"high": ["Colocón", "Colocón que da cada dosis. Por encima de 100 en total hay riesgo de sobredosis."],
	"addiction": ["Enganche", "Enganche que suma cada dosis (de 0 a 100). Con más de 5, sin colocón sube el mono."],
	"health": ["Salud", "Lo que cambia la salud."],
	"dignity": ["Dignidad", "Lo que cambia la dignidad al tomarla."],
	"sanity": ["Mente", "Lo que cambia la salud mental al tomarla."],
	"od": ["Sobredosis", "Riesgo de sobredosis pasando de 100 de colocón, y al mezclar depresores."],
	"decay": ["Se pasa", "Colocón que se pierde por minuto de juego: cuanto más, menos dura."],
	"hunger_rate": ["× hambre", "Multiplica el hambre mientras dura (1 = como siempre)."],
	"fatigue_rate": ["× sueño", "Multiplica el sueño mientras dura (1 = como siempre)."],
	"visible": ["Se nota", "Cuánto se te nota por punto de colocón (resta discreción)."],
	"sanity_rate": ["Mente/min", "Salud mental que sube por minuto con el colocón a tope (antidepresivos)."],
	"mono": ["Calma mono", "Mono que quita de la sustancia que calma (negativo: lo quita)."],
	"relief_addiction": ["Calma enganche", "Enganche que quita de la sustancia que calma."],
	"fx_text": ["Lo que dice el HUD", "La explicación de los efectos en la lista de sustancias."],
	"speed": ["Velocidad", "Andas más rápido (+) o más lento (−), con el colocón a tope."],
	"sway": ["Oscila", "La cámara oscila."],
	"shake": ["Tiembla", "La vista tiembla (negativo: calma el temblor, como el tabaco)."],
	"zoom": ["Zoom", "Lo ves más cerca (+) o más lejos (−)."],
	"drift": ["Eses", "Andas haciendo eses."],
	"lag": ["Retraso", "Reaccionas tarde a los controles."],
	"double": ["Doble", "Visión doble."],
	"saturate": ["Chillón", "Colores chillones."],
	"slowmo": ["Tiempo lento", "El tiempo se estira: todo el barrio y el reloj van más lentos."],
	"glow": ["Brillo", "Todo brilla."],
	"drowsy": ["Párpados", "Se te cierran los ojos."],
	"tunnel": ["Túnel", "Bordes oscuros."],
	"clumsy": ["Tropiezos", "Tropiezas al andar."],
	"paranoia": ["Paranoia", "Aberración cromática y miedo (negativo: la quita, como los ansiolíticos)."],
	"sharp": ["Bordes duros", "Bordes marcados y contraste (speed)."],
	"love": ["Calidez", "Todo cálido, con un halo que late (MDMA)."],
	"psico": ["Ondas", "La imagen ondula y los colores respiran (setas, LSD)."],
	"disocia": ["Disocia", "Todo se aleja y se desdobla (ketamina)."],
	"resaca": ["Luz molesta", "La luz molesta y la cabeza late (resacas)."],
	"crash.minutes": ["Minutos", "Lo que dura el bajón al acabarse el colocón."],
	"crash.sanity": ["Mente", "Lo que baja la salud mental el bajón."],
	"crash.mono": ["Mono", "Mono que te deja el bajón."],
	"crash.fatigue": ["Sueño", "Sueño que te deja el bajón."],
	"resaca.dosis": ["Por dosis", "Resaca pendiente que suma cada dosis; al dormir se convierte en resaca."],
	"resaca.horas": ["Horas", "Lo que dura la resaca (por su nivel)."],
	"resaca.mente": ["Mente/hora", "Lo que baja la salud mental por hora de resaca a tope."],
	"resaca.se_quita": ["La del perro", "Volver a meterte lo mismo te la quita a medias."],
	"resaca.text": ["Lo que dice el HUD", "La explicación de la resaca en la lista de efectos."],
	"malviaje.cordura": ["Mente <", "Con la salud mental por debajo de esto, el viaje se puede torcer."],
	"malviaje.chance": ["Probabilidad", "Probabilidad de mal viaje con la mente por debajo (si no, la de Defs.MALVIAJE_SIEMPRE)."],
	"malviaje.sanity": ["Mente", "Lo que baja la salud mental un mal viaje."],
	"malviaje.minutes": ["Minutos", "Lo que dura el mal viaje."],
	"sell": ["Compraventa €", "Lo que paga el compraventa (los yonkis lo valoran por Defs.YONKI_ITEM_VALUE)."],
	"food": ["Quita hambre", "Hambre que quita al comértelo (y un poco de salud)."],
	"markup": ["Recargo ×", "Cuánto paga sobre el precio del camello."],
	"precio": ["Precio €", "Lo que cuesta o lo que te pagan."],
	"cantidad": ["Cantidad", "Las unidades que te llevas."],
	"enganche.0": ["Enganche mín", "Enganche más bajo con el que sale uno de este tipo."],
	"enganche.1": ["Enganche máx", "Enganche más alto con el que sale uno de este tipo."],
}

## Las pestañas. `seccion` = la de Equilibrio; `cols` = las rutas de cada columna («crash.minutes»);
## o `prefijo` y `todos` = las claves dentro de ese bloque (salen también las que nadie tiene aún,
## para poder añadirlas); `extra` = más columnas al final; `solo_con` = solo las filas que tienen ese bloque.
const PESTANAS := [
	{"nombre": "Sustancias", "seccion": "sustancias",
		"cols": ["price", "high", "addiction", "health", "dignity", "sanity", "od", "decay", "hunger_rate",
			"fatigue_rate", "visible", "sanity_rate", "mono", "relief_addiction"],
		"texto": "Lo básico de cada sustancia: precio, lo que da cada dosis y cómo dura. Pasa el ratón por el nombre de una columna para ver qué es."},
	{"nombre": "Efectos", "seccion": "sustancias", "prefijo": "fx", "todos": FX, "extra": ["fx_text"],
		"texto": "Efectos en la pantalla y el manejo con el colocón a tope (de 0 a 1; algunos admiten negativos). Una casilla vacía es que no lo tiene: escribe un número para dárselo."},
	{"nombre": "Bajón", "seccion": "sustancias", "solo_con": "crash",
		"cols": ["crash.minutes", "crash.sanity", "crash.mono", "crash.fatigue"],
		"texto": "El bajón al acabarse el colocón (las que lo tienen)."},
	{"nombre": "Resaca", "seccion": "sustancias", "solo_con": "resaca",
		"cols": ["resaca.dosis", "resaca.horas", "resaca.mente", "resaca.se_quita", "resaca.text"],
		"texto": "La resaca del día siguiente (las que la dan en la vida real). Se convierte en resaca al dormir."},
	{"nombre": "Efectos de la resaca", "seccion": "sustancias", "solo_con": "resaca", "prefijo": "resaca.fx", "todos": FX,
		"texto": "Los efectos de pantalla y manejo de cada resaca, a tope."},
	{"nombre": "Mal viaje", "seccion": "sustancias", "solo_con": "malviaje",
		"cols": ["malviaje.cordura", "malviaje.chance", "malviaje.sanity", "malviaje.minutes"],
		"texto": "Los psicodélicos: cuándo se tuerce el viaje y lo que pasa."},
	{"nombre": "Objetos", "seccion": "objetos", "cols": ["sell", "food"],
		"texto": "Lo que paga el compraventa por cada objeto y lo que quita el hambre la comida."},
	{"nombre": "Clientes", "seccion": "clientes", "cols": ["markup"],
		"texto": "Al revender lo que compras al camello: cuánto paga cada tipo de cliente sobre su precio."},
	{"nombre": "Lo que consumen los bots", "seccion": "habitos", "prefijo": "usa", "todos": [], "extra": ["enganche.0", "enganche.1"],
		"texto": "Por tipo de personaje: la probabilidad de que cada uno tenga esa sustancia de cabecera (lo que falta hasta 1, nada) y su enganche."},
	{"nombre": "Precios", "seccion": "precios", "cols": ["precio", "cantidad"],
		"texto": "Lo que cuestan (o te pagan) las acciones de los sitios y de la gente."},
	{"nombre": "Receta", "seccion": "receta", "cols": ["cantidad", "precio"],
		"texto": "Con la receta del médico del CAP, la caja de la farmacia: cuántas dosis trae y lo que cuesta."},
]

var _ajustes: Dictionary = {}  ## los retoques que se están editando (sección -> id -> campos)
var _sucio := false
var _tabs: TabContainer
var _estado: Label
var _celdas: Array = []  ## por pestaña: {ruta de columna: [[control, sección, id, ruta], ...]}
var _salir: ConfirmationDialog


func _ready() -> void:
	get_tree().root.content_scale_size = TAMANO_BASE
	get_window().title = "Yonkiland · Diseñador de sustancias"
	get_tree().auto_accept_quit = false
	var _carga := Defs.SUBSTANCES  # que Defs cargue sus tablas (y Equilibrio.base)
	_ajustes = Equilibrio.ajustes.duplicate(true)
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
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_tabs)
	var pie := Label.new()
	pie.text = "Borde amarillo: retocado (se guarda en data/equilibrio.json y manda sobre defs.gd). Vacía una casilla para volver a lo de defs.gd. El fondo compara la columna: azul, más; rojo, negativo."
	pie.add_theme_color_override("font_color", C_SUAVE)
	pie.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(pie)
	_salir = ConfirmationDialog.new()
	_salir.dialog_text = "Hay retoques sin guardar."
	_salir.ok_button_text = "Salir sin guardar"
	_salir.add_button("Guardar y salir", true, "guardar")
	_salir.confirmed.connect(func(): get_tree().quit())
	_salir.custom_action.connect(func(_a):
		if _guardar():
			get_tree().quit())
	add_child(_salir)
	_construir()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _sucio:
			_salir.popup_centered()
		else:
			get_tree().quit()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.ctrl_pressed and event.keycode == KEY_S:
		_guardar()
		get_viewport().set_input_as_handled()


func _barra() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	var title := Label.new()
	title.text = "DISEÑADOR DE SUSTANCIAS"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", C_TITULO)
	bar.add_child(title)
	_estado = Label.new()
	_estado.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_estado.add_theme_color_override("font_color", C_SUAVE)
	bar.add_child(_estado)
	for b in [["Guardar", _guardar], ["Descartar cambios", _descartar],
			["Quitar los retoques de esta pestaña", _quitar_pestana], ["Probar en el juego", _probar]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.pressed.connect(b[1])
		bar.add_child(btn)
	return bar


# ------------------------------------------------------------------ tablas

## (Re)hace todas las pestañas con los valores de ahora, sin cambiar la que se ve.
func _construir() -> void:
	var actual := _tabs.current_tab
	for c in _tabs.get_children():
		_tabs.remove_child(c)
		c.queue_free()
	_celdas.clear()
	for i in PESTANAS.size():
		_tabs.add_child(_pestana(i))
	if actual >= 0 and actual < _tabs.get_tab_count():
		_tabs.current_tab = actual
	_actualizar_estado()


func _pestana(i: int) -> Control:
	var p: Dictionary = PESTANAS[i]
	var sec: String = p["seccion"]
	var box := VBoxContainer.new()
	box.name = p["nombre"]
	box.add_theme_constant_override("separation", 8)
	var info := Label.new()
	info.text = p["texto"]
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_color_override("font_color", C_SUAVE)
	box.add_child(info)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var filas := _filas(p)
	var cols := _columnas(p, filas)
	var grid := GridContainer.new()
	grid.columns = cols.size() + 1
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(grid)
	grid.add_child(Control.new())
	for col in cols:
		var info_col := _info_columna(col)
		var h := Label.new()
		h.text = info_col[0]
		h.tooltip_text = "%s\n(%s)" % [info_col[1], col]
		h.mouse_filter = Control.MOUSE_FILTER_STOP
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_theme_color_override("font_color", C_TITULO)
		h.add_theme_font_size_override("font_size", 14)
		grid.add_child(h)
	var registro := {}
	for col in cols:
		registro[col] = []
	for id in filas:
		var nombre := Label.new()
		nombre.text = _nombre_fila(sec, id)
		nombre.tooltip_text = id
		nombre.mouse_filter = Control.MOUSE_FILTER_STOP
		grid.add_child(nombre)
		for col in cols:
			var c := _celda(sec, id, col, _tipo_columna(sec, filas, col))
			grid.add_child(c)
			registro[col].append([c, sec, id, col])
	_celdas.append(registro)
	for col in cols:
		_pintar_columna(registro[col])
	return box


## Las filas de una pestaña: las de su tabla en Defs (las que tienen su bloque, si `solo_con`).
func _filas(p: Dictionary) -> Array:
	var out := []
	for id in Equilibrio.base.get(p["seccion"], {}):
		if p.has("solo_con") and not Equilibrio.base[p["seccion"]][id].has(p["solo_con"]):
			continue
		out.append(id)
	return out


func _columnas(p: Dictionary, filas: Array) -> Array:
	if p.has("cols"):
		return p["cols"]
	var pre: String = p["prefijo"]
	var claves: Array = []
	var todos: Array = p["todos"]
	if p["seccion"] == "habitos":
		todos = Equilibrio.base["sustancias"].keys()
	var usadas := {}
	for id in filas:
		var bloque = _andar(Equilibrio.base[p["seccion"]][id], pre.split("."))
		if bloque is Dictionary:
			for k in bloque:
				usadas[k] = true
		var retocado = _andar(_ajustes.get(p["seccion"], {}).get(id, {}), pre.split("."))
		if retocado is Dictionary:
			for k in retocado:
				usadas[k] = true
	for k in todos:
		claves.append(k)
	for k in usadas:
		if not k in claves:
			claves.append(k)
	var out := []
	for k in claves:
		out.append(pre + "." + k)
	return out + p.get("extra", [])


func _info_columna(col: String) -> Array:
	if COLUMNAS.has(col):
		return COLUMNAS[col]
	var ultima: String = col.get_slice(".", col.get_slice_count(".") - 1)
	if col.begins_with("usa."):
		return [Defs.item_name(ultima), "Probabilidad de que su sustancia de cabecera sea %s." % Defs.item_name(ultima).to_lower()]
	return COLUMNAS.get(ultima, [ultima, ""])


func _nombre_fila(sec: String, id: String) -> String:
	var d: Dictionary = Equilibrio.base[sec][id]
	if d.has("que"):
		return d["que"]
	if sec in ["sustancias", "objetos", "receta"]:
		return Defs.item_name(id)
	return id.capitalize()


## "numero", "texto" o "si_no", según lo que hay en esa columna en Defs.
func _tipo_columna(sec: String, filas: Array, col: String) -> String:
	for id in filas:
		var v = _andar(Equilibrio.base[sec][id], col.split("."))
		if v is bool:
			return "si_no"
		if v is String:
			return "texto"
	return "numero"


func _celda(sec: String, id: String, col: String, tipo: String) -> Control:
	var v = _valor(sec, id, col)
	if tipo == "si_no":
		var cb := CheckBox.new()
		cb.button_pressed = v == true
		cb.custom_minimum_size.x = ANCHO_NUMERO
		cb.toggled.connect(func(on: bool):
			_retocar(sec, id, col, on)
			_pintar_columna(_registro_de(cb)))
		return cb
	var le := LineEdit.new()
	le.custom_minimum_size.x = ANCHO_TEXTO if tipo == "texto" else ANCHO_NUMERO
	le.alignment = HORIZONTAL_ALIGNMENT_LEFT if tipo == "texto" else HORIZONTAL_ALIGNMENT_RIGHT
	le.text = _texto(v)
	le.placeholder_text = "·"
	le.select_all_on_focus = true
	var base = _andar(Equilibrio.base[sec][id], col.split("."))
	le.tooltip_text = "En defs.gd: %s" % ("(no lo tiene)" if base == null else _texto(base))
	le.set_meta("tipo", tipo)
	var aplicar := func():
		var t := le.text.strip_edges()
		if t == "":
			_retocar(sec, id, col, null)
		elif tipo == "texto":
			_retocar(sec, id, col, t)
		else:
			t = t.replace(",", ".")
			if not t.is_valid_float():
				_estado.text = "«%s» no es un número." % le.text
				le.text = _texto(_valor(sec, id, col))
				return
			_retocar(sec, id, col, t.to_float())
		le.text = _texto(_valor(sec, id, col))
		_pintar_columna(_registro_de(le))
	le.text_submitted.connect(func(_t): aplicar.call())
	le.focus_exited.connect(aplicar)
	return le


func _registro_de(c: Control) -> Array:
	for reg in _celdas:
		for col in reg:
			for celda in reg[col]:
				if celda[0] == c:
					return reg[col]
	return []


## Colorea una columna: el fondo, por lo grande que es cada valor respecto al mayor de la
## columna; el borde y la letra, en amarillo si está retocado.
func _pintar_columna(celdas: Array) -> void:
	var mayor := 0.0
	for c in celdas:
		var v = _valor(c[1], c[2], c[3])
		if v is int or v is float:
			mayor = maxf(mayor, absf(v))
	for c in celdas:
		var control: Control = c[0]
		var v = _valor(c[1], c[2], c[3])
		var retocado := _andar(_ajustes.get(c[1], {}).get(c[2], {}), c[3].split(".")) != null
		var sb := StyleBoxFlat.new()
		sb.bg_color = C_CELDA
		if (v is int or v is float) and mayor > 0.0 and v != 0:
			var col := C_MAS if v > 0 else C_MENOS
			sb.bg_color = Color(col, 0.12 + 0.6 * absf(v) / mayor)
		sb.set_content_margin_all(4)
		sb.set_corner_radius_all(3)
		if retocado:
			sb.border_color = C_CAMBIADO
			sb.set_border_width_all(2)
		for estilo in ["normal", "focus", "read_only"]:
			control.add_theme_stylebox_override(estilo, sb)
		if control is LineEdit:
			control.add_theme_color_override("font_color", C_CAMBIADO if retocado else Color.WHITE)


# ------------------------------------------------------------------ valores

func _texto(v) -> String:
	if v == null:
		return ""
	if v is float:
		return String.num(v, 4)
	return str(v)


## Lo que vale ahora (con los retoques) un campo; null si no lo tiene.
func _valor(sec: String, id: String, col: String):
	var r = _andar(_ajustes.get(sec, {}).get(id, {}), col.split("."))
	if r != null:
		return Equilibrio.como(_andar(Equilibrio.base[sec][id], col.split(".")), r)
	return _andar(Equilibrio.base[sec][id], col.split("."))


## Baja por un diccionario (o lista) siguiendo la ruta; null si no está.
static func _andar(d, ruta):
	var x = d
	for k in ruta:
		if x is Dictionary:
			if not x.has(k):
				return null
			x = x[k]
		elif x is Array:
			var i := int(k)
			if i < 0 or i >= x.size():
				return null
			x = x[i]
		else:
			return null
	return x


## Pone (o quita, con null o con lo mismo que en Defs) el retoque de un campo.
func _retocar(sec: String, id: String, col: String, v) -> void:
	var ruta: Array = Array(col.split("."))
	var base = _andar(Equilibrio.base[sec][id], ruta)
	if v != null and base != null:
		v = Equilibrio.como(base, v)
	var antes = _andar(_ajustes.get(sec, {}).get(id, {}), ruta)
	if v == null or (base != null and typeof(v) == typeof(base) and v == base):
		if antes == null:
			return
		_quitar(_ajustes, [sec, id] + ruta)
	else:
		if antes != null and typeof(antes) == typeof(v) and antes == v:
			return
		var x: Dictionary = _ajustes
		for k in [sec, id] + ruta.slice(0, ruta.size() - 1):
			if not x.has(k) or not x[k] is Dictionary:
				x[k] = {}
			x = x[k]
		x[ruta[-1]] = v
	_sucio = true
	_actualizar_estado()


## Quita la clave del final de la ruta y los diccionarios que se quedan vacíos.
static func _quitar(d: Dictionary, ruta: Array) -> void:
	if not d.has(ruta[0]):
		return
	if ruta.size() == 1:
		d.erase(ruta[0])
		return
	if d[ruta[0]] is Dictionary:
		_quitar(d[ruta[0]], ruta.slice(1))
		if d[ruta[0]].is_empty():
			d.erase(ruta[0])


func _contar(d) -> int:
	if not d is Dictionary:
		return 1
	var n := 0
	for k in d:
		n += _contar(d[k])
	return n


func _actualizar_estado() -> void:
	var n := _contar(_ajustes) if not _ajustes.is_empty() else 0
	_estado.text = ("%d %s%s" % [n, "retoque" if n == 1 else "retoques", " · sin guardar" if _sucio else ""]) if n > 0 else ("Todo como en defs.gd" + (" · sin guardar" if _sucio else ""))


# ------------------------------------------------------------------ botones

func _guardar() -> bool:
	# lo que se esté escribiendo en una casilla también cuenta
	var foco := get_viewport().gui_get_focus_owner()
	if foco:
		foco.release_focus()
	var err := Equilibrio.guardar(_ajustes)
	if err != OK:
		_estado.text = "No se ha podido guardar data/equilibrio.json (%s)." % error_string(err)
		return false
	_sucio = false
	_actualizar_estado()
	_estado.text += " · guardado: lo verás la próxima vez que abras el juego"
	return true


func _descartar() -> void:
	_ajustes = Equilibrio.leer()
	_sucio = false
	_construir()


func _quitar_pestana() -> void:
	var i := _tabs.current_tab
	if i < 0:
		return
	var hubo := false
	for col in _celdas[i]:
		for c in _celdas[i][col]:
			if _andar(_ajustes.get(c[1], {}).get(c[2], {}), c[3].split(".")) != null:
				_quitar(_ajustes, [c[1], c[2]] + Array(c[3].split(".")))
				hubo = true
	if hubo:
		_sucio = true
	_construir()


func _probar() -> void:
	if not _guardar():
		return
	# la versión _console abierta con ventana desde otro proceso se queda colgada
	var exe := OS.get_executable_path().replace("_console.exe", ".exe")
	if not FileAccess.file_exists(exe):
		exe = OS.get_executable_path()
	OS.create_process(exe, ["--path", ProjectSettings.globalize_path("res://")])
	_estado.text = "Abriendo el juego con los retoques..."
