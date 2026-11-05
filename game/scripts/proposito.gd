class_name Proposito
extends RefCounted
## Un propósito para cada yonki (docs/ideas.md, «Un propósito para cada yonki»): lo que quiere
## conseguir cada perfil, además de pasar un día más, por pasos (Defs.PROPOSITOS). Youssef manda
## dinero a casa y busca los papeles; Paco, recuperar a su hija; Don Ramón, que los nietos
## vuelvan a llamar; Jordi, ver al perro; Mari Loli, que callen las voces; Borja, demostrarle
## algo a papá.
##
## Choca con la caída: cada paso baja la caída (Defs.PROPOSITO_PASO_CAIDA) y lo que piden
## (estar sereno, guardar dinero, no meterse en líos) es lo contrario de caer. Cumplirlo es un
## final propio («CUMPLIDO», destino "cumplido": se queda en el barrio de vecino y deja relevo);
## perderlo para siempre es un hito («proposito_perdido»).
##
## El estado va en GameState.proposito (se guarda en la partida; un relevo empieza el suyo):
## {"paso", "progreso" (€ mandados o veces que has ido), "racha" (días seguidos aguantando),
## "hoy_ok" (si hoy aún no ha fallado nada), "dias" (días en que ya fuiste), "arrests" y
## "admissions" (al empezar, para «falla»), "estado": "activo", "hecho" o "perdido"}.
## Se ve en la libreta (Errands.notebook_entries) y avisa en el registro al avanzar.

const G := preload("res://scripts/game_state.gd")

var world: World


func _init(p_world: World) -> void:
	world = p_world


## El propósito del perfil de ahora ({} si no tiene).
static func def() -> Dictionary:
	return Defs.PROPOSITOS.get(GameState.profile.get("id", ""), {})


## El paso en el que vas ({} si ya no hay ninguno).
static func paso() -> Dictionary:
	var p: Dictionary = GameState.proposito
	var d := def()
	if p.is_empty() or d.is_empty() or p["estado"] != "activo" or p["paso"] >= d["pasos"].size():
		return {}
	return d["pasos"][p["paso"]]


# ------------------------------------------------------------------- en marcha

## Cada frame (desde World): mira si falla para siempre, si un paso «tener» ya está y si hoy se
## ha roto alguna condición de un paso «barra».
func update() -> void:
	var gs := GameState
	var p: Dictionary = gs.proposito
	if p.is_empty() or p["estado"] != "activo" or not gs.alive:
		return
	if _falla():
		perder()
		return
	var s := paso()
	match s.get("tipo", ""):
		"tener":
			if gs.has_item(s["objeto"]):
				avanzar()
		"barra":
			if p["hoy_ok"] and not _cumple(s["cond"]):
				p["hoy_ok"] = false
				gs.log_msg("Hoy ya no cuenta para tu propósito: %s." % s["texto"], G.C_BAD)


## Al empezar un día: el de ayer cuenta para la racha de un paso «barra» si aguantó entero.
func nuevo_dia() -> void:
	var p: Dictionary = GameState.proposito
	if p.is_empty() or p["estado"] != "activo":
		return
	var s := paso()
	if s.get("tipo", "") == "barra":
		p["racha"] = p["racha"] + 1 if p["hoy_ok"] and _cumple(s["cond"]) else 0
		p["hoy_ok"] = true
		if p["racha"] >= s["dias"]:
			avanzar()
		elif p["racha"] > 0:
			GameState.log_msg("Propósito: %d de %d días aguantando." % [p["racha"], s["dias"]], G.C_INFO)


## Si se cumplen ahora todas las condiciones `cond` de un paso «barra».
static func _cumple(cond: Array) -> bool:
	var gs := GameState
	for c in cond:
		if c.has("stat"):
			var v: float = float(gs.get(c["stat"]))
			if c.has("min") and v < c["min"]:
				return false
			if c.has("max") and v > c["max"]:
				return false
		if c.has("limpio") and gs.intensity(c["limpio"]) > Defs.PROPOSITO_LIMPIO:
			return false
		if c.get("no_fichado", false) and gs.is_wanted():
			return false
	return true


## Si ha pasado lo que lo pierde para siempre (`falla` en Defs.PROPOSITOS).
static func _falla() -> bool:
	var gs := GameState
	var p: Dictionary = gs.proposito
	var f = def().get("falla", "")
	if f is Dictionary:
		return f.has("dignidad") and gs.dignity < f["dignidad"]
	match f:
		"detenido":
			return gs.arrests > p["arrests"]
		"ingreso":
			return gs.admissions > p["admissions"]
	return false


## Paso cumplido: aviso, un poco menos de caída y más dignidad y mente; con el último, el final.
func avanzar() -> void:
	var gs := GameState
	var p: Dictionary = gs.proposito
	var d := def()
	var hecho: Dictionary = d["pasos"][p["paso"]]
	p["paso"] += 1
	p["progreso"] = 0
	p["racha"] = 0
	p["hoy_ok"] = true
	p["dias"] = []
	gs.log_msg("Tu propósito avanza: %s. (%d de %d)" % [hecho["texto"], p["paso"], d["pasos"].size()], G.C_GOOD)
	gs.caida = maxf(0.0, gs.caida - Defs.PROPOSITO_PASO_CAIDA)
	gs.change_dignity(Defs.PROPOSITO_PASO_DIGNIDAD, "Acercarte a lo tuyo")
	gs.change_sanity(Defs.PROPOSITO_PASO_MENTE)
	if p["paso"] >= d["pasos"].size():
		p["estado"] = "hecho"
		gs.finish(d["final"], "CUMPLIDO", "cumplido")
		return
	gs.log_msg("Lo siguiente: %s." % d["pasos"][p["paso"]]["texto"], G.C_INFO)
	gs.changed.emit()


## Lo pierdes para siempre: un hito de la caída.
func perder() -> void:
	var gs := GameState
	var p: Dictionary = gs.proposito
	p["estado"] = "perdido"
	gs.log_msg(def()["perdido"], G.C_FALL)
	gs.milestone("proposito_perdido")
	gs.change_sanity(-10, "Perder lo que te mantenía en pie")
	gs.changed.emit()


# ------------------------------------------------------------------- en los sitios

## Lo que se hace en el sitio `poi` para el paso en que vas («enviar» o «ir»).
func actions_for_poi(poi: Dictionary) -> Array:
	var gs := GameState
	var p: Dictionary = gs.proposito
	var s := paso()
	if s.is_empty() or not poi.get("kind", "") in s.get("lugar", []):
		return []
	match s["tipo"]:
		"enviar":
			var falta: int = s["total"] - p["progreso"]
			if gs.money < mini(s["minimo"], falta):
				return [Interactions._act("%s (te faltan %d €; llevas %d)" % [s["accion"], falta, gs.money], func(): pass)]
			var n := mini(gs.money, falta)
			return [Interactions._act("%s: %d € (faltan %d)" % [s["accion"], n, falta], func(): enviar(n))]
		"ir":
			if gs.day in p["dias"]:
				return []
			if not Personajes._entre(gs.hour(), s["desde"], s["hasta"]):
				return [Interactions._act("%s (de %02d a %02d h)" % [s["accion"], s["desde"], s["hasta"]], func(): pass)]
			return [Interactions._act(s["accion"], func(): ir())]
	return []


## Manda `n` € (paso «enviar»).
func enviar(n: int) -> void:
	var gs := GameState
	var p: Dictionary = gs.proposito
	var s := paso()
	gs.advance(15)
	gs.add_money(-n)
	p["progreso"] += n
	if p["progreso"] >= s["total"]:
		avanzar()
	else:
		gs.log_msg("Propósito: %d de %d € (%s)." % [p["progreso"], s["total"], s["texto"]], G.C_INFO)


## Vas a la cita de hoy (paso «ir»). Si había que ir sereno y no lo estás, no cuenta (o, si es
## estricto, lo pierdes para siempre).
func ir() -> void:
	var gs := GameState
	var p: Dictionary = gs.proposito
	var s := paso()
	gs.advance(s.get("minutos", 60))
	if s.get("sobrio", false) and gs.high > Defs.PROPOSITO_SOBRIO:
		if s.get("estricto", false):
			gs.log_msg("Llegas colocado. Se te nota desde la puerta.", G.C_BAD)
			perder()
		else:
			gs.log_msg("Llegas colocado y se te nota. Así no cuenta: otro día.", G.C_BAD)
			p["dias"].append(gs.day)
		return
	if s.get("efecto", "") == "sin_paga":
		gs.papa_cut = true
		gs.log_msg("Papá se queda callado al teléfono. «Como quieras, Borja.» Ya no hay paga.", G.C_INFO)
	p["dias"].append(gs.day)
	p["progreso"] += 1
	if p["progreso"] >= s["veces"]:
		avanzar()
	else:
		gs.log_msg("Propósito: %d de %d (%s)." % [p["progreso"], s["veces"], s["texto"]], G.C_INFO)


# ------------------------------------------------------------------- libreta

## Lo que se lee del propósito en la libreta (sin emborronar), o "".
static func texto_libreta() -> String:
	var p: Dictionary = GameState.proposito
	var d := def()
	if p.is_empty() or d.is_empty():
		return ""
	match p["estado"]:
		"hecho":
			return "Tu propósito: %s. Cumplido." % d["titulo"]
		"perdido":
			return "Tu propósito: %s. Ya no puede ser." % d["titulo"]
	var s := paso()
	var cuanto := ""
	match s["tipo"]:
		"enviar":
			cuanto = " (llevas %d de %d €)" % [p["progreso"], s["total"]]
		"ir":
			if s["veces"] > 1:
				cuanto = " (%d de %d)" % [p["progreso"], s["veces"]]
		"barra":
			cuanto = " (%d de %d días%s)" % [p["racha"], s["dias"], "" if p["hoy_ok"] else "; hoy ya no cuenta"]
	return "Tu propósito: %s. Paso %d de %d: %s%s." % [d["titulo"], p["paso"] + 1, d["pasos"].size(), s["texto"], cuanto]
