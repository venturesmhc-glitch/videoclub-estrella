# Reel de la actualización (Instagram / TikTok / Shorts)

Video vertical de 23 s (1080x1920, 30 fps) que anuncia lo nuevo del juego con texto en pantalla y termina en **¡JUGÁ STAR VIDEOCLUB!**.
El archivo terminado es `promo/reel/reel_actualizacion.mp4` (no se sube a git: está en `.gitignore`; los scripts para rehacerlo sí).

## Guion
| Seg. | Bloque | Texto en pantalla |
|---|---|---|
| 0 – 2,4 | Cinta con "● REC" y fecha 1997 | ACTUALIZACIÓN · STAR VIDEOCLUB |
| 2,5 – 6,1 | El Socio N° 0000 se acerca a tirones y abre la cara (Blender) | EL SOCIO N° 0000 TE PERSIGUE · No lo pierdas de vista. Si te toca, te graba. |
| 6,2 – 9,7 | El Trepador avanza hacia la cámara (Blender) | ALGO CAMINA POR EL TECHO, NO MIRÉS ARRIBA · Marcala con Q antes de que salte. |
| 9,8 – 13,8 | Tarjeta de novedades | NUEVO: MODO SIN FIN: RANKING GLOBAL · DESAFÍO DIARIO · UN LOCAL RENOVADO |
| 13,9 – 19,6 | Tres capturas del local en Studio con zoom lento | ASÍ SE VE EL VIDEOCLUB · Alfombras, afiches y neones · Pochoclos y arcades · Bienvenido a Star Videoclub |
| 19,7 – 23,1 | Pantalla final con el logo | ¡JUGÁ STAR VIDEOCLUB! · Buscalo en Roblox · Terror analógico · 1 a 4 jugadores |

Texto dentro de la franja central (fuera del 10 % de arriba y el 15 % de abajo, donde Instagram pone su interfaz). Sonido sintetizado con ffmpeg
(zumbido grave, estática y golpes en los sustos): no hay música con copyright. Se puede reemplazar por el audio original del juego al subirlo.

## Cómo rehacerlo
Necesita Blender 5.x, ffmpeg y Pillow (`pip install pillow`). Rutas de ejemplo (cambiá `G:\blender.exe` por la tuya):

```
G:\blender.exe -b assets/socio/socio.blend --python promo/reel/blender_socio.py -- <carpeta>/socio
G:\blender.exe -b assets/trepador/trepador.blend --python promo/reel/blender_trepador.py -- <carpeta>/trepador
python promo/reel/armar_reel.py <trabajo> <capturas> <carpeta>/socio <carpeta>/trepador promo/reel/reel_actualizacion.mp4
```
- Los dos scripts de Blender corren sin abrir la interfaz (con `preview` al final renderizan 3 cuadros chicos para encuadrar). Vuelven a enlazar las texturas
  de `assets/` porque los `.blend` las guardan con la ruta de la máquina donde se armaron.
- `<capturas>` es una carpeta (`promo/reel/capturas/` trae las usadas) con `h1_puerta.jpg`, `h2_pochoclos.jpg` y `h4_salon.jpg`: capturas del local hechas en Studio (herramienta `screen_capture`
  con cámara en (0, 5.2, 24) mirando a la puerta, (13, 6, 15) hacia los pochoclos y (0, 8.5, 32.5) hacia el fondo).
- Para cambiar textos, tiempos o capturas se edita `armar_reel.py` (los textos están al principio de cada bloque).

## Antes de publicarlo
El reel anuncia cosas que tienen que estar **publicadas** (Alt+P en Studio): el Socio más agresivo, la criatura compartida (la ven todos los jugadores), el ranking y el desafío diario
de Sin fin y el local renovado. Texto sugerido para la publicación: `promo/reel/TEXTO.md`.
