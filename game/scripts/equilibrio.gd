class_name Equilibrio
## Retoques del equilibrio hechos con el diseñador de sustancias (editor/editor_sustancias.gd).
## Los valores de partida siguen en Defs, con sus comentarios; lo que se cambia en el diseñador
## se guarda aparte, en data/equilibrio.json, solo con lo que es distinto, y Defs lo pone
## encima al cargar (`aplicar`). Para volver a lo de Defs basta con borrar el retoque.
##
## El archivo tiene una sección por tabla de Defs («sustancias», «objetos», «clientes»,
## «habitos», «precios», «receta») y dentro, por id, solo los campos retocados (también los
## de dentro: {"speed": {"fx": {"shake": 0.3}}}). En las listas, la posición va como texto ("0").

const ARCHIVO := "res://data/equilibrio.json"

## Los retoques que hay en el archivo (sección -> id -> campos).
static var ajustes: Dictionary = leer()
## Los valores de partida de Defs, sin retoques (sección -> tabla), para el diseñador.
static var base: Dictionary = {}


static func leer() -> Dictionary:
	if not FileAccess.file_exists(ARCHIVO):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(ARCHIVO))
	return d if d is Dictionary else {}


## La tabla `valores` de Defs con los retoques de su `seccion` encima. Guarda la de partida en `base`.
static func aplicar(seccion: String, valores: Dictionary) -> Dictionary:
	base[seccion] = valores.duplicate(true)
	var out := valores.duplicate(true)
	mezclar(out, ajustes.get(seccion, {}))
	return out


## Pone `cambios` encima de `destino` (un diccionario o una lista), por dentro. Los números
## quedan del tipo que tenían en Defs (los enteros, enteros), que el JSON los trae todos como decimales.
static func mezclar(destino, cambios: Dictionary) -> void:
	for k in cambios:
		var v = cambios[k]
		var clave = k
		if destino is Array:
			clave = int(k)
			if clave < 0 or clave >= destino.size():
				continue
		elif not destino is Dictionary:
			return
		var actual = destino[clave] if (destino is Array or destino.has(clave)) else null
		if v is Dictionary and (actual is Dictionary or actual is Array):
			mezclar(actual, v)
		elif v is Dictionary:
			if actual == null:
				var nuevo := {}
				mezclar(nuevo, v)
				destino[clave] = nuevo
		else:
			destino[clave] = como(actual, v)


## `v` con el tipo de `antes` (entero si era entero, verdadero o falso si lo era).
static func como(antes, v):
	if antes is int and (v is float or v is int):
		return int(round(v))
	if antes is bool:
		return bool(v)
	if antes is float and v is int:
		return float(v)
	return v


## Guarda los retoques (y los deja puestos para la próxima vez que arranque el juego).
static func guardar(nuevos: Dictionary) -> Error:
	var f := FileAccess.open(ARCHIVO, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(nuevos, "\t", true))
	f.close()
	ajustes = nuevos.duplicate(true)
	return OK
