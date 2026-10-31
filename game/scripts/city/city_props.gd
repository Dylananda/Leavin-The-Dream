class_name CityProps
## Elementos que hacen reconocible el barrio: monumentos con modelo propio,
## rótulos de edificios emblemáticos y de comercios, placas de calle de mármol y árboles.

const STONE := Color("b6a487")
const BRONZE := Color("3a2e22")
const SIGN_HEIGHT := 4.2
const SHOP_SIGN_HEIGHT := 2.9  ## justo encima de la puerta, por debajo de las placas de calle

static var _mats := {}
## Material de las copas; world.gd le actualiza los rayos X igual que a los edificios.
static var foliage_material: ShaderMaterial:
	get:
		if foliage_material == null:
			foliage_material = ShaderMaterial.new()
			foliage_material.shader = load("res://shaders/foliage.gdshader")
		return foliage_material


static func mat(color: Color, metallic := 0.0) -> StandardMaterial3D:
	var key := "%s_%s" % [color.to_html(), metallic]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		m.metallic = metallic
		_mats[key] = m
	return _mats[key]


static func part(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, rot := Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(color)
	mi.position = pos
	mi.rotation = rot
	mi.scale = scale
	parent.add_child(mi)
	return mi


static func box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func cylinder(top: float, bottom: float, height: float, segments := 12) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = segments
	return m


static func sphere(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 16
	m.rings = 8
	return m


## Modelos extra encima de algunos edificios (campanarios, chimeneas de Gaudí...).
static func building_extra(parent: Node3D, b: Dictionary) -> void:
	var pts := PackedVector2Array()
	for p in b["p"]:
		pts.append(Vector2(p[0], p[1]))
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= pts.size()
	var h := BuildingMesher.display_height(b)
	match b.get("x", ""):
		"belltower":
			# campanario en la esquina más alejada del centro, metido 3 m hacia dentro
			var far := pts[0]
			for p in pts:
				if p.distance_to(c) > far.distance_to(c):
					far = p
			var t := far.lerp(c, clampf(3.0 / far.distance_to(c), 0.0, 1.0))
			var tower_h := h + 12.0
			part(parent, box(Vector3(4.5, tower_h, 4.5)), STONE, Vector3(t.x, tower_h / 2.0, t.y))
			part(parent, box(Vector3(1.4, 2.2, 4.7)), Color("2a2420"), Vector3(t.x, tower_h - 2.5, t.y))
			part(parent, cylinder(0.0, 3.4, 5.0, 4), Color("8a6a50"), Vector3(t.x, tower_h + 2.5, t.y), Vector3(0, PI / 4.0, 0))
		"chimneys":
			# las chimeneas de colores del Palau Güell
			var colors := [Color("e05a3a"), Color("3ab0e0"), Color("f0d040"), Color("60c060"), Color("e070c0"), Color("f0f0f0")]
			var rng := RandomNumberGenerator.new()
			rng.seed = 42
			var placed := 0
			for i in 60:
				var p := c + Vector2(rng.randf_range(-8, 8), rng.randf_range(-8, 8))
				if not Geometry2D.is_point_in_polygon(p, pts):
					continue
				var ch := rng.randf_range(2.0, 3.4)
				part(parent, cylinder(0.35, 0.55, ch, 8), colors[placed % colors.size()], Vector3(p.x, h + ch / 2.0, p.y))
				part(parent, sphere(0.55), colors[(placed + 2) % colors.size()], Vector3(p.x, h + ch + 0.3, p.y))
				placed += 1
				if placed >= 12:
					break
		"market":
			# cubierta de hierro: bóveda verde sobre la nave
			var size := _extent(pts)
			var along_x := size.x >= size.y
			var length := (size.x if along_x else size.y) * 0.8
			var radius := (size.y if along_x else size.x) * 0.35
			# el cilindro se tumba a lo largo de la nave y se aplasta en vertical
			part(parent, cylinder(radius, radius, length, 16), Color("4e7a5a"),
				Vector3(c.x, h, c.y), Vector3(0, 0, PI / 2.0) if along_x else Vector3(PI / 2.0, 0, 0),
				Vector3(0.45, 1, 1) if along_x else Vector3(1, 1, 0.45))


static func _extent(pts: PackedVector2Array) -> Vector2:
	var mn := pts[0]
	var mx := pts[0]
	for p in pts:
		mn = mn.min(p)
		mx = mx.max(p)
	return mx - mn


static func statue(parent: Node3D, s: Dictionary) -> void:
	var root := Node3D.new()
	root.position = Vector3(s["x"], 0, s["z"])
	parent.add_child(root)
	match s["kind"]:
		"gat":
			# el Gat de Botero: gato gordo de bronce sobre la Rambla del Raval
			var cat := Node3D.new()
			cat.scale = Vector3.ONE * 1.6
			root.add_child(cat)
			part(cat, box(Vector3(3.0, 0.4, 1.6)), STONE, Vector3(0, 0.2, 0))
			part(cat, sphere(1.0), BRONZE, Vector3(0, 1.9, 0), Vector3.ZERO, Vector3(2.2, 1.0, 1.0))
			for lx in [-1.3, 1.3]:
				for lz in [-0.45, 0.45]:
					part(cat, cylinder(0.28, 0.32, 1.2), BRONZE, Vector3(lx, 0.9, lz))
			part(cat, sphere(0.75), BRONZE, Vector3(2.0, 2.7, 0))
			part(cat, cylinder(0.0, 0.3, 0.6, 6), BRONZE, Vector3(2.0, 3.45, -0.35))
			part(cat, cylinder(0.0, 0.3, 0.6, 6), BRONZE, Vector3(2.0, 3.45, 0.35))
			part(cat, cylinder(0.18, 0.25, 2.2), BRONZE, Vector3(-2.3, 2.4, 0), Vector3(0, 0, 0.6))
		"colom":
			# el Monument a Colom: columna de 60 m (a escala reducida para que quepa en pantalla)
			part(root, box(Vector3(9, 6, 9)), STONE, Vector3(0, 3, 0))
			part(root, cylinder(1.6, 2.0, 30.0), Color("8a8070"), Vector3(0, 21, 0))
			part(root, cylinder(2.4, 2.4, 2.0), BRONZE, Vector3(0, 37, 0))
			part(root, sphere(1.4), BRONZE, Vector3(0, 39, 0))
			part(root, cylinder(0.6, 0.9, 3.0), BRONZE, Vector3(0, 41.5, 0))
			part(root, sphere(0.6), BRONZE, Vector3(0, 43.5, 0))
			part(root, cylinder(0.15, 0.15, 2.5), BRONZE, Vector3(0.9, 43.5, 0.0), Vector3(0, 0, -1.2))


static func label(parent: Node3D, l: Dictionary) -> void:
	var lb := Label3D.new()
	lb.text = l["text"]
	# el rótulo viene a la altura real del edificio; se ajusta a la escala caricaturizada
	lb.position = Vector3(l["x"], l["y"] * BuildingMesher.LANDMARK_HEIGHT_SCALE + 2.0, l["z"])
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.font_size = 72
	lb.pixel_size = 0.03
	lb.outline_size = 18
	lb.modulate = Color("fff4d8")
	lb.outline_modulate = Color(0.1, 0.07, 0.05)
	lb.no_depth_test = true
	lb.render_priority = 2
	lb.outline_render_priority = 1
	parent.add_child(lb)


## Placa de calle de mármol como las de Barcelona, pegada a la fachada.
static func street_sign(parent: Node3D, s: Dictionary) -> void:
	var text: String = s["name"]
	var normal := Vector3(s["nx"], 0, s["nz"])
	var root := Node3D.new()
	root.position = Vector3(s["x"], SIGN_HEIGHT, s["z"])
	root.basis = Basis.looking_at(-normal)  # +Z local hacia la calle
	parent.add_child(root)
	var width := 0.6 + text.length() * 0.24
	part(root, box(Vector3(width + 0.16, 1.0, 0.06)), Color("2c3a5a"), Vector3(0, 0, 0.02))
	part(root, box(Vector3(width, 0.86, 0.08)), Color("f2efe6"), Vector3(0, 0, 0.04))
	var lb := Label3D.new()
	lb.text = text
	lb.font_size = 56
	lb.pixel_size = 0.0085
	lb.modulate = Color("1d2a48")
	lb.outline_size = 0
	lb.position = Vector3(0, 0, 0.09)
	root.add_child(lb)


## Rótulo de un comercio real (McDonald's, farmacias, bares...) sobre la puerta,
## con los colores de la marca y toldo en bares y restaurantes.
static func storefront(parent: Node3D, s: Dictionary) -> void:
	var text: String = s["t"]
	var width: float = s["w"]
	var bg := Color(s["bg"])
	var root := Node3D.new()
	root.position = Vector3(s["x"], SHOP_SIGN_HEIGHT, s["z"])
	root.basis = Basis.looking_at(-Vector3(s["nx"], 0, s["nz"]))  # +Z local hacia la calle
	parent.add_child(root)
	var board := part(root, box(Vector3(width, 0.85, 0.14)), bg, Vector3(0, 0, 0.07))
	board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if s.get("a", 0):
		var awning := part(root, box(Vector3(width, 0.06, 1.3)), bg.darkened(0.2), Vector3(0, -0.8, 0.6), Vector3(0.4, 0, 0))
		awning.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lb := Label3D.new()
	lb.text = text
	lb.font_size = 64
	# que el texto quepa en el cartel: ~0.6 em de ancho medio por letra
	lb.pixel_size = minf(0.011, (width - 0.3) / (text.length() * 64 * 0.6))
	lb.modulate = Color(s["fg"])
	lb.outline_size = 0
	lb.position = Vector3(0, 0, 0.15)
	root.add_child(lb)


static func trees(parent: Node3D, list: Array) -> void:
	if list.is_empty():
		return
	var trunk := MultiMesh.new()
	trunk.transform_format = MultiMesh.TRANSFORM_3D
	trunk.mesh = cylinder(0.22, 0.3, 4.0, 6)
	trunk.instance_count = list.size()
	var crown := MultiMesh.new()
	crown.transform_format = MultiMesh.TRANSFORM_3D
	crown.use_colors = true
	crown.mesh = sphere(2.2)
	crown.instance_count = list.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in list.size():
		var t: Array = list[i]
		var s := rng.randf_range(0.8, 1.25)
		var pos := Vector3(t[0], 0, t[1])
		trunk.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * s), pos + Vector3(0, 2.0 * s, 0)))
		crown.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(1, 0.85, 1) * s), pos + Vector3(0, 5.0 * s, 0)))
		crown.set_instance_color(i, Color.from_hsv(rng.randf_range(0.22, 0.32), 0.55, rng.randf_range(0.42, 0.6)))
	var a := MultiMeshInstance3D.new()
	a.multimesh = trunk
	a.material_override = mat(Color("6a4a30"))
	parent.add_child(a)
	var b := MultiMeshInstance3D.new()
	b.multimesh = crown
	b.material_override = foliage_material
	parent.add_child(b)
