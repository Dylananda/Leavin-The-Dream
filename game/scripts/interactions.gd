class_name Interactions
extends RefCounted
## Acciones disponibles con cada bot y en cada lugar del barrio.
## Cada acción es {"label": String, "do": Callable}; el menú las muestra tal cual.

const G := preload("res://scripts/game_state.gd")

var world: World


func _init(p_world: World) -> void:
	world = p_world


static func _act(label: String, fn: Callable) -> Dictionary:
	return {"label": label, "do": fn}


func _chance(p: float) -> bool:
	return randf() < clampf(p, 0.02, 0.95)


func _beg_bonus() -> float:
	return 0.25 if GameState.profile.get("id") == "jubilado" else 0.0


## Sube la búsqueda policial (al jubilado le cuesta más parecer sospechoso).
func _heat(amount: float) -> void:
	if GameState.profile.get("id") == "jubilado":
		amount *= 0.5
	GameState.heat = minf(100.0, GameState.heat + amount)


# --------------------------------------------------------------------- bots

func for_npc(npc: Npc) -> Array:
	match npc.kind:
		"turista": return _turista(npc)
		"camello": return _camello(npc)
		"policia": return _policia(npc)
		"yonki": return _yonki(npc)
		"educador": return _educador(npc)
		"vecino": return _vecino(npc)
		"mantero": return _mantero(npc)
	return []


func _turista(npc: Npc) -> Array:
	var gs := GameState
	var acts := [
		_act("Pedirle una moneda", func():
			gs.advance(10)
			if not npc.robbed and _chance(0.35 + _beg_bonus()):
				var n := randi_range(1, 5)
				gs.add_money(n)
				npc.say("Here... take it")
				gs.log_msg("El guiri te da %d €." % n, G.C_GOOD)
			else:
				npc.say("No, sorry, no cash")
			gs.change_dignity(-2, "Pedir a un guiri")),
		_act("Contarle tu drama", func():
			gs.advance(20)
			npc.say("Oh my god...")
			if _chance(0.25 + _beg_bonus()):
				var n := randi_range(8, 20)
				gs.add_money(n)
				gs.log_msg("Le das tanta pena que te suelta %d €." % n, G.C_GOOD)
			gs.change_dignity(-4, "Llorarle a un desconocido")),
	]
	if not npc.robbed:
		acts.append(_act("Robarle la cartera", func(): _rob_tourist(npc)))
	return acts


func _rob_tourist(npc: Npc) -> void:
	var gs := GameState
	gs.advance(5)
	var p := 0.6 - 0.12 * world.police_near(npc.cell, 20) + (0.1 if gs.is_night() else 0.0)
	if gs.high > 60.0:
		p -= 0.15
	if _chance(p):
		npc.robbed = true
		if _chance(0.4):
			gs.add_item("movil")
			gs.log_msg("Le sacas el móvil del bolsillo sin que se entere.", G.C_GOOD)
		else:
			gs.add_item("cartera")
			gs.log_msg("¡Cartera! Ábrela en el inventario.", G.C_GOOD)
		_heat(20)
		gs.milestone("primer_robo")
		gs.change_dignity(-3)
	else:
		npc.say("THIEF! ¡Al ladrón!", 4.0)
		npc.robbed = true
		_heat(70)
		gs.log_msg("Te ha pillado. Ahora la policía te busca.", G.C_BAD)
		gs.change_dignity(-2)


func _camello(npc: Npc) -> Array:
	var gs := GameState
	var acts := []
	if npc.debt > 0:
		npc.say("Primero me pagas lo que me debes")
		if gs.money > 0:
			acts.append(_act("Pagarle la deuda (%d €)" % npc.debt, func():
				var paid := mini(gs.money, npc.debt)
				gs.add_money(-paid)
				npc.debt -= paid
				gs.debt = maxi(0, gs.debt - paid)
				gs.log_msg("Le pagas %d €. Debes %d €." % [paid, npc.debt])))
		acts.append(_act("Hacerle de aguador (2 h) para saldar", func():
			gs.advance(120)
			npc.debt = maxi(0, npc.debt - 15)
			gs.debt = maxi(0, gs.debt - 15)
			_heat(15)
			gs.log_msg("Dos horas vigilando la esquina. Te descuenta 15 €.")
			gs.change_dignity(-2)))
		return acts
	for id in Defs.DEALER_STOCK:
		var s: Dictionary = Defs.SUBSTANCES[id]
		var price: int = s["price"]
		if gs.money >= price:
			acts.append(_act("Comprar %s (%d €)" % [s["name"], price], func():
				gs.add_money(-price)
				gs.add_item(id)
				npc.say("Va, rápido")
				gs.log_msg("Compras: %s." % s["name"])))
		elif price <= 15:
			acts.append(_act("Pedirle fiado: %s" % s["name"], func():
				if _chance(0.4):
					gs.add_item(id)
					npc.debt += price
					gs.debt += price
					npc.say("Mañana me lo pagas. Sé dónde duermes")
					gs.milestone("deuda")
				else:
					npc.say("Sin pasta no hay fiesta")
				gs.change_dignity(-2)))
	acts.append(_act("Hacerle de aguador (2 h)", func():
		gs.advance(120)
		_heat(15)
		if _chance(0.15):
			_heat(60)
			gs.log_msg("¡Redada! Sales corriendo con la policía detrás.", G.C_BAD)
		else:
			gs.add_money(15)
			gs.add_item("porro")
			gs.log_msg("Te paga 15 € y un porro por vigilar.", G.C_GOOD)
		gs.change_dignity(-2)))
	return acts


func _policia(npc: Npc) -> Array:
	var gs := GameState
	return [
		_act("Pedirle ayuda", func():
			gs.advance(5)
			npc.say("Pásate por el Baluard, hombre")
			gs.change_dignity(-1)),
		_act("Chivarte de un camello", func():
			npc.say("Gracias por la información")
			gs.heat = 0.0
			world.remove_random_npc("camello")
			gs.change_dignity(-10, "Chivato")
			gs.milestone("chivato")),
		_act("Insultarle", func():
			npc.say("¿Perdona? Las manos donde las vea")
			gs.change_dignity(-3)
			world.arrest_player()),
	]


func _yonki(npc: Npc) -> Array:
	var gs := GameState
	var acts := [
		_act("Pedirle algo", func():
			gs.advance(5)
			if _chance(0.2):
				gs.add_item("sobras")
				npc.say("Toma, que hoy estoy generoso")
			else:
				npc.say("Ni pa' mí, primo")
			gs.change_dignity(-2, "Pedirle a otro yonki")),
		_act("Pelearte con él", func(): _fight(npc)),
	]
	var mine := gs.inventory.keys().filter(func(id): return Defs.SUBSTANCES.has(id))
	if not mine.is_empty():
		var id: String = mine[0]
		acts.insert(0, _act("Compartir tu %s" % Defs.item_name(id).to_lower(), func():
			gs.remove_item(id)
			npc.say("Eres un hermano, tío")
			npc.set_meta("colega", true)
			gs.change_dignity(2, "Compartir es vivir")
			if _chance(0.4):
				gs.add_money(randi_range(2, 8))
				gs.log_msg("Te devuelve el favor con unas monedas.", G.C_GOOD)))
	if gs.money >= 8:
		acts.append(_act("Comprarle un móvil robado (8 €)", func():
			gs.add_money(-8)
			gs.add_item("movil" if _chance(0.5) else "movil_roto")
			npc.say("Está como nuevo")))
	return acts


func _fight(npc: Npc) -> void:
	var gs := GameState
	gs.advance(10)
	_heat(30)
	var me := gs.health + gs.high * 0.3 - gs.mono * 0.3 + randf_range(-20, 20)
	var him := randf_range(30.0, 70.0)
	if me > him:
		var loot := npc.money + randi_range(0, 5)
		npc.money = 0
		gs.add_money(loot)
		npc.say("¡Vale, vale, ya está!")
		gs.change_health(-randf_range(3, 10), "Una pelea de más")
		gs.log_msg("Ganas la pelea y le quitas %d €." % loot, G.C_GOOD)
		gs.change_dignity(-3)
	else:
		var lost := int(gs.money * 0.3)
		gs.add_money(-lost)
		npc.say("¡Toma ya!")
		gs.change_health(-20, "Te mató a palos un yonki")
		gs.log_msg("Te revienta y te quita %d €." % lost, G.C_BAD)
		gs.change_dignity(-6)
		gs.milestone("pelea_perdida")


func _educador(npc: Npc) -> Array:
	var gs := GameState
	var acts := [
		_act("Hablar un rato", func():
			gs.advance(30)
			npc.say("Cuídate, ¿vale?")
			gs.ease_mono(5.0)
			gs.change_sanity(5)
			gs.change_dignity(4, "Alguien te trata como a una persona")),
		_act("Preguntar dónde dan metadona", func():
			var cas := world.city.pois_of_kind("cas")
			if cas.is_empty():
				npc.say("Ve al CAP")
			else:
				var c: Dictionary = cas[0]
				npc.say("En el Baluard, cerca de %s" % world.city.street_name_near(Vector2i(c["x"], c["y"])), 5.0)
				world.highlight_poi(c)),
	]
	if npc.last_interaction_day != gs.day:
		acts.insert(0, _act("Pedirle un bocadillo", func():
			npc.last_interaction_day = gs.day
			gs.add_item("bocadillo")
			npc.say("Toma, de chorizo")
			gs.change_dignity(-1)))
	return acts


func _vecino(npc: Npc) -> Array:
	var gs := GameState
	return [
		_act("Pedirle una moneda", func():
			gs.advance(5)
			if _chance(0.1 + _beg_bonus()):
				gs.add_money(1)
				npc.say("Toma, y vete")
			else:
				npc.say(["¡Búscate un trabajo!", "¡Que llamo a la policía!", "Ay, pobre..."].pick_random())
			gs.change_dignity(-3, "Que te miren así")),
		_act("Pedirle el móvil «para llamar a tu madre»", func():
			gs.advance(5)
			if _chance(0.15):
				gs.add_item("movil")
				_heat(40)
				gs.log_msg("Sales corriendo con su móvil.", G.C_GOOD)
				gs.milestone("primer_robo")
				npc.say("¡Mi móvil! ¡Policía!", 4.0)
			else:
				_heat(25)
				npc.say("¡Ni se te ocurra!", 3.0)
			gs.change_dignity(-3)),
	]


func _mantero(npc: Npc) -> Array:
	var gs := GameState
	var acts := [
		_act("Hacerle de vigía (2 h)", func():
			gs.advance(120)
			var pay := 20 if gs.profile.get("id") == "sin_papeles" else 8
			gs.add_money(pay)
			_heat(10)
			npc.say("Gracias, hermano")
			gs.log_msg("Vigilas por si viene la policía. Te da %d €." % pay, G.C_GOOD)),
	]
	if gs.money >= 5:
		acts.append(_act("Comprarle unas gafas (5 €)", func():
			gs.add_money(-5)
			gs.add_item("gafas")
			npc.say("Ray-Ban, original")))
	return acts


# ------------------------------------------------------------------- lugares

const POI_LABELS := {
	"super": "Súper", "farmacia": "Farmacia", "bar": "Bar", "kebab": "Kebab",
	"cajero": "Cajero", "iglesia": "Iglesia", "banco": "Banco de la calle",
	"albergue": "Servicio social", "cap": "Centro de salud", "cas": "CAS Baluard",
	"comisaria": "Comisaría", "compraventa": "Compraventa",
}


func for_poi(poi: Dictionary) -> Array:
	var gs := GameState
	var acts := []
	match poi["kind"]:
		"super":
			acts.append(_buy("Comprar una litrona", 2, "litrona"))
			acts.append(_buy("Comprar un bocadillo", 3, "bocadillo"))
			acts.append(_act("Robar una litrona", func():
				if _chance(0.6 - 0.1 * world.police_near(world.player.cell, 16)):
					gs.add_item("litrona")
					gs.log_msg("Litrona bajo el abrigo. Nadie ha visto nada.", G.C_GOOD)
					gs.milestone("primer_robo")
				else:
					_heat(40)
					gs.log_msg("El de seguridad te pilla y te echa a empujones.", G.C_BAD)
				gs.change_dignity(-2)))
		"farmacia":
			if gs.can_get_meds():
				acts.append(_act("Recoger tu medicación", func():
					gs.got_meds()
					gs.add_item("pastillas", 3)
					gs.log_msg("La farmacéutica te da tus pastillas. Tú sabrás lo que haces con ellas.")))
			acts.append(_act("Pedir un kit de reducción de daños", func():
				gs.advance(10)
				gs.change_health(3)
				gs.log_msg("Agua, gasas y un folleto. Algo es algo.")))
			acts.append(_buy_effect("Comprar ibuprofeno", 3, func(): gs.change_health(5)))
		"bar":
			acts.append(_buy_effect("Tomarte un carajillo", 2, func():
				gs.add_item("litrona")
				gs.consume("litrona")))
			acts.append(_act("Pedir por las mesas de la terraza", func():
				gs.advance(15)
				if _chance(0.3 + _beg_bonus()):
					var n := randi_range(1, 4)
					gs.add_money(n)
					gs.log_msg("Sacas %d € entre las mesas." % n, G.C_GOOD)
				else:
					gs.log_msg("El camarero te echa con un trapo.")
				gs.change_dignity(-3, "Mendigar en una terraza")))
			acts.append(_act("Robar la propina del platito", func():
				if _chance(0.5):
					var n := randi_range(2, 6)
					gs.add_money(n)
					gs.log_msg("%d € de propina ajena." % n, G.C_GOOD)
					gs.milestone("primer_robo")
				else:
					_heat(40)
					gs.log_msg("«¡Eh, tú!» Sales por patas.", G.C_BAD)
				gs.change_dignity(-2)))
		"kebab":
			acts.append(_buy_effect("Comerte un dürüm", 4, func():
				gs.add_item("durum")
				gs.consume("durum")))
			acts.append(_act("Pedir las sobras", func():
				gs.add_item("sobras")
				gs.consume("sobras")))
		"cajero":
			if gs.bank > 0:
				acts.append(_act("Sacar dinero (%d €)" % gs.bank, func():
					gs.add_money(gs.bank)
					gs.log_msg("Sacas %d €." % gs.bank, G.C_GOOD)
					gs.bank = 0))
			acts.append(_act("Dormir en el cajero (7 h)", func():
				world.sleep(7 * 60, 0.15, 25.0, 0.7)
				gs.change_dignity(-6, "Dormir entre recibos")
				gs.milestone("cajero")))
		"iglesia":
			acts.append(_act("Pedir en la puerta", func():
				gs.advance(30)
				var p := 0.5 + _beg_bonus() + (0.2 if gs.hour() < 13 else 0.0)
				if _chance(p):
					var n := randi_range(1, 6)
					gs.add_money(n)
					gs.log_msg("Una señora te da %d € y un «que Dios te ayude»." % n, G.C_GOOD)
				gs.change_dignity(-2, "Pedir en la iglesia")))
		"banco":
			acts.append(_act("Dormir en el banco (6 h)", func():
				world.sleep(6 * 60, 0.3, 15.0, 0.6)
				gs.change_dignity(-4, "Dormir al raso")
				gs.milestone("primera_calle")))
		"albergue":
			if gs.hour() >= 19 or gs.hour() < 1:
				acts.append(_act("Pasar la noche en el albergue", func():
					var until_morning := (24 - gs.hour() + 8) % 24 * 60.0
					gs.eat(40.0)
					gs.log_msg("Cena caliente: lentejas y pan.", G.C_GOOD)
					world.sleep(until_morning, 0.0, 35.0, 1.0)
					gs.change_dignity(2, "Una cama de verdad")))
			else:
				acts.append(_act("Preguntar por una cama", func():
					gs.log_msg("Las camas se reparten a partir de las 19:00.")))
			acts.append(_act("Ducharte", func():
				gs.advance(30)
				gs.change_dignity(3, "Agua caliente")))
		"cap":
			acts.append(_act("Ir a urgencias (4 h)", func():
				gs.advance(240)
				gs.change_health(25)
				gs.log_msg("Cuatro horas en la sala de espera, pero te curan.", G.C_GOOD)))
		"cas":
			if gs.can_get_methadone():
				acts.append(_act("Tomar tu dosis de metadona", func():
					gs.got_methadone()
					gs.add_item("metadona")
					gs.consume("metadona")
					gs.log_msg("El mono se calma. Por hoy.", G.C_GOOD)))
			for id in gs.inventory.keys():
				if Defs.SUBSTANCES.has(id):
					acts.append(_act("Consumir %s en la sala supervisada" % Defs.item_name(id).to_lower(), func():
						gs.consume(id, true)))
			acts.append(_act("Café y ducha", func():
				gs.advance(40)
				gs.eat(10.0)
				gs.ease_mono(5.0)
				gs.change_health(5)
				gs.change_dignity(2)))
		"comisaria":
			acts.append(_act("Entregarte", func():
				gs.change_dignity(-2)
				world.arrest_player()))
			acts.append(_act("Denunciar que te han robado", func():
				gs.advance(60)
				gs.log_msg("Te miran de arriba abajo y te hacen esperar una hora para nada.")
				gs.change_dignity(-1)))
		"compraventa":
			for id in gs.inventory.keys():
				var item: Dictionary = Defs.ITEMS.get(id, {})
				if item.get("sell", 0) > 0:
					acts.append(_act("Vender %s (%d €)" % [item["name"].to_lower(), item["sell"]], func():
						gs.remove_item(id)
						gs.add_money(item["sell"])
						gs.log_msg("Vendido: %s." % item["name"], G.C_GOOD)
						if id == "anillo":
							gs.change_dignity(-10, "Adiós, matrimonio")
							gs.milestone("anillo")))
			if acts.is_empty():
				acts.append(_act("Mirar el escaparate", func():
					gs.log_msg("No tienes nada que valga algo. Ni tú.")))
	return acts


func _buy(label: String, price: int, item: String) -> Dictionary:
	return _buy_effect(label, price, func(): GameState.add_item(item))


func _buy_effect(label: String, price: int, effect: Callable) -> Dictionary:
	var gs := GameState
	return _act("%s (%d €)" % [label, price], func():
		if gs.money < price:
			gs.log_msg("No te llega.", G.C_BAD)
			return
		gs.add_money(-price)
		effect.call())
