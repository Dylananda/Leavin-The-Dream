class_name Fama
extends RefCounted
## Tu fama por zonas del barrio (docs/ideas.md, «Amistades y enemistades entre los NPC»): lo que
## se dice de ti en cada cuadrado de Defs.FAMA_ZONA casillas, con fama «buena» (ayudas) y
## «mala» (robas, pegas, timas), de 0 a 100. Sube con lo que haces a la vista (cuantos más te
## ven, más; Npc.remember la apunta) y con lo que se cuentan (cada día corre a las zonas de al
## lado y se va olvidando). Va en GameState.fama ({"x,y": {"buena", "mala"}}), que se guarda;
## al relevo pasa a la historia del yonki de antes y el nuevo empieza sin fama.
##
## Cambia cómo te trata quien no te conoce (Npc.grudge, Interactions, Trade, Vinculos.tick):
## con mala fama te evita, el camello no te vende y los clientes no te compran; con buena, los
## de la calle vienen a pedirte y alguien te avisa cuando viene la policía.


static func zona(cell: Vector2i) -> String:
	return "%d,%d" % [floori(cell.x / float(Defs.FAMA_ZONA)), floori(cell.y / float(Defs.FAMA_ZONA))]


## Tu fama `tipo` ("buena" o "mala") en la zona de `cell` (en la partida de ahora, o en `fama`).
static func de(cell: Vector2i, tipo: String, fama: Dictionary = {}) -> float:
	var f: Dictionary = fama if not fama.is_empty() else GameState.fama
	return float(f.get(zona(cell), {}).get(tipo, 0.0))


## Suma `puntos` de fama `tipo` en la zona de `cell`.
static func sumar(cell: Vector2i, tipo: String, puntos: float) -> void:
	var z := zona(cell)
	if not GameState.fama.has(z):
		GameState.fama[z] = {"buena": 0.0, "mala": 0.0}
	GameState.fama[z][tipo] = clampf(GameState.fama[z][tipo] + puntos, 0.0, 100.0)


## Has hecho `que` (Defs.FAMA_HECHOS) a alguien en `cell`, con `testigos` mirando: se corre.
static func hecho(cell: Vector2i, que: String, testigos: int) -> void:
	if not Defs.FAMA_HECHOS.has(que):
		return
	var h: Array = Defs.FAMA_HECHOS[que]
	var factor: float = 1.0 + Defs.FAMA_TESTIGO * testigos if testigos > 0 else Defs.FAMA_SOLO
	sumar(cell, h[0], h[1] * factor)


## Al empezar un día: la fama se va olvidando y corre a las zonas de al lado.
static func nuevo_dia() -> void:
	var f: Dictionary = GameState.fama
	var corre := {}
	for z in f:
		var xy: PackedStringArray = z.split(",")
		var c := Vector2i(int(xy[0]), int(xy[1]))
		for tipo in ["buena", "mala"]:
			var v: float = f[z][tipo] * Defs.FAMA_CORRE
			if v < 1.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var k := "%d,%d" % [c.x + d.x, c.y + d.y]
				if not corre.has(k):
					corre[k] = {"buena": 0.0, "mala": 0.0}
				corre[k][tipo] = maxf(corre[k][tipo], v)
	for z in corre:
		if not f.has(z):
			f[z] = {"buena": 0.0, "mala": 0.0}
		for tipo in ["buena", "mala"]:
			f[z][tipo] = maxf(f[z][tipo], corre[z][tipo])
	for z in f.keys():
		for tipo in ["buena", "mala"]:
			f[z][tipo] = maxf(0.0, f[z][tipo] - Defs.FAMA_OLVIDO)
		if f[z]["buena"] <= 0.0 and f[z]["mala"] <= 0.0:
			f.erase(z)


## Lo que se dice de ti por aquí (para la libreta), o "".
static func texto(cell: Vector2i) -> String:
	var buena := de(cell, "buena")
	var mala := de(cell, "mala")
	if maxf(buena, mala) < 15.0:
		return ""
	var t := ""
	if mala >= Defs.FAMA_NO_VENDE:
		t = "aquí todo el mundo sabe quién eres, y no para bien: ni los camellos te venden"
	elif mala >= Defs.FAMA_EVITA:
		t = "por aquí tienes mala fama: la gente se aparta al verte"
	elif buena >= Defs.FAMA_PIDEN:
		t = "por aquí se dice que ayudas a la gente: te piden y te avisan si viene la policía"
	elif buena >= mala:
		t = "por aquí alguno habla bien de ti"
	else:
		t = "por aquí alguno habla mal de ti"
	return "Lo que se dice de ti en esta zona: %s." % t
