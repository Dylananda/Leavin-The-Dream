class_name Personajes
extends RefCounted
## Personajes únicos hechos con el editor de personajes (editor/editor_personajes.tscn), uno por
## archivo en data/personajes/<id>.json. El juego los carga al empezar y saca a cada uno en su
## zona y a sus horas (ver Censo), con sus misiones (ver Misiones). Lo que todavía no sabe
## usar (relaciones...) se guarda igual, para cuando lo sepa: ver USADO.
##
## Las posiciones (polígono de la zona, casa y lugares) van en casillas de la cuadrícula del
## mapa (CityMap, 2 m), como los pois de data/raval_map.json.

const DIR := "res://data/personajes/"
const VERSION := 1
## Zonas que se pueden elegir en vez de dibujar un polígono. Las que no son "barrio" ni
## "poligono" son las mismas de Npc.KINDS[...]["zone"] (ver World._zone_cell).
const ZONAS := {
	"barrio": "Todo el Raval",
	"rambla": "La Rambla",
	"rambla_raval": "Rambla del Raval, Sant Pau y Robadors",
	"bares": "Junto a los bares",
	"plazas": "Las plazas",
	"robadors": "Robadors, Sant Ramon y Sant Pau",
	"musica": "Puntos de música (Rambla, el Pi, MACBA, Liceu, CCCB)",
	"pintores": "Plaça de Sant Josep Oriol y del Pi",
	"estatuas": "Tramo de abajo de la Rambla",
	"macba": "Plaça dels Àngels (MACBA)",
	"poligono": "Zona dibujada en el mapa",
}
## Tipos de sitio de la rutina: adonde va el personaje a esas horas y se queda por allí.
const LUGARES := {
	"dormir": {"label": "Dormir", "color": Color("6a8ae8")},
	"pedir": {"label": "Pedir", "color": Color("e8c040")},
	"tocar": {"label": "Tocar / actuar", "color": Color("d070e0")},
	"trabajar": {"label": "Trabajar", "color": Color("50c8a0")},
	"trapichear": {"label": "Trapichear", "color": Color("e05050")},
	"comer": {"label": "Comer", "color": Color("e09040")},
	"otro": {"label": "Otro", "color": Color("c0c0c0")},
}
## Radio (casillas) en el que se mueve alguien mientras está en uno de sus lugares.
const LUGAR_WANDER := 2
## Lo que el juego ya usa de cada personaje; el resto se guarda para más adelante.
const USADO := ["nombre", "genero", "tipo", "historia", "aspecto", "zona", "horario", "lugares",
	"dinero", "velocidad", "fuerza", "valor", "agresividad", "llama_policia", "quiere", "lleva", "vende",
	"frases", "ficha", "amo", "misiones", "le_debes"]
## Colores del aspecto, que se guardan en hexadecimal ("" = sin chaqueta).
const COLORES := ["skin", "shirt", "pants", "hair", "jacket"]


## Plantilla de un personaje nuevo del tipo `tipo`.
static func nuevo(tipo := "yonki") -> Dictionary:
	return {
		"version": VERSION,
		"id": "",
		"nombre": "",
		"apodo": "",
		"edad": 40,
		"genero": "m",
		"tipo": tipo,
		"amo": "",  ## (perros) id del personaje con el que va
		"historia": "",
		"fuentes": "",
		"aspecto": {
			"skin": "d9a77c", "shirt": "6a6a70", "pants": "3a3a40", "hair": "3a2418", "jacket": "",
			"hair_style": "corto", "facial": "", "glasses": false, "skirt": false,
			"accesorio": "", "tamano": 1.0,
		},
		"zona": {"tipo": "barrio", "poligono": [], "casa": []},
		"horario": [],
		"lugares": [],
		"stats": {
			"dinero": 10, "velocidad": 10.0, "fuerza": 5, "valor": 5, "agresividad": 3,
			"llama_policia": false, "quiere": [], "lleva": {}, "vende": {},
			"le_debes": 0,  ## lo que le debes al empezar la partida (ver Misiones.debes)
		},
		"ficha": {"quien": "", "habla": "", "sabe": "", "no_sabe": "", "quiere": ""},
		"frases": [],
		"misiones": [],
		"relaciones": [],
		"notas": "",
	}


## Plantilla de una misión nueva (ver Misiones, que las juega).
static func nueva_mision() -> Dictionary:
	return {
		"id": "",
		"titulo": "",
		"dice": "",  ## lo que te dice al dártela
		"condiciones": {
			"desde": 0, "hasta": 0,  ## horas en que la ofrece (iguales: a cualquier hora)
			"dia": 1,  ## a partir de qué día de partida
			"tras": "",  ## "personaje/misión" que tienes que haber cumplido antes ("" nada)
			"dignidad": 0,  ## dignidad mínima: a quien va muy tirado no le confía nada
			"repetible": false,  ## se puede volver a hacer (una vez al día)
		},
		"objetivo": {
			"tipo": "llevar_lugar",
			"objeto": "paquete",  ## lo que se lleva o se trae
			"lo_da": true,  ## te lo da él al aceptarla (si no, lo tienes que conseguir)
			"lugar": "bar",  ## tipo de sitio del mapa (Misiones.LUGARES)
			"personaje": "",  ## id del otro personaje
			"prueba": "",  ## objeto con el que se le convence seguro ("" ninguno: hay que mentir)
			"desde": 10, "hasta": 11,  ## horas de la cita (del día siguiente)
			"minutos": 120,  ## lo que dura hacer de vigía
			"dificultad": 0.5,  ## 0..1, del minijuego o de colar la mentira
		},
		"plazo": 2.0,  ## horas de juego desde que la aceptas (0 = sin plazo; la cita lleva el suyo)
		"exito": {"texto": "", "efectos": []},
		"fallo": {"texto": "", "efectos": []},
	}


## Un efecto nuevo del tipo `tipo`.
static func nuevo_efecto(tipo := "dinero") -> Dictionary:
	return {"tipo": tipo, "valor": 0, "quien": "", "que": ""}


## La misión `m` completada con la plantilla (por si es de una versión anterior del editor).
static func completar_mision(m: Dictionary) -> Dictionary:
	var out := nueva_mision()
	for k in m:
		if out.get(k) is Dictionary and m[k] is Dictionary:
			out[k].merge(m[k], true)
		else:
			out[k] = m[k]
	for lado in ["exito", "fallo"]:
		var efectos: Array = []
		for ef in out[lado].get("efectos", []):
			var full := nuevo_efecto()
			full.merge(ef, true)
			efectos.append(full)
		out[lado]["efectos"] = efectos
	return out


## Todos los personajes guardados, ordenados por nombre.
static func cargar_todos() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir := DirAccess.open(DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".json"):
			var d := cargar(DIR + f)
			if not d.is_empty():
				out.append(d)
	out.sort_custom(func(a, b): return a["nombre"].naturalnocasecmp_to(b["nombre"]) < 0)
	return out


## Un personaje desde su archivo, completado con la plantilla (por si es de una versión
## anterior del editor). Vacío si no se puede leer.
static func cargar(path: String) -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_warning("Personaje ilegible: " + path)
		return {}
	var d := nuevo(data.get("tipo", "yonki"))
	for k in data:
		if d.get(k) is Dictionary and data[k] is Dictionary:
			d[k].merge(data[k], true)
		else:
			d[k] = data[k]
	d["misiones"] = d["misiones"].map(func(m): return completar_mision(m))
	return d


## Guarda el personaje en data/personajes/<id>.json.
static func guardar(d: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var f := FileAccess.open(DIR + d["id"] + ".json", FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(d, "\t", false))
	return OK


static func borrar(id: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + id + ".json"))


## Identificador de archivo a partir del nombre: "La Paqui" -> "la_paqui".
static func slug(nombre: String) -> String:
	var s := nombre.strip_edges().to_lower()
	for pair in [["á", "a"], ["à", "a"], ["é", "e"], ["è", "e"], ["í", "i"], ["ï", "i"], ["ó", "o"],
			["ò", "o"], ["ú", "u"], ["ü", "u"], ["ñ", "n"], ["ç", "c"], ["l·l", "ll"]]:
		s = s.replace(pair[0], pair[1])
	var out := ""
	for c in s:
		out += c if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") else "_"
	while "__" in out:
		out = out.replace("__", "_")
	return out.trim_prefix("_").trim_suffix("_")


## El aspecto con colores de verdad, como lo espera Actor.look.
static func look_de(d: Dictionary) -> Dictionary:
	var a: Dictionary = d["aspecto"]
	var look := {"gender": d["genero"]}
	for k in ["hair_style", "facial", "glasses", "skirt"]:
		look[k] = a[k]
	for k in COLORES:
		if a.get(k, "") != "":
			look[k] = Color(a[k])
	if d["tipo"] == "perro":
		look["species"] = "perro"
		look["fur"] = look["shirt"]  # el color de la camiseta hace de pelaje
	return look


## El aspecto de Actor.look en el formato del archivo (colores en hexadecimal).
static func aspecto_de(look: Dictionary, accesorio: String, tamano: float) -> Dictionary:
	var a := {"accesorio": accesorio, "tamano": tamano, "jacket": ""}
	for k in ["hair_style", "facial", "glasses", "skirt"]:
		a[k] = look.get(k, nuevo()["aspecto"][k])
	for k in COLORES:
		if look.has(k):
			a[k] = (look[k] as Color).to_html(false)
	return a


## Si anda por la calle a la hora `h` (horario vacío: a todas horas).
static func activo(d: Dictionary, h: int) -> bool:
	var hours: Array = d["horario"]
	if hours.size() < 2:
		return true
	return _entre(h, hours[0], hours[1])


## El lugar de su rutina en el que está a la hora `h` ({} si ninguno).
static func lugar_a(d: Dictionary, h: int) -> Dictionary:
	for l in d["lugares"]:
		if _entre(h, l["desde"], l["hasta"]):
			return l
	return {}


## [desde, hasta) en horas del día; puede pasar de medianoche. desde == hasta: todo el día.
static func _entre(h: int, from: int, to: int) -> bool:
	if from == to:
		return true
	return (h >= from and h < to) if from < to else (h >= from or h < to)


## Si la casilla `p` está dentro del polígono `poly` ([[x, y], ...] en casillas).
static func dentro(p: Vector2, poly: Array) -> bool:
	var pts := PackedVector2Array()
	for v in poly:
		pts.append(Vector2(v[0], v[1]))
	return pts.size() >= 3 and Geometry2D.is_point_in_polygon(p, pts)
