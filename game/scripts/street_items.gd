class_name StreetItems
extends RefCounted
## Objetos tirados por la calle con los que trapichear: móviles perdidos a la salida de los
## bares, carteras, cable de las obras, chatarra, bicis y patinetes mal atados... y mucha basura.
##
## Se ven poco (son pequeños y apenas destellan) y, cuanto más ido vas (GameState.befuddlement()),
## más fácil es confundirlos: la basura te parece un móvil y te la guardas (en el inventario sale
## como un móvil, pero es una piedra: GameState.fakes), o un móvil te parece basura y pasas de
## largo. Las piedras se descubren al intentar venderlas o usarlas, o al volver a estar sereno.
## El equilibrio está en Defs.STREET_ITEMS y las constantes que lo siguen.

const G := preload("res://scripts/game_state.gd")

const REFRESH_MINUTES := 2.0  ## cada cuánto (minutos de juego) se revisa lo que ves y lo que queda
const PICK_RADIUS_PX := 22.0
const VISIBLE_CELLS := 40  ## más lejos no se distingue (ni se puede señalar) un objeto en el suelo

var world: World
var items: Array[StreetItem] = []
var _next_refresh := 0.0


func _init(p_world: World) -> void:
	world = p_world


## Llena el barrio de objetos al empezar.
func populate() -> void:
	for i in Defs.STREET_ITEMS_COUNT:
		_spawn(3)
	_refresh()


## Cada pocos minutos de juego: lo que ves (según lo ido que vas), lo que se llevan otros,
## lo que aparece y las piedras que descubres al volver a estar sereno.
func update() -> void:
	var now: float = GameState.now()
	if now < _next_refresh:
		return
	_next_refresh = now + REFRESH_MINUTES
	for item in items.duplicate():
		var old: bool = now - item.born > Defs.STREET_ITEM_HOURS * 60.0
		if old and world.player.distance_to_cell(item.cell) > VISIBLE_CELLS:
			_remove(item)
	while items.size() < Defs.STREET_ITEMS_COUNT:
		_spawn(Defs.STREET_SPAWN_AWAY)
	_refresh()
	if not GameState.fakes.is_empty() and GameState.befuddlement() < Defs.FAKE_REVEAL_BELOW:
		_reveal_all()


func _refresh() -> void:
	for item in items:
		item.show_as(perceived(item))


## Lo que te parece `item` ahora. Solo se confunden la basura y lo que tiene `fake` en Defs.
func perceived(item: StreetItem) -> String:
	var confused := item.roll < Defs.MISSEE_PER_BEFUDDLEMENT * GameState.befuddlement()
	if not confused:
		return item.id
	if item.id == "basura":
		return item.decoy
	if Defs.STREET_ITEMS[item.id].has("fake"):
		return "basura"
	return item.id


## Texto al pasar el ratón: lo que crees que hay.
func label(item: StreetItem) -> String:
	if item.seen_as == "basura":
		return "Basura"
	return "%s (en el suelo)" % Defs.item_name(item.seen_as)


## El objeto bajo el ratón (solo los que se distinguen desde donde estás).
func item_at(screen_pos: Vector2) -> StreetItem:
	var best: StreetItem = null
	var best_d := PICK_RADIUS_PX
	for item in items:
		if world.player.distance_to_cell(item.cell) > VISIBLE_CELLS:
			continue
		var p := item.global_position + Vector3(0, 0.2, 0)
		if world.camera.is_position_behind(p):
			continue
		var d := world.camera.unproject_position(p).distance_to(screen_pos)
		if d < best_d:
			best_d = d
			best = item
	return best


## Te llevas lo que hay (o lo que crees que hay).
func pick_up(item: StreetItem) -> void:
	var gs := GameState
	var seen := item.seen_as
	if item.id == "basura":
		if seen == "basura":
			gs.advance(2)
			gs.log_msg("Bolsas de basura y cartones. Nada que valga la pena.")
			return
		# la basura que te parecía otra cosa: te la guardas sin saberlo
		gs.advance(1)
		gs.add_item(seen)
		gs.fakes[seen] = gs.fakes.get(seen, 0) + 1
		gs.log_msg(Defs.STREET_ITEMS[seen]["found"], G.C_GOOD)
		_remove(item)
		return
	var d: Dictionary = Defs.STREET_ITEMS[item.id]
	gs.advance(d.get("minutes", 1))
	if seen == "basura":
		gs.log_msg("Ibas a pasar de largo, pero entre la basura hay algo...", G.C_GOOD)
	gs.log_msg(d["found"], G.C_GOOD)
	gs.add_item(item.id)
	if d.has("risk"):
		_risk(item, d["risk"])
	if item.id in ["bici", "patinete"]:
		gs.milestone("bici")
	_remove(item)


## Te ven llevándote algo que tiene dueño: quien te ve (con su cono, como en los demás robos)
## puede montar un escándalo; un agente, siempre. Los que viven de la calle miran a otro lado.
func _risk(item: StreetItem, risk: float) -> void:
	var seen := world.watching().filter(func(n): return n.kind not in Defs.NEVER_INTERVENE)
	if seen.is_empty():
		return
	var police := seen.filter(func(n): return n.is_police())
	if not police.is_empty():
		police[0].reveal()
		world.scandal(police[0], "¡Alto! ¡Deja eso donde estaba!")
	elif randf() < risk:
		world.scandal(seen[0], ["¡Eh! ¡Eso no es tuyo!", "¡Al ladrón! ¡Se lleva la bici!", "Hey! That's not yours!"].pick_random())
		GameState.change_dignity(-2, "Que te pillen robando una bici")
	else:
		seen[0].say("...", 2.0)
		GameState.heat = minf(100.0, GameState.heat + 10.0)


## Antes de vender o usar un `id`: si el que coges es uno de los falsos, lo descubres, lo
## pierdes y devuelve true. `how` es la frase, con %s para lo que era de verdad.
func take_fake(id: String, how: String) -> bool:
	var gs := GameState
	var n: int = gs.fakes.get(id, 0)
	if n <= 0 or randf() >= float(n) / maxf(1.0, gs.inventory.get(id, 0)):
		return false
	_drop_fakes(id, 1)
	gs.log_msg(how % Defs.STREET_ITEMS[id]["fake"], G.C_BAD)
	gs.change_dignity(-2, "Ir por ahí con basura en los bolsillos")
	return true


## Sereno, miras bien lo que llevas encima.
func _reveal_all() -> void:
	var gs := GameState
	for id in gs.fakes.keys():
		var n: int = gs.fakes[id]
		var what: String = Defs.item_name(id).to_lower()
		if n == 1:
			gs.log_msg("Miras bien lo que llevas: el «%s» que recogiste es %s. Lo tiras." % [what, Defs.STREET_ITEMS[id]["fake"]], G.C_BAD)
		else:
			gs.log_msg("Miras bien lo que llevas: %d de tus «%s» son %s. Los tiras." % [n, what, Defs.STREET_ITEMS[id]["fake"]], G.C_BAD)
		_drop_fakes(id, n)
	gs.change_sanity(-2, "No fiarte ni de tus ojos")


func _drop_fakes(id: String, n: int) -> void:
	var gs := GameState
	var left: int = gs.fakes.get(id, 0) - n
	if left <= 0:
		gs.fakes.erase(id)
	else:
		gs.fakes[id] = left
	gs.remove_item(id, n)


## Un objeto nuevo, a más de `away` casillas de ti. Lo más habitual es basura.
func _spawn(away: int) -> void:
	var id := _pick_id()
	var cell := Vector2i.ZERO
	for i in 20:
		var near: String = Defs.STREET_ITEMS.get(id, {}).get("near", "")
		var spots: Array = world.city.pois_of_kind(near) if near != "" else []
		if not spots.is_empty() and randf() < 0.7:
			var p: Dictionary = spots.pick_random()
			cell = world.city.random_walkable_near(Vector2i(p["x"], p["y"]), 6)
		else:
			cell = world.city.random_walkable()
		if world.player.distance_to_cell(cell) > away:
			break
	var item := StreetItem.new()
	item.roll = randf()
	if id == "basura":
		var decoys := Defs.STREET_ITEMS.keys().filter(func(k): return Defs.STREET_ITEMS[k].has("fake"))
		item.decoy = decoys.pick_random()
	item.born = GameState.now()
	item.setup(id, cell, world.city.cell_to_world(cell))
	world.city.entities.add_child(item)
	items.append(item)


func _pick_id() -> String:
	var night := GameState.is_night()
	var total := Defs.STREET_JUNK_WEIGHT
	var weights := {}
	for id in Defs.STREET_ITEMS:
		var d: Dictionary = Defs.STREET_ITEMS[id]
		var w: float = d["weight"] * (d.get("night", 1.0) if night else 1.0)
		weights[id] = w
		total += w
	var r := randf() * total
	for id in weights:
		r -= weights[id]
		if r < 0.0:
			return id
	return "basura"


func _remove(item: StreetItem) -> void:
	items.erase(item)
	item.queue_free()
