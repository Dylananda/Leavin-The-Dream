class_name EsquemaMisiones
extends Control
## Esquema de las cadenas de misiones (fase 3 del diseñador de personajes): una caja por
## misión de todos los personajes, en columnas según lo que hay que hacer antes («después de»),
## con flechas para las cadenas, líneas rojas entre las que se excluyen («si no has hecho») y
## líneas amarillas entre las que comparten personajes (el que la da, el del objetivo, quien
## tiene lo que te piden, a quien te chivas, quien acecha, a quien le tocan los resultados).
## Debajo de cada caja, lo que pasa: deudas, favores, amigos, enemigos, detenidos.
## Un clic en una caja abre ese personaje en el editor.

signal elegido(pid: String)

const CAJA := Vector2(330, 86)
const HUECO := Vector2(70, 26)
const MARGEN := Vector2(20, 20)
const C_CAJA := Color(1, 1, 1, 0.07)
const C_BORDE := Color("e07a30")
const C_TRAS := Color("6a9ae8")
const C_EXCEPTO := Color("ff6050")
const C_CRUCE := Color(1.0, 0.82, 0.3, 0.35)
const C_TEXTO := Color(1, 1, 1, 0.9)
const C_SUAVE := Color(1, 1, 1, 0.55)
## Cómo se resume cada resultado en la caja.
const EFECTO_CORTO := {
	"deuda": "le debes %s", "deuda_ya": "viene a cobrarte %s", "saldar": "saldas lo de %s",
	"favor": "favor de %s", "amigo": "amigo: %s", "enemigo": "enemigo: %s",
	"detenido": "detienen a %s", "venganza": "%s va a por ti",
}

var _cajas: Array[Dictionary] = []  ## {key, pid, nombre, titulo, resumen, efectos, rect, tras, excepto, gente}


## Monta el esquema con las misiones de `personajes` (las fichas, como las guarda el editor).
func mostrar(personajes: Array) -> void:
	_cajas.clear()
	var nombres := {}
	for d in personajes:
		nombres[d["id"]] = d["nombre"]
	var por_clave := {}
	for d in personajes:
		for m in d.get("misiones", []):
			if m.get("id", "") == "":
				continue
			var c := {
				"key": Misiones.clave(d["id"], m), "pid": d["id"], "nombre": d["nombre"],
				"titulo": m["titulo"], "resumen": Misiones.resumen(m, nombres),
				"tras": m["condiciones"].get("tras", ""), "excepto": m["condiciones"].get("excepto", ""),
				"gente": _gente(d["id"], m), "efectos": _efectos(m, d["id"], nombres),
			}
			_cajas.append(c)
			por_clave[c["key"]] = c
	# columnas: cuántas misiones hay antes en la cadena de «después de»
	var columnas := {}
	for c in _cajas:
		var n := _profundidad(c, por_clave, 0)
		if not columnas.has(n):
			columnas[n] = []
		columnas[n].append(c)
	var alto := 0.0
	var ancho := 0.0
	for n in columnas:
		var col: Array = columnas[n]
		# las que comparten gente, juntas: por el primero que sale en ellas
		col.sort_custom(func(a, b): return a["nombre"].naturalnocasecmp_to(b["nombre"]) < 0)
		for i in col.size():
			var pos := MARGEN + Vector2(n * (CAJA.x + HUECO.x), i * (CAJA.y + HUECO.y))
			col[i]["rect"] = Rect2(pos, CAJA)
			alto = maxf(alto, pos.y + CAJA.y)
			ancho = maxf(ancho, pos.x + CAJA.x)
	custom_minimum_size = Vector2(ancho, alto) + MARGEN
	queue_redraw()


func _profundidad(c: Dictionary, por_clave: Dictionary, n: int) -> int:
	if n > 20 or not por_clave.has(c["tras"]):
		return n
	return _profundidad(por_clave[c["tras"]], por_clave, n + 1)


## Los personajes que tienen que ver con la misión `m` de `pid`.
static func _gente(pid: String, m: Dictionary) -> Array:
	var out := [pid]
	var o: Dictionary = m["objetivo"]
	for k in ["personaje", "lo_tiene", "chivato", "acecha"]:
		if o.get(k, "") != "" and not o[k] in out:
			out.append(o[k])
	for lado in ["exito", "fallo"]:
		for ef in m[lado]["efectos"]:
			if ef.get("quien", "") != "" and not ef["quien"] in out:
				out.append(ef["quien"])
	return out


## Lo que pasa con otros personajes al cumplirla (✔) o fallarla (✖), en pocas palabras.
static func _efectos(m: Dictionary, pid: String, nombres: Dictionary) -> String:
	var out := []
	for lado in [["exito", "✔"], ["fallo", "✖"]]:
		var partes := []
		for ef in m[lado[0]]["efectos"]:
			if not EFECTO_CORTO.has(ef["tipo"]):
				continue
			var quien: String = ef.get("quien", "")
			var nombre: String = nombres.get(quien if quien != "" else pid, quien)
			var t: String = EFECTO_CORTO[ef["tipo"]] % nombre
			if ef["tipo"] == "favor":
				t += " (%s)" % ef.get("que", "")
			partes.append(t)
		if not partes.is_empty():
			out.append(lado[1] + " " + ", ".join(partes))
	return "   ".join(out)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var por_clave := {}
	for c in _cajas:
		por_clave[c["key"]] = c
	if _cajas.is_empty():
		draw_string(font, MARGEN + Vector2(0, 20), "Ningún personaje guardado tiene misiones todavía.", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, C_SUAVE)
		return
	# cruces: misiones que comparten personajes (sin contar las que ya van encadenadas)
	for i in _cajas.size():
		for j in range(i + 1, _cajas.size()):
			var a: Dictionary = _cajas[i]
			var b: Dictionary = _cajas[j]
			if a["tras"] == b["key"] or b["tras"] == a["key"]:
				continue
			var comunes: Array = a["gente"].filter(func(p): return p in b["gente"])
			if not comunes.is_empty():
				draw_line(a["rect"].get_center(), b["rect"].get_center(), C_CRUCE, 1.5, true)
	# excluyentes
	for c in _cajas:
		if por_clave.has(c["excepto"]):
			var o: Dictionary = por_clave[c["excepto"]]
			draw_dashed_line(c["rect"].get_center(), o["rect"].get_center(), C_EXCEPTO, 2.5, 8.0)
	# cajas
	for c in _cajas:
		var r: Rect2 = c["rect"]
		draw_rect(r, Color(0.07, 0.06, 0.08))
		draw_rect(r, C_CAJA)
		draw_rect(r, C_BORDE, false, 1.5)
		draw_string(font, r.position + Vector2(8, 18), "%s · %s" % [c["nombre"], c["titulo"]], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 16, 15, C_BORDE)
		draw_string(font, r.position + Vector2(8, 38), c["resumen"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 16, 13, C_TEXTO)
		draw_multiline_string(font, r.position + Vector2(8, 56), c["efectos"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 16, 12, 2, C_SUAVE)
	# cadenas: «después de», con flecha
	for c in _cajas:
		if por_clave.has(c["tras"]):
			var from: Rect2 = por_clave[c["tras"]]["rect"]
			var to: Rect2 = c["rect"]
			var a := Vector2(from.end.x, from.get_center().y)
			var b := Vector2(to.position.x, to.get_center().y)
			draw_line(a, b, C_TRAS, 2.5, true)
			var d := (b - a).normalized()
			draw_colored_polygon(PackedVector2Array([b, b - d * 12 + d.orthogonal() * 6, b - d * 12 - d.orthogonal() * 6]), C_TRAS)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for c in _cajas:
			if c["rect"].has_point(event.position):
				elegido.emit(c["pid"])
				return


## Las cajas (para las pruebas).
func cajas() -> Array[Dictionary]:
	return _cajas
