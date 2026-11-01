extends Node3D
## Escena de tests/retratos.gd: personajes en fila sobre un suelo liso, con su nombre encima.

const STEP := 2.4  ## metros entre personajes
const ROW_H := 4.2  ## metros entre filas


func build(which: String) -> void:
	var people: Array[Actor] = []
	if which == "":
		for p in Defs.PROFILES:
			var a := Actor.new()
			a.display_name = p["name"]
			a.look = p["look"]
			people.append(a)
	else:
		for kind in Npc.KINDS:
			if which != "todos" and kind != which:
				continue
			for n in Npc.KINDS[kind]["names"]:
				var npc := Npc.new()
				npc.init_kind(kind, n)
				people.append(npc)
	# en filas apiladas como en una estantería, vistos casi de frente
	var cols := mini(people.size(), 10)
	var rows := ceili(people.size() / float(cols))
	for i in people.size():
		var a := people[i]
		a.position = Vector3((i % cols - (cols - 1) / 2.0) * STEP, -(i / cols) * ROW_H, 0)
		a.process_mode = Node.PROCESS_MODE_DISABLED  # quietos, sin pasear
		add_child(a)
		var tag := Label3D.new()
		tag.text = "%s
%s" % [a.display_name, (a as Npc).label().get_slice("(", 1).trim_suffix(")") if a is Npc else "jugador"]
		tag.font_size = 40
		tag.pixel_size = 0.008
		tag.outline_size = 10
		tag.position = a.position + Vector3(0, -0.35, 0.6)
		add_child(tag)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-40), deg_to_rad(-25), 0)
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.78, 0.74, 0.66)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	add_child(env)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(cols * STEP * 0.6, rows * ROW_H + 1.0)
	var center := Vector3(0, 1.4 - (rows - 1) * ROW_H / 2.0, 0)
	add_child(cam)
	cam.look_at_from_position(center + Vector3(0, 4, 14), center, Vector3.UP)
