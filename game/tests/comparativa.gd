extends SceneTree
## Compara los personajes de ahora con modelos descargados (game/_comparativa/*.glb, no se
## suben): en fila, a la misma altura, andando si tienen animación. Saca una captura de cerca
## y otra con la cámara del juego (ortográfica, inclinada como World.CAMERA_PITCH) e imprime
## triángulos, vértices, texturas y lo que ocupa cada uno.
## Uso: godot --path game --resolution 1600x900 --script res://tests/comparativa.gd -- <salida.png> [solo_glb|cabezas]
## «cabezas»: algunos modelos dos veces, tal cual y con la cabeza y las manos más grandes
## (tests/cabeza_grande.gd), para ver cómo se leen desde la cámara del juego.

const DIR := "res://_comparativa/"
const STEP := 2.6
const POR_FILA := 5
const FILA := 4.5  ## metros entre filas (hacia atrás)
## Los que salen mal (woman_b: el esqueleto deforma parte de la malla).
const FUERA := ["woman_b"]


func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://comparativa.png"
	var escena := Node3D.new()
	root.add_child(escena)
	var gente: Array = []
	# los de ahora: dos perfiles
	var perfiles := [] if "solo_glb" in OS.get_cmdline_user_args() else [Defs.PROFILES[0], Defs.PROFILES[2]]
	for p in perfiles:
		var a := Actor.new()
		a.look = p["look"]
		a.process_mode = Node.PROCESS_MODE_DISABLED
		gente.append({"nombre": "Ahora (" + p["name"] + ")", "nodo": a, "archivo": ""})
	if "cabezas" in OS.get_cmdline_user_args():
		gente = gente.slice(0, 1)
		for f in ["grandpa", "casual", "punk", "woman_a", "business"]:
			var ps: PackedScene = load(DIR + f + ".glb")
			gente.append({"nombre": f, "nodo": ps.instantiate(), "archivo": DIR + f + ".glb"})
			if f != "grandpa":
				var grande := ps.instantiate()
				for sk in grande.find_children("*", "Skeleton3D", true, false):
					var mod := SkeletonModifier3D.new()
					mod.set_script(load("res://tests/cabeza_grande.gd"))
					sk.add_child(mod)
				gente.append({"nombre": f + " (cabeza +35 %)", "nodo": grande, "archivo": DIR + f + ".glb"})
	else:
		var dir := DirAccess.open(DIR)
		for f in dir.get_files():
			if f.ends_with(".glb") and not f.get_basename() in FUERA:
				var ps: PackedScene = load(DIR + f)
				if ps:
					gente.append({"nombre": f.get_basename(), "nodo": ps.instantiate(), "archivo": DIR + f})
	var alto := 0.0
	for i in gente.size():
		var g: Dictionary = gente[i]
		var n: Node3D = g["nodo"]
		escena.add_child(n)
		n.position = Vector3((i % POR_FILA - (POR_FILA - 1) / 2.0) * STEP, 0, -(i / POR_FILA) * FILA)
	await process_frame
	await process_frame
	# altura de referencia: la de los de ahora
	for g in gente:
		g["aabb"] = _aabb(g["nodo"])
	alto = gente[0]["aabb"].size.y if perfiles.size() > 0 else 2.96
	print("COMPARATIVA (altura de referencia %.2f m)" % alto)
	for g in gente:
		var n: Node3D = g["nodo"]
		if g["archivo"] != "":
			var s: float = alto / maxf(g["aabb"].size.y, 0.01)
			n.scale = Vector3.ONE * s
			n.position.y -= g["aabb"].position.y * s
		var st := _stats(n)
		for m in n.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = m.get_aabb()
			if b.size.length() > 6.0 / maxf(n.scale.x, 0.001):
				print("    (malla grande en %s: %s %s)" % [g["nombre"], m.name, b.size])
		var anim := _andar(n)
		var kb := FileAccess.get_file_as_bytes(g["archivo"]).size() / 1024 if g["archivo"] != "" else 0
		print("  %-22s %6d triángulos %6d vértices  %d mallas  %d huesos  texturas: %s  archivo: %d KB  animaciones: %d (%s)" % [
			g["nombre"], st["tris"], st["verts"], st["mallas"], st["huesos"], st["texturas"], kb, anim[0], anim[1]])
		var tag := Label3D.new()
		tag.text = g["nombre"]
		tag.font_size = 36
		tag.pixel_size = 0.008
		tag.outline_size = 10
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.position = Vector3(n.position.x, 0.2, n.position.z + 1.0)
		escena.add_child(tag)
	_luz(escena)
	var suelo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(STEP * POR_FILA + 6, 16)
	suelo.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("c8b8a0")
	suelo.material_override = mat
	escena.add_child(suelo)
	var cam := Camera3D.new()
	escena.add_child(cam)
	# de cerca, casi de frente
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = POR_FILA * STEP + 0.6
	cam.rotation_degrees = Vector3(-22, 0, 0)
	cam.position = Vector3(0, alto * 0.75, -FILA * 0.5) + cam.transform.basis.z * 40.0
	cam.current = true
	for i in 40:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	# con la cámara del juego: ortográfica a 34 m de ancho, inclinada 40º y girada 45º
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = 34.0  # el zoom de partida del juego (World._camera_zoom), en alto
	cam.rotation_degrees = Vector3(-40, 45, 0)
	cam.position = Vector3(0, 0, 0) + cam.transform.basis.z * 60.0
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_juego.png"))
	quit()


func _aabb(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for m in n.find_children("*", "VisualInstance3D", true, false) + ([n] if n is VisualInstance3D else []):
		if not m is GeometryInstance3D or m is Label3D:
			continue
		var b: AABB = m.global_transform * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _stats(n: Node) -> Dictionary:
	var tris := 0
	var verts := 0
	var mallas := 0
	var huesos := 0
	var tex := {}
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = m.mesh
		if mesh == null:
			continue
		mallas += 1
		for s in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx = arr[Mesh.ARRAY_INDEX]
			verts += v.size()
			tris += (idx.size() if idx != null and idx.size() > 0 else v.size()) / 3
			var mat = m.get_active_material(s)
			if mat is BaseMaterial3D and mat.albedo_texture:
				var t: Texture2D = mat.albedo_texture
				tex["%dx%d" % [t.get_width(), t.get_height()]] = true
	for sk in n.find_children("*", "Skeleton3D", true, false):
		huesos += sk.get_bone_count()
	return {"tris": tris, "verts": verts, "mallas": mallas, "huesos": huesos,
		"texturas": ", ".join(tex.keys()) if not tex.is_empty() else "ninguna (colores)"}


## Pone a andar el modelo si tiene una animación de andar (o la primera que tenga).
func _andar(n: Node) -> Array:
	var aps := n.find_children("*", "AnimationPlayer", true, false)
	if aps.is_empty():
		return [0, "-"]
	var ap: AnimationPlayer = aps[0]
	var lista := ap.get_animation_list()
	var elegida := ""
	for a in lista:
		if "walk" in a.to_lower():
			elegida = a
			break
	if elegida == "" and lista.size() > 0:
		elegida = lista[0]
	if elegida != "":
		ap.get_animation(elegida).loop_mode = Animation.LOOP_LINEAR
		ap.play(elegida)
		ap.seek(0.3, true)
	return [lista.size(), elegida]


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
