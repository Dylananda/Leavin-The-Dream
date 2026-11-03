# Encargos para las sesiones en la nube

Encargos grandes preparados para pedirlos desde el móvil. Para lanzar uno, en una sesión nueva
de la pestaña Code (entorno Barcelonely, repositorio `Dylananda/Leavin-The-Dream`, rama `main`),
basta con escribir: «Haz el encargo 1 de `docs/encargos-nube.md`».

Para todos:

- Lee primero `CLAUDE.md` (sección «En la nube»), `README.md` y `docs/ideas.md`.
- Trabaja en una rama nueva a partir de `main` y súbela a GitHub al terminar; no toques `main`.
- Pasa el test de humo sin `SCRIPT ERROR` ni `FALLO` y añade pruebas de lo nuevo.
- Las capturas no se pueden hacer en la nube: di cuáles habría que hacer en el PC.
- Marca en `docs/ideas.md` lo que quede hecho y apunta lo que quede pendiente.
- Cada encargo sale de `main` sin los otros: si algo choca con lo que podría hacer otro
  encargo, mantén los cambios en su zona y explícalo al final, que se juntan en el PC.

Orden recomendado: el 1 y el 3 en cualquier orden; el 2, cuando los otros dos estén juntos en
`main`, porque tiene que guardar todo lo que añadan.

## Encargo 1. Todo el mundo está yonki a su manera (primer paso)

Lee la sección 8 de `docs/ideas.md` («Todo el mundo está yonki a su manera»). Primer paso:

- **Los bots también consumen.** Cada tipo con sus sustancias más probables (en `Defs`, como
  el resto del equilibrio), con colocón, mono y enganche como el jugador pero simplificados.
  Que se note en su conducta: velocidad y forma de andar, dormirse en un portal, buscar bronca,
  venir a pedirte o a comprarte. Que influya en lo que ya hay (trapicheo: quien tiene mono
  compra o roba; peleas; lo que te dicen al pasar).
- **El censo**: al despertar a un latente, calcular cómo le ha ido el tiempo que ha estado
  latente (colocón pasado, mono acumulado, si ha conseguido o no).
- **Dos sustancias nuevas, speed y MDMA**, con sus efectos de pantalla (shader de viñeta),
  de manejo y de enganche, precios coherentes con las demás y su hito de la caída. Que alguien
  las venda y que alguien las quiera.

## Encargo 2. Partidas guardadas

Ahora cada partida empieza de cero al cerrar el juego. Hace falta guardar y cargar:

- Todo `GameState`: barras, vitalidad, sustancias, inventario, dinero, banco, deudas, hitos,
  caída, día y hora, búsqueda y fichajes, encargos, libreta y misiones (también sus resultados
  y favores).
- **El censo** (`scripts/censo.gd`): todos los registros con su estado y lo que recuerdan,
  incluidos los personajes del editor; los que tienen cuerpo se guardan como si se durmieran.
- La memoria de las conversaciones con la IA (`ai/conversation.gd`).
- Dónde está el jugador.

Guardado automático al dormir y al cambiar de día, y a mano desde la pausa («Guardar»); en el
menú de inicio, «Continuar» si hay partida. Un archivo por partida en `user://`, en JSON y con
número de versión, que no se rompa si se añaden campos nuevos. Prueba de humo: guardar a media
partida, cargar y comprobar que todo coincide (incluido un bot que te recuerda).

## Encargo 3. Relaciones entre personajes y misiones encadenadas

Fase 3 del diseñador de personajes (ver «11. Diseñador de personajes» en `docs/ideas.md`):

- **Relaciones** en el diseñador (pestaña nueva o en «Misiones y notas»): con quién se lleva
  bien, mal, le debe dinero, es familia, trabaja para... Que el juego las use: si ayudas o
  traicionas a uno, los suyos se enteran (amigos se acercan, enemigos se apartan o van a por ti).
- **Esquema de las cadenas de misiones**: una vista en el diseñador con las misiones de todos
  los personajes y cómo se encadenan (después de, deudas, favores, enemigos).
- **Pasar a misiones de verdad** las historias que ya están escritas en las notas de los
  personajes de ejemplo: el pasaporte de Grzegorz (lo tiene Vera), el acordeón de Vasile (El
  Mudo y la compraventa), Joy y la denuncia (Agent Ortega, Rosi), el Sr. Feliu y el inversor
  Pol, las pruebas del piso de Quique (Sra. Encarna, Agent Serra) y Margit buscando su bar.
  Que se crucen entre ellas y obliguen a elegir, como «El paquete para Txell».
