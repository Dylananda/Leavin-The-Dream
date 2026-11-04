extends SceneTree
## Compara el muñeco de ahora con el prototipo con más detalle (scripts/actors/cuerpo.gd):
## la misma gente arriba (de ahora) y abajo (nuevo), de cerca y con la cámara del juego, y un
## catálogo de los peinados nuevos. Imprime los triángulos de cada uno.
## Uso: godot --path game --resolution 1600x900 --script res://tests/muneco_v2.gd -- <salida.png>

const STEP := 1.9
const ACCESORIOS := ["gorra_poli", "capucha", "mochila", "chaleco", "despedida", "gorra", "cresta",
	"bolsa", "guitarra", "skate", "rosas", "paraguas", "reparto", "carro"]
const FILA_Z := 8.0  ## las dos filas, separadas para sacar cada una en su captura


func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://muneco.png"
	var escena := Node3D.new()
	root.add_child(escena)
	var looks: Array = []
	for p in Defs.PROFILES:
		looks.append([p["name"], p["look"], ""])
	# (Npc, cargado a mano: --script compila antes de que exista el autoload que usa)
	var NpcS = load("res://scripts/actors/npc.gd")
	for kind in ["vecino", "turista", "punki", "yonki", "fiestero"]:
		for n in NpcS.KINDS[kind]["names"].slice(0, 2):
			var npc = NpcS.new()
			npc.init_kind(kind, n)
			looks.append([n, npc.look.duplicate(true), npc.accessory])
			npc.free()
	looks = looks.slice(0, 10)
	var tris := [0, 0]
	var gente := [[], []]
	var grupos := [Node3D.new(), Node3D.new(), Node3D.new(), Node3D.new()]  ## ahora, nuevo, peinados y accesorios
	for g in grupos:
		escena.add_child(g)
	for fila in 2:
		Actor.cuerpo_nuevo = fila == 1
		for i in looks.size():
			var a := Actor.new()
			a.look = looks[i][1]
			a.accessory = looks[i][2]
			a.process_mode = Node.PROCESS_MODE_DISABLED
			a.position = Vector3((i - (looks.size() - 1) / 2.0) * STEP, 0, -fila * FILA_Z)
			grupos[fila].add_child(a)
			_rotulo(grupos[fila], looks[i][0], a.position + Vector3(0, 0.15, 1.0))
			gente[fila].append(a)
		# se montan al primer frame (en _ready): antes de cambiar de cuerpo
		await process_frame
		for a in gente[fila]:
			tris[fila] += _tris(a)
	print("MUÑECO: triángulos por persona: ahora %d, nuevo %d" % [tris[0] / looks.size(), tris[1] / looks.size()])
	# catálogo de peinados del nuevo
	Actor.cuerpo_nuevo = true
	var x := 0
	for g in ["m", "f"]:
		for estilo in Cuerpo.PEINADOS[g]:
			var a := Actor.new()
			var base: Dictionary = Defs.PROFILES[0 if g == "m" else 1]["look"].duplicate(true)
			base["gender"] = g
			base["hair_style"] = estilo
			base["facial"] = ""
			base["hair"] = [Color("3a2418"), Color("c89a50"), Color("1a1414"), Color("8a4a2a"), Color("d0d0d0")][x % 5]
			a.look = base
			a.process_mode = Node.PROCESS_MODE_DISABLED
			a.position = Vector3((x - 6.5) * STEP * 0.8, 0, 12)
			a.rotation_degrees.y = 35.0
			grupos[2].add_child(a)
			_rotulo(grupos[2], estilo, a.position + Vector3(0, 0.15, 1.0))
			x += 1
	# catálogo de accesorios: arriba el de ahora y abajo el nuevo
	for fila in 2:
		Actor.cuerpo_nuevo = fila == 1
		for i in ACCESORIOS.size():
			var a := Actor.new()
			a.look = Defs.PROFILES[i % 3]["look"].duplicate(true)
			a.accessory = ACCESORIOS[i]
			a.process_mode = Node.PROCESS_MODE_DISABLED
			a.position = Vector3((i - (ACCESORIOS.size() - 1) / 2.0) * STEP, 0, 20 + fila * 4.0)
			a.rotation_degrees.y = 25.0
			grupos[3].add_child(a)
			if fila == 1:
				_rotulo(grupos[3], ACCESORIOS[i], a.position + Vector3(0, 0.15, 1.6))
		await process_frame
	_luz(escena)
	var suelo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	suelo.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("c8b8a0")
	suelo.material_override = mat
	escena.add_child(suelo)
	var cam := Camera3D.new()
	escena.add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.current = true
	# 1) de cerca: cada fila (ahora y nuevo); 2) las caras de los cuatro primeros
	for fila in 2:
		for k in 4:
			grupos[k].visible = k == fila
		var sufijo := "_ahora" if fila == 0 else "_nuevo"
		cam.size = looks.size() * STEP + 0.4
		cam.rotation_degrees = Vector3(-12, 0, 0)
		cam.position = Vector3(0, 1.5, -fila * FILA_Z) + cam.transform.basis.z * 40.0
		await _captura(out.replace(".png", sufijo + ".png"))
		cam.size = 4 * STEP
		cam.rotation_degrees = Vector3(-8, 0, 0)
		cam.position = Vector3(-(looks.size() - 1) / 2.0 * STEP + 1.5 * STEP, 1.7, -fila * FILA_Z) + cam.transform.basis.z * 40.0
		await _captura(out.replace(".png", "_caras" + sufijo + ".png"))
	# 3) peinados
	for k in 4:
		grupos[k].visible = k == 2
	cam.size = 14 * STEP * 0.8 + 0.4
	cam.rotation_degrees = Vector3(-15, 0, 0)
	cam.position = Vector3(-0.4, 2.4, 12) + cam.transform.basis.z * 40.0
	await _captura(out.replace(".png", "_peinados.png"))
	for k in 4:
		grupos[k].visible = k == 3
	cam.size = ACCESORIOS.size() * STEP + 0.4
	cam.rotation_degrees = Vector3(-25, 0, 0)
	cam.position = Vector3(0, 1.4, 22) + cam.transform.basis.z * 40.0
	await _captura(out.replace(".png", "_accesorios.png"))
	# 4) con la cámara del juego: las dos filas
	for k in 4:
		grupos[k].visible = k < 2
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = 34.0
	cam.rotation_degrees = Vector3(-40, 45, 0)
	cam.position = Vector3(0, 0, -FILA_Z / 2.0) + cam.transform.basis.z * 60.0
	await _captura(out.replace(".png", "_juego.png"))
	quit()


func _captura(path: String) -> void:
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)


func _tris(n: Node) -> int:
	var t := 0
	for m in n.find_children("*", "MeshInstance3D", true, false):
		if m.mesh and not m.get_parent() is Label3D:
			for s in m.mesh.get_surface_count():
				var idx = m.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX]
				t += idx.size() / 3 if idx != null else 0
	return t


func _rotulo(escena: Node3D, texto: String, pos: Vector3) -> void:
	var tag := Label3D.new()
	tag.text = texto
	tag.font_size = 30
	tag.pixel_size = 0.007
	tag.outline_size = 8
	tag.position = pos
	escena.add_child(tag)


func _luz(escena: Node3D) -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-45), deg_to_rad(-30), 0)
	sun.shadow_enabled = true
	escena.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.78, 0.74, 0.66)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	escena.add_child(env)
