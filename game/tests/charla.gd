extends SceneTree
## Conversación real con la IA (necesita Ollama en marcha), sin abrir el juego: crea un bot
## del tipo pedido, le dice cada frase y muestra lo que contesta y las acciones que salen.
## Uso: godot --headless --path game --script res://tests/charla.gd -- latero "Hola" "¿Viene la Urbana?"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var kind: String = args[0] if not args.is_empty() else "latero"
	var lines: Array = Array(args.slice(1)) if args.size() > 1 else ["Hola, amigo. ¿Qué tal la noche?"]
	var gs = root.get_node("GameState")
	gs.new_game("parado")
	change_scene_to_file("res://scenes/world.tscn")
	await process_frame
	await process_frame
	var world = current_scene
	world._spawn_npc(kind)
	var npc = world.npcs[-1]
	# a una hora en la que los de ese tipo andan por la calle (si no, se retiran a media charla;
	# sin nombrar la clase Npc: --script la compilaría antes de que exista el autoload)
	var hours: Array = npc.KINDS[kind].get("hours", [22, 5])
	gs.minute_of_day = (hours[0] + 1) % 24 * 60.0
	npc.money = 30
	var conv = world.conversation
	print("== %s · %s" % [npc.label(), conv.client.describe()])
	gs.message.connect(func(text: String, _c: Color): print("   [registro] ", text))
	for line in lines:
		print("Tú: ", line)
		var reply := []
		var on_reply := func(_n, text, deals, ended): reply.append([text, deals, ended])
		var on_fail := func(_n, error): reply.append(["(error: %s)" % error, [], true])
		conv.replied.connect(on_reply)
		conv.failed.connect(on_fail)
		var t0 := Time.get_ticks_msec()
		conv.say(npc, line)
		while reply.is_empty():
			await process_frame
		conv.replied.disconnect(on_reply)
		conv.failed.disconnect(on_fail)
		print("%s (%.1f s): %s" % [npc.display_name, (Time.get_ticks_msec() - t0) / 1000.0, reply[0][0]])
		for offer in reply[0][1]:
			print("   [ofrece] ", offer["label"])
		if reply[0][2]:
			break
	quit()
