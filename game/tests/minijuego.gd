extends SceneTree
## Captura de un minijuego a medias, sin jugarlo: para revisar la vista y el dibujo.
## Uso: godot --path game --resolution 1600x900 --script res://tests/minijuego.gd -- <salida.png> <robo|movil|vigia|aguador|pelea> [hora] [sustancias]
## En el robo, la mano que distrae se pone a un lado y la otra en el bolsillo; en el vigía
## pasan unos segundos de gente.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://minijuego.png"
	var which := args[1] if args.size() > 1 else "robo"
	var hour := float(args[2]) if args.size() > 2 else 12.0
	var take := args[3].split(",", false) if args.size() > 3 else PackedStringArray()
	var gs = root.get_node("GameState")
	gs.new_game("parado")
	change_scene_to_file("res://scenes/world.tscn")
	await process_frame
	await process_frame
	gs.minute_of_day = hour * 60.0
	for id in take:
		gs.add_item(id)
		gs.consume(id, true)
	var world = current_scene
	var kind: String = {"robo": "turista", "movil": "fiestero", "vigia": "mantero", "aguador": "camello", "pelea": "yonki"}[which]
	var npc = null
	for n in world.npcs:
		if n.kind == kind:
			npc = n
	if npc == null:
		world._spawn_npc(kind)
		npc = world.npcs[-1]
	for i in 10:
		await process_frame
	var game
	if which in ["robo", "movil"]:
		game = load("res://scripts/minigames/pickpocket.gd").new(npc, "cartera" if which == "robo" else "movil")
	elif which == "pelea":
		game = load("res://scripts/minigames/fight.gd").new(npc)
	else:
		game = load("res://scripts/minigames/lookout.gd").new(npc)
	world.play_minigame(game, 0.5, func(result, stats): print("resultado: ", result, " ", stats))
	await process_frame
	if which in ["robo", "movil"]:
		game._hand_l = Vector2(160, 170)
		game._interest = 1.0
		for i in 60:
			game.test_mouse = game._pocket() + Vector2(4, 6)
			await process_frame
	elif which == "pelea":
		for i in 200:
			await process_frame
			if game._state == "carga":
				break
	else:
		game.test_mouse = Vector2(600, 260)
		for i in 240:
			await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
