class_name Npc
extends Actor
## Bot del barrio. Cada tipo tiene su forma de moverse y sus frases;
## las interacciones con el jugador están en interactions.gd.
## Ven en un cono tapado por los edificios y se acuerdan de lo que les has hecho: según eso
## te persiguen, te denuncian, se apartan o se acercan (ver grudge() y react()).

signal caught_player(npc: Npc)

## speed en metros por segundo; wander en casillas (2 m).
## hours = [desde, hasta) en horas del día (puede pasar de medianoche); sin hours, a todas horas.
## zone = dónde viven: "rambla", "rambla_raval", "bares", "plazas", "macba", "robadors",
## "musica", "pintores", "estatuas" (ver World.ZONE_STREETS y World._zone_cell).
## disguise = cómo se le ve hasta que hablas con él (las secretas, hasta que actúan);
## bios = historia de cada nombre. still = se queda quieto sin mirar a los lados (estatuas);
## bed = tipo de lugar del mapa donde pasa la noche (ver World._spawn_npc).
## women = nombres que son de mujer; either = nombres que no dicen el género (se elige al
## azar, pero siempre el mismo para ese nombre); el resto son hombres. label_f = etiqueta en
## femenino si cambia. looks = rasgos fijos de algún nombre (ver Actor.look).
## Los tipos nuevos se basan en fenómenos documentados del barrio (fuentes en docs/ideas.md).
const KINDS := {
	"turista": {
		"label": "Turista", "speed": 10.4, "wander": 80, "accessory": "mochila",
		"names": ["Kevin", "Sven", "Giulia", "Brad", "Ingrid", "Pierre", "Hannah"],
		"women": ["Giulia", "Ingrid", "Hannah"],
		"lines": ["Is this the real Barcelona?", "Where is the Sagrada Familia?", "So authentic!", "Una cerveza, please"],
	},
	"camello": {
		"label": "Camello", "speed": 12.0, "wander": 8, "accessory": "capucha",
		"names": ["El Rata", "Chino", "El Tuerto", "Nene", "Boli", "El Primo"],
		"lines": ["Chocolate, maría...", "¿Qué buscas, amigo?", "Sssst, ven aquí", "Aquí no, muévete"],
	},
	# La policía, en dos cuerpos con sus competencias (ver Defs.CRIME_CORPS): la Guàrdia
	# Urbana (del Ajuntament: convivencia y ordenanzas) y los Mossos d'Esquadra (de la
	# Generalitat: delitos, orden público y detenciones). Cada uno con agentes de paisano.
	"urbano": {
		"label": "Agente de la Urbana", "speed": 14.4, "wander": 120, "accessory": "gorra_poli",
		"names": ["Agente Puig", "Agente Soler", "Agente Romero", "Agente Vidal", "Agente Ferrer", "Agente Navarro"],
		"either": ["Agente Puig", "Agente Soler", "Agente Romero", "Agente Vidal", "Agente Ferrer", "Agente Navarro"],
		"lines": ["Circulen.", "Aquí no se puede beber.", "Recoja eso, por favor.", "¿Todo bien por aquí?", "Esto es vía pública."],
	},
	"mosso": {
		"label": "Mosso d'Esquadra", "label_f": "Mossa d'Esquadra", "speed": 14.4, "wander": 140, "accessory": "gorra_poli",
		"names": ["Agent Casals", "Agent Rius", "Agent Moreno", "Agent Prats", "Agent Gil"],
		"either": ["Agent Casals", "Agent Rius", "Agent Moreno", "Agent Prats", "Agent Gil"],
		"lines": ["Documentació, si us plau.", "Documentación.", "¿Ha visto algo?", "Apártese, por favor.", "Mossos. Quieto ahí."],
	},
	"urbano_secreta": {
		"label": "Urbana de paisano", "speed": 12.0, "wander": 50, "accessory": "mochila", "disguise": "turista",
		"hours": [9, 23], "zone": "rambla",
		"names": ["Toni", "Cristina", "Marcos", "Eva"],
		"women": ["Cristina", "Eva"],
		"lines": ["Is this the Boqueria?", "*mira el móvil*", "*se toca la oreja*", "Sorry, sorry"],
		"bios": {
			"Toni": "Seis años en la unidad de paisano de la Guàrdia Urbana en Ciutat Vella. Conoce de vista a todos los carteristas de la Rambla y ellos, cada vez más, a él.",
			"Cristina": "Va de guiri con una mochila y un mapa al revés. En el metro de Liceu se baja y se sube del mismo vagón hasta que alguien mete la mano donde no debe.",
		},
	},
	"mosso_secreta": {
		"label": "Mosso de paisano", "label_f": "Mossa de paisano", "speed": 12.0, "wander": 40, "disguise": "vecino",
		"accessory": "", "zone": "robadors",
		"names": ["Jordi", "Sílvia", "Rubén", "Laura"],
		"women": ["Sílvia", "Laura"],
		"lines": ["Voy al mercado", "*hace como que lee el periódico*", "*se toca la oreja*", "Uf, qué calor"],
		"bios": {
			"Rubén": "De la unidad de investigación de los Mossos en Ciutat Vella. Lleva tres semanas apuntando quién entra y quién sale de un narcopiso de la calle d'en Robador.",
			"Laura": "Se hace pasar por vecina con el carro de la compra. Los camellos la saludan; ella les sonríe y apunta matrículas.",
		},
	},
	"yonki": {
		"label": "Yonki", "speed": 8.8, "wander": 50, "accessory": "",
		"names": ["El Lolo", "Manoli", "El Cuervo", "Toni Calcetines", "La Yoli", "El Pirata"],
		"women": ["Manoli", "La Yoli"],
		"lines": ["¿Tienes un euro, primo?", "Ayer vi a Dios en un cajero", "Esto antes era otra cosa", "¿Fuego?"],
	},
	"educador": {
		"label": "Educador social", "label_f": "Educadora social", "speed": 11.2, "wander": 60, "accessory": "chaleco", "hours": [9, 21],
		"names": ["Núria", "Marc", "Laia", "Oriol"],
		"women": ["Núria", "Laia"],
		"lines": ["¿Has pasado por el Baluard?", "Si necesitas algo, aquí estamos", "¿Has comido hoy?"],
	},
	"vecino": {
		"label": "Vecino", "label_f": "Vecina", "speed": 9.6, "wander": 30, "accessory": "", "hours": [7, 23],
		"names": ["Sra. Pepita", "Sr. Antonio", "Fatima", "Rajesh", "Montse"],
		"women": ["Sra. Pepita", "Fatima", "Montse"],
		"looks": {
			"Sra. Pepita": {"hair": Color("d8d8d8"), "hair_style": "moño", "skirt": true, "glasses": true},
			"Sr. Antonio": {"hair": Color("c8c8c8"), "hair_style": "calvo", "facial": "bigote", "jacket": Color("5a4a3a")},
		},
		"lines": ["¡Esto es una vergüenza!", "Que no se puede vivir", "Voy al mercado", "¡Ese portal no es un baño!"],
	},
	"mantero": {
		"label": "Mantero", "speed": 12.8, "wander": 20, "accessory": "",
		"names": ["Moussa", "Ibrahima", "Lamine", "Cheikh"],
		"lines": ["Gafas, bolsos, barato", "Amigo, mira", "¡Agua! ¡Water!"],
	},
	"fiestero": {
		"label": "De despedida", "speed": 9.0, "wander": 25, "accessory": "despedida",
		"hours": [22, 5], "zone": "bares",
		"names": ["Dani", "Tom", "Lukas", "Chloe", "Marco", "Aitor", "Jess"],
		"women": ["Chloe", "Jess"],
		"looks": {
			"Dani": {"hair": Color("ff7ac0"), "hair_style": "melena"},  # la peluca rosa
			"Chloe": {"skirt": true, "hair_style": "melena", "hair": Color("e8c860")},
		},
		"lines": ["¡Que se casa! ¡Que se casa!", "One more beer!", "¿Dónde está la fiesta?", "¡Uno más y nos vamos!", "*vomita en un portal*"],
		"bios": {
			"Dani": "Se casa el sábado en Valladolid. Sus amigos le han puesto una peluca rosa y le han hecho prometer que no llamará a su novia hasta el domingo.",
			"Chloe": "Vuelo low cost desde Mánchester por 19 libras. Lleva una banda de «Bride to be» y no ha visto la Sagrada Familia ni de lejos.",
			"Aitor": "Es el único sobrio del grupo: le toca devolverlos al apartamento turístico. Cuenta las horas.",
		},
	},
	"latero": {
		"label": "Latero", "speed": 10.0, "wander": 15, "accessory": "bolsa",
		"hours": [20, 5], "zone": "bares",
		"names": ["Shahid", "Imran", "Bilal", "Rafiq", "Nasir"],
		"lines": ["¡Cerveza, beer!", "Un euro, amigo", "Fría, fría", "¿Cervezabeer?"],
		"bios": {
			"Shahid": "Estudió contabilidad. Lleva ocho años en Barcelona esperando papeles; manda a casa lo que saca y duerme cuatro horas.",
			"Imran": "Fue cocinero en un restaurante del Born hasta que cerró. Las latas las guarda en una alcantarilla para que no se las requisen... ni se calienten.",
			"Bilal": "Tiene diecinueve años y paga 150 € al mes por un colchón en un piso de la calle del Hospital. Su madre cree que trabaja en una tienda.",
			"Rafiq": "Vino con un contrato de temporero en Lleida que nunca existió. Las latas son lo único que le salió.",
			"Nasir": "La Guàrdia Urbana le ha quitado tantas latas que ya no las cuenta. Vuelve a por más al súper de enfrente.",
		},
	},
	"trilero": {
		"label": "Trilero", "label_f": "Trilera", "speed": 12.0, "wander": 2, "accessory": "caja",
		"hours": [10, 20], "zone": "rambla",
		"names": ["El Profesor", "Pecas", "Ciri", "Manolo Cubiletes"],
		"either": ["Pecas", "Ciri"],
		"looks": {"El Profesor": {"glasses": true, "hair": Color("9a9a9a"), "facial": "barba"}},
		"lines": ["¿Dónde está la bolita?", "¡Mira, mira, que gana!", "Cincuenta, doble o nada", "¡Agua! ¡Recoge!"],
		"bios": {
			"El Profesor": "Treinta años moviendo cubiletes en la Rambla. Dice que el truco no está en las manos, sino en los ganchos que fingen ganar.",
			"Pecas": "Empezó de vigía con catorce años. Ahora tiene la mesa y dos chavales que le avisan de la Urbana.",
		},
	},
	"carterista": {
		"label": "Carterista", "speed": 11.5, "wander": 40, "accessory": "mochila", "disguise": "turista",
		"hours": [9, 21], "zone": "rambla",
		"names": ["Sandra", "Dedos", "Nico", "La Sombra", "Manu"],
		"women": ["Sandra"],
		"either": ["La Sombra", "Manu"],
		"lines": ["Excuse me, the map...", "Perdona, ¿la Boqueria?", "Sorry, sorry"],
		"bios": {
			"Sandra": "Treinta y tantas detenciones y ninguna condena larga: robar menos de 400 € es delito leve. Lo sabe y lo cuenta riéndose.",
			"Dedos": "Trabaja la Rambla por la mañana y el metro por la tarde. Va vestido de guiri, con mapa y todo.",
			"La Sombra": "Le han prohibido entrar en el metro. Desde entonces se ha mudado a la Boqueria.",
		},
	},
	"chaval": {
		"label": "Chaval", "speed": 12.0, "wander": 30, "accessory": "gorra", "size": 0.8,
		"hours": [15, 3], "zone": "rambla_raval",
		"names": ["Anas", "Yassin", "Hamza", "Ilyas", "Omar"],
		"lines": ["¿Tienes un cigarro?", "Un euro, hermano", "*huele a disolvente*", "No pasa nada, no pasa nada"],
		"bios": {
			"Anas": "Quince años. Se escapó de un centro de acogida y duerme en un portal de Sant Pau. Dice que la cola le quita el hambre y el frío.",
			"Yassin": "Cruzó escondido bajo un camión para trabajar y mandar dinero a casa. Aquí nadie contrata a un menor.",
			"Hamza": "Tiene un cuaderno donde apunta palabras en castellano. Va por la página doce.",
			"Ilyas": "Las educadoras de calle le conocen por su nombre. Algunos días va con ellas; otros, no.",
			"Omar": "Dieciséis años. Quiere ser mecánico. Cuando habla de motos se le olvida la bolsa.",
		},
	},
	"nino": {
		"label": "Niño", "label_f": "Niña", "speed": 9.0, "wander": 10, "accessory": "", "size": 0.62,
		"hours": [9, 21], "zone": "plazas",
		"names": ["Aisha", "Pau", "Adam", "Rania", "Joel", "Marina", "Kiko", "Mei"],
		"women": ["Aisha", "Rania", "Marina", "Mei"],
		"lines": ["¡Pásala!", "¡Gooool!", "¡Eso es mano!", "Mi madre dice que no hable contigo", "¿Por qué hueles raro?"],
		"bios": {
			"Aisha": "Nueve años. Le hace de traductora a su madre en el CAP y en las reuniones del colegio. Habla cuatro idiomas y medio.",
			"Pau": "Juega a la pelota en la plaza entre los skaters del MACBA. Ya sabe qué jeringuillas no se tocan.",
			"Rania": "Vive con sus padres y sus dos hermanos en un piso de una habitación. Hace los deberes en la biblioteca hasta que cierra.",
			"Mei": "Sus padres tienen un colmado que abre hasta las doce. Ella baja a jugar mientras ellos atienden.",
		},
	},
	"anciano": {
		"label": "Abuelo", "label_f": "Abuela", "speed": 5.5, "wander": 14, "accessory": "baston",
		"hours": [8, 21],
		"names": ["Sra. Remei", "Sr. Joan", "Sra. Carmen", "Sr. Paco", "Sra. Lola", "Sr. Ginés"],
		"women": ["Sra. Remei", "Sra. Carmen", "Sra. Lola"],
		"lines": ["Esto antes era otra cosa", "¡Ay, mis rodillas!", "¿Has visto a mi nieto?", "Aquí ya no queda nadie de antes", "Voy a la farmacia"],
		"bios": {
			"Sra. Remei": "Ochenta y cuatro años en el mismo piso de la calle de la Cera, un cuarto sin ascensor. El fondo que compró el edificio le ofrece dinero por irse. Dice que de ahí la sacan con los pies por delante.",
			"Sr. Joan": "Fue estibador en el puerto. Baja cada mañana a la plaza a leer el periódico en el banco y a contar quién se ha ido del barrio.",
			"Sra. Carmen": "Llegó de Jaén en el 62 y cosió en un taller del barrio cuarenta años. Vive sola; la llama una voluntaria los martes.",
			"Sr. Ginés": "Viudo desde hace seis años. Come en el menú del bar de abajo y le dejan pagar a final de mes.",
		},
	},
	"perro": {
		"label": "Perro", "label_f": "Perra", "speed": 11.0, "wander": 3, "accessory": "",
		"names": ["Bobby", "Lola", "Rocky", "Canela", "Thor", "Kira", "Chispa", "Negro"],
		"women": ["Lola", "Canela", "Kira", "Chispa"],
		"lines": ["¡Guau!", "*olfatea*", "*mueve la cola*", "¡Grrr!"],
	},
	"mensajero": {
		"label": "Repartidor", "label_f": "Repartidora", "speed": 17.0, "wander": 120, "accessory": "reparto",
		"hours": [11, 24],
		"names": ["Karim", "Ana Lucía", "Jhon", "Arif", "Mamadou", "Yeison"],
		"women": ["Ana Lucía"],
		"lines": ["¡Paso, paso!", "Llego tarde, llego tarde", "¿El portal 14?", "*mira el móvil*"],
		"bios": {
			"Karim": "Reparte con la cuenta de otro, que se queda un tercio de lo que saca. Sin papeles no puede tener la suya.",
			"Ana Lucía": "Era ingeniera en Venezuela. Aquí hace doce horas en bici y cobra por pedido, unos pocos euros cada uno.",
			"Jhon": "Se cayó de la bici en la Ronda y nadie le cubrió la baja: para la aplicación era autónomo.",
			"Mamadou": "Comparte la bici y la cuenta con su primo: él de día, el primo de noche.",
		},
	},
	"pudiente": {
		"label": "Pijo", "label_f": "Pija", "speed": 10.0, "wander": 60, "accessory": "",
		"hours": [10, 2],
		"names": ["Borja", "Cayetana", "Tobias", "Olivia", "Jean-Baptiste", "Marc"],
		"women": ["Cayetana", "Olivia"],
		"lines": ["Qué barrio tan auténtico", "¿Dónde era el restaurante?", "Uf, qué olor", "Agarra bien el bolso"],
		"bios": {
			"Tobias": "Nómada digital de Berlín. Paga 1.900 € al mes por un estudio en la Riera Alta y dice que el barrio tiene «mucha vida».",
			"Cayetana": "Va al Liceu los jueves y aparca en la Rambla. Del Raval solo conoce el tramo hasta la puerta.",
			"Marc": "Compra pisos enteros para convertirlos en alquiler de temporada. Hoy viene a ver uno en la calle de la Cera.",
			"Olivia": "Diseñadora en un estudio junto al MACBA. Le encanta el barrio, pero lleva el bolso cruzado.",
			"Jean-Baptiste": "Coleccionista de arte. Viene a una inauguración en el MACBA; su chófer le espera en la Rambla.",
		},
	},
	# --- fauna de la calle (fuentes en docs/ideas.md)
	"musico": {
		"label": "Músico", "label_f": "Música", "speed": 9.0, "wander": 0, "accessory": "guitarra",
		"hours": [10, 23], "zone": "musica",
		"names": ["Iosif", "Lucía", "Pere", "Abdou", "Martina"],
		"women": ["Lucía", "Martina"],
		"lines": ["*toca «Bésame mucho»*", "Gràcies, gràcies!", "Una monedita para la música", "Esta es para los enamorados", "*afina*"],
		"bios": {
			"Iosif": "Toca el acordeón en la plaça del Pi desde hace veinte años. En Bucarest daba clases de solfeo; aquí se sabe de memoria lo que piden los guiris: «Bésame mucho» y la de El Padrino.",
			"Lucía": "Estudia en el Conservatori del Liceu y toca el violonchelo en la calle los fines de semana para pagar la habitación. Pasó la prueba para tener uno de los puntos de Música al Carrer.",
			"Pere": "Cantautor de los ochenta. Grabó un disco que nadie recuerda; él sí. Canta en catalán junto al MACBA y vende el CD a cinco euros.",
			"Abdou": "Toca el djembé con dos amigos. Cuando llegan los skaters se pican a ver quién hace más ruido, y los vecinos de Ferlandina les gritan a los dos.",
			"Martina": "Llegó de Rosario con una guitarra y un visado de estudiante. Toca tangos a la salida del Liceu y dice que la Rambla tiene mejor acústica que su piso.",
		},
	},
	"estatua": {
		"label": "Estatua humana", "speed": 6.0, "wander": 0, "accessory": "platillo", "still": true,
		"hours": [10, 20], "zone": "estatuas",
		"names": ["El Hombre de Plata", "La Dama de Bronce", "Rui", "Gerardo"],
		"women": ["La Dama de Bronce"],
		"lines": ["*inmóvil*", "*ni pestañea*", "*guiña un ojo*", "*inmóvil*"],
		"bios": {
			"El Hombre de Plata": "Lleva veinte años pintándose de plata cada mañana en un portal de la calle Nou de la Rambla. Desde que el Ajuntament mandó las estatuas al tramo de abajo, junto a Colom, saca la mitad.",
			"La Dama de Bronce": "Bailarina de formación. Aguanta dos horas sin moverse y, cuando le cae una moneda, hace la reverencia que aprendió en el Institut del Teatre.",
			"Rui": "Tiene la licencia de estatua humana, que se reparte por concurso. Dice que lo más duro no es estarse quieto, sino el viento que baja del puerto en invierno.",
		},
	},
	"mendigo": {
		"label": "Sin techo", "speed": 6.5, "wander": 3, "accessory": "carton", "bed": "cajero",
		"names": ["Ramón", "Mercè", "Andrzej", "Fina", "Ousmane"],
		"women": ["Mercè", "Fina"],
		"lines": ["Una ayuda, por favor", "Buenos días, que tenga un buen día", "*cuenta las monedas del vaso*", "Gracias, guapa", "¿Me da algo para un café?"],
		"bios": {
			"Ramón": "Fue camionero treinta años. Una hernia, el paro, el divorcio y el desahucio, por ese orden. Duerme en un cajero y lo deja limpio antes de que abra la oficina.",
			"Mercè": "Sesenta y un años. Pide en la puerta de Betlem con un vaso de cartón y saluda a todo el mundo por su nombre. Los voluntarios de Arrels le traen la cena y la cuentan en el recuento de cada invierno.",
			"Andrzej": "Vino a trabajar en la obra del Fòrum. Ahora vive en un portal con las mantas bien dobladas y habla de volver a Gdańsk cuando haga calor.",
			"Fina": "Se quedó en la calle al dejar a su pareja, que le pegaba. Prefiere un portal a un albergue lleno de hombres. Duerme poco y con un ojo abierto.",
			"Ousmane": "Tiene papeles y un título de electricista que aquí no le convalidan. Sin nómina no hay piso, y sin piso no hay nómina.",
		},
	},
	"skater": {
		"label": "Skater", "speed": 16.0, "wander": 10, "accessory": "skate",
		"hours": [12, 22], "zone": "macba",  # de 22 a 9 no se puede patinar en la plaza (2023)
		"names": ["Biel", "Noa", "Jonas", "Yuki", "Bruno"],
		"women": ["Noa"],
		"lines": ["*clac* ¡Uooo!", "¡Casi!", "Otra vez, otra vez", "Aparta, que voy", "¿Lo has grabado?"],
		"bios": {
			"Biel": "Patina en la plaça dels Àngels desde los doce años. Los vecinos firman quejas por el ruido del mármol; su madre es una de ellas.",
			"Jonas": "Vino de Copenhague tres semanas para grabar un vídeo en el MACBA, la plaza más famosa del skate europeo. Lleva dos años durmiendo en sofás.",
			"Noa": "La única de su grupo que salta la escalera grande. Pone cafés por la mañana y por la tarde se deja las rodillas en el suelo del museo.",
			"Yuki": "Fotógrafo de skate. Dice que la fachada del MACBA sale en más vídeos que todas las obras que hay dentro.",
		},
	},
	"captador": {
		"label": "Captador", "label_f": "Captadora", "speed": 10.0, "wander": 12, "accessory": "folletos",
		"hours": [17, 3], "zone": "rambla",
		"names": ["Leo", "Bianca", "Kenny", "Sofía"],
		"women": ["Bianca", "Sofía"],
		"lines": ["Party tonight? Free entrance!", "Cannabis club, my friend? Members only", "Pub crawl, free shots!", "Hey guys, where are you from?"],
		"bios": {
			"Bianca": "Licenciada en Turismo en Nápoles. Cobra unos euros por cada guiri que entra en la discoteca con su flyer; si no llega a veinte en la noche, no le pagan ni el bus.",
			"Leo": "Ofrece «cannabis club, members only» a media voz. Sabe que captar socios en la calle está prohibido y que la Urbana tiene a gente de paisano para eso: cambia de esquina cada media hora.",
			"Kenny": "Lleva la ruta de bares de los martes: doce bares, un chupito en cada uno y cuarenta guiris a su cargo. A las tres le toca recogerlos del suelo.",
			"Sofía": "Reparte flyers de un club de la calle Escudellers. Odia el trabajo y adora a sus compañeros; entre todos se avisan de los carteristas.",
		},
	},
	"rosero": {
		"label": "Rosero", "label_f": "Rosera", "speed": 9.0, "wander": 25, "accessory": "rosas",
		"hours": [20, 3], "zone": "bares",
		"names": ["Habib", "Sumon", "Joy", "Anwar"],
		"lines": ["¿Rosa, señorita?", "Una rosa para la novia", "Dos euros, amigo", "*ofrece una rosa*", "¿Foto? ¿Luz?"],
		"bios": {
			"Habib": "Compra las rosas por la mañana a mayoristas y las vende de noche por las terrazas. Si a las tres le quedan, se las regala a la última pareja que ve: dice que trae suerte.",
			"Sumon": "Estudió informática. Vende rosas de noche y por la mañana va a clase de catalán; ya lo habla mejor que muchos del barrio.",
			"Joy": "Tiene veintidós años y una sonrisa que vende más que las rosas. Comparte habitación con cinco compañeros en la calle de l'Hospital.",
			"Anwar": "Lleva quince años por las terrazas de la plaça Reial y del Raval. Los camareros le conocen y le dejan usar el baño.",
		},
	},
	"chatarrero": {
		"label": "Chatarrero", "label_f": "Chatarrera", "speed": 8.0, "wander": 90, "accessory": "carro",
		"hours": [7, 22],
		"names": ["Pap", "Viorel", "Paco", "Lamin", "Mirela"],
		"women": ["Mirela"],
		"lines": ["¡Hierro, chatarra!", "¿Eso lo tiras?", "*empuja el carro*", "El cobre está caro, ¿eh?"],
		"bios": {
			"Pap": "Recorre el barrio con un carro de supermercado cargado de somieres y radiadores. Vivió en una nave del Poblenou con cientos de chatarreros hasta que la desalojaron.",
			"Viorel": "Sale a las siete con el carro y su mujer, Mirela, cada uno por un lado. Sabe qué noche saca la gente los trastos en cada calle.",
			"Paco": "Setenta años y una pensión que no llega. Vende la chatarra para el tabaco y, dice, para que no se le olvide andar.",
			"Mirela": "Se conoce los contenedores de obra de todo Ciutat Vella. Separa el cobre, el aluminio y el hierro mejor que la planta de reciclaje.",
		},
	},
	"trabajadora_sexual": {
		"label": "Trabajadora sexual", "speed": 8.0, "wander": 4, "accessory": "",
		"hours": [11, 5], "zone": "robadors",
		"names": ["Mari Carmen", "Precious", "Ioana", "Valeria", "Lorena"],
		"women": ["Mari Carmen", "Precious", "Ioana", "Valeria", "Lorena"],
		"looks": {
			"Mari Carmen": {"hair": Color("c8a060"), "hair_style": "melena", "skirt": true},
			"Valeria": {"hair_style": "melena", "skirt": true},
		},
		"lines": ["Hola, cariño", "Si no vas a subir, no te pares aquí", "Hoy no hay nadie...", "¿Has visto a la Urbana?"],
		"bios": {
			"Mari Carmen": "Treinta años en la calle d'en Robador. Ha visto tirar medio barrio para abrir la Rambla del Raval; ella sigue en el mismo portal y paga la habitación por horas.",
			"Precious": "Llegó con una deuda enorme con quien la trajo y la paga a plazos. Las de la asociación le han hablado de una abogada; todavía no se atreve.",
			"Ioana": "Tiene un hijo de seis años con su madre, en Constanța. Le dicen que trabaja de camarera. Hace las revisiones en una asociación del barrio.",
			"Valeria": "Mujer trans con estudios de enfermería. La echaron de dos trabajos al ver su nombre antiguo en el DNI. Es la que avisa a las demás cuando un cliente se pone violento.",
			"Lorena": "Trabaja de día para recoger a su hija del colegio a las cinco. La Urbana le ha puesto dos multas por la ordenanza; las dos las ha recurrido.",
		},
	},
	"guia": {
		"label": "Guía", "speed": 7.5, "wander": 60, "accessory": "paraguas",
		"hours": [10, 19], "zone": "rambla",
		"names": ["Marta", "Giorgio", "Clara", "Álex"],
		"women": ["Marta", "Clara"],
		"lines": ["Follow me, please!", "Here, in 1920...", "Stay together, guys!", "This is the real Barcelona", "At the end, you pay what you think it's worth"],
		"bios": {
			"Marta": "Historiadora del arte. Hace tres free tours al día por el Gòtic y el Raval y vive de las propinas; la plataforma donde se apuntan los guiris también se lleva su parte.",
			"Giorgio": "Cuenta la historia del barrio chino y de la Bella Dorita con tanto teatro que algunos guiris aplauden. En Ciutat Vella el grupo no puede pasar de quince ni llevar megáfono.",
			"Clara": "Lleva un paraguas amarillo para que el grupo no la pierda. Los vecinos le gritan desde los balcones; ella les da la razón en voz baja.",
			"Álex": "Hace la ruta del «Raval canalla»: los antiguos burdeles, los bares de marineros, la Criolla. Cuando pasa por delante de un narcopiso, acelera.",
		},
	},
	"caricaturista": {
		"label": "Caricaturista", "speed": 7.0, "wander": 0, "accessory": "caballete",
		"hours": [10, 20], "zone": "pintores",
		"names": ["Ernesto", "Anaïs", "Hyun", "Jaume"],
		"women": ["Anaïs"],
		"looks": {"Ernesto": {"hair": Color("b8b8b8"), "facial": "barba", "glasses": true}},
		"lines": ["Caricature? Ten minutes!", "¿Un retrato, señora?", "Quieto, no se mueva", "*dibuja*", "Sonría, que sale mejor"],
		"bios": {
			"Ernesto": "Dibuja caricaturas en la Rambla desde antes de los Juegos Olímpicos. Tiene una de las licencias municipales y el taburete de un compañero que se jubiló.",
			"Anaïs": "Estudió Bellas Artes en Toulouse. Pinta acuarelas de la plaça del Pi que los guiris compran por veinte euros; sus cuadros de verdad no los compra nadie.",
			"Hyun": "Hace retratos a lápiz en diez minutos. Los turistas coreanos le hacen cola porque les habla en su idioma.",
			"Jaume": "Lleva una libreta con caricaturas de todos los vecinos que se han ido del barrio. Dice que es su censo.",
		},
	},
	"punki": {
		"label": "Punki", "speed": 9.0, "wander": 25, "accessory": "cresta",
		"hours": [11, 4], "zone": "plazas",
		"names": ["Txus", "Klaus", "Raquel", "Moco"],
		"women": ["Raquel"],
		"lines": ["Unas monedas pa' los perros", "¡Oi! ¡Oi!", "Ni dios ni amo", "Tranqui, que no muerde... mucho", "*bebe del litro*"],
		"bios": {
			"Txus": "De Irún. Lleva desde los noventa en la calle con sus perros, Kaos y Bruja. En el albergue no admiten perros, así que duerme donde duermen ellos.",
			"Klaus": "Vino de Hamburgo a un festival en 2009 y no se fue. Toca la armónica fatal y lo sabe; pide «para los perros» y es verdad.",
			"Raquel": "Vivía en una casa okupada de la calle de la Cera hasta el desalojo. Hace malabares en los semáforos del Paral·lel y comparte el bocadillo con su perra.",
			"Moco": "Veintitrés años, el pelo verde, una beca de Bellas Artes que perdió y un perro que no pierde nunca.",
		},
	},
}
## Tipos de bot que pasean un perro a veces (World lo saca con ellos) y con qué probabilidad.
## Por encima de 1, más de uno: el punki lleva siempre uno y a menudo dos (1.6).
const DOG_OWNERS := {"vecino": 0.3, "anciano": 0.35, "yonki": 0.3, "pudiente": 0.2, "punki": 1.6, "mendigo": 0.15}
## La policía: los dos cuerpos, de uniforme y de paisano, y a cuál pertenece cada tipo.
const POLICE := {"urbano": "urbana", "urbano_secreta": "urbana", "mosso": "mossos", "mosso_secreta": "mossos"}
const CORPS_NAMES := {"urbana": "la Guàrdia Urbana", "mossos": "los Mossos"}
const DOG_FURS := [Color("6b4426"), Color("1c1a18"), Color("e8e0d0"), Color("c8963c"), Color("8a8a8a")]

const SKINS := [Color("f0cfb0"), Color("e0b08a"), Color("c68c5e"), Color("8d5a3b"), Color("5a3a26")]
const HAIR_COLORS := [Color("1b1410"), Color("3a2418"), Color("5a3a20"), Color("8a5a30"), Color("c8a060"), Color("7a7a7a")]
## Probabilidades de cada rasgo. Las tiradas dependen del nombre: el mismo personaje
## sale siempre igual, para que lo reconozcas al volver a verlo.
const P_BEARD := 0.3
const P_MOUSTACHE := 0.12
const P_GLASSES := 0.15
const P_JACKET := 0.35
const P_SKIRT := 0.35
## Tipos que van de uniforme (sin chaqueta ni falda).
const UNIFORMED := ["urbano", "mosso", "educador"]
const THINK_TIME := 0.25  ## cada cuánto miran y deciden (segundos)
## Colores del cono de visión: tranquilo, con sospecha y persiguiéndote.
const C_CONE_CALM := Color(0.6, 0.9, 1.0, 0.16)
const C_CONE_ALERT := Color(1.0, 0.85, 0.2, 0.3)
const C_CONE_CHASE := Color(1.0, 0.25, 0.2, 0.34)
const CONE_RAYS := 16  ## rayos del abanico (más, mejor recorte contra las esquinas)

var kind := "turista"
var gender := "m"  ## "m" o "f", según el nombre (ver KINDS)
var home := Vector2i.ZERO
var wander_radius := 20
var money := 0
var debt := 0  ## Lo que le debe el jugador (camellos)
var player: Actor
var world: World
var robbed := false  ## Ya le han robado (turistas), tú o un carterista
var last_interaction_day := -1
## Personaje único hecho con el editor de personajes (ver Personajes); vacío en los bots corrientes.
var personaje := {}
## "tipo|nombre" de los personajes del editor: los bots corrientes no salen con esos nombres,
## para que un personaje que sustituye a un bot del juego no salga repetido.
static var reservados := {}
var _zona: Array[Vector2i] = []  ## casillas por las que anda, si su zona es un polígono dibujado
var known := false  ## Ya has hablado con él (los disfrazados dejan de parecer lo que no son)
## Lo que ha pasado contigo: "pedido", "robado", "ayudado", "pegado", y del trapicheo
## (scripts/trade.gd) "cliente", "timado" (le vendiste cortado o una piedra) y "pisado" (un
## camello que te vio vender en su esquina) -> veces. Decide cómo
## reacciona al verte (ver grudge()).
var memory := {}
## Lo que está haciendo por ti: "" (su vida), "persigue", "busca" (donde te vio por última
## vez), "aparta" (se quita de en medio), "denuncia" (va a por un policía), "acerca" (a saludar).
var mode := ""
var chase_reason := ""  ## por qué te persigue: "policia", "deuda", "venganza", "parar"
var alert := 0.0  ## 0..1: la sospecha mientras te ve; llena, reacciona
var sees_player := false
var last_seen := Vector2i.ZERO  ## casilla donde te vio por última vez
var debt_due := 0.0  ## now() a partir del cual el camello viene a cobrar lo fiado
## Si se dibuja su cono de visión en el suelo (lo decide World según la distancia y la tecla V).
var cone_visible := false
var amo: Npc  ## (perros, el grupo de un guía o de una despedida, niños con un adulto) a quién siguen; World los retira cuando se va
var bed := Vector2i(-1, -1)  ## (KINDS[...]["bed"]) dónde pasa la noche; -1 si no tiene sitio
var _still_until := 0.0  ## (estatuas) hasta entonces se mueve: le han echado una moneda
var on_screen := true  ## lo pone World: fuera de la pantalla se actualiza menos (ver _process)
var _offscreen_dt := 0.0
var _offscreen_frame := randi()  ## desfasado para que no les toque a todos en el mismo frame
var chasing: bool:
	get:
		return mode == "persigue"

var _idle := 0.0
var _think := 0.0
var _chatter := randf_range(8.0, 30.0)
var _lost := 0.0  ## segundos persiguiéndote sin verte
var _search := 0.0  ## segundos que le quedan buscándote
var _hunt := 0.0  ## (mode "viene") segundos que le quedan viniendo a por ti
var _hunt_why := ""  ## (mode "viene") a qué viene: "cobrar"
var _calm_until := 0.0  ## (segundos de reloj) hasta entonces no vuelve a reaccionar
var _look_yaw := 0.0  ## hacia dónde gira la cabeza cuando está parado
var _look_timer := 0.0
var _cone: MeshInstance3D
var _cone_mesh: ImmediateMesh
var _cone_timer := 0.0
var _denounce_to: Npc  ## el agente al que va a contarle lo que le hiciste

static var _cone_material: StandardMaterial3D


## Prepara un bot del tipo `p_kind`; sin `p_name`, con uno de sus nombres al azar.
func init_kind(p_kind: String, p_name := "") -> void:
	kind = p_kind
	var k: Dictionary = KINDS[kind]
	display_name = p_name if p_name != "" else _pick_name(p_kind)
	speed = k["speed"]
	wander_radius = k["wander"]
	accessory = k["accessory"]
	body_size = k.get("size", 1.0)
	# el aspecto sale del nombre: quien vuelve a salir con el mismo nombre se ve igual
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind + "|" + display_name)
	gender = "f" if display_name in k.get("women", []) else "m"
	if display_name in k.get("either", []):
		gender = "f" if rng.randf() < 0.5 else "m"
	look = {
		"gender": gender,
		"skin": SKINS[rng.randi_range(0, SKINS.size() - 1)],
		"shirt": Color.from_hsv(rng.randf(), rng.randf_range(0.2, 0.7), rng.randf_range(0.35, 0.85)),
		"pants": Color.from_hsv(rng.randf(), 0.2, rng.randf_range(0.2, 0.5)),
		"hair": HAIR_COLORS[rng.randi_range(0, HAIR_COLORS.size() - 1)],
	}
	_roll_traits(rng)
	# complexión y algo de altura, para que no sean todos iguales (fijas por nombre)
	var r := rng.randf()
	look["build"] = "delgado" if r < Defs.BUILD_THIN else ("grueso" if r < Defs.BUILD_THIN + Defs.BUILD_HEAVY else "")
	body_size *= rng.randf_range(Defs.HEIGHT_RANGE.x, Defs.HEIGHT_RANGE.y)
	match kind:
		"urbano":
			# azul de la Guàrdia Urbana, con la banda de cuadros blancos en la gorra
			look["shirt"] = Color("2a3d7a")
			look["pants"] = Color("1d2a5a")
			look["cap"] = Color("1d2a5a")
			look["cap_band"] = Color("e8ecf4")
		"mosso":
			# azul marino de los Mossos, con el rojo en la gorra
			look["shirt"] = Color("1a2140")
			look["pants"] = Color("141a30")
			look["cap"] = Color("141a30")
			look["cap_band"] = Color("c8202c")
		"urbano_secreta":
			money = randi_range(20, 60)
			look["skin"] = SKINS[rng.randi_range(0, 2)]
			look["shirt"] = Color.from_hsv(rng.randf(), 0.6, 0.95)  # de guiri, como los turistas
		"mosso_secreta":
			money = randi_range(10, 40)
			look["jacket"] = Color.from_hsv(rng.randf(), 0.15, rng.randf_range(0.2, 0.4))
		"musico", "caricaturista", "guia", "captador", "skater":
			money = randi_range(5, 30)
		"estatua":
			# pintado de arriba abajo de un solo color: plata, bronce o dorado
			var paint: Color = [Color("c8ccd0"), Color("9a6a3a"), Color("d8b848")][rng.randi_range(0, 2)]
			if display_name == "El Hombre de Plata":
				paint = Color("c8ccd0")
			elif display_name == "La Dama de Bronce":
				paint = Color("9a6a3a")
			for part in ["skin", "shirt", "pants", "hair"]:
				look[part] = paint
			look["facial"] = ""
			look["glasses"] = false
			look.erase("jacket")
			money = randi_range(5, 20)
		"mendigo":
			money = randi_range(0, 8)
			look["shirt"] = look["shirt"].darkened(0.45)
			look["jacket"] = Color.from_hsv(rng.randf(), 0.15, 0.22)  # el abrigo de siempre
		"rosero", "chatarrero", "trabajadora_sexual":
			money = randi_range(5, 25)
			if kind == "trabajadora_sexual":
				look["skirt"] = true
				look["shirt"] = Color.from_hsv(rng.randf(), 0.7, 0.85)
		"punki":
			money = randi_range(0, 6)
			look["shirt"] = Color("1a1a1a")
			look["jacket"] = Color("101010")  # chupa de cuero
			look["pants"] = [Color("2a2a2a"), Color("8a2020"), Color("3a3a50")][rng.randi_range(0, 2)]
			look["hair"] = [Color("40d040"), Color("e03c8c"), Color("3c8ce0"), Color("e05020")][rng.randi_range(0, 3)]
		"turista":
			money = randi_range(20, 160)
			look["skin"] = SKINS[rng.randi_range(0, 1)]
			look["shirt"] = Color.from_hsv(rng.randf(), 0.6, 0.95)
		"yonki":
			money = randi_range(0, 6)
			look["shirt"] = look["shirt"].darkened(0.4)
		"educador":
			look["shirt"] = Color("e07a30")
		"fiestero":
			money = randi_range(30, 120)
			look["shirt"] = [Color("ff5fa0"), Color("f0f0f0"), Color("40c0f0")][rng.randi_range(0, 2)]
		"latero", "trilero":
			money = randi_range(5, 30)
		"carterista":
			money = randi_range(20, 80)
			look["shirt"] = Color.from_hsv(rng.randf(), 0.6, 0.95)  # de guiri, como los turistas
		"chaval":
			money = randi_range(0, 3)
			look["shirt"] = look["shirt"].darkened(0.3)
			look["facial"] = ""
		"nino":
			money = randi_range(0, 2)
			look["shirt"] = Color.from_hsv(rng.randf(), 0.65, 0.95)
			look["hair"] = HAIR_COLORS[rng.randi_range(0, 4)]  # sin canas
			look["facial"] = ""
			look["glasses"] = false
			look.erase("jacket")
		"anciano":
			money = randi_range(10, 40)
			look["hair"] = [Color("d8d8d8"), Color("b8b8b8"), Color("f0f0f0")][rng.randi_range(0, 2)]
			look["shirt"] = [Color("8a7a5a"), Color("6a6a70"), Color("2a3450"), Color("5a3a2a"), Color("6a2430"), Color("c8bca0")][rng.randi_range(0, 5)]
			if gender == "m":
				look["hair_style"] = "calvo" if rng.randf() < 0.5 else "corto"
			else:
				look["hair_style"] = ["moño", "rizos"][rng.randi_range(0, 1)]
		"mensajero":
			money = randi_range(5, 25)
			look["shirt"] = [Color("ffc81e"), Color("00c8b4")][rng.randi_range(0, 1)]
			look.erase("jacket")
			look["bici"] = rng.randf() < Defs.RIDER_BIKE
		"pudiente":
			money = randi_range(100, 400)
			look["jacket"] = [Color("1e2430"), Color("3a2e26"), Color("e8e2d4")][rng.randi_range(0, 2)]
			look["shirt"] = Color("f4f4f0")
			look["pants"] = Color("2a2a30")
		"perro":
			look["species"] = "perro"
			look["fur"] = DOG_FURS[rng.randi_range(0, DOG_FURS.size() - 1)]
	look.merge(k.get("looks", {}).get(display_name, {}), true)
	_idle = randf_range(0.0, 3.0)


## Un nombre al azar del tipo, sin los que ya son personajes del editor (`reservados`).
static func _pick_name(p_kind: String) -> String:
	var names: Array = KINDS[p_kind]["names"].filter(func(n): return not reservados.has(p_kind + "|" + n))
	return names.pick_random() if not names.is_empty() else KINDS[p_kind]["names"].pick_random()


## Peinado, barba, gafas, chaqueta y falda, con las tiradas de `rng`.
func _roll_traits(rng: RandomNumberGenerator) -> void:
	var styles: Array = Actor.HAIR_STYLES[gender]
	# la mitad de las veces, uno de los dos peinados más corrientes
	var n := 2 if rng.randf() < 0.5 else styles.size()
	look["hair_style"] = styles[rng.randi_range(0, n - 1)]
	if gender == "m":
		var r := rng.randf()
		look["facial"] = "barba" if r < P_BEARD else ("bigote" if r < P_BEARD + P_MOUSTACHE else "")
	look["glasses"] = rng.randf() < P_GLASSES
	if kind not in UNIFORMED:
		if rng.randf() < P_JACKET:
			look["jacket"] = Color.from_hsv(rng.randf(), rng.randf_range(0.1, 0.5), rng.randf_range(0.15, 0.45))
		look["skirt"] = gender == "f" and rng.randf() < P_SKIRT


func label() -> String:
	var k: Dictionary = KINDS[kind]
	if amo != null and is_instance_valid(amo):
		if kind == "perro":
			return "%s (%s de %s)" % [display_name, kind_label(kind, gender).to_lower(), amo.display_name]
		if kind == "nino":
			var rel := ("nieta" if gender == "f" else "nieto") if amo.kind == "anciano" else ("hija" if gender == "f" else "hijo")
			return "%s (%s de %s)" % [display_name, rel, amo.display_name]
		return "%s (%s del grupo de %s)" % [display_name, kind_label(kind, gender).to_lower(), amo.display_name]
	if not known and k.has("disguise"):
		return "%s (%s)" % [display_name, kind_label(k["disguise"], gender)]
	return "%s (%s)" % [display_name, kind_label(kind, gender)]


## Nombre del tipo de bot `p_kind` en el género `p_gender`.
static func kind_label(p_kind: String, p_gender: String) -> String:
	var k: Dictionary = KINDS[p_kind]
	return k.get("label_f", k["label"]) if p_gender == "f" else k["label"]


## (estatuas) Se mueve `seconds` segundos: le han echado una moneda.
func wake_statue(seconds: float) -> void:
	_still_until = _clock() + seconds


## Si te hace la vista gorda (el favor de una misión del editor; ver Misiones.FAVORES).
func vista_gorda() -> bool:
	return Misiones.favor(personaje.get("id", ""), "vista_gorda")


## Si es de la policía (de uniforme o de paisano).
func is_police() -> bool:
	return POLICE.has(kind)


## Cuerpo al que pertenece ("urbana" o "mossos"); "" si no es policía.
func corps() -> String:
	return POLICE.get(kind, "")


## Si se le ve como policía: de uniforme, o de paisano y ya se ha descubierto.
func looks_police() -> bool:
	return is_police() and (not KINDS[kind].has("disguise") or known)


## Si es un agente de paisano que todavía no se ha descubierto.
func undercover() -> bool:
	return is_police() and KINDS[kind].has("disguise") and not known


## Un agente de paisano se descubre: saca la placa y ya se le ve como lo que es.
func reveal() -> void:
	if undercover():
		known = true
		say("¡Guàrdia Urbana!" if corps() == "urbana" else "¡Mossos d'Esquadra!", 3.0)


## Historia de este personaje, si la tiene.
func bio() -> String:
	if personaje.get("historia", "") != "":
		return personaje["historia"]
	return KINDS[kind].get("bios", {}).get(display_name, "")


## Lo que dice al pasar: sus frases si es un personaje del editor, si no las de su tipo.
func lines() -> Array:
	return personaje["frases"] if not personaje.get("frases", []).is_empty() else KINDS[kind]["lines"]


## Si este bot anda por la calle a la hora `h` (su horario, o el de su tipo).
func active(h: int) -> bool:
	return Personajes.activo(personaje, h) if not personaje.is_empty() else active_at(kind, h)


## Prepara un personaje del editor (`d`, ver Personajes): su tipo base con su nombre, su
## aspecto, su dinero y su velocidad. La casa y la zona las pone Censo.despertar.
func init_personaje(d: Dictionary) -> void:
	init_kind(d["tipo"], d["nombre"])
	personaje = d
	gender = d["genero"]
	look = Personajes.look_de(d)
	accessory = d["aspecto"]["accesorio"]
	body_size = d["aspecto"]["tamano"]
	money = int(d["stats"]["dinero"])
	speed = d["stats"]["velocidad"]


## Casillas de su zona dibujada (las transitables dentro del polígono).
func set_zona(cells: Array) -> void:
	_zona.assign(cells)


## Adónde va a dar una vuelta: al lugar de su rutina a esta hora, si tiene; si no, a
## cualquier sitio de su zona dibujada o, sin ella, cerca de casa.
func _wander_target() -> Vector2i:
	if not personaje.is_empty():
		var l := Personajes.lugar_a(personaje, GameState.hour())
		if not l.is_empty():
			return city.random_walkable_near(Vector2i(l["x"], l["y"]), Personajes.LUGAR_WANDER)
		if not _zona.is_empty():
			return _zona.pick_random()
	return city.random_walkable_near(home, wander_radius)


## Si los de este tipo andan por la calle a la hora `h`.
static func active_at(p_kind: String, h: int) -> bool:
	var hours: Array = KINDS[p_kind].get("hours", [])
	if hours.is_empty():
		return true
	var from: int = hours[0]
	var to: int = hours[1]
	return (h >= from and h < to) if from < to else (h >= from or h < to)




# --------------------------------------------------------- memoria y visión

## Apunta algo que ha pasado contigo ("pedido", "robado", "ayudado", "pegado").
func remember(what: String) -> void:
	memory[what] = memory.get(what, 0) + 1


func remembers(what: String) -> int:
	return memory.get(what, 0)


## Te fía `amount` € y te da `hours` horas para pagar antes de venir a cobrar.
func add_debt(amount: int, hours: float) -> void:
	debt += amount
	debt_due = GameState.now() + hours * 60.0


## Lo que le toca hacer si te ve, según quién es y lo que recuerda de ti; "" si le da igual.
## "persigue" (la policía, si estás fichado por algo de su competencia o muy buscado), "cobrar" (un camello al que
## debes), "venganza" (le robaste y va a por lo suyo), "denuncia" (le robaste y busca a un
## agente), "territorio" (un camello en cuya esquina vendiste), "aparta" (le has pedido
## demasiado, le pegaste o le timaste) o "acerca" (le ayudaste o te compra).
func grudge() -> String:
	var gs := GameState
	if is_police():
		if vista_gorda():
			return ""
		return "persigue" if gs.is_wanted_by(corps()) or gs.heat > Defs.CHASE_HEAT else ""
	if kind == "camello" and debt > 0 and gs.now() >= debt_due:
		return "cobrar"
	if kind == "camello" and remembers("pisado") > 0:
		return "territorio"
	if remembers("timado") > 0:
		# a la policía no le vas a contar que te vendieron yeso
		return "venganza" if avenger() else "aparta"
	if remembers("robado") > 0:
		if avenger():
			return "venganza"
		# los que viven de la calle no van con cuentos a la policía
		return "aparta" if kind in Defs.NEVER_INTERVENE else "denuncia"
	if remembers("pegado") > 0 or remembers("pedido") >= Defs.BEG_ANNOY:
		return "venganza" if stat("agresividad") >= Defs.STAT_HOTHEAD else "aparta"
	if remembers("ayudado") > 0 or remembers("cliente") > 0:
		return "acerca"
	return ""


## Si, robado, va a por ti en vez de buscar a un agente (tirada fija por nombre).
func avenger() -> bool:
	var p: float = Defs.AVENGER_CHANCE[gender]
	if kind == "fiestero":
		p += 0.2  # van en grupo y van ciegos
	p += (stat("valor") + stat("agresividad") - 10) * Defs.STAT_AVENGE
	return _trait("venganza") < p


## Cómo reacciona ante un escándalo: "valiente" (intenta pararte), "llama" (a la policía) o
## "pasa". Los que viven de la calle siempre pasan.
func temper() -> String:
	if kind in Defs.NEVER_INTERVENE or is_police():
		return "pasa"
	var r := _trait("caracter")
	var brave := Defs.BRAVE_CHANCE + (stat("valor") - 5) * Defs.STAT_BRAVE
	if r < brave:
		return "valiente"
	if personaje.get("stats", {}).get("llama_policia", false):
		return "llama"
	return "llama" if r < brave + Defs.CALLER_CHANCE else "pasa"


## Estadística de 0 a 10 del editor de personajes ("fuerza", "valor", "agresividad"); los
## bots corrientes, 5.
func stat(what: String) -> int:
	return int(personaje.get("stats", {}).get(what, 5))


## Tirada 0..1 que depende solo del personaje y de `salt`: el mismo siempre hace lo mismo.
func _trait(salt: String) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind + "|" + display_name + "|" + salt)
	return rng.randf()


## Alcance (metros, en x) y media apertura (radianes, en y) de su cono de visión ahora.
func vision() -> Vector2:
	var v: Dictionary = Defs.VISION.get(kind, Defs.VISION["_"])
	var r: float = v["range"] * city.cell_m
	if GameState.is_night():
		r *= Defs.NIGHT_SIGHT
	if GameState.heat >= 90.0:
		r *= Defs.EXPOSED_SIGHT
	return Vector2(r, deg_to_rad(v["angle"]) / 2.0)


## Si ve a `who`: dentro del cono (o pegado a él) y sin edificios en medio.
func can_see(who: Actor) -> bool:
	if who == null or city == null:
		return false
	var v := vision()
	var to := who.position - position
	to.y = 0.0
	var dist := to.length()
	if dist > v.x:
		return false
	if dist > Defs.NEAR_SIGHT * city.cell_m and facing().dot(to / dist) < cos(v.y):
		return false
	return city.line_of_sight(cell, who.cell)


## Deja de hacer lo que hacía por ti y vuelve a lo suyo.
func calm_down() -> void:
	mode = ""
	chase_reason = ""
	alert = 0.0
	_denounce_to = null
	speed = KINDS[kind]["speed"]


## Viene a buscarte desde lejos por `why` (lo que hará al verte, ver react: "cobrar"): anda
## hacia donde estás hasta verte. Se cansa a los Defs.HUNT_SECONDS.
func come_for(why: String) -> void:
	mode = "viene"
	_hunt_why = why
	_hunt = Defs.HUNT_SECONDS
	walk_to(player.cell)


## Empieza a perseguirte por `reason` ("policia", "deuda", "venganza", "parar").
func start_chase(reason: String) -> void:
	mode = "persigue"
	chase_reason = reason
	alert = 1.0
	_lost = 0.0
	last_seen = player.cell
	speed = KINDS[kind]["speed"] * (1.3 if reason == "policia" else 1.2)
	walk_to(player.cell)


## Va a mirar a `at` (ha oído un escándalo o se lo han contado); si te ve allí, te persigue.
func investigate(at: Vector2i) -> void:
	if mode == "persigue":
		return
	mode = "busca"
	if is_police():
		chase_reason = "policia"
		reveal()
	last_seen = at
	_search = Defs.SEARCH_TIME * 1.5
	speed = KINDS[kind]["speed"] * 1.3
	walk_to(at)


## Te ha visto y reacciona según grudge(); sin motivo, nada.
func react(why: String) -> void:
	_calm_until = _clock() + 25.0
	match why:
		"persigue":
			if undercover():
				reveal()
			else:
				say("¡Alto! ¡Policía!" if corps() == "urbana" else "¡Alto! ¡Mossos!")
			start_chase("policia")
		"cobrar":
			say("¡Eh, tú! ¡Mi dinero!", 3.0)
			start_chase("deuda")
		"territorio":
			say("¡Eh! ¡Esta esquina es mía!", 3.0)
			start_chase("territorio")
		"venganza":
			say("You! ¡Tú! ¡Devuélvemelo!" if kind in ["turista", "fiestero"] else "¡Tú! ¡Ladrón!", 3.0)
			start_chase("venganza")
		"denuncia":
			alert = 0.0
			_denounce_to = _nearest_police()
			say("¡Ese! ¡Ese me robó!", 3.0)
			if _denounce_to:
				mode = "denuncia"
				walk_to(_denounce_to.cell)
			else:
				GameState.mark_wanted("%s te ha reconocido y ha llamado a la policía" % display_name)
		"aparta":
			alert = 0.0
			mode = "aparta"
			say(["Otra vez tú no...", "Ni me mires", "Uf, este otra vez"].pick_random())
			var away := Vector2(cell - player.cell).normalized() * 10.0
			walk_to(city.nearest_walkable(cell + Vector2i(roundi(away.x), roundi(away.y))))
		"acerca":
			alert = 0.0
			mode = "acerca"
			walk_to(player.cell)


func _process(delta: float) -> void:
	# fuera de la pantalla y sin nada contigo, a trompicones: cada OFFSCREEN_EVERY frames, con
	# el tiempo acumulado (no se ve, y con muchos bots es casi todo el trabajo)
	if not on_screen and mode == "":
		_offscreen_dt += delta
		_offscreen_frame += 1
		if _offscreen_frame % Defs.OFFSCREEN_EVERY != 0:
			return
		delta = _offscreen_dt
	_offscreen_dt = 0.0
	super._process(delta)
	if not GameState.alive:
		return
	_think -= delta
	_chatter -= delta
	if _chatter <= 0.0:
		_chatter = randf_range(15.0, 45.0)
		if player and distance_to_cell(player.cell) < 20:
			say(lines().pick_random())
	if player and _think <= 0.0:
		_think = THINK_TIME
		perceive(THINK_TIME)
		_follow_mode(THINK_TIME)
	_cone_timer -= delta
	if _cone_timer <= 0.0:
		_cone_timer = 0.1
		_update_cone()
	if mode != "":
		if mode == "busca" and not is_moving():
			_look_around(delta, 2.5)
		return
	if kind == "perro" or amo != null:
		_follow_owner(delta)
		return
	if KINDS[kind].get("still", false) and _clock() >= _still_until:
		return  # estatua: ni se mueve ni mira, hasta que le echan una moneda
	if not is_moving():
		_look_around(delta, 1.0)
		_idle -= delta
		if _idle <= 0.0:
			_idle = randf_range(1.0, 5.0) if kind != "camello" else randf_range(4.0, 12.0)
			# de noche, quien tiene sitio para dormir se va a él y se queda (los del editor
			# de personajes con rutina van a los lugares de su rutina)
			if bed.x >= 0 and GameState.is_night() and personaje.get("lugares", []).is_empty():
				if distance_to_cell(bed) > 1:
					walk_to(bed)
				return
			walk_to(_wander_target())


## Mira (cono de visión) y sube o baja la sospecha. Llena, reacciona si tiene motivo.
func perceive(dt: float) -> void:
	var far: float = Defs.VISION["mosso"]["range"] * Defs.EXPOSED_SIGHT
	sees_player = distance_to_cell(player.cell) <= far and can_see(player)
	if mode in ["aparta", "denuncia", "acerca"]:
		return
	var why := grudge() if sees_player else ""
	if sees_player:
		last_seen = player.cell
		_lost = 0.0
	if why != "" or (sees_player and mode == "persigue"):
		var closeness := clampf(position.distance_to(player.position) / vision().x, 0.0, 1.0)
		alert = minf(1.0, alert + dt / Defs.ALERT_TIME * lerpf(3.0, 1.0, closeness))
	elif mode != "persigue":
		alert = maxf(0.0, alert - dt * Defs.ALERT_DECAY)
	if alert >= 1.0 and mode in ["", "busca"] and why != "" and _clock() >= _calm_until:
		react(why)


## Sigue con lo que esté haciendo por ti: perseguir, buscar, apartarse, denunciar, saludar.
func _follow_mode(dt: float) -> void:
	match mode:
		"persigue":
			if chase_reason == "policia" and GameState.heat <= 10.0 and not GameState.is_wanted():
				say("Bah, déjalo.")
				calm_down()
				return
			if distance_to_cell(player.cell) <= 2:
				stop()
				var why := chase_reason
				calm_down()
				_calm_until = _clock() + 30.0
				chase_reason = why
				caught_player.emit(self)
				chase_reason = ""
				return
			if sees_player:
				walk_to(player.cell)
			else:
				_lost += dt
				if _lost >= Defs.LOSE_SIGHT_TIME:
					if chase_reason == "parar":
						calm_down()  # un transeúnte no sigue a nadie por las esquinas
						return
					mode = "busca"
					_search = Defs.SEARCH_TIME
					say("¿Dónde se ha metido?")
					walk_to(last_seen)
		"busca":
			if not is_moving():
				_search -= dt
				if _search <= 0.0:
					if chase_reason == "policia":
						say("Se ha escapado...")
						GameState.mark_wanted("te has escapado de la policía")
					calm_down()
					walk_to(_wander_target())
		"denuncia":
			if not is_instance_valid(_denounce_to):
				_denounce_to = _nearest_police()
				if _denounce_to == null:
					GameState.mark_wanted("%s ha llamado a la policía" % display_name)
					calm_down()
					return
			if distance_to_cell(_denounce_to.cell) <= 4:
				say("¡Agente! ¡Ese me ha robado!", 3.0)
				_denounce_to.say("¿Cuál? Vale, vamos.")
				_denounce_to.investigate(last_seen)
				GameState.mark_wanted("%s te ha denunciado a %s" % [display_name, _denounce_to.display_name])
				calm_down()
			elif not is_moving() or randf() < 0.2:
				walk_to(_denounce_to.cell)
		"viene":
			# viene desde lejos (Censo, despertadores): en cuanto te ve, reacciona
			if sees_player:
				var why := _hunt_why
				calm_down()
				react(why)
				return
			_hunt -= dt
			if _hunt <= 0.0:
				calm_down()
				walk_to(_wander_target())
			elif not is_moving() or randf() < 0.05:
				walk_to(player.cell)
		"aparta":
			if not is_moving():
				calm_down()
		"acerca":
			if distance_to_cell(player.cell) <= 3:
				stop()
				if remembers("cliente") > 0:
					say(["¿Tienes algo?", "Hey, my friend! Same as yesterday?", "¿Me pasas lo de siempre?"].pick_random(), 3.0)
				else:
					say(["¡Eh, colega!", "¡Hombre! ¿Qué tal?", "Gracias por lo del otro día"].pick_random(), 3.0)
				calm_down()
			elif not is_moving():
				calm_down()


## (perros y grupos de un guía) Va detrás de su dueño, a dos o tres casillas, y mira cuando se para.
func _follow_owner(delta: float) -> void:
	if amo == null or not is_instance_valid(amo):
		return
	_idle -= delta
	if _idle <= 0.0:
		_idle = 0.4
		if distance_to_cell(amo.cell) > 2:
			walk_to(city.random_walkable_near(amo.cell, 1))
	if not is_moving():
		_look_around(delta, 2.0)


## Parado, gira la cabeza a un lado y a otro (para que el cono barra la calle).
func _look_around(delta: float, pace: float) -> void:
	_look_timer -= delta * pace
	if _look_timer <= 0.0:
		_look_timer = randf_range(1.5, 4.0)
		_look_yaw = atan2(facing().x, facing().z) + randf_range(-1.6, 1.6)
	_face(Vector3(sin(_look_yaw), 0, cos(_look_yaw)), delta * 0.25 * pace)


func _nearest_police() -> Npc:
	if world == null:
		return null
	var best: Npc = null
	for n in world.npcs:
		if n.looks_police() and is_instance_valid(n) and (best == null or n.distance_to_cell(cell) < best.distance_to_cell(cell)):
			best = n
	return best


func _clock() -> float:
	return Time.get_ticks_msec() / 1000.0


## Dibuja en el suelo lo que ve, recortado por los edificios, como en *Commandos*.
## El color dice qué piensa: tranquilo, con sospecha o persiguiéndote.
func _update_cone() -> void:
	if not cone_visible or city == null:
		if _cone:
			_cone.visible = false
		return
	if _cone == null:
		if _cone_material == null:
			_cone_material = StandardMaterial3D.new()
			_cone_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_cone_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_cone_material.vertex_color_use_as_albedo = true
			_cone_material.cull_mode = BaseMaterial3D.CULL_DISABLED
			_cone_material.render_priority = 1
		_cone_mesh = ImmediateMesh.new()
		_cone = MeshInstance3D.new()
		_cone.mesh = _cone_mesh
		_cone.material_override = _cone_material
		_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_cone.top_level = true
		add_child(_cone)
	_cone.visible = true
	_cone.global_transform = Transform3D.IDENTITY
	var color := C_CONE_CALM
	if mode in ["persigue", "busca"]:
		color = C_CONE_CHASE
	elif alert > 0.05:
		color = C_CONE_CALM.lerp(C_CONE_ALERT, minf(1.0, alert * 2.0))
	var edge := Color(color, color.a * 0.35)
	var v := vision()
	var origin := global_position + Vector3(0, 0.08, 0)
	var ahead := facing()
	_cone_mesh.clear_surfaces()
	_cone_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var prev := Vector3.ZERO
	for i in CONE_RAYS + 1:
		var dir := ahead.rotated(Vector3.UP, lerpf(-v.y, v.y, float(i) / CONE_RAYS))
		var p := origin + dir * city.clear_distance(global_position, dir, v.x)
		if i > 0:
			_cone_mesh.surface_set_color(color)
			_cone_mesh.surface_add_vertex(origin)
			_cone_mesh.surface_set_color(edge)
			_cone_mesh.surface_add_vertex(prev)
			_cone_mesh.surface_set_color(edge)
			_cone_mesh.surface_add_vertex(p)
		prev = p
	_cone_mesh.surface_end()
