# Encargos para las sesiones en la nube

Encargos grandes preparados para pedirlos desde el móvil. Para lanzar uno, en una sesión nueva
de la pestaña Code (entorno Barcelonely, repositorio `Dylananda/Leavin-The-Dream`, rama `main`),
basta con escribir: «Haz el encargo 1 de `docs/encargos-nube.md`».

Para todos:

- Lee primero `CLAUDE.md` (sección «En la nube»), `README.md` y `docs/ideas.md`, sobre todo
  «La partida como una historia de relevos», en «Personajes que viven (y relevo)».
- Trabaja en una rama nueva a partir de `main` y súbela a GitHub al terminar; no toques `main`.
- Pasa el test de humo sin `SCRIPT ERROR` ni `FALLO` y añade pruebas de lo nuevo.
- Las capturas no se pueden hacer en la nube: di cuáles habría que hacer en el PC.
- Marca en `docs/ideas.md` lo que quede hecho y apunta lo que quede pendiente.
- El equilibrio (probabilidades, precios, duraciones) va en `Defs`, con su comentario.
- Todo lo nuevo que dure entre días tiene que guardarse en la partida (`Partida.CAMPOS` o el
  censo) y sobrevivir a un relevo si es del barrio (ver `GameState.relevo`).
- Cada encargo sale de `main` sin los otros: si algo choca con lo que podría hacer otro
  encargo, mantén los cambios en su zona y explícalo al final, que se juntan en el PC.

Se pueden hacer en cualquier orden. Los cuatro tocan `defs.gd` y `world.gd`: añade bloques
nuevos en vez de reorganizar lo que hay, para que se junten sin conflictos.

## Encargo 1. Un propósito para cada yonki

Cada perfil tiene algo que quiere conseguir, además de pasar un día más (ver las ideas en
«Un propósito para cada yonki»: Youssef manda dinero a casa y busca los papeles, Paco quiere
recuperar a su hija, Don Ramón que los nietos vuelvan a llamar, Jordi ver al perro, Mari
Loli que callen las voces, Borja demostrarle algo a papá).

- Define los propósitos en `Defs` (uno por perfil, por pasos si hace falta), con algo concreto
  que hacer en el barrio: juntar dinero y mandarlo (locutorio o cajero), ir a ciertos sitios a
  ciertas horas, conseguir algo de alguien, mantener una barra durante días...
- Que se vea: en la libreta, con su progreso, y un aviso en el registro al avanzar.
- Que choque con la caída: lo que acerca al propósito suele alejar de caer (y al revés), para
  que haya que elegir.
- Cumplirlo es un final propio («CUMPLIDO», con su texto) que también deja relevo, y queda
  en `GameState.historia`; fallarlo para siempre (p. ej. los nietos dejan de llamar) es un hito.
- Prueba de humo: cumplir el propósito de un perfil paso a paso y comprobar el final.

## Encargo 2. Sucesos del barrio

Cosas que le pasan al Raval durante unos días y lo cambian para todos (ver «Sucesos de la
historia del barrio»):

- Un sistema de sucesos en marcha (`GameState` o un script nuevo, guardado en la partida), con
  su anuncio en el registro y en los rumores, que empiezan por fecha o al azar y duran días.
- Al menos estos cuatro:
  - **Llega el fentanilo**: nueva sustancia (parches o cortado en el caballo, sin avisar), muy
    barata y con mucho riesgo de sobredosis; más sobredosis de bots; los educadores reparten naloxona.
  - **Redadas fuertes**: más Mossos y Urbana durante unos días, camellos escondidos y droga más
    cara.
  - **Fiesta Mayor del Raval** (julio): más gente, más turistas, música y oportunidades.
  - **Obras** que cortan una calle unos días (casillas no transitables y vallas).
- Prueba de humo: forzar cada suceso, comprobar que se nota (precios, cuántos bots, casillas) y
  que se acaba y se guarda.

## Encargo 3. Amistades, enemistades y fama entre los bots

Hoy cada bot recuerda lo que le haces tú (`Npc.memory`), pero entre ellos no se conocen (ver
«Amistades y enemistades entre los NPC»). Primer paso:

- **Relaciones entre bots** en el censo: se hacen amigos o enemigos por lo que ven y lo que se
  hacen (peleas entre yonkis, robos, el tirón, quien da una dosis a otro). Con un tope por bot y
  que se olviden con el tiempo, como `Defs.LATENT_*`.
- **Fama** del jugador por zona del barrio (calles cercanas): sube con lo que hace a la vista
  y con lo que se cuentan, y cambia cómo te tratan los que no te conocen (te piden, te evitan,
  te avisan de la policía, no te venden).
- Que lo de antes también cuente para el yonki anterior (`recuerda_a` en el censo).
- Apunta en `docs/ideas.md` cómo podrían salir **bandas** de aquí (no hace falta hacerlas).
- Prueba de humo: dos bots que se pelean quedan enemigos; hacer algo a la vista sube la fama de
  esa zona y otro bot de la zona lo nota.

## Encargo 4. Partidas: elegir, borrar y más relevos

- En el menú de inicio, la lista de partidas guardadas (no solo «Continuar»): con quién va,
  qué día, la caída, quiénes vinieron antes (`historia` en la cabecera) y un botón para
  borrar cada una (con confirmación).
- **Repetir perfil** cuando ya han salido los seis: un «Paco» distinto (otro nombre y aspecto
  dentro del perfil) para que la partida no se acabe.
- **Legado** del relevo (ver los pendientes del relevo en `docs/ideas.md`): algo que el nuevo
  hereda del de antes según cómo acabó y cómo le fue: un escondite con lo que guardaba, un
  contacto que le ayudaba, una deuda que alguien viene a cobrarte a ti.
- Prueba de humo: guardar dos partidas, listarlas, borrar una; agotar los seis perfiles y
  seguir; comprobar el legado.
