class_name Vinculos
extends RefCounted
## Amistades y enemistades entre los bots (docs/ideas.md, «Amistades y enemistades entre los
## NPC»). Hasta ahora cada bot solo recordaba lo que le hacías tú (Npc.memory); aquí se conocen
## entre ellos: se hacen enemigos al pelearse, al robarse o darse el tirón, y amigos al pasarse
## una dosis cuando el otro está fatal. Lo que le hacen a uno lo saben sus amigos
## (Defs.VINCULO_SE_CUENTA). Cada uno recuerda como mucho Defs.VINCULOS_MAX y se va olvidando.
##
## Va en el registro del censo de cada uno («vinculos»: {uid del otro: valor de -100 a 100} y
## «vinculos_t», cuándo se puso al día), así que se guarda en la partida y se duerme y se
## despierta con él. Al cruzarse por la calle (tick), los enemigos discuten (y a veces llegan a
## las manos) y los amigos se saludan.
##
## También mira tu fama (Fama): con buena fama en la zona, alguien te avisa si viene la policía.

const G := preload("res://scripts/game_state.gd")

var world: World
var _timer := 0.0
var _aviso := -INF  ## (segundos de reloj) último aviso de la policía


func _init(p_world: World) -> void:
	world = p_world


# ------------------------------------------------------------------- lo que piensa cada uno

## Lo que piensa el del registro `a` del del registro `b` (-100..100; 0 si no le conoce).
static func valor(a: Dictionary, b: Dictionary) -> float:
	_olvidar(a)
	return float(a.get("vinculos", {}).get(b.get("uid", -1), 0.0))


## Cambia lo que piensa `a` de `b` en `delta` (y `b` de `a`, si `mutuo`). Si es malo, los amigos
## de `a` (el agredido) también se lo apuntan a `b`, a medias.
static func cambiar(censo, a: Dictionary, b: Dictionary, delta: float, mutuo := true, se_cuenta := true) -> void:
	if a.is_empty() or b.is_empty() or is_same(a, b):
		return
	_apuntar(censo, a, b, delta)
	if mutuo:
		_apuntar(censo, b, a, delta)
	if delta < 0.0 and se_cuenta:
		for uid in amigos(a):
			var f: Dictionary = censo.por_uid(uid)
			if not f.is_empty() and not is_same(f, b):
				_apuntar(censo, f, b, delta * Defs.VINCULO_SE_CUENTA)


static func _apuntar(censo, a: Dictionary, b: Dictionary, delta: float) -> void:
	_olvidar(a)
	var v: Dictionary = a.get("vinculos", {})
	var uid: int = censo.uid(b)
	v[uid] = clampf(v.get(uid, 0.0) + delta, -100.0, 100.0)
	# como mucho VINCULOS_MAX: se queda con los que más pesan
	if v.size() > Defs.VINCULOS_MAX:
		var keys := v.keys()
		keys.sort_custom(func(x, y): return absf(v[x]) > absf(v[y]))
		for k in keys.slice(Defs.VINCULOS_MAX):
			v.erase(k)
	a["vinculos"] = v


## Con los días se va olvidando (Defs.VINCULO_OLVIDO por día).
static func _olvidar(a: Dictionary) -> void:
	var v: Dictionary = a.get("vinculos", {})
	var t: float = a.get("vinculos_t", GameState.now())
	var dias := (GameState.now() - t) / 1440.0
	a["vinculos_t"] = GameState.now()
	if dias <= 0.0 or v.is_empty():
		return
	for k in v.keys():
		var x: float = v[k]
		x = move_toward(x, 0.0, Defs.VINCULO_OLVIDO * dias)
		if absf(x) < 3.0:
			v.erase(k)
		else:
			v[k] = x


static func amigos(a: Dictionary) -> Array:
	_olvidar(a)
	var v: Dictionary = a.get("vinculos", {})
	return v.keys().filter(func(k): return v[k] >= Defs.VINCULO_AMIGO)


static func enemigos(a: Dictionary) -> Array:
	_olvidar(a)
	var v: Dictionary = a.get("vinculos", {})
	return v.keys().filter(func(k): return v[k] <= Defs.VINCULO_ENEMIGO)


# ------------------------------------------------------------------- lo que pasa entre ellos

## `a` y `b` (bots con cuerpo) se pelean: quedan enemigos.
func pelea(a: Npc, b: Npc) -> void:
	cambiar(world.censo, a.reg, b.reg, Defs.VINCULO_PELEA)
	b.walk_to(a.cell)
	a.say(["¡Me has robado la base!", "¡Esa esquina es mía!", "¡Devuélveme el mechero!"].pick_random(), 4.0)
	b.say("¡Ven aquí si tienes huevos!", 4.0)
	if a.distance_to_cell(world.player.cell) < 40:
		GameState.log_msg("Pelea entre %s y %s cerca de %s." % [a.display_name, b.display_name, world.city.street_name_near(a.cell)])


## `ladron` le roba a `victima` (lo nota): la víctima no se lo perdona.
func robo(ladron: Npc, victima: Npc, cuanto: int, tiron := false) -> void:
	cambiar(world.censo, victima.reg, ladron.reg, Defs.VINCULO_TIRON if tiron else Defs.VINCULO_ROBO, false)
	victima.money = maxi(0, victima.money - cuanto)
	ladron.money += cuanto
	if tiron:
		ladron.say("Lo siento, tío... lo necesito.", 3.0)
		victima.say("¡Eh! ¡Mi dinero! ¡Te voy a encontrar!", 3.0)
		if ladron.distance_to_cell(world.player.cell) < 30:
			GameState.log_msg("%s le da el tirón a %s y sale corriendo." % [ladron.display_name, victima.display_name])


## `de` le pasa una dosis de lo suyo a `para`, que tenía mono: amigos.
func dosis(de: Npc, para: Npc) -> void:
	de.consumo["dosis"] -= 1
	Consumo.meterse(para.consumo, true)
	cambiar(world.censo, para.reg, de.reg, Defs.VINCULO_DOSIS)
	de.say("Toma, que se te ve fatal.", 3.0)
	para.say("Te debo una, tío.", 3.0)


## Un suceso entre bots, de vez en cuando (World._random_event): un yonki con mono le da el
## tirón a otro o alguien le pasa una dosis. false si no ha pasado nada.
func suceso() -> bool:
	var con_mono := world.npcs.filter(func(n): return is_instance_valid(n) and n.mode == "" and Consumo.necesita(n.consumo))
	con_mono.shuffle()
	for n in con_mono.slice(0, 5):
		var cerca := world.npcs.filter(func(o): return o != n and is_instance_valid(o) and o.mode == "" and o.amo == null 			and not o.is_police() and o.distance_to_cell(n.cell) < 12)
		# alguien que lleva lo suyo se lo pasa (sobre todo si son amigos)
		for o in cerca:
			if not o.consumo.is_empty() and o.consumo["id"] == n.consumo["id"] and o.consumo["dosis"] > 0:
				if valor(o.reg, n.reg) >= 0.0 and randf() < 0.6:
					dosis(o, n)
					return true
		# sin dinero, a tope de mono y de la calle: el tirón al que lleve algo
		if n.money <= 0 and n.consumo["mono"] >= Defs.NPC_ROB_AT and n.kind in Defs.NEVER_INTERVENE:
			for o in cerca:
				if o.money > 0:
					robo(n, o, mini(o.money, Defs.NPC_TIRON_MAX), true)
					return true
	return false


# ------------------------------------------------------------------- al cruzarse

## Cada poco (desde World): los que se conocen y se cruzan reaccionan, y con buena fama alguien
## te avisa de que viene la policía.
func tick(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 1.0
	_aviso_policia()
	var ahora := Time.get_ticks_msec() / 1000.0
	for n in world.npcs:
		if not is_instance_valid(n) or n.mode != "" or n.amo != null or ahora < n.get_meta("cruce", -INF):
			continue
		var r: Dictionary = n.reg
		if r.get("vinculos", {}).is_empty():
			continue
		for o in world.npcs:
			if o == n or not is_instance_valid(o) or o.mode != "" or n.distance_to_cell(o.cell) > Defs.VINCULO_CRUCE:
				continue
			var v := valor(r, o.reg)
			if v == 0.0:
				continue
			n.set_meta("cruce", ahora + Defs.VINCULO_CRUCE_PAUSA)
			o.set_meta("cruce", ahora + Defs.VINCULO_CRUCE_PAUSA)
			if v <= Defs.VINCULO_ENEMIGO:
				n.say(["¡Tú! ¿Todavía tienes cara de venir por aquí?", "Mira quién está aquí...", "Lárgate de mi calle."].pick_random(), 3.0)
				o.say(["¿Qué pasa? ¿Eh? ¿Qué pasa?", "Ni me mires.", "Ven tú si te atreves."].pick_random(), 3.0)
				if randf() < Defs.VINCULO_BRONCA:
					pelea(n, o)
			elif v >= Defs.VINCULO_AMIGO:
				n.say("¡Eh, %s!" % o.display_name, 2.5)
				o.say(["¿Qué pasa, tío?", "¡Hombre! ¿Cómo va?", "¡Ey!"].pick_random(), 2.5)
				o.walk_to(world.city.random_walkable_near(n.cell, 1))
			break


## Con buena fama en tu zona, si te buscan y hay un agente cerca, alguien de la calle te avisa.
func _aviso_policia() -> void:
	var gs := GameState
	var me: Vector2i = world.player.cell
	var ahora := Time.get_ticks_msec() / 1000.0
	if ahora - _aviso < Defs.FAMA_AVISO_PAUSA or Fama.de(me, "buena") < Defs.FAMA_AVISA:
		return
	if not gs.is_wanted() and gs.heat < Defs.CHASE_HEAT * 0.75:
		return
	var poli: Npc = null
	for n in world.npcs:
		if n.looks_police() and n.distance_to_cell(me) < 30:
			poli = n
			break
	if poli == null:
		return
	for n in world.npcs:
		if n.is_police() or n.kind in ["perro", "nino"] or n.amo != null or n.distance_to_cell(me) > 10:
			continue
		_aviso = ahora
		n.say("¡Eh! ¡Que viene la pasma, por %s!" % world.city.street_name_near(poli.cell), 4.0)
		gs.log_msg("%s te avisa: viene la policía por %s. Tienes buena fama por aquí." % [n.display_name, world.city.street_name_near(poli.cell)], G.C_GOOD)
		return
