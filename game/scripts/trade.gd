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
## objetos de la calle, que valoran más que el compraventa. Quien tiene mono de lo suyo
## (Consumo) te lo compra aunque no sea cliente, y paga más cuanto peor está; o se lo puedes dar.
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
		if Defs.CLIENTS.has(client_kind(npc)):
			npc.say("A ti no te compro nada más. Aquello era yeso")
		return acts
	# con mala fama en la zona, quien no te conoce no te compra (Fama)
	if npc.memory.is_empty() and Fama.de(npc.cell, "mala") >= Defs.FAMA_NO_VENDE:
		return acts
	acts.append_array(_sales(npc))
	acts.append_array(_gift(npc))
	acts.append_array(_purchases(npc))
	if npc.kind == "yonki" or not _own_stash(npc).is_empty():
		acts.append_array(_swaps(npc))
	return acts


# -------------------------------------------------------------------- vender

## Qué cliente es `npc` en Defs.CLIENTS: los de paisano compran como lo que parecen.
func client_kind(npc: Npc) -> String:
	return "turista" if npc.kind == "urbano_secreta" else npc.kind


## Lo que compra `npc`: lo que quiere si es un personaje del editor (Personajes), si no lo de
## su tipo en Defs.CLIENTS.
func wants(npc: Npc) -> Array:
	var q: Array = npc.personaje.get("stats", {}).get("quiere", [])
	if q.is_empty():
		q = Defs.CLIENTS.get(client_kind(npc), {}).get("wants", [])
	var c := npc.consumo
	if not c.is_empty() and c["dosis"] <= 0 and c["mono"] >= Defs.NPC_USE_AT and not c["id"] in q:
		q = q + [c["id"]]  # con mono, lo suyo se lo compra a quien sea
	return q


## Lo que paga `npc` ahora por una dosis de `id` (más si ya te compró antes). Los personajes
## de un tipo que no es cliente pagan como un yonki.
func price_for(npc: Npc, id: String) -> int:
	var c: Dictionary = Defs.CLIENTS.get(client_kind(npc), Defs.CLIENTS["yonki"])
	var regular := mini(npc.remembers("cliente"), Defs.REGULAR_MAX)
	var base: float = GameState.precio(id) * c["markup"] * Consumo.ansia(npc.consumo, id)
	return maxi(1, roundi(base * (1.0 + Defs.REGULAR_BONUS * regular)))


## Si este cliente es en realidad un secreta: los agentes de paisano, y algún guiri que lo es
## sin estar en la calle como tal (siempre igual para el mismo nombre).
func undercover(npc: Npc) -> bool:
	return npc.is_police() or (npc.kind == "turista" and npc._trait("secreta") < Defs.UNDERCOVER_CHANCE)


func _sales(npc: Npc) -> Array:
	var acts := []
	var gs := GameState
	for id in wants(npc):
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
		npc.known = true
		if npc.kind == "mosso_secreta":
			npc.say("Mossos d'Esquadra. Las manos donde las vea.", 4.0)
			gs.log_msg("El vecino que preguntaba si tenías algo saca una placa de los Mossos.", G.C_BAD)
		else:
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
	if not npc.consumo.is_empty() and npc.consumo["id"] == id:
		Consumo.meterse(npc.consumo, true)  # se la mete en cuanto puede
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
	if seen.any(func(n): return n.is_police()):
		gs.heat = minf(100.0, gs.heat + 60.0)
		gs.mark_wanted("un agente te ha visto pasar algo", "drogas")
	elif seen.any(func(n): return n.kind in World.WITNESS_KINDS):
		gs.heat = minf(100.0, gs.heat + 10.0)
	for npc in seen:
		if npc.kind == "camello" and npc.distance_to_cell(world.player.cell) <= Defs.TURF_CELLS and npc.mode == "":
			npc.remember("pisado")
			npc.react("territorio")
			gs.log_msg("%s te ha visto vender en su esquina." % npc.display_name, G.C_BAD)
			break


## Darle una dosis de lo suyo a quien tiene mono y nada encima (Consumo.necesita).
func _gift(npc: Npc) -> Array:
	var c := npc.consumo
	if not Consumo.necesita(c) or not GameState.has_item(c["id"]):
		return []
	var what: String = Defs.item_name(c["id"]).to_lower()
	return [Interactions._act("Darle %s (tiene mono)" % what, func(): give(npc))]


func give(npc: Npc) -> void:
	var gs := GameState
	var c := npc.consumo
	gs.advance(5)
	gs.remove_item(c["id"])
	Consumo.meterse(c, true)
	npc.remember("ayudado")
	npc.say(["Gracias, tío. Te debo una.", "Me has salvado el día.", "No se me olvida, ¿eh?"].pick_random(), 3.0)
	gs.log_msg("Le das %s a %s, que estaba fatal." % [Defs.item_name(c["id"]).to_lower(), npc.display_name])
	gs.change_dignity(1, "Compartir con quien tiene mono")


# ------------------------------------------------------------------- trueque

## Lo que lleva encima un yonki hoy: {"id", "n"}. Siempre la misma sustancia para el mismo
## nombre; se repone cada día.
## Los personajes del editor llevan lo que pone su ficha («Lo que lleva»).
func stash(npc: Npc) -> Dictionary:
	var s: Dictionary = npc.get_meta("trapi", {})
	if s.get("day", -1) != GameState.day:
		var own := _own_stash(npc)
		if not own.is_empty():
			s = {"id": own["id"], "n": own["n"], "day": GameState.day}
		else:
			var ids: Array = Defs.YONKI_STASH
			s = {"id": ids[int(npc._trait("alijo") * ids.size())], "n": randi_range(1, 2), "day": GameState.day}
		npc.set_meta("trapi", s)
	return s


## La primera sustancia que lleva un personaje del editor: {"id", "n"}, o {} si ninguna.
func _own_stash(npc: Npc) -> Dictionary:
	var lleva: Dictionary = npc.personaje.get("stats", {}).get("lleva", {})
	for id in lleva:
		if Defs.SUBSTANCES.has(id) and int(lleva[id]) > 0:
			return {"id": id, "n": int(lleva[id])}
	return {}


# -------------------------------------------------------------------- comprar

## Lo que te vende un personaje del editor («Lo vende a»): de lo que lleva, hasta que se le
## acabe (se repone cada día); si no lo lleva apuntado, no se le acaba.
func _purchases(npc: Npc) -> Array:
	var acts := []
	var vende: Dictionary = npc.personaje.get("stats", {}).get("vende", {})
	for id in vende:
		var price := int(vende[id])
		if price <= 0 or GameState.money < price or _left(npc, id) == 0:
			continue
		acts.append(Interactions._act("Comprarle %s (%d €)" % [Defs.item_name(id).to_lower(), price], func(): buy(npc, id)))
	return acts


## Unidades de `id` que le quedan hoy a `npc` para venderte (-1: no se le acaban).
func _left(npc: Npc, id: String) -> int:
	var lleva: Dictionary = npc.personaje.get("stats", {}).get("lleva", {})
	if not lleva.has(id):
		return -1
	var sold: Dictionary = npc.get_meta("vendido", {})
	if sold.get("day", -1) != GameState.day:
		sold = {"day": GameState.day}
		npc.set_meta("vendido", sold)
	return maxi(0, int(lleva[id]) - sold.get(id, 0))


## Le compras una unidad de `id` a `npc` al precio de su ficha.
func buy(npc: Npc, id: String) -> void:
	var gs := GameState
	var price := int(npc.personaje["stats"]["vende"][id])
	gs.advance(5)
	gs.add_money(-price)
	npc.money += price
	gs.add_item(id)
	if _left(npc, id) > 0:
		var sold: Dictionary = npc.get_meta("vendido")
		sold[id] = sold.get(id, 0) + 1
	npc.say(["Toma, y no me has visto", "Aquí tienes", "Lo mejor del barrio"].pick_random())
	gs.log_msg("Le compras %s a %s por %d €." % [Defs.item_name(id).to_lower(), npc.display_name, price], G.C_GOOD)
	if Defs.SUBSTANCES.has(id):
		_after_deal(npc)


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
