class_name TiposPersonaje
extends RefCounted
## Tipos base que se pueden elegir en el editor de personajes. Un personaje hereda de su tipo
## la forma de moverse, las reacciones y el menú de acciones del juego (Npc.KINDS e
## interactions.gd). Hay tipos que el juego todavía no tiene: se pueden diseñar ya, pero no
## saldrán a la calle hasta que existan en Npc.KINDS (ver en_juego()).
##
## grupo = apartado de la lista; desc = qué es y qué hace (para quien diseña);
## look = colores fijos de uniforme o de oficio; accesorio = el de partida.

const GRUPOS := ["Policía", "Buscarse la vida", "Calle y artistas", "Vecinos", "De paso"]

const TIPOS := {
	# --- Policía
	"urbano": {
		"label": "Guàrdia Urbana", "grupo": "Policía", "accesorio": "gorra_poli",
		"look": {"shirt": "2a3d7a", "pants": "1d2a5a"},
		"desc": "Policía municipal: convivencia y ordenanzas. Despierta y echa a quien duerme en la calle, multa por beber fuera, requisa latas y mantas, persigue trileros y vigila la Rambla.",
	},
	"urbano_secreta": {
		"label": "Urbana de paisano", "grupo": "Policía", "accesorio": "mochila",
		"desc": "Agente de la Guàrdia Urbana vestido de turista o de vecino. Patrulla la Rambla y el metro a por los carteristas.",
	},
	"mosso": {
		"label": "Mosso d'Esquadra", "grupo": "Policía", "accesorio": "gorra_poli",
		"look": {"shirt": "1c2340", "pants": "141a30"},
		"desc": "Policía de la Generalitat: delitos penales. Robos con violencia, peleas, tráfico de drogas, narcopisos y detenciones.",
	},
	"mosso_secreta": {
		"label": "Mosso de paisano", "grupo": "Policía", "accesorio": "capucha",
		"desc": "Mosso de paisano que sigue a los camellos y espera a ver el pase para detenerlos.",
	},
	"policia": {
		"label": "Agente (sin dividir)", "grupo": "Policía", "accesorio": "gorra_poli",
		"look": {"shirt": "2a3d7a", "pants": "1d2a5a"},
		"desc": "El policía genérico de ahora. Se dividirá en Guàrdia Urbana y Mossos: mejor elegir uno de ellos.",
	},
	# --- Buscarse la vida
	"yonki": {"label": "Yonki", "grupo": "Buscarse la vida", "desc": "Consume en la calle, pide, trapichea y conoce todos los rincones."},
	"camello": {"label": "Camello", "grupo": "Buscarse la vida", "accesorio": "capucha", "desc": "Vende en una esquina fija. Fía y luego viene a cobrar."},
	"mendigo": {"label": "Mendigo", "label_f": "Mendiga", "grupo": "Buscarse la vida", "desc": "Pide en un sitio fijo (puertas de súper, iglesias, cajeros) y duerme en portales o cajeros."},
	"mantero": {"label": "Mantero", "grupo": "Buscarse la vida", "desc": "Vende en una manta que recoge de golpe cuando llega la Urbana."},
	"latero": {"label": "Latero", "grupo": "Buscarse la vida", "accesorio": "bolsa", "desc": "Vende latas de cerveza por la noche en la puerta de los bares."},
	"rosero": {"label": "Vendedor de rosas", "label_f": "Vendedora de rosas", "grupo": "Buscarse la vida", "desc": "Recorre las terrazas y los bares de noche con un ramo de rosas."},
	"chatarrero": {"label": "Chatarrero", "label_f": "Chatarrera", "grupo": "Buscarse la vida", "desc": "Recoge chatarra y cobre con un carro de supermercado y lo vende al peso."},
	"trilero": {"label": "Trilero", "label_f": "Trilera", "grupo": "Buscarse la vida", "accesorio": "caja", "desc": "Mesa de cubiletes en la Rambla, con ganchos que fingen ganar."},
	"carterista": {"label": "Carterista", "grupo": "Buscarse la vida", "accesorio": "mochila", "desc": "Disfrazado de turista, roba en la Rambla y en el metro."},
	"trabajadora_sexual": {"label": "Trabajador sexual", "label_f": "Trabajadora sexual", "grupo": "Buscarse la vida", "desc": "Trabaja en la calle de Robadors y alrededores. Conoce a todo el mundo y sabe quién es peligroso."},
	"chaval": {"label": "Chaval", "grupo": "Buscarse la vida", "accesorio": "gorra", "tamano": 0.8, "desc": "Menor migrante sin hogar. Duerme en portales y esnifa cola."},
	"captador": {"label": "Captador", "label_f": "Captadora", "grupo": "Buscarse la vida", "desc": "Relaciones públicas de discoteca o de club cannábico que caza turistas en la Rambla."},
	# --- Calle y artistas
	"musico": {"label": "Músico callejero", "label_f": "Música callejera", "grupo": "Calle y artistas", "desc": "Toca en sitios fijos (plazas, pasajes con eco, el metro) y se los turna con otros."},
	"estatua": {"label": "Estatua humana", "grupo": "Calle y artistas", "desc": "Inmóvil en la Rambla hasta que le echan una moneda. Necesita permiso municipal para su sitio."},
	"caricaturista": {"label": "Caricaturista", "grupo": "Calle y artistas", "desc": "Pintor de retratos y caricaturas para turistas en la Rambla."},
	"skater": {"label": "Skater", "grupo": "Calle y artistas", "accesorio": "gorra", "desc": "De la plaza dels Àngels, frente al MACBA. Llegan de todo el mundo a patinar ahí."},
	"punki": {"label": "Punki", "grupo": "Calle y artistas", "desc": "Punki con perros. Duerme donde puede, pide y se junta con los suyos en las plazas."},
	"educador": {"label": "Educador social", "label_f": "Educadora social", "grupo": "Calle y artistas", "accesorio": "chaleco", "look": {"shirt": "e07a30"}, "desc": "Educadores de calle: reparten material, acompañan al CAS y conocen a todos por su nombre."},
	# --- Vecinos
	"vecino": {"label": "Vecino", "label_f": "Vecina", "grupo": "Vecinos", "desc": "Vive en el barrio y está harto, o lo defiende, o las dos cosas."},
	"anciano": {"label": "Abuelo", "label_f": "Abuela", "grupo": "Vecinos", "accesorio": "baston", "desc": "Toda la vida en el barrio. Ve cómo se va la gente de antes."},
	"nino": {"label": "Niño", "label_f": "Niña", "grupo": "Vecinos", "tamano": 0.62, "desc": "Juega en las plazas al salir del cole."},
	"perro": {"label": "Perro", "label_f": "Perra", "grupo": "Vecinos", "desc": "Perro con nombre. Sale con su dueño."},
	# --- De paso
	"turista": {"label": "Turista", "grupo": "De paso", "accesorio": "mochila", "desc": "Visita el barrio de día y lleva dinero encima."},
	"fiestero": {"label": "De despedida", "grupo": "De paso", "accesorio": "despedida", "desc": "Despedida de soltero: borracho, eufórico y perdido."},
	"guia": {"label": "Guía de free tour", "grupo": "De paso", "desc": "Lleva grupos de turistas con un paraguas en alto y vive de las propinas."},
	"mensajero": {"label": "Repartidor", "label_f": "Repartidora", "grupo": "De paso", "accesorio": "reparto", "desc": "Rider en bici, a menudo con la cuenta alquilada a otro."},
	"pudiente": {"label": "Pijo", "label_f": "Pija", "grupo": "De paso", "desc": "Con dinero: nómadas digitales, inversores, gente del MACBA y del Liceu."},
}

## Accesorios que sabe dibujar Actor (ver Actor._build_person).
const ACCESORIOS := {
	"": "Ninguno", "gorra": "Gorra del revés", "gorra_poli": "Gorra de policía", "capucha": "Capucha",
	"mochila": "Mochila y sombrero", "chaleco": "Chaleco", "bolsa": "Bolsa de latas", "caja": "Caja de trile",
	"baston": "Bastón", "reparto": "Mochila de reparto", "despedida": "Banda de despedida",
}
const PEINADOS := {"corto": "Corto", "rapado": "Rapado", "calvo": "Calvo", "tupe": "Tupé", "rizos": "Rizos",
	"coleta": "Coleta", "melena": "Melena", "moño": "Moño", "corta": "Media melena"}
const VELLO := {"": "Nada", "barba": "Barba", "bigote": "Bigote"}


## Si el juego ya tiene este tipo de bot (si no, el personaje se guarda pero no sale).
static func en_juego(id: String) -> bool:
	return Npc.KINDS.has(id)


static func label(id: String, genero := "m") -> String:
	var t: Dictionary = TIPOS.get(id, {"label": id})
	return t.get("label_f", t["label"]) if genero == "f" else t["label"]


## Ids de los tipos de un grupo, en el orden de TIPOS.
static func del_grupo(grupo: String) -> Array[String]:
	var out: Array[String] = []
	for id in TIPOS:
		if TIPOS[id]["grupo"] == grupo:
			out.append(id)
	return out
