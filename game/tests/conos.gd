extends SceneTree
## Captura de los conos de visión: pone a dos agentes y a un camello al que debes cerca del
## jugador, enciende todos los conos (tecla V), monta un escándalo y guarda la imagen.
## Uso: godot --path game --resolution 1600x900 --script res://tests/conos.gd -- <salida.png> [hora]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://conos.png"
	var gs = root.get_node("GameState")
	gs.new_game("parado")
	change_scene_to_file("res://scenes/world.tscn")
	await process_frame
	await process_frame
	var w = current_scene
	if args.size() > 1:
		gs.minute_of_day = float(args[1]) * 60.0
	# el jugador en un cruce con calles a la vista
	var p: Vector2i = w.player.cell
	for i in 400:
		var c: Vector2i = w.city.random_walkable()
		var open := 0
		for d in [Vector2i(6, 0), Vector2i(-6, 0), Vector2i(0, 6), Vector2i(0, -6)]:
			if w.city.line_of_sight(c, c + d) and w.city.is_walkable(c + d):
				open += 1
		if open >= 3:
			p = c
			break
	w.player.setup(w.city, p)
	w._camera_focus = w.player.position
	var cops: Array = w.npcs.filter(func(n): return n.kind == "urbano")
	for i in mini(2, cops.size()):
		cops[i].setup(w.city, w.city.random_walkable_near(p, 10))
	w._spawn_npc("camello")
	var dealer = w.npcs[-1]
	dealer.setup(w.city, w.city.random_walkable_near(p, 8))
	dealer.add_debt(20, 0.0)
	w._all_cones = true
	for i in 30:
		await process_frame
	w._spawn_npc("turista")
	var victim = w.npcs[-1]
	victim.setup(w.city, w.city.random_walkable_near(p, 3))
	w.scandal(victim, "THIEF! ¡Al ladrón!")
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
