class_name Consumo
extends RefCounted
## Lo que consumen los bots: todo el mundo está yonki a su manera (docs/ideas.md, punto 8).
##
## Cada bot tiene (o no) una sustancia de cabecera, fija por su nombre y su tipo
## (Defs.NPC_HABITS), con colocón, mono y enganche como los del jugador pero simplificados:
## una sola sustancia, el colocón baja con el `decay` de Defs.SUBSTANCES, sin colocón sube el
## mono según el enganche, y con mono se mete lo que lleva encima o sale a pillar. El estado es
## un diccionario en Npc.consumo, que el censo guarda al dormirlo; al despertarlo, avanzar()
## calcula cómo le ha ido mientras tanto (si se ha colocado, si ha pillado o no).
##
## Lo que se nota: la velocidad y la forma de andar (los efectos `speed`, `drift` y `sway` de
## la sustancia), dormirse en un portal (cabecear), buscar bronca, venir a pedirte o a
## comprarte, el tirón cuando el mono aprieta, lo que dicen al pasar y lo que pagan.
## El equilibrio está en Defs (NPC_HABITS y las constantes NPC_* que lo siguen).

## Sustancias que, colocado, le hacen cabecear (y quedarse dormido en un portal) o buscar bronca.
const DOWNERS := ["caballo", "pastillas", "litrona", "metadona", "ansioliticos", "tramadol", "ketamina"]
const UPPERS := ["farlopa", "base", "speed"]


## Estado nuevo para `npc`: su sustancia (la que quiere, si es un personaje del editor; si no,
## una tirada fija por nombre en Defs.NPC_HABITS), su enganche y cómo está ahora mismo.
static func nuevo(npc: Npc) -> Dictionary:
	var id := habito(npc.kind, npc.display_name, npc.personaje)
	if id == "":
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(npc.kind + "|" + npc.display_name + "|consumo")
	var spec: Dictionary = Defs.NPC_HABITS.get(npc.kind, {})
	var range_: Array = spec.get("enganche", Defs.NPC_PERSONAJE_ENGANCHE)
	# el barrio se engancha más con cada relevo (Defs.RELEVO_ENGANCHE)
	var enganche := minf(100.0, rng.randf_range(range_[0], range_[1]) + Defs.RELEVO_ENGANCHE * GameState.historia.size())
	var high: float = Defs.SUBSTANCES[id]["high"]
	# cómo le pilla al salir: más o menos colocado, con más o menos mono (a voleo)
	return {
		"id": id,
		"enganche": enganche,
		"colocon": randf_range(0.0, high) if randf() < 0.5 else 0.0,
		"mono": randf_range(0.0, enganche * 0.6),
		"dosis": randi_range(0, 2),
		"t": GameState.now(),
	}


## La sustancia de cabecera de un bot ("" si ninguna). Los personajes del editor, la primera
## sustancia de las que quieren; los demás, por la tirada fija de su nombre.
static func habito(kind: String, nombre: String, personaje: Dictionary) -> String:
	for id in personaje.get("stats", {}).get("quiere", []):
		if Defs.SUBSTANCES.has(id):
			return id
	var usa: Dictionary = Defs.NPC_HABITS.get(kind, {}).get("usa", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind + "|" + nombre + "|habito")
	var r := rng.randf()
	for id in usa:
		r -= usa[id]
		if r < 0.0:
			return id
	return ""


## Pasan `minutos` de juego: se le baja el colocón, le sube el mono y, si aprieta, se mete lo
## que lleva o sale a pillar. Devuelve cuántas veces se ha metido algo. Va a tramos para que
## un rato largo (un latente al despertar) dé lo mismo que muchos cortos.
static func avanzar(c: Dictionary, minutos: float, money := -1) -> int:
	if c.is_empty() or minutos <= 0.0:
		return 0
	var d: Dictionary = Defs.SUBSTANCES[c["id"]]
	var veces := 0
	var left := minutos
	while left > 0.0:
		var m := minf(left, Defs.NPC_STEP)
		left -= m
		c["colocon"] = maxf(0.0, c["colocon"] - d.get("decay", 0.12) * m)
		if c["colocon"] < 10.0:
			c["mono"] = minf(100.0, c["mono"] + c["enganche"] * Defs.NPC_MONO_RATE * m)
		else:
			c["mono"] = maxf(0.0, c["mono"] - 0.05 * m)
		if c["mono"] >= Defs.NPC_USE_AT and c["colocon"] < 10.0:
			if c["dosis"] <= 0 and randf() < Defs.NPC_SCORE_PER_HOUR * m / 60.0 and money != 0:
				c["dosis"] += randi_range(1, 2)  # ha pillado (lo paga Npc: ver Npc.pasa_consumo)
				c["pillado"] = c.get("pillado", 0) + 1
			if c["dosis"] > 0:
				meterse(c)
				veces += 1
	c["t"] = GameState.now()
	return veces


## Se mete una dosis de lo suyo (de lo que lleva, o de lo que le das tú).
static func meterse(c: Dictionary, de_regalo := false) -> void:
	var d: Dictionary = Defs.SUBSTANCES[c["id"]]
	if not de_regalo:
		c["dosis"] -= 1
	c["colocon"] = minf(100.0, c["colocon"] + d["high"])
	c["mono"] = maxf(0.0, c["mono"] - d["high"] * 1.2)
	c["enganche"] = minf(100.0, c["enganche"] + d["addiction"] * Defs.NPC_ADDICTION_GAIN)


## Lo fuerte que le pega ahora (0..1), como GameState.intensity.
static func intensidad(c: Dictionary) -> float:
	return clampf(c.get("colocon", 0.0) / 50.0, 0.0, 1.0)


## Lo que se le nota: "colocado", "mono" o "" (nada, o no consume).
static func estado(c: Dictionary) -> String:
	if c.is_empty():
		return ""
	if intensidad(c) >= 0.4:
		return "colocado"
	if c["mono"] >= Defs.NPC_ASK_AT:
		return "mono"
	return ""


## Velocidad (multiplica la suya) y eses al andar por lo que lleva encima o por el mono.
static func manejo(c: Dictionary) -> Vector2:
	if c.is_empty():
		return Vector2(1.0, 0.0)
	var fx: Dictionary = Defs.SUBSTANCES[c["id"]]["fx"]
	var i := intensidad(c)
	var mono_i := clampf((c["mono"] - 50.0) / 50.0, 0.0, 1.0)
	var slow: float = 1.0 + fx.get("speed", 0.0) * i - 0.2 * mono_i
	var wobble: float = clampf((fx.get("drift", 0.0) + fx.get("sway", 0.0) * 0.5) * i, 0.0, 1.0)
	return Vector2(clampf(slow, 0.45, 1.5), wobble)


## Si cabecea: colocado de algo que tumba (caballo, pastillas, mucho alcohol).
static func cabecea(c: Dictionary) -> bool:
	return not c.is_empty() and c["id"] in DOWNERS and intensidad(c) >= Defs.NPC_NOD


## Si va acelerado de algo que pone agresivo (farlopa, base, speed).
static func acelerado(c: Dictionary) -> bool:
	return not c.is_empty() and c["id"] in UPPERS and intensidad(c) >= Defs.NPC_BRONCA


## Si tiene mono y nada que meterse: te pide, te compra o te da el tirón.
static func necesita(c: Dictionary) -> bool:
	return not c.is_empty() and c["dosis"] <= 0 and c["mono"] >= Defs.NPC_ASK_AT and c["colocon"] < 10.0


## Lo que paga de más quien tiene mono por lo suyo (1 = nada).
static func ansia(c: Dictionary, id: String) -> float:
	if c.is_empty() or c["id"] != id:
		return 1.0
	return 1.0 + Defs.NPC_MONO_PAYS * clampf(c["mono"] / 100.0, 0.0, 1.0)


## Una frase al pasar según cómo va, o "" si no toca.
static func frase(c: Dictionary) -> String:
	var e := estado(c)
	if e == "":
		return ""
	var key: String = c["id"] if e == "colocado" else "mono"
	var lines: Array = Defs.NPC_DRUG_LINES.get(key, [])
	return lines.pick_random() if not lines.is_empty() else ""
