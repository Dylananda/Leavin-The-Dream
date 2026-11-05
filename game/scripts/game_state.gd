extends Node
## Estado de la partida del yonki que controla el jugador (autoload "GameState").
##
## Todas las estadísticas van de 0 a 100 salvo el dinero y la caída.
## La caída es la puntuación: sube al perder dignidad y al alcanzar hitos.
## El hambre y el sueño son malos cuando suben; la salud, la salud mental y la dignidad, cuando bajan.
## Cada sustancia que conoces lleva su propio colocón, mono y enganche (`subs`).

signal changed
signal message(text: String, color: Color)
signal game_over(reason: String)
## Algo te ha dejado fuera de juego y apareces en otro sitio ("cap": urgencias o el alta del psiquiátrico).
signal relocated(place: String)
signal new_day  ## empieza un día (World guarda la partida: ver Partida)

const C_INFO := Color(0.85, 0.85, 0.8)
const C_GOOD := Color(0.55, 0.85, 0.5)
const C_BAD := Color(0.95, 0.45, 0.4)
const C_FALL := Color(0.85, 0.55, 0.95)
const C_VOICE := Color(0.6, 0.8, 1.0)

var profile: Dictionary = {}
var partida_id := ""  ## archivo de la partida guardada (ver Partida); "" hasta que se guarda
var money := 0
var bank := 0
var health := 100.0
var hunger := 0.0
var fatigue := 0.0  ## Sueño
var starving := 0.0  ## horas pasando hambre de verdad (ver Defs.STARVE_*)
var vitality := 100.0  ## aguante para correr y pelear (ver vitality_max y Defs.VITALITY_*)
var riding := false  ## vas montado en una bici (B; ver World.toggle_bike)
var exhausted := false  ## agotado: no se corre hasta recuperar Defs.VITALITY_RECOVER
var sanity := 100.0  ## Salud mental
var dignity := 100.0
## Lo que llamas la atención y lo buscada que te tiene la policía. La barra de Discreción es su inverso.
var heat := 0.0
var caida := 0.0
var debt := 0  ## Lo que debes a los camellos
## Hasta cuándo (minutos de now()) estás fichado: la policía que te vea te persigue. -1 = no.
var wanted_until := -1.0
## Por qué estás fichado (clave de Defs.CRIME_CORPS): decide qué cuerpo de policía va a por ti.
var wanted_crime := ""
var inventory: Dictionary = {}
## Cuántos de los objetos de `inventory` no son lo que crees (la basura que recogiste ido
## pensando que era un móvil): id -> número. Ver scripts/street_items.gd.
var fakes: Dictionary = {}
var milestones: Array[String] = []
var arrests := 0
var fines := 0  ## Multas de la Guàrdia Urbana (ver fine())
var admissions := 0  ## Ingresos en el psiquiátrico
## Sustancias que conoces: id -> {"high": colocón, "mono": mono, "addiction": enganche, "crash": minutos de bajón}
var subs: Dictionary = {}
## Resacas en curso: {sustancia: {"nivel": 0..Defs.RESACA_MAX, "left": minutos, "total": minutos}}.
## Empiezan al dormir con lo consumido desde la última vez (subs[id]["resaca_pend"]).
var resacas: Dictionary = {}
var _next_receta_day := 0  ## (CAP) desde qué día te vuelve a hacer una receta el médico
## Asociaciones cannábicas, por su nombre (ver Interactions._club): las que sabes qué son
## (las demás son una puerta sin rótulo), de las que eres socio, las precintadas tras una
## redada (nombre -> día en que reabren) y lo que te han vendido hoy ({"dia", "n"}).
var clubs_conocidos: Array = []
var clubs_socio: Array = []
var clubs_cerrados: Dictionary = {}
var club_compras: Dictionary = {}
## Encargos aceptados y lo que apuntaste de ellos en la libreta (ver scripts/errands.gd).
## Cada nota guarda lo que crees que te dijeron, que no siempre coincide con el encargo.
var errands: Array = []
var notes: Array = []
## Lo que te han contado en las conversaciones (pistas para la libreta):
## [{"time": now(), "who", "text", "poi" ({} si no señala un sitio)}]
var pistas: Array = []
## Misiones de los personajes del editor (ver Misiones): lo que pasó con cada una
## ({"personaje/misión": {"estado": "hecho" o "fallado", "dia"}}), los favores que te hacen
## ({personaje: {favor: now() hasta el que dura}}) y lo que debes a cada uno ({personaje: €}).
var misiones: Dictionary = {}
var favores: Dictionary = {}
var debe_a: Dictionary = {}
var apartados: Dictionary = {}  ## {personaje: now() hasta el que está fuera del barrio (detenido)}
## Minutos que adelanta (o retrasa) el reloj del HUD mientras miente; ver _update_clock_lie().
var clock_skew := 0.0
var _clock_lie_left := 0.0  ## minutos que le quedan a la mentira del reloj
var _clock_blank := false  ## el reloj no se lee en absoluto

var day := 1
var minute_of_day := 9.0 * 60.0  ## Se empieza a las 9:00
var alive := true
var ending_title := ""  ## título de la pantalla final ("" = «Fin de la partida»)
## Qué ha sido del yonki al acabar (clave de Defs.DESTINOS: "muerto", "preso"...).
var destino := ""
## Los yonkis anteriores de esta partida, del primero al último (ver World.relevo):
## [{perfil, nombre, destino, titulo, motivo, desde, dia, caida, celda, look, rebuscado}]
var historia: Array = []
## Lo que quiere conseguir este yonki y cómo va (ver Proposito y Defs.PROPOSITOS); {} si nada.
var proposito: Dictionary = {}
## Sucesos del barrio en marcha ({id: {"hasta": now(), ...}}) y cuándo acabó cada uno
## ({id: now()}); ver Sucesos y Defs.SUCESOS. Son del barrio: sobreviven a un relevo.
var sucesos: Dictionary = {}
var sucesos_fin: Dictionary = {}
## Tu fama por zonas del barrio ({"x,y": {"buena", "mala"}}; ver Fama). Es tuya: al relevo
## pasa a la historia del de antes y el nuevo empieza sin.
var fama: Dictionary = {}
var dia_inicio := 1  ## día en que empezó el yonki de ahora
var papa_cut := false
var sleeping := false
var _sleep_quality := 1.0
var _handling := false  ## Mientras se resuelve una consecuencia no se encadena otra
var _next_income_day := 0
var _last_meds_day := -99
var _last_methadone_day := -99
var _voice_timer := 0.0

## Totales para lo que no distingue sustancias: colocón sumado, el peor mono y el mayor enganche.
var high: float:
	get:
		var t := 0.0
		for id in subs:
			t += subs[id]["high"]
		return t
var mono: float:
	get:
		return _max_of("mono")
var addiction: float:
	get:
		return _max_of("addiction")
var discretion: float:
	get:
		return 100.0 - heat


func new_game(profile_id: String) -> void:
	profile = Defs.profile(profile_id)
	partida_id = ""
	money = profile["money"]
	bank = 0
	health = profile["health"]
	dignity = profile["dignity"]
	sanity = profile["sanity"]
	hunger = 30.0
	fatigue = 20.0
	vitality = 100.0
	exhausted = false
	riding = false
	starving = 0.0
	subs = {}
	resacas = {}
	_next_receta_day = 0
	clubs_conocidos = []
	clubs_socio = []
	clubs_cerrados = {}
	club_compras = {}
	for id in profile["knows"]:
		_learn(id, float(profile["knows"][id]))
	heat = 0.0
	wanted_until = -1.0
	wanted_crime = ""
	caida = 0.0
	ending_title = ""
	destino = ""
	historia = []
	dia_inicio = 1
	pistas = []
	debt = 0
	inventory = profile["items"].duplicate()
	fakes = {}
	milestones = []
	arrests = 0
	fines = 0
	admissions = 0
	day = 1
	minute_of_day = 9.0 * 60.0
	alive = true
	papa_cut = false
	sleeping = false
	_handling = false
	_next_income_day = 1 + int(profile["income"].get("every_days", 0)) if profile["income"] else 0
	_last_meds_day = -99
	_last_methadone_day = -99
	errands = []
	notes = []
	misiones = {}
	favores = {}
	debe_a = {}
	apartados = {}
	clock_skew = 0.0
	_clock_lie_left = 0.0
	_clock_blank = false
	proposito = _nuevo_proposito()
	sucesos = {}
	sucesos_fin = {}
	fama = {}
	changed.emit()


## El propósito del perfil de ahora, por empezar (ver Proposito): {} si no tiene.
func _nuevo_proposito() -> Dictionary:
	if not Defs.PROPOSITOS.has(profile.get("id", "")):
		return {}
	return {"paso": 0, "progreso": 0, "racha": 0, "hoy_ok": true, "dias": [], "arrests": arrests,
		"admissions": admissions, "estado": "activo"}


## Sigues con otro yonki (`profile_id`) en el mismo barrio, `dias` después: todo lo tuyo
## empieza de cero, pero se quedan la historia, la partida guardada y lo que es del barrio
## (los clubs precintados, los personajes detenidos por una misión).
func relevo(profile_id: String, dias: int) -> void:
	var keep := {"historia": historia, "partida_id": partida_id, "clubs_cerrados": clubs_cerrados,
		"apartados": apartados, "sucesos": sucesos, "sucesos_fin": sucesos_fin}
	var hoy := day + dias
	new_game(profile_id)
	for k in keep:
		set(k, keep[k])
	day = hoy
	dia_inicio = hoy
	if profile["income"]:
		_next_income_day = day + int(profile["income"].get("every_days", 0))
	changed.emit()


## La fecha del día de ahora: [mes, día] (Defs.CALENDARIO_INICIO es el día 1).
func fecha() -> Array:
	var mes: int = Defs.CALENDARIO_INICIO[0]
	var dia: int = Defs.CALENDARIO_INICIO[1] + day - 1
	while dia > Defs.DIAS_MES[mes - 1]:
		dia -= Defs.DIAS_MES[mes - 1]
		mes = mes % 12 + 1
	return [mes, dia]


## «17 de julio».
func fecha_texto() -> String:
	var f := fecha()
	return "%d de %s" % [f[1], Defs.MESES[f[0] - 1]]


## Lo que multiplica el precio de la droga por los sucesos en marcha (las redadas la encarecen).
func factor_precio() -> float:
	var f := 1.0
	for id in sucesos:
		f *= Defs.SUCESOS[id].get("precio", 1.0)
	return f


## Lo que cuesta ahora una dosis de `id` al camello (con los sucesos en marcha).
func precio(id: String) -> int:
	return maxi(1, roundi(Defs.SUBSTANCES[id]["price"] * factor_precio()))


## Lo que suma a lo que te dan pidiendo la gente de fiesta (sucesos con `pedir`).
func extra_pedir() -> float:
	var f := 0.0
	for id in sucesos:
		f += Defs.SUCESOS[id].get("pedir", 0.0)
	return f


func hour() -> int:
	return int(minute_of_day / 60.0)


func clock_text() -> String:
	return "Día %d · %02d:%02d" % [day, hour(), int(minute_of_day) % 60]


## Minutos de juego desde el comienzo de la partida (para los plazos de los encargos).
func now() -> float:
	return (day - 1) * 1440.0 + minute_of_day


## Si estás fichado: la policía que te vea va a por ti aunque no hagas nada.
func is_wanted() -> bool:
	return wanted_until > now()


## Si te busca el cuerpo `corps` ("urbana" o "mossos"): estás fichado por algo de su competencia.
func is_wanted_by(corps: String) -> bool:
	return is_wanted() and corps in Defs.CRIME_CORPS.get(wanted_crime, Defs.CRIME_CORPS["hurto"])


## Te fichan (alguien ha dado tu descripción) durante Defs.WANTED_MINUTES por `crime` (clave de
## Defs.CRIME_CORPS); si ya lo estabas por algo más grave (que persiguen más cuerpos), se queda.
func mark_wanted(why: String, crime := "hurto") -> void:
	var corps: Array = Defs.CRIME_CORPS[crime]
	if not is_wanted():
		log_msg("Fichado: %s. Si te ve %s, irá a por ti." % [why, _corps_text(corps)], C_BAD)
		wanted_crime = crime
	elif corps.size() >= Defs.CRIME_CORPS.get(wanted_crime, []).size():
		wanted_crime = crime
	wanted_until = now() + Defs.WANTED_MINUTES


func _corps_text(corps: Array) -> String:
	if corps.size() > 1:
		return "un agente"
	return "la Urbana" if corps[0] == "urbana" else "un mosso"


## Multa de la Guàrdia Urbana por la ordenanza: pagas lo que llevas hasta `amount` €; lo que no
## puedes pagar queda como denuncia (se nota en la dignidad, no en el bolsillo).
func fine(amount: int, why: String) -> void:
	var paid := mini(money, amount)
	money -= paid
	fines += 1
	if paid >= amount:
		log_msg("Multa de %d € por %s." % [amount, why], C_BAD)
	else:
		log_msg("Multa de %d € por %s. No llevas ni para empezar: te la mandan a una dirección que ya no es la tuya." % [amount, why], C_BAD)
	change_dignity(-2, "Que te multen por %s" % why)
	milestone("multa")
	changed.emit()


## Hora de un instante de now(): «14:30», o «10:00 del día 3» si no es hoy.
func time_text(t: float) -> String:
	var d := int(t / 1440.0) + 1
	var m := int(fposmod(t, 1440.0))
	var hm := "%02d:%02d" % [int(m / 60.0), m % 60]
	return hm if d == day else "%s del día %d" % [hm, d]


## Lo que enseña el reloj del HUD: casi siempre la verdad; ido, a ratos miente (_update_clock_lie).
func shown_clock_text() -> String:
	if _clock_blank:
		return "Día ? · --:--"
	# el minuto se corta antes de sumar el día: 1349,9999 + 1440 redondea a 2790 y adelantaría un minuto
	var t := maxf(0.0, (day - 1) * 1440.0 + floorf(minute_of_day) + clock_skew)
	var m := int(fposmod(t, 1440.0))
	return "Día %d · %02d:%02d" % [int(t / 1440.0) + 1, int(m / 60.0), m % 60]


## Lo ida que tienes la cabeza (0..1): colocón, mono, sueño y salud mental baja.
## Decide cuánto fallan la libreta y el reloj; sobrio, descansado y entero es 0.
func befuddlement() -> float:
	var b := maxf(0.0, (high - 20.0) / 100.0)
	b += maxf(0.0, (mono - 50.0) / 100.0)
	b += maxf(0.0, (fatigue - 70.0) / 60.0)
	b += maxf(0.0, (40.0 - sanity) / 80.0)
	return clampf(b, 0.0, 1.0)


## De vez en cuando, ido, el reloj del HUD se adelanta o se atrasa un rato (con el porro se
## atrasa; con farlopa o base, se adelanta). Con mono o sueño fuertes, a veces ni lo lees.
func _update_clock_lie(m: float) -> void:
	if _clock_lie_left > 0.0:
		_clock_lie_left -= m
		if _clock_lie_left <= 0.0:
			clock_skew = 0.0
			_clock_blank = false
		return
	var b := befuddlement()
	if b <= 0.0 or randf() >= Defs.CLOCK_LIE_PER_HOUR * b * m / 60.0:
		return
	_clock_lie_left = randf_range(30.0, 90.0)
	_clock_blank = (mono > 80.0 or fatigue > 90.0) and randf() < 0.5
	var dir := 1.0 if randf() < 0.5 else -1.0
	if intensity("porro") > 0.3:
		dir = -1.0
	elif intensity("farlopa") + intensity("base") + intensity("speed") > 0.3:
		dir = 1.0
	clock_skew = dir * snappedf(randf_range(20.0, 60.0) * (0.5 + b), 5.0)


func is_night() -> bool:
	return hour() >= 22 or hour() < 7


## Avanza el reloj `minutes` minutos de juego aplicando el desgaste del cuerpo.
func advance(minutes: float) -> void:
	if not alive:
		return
	var m := minutes
	_update_subs(m)
	_update_resacas(m)
	_update_body(m)
	heat = maxf(heat - Defs.HEAT_DECAY * m, exposure())
	_update_clock_lie(m)

	var prev_hour := hour()
	minute_of_day += m
	while minute_of_day >= 24.0 * 60.0:
		minute_of_day -= 24.0 * 60.0
		_new_day()
	if OS.is_debug_build() and hour() != prev_hour:
		print(debug_status())

	# las voces: Mari Loli siempre; los demás cuando la cabeza se les va
	if profile.get("id") == "psiquiatrico" or sanity < 30.0:
		_voice_timer -= m * (2.0 if sanity < 20.0 else 1.0)
		if _voice_timer <= 0.0:
			_voice_timer = randf_range(90.0, 240.0)
			say_voice()

	if not _handling and not sleeping:
		if (sanity < 15.0 or mono > 85.0) and randf() < 0.003 * m:
			_outburst()
		_check_extremes()
	_check_death(_worst_cause())
	changed.emit()


## Colocón, bajón, mono y enganche de cada sustancia conocida.
func _update_subs(m: float) -> void:
	for id in subs:
		var s: Dictionary = subs[id]
		var d: Dictionary = Defs.SUBSTANCES[id]
		var was_high: bool = s["high"] >= 10.0
		s["high"] = maxf(0.0, s["high"] - d.get("decay", 0.12) * m)
		s["crash"] = maxf(0.0, s["crash"] - m)
		s["malviaje"] = maxf(0.0, s.get("malviaje", 0.0) - m)
		if was_high and s["high"] < 10.0 and d.has("crash"):
			_crash(id)
		if s["high"] < 10.0 and not _relieved(id):
			s["mono"] = minf(100.0, s["mono"] + s["addiction"] * 0.004 * m)
		else:
			s["mono"] = maxf(0.0, s["mono"] - 0.05 * m)
		# sin tomarla, el enganche se va soltando muy despacio
		if s["high"] < 1.0:
			s["addiction"] = maxf(0.0, s["addiction"] - 0.003 * m)


## Las resacas se van pasando (y mientras duran, bajan la mente lo que diga cada una).
func _update_resacas(m: float) -> void:
	for id in resacas.keys():
		var r: Dictionary = resacas[id]
		var i := resaca_intensity(id)
		sanity = clampf(sanity + Defs.SUBSTANCES[id]["resaca"].get("mente", 0.0) * i * m / 60.0, 0.0, 100.0)
		r["left"] -= m
		if r["left"] <= 0.0:
			resacas.erase(id)


## Lo fuerte que es ahora la resaca de `id` (0..1): su nivel, que se va pasando con las horas.
func resaca_intensity(id: String) -> float:
	if not resacas.has(id):
		return 0.0
	var r: Dictionary = resacas[id]
	return clampf(r["nivel"] / Defs.RESACA_MAX * 1.5 * clampf(r["left"] / maxf(r["total"], 1.0), 0.0, 1.0), 0.0, 1.0)


## Al despertar: lo consumido desde la última vez que dormiste se convierte en resaca.
func _despertar_con_resaca() -> void:
	var nombres := []
	for id in subs:
		var pend: float = subs[id].get("resaca_pend", 0.0)
		if pend <= 0.0 or not Defs.SUBSTANCES[id].has("resaca"):
			continue
		subs[id]["resaca_pend"] = 0.0
		var nivel := clampf(pend, 0.2, Defs.RESACA_MAX)
		var total: float = Defs.SUBSTANCES[id]["resaca"]["horas"] * 60.0 * clampf(nivel, 0.5, Defs.RESACA_MAX)
		var old: Dictionary = resacas.get(id, {})
		if old.is_empty() or old["left"] < total:
			resacas[id] = {"nivel": maxf(nivel, old.get("nivel", 0.0)), "left": total, "total": total}
		nombres.append(Defs.item_name(id).to_lower())
	if not nombres.is_empty():
		log_msg("Te despiertas con resaca (%s)." % ", ".join(nombres), C_BAD)


## Hambre, sueño, salud y salud mental.
func _update_body(m: float) -> void:
	var hunger_rate := 1.0
	var fatigue_rate := 1.0
	for id in subs:
		var i := intensity(id)
		if i > 0.0:
			var d: Dictionary = Defs.SUBSTANCES[id]
			hunger_rate *= lerpf(1.0, d.get("hunger_rate", 1.0), i)
			fatigue_rate *= lerpf(1.0, d.get("fatigue_rate", 1.0), i)
			# los antidepresivos, tomados, sostienen la cabeza poco a poco
			sanity = minf(100.0, sanity + d.get("sanity_rate", 0.0) * i * m)
	if sleeping:
		hunger += Defs.HUNGER_RATE * 0.5 * m
		fatigue -= Defs.SLEEP_RECOVERY * _sleep_quality * m
	else:
		hunger += Defs.HUNGER_RATE * hunger_rate * m
		fatigue += Defs.FATIGUE_RATE * fatigue_rate * m
	hunger = clampf(hunger, 0.0, 100.0)
	fatigue = clampf(fatigue, 0.0, 100.0)

	var worst_mono := mono
	if worst_mono > 70.0:
		health -= 0.03 * m
	if high > 90.0:
		health -= 0.04 * m
	if hunger >= Defs.STARVE_FROM:
		starving += m / 60.0
	else:
		starving = maxf(0.0, starving - m / 30.0)
	if hunger > 85.0:
		health -= Defs.STARVE_HEALTH * m * (1.0 + starving / Defs.STARVE_WORSEN)
		sanity -= Defs.STARVE_SANITY * m * starving / 24.0
	if fatigue > 90.0:
		health -= 0.015 * m
	if worst_mono < 30.0 and high < 30.0 and hunger < 60.0:
		health = minf(100.0, health + 0.004 * m)

	var drain := 0.0
	if hunger > 70.0:
		drain += 0.02
	if fatigue > 75.0:
		drain += 0.03
	if worst_mono > 50.0:
		drain += 0.02
	if sleeping:
		sanity += 0.01 * _sleep_quality * m
	elif drain == 0.0 and dignity > 30.0:
		sanity += 0.008 * m
	sanity = clampf(sanity - drain * m, 0.0, 100.0)


func _new_day() -> void:
	day += 1
	new_day.emit()
	# Borja: si cae demasiado, su familia viene a por él (y eso, aquí, es perder)
	if profile.get("id") == "nino_bien" and dignity < Defs.HOME_RESCUE_DIGNITY and alive and randf() < Defs.HOME_RESCUE_CHANCE:
		_end("Un domingo aparece tu madre con el chófer y una psicóloga. Te meten en el coche sin preguntar. Una clínica en Suiza, luego un máster. En las cenas de Navidad, lo del Raval es «aquella etapa».",
			"TE LLEVAN A CASA", "fuera")
		return
	if dignity < 20.0:
		add_caida(5.0)
		log_msg("Otro día más en lo más hondo. (+5 de caída)", C_FALL)
	var income: Dictionary = profile["income"]
	if income and day >= _next_income_day:
		_next_income_day = day + int(income["every_days"])
		if profile["id"] == "nino_bien" and papa_cut:
			return
		bank += int(income["amount"])
		if income["amount"] > 0:
			log_msg("Te han ingresado %s: %d €. Ve a un cajero." % [income["label"], income["amount"]], C_GOOD)
		else:
			log_msg("Te han cobrado %s: %d €." % [income["label"], -income["amount"]], C_BAD)
			if bank < 0:
				change_dignity(-5, "Números rojos por no pagar a tu ex.")


func say_voice() -> void:
	var voices := [
		"Las voces: «Ese turista lleva la cartera en el bolsillo de atrás».",
		"Las voces: «La paloma te está juzgando».",
		"Las voces: «Deberías llamar a tu madre. No, mejor no».",
		"Las voces: «El de la farmacia sabe lo que hiciste».",
		"Las voces: «Hoy es buen día para tocar fondo».",
	]
	log_msg(voices.pick_random(), C_VOICE)


func log_msg(text: String, color: Color = C_INFO) -> void:
	if OS.is_debug_build():
		print("[%s] %s" % [clock_text(), text])
	message.emit(text, color)


## Línea de estado para la consola de depuración.
func debug_status() -> String:
	var s := []
	for id in subs:
		s.append("%s(%d/%d/%d)" % [id, subs[id]["high"], subs[id]["mono"], subs[id]["addiction"]])
	return "[%s] salud=%d hambre=%d sueño=%d mente=%d dignidad=%d policía=%d dinero=%d banco=%d caída=%d sustancias(colocón/mono/enganche)=%s inv=%s" % [
		clock_text(), health, hunger, fatigue, sanity, dignity, heat, money, bank, caida, " ".join(s), inventory]


func add_money(amount: int) -> void:
	money = maxi(0, money + amount)
	changed.emit()


func add_item(id: String, count := 1) -> void:
	inventory[id] = inventory.get(id, 0) + count
	changed.emit()


func has_item(id: String) -> bool:
	return inventory.get(id, 0) > 0


func remove_item(id: String, count := 1) -> void:
	var n: int = inventory.get(id, 0) - count
	if n <= 0:
		inventory.erase(id)
	else:
		inventory[id] = n
	# si ya no te quedan tantos, los falsos se fueron con ellos
	if fakes.get(id, 0) > maxi(n, 0):
		if n <= 0:
			fakes.erase(id)
		else:
			fakes[id] = n
	changed.emit()


## Vitalidad máxima ahora: la bajan el hambre y el sueño altos, el mono y la salud perdida.
func vitality_max() -> float:
	var m := 100.0 - maxf(0.0, hunger - 50.0) * Defs.VITALITY_HUNGER 		- maxf(0.0, fatigue - 50.0) * Defs.VITALITY_FATIGUE 		- mono * Defs.VITALITY_MONO - (100.0 - health) * Defs.VITALITY_HEALTH 		- starving * Defs.VITALITY_STARVE - _resaca_total() * Defs.RESACA_VITALIDAD
	return clampf(m, Defs.VITALITY_MIN_MAX, 100.0)


## Cuánta resaca llevas encima, sumando todas (0..1).
func _resaca_total() -> float:
	var t := 0.0
	for id in resacas:
		t += resaca_intensity(id)
	return clampf(t, 0.0, 1.0)


## Gasta (negativo) o recupera vitalidad, sin pasar del máximo. Al vaciarse quedas agotado.
func change_vitality(amount: float) -> void:
	vitality = clampf(vitality + amount, 0.0, vitality_max())
	if vitality <= 0.0:
		exhausted = true
	elif exhausted and vitality >= minf(Defs.VITALITY_RECOVER, vitality_max()):
		exhausted = false


## Apunta una pista que te ha dado `who` (ver Errands.notebook_entries).
func add_pista(who: String, text: String, poi := {}) -> void:
	pistas.append({"time": now(), "who": who, "text": text, "poi": poi})
	while pistas.size() > 20:
		pistas.pop_front()


func add_caida(points: float) -> void:
	caida += points
	changed.emit()
	if alive and caida >= Defs.LEGEND_CAIDA:
		_end("Has caído tan hondo que ya formas parte del paisaje. Los guías de los free tours paran delante de tu portal y cuentan tu historia, cada vez con más detalles inventados. Lo has conseguido: eres patrimonio del Raval.",
			"LEYENDA DEL BARRIO", "leyenda")


## Perder dignidad es caer: cada punto perdido suma un punto de caída. También pesa en la cabeza.
func change_dignity(amount: float, reason := "") -> void:
	if amount < 0.0:
		add_caida(-amount)
	dignity = clampf(dignity + amount, 0.0, 100.0)
	sanity = clampf(sanity + amount * 0.4, 0.0, 100.0)
	if reason != "":
		log_msg("%s (%+d dignidad)" % [reason, int(amount)], C_FALL if amount < 0 else C_GOOD)
	if dignity <= 0.0:
		milestone("fondo")
	if profile.get("id") == "nino_bien" and not papa_cut and dignity < 40.0:
		papa_cut = true
		log_msg("Un amigo de papá te ha visto por el Raval. Se acabó la paga.", C_BAD)
		milestone("papa_corta")
	changed.emit()


func change_health(amount: float, cause := "") -> void:
	health = clampf(health + amount, 0.0, 100.0)
	_check_death(cause)
	changed.emit()


func change_sanity(amount: float, reason := "") -> void:
	sanity = clampf(sanity + amount, 0.0, 100.0)
	if reason != "":
		log_msg("%s (%+d salud mental)" % [reason, int(amount)], C_VOICE if amount < 0 else C_GOOD)
	changed.emit()


## Quita hambre sin pasar por el inventario (la cena del albergue, un café...).
func eat(amount: float) -> void:
	hunger = maxf(0.0, hunger - amount)
	changed.emit()


## Calma el mono de todas las sustancias (hablar con alguien, un café...).
func ease_mono(amount: float) -> void:
	for id in subs:
		subs[id]["mono"] = maxf(0.0, subs[id]["mono"] - amount)
	changed.emit()


func milestone(id: String) -> void:
	if id in milestones:
		return
	milestones.append(id)
	var m: Array = Defs.MILESTONES[id]
	add_caida(m[1])
	log_msg("★ Hito de la caída: %s (+%d)" % [m[0], m[1]], C_FALL)


# ------------------------------------------------------------------ sustancias

func knows(id: String) -> bool:
	return subs.has(id)


func _learn(id: String, enganche: float) -> void:
	subs[id] = {"high": 0.0, "mono": enganche * 0.5, "addiction": enganche, "crash": 0.0,
		"resaca_pend": 0.0, "malviaje": 0.0}


## Conocer una sustancia nueva es un hito de la caída y le da una barra en el HUD.
func _discover(id: String) -> void:
	if knows(id):
		return
	_learn(id, 0.0)
	log_msg("Una sustancia nueva en tu vida: %s." % Defs.item_name(id).to_lower(), C_FALL)
	milestone("probar_" + id)


## Lo fuerte que pega ahora una sustancia (0..1): decide sus efectos en cámara y movimiento.
func intensity(id: String) -> float:
	return clampf(subs[id]["high"] / 50.0, 0.0, 1.0) if knows(id) else 0.0


## Lo fuerte que aprieta el mono de una sustancia (0..1).
func mono_intensity(id: String) -> float:
	return clampf((subs[id]["mono"] - 30.0) / 50.0, 0.0, 1.0) if knows(id) else 0.0


## Si otra sustancia que llevas encima calma el mono de `id` (la metadona, el del caballo).
func _relieved(id: String) -> bool:
	for other in subs:
		if Defs.SUBSTANCES[other].get("relieves", "") == id and subs[other]["high"] >= 3.0:
			return true
	return false


func _crash(id: String) -> void:
	var c: Dictionary = Defs.SUBSTANCES[id]["crash"]
	var s: Dictionary = subs[id]
	s["crash"] = c["minutes"]
	# el bajón trae mono en proporción al enganche: la primera vez casi nada
	s["mono"] = minf(100.0, s["mono"] + c["mono"] * minf(1.0, s["addiction"] / 15.0))
	fatigue = minf(100.0, fatigue + c.get("fatigue", 0.0))
	change_sanity(c["sanity"], "Bajón de %s" % Defs.item_name(id).to_lower())


func _max_of(key: String) -> float:
	var best := 0.0
	for id in subs:
		best = maxf(best, subs[id][key])
	return best


func _add_mono(amount: float) -> void:
	for id in subs:
		if subs[id]["addiction"] > 5.0:
			subs[id]["mono"] = minf(100.0, subs[id]["mono"] + amount)


## Consume una sustancia o comida del inventario.
func consume(id: String, safe := false) -> void:
	if not has_item(id):
		return
	if Defs.ITEMS.get(id, {}).has("food"):
		remove_item(id)
		var food: float = Defs.ITEMS[id]["food"]
		eat(food)
		change_health(food * 0.15)
		log_msg("Te comes: %s." % Defs.item_name(id), C_GOOD)
		if id == "sobras":
			change_dignity(-3)
			milestone("sobras")
		return
	if not Defs.SUBSTANCES.has(id):
		return
	remove_item(id)
	var d: Dictionary = Defs.SUBSTANCES[id]
	_discover(id)
	var s: Dictionary = subs[id]
	# mezclar depresores: mira lo que ya llevas antes de meterte esto
	var mezcla := false
	for other in d.get("mezcla", []):
		if other != id and intensity(other) > 0.3:
			mezcla = true
	s["high"] += d["high"]
	s["crash"] = 0.0
	if d.has("resaca"):
		s["resaca_pend"] = s.get("resaca_pend", 0.0) + d["resaca"]["dosis"]
		if d["resaca"].get("se_quita", false) and resacas.has(id):
			resacas[id]["left"] *= 0.5
			log_msg("La del perro: la resaca se te pasa un poco... de momento.", C_INFO)
	if d.has("malviaje") and randf() < (d["malviaje"]["chance"] if sanity < d["malviaje"]["cordura"] else Defs.MALVIAJE_SIEMPRE):
		s["malviaje"] = d["malviaje"]["minutes"]
		change_sanity(d["malviaje"]["sanity"], "Un mal viaje")
		log_msg("El viaje se tuerce. Todo te mira, todo se te echa encima.", C_BAD)
		milestone("malviaje")
	s["addiction"] = clampf(s["addiction"] + d["addiction"], 0.0, 100.0)
	s["mono"] = maxf(0.0, s["mono"] - d["high"] * 1.2)
	if d.has("relieves") and knows(d["relieves"]):
		var r: Dictionary = subs[d["relieves"]]
		r["mono"] = maxf(0.0, r["mono"] + d["mono"])
		r["addiction"] = maxf(0.0, r["addiction"] - d.get("relief_addiction", 0))
	var meds: bool = id == "pastillas" and profile.get("id") == "psiquiatrico"
	change_sanity(Defs.MEDS_SANITY if meds else d["sanity"])
	change_dignity(d["dignity"])
	log_msg("Te metes: %s." % d["name"], C_INFO)
	if mezcla:
		milestone("mezcla")
		log_msg("Lo mezclas con lo que ya llevas encima. Mala idea.", C_BAD)
	var od_chance: float = (high - 100.0) * 0.02 * d["od"] + 0.05 * d["od"] if high > 100.0 else 0.0
	if mezcla:
		od_chance += Defs.MEZCLA_OD * d["od"]
	# el fentanilo tiene riesgo en cada dosis; y, mientras está en el barrio, el caballo puede venir cortado
	od_chance += d.get("od_base", 0.0)
	var cortado: bool = id == "caballo" and sucesos.has("fentanilo") and randf() < Defs.FENTA_CORTE
	if cortado:
		od_chance += Defs.FENTA_CORTE_OD
	if not safe and od_chance > 0.0 and randf() < od_chance:
		if id in Defs.OPIACEOS and has_item("naloxona"):
			# la naloxona que llevas: alguien te la pone y vuelves de golpe, con un mono brutal
			remove_item("naloxona")
			log_msg("Sobredosis. Alguien encuentra la naloxona en tu bolsillo y te la clava. Vuelves de golpe, temblando.", C_BAD)
			change_health(-Defs.NALOXONA_SALUD, "Sobredosis en un portal")
			s["high"] = 0.0
			s["mono"] = 90.0
			milestone("naloxona")
			if alive:
				milestone("sobredosis")
				advance(30.0)
			return
		log_msg("Sobredosis. Te despiertas en el suelo con un desconocido encima.", C_BAD)
		change_health(-45.0, "Sobredosis en un portal")
		if alive:
			milestone("sobredosis")
			advance(120.0)
			return
	if cortado:
		log_msg("Este caballo pega distinto. Más fuerte. Más raro.", C_BAD)
	change_health(d["health"], "Tu cuerpo dijo basta")


## Lo que llamas la atención solo por tu aspecto: colocón a la vista, mono, mala pinta, hablar solo.
## Es el mínimo por debajo del cual no baja `heat`.
func exposure() -> float:
	var e := 0.0
	for id in subs:
		e += subs[id]["high"] * Defs.SUBSTANCES[id].get("visible", 0.2)
	e += maxf(0.0, mono - 50.0) * 0.4
	e += maxf(0.0, 30.0 - dignity) * 0.4
	if sanity < 20.0:
		e += 8.0
	if profile.get("id") == "jubilado":
		e *= 0.5
	return minf(e, Defs.MAX_EXPOSURE)


## Efectos en cámara, movimiento y pantalla que tocan ahora, y sus causas para el HUD.
## Devuelve {"fx": {efecto: intensidad}, "causes": [[texto, color], ...]}.
func effects() -> Dictionary:
	var fx := {}
	var causes := []
	for id in subs:
		var d: Dictionary = Defs.SUBSTANCES[id]
		var i := intensity(id)
		if i > 0.1:
			_add_fx(fx, d["fx"], i)
			causes.append(["%s: %s" % [d["name"], d["fx_text"]], d["color"]])
		if subs[id].get("malviaje", 0.0) > 0.0:
			_add_fx(fx, Defs.MALVIAJE_FX, clampf(subs[id]["malviaje"] / 30.0, 0.0, 1.0))
			causes.append(["Mal viaje de %s: %s" % [d["name"].to_lower(), Defs.MALVIAJE_FX_TEXT], C_BAD])
		var ri := resaca_intensity(id)
		if ri > 0.05:
			_add_fx(fx, d["resaca"]["fx"], ri)
			causes.append(["Resaca de %s: %s" % [d["name"].to_lower(), d["resaca"]["text"]], Color("c0a060")])
		if subs[id]["crash"] > 0.0:
			_add_fx(fx, Defs.CRASH_FX, clampf(subs[id]["crash"] / 20.0, 0.0, 1.0))
			causes.append(["Bajón de %s: %s" % [d["name"].to_lower(), Defs.CRASH_FX_TEXT], C_BAD])
		var mi := mono_intensity(id)
		if mi > 0.1:
			_add_fx(fx, Defs.MONO_FX, mi)
			fx["mono"] = maxf(fx.get("mono", 0.0), mi)
			causes.append(["Mono de %s: %s" % [d["name"].to_lower(), Defs.MONO_FX_TEXT], Color("e05a4a")])
	for key in Defs.BODY_FX:
		var b: Dictionary = Defs.BODY_FX[key]
		var i := clampf(inverse_lerp(b["from"], b["to"], get(key)), 0.0, 1.0)
		if i > 0.1:
			_add_fx(fx, b["fx"], i)
			causes.append(["%s: %s" % [b["name"], b["text"]], Color("c0b0a0")])
	fx["high"] = clampf((high - 60.0) / 60.0, 0.0, 1.0)
	return {"fx": fx, "causes": causes}


func _add_fx(fx: Dictionary, add: Dictionary, weight: float) -> void:
	for k in add:
		fx[k] = fx.get(k, 0.0) + add[k] * weight


# ------------------------------------------------------------------ dormir y consecuencias

## Duerme `minutes` minutos. `quality` (0..1) es lo que descansas; `robbery_risk`, la
## probabilidad de que te roben si llevas dinero; `heal`, la salud que recuperas.
func rest(minutes: float, quality: float, robbery_risk := 0.0, heal := 0.0) -> void:
	var q := quality
	for id in subs:
		if intensity(id) > 0.3 and Defs.SUBSTANCES[id].get("fatigue_rate", 1.0) < 1.0:
			q *= 0.3
			log_msg("Con la %s en el cuerpo no pegas ojo." % Defs.item_name(id).to_lower(), C_BAD)
			break
	if mono > 60.0:
		q *= 0.5
		log_msg("El mono no te deja dormir: sudores, patadas, pesadillas.", C_BAD)
	_sleep_quality = q
	sleeping = true
	advance(minutes)
	sleeping = false
	if not alive:
		return
	if minutes >= Defs.RESACA_SUENO:
		_despertar_con_resaca()
	change_health(heal * q)
	log_msg("Duermes %d horas. Son las %02d:%02d." % [int(minutes / 60), hour(), int(minute_of_day) % 60])
	if money > 0 and randf() < robbery_risk:
		log_msg("Al despertar te faltan los %d € que llevabas." % money, C_BAD)
		money = 0
		change_dignity(-3)


## Si una barra ha llegado al extremo, pasa algo malo.
func _check_extremes() -> void:
	if not alive:
		return
	_handling = true
	if fatigue >= 100.0:
		_pass_out()
	elif hunger >= 100.0:
		_faint()
	elif sanity <= 0.0:
		_admit()
	_handling = false


func _pass_out() -> void:
	log_msg("Llevas demasiadas horas sin dormir. Te quedas frito en plena calle.", C_BAD)
	rest(5 * 60, 0.5, 0.5)
	change_dignity(-4)
	milestone("frito")


## Te desmayas de hambre. Si alguien llama a una ambulancia, despiertas en urgencias con
## algo en el cuerpo; si no, en el mismo portal y con el mismo hambre (Defs.FAINT_RESCUE).
func _faint() -> void:
	milestone("desmayo")
	change_dignity(-3)
	if randf() < Defs.FAINT_RESCUE:
		log_msg("Te desmayas de hambre. Te despiertas en urgencias con un zumo y un sermón.", C_BAD)
		advance(4 * 60)
		hunger = 55.0
		change_health(-2, _starve_cause())
		if alive:
			relocated.emit("cap")
	else:
		log_msg("Te desmayas de hambre en un portal. Nadie llama a nadie. Te despiertas horas después, más débil.", C_BAD)
		advance(3 * 60)
		hunger = 90.0  # el mismo hambre: hay un par de horas para buscar algo antes de volver a caer
		change_health(-1.5, _starve_cause())


## Brote: dos días de ingreso. Sales desintoxicado, pero sin nada de lo que llevabas.
func _admit() -> void:
	admissions += 1
	log_msg("Brote. Te encuentran gritándoles a las palomas y acabas con un ingreso en el psiquiátrico.", C_BAD)
	for id in inventory.keys():
		if Defs.SUBSTANCES.has(id):
			inventory.erase(id)
	for i in 2:
		_new_day()
	for id in subs:
		var s: Dictionary = subs[id]
		s["high"] = 0.0
		s["crash"] = 0.0
		s["mono"] *= 0.2
		s["addiction"] *= 0.7
	hunger = 25.0
	fatigue = 15.0
	sanity = 55.0
	heat = 0.0
	health = minf(100.0, health + 10.0)
	milestone("psiquiatrico")
	add_caida(10.0)
	var limit := 2 if profile.get("id") == "psiquiatrico" else 3
	if admissions >= limit:
		_end("Esta vez no te dan el alta. El Raval sigue sin ti.", "", "psiquiatrico")
	else:
		log_msg("Dos días después te dan el alta, una receta y un «cuídate».")
		relocated.emit("cap")


## Estallas: gritos, una patada a un contenedor... Te mira todo el mundo.
func _outburst() -> void:
	var lines := [
		"Le gritas a un vecino que te ha mirado mal.",
		"Te encaras con un guiri por nada.",
		"Le das una patada a un contenedor y medio barrio se te queda mirando.",
	]
	log_msg(lines.pick_random() + " (−discreción)", C_BAD)
	heat = minf(100.0, heat + 25.0)
	change_dignity(-2)
	if randf() < 0.3:
		log_msg("Alguien te contesta con un puñetazo.", C_BAD)
		change_health(-6, "Una pelea que empezaste tú")


func can_get_methadone() -> bool:
	return _last_methadone_day != day


func got_methadone() -> void:
	_last_methadone_day = day


func can_get_meds() -> bool:
	return profile.get("id") == "psiquiatrico" and day - _last_meds_day >= 2


func got_meds() -> void:
	_last_meds_day = day


func arrest() -> void:
	arrests += 1
	var lost: Array = []
	for id in inventory.keys():
		if Defs.SUBSTANCES.has(id) or id in ["movil", "cartera", "cobre", "paquete", "cartera_caliente"]:
			lost.append(id)
	for id in lost:
		inventory.erase(id)
	heat = 0.0
	wanted_until = -1.0
	wanted_crime = ""
	log_msg("Detenido. Te quitan lo que llevabas encima y pasas la noche en el calabozo.", C_BAD)
	milestone("primera_detencion")
	add_caida(8.0)
	# en el calabozo se duerme mal, pero se duerme
	_sleep_quality = 0.3
	sleeping = true
	advance(12.0 * 60.0)
	sleeping = false
	_add_mono(25.0)
	change_sanity(-5)
	if profile.get("id") == "sin_papeles" and arrests >= 3 and alive:
		_end("Orden de expulsión. Te deportan. El Raval no se acuerda de ti.", "", "deportado")
	elif arrests >= Defs.PRISON_ARRESTS and alive:
		_end("A la %sª detención, el juez ya no te suelta. Te caen dos años en Brians. Cuando sales, el Raval ya no es tu barrio." % arrests, "", "preso")
	elif arrests == Defs.PRISON_ARRESTS - 1:
		log_msg("El juez te mira por encima de las gafas: «A la próxima, entras».", C_BAD)


## La causa de muerte más probable según lo que más está tirando de la salud.
func _worst_cause() -> String:
	if hunger > 85.0:
		return _starve_cause()
	if mono > 70.0:
		return "El mono te ha consumido"
	return "Tu cuerpo dijo basta"


func _starve_cause() -> String:
	var days := maxi(1, ceili(starving / 24.0))
	return "Te has muerto de hambre en un portal, tras %d %s casi sin comer" % [days, "día" if days == 1 else "días"]


func _check_death(cause: String) -> void:
	if alive and health <= 0.0:
		_end(cause if cause != "" else "Tu cuerpo dijo basta")


## Acaba la partida con un final que decide otro sistema (World: la redención).
func finish(reason: String, title := "", p_destino := "muerto") -> void:
	if alive:
		_end(reason, title, p_destino)


## Acaba con el yonki de ahora: `p_destino`, qué ha sido de él (Defs.DESTINOS).
func _end(reason: String, title := "", p_destino := "muerto") -> void:
	alive = false
	ending_title = title
	destino = p_destino
	changed.emit()
	game_over.emit(reason)
