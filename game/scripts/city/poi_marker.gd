class_name PoiMarker
extends Node3D
## Cartel de un lugar del barrio (bar, farmacia, cajero...) sobre un poste en la acera.

const STYLE := {
	"super": ["SÚPER", Color("2f8f4f")],
	"farmacia": ["✚ FARMÀCIA", Color("1fae5a")],
	"bar": ["BAR", Color("b8862f")],
	"kebab": ["KEBAB", Color("c0452f")],
	"cajero": ["€ CAJERO", Color("2f5fae")],
	"iglesia": ["✝", Color("7a6a5a")],
	"banco": ["", Color("6a5040")],
	"albergue": ["SOCIAL", Color("8a5ab0")],
	"cap": ["CAP", Color("2fa0b0")],
	"cas": ["CAS BALUARD", Color("e07a30")],
	"comisaria": ["POLICÍA", Color("1d2a5a")],
	"compraventa": ["COMPRO ORO", Color("b0a02f")],
	"club": ["·", Color("2a3a2a")],  # una puerta sin rótulo; «CLUB» cuando sabes lo que es
	"altar": ["DEP", Color("4a3a5a")],  # donde murió un yonki de antes (World._altar)
}
const NAMED_KINDS := ["bar", "kebab", "super", "compraventa"]
const SIGN_Y := 4.6

var poi: Dictionary
var highlighted := false:
	set(v):
		highlighted = v
		if not v and _label:
			_label.visible = true

var _label: Label3D
var _t := 0.0


func setup(p_poi: Dictionary, world_pos: Vector3) -> void:
	poi = p_poi
	position = world_pos


func _ready() -> void:
	var style: Array = STYLE.get(poi["kind"], ["?", Color.GRAY])
	if poi["kind"] == "banco":
		# banco de la calle: mobiliario, sin cartel
		CityProps.part(self, CityProps.box(Vector3(2.0, 0.12, 0.6)), Color("7a5a40"), Vector3(0, 0.55, 0))
		CityProps.part(self, CityProps.box(Vector3(2.0, 0.5, 0.1)), Color("7a5a40"), Vector3(0, 0.85, -0.28))
		for x in [-0.85, 0.85]:
			CityProps.part(self, CityProps.box(Vector3(0.1, 0.55, 0.5)), Color("2a2a2a"), Vector3(x, 0.27, 0))
		return
	if poi["kind"] == "altar":
		_altar()
		return
	CityProps.part(self, CityProps.cylinder(0.07, 0.07, SIGN_Y), Color("303034"), Vector3(0, SIGN_Y / 2.0, 0))
	_label = Label3D.new()
	_label.text = style[0]
	# en bares, comida y tiendas se lee el nombre real (que un McDonald's no ponga "KEBAB")
	var poi_name: String = poi["name"]
	if poi["kind"] in NAMED_KINDS and poi_name != "" and poi_name.length() <= 16:
		_label.text = poi_name.to_upper()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0, SIGN_Y + 0.4, 0)
	_label.font_size = 48
	_label.pixel_size = 0.016
	_label.outline_size = 30
	_label.modulate = Color.WHITE
	_label.outline_modulate = style[1]
	add_child(_label)


## El altar de la calle: un cartón con su nombre contra la pared, velas, flores de gasolinera
## y alguna lata, y el nombre encima («DEP Paco»), más bajo que los carteles.
func _altar() -> void:
	var a := Node3D.new()  # todo algo más grande que en la realidad, como los muñecos
	a.scale = Vector3.ONE * 1.6
	add_child(a)
	var carton := CityProps.part(a, CityProps.box(Vector3(0.9, 0.7, 0.04)), Color("c8a46a"), Vector3(0, 0.45, -0.5))
	carton.rotation.x = deg_to_rad(-12.0)
	CityProps.part(a, CityProps.box(Vector3(0.6, 0.06, 0.05)), Color("2a2a2a"), Vector3(0, 0.55, -0.47))
	for i in 5:
		var x := -0.45 + 0.22 * i
		CityProps.part(a, CityProps.cylinder(0.05, 0.05, 0.16 + 0.05 * (i % 3), 8), Color("f0e8d0"), Vector3(x, 0.1, -0.15 + 0.08 * (i % 2)))
		CityProps.part(a, CityProps.sphere(0.035), Color(1.6, 1.1, 0.4), Vector3(x, 0.22 + 0.05 * (i % 3), -0.15 + 0.08 * (i % 2)))  # la llama (brilla)
	for i in 4:
		var ang := 0.6 + i * 0.5
		CityProps.part(a, CityProps.sphere(0.09), [Color("d02040"), Color("f0d030"), Color("f0f0f0"), Color("e06080")][i], Vector3(cos(ang) * 0.4, 0.08, -0.35 + sin(ang) * 0.12))
	CityProps.part(a, CityProps.cylinder(0.05, 0.05, 0.18, 8), Color("2a6a3a"), Vector3(0.55, 0.09, -0.05))  # la litrona
	_label = Label3D.new()
	_label.text = "DEP " + str(poi["name"]).to_upper()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0, 2.4, 0)
	_label.font_size = 40
	_label.pixel_size = 0.016
	_label.outline_size = 24
	_label.outline_modulate = Color("4a3a5a")
	add_child(_label)


func sign_position() -> Vector3:
	var y: float = {"banco": 0.6, "altar": 2.4}.get(poi["kind"], SIGN_Y + 0.4)
	return global_position + Vector3(0, y, 0)


func _process(delta: float) -> void:
	if poi["kind"] == "club" and _label:
		var conocido: bool = poi["name"] in GameState.clubs_conocidos
		_label.text = "CLUB" if conocido else "·"
		_label.outline_modulate = Color("3a7a3a") if conocido else Color("2a3a2a")
	if highlighted and _label:
		_t += delta
		_label.visible = int(_t * 3.0) % 2 == 0
