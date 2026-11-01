extends SceneTree
## Captura de todos los personajes en fila, de cerca: los 6 perfiles del jugador y un bot de
## cada nombre de Npc.KINDS. Para revisar género y rasgos sin buscarlos por el barrio.
## Uso: godot --path game --resolution 1600x900 --script res://tests/retratos.gd -- <salida.png> [tipo de bot]
## Sin tipo, saca los perfiles; con tipo (o "todos"), los nombres de ese tipo.
## (La escena está en retratos_escena.gd: se carga al arrancar porque los personajes usan
## los autoloads, que aún no existen cuando se compila este script.)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://retratos.png"
	var which := args[1] if args.size() > 1 else ""
	var stage: Node3D = load("res://tests/retratos_escena.gd").new()
	root.add_child(stage)
	stage.build(which)
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
