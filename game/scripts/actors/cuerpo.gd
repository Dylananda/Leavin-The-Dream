class_name Cuerpo
## El muñeco de las personas con más detalle: cuerpo redondeado con cuello,
## hombros, codos, manos y zapatos; cara con ojos, cejas, nariz, boca y orejas; y el pelo
## como una malla de verdad (un casco con mechones que se ajusta a la cabeza, más mechones
## colgando en las melenas). Mismo sistema que el de siempre (Actor._part, que luego se
## juntan en una malla por pieza con el color en los vértices), así que cuesta lo mismo de
## dibujar. Se elige con Actor.cuerpo_nuevo.

const CABEZA_Y := 1.9  ## centro de la cabeza
const CABEZA_R := 0.31  ## radio del cráneo con el que se diseñó la cabeza (antes de CABEZA_K)
const CABEZA_ESCALA := Vector3(0.95, 1.08, 0.98)
## Cuánto se agranda la cabeza con todo lo que lleva (cara, pelo, gorras): una cabeza más
## grande que la real se lee mejor desde la cámara del juego.
const CABEZA_K := 1.17
## Peinados del cuerpo nuevo: los de Actor.HAIR_STYLES y algunos más.
const PEINADOS := {
	"m": ["corto", "rapado", "tupe", "rizos", "media_melena", "calvo", "coleta"],
	"f": ["melena", "flequillo", "coleta", "moño", "corta", "rizos", "rapado"],
}

static var _pelos := {}  ## mallas de pelo ya hechas (estilo|sombrero)


static func _capsula(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = maxf(h, r * 2.0)
	m.radial_segments = 10
	m.rings = 3
	return m


static func _esfera(r: float, seg := 12, anillos := 6) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = seg
	m.rings = anillos
	return m


## Una persona: lo mismo que Actor._build_person (piernas, cuerpo, brazos, cabeza, pelo y
## cara) con más detalle, y los mismos accesorios.
static func persona(a: Actor) -> void:
	var look := a.look
	var body := a._body
	var female: bool = look.get("gender", "m") == "f"
	var skin: Color = look["skin"]
	var shirt: Color = look["shirt"]
	var jacket: Color = look.get("jacket", Color.TRANSPARENT)
	var con_chaqueta := jacket.a > 0.0
	var skirt: bool = look.get("skirt", false)
	var build: float = Actor.BUILDS.get(look.get("build", ""), 1.0)
	var pants: Color = look["pants"]
	var zapato := pants.darkened(0.55).lerp(Color("2a2420"), 0.6)
	var hombro := (0.25 if female else 0.29) * build
	var cintura := (0.17 if female else 0.2) * build
	var cadera := (0.22 if female else 0.2) * lerpf(1.0, build, 0.7)

	# piernas: muslo, pantorrilla y zapato, con el pivote en la cadera
	var pierna_r := (0.085 if female else 0.095) * lerpf(1.0, build, 0.6)
	var piel_piernas := skin.darkened(0.08)
	a._legs = []
	for x in [-0.11, 0.11]:
		var j := Node3D.new()
		j.position = Vector3(x * lerpf(1.0, build, 0.5), 0.84, 0)
		body.add_child(j)
		var muslo := piel_piernas if skirt else pants
		a._part(j, _capsula(pierna_r, 0.46), muslo, Vector3(0, -0.2, 0))
		a._part(j, _capsula(pierna_r * 0.85, 0.44), piel_piernas if skirt else pants, Vector3(0, -0.54, -0.01))
		a._part(j, _esfera(0.1, 10, 5), zapato, Vector3(0, -0.77, 0.06), Vector3(0.95, 0.55, 1.65))
		a._legs.append(j)
	# cadera (o falda) y tronco que se estrecha en la cintura
	if skirt:
		a._part(body, CityProps.cylinder(cadera * 1.05, cadera * 1.5, 0.46, 14), pants, Vector3(0, 0.74, 0), Vector3(1, 1, 0.8))
	else:
		a._part(body, CityProps.cylinder(cadera, cadera * 1.02, 0.2, 14), pants, Vector3(0, 0.9, 0), Vector3(1, 1, 0.75))
	var tronco := jacket if con_chaqueta else shirt
	a._part(body, CityProps.cylinder(hombro, cintura, 0.6, 14), shirt, Vector3(0, 1.22, 0), Vector3(1, 1, 0.62 * build))
	a._part(body, _esfera(hombro * 0.98, 14, 6), shirt, Vector3(0, 1.46, 0), Vector3(1, 0.34, 0.62 * build))
	if female:
		a._part(body, _esfera(0.15, 12, 6), tronco, Vector3(0, 1.3, 0.07 * build), Vector3(1.3, 0.62, 0.7))
	if build > 1.1:
		a._part(body, _esfera(0.26, 12, 6), shirt, Vector3(0, 1.05, 0.08 * build), Vector3(1.05, 0.9, 0.85))
	if con_chaqueta:
		# chaqueta abierta: por encima del tronco, con la camiseta asomando por delante
		a._part(body, CityProps.cylinder(hombro * 1.06, cintura * 1.1, 0.64, 14), jacket, Vector3(0, 1.21, 0), Vector3(1, 1, 0.66 * build))
		a._part(body, CityProps.box(Vector3(hombro * 0.45, 0.56, 0.04)), shirt, Vector3(0, 1.25, hombro * 0.66 * build * 0.93))
		a._part(body, _esfera(hombro * 1.05, 14, 6), jacket, Vector3(0, 1.47, -0.01), Vector3(1, 0.36, 0.64 * build))
	# cuello
	a._part(body, CityProps.cylinder(0.075, 0.085, 0.18, 10), skin, Vector3(0, 1.57, -0.01))

	# brazos: hombro, brazo, antebrazo (de piel si va en manga corta) y mano
	var brazo_r := (0.065 if female else 0.075) * lerpf(1.0, build, 0.7)
	var manga := jacket if con_chaqueta else shirt.darkened(0.06)
	var antebrazo := manga if con_chaqueta else skin
	a._arms = []
	for s in [-1.0, 1.0]:
		var j := Node3D.new()
		j.position = Vector3(s * (hombro + brazo_r * 0.4), 1.45, 0)
		body.add_child(j)
		a._part(j, _esfera(brazo_r * 1.15, 10, 5), manga, Vector3(0, -0.02, 0))
		a._part(j, _capsula(brazo_r * 1.1, 0.36), manga, Vector3(0, -0.17, 0))
		var ante := a._part(j, _capsula(brazo_r * 0.92, 0.34), antebrazo, Vector3(0, -0.47, 0.035))
		ante.rotation.x = deg_to_rad(-8.0)
		a._part(j, _esfera(brazo_r * 1.05, 10, 5), skin, Vector3(0, -0.67, 0.06), Vector3(0.8, 1.1, 1.0))
		a._arms.append(j)

	# cabeza: cráneo, mandíbula y orejas
	_en_cabeza(a, _esfera(CABEZA_R, 16, 8), skin, Vector3.ZERO, CABEZA_ESCALA)
	_en_cabeza(a, _esfera(0.21, 12, 6), skin, Vector3(0, -0.13, 0.05), Vector3(1.12, 0.8, 1.0))
	for s in [-1.0, 1.0]:
		_en_cabeza(a, _esfera(0.065, 8, 4), skin.darkened(0.05), Vector3(s * 0.29, -0.01, -0.01), Vector3(0.45, 1.0, 0.75))
	_cara(a, skin)
	var hat: bool = a.accessory in ["gorra_poli", "gorra", "mochila", "cresta"]
	if a.accessory == "cresta":
		_pelo(a, "rapado", true)  # rapado por los lados; la cresta la pone el accesorio
	elif a.accessory != "capucha":
		_pelo(a, look.get("hair_style", "melena" if female else "corto"), hat)
	# los accesorios, los mismos que el muñeco de siempre (Actor._accesorio) con las medidas
	# de este cuerpo; las gorras, a la altura de esta cabeza (k: su alto respecto a la de 0,36)
	a._accesorio({"arm_x": hombro + brazo_r * 0.4, "hombros": hombro * 2.0, "mangas": manga,
		"cabeza": Vector3(0, CABEZA_Y, 0), "k": CABEZA_R * CABEZA_K * CABEZA_ESCALA.y / 0.36,
		"tronco": [hombro, cintura, 0.62 * build], "nuevo": true})


## Un color sin contorno (alfa 0: ver shaders/contorno.gdshader), para los detalles de la cara.
## Una pieza de la cabeza: `local` respecto al centro de la cabeza, en las medidas con las
## que se diseñó (CABEZA_R); se agranda todo por CABEZA_K.
static func _en_cabeza(a: Actor, mesh: Mesh, color: Color, local: Vector3, escala := Vector3.ONE) -> MeshInstance3D:
	return a._part(a._body, mesh, color, Vector3(0, CABEZA_Y, 0) + local * CABEZA_K, escala * CABEZA_K)


static func _liso(c: Color) -> Color:
	return Color(c, 0.0)


## Ojos (blanco y pupila), cejas del color del pelo, nariz, boca y barba o bigote, sin contorno.
static func _cara(a: Actor, skin: Color) -> void:
	var look := a.look
	var hair: Color = look["hair"]
	var y := 0.02
	for s in [-1.0, 1.0]:
		_en_cabeza(a, _esfera(0.052, 10, 5), _liso(Color("f4f0e8")), Vector3(s * 0.1, y, 0.262), Vector3(1.0, 1.05, 0.55))
		_en_cabeza(a, _esfera(0.03, 8, 4), _liso(Color("1a1410")), Vector3(s * 0.1, y - 0.005, 0.287), Vector3(1, 1, 0.5))
		var ceja := _en_cabeza(a, CityProps.box(Vector3(0.11, 0.03, 0.035)), _liso(hair.darkened(0.25)), Vector3(s * 0.1, y + 0.085, 0.27))
		ceja.rotation.z = deg_to_rad(-8.0 * s)
	_en_cabeza(a, _esfera(0.045, 8, 4), _liso(skin.darkened(0.1)), Vector3(0, -0.04, 0.305), Vector3(0.95, 1.3, 1.1))
	_en_cabeza(a, CityProps.box(Vector3(0.11, 0.022, 0.03)), _liso(skin.darkened(0.45).lerp(Color("8a3a3a"), 0.4)), Vector3(0, -0.15, 0.245))
	match look.get("facial", ""):
		"barba":
			_en_cabeza(a, _esfera(0.22, 12, 6), hair, Vector3(0, -0.15, 0.06), Vector3(1.12, 0.78, 1.0))
			_en_cabeza(a, CityProps.box(Vector3(0.16, 0.035, 0.05)), _liso(skin.darkened(0.45).lerp(Color("8a3a3a"), 0.4)), Vector3(0, -0.13, 0.265))
		"bigote":
			_en_cabeza(a, CityProps.box(Vector3(0.17, 0.045, 0.05)), _liso(hair), Vector3(0, -0.11, 0.27))
	if look.get("glasses", false):
		var frame := Color("1a1a1e")
		for s in [-1.0, 1.0]:
			# montura en aro (no un disco: se ven los ojos a través)
			var aro := TorusMesh.new()
			aro.inner_radius = 0.05
			aro.outer_radius = 0.066
			aro.rings = 14
			aro.ring_segments = 5
			_en_cabeza(a, aro, _liso(frame), Vector3(s * 0.1, y, 0.29)).rotation.x = deg_to_rad(90.0)
		_en_cabeza(a, CityProps.box(Vector3(0.08, 0.02, 0.02)), _liso(frame), Vector3(0, y + 0.01, 0.3))


# ------------------------------------------------------------------ pelo

## El pelo: un casco con mechones que se pega a la cabeza (Cuerpo.casco) más, según el
## peinado, mechones colgando, coleta, moño o tupé.
static func _pelo(a: Actor, estilo: String, hat: bool) -> void:
	var hair: Color = a.look["hair"]
	var key := estilo + ("|gorra" if hat else "")
	if not _pelos.has(key):
		_pelos[key] = casco(estilo, hat)
	_en_cabeza(a, _pelos[key], hair, Vector3.ZERO, CABEZA_ESCALA)
	match estilo:
		"melena", "flequillo":
			_mechones(a, hair, 0.5, 0.95)
		"corta":
			_mechones(a, hair, 0.26, 1.15)
		"media_melena":
			_mechones(a, hair, 0.2, 0.75)
		"coleta":
			if not hat:
				_en_cabeza(a, _esfera(0.07, 8, 4), hair.darkened(0.2), Vector3(0, 0.08, -0.31))
			_en_cabeza(a, _capsula(0.07, 0.42), hair, Vector3(0, -0.12, -0.38)).rotation.x = deg_to_rad(15.0)
		"moño":
			if not hat:
				_en_cabeza(a, _esfera(0.13, 10, 5), hair, Vector3(0, 0.3, -0.12))


## Mechones colgando por detrás y por los lados, de `largo` metros, hasta `lados` (radianes
## desde la nuca hacia delante, a cada lado).
static func _mechones(a: Actor, hair: Color, largo: float, lados: float) -> void:
	var n := 11
	for i in n:
		var ang := PI + lados * (2.0 * i / (n - 1) - 1.0) * 1.6  # de un lado a otro pasando por la nuca
		var r := CABEZA_R * 0.98
		var dir := Vector3(sin(ang), 0, cos(ang))
		var pos := Vector3(0, -0.05 - largo * 0.45, 0) + dir * r * Vector3(CABEZA_ESCALA.x, 1, CABEZA_ESCALA.z)
		var m := _en_cabeza(a, _capsula(0.075, largo + 0.2), hair.darkened(0.04 * (i % 2)), pos)
		# un poco hacia fuera por abajo, como cae el pelo sobre los hombros
		m.rotation = Vector3(-dir.z * 0.18, 0, dir.x * 0.18)


## El casco de pelo de un peinado: una esfera de la cabeza en la que cada punto sale hacia
## fuera lo que tiene de grosor el pelo ahí (con surcos de mechones) o, donde no hay pelo, se
## hunde dentro de la cabeza y no se ve. `hat`: sin lo que abulta por arriba.
static func casco(estilo: String, hat: bool) -> ArrayMesh:
	var seg_phi := 32
	var seg_theta := 18
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for it in seg_theta + 1:
		var theta := PI * it / seg_theta
		for ip in seg_phi + 1:
			var phi := TAU * ip / seg_phi
			var d := Vector3(sin(theta) * sin(phi), cos(theta), sin(theta) * cos(phi))
			var t := _grosor(estilo, theta, phi, hat)
			var rad := CABEZA_R - 0.03 if t <= 0.0 else CABEZA_R + t
			st.add_vertex(d * rad)
	for it in seg_theta:
		for ip in seg_phi:
			var i0 := it * (seg_phi + 1) + ip
			var i1 := i0 + 1
			var i2 := i0 + seg_phi + 1
			var i3 := i2 + 1
			st.add_index(i0)
			st.add_index(i1)
			st.add_index(i2)
			st.add_index(i1)
			st.add_index(i3)
			st.add_index(i2)
	st.generate_normals()
	return st.commit()


## Grosor del pelo en un punto de la cabeza: `theta` desde la coronilla (0) hacia abajo, `phi`
## alrededor (0 = la frente). 0 = no hay pelo.
static func _grosor(estilo: String, theta: float, phi: float, hat: bool) -> float:
	var frente := (cos(phi) + 1.0) / 2.0  # 1 delante, 0 en la nuca
	var lado := absf(sin(phi))
	# hasta dónde baja el pelo: por delante (la frente), por los lados y por la nuca
	var cfg := {
		"corto": [1.0, 1.7, 2.05, 0.045, 0.35],
		"rapado": [1.05, 1.75, 2.1, 0.012, 0.0],
		"tupe": [1.0, 1.7, 2.05, 0.04, 0.3],
		"rizos": [0.95, 1.85, 2.15, 0.075, 0.8],
		"media_melena": [0.95, 1.95, 2.2, 0.05, 0.4],
		"calvo": [1.15, 1.8, 2.15, 0.05, 0.25],
		"coleta": [0.95, 1.8, 2.1, 0.03, 0.25],
		"melena": [0.9, 2.0, 2.3, 0.05, 0.45],
		"flequillo": [1.25, 2.0, 2.3, 0.05, 0.45],
		"moño": [0.95, 1.8, 2.1, 0.03, 0.25],
		"corta": [0.95, 2.05, 2.25, 0.055, 0.4],
	}
	var c: Array = cfg.get(estilo, cfg["corto"])
	var hasta: float = lerpf(lerpf(c[2], c[1], lado), c[0], pow(frente, 1.6))
	if theta > hasta:
		return 0.0
	if estilo == "calvo" and theta < 1.08 + 0.28 * (1.0 - frente):
		return 0.0  # la coronilla y la frente, al aire
	var borde := clampf((hasta - theta) / 0.18, 0.0, 1.0)
	var grosor: float = c[3] * (0.35 + 0.65 * borde)
	# surcos de mechones (y rizos, en las dos direcciones)
	var bulto: float = c[4]
	if estilo == "rizos":
		grosor *= 1.0 + bulto * 0.5 * (sin(phi * 11.0) * sin(theta * 12.0))
	else:
		grosor *= 1.0 + bulto * 0.35 * sin(phi * 18.0 + theta * 4.0)
	if hat and theta < 1.1:
		grosor = minf(grosor, 0.02)
	elif estilo == "tupe":
		# el tupé: abulta delante arriba
		grosor += 0.13 * exp(-pow((theta - 0.55) / 0.3, 2.0)) * pow(frente, 3.0)
	elif estilo == "flequillo":
		pass
	return grosor
