class_name BuildingMesher
## Construye las mallas de los edificios a partir de sus huellas reales (extrusión)
## y de las casillas de "relleno" (interiores de manzana sin mapear).
## Agrupa todo en trozos de CHUNK_M metros para que la cámara pueda descartar los que no ve.

const CHUNK_M := 128.0
const BAY_M := 3.5  ## ancho de un vano de fachada
const FLOOR_M := 3.3
## Caricatura: los edificios tienen menos plantas que en la realidad para que desde
## la cámara isométrica se vean las calles (el Raval real es un cañón de 6 plantas).
const LEVEL_SCALE := 0.55
const LANDMARK_HEIGHT_SCALE := 0.75
const FILLER_LEVELS := 2
const FILLER_HEIGHT := FILLER_LEVELS * FLOOR_M + 0.6

## Colores de fachada típicos de Ciutat Vella: ocres, cremas, rosas desvaídos, grises.
const FACADE_COLORS := [
	Color("d9b48a"), Color("c98f6a"), Color("e6d3ad"), Color("b9a08a"),
	Color("d6a47c"), Color("a9a59c"), Color("cf9d92"), Color("e8dcc0"),
	Color("c4b07a"), Color("b8806a"),
]

var _tools := {}  ## Vector2i trozo -> SurfaceTool


static func facade_color(seed: int) -> Color:
	return FACADE_COLORS[seed % FACADE_COLORS.size()]


## Altura con la que se dibuja el edificio (ver LEVEL_SCALE).
static func display_height(b: Dictionary) -> float:
	if b.has("c") or b["s"] != 0:  # monumentos e iglesias
		return b["h"] * LANDMARK_HEIGHT_SCALE
	var levels := maxf(1.0, roundf(b["lv"] * LEVEL_SCALE))
	return levels * FLOOR_M + 0.6


func add_building(b: Dictionary) -> void:
	var pts := PackedVector2Array()
	for p in b["p"]:
		pts.append(Vector2(p[0], p[1]))
	var h := display_height(b)
	var levels := maxf(1.0, roundf((h - 0.6) / FLOOR_M))
	var seed: int = b["seed"]
	var color := Color(b["c"][0] / 255.0, b["c"][1] / 255.0, b["c"][2] / 255.0) if b.has("c") else facade_color(seed)
	var style: float = b["s"]
	var st := _tool_for(_centroid(pts))
	st.set_color(color)
	st.set_uv2(Vector2(style, (seed % 997) / 997.0))
	var n := pts.size()
	for i in n:
		var a := pts[i]
		var c := pts[(i + 1) % n]
		var length := a.distance_to(c)
		if length < 0.01:
			continue
		var bays := maxf(1.0, roundf(length / BAY_M))
		var e := (c - a) / length
		_quad(st,
			Vector3(a.x, 0, a.y), Vector3(c.x, 0, c.y), Vector3(c.x, h, c.y), Vector3(a.x, h, a.y),
			Vector2(0, 0), Vector2(bays, 0), Vector2(bays, levels), Vector2(0, levels),
			Vector3(e.y, 0, -e.x))
	_roof(st, pts, h)


## Casilla de relleno: bloque bajo con paredes solo hacia la calle.
## Las esquinas que sobresalen (dos lados contiguos abiertos) se achaflanan en diagonal para
## que el borde de una manzana sin mapear no se vea como una escalera, y las casillas sueltas
## (tres o cuatro lados abiertos) no se dibujan.
func add_filler(cell: Vector2i, cell_m: float, open_sides: Array, seed: int) -> void:
	if open_sides.size() >= 3:
		return
	var x0 := cell.x * cell_m
	var z0 := cell.y * cell_m
	var x1 := x0 + cell_m
	var z1 := z0 + cell_m
	var h := FILLER_HEIGHT
	var st := _tool_for(Vector2(x0, z0))
	st.set_color(facade_color(seed))
	st.set_uv2(Vector2(0, (seed % 997) / 997.0))
	var L := float(FILLER_LEVELS)
	if open_sides.size() == 2 and open_sides[0] != -open_sides[1]:
		var sa := Vector3(open_sides[0].x, 0, open_sides[0].y)
		var sb := Vector3(open_sides[1].x, 0, open_sides[1].y)
		var center := Vector3(x0 + cell_m / 2.0, 0, z0 + cell_m / 2.0)
		var half := cell_m / 2.0
		var a := center + (sa - sb) * half
		var c := center + (sb - sa) * half
		var back := center - (sa + sb) * half
		var up := Vector3(0, h, 0)
		var bays := cell_m * sqrt(2.0) / BAY_M
		var u0 := float(cell.x + cell.y) * bays
		_quad(st, a, c, c + up, a + up,
			Vector2(u0, 0), Vector2(u0 + bays, 0), Vector2(u0 + bays, L), Vector2(u0, L),
			(sa + sb).normalized())
		_tri(st, a + up, c + up, back + up, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector3.UP)
		return
	var corners := {
		Vector2i(0, -1): [Vector3(x1, 0, z0), Vector3(x0, 0, z0)],
		Vector2i(0, 1): [Vector3(x0, 0, z1), Vector3(x1, 0, z1)],
		Vector2i(-1, 0): [Vector3(x0, 0, z0), Vector3(x0, 0, z1)],
		Vector2i(1, 0): [Vector3(x1, 0, z1), Vector3(x1, 0, z0)],
	}
	for side in open_sides:
		var a: Vector3 = corners[side][0]
		var c: Vector3 = corners[side][1]
		var bays := cell_m / BAY_M
		var u0 := float(cell.x + cell.y) * bays  # vanos continuos entre casillas vecinas
		_quad(st, a, c, c + Vector3(0, h, 0), a + Vector3(0, h, 0),
			Vector2(u0, 0), Vector2(u0 + bays, 0), Vector2(u0 + bays, L), Vector2(u0, L),
			Vector3(side.x, 0, side.y))
	_quad(st, Vector3(x0, h, z0), Vector3(x1, h, z0), Vector3(x1, h, z1), Vector3(x0, h, z1),
		Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector3.UP)


func build(material: Material) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for key in _tools:
		var st: SurfaceTool = _tools[key]
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = material
		mi.name = "Edificios_%d_%d" % [key.x, key.y]
		out.append(mi)
	_tools.clear()
	return out


func _tool_for(pos: Vector2) -> SurfaceTool:
	var key := Vector2i(floori(pos.x / CHUNK_M), floori(pos.y / CHUNK_M))
	if not _tools.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[key] = st
	return _tools[key]


func _centroid(pts: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	return c / pts.size()


func _roof(st: SurfaceTool, pts: PackedVector2Array, h: float) -> void:
	var idx := Geometry2D.triangulate_polygon(pts)
	for i in range(0, idx.size(), 3):
		var v0 := Vector3(pts[idx[i]].x, h, pts[idx[i]].y)
		var v1 := Vector3(pts[idx[i + 1]].x, h, pts[idx[i + 1]].y)
		var v2 := Vector3(pts[idx[i + 2]].x, h, pts[idx[i + 2]].y)
		_tri(st, v0, v1, v2, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector3.UP)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, normal: Vector3) -> void:
	_tri(st, a, b, c, ua, ub, uc, normal)
	_tri(st, a, c, d, ua, uc, ud, normal)


## Añade un triángulo orientado para que su cara visible mire hacia `normal`
## (Godot dibuja las caras cuyos vértices van en sentido horario vistos de frente).
func _tri(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3,
		u0: Vector2, u1: Vector2, u2: Vector2, normal: Vector3) -> void:
	if (v2 - v0).cross(v1 - v0).dot(normal) < 0.0:
		var tv := v1
		v1 = v2
		v2 = tv
		var tu := u1
		u1 = u2
		u2 = tu
	st.set_normal(normal)
	st.set_uv(u0)
	st.add_vertex(v0)
	st.set_uv(u1)
	st.add_vertex(v1)
	st.set_uv(u2)
	st.add_vertex(v2)
