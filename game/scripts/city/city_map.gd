class_name CityMap
extends Node3D
## Barrio en 3D construido a partir de data/<barrio>_map.json (tools/build_map.py, desde OpenStreetMap).
##
## Coordenadas: 1 unidad = 1 metro. La casilla de navegación (x, y) ocupa
## [x*cell_m, (x+1)*cell_m) en X y lo mismo en Z. El suelo está en Y = 0.
## La navegación usa la cuadrícula; lo que se ve son las huellas reales de los edificios.

enum Cell { VOID, BUILDING, ROAD, STREET, PLAZA, FILLER }

const WALKABLE := [Cell.ROAD, Cell.STREET, Cell.PLAZA]

@export_file("*.json") var map_path := "res://data/raval_map.json"
@export_file("*.json") var crime_path := "res://data/raval_crime.json"

var width := 0
var height := 0
var cell_m := 4.0
var cells := PackedByteArray()
var pois: Array = []  ## [{kind, name, x, y}] en casillas
var streets: Array = []  ## [{name, x, y}] muestras de cada calle, en casillas
var labels: Array = []  ## [{text, x, z}] rótulos de los edificios conocidos (MACBA, Liceu...), en metros
var crime: Dictionary = {}
var barrio_name := ""

var entities: Node3D  ## Personajes y carteles
var building_material: ShaderMaterial
var astar := AStarGrid2D.new()

var _data: Dictionary
var _walkable_cells: Array[Vector2i] = []


func _ready() -> void:
	_load()
	_build_ground()
	_build_buildings()
	var props := Node3D.new()
	props.name = "Props"
	add_child(props)
	for b in _data["buildings"]:
		if b.has("x"):
			CityProps.building_extra(props, b)
	for s in _data["statues"]:
		CityProps.statue(props, s)
	for l in _data["labels"]:
		CityProps.label(props, l)
	for s in _data["signs"]:
		CityProps.street_sign(props, s)
	for s in _data.get("storefronts", []):
		CityProps.storefront(props, s)
	CityProps.trees(props, _data["trees"])
	entities = Node3D.new()
	entities.name = "Entities"
	add_child(entities)
	_build_astar()


func _load() -> void:
	_data = JSON.parse_string(FileAccess.get_file_as_string(map_path))
	barrio_name = _data["name"]
	width = _data["width"]
	height = _data["height"]
	cell_m = _data["cell_m"]
	cells.resize(width * height)
	var rows: Array = _data["cells"]
	for y in height:
		var row: String = rows[y]
		for x in width:
			cells[y * width + x] = row.unicode_at(x) - 48
	pois = _data["pois"]
	streets = _data["streets"]
	labels = _data.get("labels", [])
	if FileAccess.file_exists(crime_path):
		crime = JSON.parse_string(FileAccess.get_file_as_string(crime_path))


func size_m() -> Vector2:
	return Vector2(width, height) * cell_m


func _build_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = size_m()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/ground.png")
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var mi := MeshInstance3D.new()
	mi.name = "Suelo"
	mi.mesh = plane
	mi.material_override = mat
	mi.position = Vector3(size_m().x / 2.0, 0, size_m().y / 2.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_buildings() -> void:
	building_material = ShaderMaterial.new()
	building_material.shader = load("res://shaders/building.gdshader")
	building_material.set_shader_parameter("facade", load("res://assets/facade.png"))
	var mesher := BuildingMesher.new()
	mesher.index_footprints(_data["buildings"])
	mesher.is_street = func(p: Vector2) -> bool: return is_walkable(world_to_cell(Vector3(p.x, 0, p.y)))
	for b in _data["buildings"]:
		mesher.add_building(b)
	# relleno: interiores de manzana sin edificio en OSM
	var sides := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	for y in height:
		for x in width:
			if cells[y * width + x] != Cell.FILLER:
				continue
			var open := []
			for s in sides:
				var t := cell_type(Vector2i(x, y) + s)
				if t in WALKABLE or t == Cell.VOID:
					open.append(s)
			# misma fachada por bloques de ~12 m para que no parezca un mosaico
			var block := Vector2i(floori(x * cell_m / 12.0), floori(y * cell_m / 12.0))
			mesher.add_filler(Vector2i(x, y), cell_m, open, block.x * 31 + block.y * 17)
	var holder := Node3D.new()
	holder.name = "Edificios"
	add_child(holder)
	for mi in mesher.build(building_material):
		holder.add_child(mi)


func _build_astar() -> void:
	astar.region = Rect2i(0, 0, width, height)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	_walkable_cells.clear()
	for y in height:
		for x in width:
			var pos := Vector2i(x, y)
			if is_walkable(pos):
				_walkable_cells.append(pos)
				if cells[y * width + x] == Cell.ROAD:
					astar.set_point_weight_scale(pos, 1.5)  # mejor ir por la acera
			else:
				astar.set_point_solid(pos, true)


func cell_type(cell: Vector2i) -> int:
	if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
		return Cell.VOID
	return cells[cell.y * width + cell.x]


func is_walkable(cell: Vector2i) -> bool:
	return cell_type(cell) in WALKABLE


func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3((cell.x + 0.5) * cell_m, 0, (cell.y + 0.5) * cell_m)


func world_to_cell(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / cell_m), floori(pos.z / cell_m))


func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if not is_walkable(from):
		from = nearest_walkable(from)
	if not is_walkable(to):
		to = nearest_walkable(to)
	return astar.get_id_path(from, to)


func nearest_walkable(cell: Vector2i, max_radius := 40) -> Vector2i:
	if is_walkable(cell):
		return cell
	for r in range(1, max_radius + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := cell + Vector2i(dx, dy)
				if is_walkable(c):
					return c
	return cell


## Si desde la casilla `from` se ve la casilla `to`: la recta entre las dos (Bresenham) no
## pasa por ninguna casilla que no sea calle o plaza (edificios, interiores de manzana).
func line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	var d := Vector2i(absi(to.x - from.x), -absi(to.y - from.y))
	var s := Vector2i(1 if from.x < to.x else -1, 1 if from.y < to.y else -1)
	var err := d.x + d.y
	var c := from
	while c != to:
		var e2 := 2 * err
		if e2 >= d.y:
			err += d.y
			c.x += s.x
		if e2 <= d.x:
			err += d.x
			c.y += s.y
		if c != to and not is_walkable(c):
			return false
	return true


## Metros que se ven en línea recta desde `from` en la dirección `dir` (plana) antes de
## topar con un edificio, hasta `max_m`. Para dibujar los conos de visión.
func clear_distance(from: Vector3, dir: Vector3, max_m: float) -> float:
	var step := cell_m * 0.25
	var d := step
	while d < max_m:
		if not is_walkable(world_to_cell(from + dir * d)):
			return d
		d += step
	return max_m


func random_walkable() -> Vector2i:
	return _walkable_cells.pick_random()


## Casilla transitable al azar a menos de `radius` casillas de `center`.
func random_walkable_near(center: Vector2i, radius: int) -> Vector2i:
	for i in 30:
		var c := center + Vector2i(randi_range(-radius, radius), randi_range(-radius, radius))
		if is_walkable(c):
			return c
	return nearest_walkable(center)


func pois_of_kind(kind: String) -> Array:
	return pois.filter(func(p): return p["kind"] == kind)


## Casilla andable más cercana al edificio con el rótulo `text` (MACBA, Liceu, Colom...);
## (-1, -1) si no está en el mapa.
func landmark_cell(text: String) -> Vector2i:
	for l in labels:
		if l["text"] == text:
			return nearest_walkable(world_to_cell(Vector3(l["x"], 0.0, l["z"])))
	return Vector2i(-1, -1)


## Casillas transitables de una calle (a partir de sus muestras); vacío si no está en el mapa.
func street_cells(street: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for s in streets:
		if s["name"] == street:
			var c := Vector2i(s["x"], s["y"])
			if is_walkable(c):
				out.append(c)
	return out


func street_name_near(cell: Vector2i, max_cells := 1e9) -> String:
	var best := ""
	var best_d := max_cells * max_cells
	for s in streets:
		var d := Vector2(s["x"] - cell.x, s["y"] - cell.y).length_squared()
		if d < best_d:
			best_d = d
			best = s["name"]
	return best


## Índice de criminalidad de una categoría convertido en multiplicador (ver Defs.crime_factor).
func crime_factor(category: String) -> float:
	return Defs.crime_factor(crime.get("index", {}).get(category, 1.0))
