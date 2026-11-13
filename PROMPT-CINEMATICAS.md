# Prompt para Claude Code — Cinemáticas para TikTok / Reels / YouTube

Pegar esto en Claude Code abierto en la carpeta `rolbox` (con Studio abierto en starvideoclub y Blender con el add-on MCP en Start).

---

Quiero hacer clips cortos de promoción de Star Videoclub para TikTok, Reels y YouTube Shorts. Antes de empezar leé LEEME.md y assets/FICHA.md para entender el juego. Usá lo que ya existe en el proyecto; no rehagas sistemas que ya están.

## Lo que ya tenemos y tenés que aprovechar
- MCP de Roblox Studio (node mcp-call.js / .mcp.json) y MCP de Blender (blender-mcp.js).
- El filtro VHS del juego (Client/Filtro.lua, Client/VHSEffects.lua) y la interfaz de videocasetera (Client/OSD.lua: "▶ PLAY", contador y fecha). Las cinemáticas tienen que verse con ese filtro y ese OSD, no con un filtro nuevo.
- El Socio N° 0000 (ReplicatedStorage.SocioModelo, animado con Shared/SocioHuesos.lua y Client/SocioAnimacion.lua, con gestos y la cara que se abre) y el Trepador (ReplicatedStorage.TrepadorModelo, Client/Trepador.lua). Usá sus animaciones y gestos reales.
- Los modelos de Blender: blender/socio.py, blender/trepador.py, blender/comun.py y assets/*/ *.blend.
- dbg.js para poner el juego en un estado concreto (noche 4, corte de luz, etc.).

## Qué quiero
Un sistema de cinemáticas para grabar con OBS, dentro de Studio:
1. Un módulo cliente nuevo, Client/Cinematica.lua, que tome el control de la cámara (CameraType Scriptable), recorra puntos de cámara con TweenService y easing suave, y agregue un leve temblor de cámara en mano. Que use el FOV de Config.
2. Un "modo grabación" activable con Config.Debug.ModoGrabacion = true y con un comando nuevo de dbg.js (`node dbg.js cine NOMBRE`): oculta la ficha de socio, la barra de energía, los carteles flotantes y el menú, pero deja el filtro VHS y el OSD. La cinemática arranca a los 3 segundos.
3. Cada clip definido como datos en una tabla (Config.Cinematicas o un archivo Shared/Cinematicas.lua): puntos de cámara, tiempos, eventos sincronizados (parpadeo de luces con LuzFluorescente, estado del OSD, aparición del Socio o del Trepador, gestos, sonidos) y la hora que muestra el OSD. Así puedo pedirte cambios chicos sin reescribir código.
4. Un modo de encuadre vertical: una opción para que la acción importante quede en el centro, para recortar a 9:16 sin perder nada.
5. Que nada de esto afecte el juego normal: si ModoGrabacion está en false, no se carga.

## Los primeros 5 clips (15 a 25 segundos cada uno)
1. "Turno noche": cámara lenta por las góndolas, OSD en "NOV 16 1997 03:16", radio sonando. Al fondo, el Socio quieto entre los estantes. La luz fluorescente parpadea y cuando vuelve ya no está. Corte a negro.
2. "La cinta de las 3:33": el buzón, cae el casete sin etiqueta, plano de la videocasetera, OSD pasa a "▶ PLAY", estática y corte.
3. "No mires arriba": plano del mostrador, la cámara sube despacio al techo y ahí está el Trepador cabeza abajo; gira la cabeza 180° y se corta.
4. "Mirá bien": el local vacío con una anomalía chiquita (un título que no existe). Que se quede quieto 2 segundos de más. Para el formato "¿viste lo que hay en el segundo 3?".
5. "Socio N° 0000": el Socio avanza a tirones por el pasillo, la linterna lo alumbra, se frena, ladea la cabeza y a menos de BocaDistancia la cara se abre. Corte en el momento justo (sin mostrar el screamer completo).

## Cómo trabajar
- Antes de grabar nada, para cada clip sacá 3 o 4 capturas de los momentos clave con el MCP de Studio (como hace foto.sh), miralas y corregí encuadre y luz. Mostrámelas y esperá mi OK antes de seguir con el siguiente clip.
- Para planos que en el juego no se puedan lograr bien (primerísimos planos de la cara del Socio, la boca del Trepador, una toma tipo póster), usá Blender: render con Eevee a partir de los .blend que ya existen, con luz fría y fondo negro como en blender/render.py. Guardá esos renders en una carpeta nueva, assets/promo/.
- Si ffmpeg está instalado, armá un script (promo/vertical.cmd) que tome un .mp4 grabado con OBS y genere la versión 9:16 (1080x1920) recortando el centro, más una versión con 1 segundo de negro al final con el texto "STAR VIDEOCLUB · Buscalo en Roblox". Si no está, decime cómo instalarlo.

## Reglas
- No borres ni sobrescribas archivos existentes salvo los que tengas que editar para integrar esto (Config.lua, dbg.js, el loader del cliente); en ese caso decime qué cambiaste.
- Sincronizá con node push.js como siempre. Si hace falta tocar el .rbxl, avisame antes.
- Al final, explicame cómo grabar cada clip con OBS (resolución, fps y qué captura conviene usar) y cómo editar un clip nuevo cambiando solo los datos.
