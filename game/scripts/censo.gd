class_name Censo
extends RefCounted
## Censo del barrio: todos los bots que existen, se vean o no. Cada uno es un registro de
## datos; solo los que andan cerca del jugador tienen cuerpo (un Npc en la escena, en
## World.npcs). Los demás están latentes: no se simulan, porque su casa, su rutina y la hora
## dicen dónde están; al acercarte se materializan donde les toca y se ponen al día de lo que
## ha pasado desde la última vez (ver _al_dia). Así puede haber miles de vecinos en el registro
## y solo se simula lo que tienes alrededor.
##
## No se duermen los que tienen asuntos contigo ahora mismo (anclado): te persiguen, te buscan
## o te han dado un encargo en marcha. A los que les debes dinero no hace falta tenerlos
## despiertos: cuando vence el plazo, vienen a buscarte estén donde estén (despertadores). Los que van detrás de otro (perros, el grupo del
## guía) no tienen registro propio: se duermen y se despiertan con su amo.
##
## Un registro: kind, name, personaje (ficha del editor o {}), home, bed, zona (casillas de su
## polígono), seguidores (tipos de los que le siguen), estado (lo que cambia del Npc, ver
## ESTADO), visto (GameState.now() al dormirse), pos/pos_t (dónde anda mientras está latente)
## y npc (su cuerpo, o null).

const CADA := 0.25  ## segundos reales entre repasos
const RADIO_ACTIVO := 66  ## casillas: los latentes que andan más cerca se materializan...
const RADIO_DORMIR := 80  ## ... y los que se alejan más se duermen (margen para que no parpadeen)
const RADIO_VISTA := 62  ## casillas que se ven alrededor del jugador con todo el zoom: nadie aparece ahí de golpe
const MAX_DESPERTAR := 3  ## cuerpos que se montan como mucho en cada repaso (unos 12 por segundo)
const SALTO := 20  ## casillas entre dos repasos a partir de las que el jugador no ha andado, ha saltado
const TANDA := 300  ## registros que se miran en cada repaso (el resto, en los siguientes)
const VAGA_DESDE := 40  ## a partir de este radio de paseo, mientras duerme se le cambia de sitio...
const VAGA_CADA := 30.0  ## ... cada tantos minutos de juego
## Campos del Npc que se guardan al dormirlo y se le devuelven al despertar.
const ESTADO := ["display_name", "gender", "look", "accessory", "body_size", "speed", "wander_radius",
	"money", "debt", "debt_due", "robbed", "known", "memory", "last_interaction_day"]

var world: World
var registros: Array[Dictionary] = []
var pausado := false  ## sin repasos automáticos (lo usa el test de humo)
var _timer := 0.0
var _cursor := 0  ## por dónde va el repaso por tandas
var _ultima := Vector2i(-9999, -9999)  ## casilla del jugador en el repaso anterior
var _alarmas := 0.0  ## segundos hasta mirar los despertadores


func _init(p_world: World) -> void:
	world = p_world


## Registro de un bot corriente nuevo del tipo `kind`, con su nombre, su casa y quién le sigue.
func nuevo(kind: String) -> Dictionary:
	var k: Dictionary = Npc.KINDS[kind]
	var zone: String = k.get("zone", "")
	var r := {"kind": kind, "name": Npc._pick_name(kind), "personaje": {},
		"home": world._zone_cell(zone) if zone != "" else world._default_home(kind),
		"bed": Vector2i(-1, -1), "zona": [], "seguidores": [], "estado": {}, "visto": GameState.now(), "npc": null}
	# algunos sacan al perro (Npc.DOG_OWNERS; por encima de 1, más de uno)
	var p_dog: float = Npc.DOG_OWNERS.get(kind, 0.0)
	while randf() < p_dog:
		r["seguidores"].append("perro")
		p_dog -= 1.0
	# el guía, con su grupo del free tour; las despedidas, en grupo
	if kind == "guia":
		for i in randi_range(Defs.GUIDE_GROUP.x, Defs.GUIDE_GROUP.y):
			r["seguidores"].append("turista")
	if kind == "fiestero":
		for i in randi_range(Defs.PARTY_GROUP.x, Defs.PARTY_GROUP.y):
			r["seguidores"].append("fiestero")
	# algunos vecinos y abuelos van con los niños
	if randf() < Defs.KIDS_WITH.get(kind, 0.0):
		for i in randi_range(Defs.KIDS_GROUP.x, Defs.KIDS_GROUP.y):
			r["seguidores"].append("nino")
	registros.append(r)
	return r


## Registro de un personaje del editor (ver Personajes).
func de_personaje(d: Dictionary) -> Dictionary:
	var r := {"kind": d["tipo"], "name": d["nombre"], "personaje": d, "home": Vector2i(-1, -1),
		"bed": Vector2i(-1, -1), "zona": [], "seguidores": [], "estado": {}, "visto": GameState.now(), "npc": null}
	if d["zona"]["tipo"] == "poligono":
		r["zona"] = world._cells_in_polygon(d["zona"]["poligono"])
	registros.append(r)
	return r


## Le da al dueño (`d["amo"]`) el perro del editor `d`: sale y se duerme con él. false si
## el dueño no está en el censo.
func con_amo(d: Dictionary) -> bool:
	for r in registros:
		if r["personaje"].get("id", "") == d["amo"]:
			r["perros"] = r.get("perros", []) + [d]
			return true
	return false


## Si anda por la calle a la hora `h`.
func activo(r: Dictionary, h: int) -> bool:
	if not r["personaje"].is_empty():
		return Personajes.activo(r["personaje"], h)
	return Npc.active_at(r["kind"], h)


## Si tiene asuntos contigo y no se puede dormir aunque te alejes.
func anclado(npc: Npc) -> bool:
	if npc.mode != "":
		return true
	return GameState.errands.any(func(e): return e["state"] == "activo" and is_same(e["giver"], npc))


## Dónde está ahora un latente: el lugar de su rutina a esta hora o su casa; los que pasean
## mucho (la policía, los repartidores) van cambiando de sitio por su zona.
func posicion(r: Dictionary) -> Vector2i:
	if not r["personaje"].is_empty():
		var l := Personajes.lugar_a(r["personaje"], GameState.hour())
		if not l.is_empty():
			return Vector2i(l["x"], l["y"])
		if r["home"].x < 0:
			r["home"] = world._personaje_home(r["personaje"], r["zona"])
		return r["home"]
	var wander: int = Npc.KINDS[r["kind"]]["wander"]
	if wander < VAGA_DESDE:
		return r["home"]
	if GameState.now() - r.get("pos_t", -INF) >= VAGA_CADA:
		r["pos"] = world.city.random_walkable_near(r["home"], wander)
		r["pos_t"] = GameState.now()
	return r["pos"]


## Repasa el censo cada CADA segundos: duerme a los que se han alejado y despierta a los
## que han entrado en el radio.
func tick(delta: float) -> void:
	if pausado:
		return
	_alarmas -= delta
	if _alarmas <= 0.0:
		_alarmas = 5.0
		despertadores()
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = CADA
	# si el jugador ha saltado de sitio (empieza la partida, le llevan a comisaría...), todo
	# de una vez y cada uno ya en su sitio: no hay tiempo de verlos llegar
	var salto := _dist(world.player.cell, _ultima) > SALTO
	_ultima = world.player.cell
	if salto:
		repasar(0, 0, true)
	else:
		repasar(MAX_DESPERTAR, TANDA)


## Duerme a los que se han alejado y despierta, los más cercanos primero, hasta `limite` de
## los que han entrado en el radio (0: todos; montar un cuerpo cuesta, y de golpe se nota).
## Con `tanda`, solo mira esos registros, siguiendo por donde lo dejó la vez anterior.
## Con `en_su_sitio`, los que despiertan a la vista aparecen ya donde les toca.
func repasar(limite := 0, tanda := 0, en_su_sitio := false) -> void:
	var h := GameState.hour()
	var me: Vector2i = world.player.cell
	var cerca: Array[Dictionary] = []
	var lote := registros
	if tanda > 0 and registros.size() > tanda:
		if _cursor >= registros.size():
			_cursor = 0
		lote = registros.slice(_cursor, _cursor + tanda)
		_cursor += tanda
	for r in lote:
		var npc: Npc = r["npc"]
		if npc != null and not is_instance_valid(npc):
			r["npc"] = null  # lo ha quitado otro (una detención, un susto...)
			npc = null
		if npc != null:
			if npc.distance_to_cell(me) > RADIO_DORMIR and not anclado(npc):
				dormir(r)
		elif activo(r, h):
			var d := _dist(posicion(r), me)
			if d <= RADIO_ACTIVO:
				r["_d"] = d
				cerca.append(r)
	if limite > 0 and cerca.size() > limite:
		cerca.sort_custom(func(a, b): return a["_d"] < b["_d"])
		cerca.resize(limite)
	for r in cerca:
		despertar(r, posicion(r) if en_su_sitio else Vector2i(-1, -1))


## Despertadores: el que tiene que cobrarte (una deuda vencida) viene a buscarte aunque esté
## latente o en la otra punta: aparece fuera de la vista, cerca de ti, y viene hacia ti. Si no
## le pagas, vuelve cada Defs.DEBT_VISIT_EVERY horas.
func despertadores() -> void:
	var now := GameState.now()
	var me: Vector2i = world.player.cell
	for r in registros:
		var npc: Npc = r["npc"]
		if npc != null and not is_instance_valid(npc):
			npc = null
		var debt: int = npc.debt if npc != null else r["estado"].get("debt", 0)
		var due: float = npc.debt_due if npc != null else r["estado"].get("debt_due", 0.0)
		if debt <= 0 or now < due or now < r.get("visita", -INF):
			continue
		if npc != null and (npc.mode != "" or npc.distance_to_cell(me) <= RADIO_VISTA):
			continue  # ya está en ello, o a la vista: te cobrará cuando te vea
		r["visita"] = now + Defs.DEBT_VISIT_EVERY * 60.0
		var spot := _fuera_de_vista(me)
		if npc == null:
			npc = despertar(r, spot)
		else:
			npc.setup(world.city, spot)
		npc.come_for("cobrar")


## Una casilla de calle a las afueras de lo que ves, en una dirección al azar (que no se salga
## del mapa: cerca del borde se prueban otras).
func _fuera_de_vista(me: Vector2i) -> Vector2i:
	var city := world.city
	for i in 12:
		var dir := Vector2.RIGHT.rotated(randf() * TAU)
		var c := me + Vector2i(dir * (RADIO_VISTA + 4))
		if c.x < 0 or c.y < 0 or c.x >= city.width or c.y >= city.height:
			continue
		var spot := city.nearest_walkable(c, 10)
		if city.is_walkable(spot) and _dist(spot, me) > RADIO_VISTA and _dist(spot, me) <= RADIO_VISTA + 14:
			return spot
	return city.random_walkable_near(me, RADIO_VISTA)


## Le quita el cuerpo y guarda en el registro lo que le ha pasado.
func dormir(r: Dictionary) -> void:
	var npc: Npc = r["npc"]
	if npc == null:
		return
	for k in ESTADO:
		var v = npc.get(k)
		r["estado"][k] = v.duplicate(true) if v is Dictionary else v
	var metas := {}
	for m in npc.get_meta_list():
		metas[m] = npc.get_meta(m)
	r["estado"]["metas"] = metas
	r["home"] = npc.home
	r["bed"] = npc.bed
	r["visto"] = GameState.now()
	for f in world.npcs.filter(func(n): return n.amo == npc):
		world.npcs.erase(f)
		f.queue_free()
	world.npcs.erase(npc)
	npc.queue_free()
	r["npc"] = null


## Le da cuerpo donde le toca estar: lejos de la vista si está cerca, y yendo hacia su sitio.
## Con `junto_a`, aparece ahí mismo (las pruebas y el botón «Probar en el juego»).
func despertar(r: Dictionary, junto_a := Vector2i(-1, -1)) -> Npc:
	var npc := Npc.new()
	if r["personaje"].is_empty():
		npc.init_kind(r["kind"], r["name"])
		npc.home = r["home"]
	else:
		npc.init_personaje(r["personaje"])
		npc.set_zona(r["zona"])
		r["home"] = world._personaje_home(r["personaje"], r["zona"])
		npc.home = r["home"]
	_al_dia(npc, r)
	npc.player = world.player
	npc.world = world
	world.city.entities.add_child(npc)
	var goal := posicion(r)
	var start := goal
	var me: Vector2i = world.player.cell
	if junto_a.x >= 0:
		start = junto_a
		goal = junto_a
	elif _dist(goal, me) < RADIO_VISTA:
		# está a la vista: que llegue andando desde fuera, no que aparezca de la nada
		var dir := Vector2(goal - me)
		dir = dir.normalized() if dir.length() > 0.5 else Vector2.RIGHT.rotated(randf() * TAU)
		start = world.city.nearest_walkable(me + Vector2i(dir * (RADIO_VISTA + 4)))
	npc.setup(world.city, world.city.random_walkable_near(start, 2))
	if start != goal:
		npc.walk_to(world.city.random_walkable_near(goal, 2))
	npc.caught_player.connect(world._on_caught)
	world.npcs.append(npc)
	if Npc.KINDS[r["kind"]].has("bed") and r["personaje"].is_empty():
		if r["bed"].x < 0:
			r["bed"] = world._bed_for(npc)
		npc.bed = r["bed"]
	for kind in r["seguidores"]:
		world._spawn_follower(kind, npc)
	for d in r.get("perros", []):
		world._spawn_follower("perro", npc, d)
	r["npc"] = npc
	return npc


## Le devuelve lo que guardó al dormirse y le pone al día del tiempo que ha pasado latente:
## a quien le robaron vuelve a llevar algo encima y lo que le hiciste se va olvidando
## (Defs.LATENT_*), igual que olvida la gente de verdad. El rencor fuerte dura más.
func _al_dia(npc: Npc, r: Dictionary) -> void:
	var e: Dictionary = r["estado"]
	if e.is_empty():
		return
	for k in ESTADO:
		if e.has(k):
			npc.set(k, e[k].duplicate(true) if e[k] is Dictionary else e[k])
	for m in e.get("metas", {}):
		npc.set_meta(m, e["metas"][m])
	var minutes: float = GameState.now() - r["visto"]
	if npc.robbed and minutes >= Defs.LATENT_ROBBED_FORGET:
		npc.robbed = false
		var fresh := Npc.new()
		fresh.init_kind(npc.kind, npc.display_name)
		npc.money = maxi(npc.money, fresh.money)
		fresh.free()
	var steps := floori(minutes / Defs.LATENT_MEMORY_FADE)
	if steps > 0:
		for what in npc.memory.keys():
			var keep: int = npc.memory[what] - steps / (2 if what in Defs.LATENT_GRUDGES else 1)
			if keep > 0:
				npc.memory[what] = keep
			else:
				npc.memory.erase(what)


## Registro del bot `npc`, o {} si no tiene (los que van detrás de otro).
func de(npc: Npc) -> Dictionary:
	for r in registros:
		if is_same(r["npc"], npc):
			return r
	return {}


## Si vale la pena guardar al bot aunque se acabe su horario: le conoces o te recuerda.
func conocido(r: Dictionary) -> bool:
	if not r["personaje"].is_empty():
		return true
	var npc: Npc = r["npc"]
	if npc != null and is_instance_valid(npc):
		return npc.known or not npc.memory.is_empty() or npc.debt > 0
	return r["estado"].get("known", false) or not r["estado"].get("memory", {}).is_empty()


## Saca del censo a los latentes que ya no andan por la calle a esta hora y no te conocen.
func olvidar(h: int) -> void:
	for r in registros.duplicate():
		if r["npc"] == null and not activo(r, h) and not conocido(r):
			registros.erase(r)


## Los que te tienen ganas (les robaste, pegaste, timaste o les pisaste la esquina), tengan
## cuerpo o no.
func rencorosos() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r in registros:
		var npc: Npc = r["npc"]
		var mem: Dictionary = npc.memory if npc != null and is_instance_valid(npc) else r["estado"].get("memory", {})
		if Defs.LATENT_GRUDGES.any(func(g): return mem.get(g, 0) > 0):
			out.append(r)
	return out


func latentes() -> int:
	return registros.filter(func(r): return r["npc"] == null).size()


static func _dist(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))
