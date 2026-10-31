class_name Defs
## Datos fijos del juego: perfiles de yonki, sustancias, objetos y títulos.
## Para equilibrar el juego, casi todo se toca aquí.

## Minutos de juego que pasan por cada segundo real.
const GAME_MINUTES_PER_SECOND := 2.0

const PROFILES := [
	{
		"id": "sin_papeles",
		"name": "Youssef",
		"title": "Sin papeles",
		"desc": "Llegó en patera con un sueño. El sueño se quedó en Tarifa. Sin paro, sin pensión, sin nada que perder... salvo el país.",
		"money": 15, "health": 85, "dignity": 70, "addiction": 10,
		"income": {},
		"perk": "Sabe ganarse la vida en la calle: los manteros le dan curro. Pero tres detenciones y lo deportan.",
		"items": {"movil_roto": 1},
		"look": {"skin": Color("8d5a3b"), "shirt": Color("2f6b4f"), "pants": Color("3a3a48"), "hair": Color("1b1410")},
	},
	{
		"id": "parado",
		"name": "Paco",
		"title": "Parado de larga duración",
		"desc": "52 años, 30 cotizando en una fábrica que ahora es un hotel boutique. Le queda el paro y la litrona de las once.",
		"money": 60, "health": 65, "dignity": 60, "addiction": 25,
		"income": {"amount": 150, "every_days": 3, "label": "el paro"},
		"perk": "Cobra el paro cada 3 días en el cajero.",
		"items": {"litrona": 1},
		"look": {"skin": Color("d9a77c"), "shirt": Color("8a8f5a"), "pants": Color("4a3f35"), "hair": Color("6b6b6b")},
	},
	{
		"id": "jubilado",
		"name": "Don Ramón",
		"title": "Jubilado",
		"desc": "Viudo, 71 años. Descubrió las tragaperras, después los carajillos, después lo demás. Los nietos ya no llaman.",
		"money": 120, "health": 45, "dignity": 85, "addiction": 15,
		"income": {"amount": 220, "every_days": 4, "label": "la pensión"},
		"perk": "La policía no sospecha de un abuelo. Da mucha pena pidiendo.",
		"items": {"bocadillo": 1},
		"look": {"skin": Color("e8bfa0"), "shirt": Color("5b4a3a"), "pants": Color("6e6658"), "hair": Color("e8e8e8")},
	},
	{
		"id": "divorciado",
		"name": "Jordi",
		"title": "Divorciado",
		"desc": "Ella se quedó la casa, el perro y los amigos. Él se quedó un estudio en la calle del Carme y mucho tiempo libre.",
		"money": 350, "health": 80, "dignity": 95, "addiction": 5,
		"income": {"amount": -80, "every_days": 4, "label": "la pensión alimenticia"},
		"perk": "Empieza con ahorros y un anillo de boda que vender. Cada 4 días le cobran la pensión alimenticia.",
		"items": {"anillo": 1, "movil": 1},
		"look": {"skin": Color("e0b08a"), "shirt": Color("3d5a8a"), "pants": Color("2b2b33"), "hair": Color("4a3020")},
	},
	{
		"id": "psiquiatrico",
		"name": "Mari Loli",
		"title": "Recién salida del psiquiátrico",
		"desc": "Le dieron el alta, una receta y un 'cuídate, Loli'. Las voces dicen que el Raval es un buen sitio para empezar.",
		"money": 30, "health": 70, "dignity": 50, "addiction": 20,
		"income": {},
		"perk": "Recoge pastillas gratis en la farmacia cada 2 días. Oye voces.",
		"items": {"pastillas": 2},
		"look": {"skin": Color("efc7a8"), "shirt": Color("a04a7a"), "pants": Color("5a4a6a"), "hair": Color("c45a2a")},
	},
	{
		"id": "nino_bien",
		"name": "Borja",
		"title": "Niño bien de Pedralbes",
		"desc": "Bajó al Raval 'a conocer la Barcelona auténtica'. Papá le pasa una paga. Tiene muchísima dignidad que perder.",
		"money": 600, "health": 95, "dignity": 100, "addiction": 0,
		"income": {"amount": 200, "every_days": 3, "label": "la paga de papá"},
		"perk": "Papá le ingresa dinero... hasta que su dignidad baje de 40 y alguien se lo cuente.",
		"items": {"movil": 1},
		"look": {"skin": Color("f0cfb0"), "shirt": Color("e8e2d0"), "pants": Color("2a3a5a"), "hair": Color("d8b060")},
	},
]

## Efectos en el juego (no son datos reales):
## high = colocón, addiction = enganche, health/dignity = cambios, od = riesgo de sobredosis.
const SUBSTANCES := {
	"litrona": {"name": "Litrona", "price": 2, "high": 15, "addiction": 1, "health": -1, "dignity": -1, "od": 0.0},
	"porro": {"name": "Porro", "price": 4, "high": 15, "addiction": 1, "health": -1, "dignity": 0, "od": 0.0},
	"pastillas": {"name": "Pastillas", "price": 3, "high": 22, "addiction": 3, "health": -3, "dignity": -1, "od": 0.2},
	"farlopa": {"name": "Farlopa", "price": 30, "high": 35, "addiction": 4, "health": -4, "dignity": -2, "od": 0.3},
	"base": {"name": "Base", "price": 10, "high": 40, "addiction": 9, "health": -6, "dignity": -6, "od": 0.5},
	"caballo": {"name": "Caballo", "price": 15, "high": 55, "addiction": 8, "health": -8, "dignity": -5, "od": 1.0},
	"metadona": {"name": "Metadona", "price": 0, "high": 8, "addiction": -2, "health": 0, "dignity": 0, "od": 0.0, "mono": -60},
}

## Lo que vende cada camello (el resto se consigue por otras vías).
const DEALER_STOCK := ["porro", "pastillas", "farlopa", "base", "caballo"]

const ITEMS := {
	"movil": {"name": "Móvil", "sell": 30},
	"movil_roto": {"name": "Móvil con la pantalla rota", "sell": 6},
	"cartera": {"name": "Cartera ajena", "sell": 0},
	"anillo": {"name": "Anillo de boda", "sell": 60},
	"cobre": {"name": "Cable de cobre", "sell": 8},
	"gafas": {"name": "Gafas de sol de mantero", "sell": 1},
	"bocadillo": {"name": "Bocadillo", "sell": 0, "food": 12},
	"durum": {"name": "Dürüm", "sell": 0, "food": 18},
	"sobras": {"name": "Sobras", "sell": 0, "food": 6},
}

## Títulos finales según la caída acumulada.
const TITLES := [
	[0, "Turista accidental"],
	[60, "Habitual del barrio"],
	[150, "Carne de cajero"],
	[300, "Fauna del Raval"],
	[500, "Leyenda de Ciutat Vella"],
	[800, "Patrimonio inmaterial de la Humanidad"],
]

## Hitos de la caída: se cuentan una sola vez.
const MILESTONES := {
	"primera_calle": ["Primera noche al raso", 15],
	"cajero": ["Dormir en un cajero", 10],
	"primer_robo": ["Primer palo", 10],
	"primera_detencion": ["Primera noche en el calabozo", 20],
	"sobras": ["Comer sobras ajenas", 5],
	"rebuscar": ["Rebuscar en la basura", 5],
	"sobredosis": ["Sobrevivir a una sobredosis", 25],
	"anillo": ["Empeñar el anillo de boda", 20],
	"chivato": ["Chivarse a la policía", 15],
	"papa_corta": ["Papá te corta el grifo", 25],
	"pelea_perdida": ["Perder una pelea con otro yonki", 10],
	"primer_caballo": ["Probar el caballo", 10],
	"primera_base": ["Probar la base", 10],
	"fondo": ["Tocar fondo (dignidad 0)", 50],
	"deuda": ["Deber dinero a un camello", 10],
}


static func profile(id: String) -> Dictionary:
	for p in PROFILES:
		if p["id"] == id:
			return p
	return PROFILES[0]


static func item_name(id: String) -> String:
	if SUBSTANCES.has(id):
		return SUBSTANCES[id]["name"]
	if ITEMS.has(id):
		return ITEMS[id]["name"]
	return id


static func title_for(caida: float) -> String:
	var t: String = TITLES[0][1]
	for entry in TITLES:
		if caida >= entry[0]:
			t = entry[1]
	return t


## Convierte un índice de criminalidad (1.0 = barrio mediano) en un multiplicador suave.
static func crime_factor(index: float) -> float:
	return clampf(1.0 + 0.3 * log(maxf(index, 0.01)) / log(2.0), 0.5, 3.5)
