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


func sign_position() -> Vector3:
	return global_position + Vector3(0, SIGN_Y + 0.4 if poi["kind"] != "banco" else 0.6, 0)


func _process(delta: float) -> void:
	if highlighted and _label:
		_t += delta
		_label.visible = int(_t * 3.0) % 2 == 0
