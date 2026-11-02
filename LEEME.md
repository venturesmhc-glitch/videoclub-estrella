# Videoclub Estrella — cómo jugar y cómo está armado

Juego de terror analógico para Roblox (1 a 4 jugadores, cooperativo). Estás en el turno noche de un videoclub
argentino, noviembre de 1997. Hay cinco noches y tres finales.

## Cómo jugarlo
1. Abrí `starvideoclub` en Roblox Studio (ya está abierto con todo cargado) y apretá **Play**.
   También se puede jugar desde Roblox si publicás el lugar (Archivo → Publicar en Roblox, `Alt+P`).
2. Al entrar aparece el **menú**: Un jugador (arranca el turno), Multijugador (lista de salas públicas; abajo, **Crear** —pública o privada, de 2 a 4 jugadores— y **Unirse por código**; dentro de la sala se ve el código y los jugadores, y el anfitrión la arranca con **Iniciar**), Ajustes (música, ambiente y estática del filtro) y Cómo jugar. **M** abre los ajustes durante el turno.
3. Controles: **WASD** moverte · **E** interactuar · **R** (mantener) segunda acción · **Tab** ocultar la ficha · **G** soltar el casete que llevás ·
   **Q** marcar una anomalía (apuntándole) · **F** linterna (cuando se corta la luz) · **Shift** suelta o atrapa el mouse (en primera persona está bloqueado; sirve para tocar "Revivir" y los botones del menú).
4. La **ficha de socio** (cartón, a la izquierda) es tu inventario: tareas, lo que llevás en la mano y lo que pide el cliente.

Al empezar la noche 1 suena el teléfono del mostrador (cartel flotante "TELÉFONO SONANDO"): atendelo con **E** y
Don Ernesto explica el trabajo y los controles. Suena hasta que alguien lo atiende; el primer cliente llega después.

## Qué hacer
- **Atender clientes** en el mostrador (E). Los que alquilan piden un género: sacá un casete de esa góndola y entregáselo.
  Los que devuelven dejan una cinta en el mostrador.
- **Rebobinar** las cintas devueltas (videocasetera, mantener E) y **reponerlas** en la góndola de su género.
- **Separar** en la caja de dañadas las cintas arrugadas y las anómalas (título que no existe).
- **El Socio N° 0000 solo se mueve cuando nadie lo mira.** El filtro VHS se deforma cuando está cerca. Si te toca, te graba:
  volvés al mostrador aturdido. Cada captura se cuenta en el aviso ("fue grabado (1/2)"): a la segunda, ese jugador queda fuera de la noche y aparece como fantasma
  traslúcido en el motel de enfrente (se lo ve desde las ventanas). Si caen todos, la noche se repite; en la siguiente vuelven todos.
- A las 3:33 (noche 1) cae por el buzón un casete sin etiqueta. En la videocasetera se **reproduce** (mirás el local desde
  arriba, con cosas que no están): da información, pero hace avanzar al Socio. **E** saca la cinta.
- Noche 2: anomalías por jugador (apuntales y **Q**). Noche 3: notas de Darío (algunas son falsas), teléfonos, clientes que
  repiten frases. Noche 4: corte de luz, depósito más largo, clientes iguales (uno es el Socio: **R** para rechazar).
  Noche 5: el Socio hace cola. Tres finales: **devolverle la cinta** (final verdadero), **grabarle encima**
  (R en la videocasetera, mantener) o **mirarla entera**.

- **Tareas extra** (para repartir entre varios): las bolsas de basura se llevan al contenedor del patio (puerta del fondo a la derecha; con una bolsa en las manos no se pueden tomar casetes) y las manchas se limpian con el **cepillo de mano** (cuelga de la pared del baño, junto al lavatorio: E lo toma o lo guarda; con el cepillo en la mano, mantené E sobre la mancha). La cocina (puerta del fondo a la izquierda) y el baño también tienen tareas.

- **Tareas del local**: además de clientes, cintas, basura y manchas hay pequeñas tareas (regar la planta, ordenar las fichas, enderezar el cartel, limpiar el vidrio, contar la caja; se marcan con un contorno y se hacen manteniendo E). Con más jugadores hay más trabajo (clientes, cintas, basura, manchas y tareas del local por cada jugador extra: `NightData.paraJugadores`).
- **Radio** (sobre el lateral del mostrador): E cambia de estación (Radio AM, Synthwave, Jazz, Cumbia, Tango), R mantenido la apaga. Las estaciones están en `Config.Radio`.
- **El monstruo** aparece 30 s por persecución (`Config.Socio.PersecucionSeg`) y vuelve a aparecer cada 55 a 90 s mientras dure la noche.
- **Quedar fuera de la noche**: a la segunda captura el jugador pasa a ser **espectador** (ve el local por la cámara de sus compañeros, distorsionado y sin el monstruo) y su personaje queda como una estatua traslúcida en el motel. No se reinicia el personaje. Vuelve con **Revivir (R$ 15)** o si todo el equipo cae y la noche se repite.
- **Screamers** automáticos en las noches 2 a 5 y **Asustar a todos (R$ 10)**: se compra manteniendo E sobre la **máscara de Ghostface** colgada en la pared izquierda del depósito (brilla con destellos blancos). Los dos productos son Developer Products de la experiencia (ids en `Config.Tienda.Productos`; con 0 la compra se simula solo en Studio).
- **Insignias** (`Insignias.lua`, lista en `Catalogo.Insignias`): Primer turno, En vivo (llegar a la noche 5), una por cada final (Grabar encima, Cuenta cerrada, Hasta el final), Cinta completa (los tres finales) y, en Sin fin, Insomnio (5 noches seguidas) y Turno eterno (10). Quedan anotadas en el perfil (DataStore) y se otorgan con BadgeService cuando su id está cargado en `Config.Insignias.Ids` (con 0 solo se avisa en pantalla).
- **Modo Sin fin**: se desbloquea al alcanzar cualquier final de la historia. En el menú, el selector **HISTORIA / SIN FIN** vale para Un jugador y para las salas (el anfitrión lo elige al crear). Las noches se arman solas (`NightData.sinFin`), suben de dificultad hasta la noche 12 y no hay final ni cinta final: la racha termina cuando cae todo el equipo ("Noches superadas" y récord) y el turno vuelve a empezar desde la noche 1. El récord se guarda en el perfil (`mejorSinFin`).

- **Idioma**: el juego se ve en español o en inglés según el idioma de Roblox del jugador (si empieza con "es", español; con cualquier otro, inglés). Todo está escrito en español y `Client/Traductor.lua` traduce lo que se muestra con el diccionario de `Shared/Idioma.lua` (exacto + patrones). Si agregás un texto nuevo, sumá su traducción ahí; `Config.Idioma.Forzar = "en"` fuerza un idioma para probar.

## Cómo está armado
- `src/` es la fuente de verdad del código (Luau). `node push.js` lo sincroniza a Studio.
- `build/videoclub.lua` reconstruye el local (`node mcp-call.js execute_luau @build/videoclub.lua`).
- Las tareas extra usan dos modelos de la toolbox guardados en el place, en `ServerStorage.Plantillas`: `trash bag` (bolsa) y `trash` (decal de suciedad); la máscara de la tienda es `ghostface.Mascara` (inventario, id 78464649977521).
  No viajan con el repo (viven en el `.rbxl`); si faltan, `ChoreSystem` usa una esfera negra y un círculo oscuro. Para ponerlos: `insert_asset` 10795701949 (trash bag) y 12900378954 (trash) y moverlos a esa carpeta.
- `mcp-call.js` es un puente para llamar a las herramientas del servidor MCP de Studio; `studio-mcp.cmd` y `.mcp.json` lo conectan.
- `dbg.js` ejecuta comandos de depuración en el servidor durante el Play (`node dbg.js empezar | estado | noche 4 | saltar 120 | basura LOCAL | derrame BANO | tarea levantar|tirar|cepillo|limpiar | sinfin [noche] | desbloquear [FINAL] | insignia CLAVE | todo ...`).
  Se desactivan con `Config.Debug.Comandos = false`.
- Todos los números del juego están en `src/ReplicatedStorage/Shared/Config.lua`; el contenido de cada noche, en `NightData.lua`.

## Pendiente / límites conocidos
- **Servidores**: el servidor público (el de entrada) solo muestra el menú y la sala de espera; nunca corre un turno, así que los 60 que caben ahí no comparten partida. Crear o unirse a una sala **no te cambia de servidor**: la sala es un registro compartido (MemoryStore) y cada jugador la ve desde donde está. Al apretar **Iniciar**, el anfitrión reserva un servidor de juego y todo el equipo se teletransporta junto; ahí el turno arranca cuando llegaron todos (o a los 20 s). "Un jugador" también abre un servidor de juego propio. Desde Ajustes (M) se vuelve al menú.
- **Salas (multijugador)**: ver `Salas.lua` y `Partida.lua`. En Studio no hay teletransporte ni MemoryStore asegurado: ahí la sala es el propio servidor (modo local; se prueba con *Start Server* + varios clientes). Con `Config.Salas.SimularNube = true` Studio simula el servidor de entrada con un MemoryStore en memoria (el comando `node dbg.js salasim` muestra los teletransportes anotados). La parte entre servidores reales no se pudo probar en Studio: probala publicada con dos cuentas.


