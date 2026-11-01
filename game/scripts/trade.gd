class_name Trade
extends RefCounted
## Trapicheo: revender a otros lo que compras al camello y cambiar cosas con otros yonkis.
##
## Las despedidas pagan el doble por farlopa o porros; los guiris, un dineral por un porro (pero
## alguno es secreta); los yonkis, poco y solo por lo barato. Los clientes se acuerdan de ti
## (Npc.remember("cliente")): pagan algo más cada vez y se te acercan cuando te ven. Cortar la
## mercancía da más de media, pero el cliente lo nota (Npc.remember("timado")): las despedidas
## van a por ti, los demás no te vuelven a comprar. Vender a la vista de un agente o de un
## camello (le pisas el terreno) se paga. Los yonkis llevan algo encima y te lo cambian por
## objetos de la calle, que valoran más que el compraventa.
## El equilibrio está en Defs.CLIENTS y las constantes que lo siguen.

const G := preload("res://scripts/game_state.gd")

const MAX_SWAPS := 3  ## cambios que ofrece un yonki a la vez (los objetos que más valen)

var world: World


func _init(p_world: World) -> void:
	world = p_world


## Lo que puedes trapichear con `npc` (para su menú).
func offers_for(npc: Npc) -> Array:
	var acts := []
	if npc.remembers("timado") > 0:
		if Defs.CLIENTS.has(npc.kind):
			npc.say("A ti no te compro nada más. Aquello era yeso")
		return acts
	acts.append_array(_sales(npc))
	if npc.kind == "yonki":
		acts.append_array(_swaps(npc))
	return acts


# -------------------------------------------------------------------- vender

## Lo que paga `npc` ahora por una dosis de `id` (más si ya te compró antes).
func price_for(npc: Npc, id: String) -> int:
	var c: Dictionary = Defs.CLIENTS[npc.kind]
	var regular := mini(npc.remembers("cliente"), Defs.REGULAR_MAX)
	var base: float = Defs.SUBSTANCES[id]["price"] * c["markup"]
	return maxi(1, roundi(base * (1.0 + Defs.REGULAR_BONUS * regular)))


## Si este guiri es en realidad un secreta (siempre igual para el mismo nombre).
func undercover(npc: Npc) -> bool:
	return npc.kind == "turista" and npc._trait("secreta") < Defs.UNDERCOVER_CHANCE


func _sales(npc: Npc) -> Array:
	var acts := []
	if not Defs.CLIENTS.has(npc.kind):
		return acts
	var gs := GameState
	for id in Defs.CLIENTS[npc.kind]["wants"]:
		if not gs.has_item(id):
			continue
		var price := price_for(npc, id)
		if npc.money < price:
			continue
		var what: String = Defs.item_name(id).to_lower()
		acts.append(Interactions._act("Venderle %s (%d €)" % [what, price], func(): sell(npc, id, false)))
		acts.append(Interactions._act("Venderle %s cortada (%d €)" % [what, price], func(): sell(npc, id, true)))
	return acts


## Le vendes una dosis de `id` a `npc`; `cut` = cortada (gastas menos, pero se da cuenta).
func sell(npc: Npc, id: String, cut: bool) -> void:
	var gs := GameState
	gs.advance(5)
	if undercover(npc):
		gs.remove_item(id)
		npc.say("Policía. Las manos donde las vea.", 4.0)
		gs.log_msg("El guiri de las chanclas saca una placa. Era un secreta.", G.C_BAD)
		gs.milestone("secreta")
		world.arrest_player()
		return
	var price := price_for(npc, id)
	npc.money -= price
	gs.add_money(price)
	if cut and randf() < Defs.CUT_KEEPS:
		gs.log_msg("Le pasas media dosis con yeso por %d €. Te queda la otra media." % price, G.C_GOOD)
	else:
		gs.remove_item(id)
		gs.log_msg("Le pasas %s por %d €." % [Defs.item_name(id).to_lower(), price], G.C_GOOD)
	if cut:
		npc.remember("timado")
		gs.milestone("cortar")
	else:
		npc.remember("cliente")
		npc.say(["Gracias, bro", "Thanks, man!", "Si tienes más, ya sabes"].pick_random())
	gs.milestone("camello")
	gs.change_dignity(-2, "Pasar papelas")
	_after_deal(npc)


## Quién te ha visto vender: un agente va a por ti, un vecino o un guiri llaman la atención
## y un camello cercano se lo toma como que le pisas la esquina.
func _after_deal(client: Npc) -> void:
	var gs := GameState
	var seen := world.watching([], client)
	if seen.any(func(n): return n.kind == "policia"):
		gs.heat = minf(100.0, gs.heat + 60.0)
		gs.log_msg("Un agente te ha visto pasar algo.", G.C_BAD)
	elif seen.any(func(n): return n.kind in World.WITNESS_KINDS):
		gs.heat = minf(100.0, gs.heat + 10.0)
	for npc in seen:
		if npc.kind == "camello" and npc.distance_to_cell(world.player.cell) <= Defs.TURF_CELLS and npc.mode == "":
			npc.remember("pisado")
			npc.react("territorio")
			gs.log_msg("%s te ha visto vender en su esquina." % npc.display_name, G.C_BAD)
			break


# ------------------------------------------------------------------- trueque

## Lo que lleva encima un yonki hoy: {"id", "n"}. Siempre la misma sustancia para el mismo
## nombre; se repone cada día.
func stash(npc: Npc) -> Dictionary:
	var s: Dictionary = npc.get_meta("trapi", {})
	if s.get("day", -1) != GameState.day:
		var ids: Array = Defs.YONKI_STASH
		s = {"id": ids[int(npc._trait("alijo") * ids.size())], "n": randi_range(1, 2), "day": GameState.day}
		npc.set_meta("trapi", s)
	return s


## Dosis de lo suyo que te da un yonki por tu `item` (0 si no le interesa).
func swap_doses(npc: Npc, item: String) -> int:
	var s := stash(npc)
	var value: float = Defs.ITEMS.get(item, {}).get("sell", 0) * Defs.YONKI_ITEM_VALUE
	var price: float = Defs.SUBSTANCES[s["id"]]["price"]
	if value < price * 0.8:
		return 0
	return clampi(floori(value / price), 1, s["n"])


func _swaps(npc: Npc) -> Array:
	var acts := []
	var s := stash(npc)
	if s["n"] <= 0:
		return acts
	var items: Array = GameState.inventory.keys().filter(func(id): return swap_doses(npc, id) > 0)
	items.sort_custom(func(a, b): return Defs.ITEMS[a]["sell"] > Defs.ITEMS[b]["sell"])
	for item in items.slice(0, MAX_SWAPS):
		var n := swap_doses(npc, item)
		acts.append(Interactions._act("Cambiarle tu %s por %s" % [Defs.item_name(item).to_lower(), _doses(s["id"], n)],
			func(): swap(npc, item)))
	return acts


func _doses(id: String, n: int) -> String:
	var name: String = Defs.item_name(id).to_lower()
	return name if n == 1 else "%d de %s" % [n, name]


## Le das `item` a un yonki a cambio de lo que lleva encima.
func swap(npc: Npc, item: String) -> void:
	var gs := GameState
	gs.advance(5)
	var s := stash(npc)
	if world.street_items.take_fake(item, "«¿Me tomas por tonto?» Lo que le ofreces es %s."):
		npc.remember("timado")
		npc.say("Lárgate antes de que te abra la cabeza", 3.0)
		return
	var n := swap_doses(npc, item)
	gs.remove_item(item)
	gs.add_item(s["id"], n)
	s["n"] -= n
	npc.remember("cliente")
	npc.say(["Trato hecho, primo", "Esto lo coloco yo en un pispás", "Vale, vale"].pick_random())
	gs.log_msg("Le das tu %s y te pasa %s." % [Defs.item_name(item).to_lower(), _doses(s["id"], n)], G.C_GOOD)
