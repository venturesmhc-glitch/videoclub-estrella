# Videoclub Estrella — cómo jugar y cómo está armado

Juego de terror analógico para Roblox (1 a 4 jugadores, cooperativo). Estás en el turno noche de un videoclub
argentino, noviembre de 1997. Hay cinco noches y tres finales.

## Cómo jugarlo
1. Abrí `starvideoclub` en Roblox Studio (ya está abierto con todo cargado) y apretá **Play**.
   También se puede jugar desde Roblox si publicás el lugar (Archivo → Publicar en Roblox, `Alt+P`).
2. Al entrar aparece el **menú**: Un jugador (arranca el turno), Multijugador (lista de salas públicas; abajo, **Crear** —pública o privada, de 2 a 4 jugadores— y **Unirse por código**; dentro de la sala se ve el código y los jugadores, y el anfitrión la arranca con **Iniciar**), Ajustes (música, ambiente y estática del filtro) y Cómo jugar. **M** abre los ajustes durante el turno.
3. Controles: **WASD** moverte · **E** interactuar · **R** (mantener) segunda acción · **Tab** ocultar la ficha · **G** soltar el casete que llevás ·
   **Q** marcar una anomalía (apuntándole) · **F** linterna (cuando se corta la luz).
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

- **Tareas extra** (para repartir entre varios): las bolsas de basura se llevan al contenedor del patio (puerta del fondo a la derecha; con una bolsa en las manos no se pueden tomar casetes) y las manchas se limpian manteniendo E. La cocina (puerta del fondo a la izquierda) y el baño también tienen tareas.

## Cómo está armado
- `src/` es la fuente de verdad del código (Luau). `node push.js` lo sincroniza a Studio.
- `build/videoclub.lua` reconstruye el local (`node mcp-call.js execute_luau @build/videoclub.lua`).
- Las tareas extra usan dos modelos de la toolbox guardados en el place, en `ServerStorage.Plantillas`: `trash bag` (bolsa) y `trash` (decal de suciedad).
  No viajan con el repo (viven en el `.rbxl`); si faltan, `ChoreSystem` usa una esfera negra y un círculo oscuro. Para ponerlos: `insert_asset` 10795701949 (trash bag) y 12900378954 (trash) y moverlos a esa carpeta.
- `mcp-call.js` es un puente para llamar a las herramientas del servidor MCP de Studio; `studio-mcp.cmd` y `.mcp.json` lo conectan.
- `dbg.js` ejecuta comandos de depuración en el servidor durante el Play (`node dbg.js empezar | estado | noche 4 | saltar 120 | basura LOCAL | derrame BANO | tarea levantar|tirar|limpiar | todo ...`).
  Se desactivan con `Config.Debug.Comandos = false`.
- Todos los números del juego están en `src/ReplicatedStorage/Shared/Config.lua`; el contenido de cada noche, en `NightData.lua`.

## Pendiente / límites conocidos
- **Salas (multijugador)**: en el juego publicado cada sala es un servidor reservado (`Salas.lua`: `ReserveServer` + `TeleportService` + MemoryStore para la lista y los códigos). En Studio no hay teletransporte, así que ahí la sala es el propio servidor (modo local; se prueba con *Start Server* + varios clientes). La parte entre servidores no se pudo probar en Studio: probala publicada con dos cuentas.
- **Audio**: zumbido de tubo, hiss de cinta, aire pesado, ondas beta y música de fondo (ids en `Config.Audio.Capas`, de la Creator Store). Los elegí por nombre y comprobé que cargan, pero no los escuché: ajustalos a gusto.
- **DataStore**: en Studio hace falta activar *Allow Studio Access to API Services* para guardar; en el juego publicado funciona solo.
- Probado con un jugador en Studio; falta probar con 2 a 4 jugadores y en móviles.
