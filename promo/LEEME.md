# Clips de promoción (TikTok / Reels / Shorts)

## Preparar
1. `Config.Debug.ModoGrabacion = true` en `src/ReplicatedStorage/Shared/Config.lua` y `node push.js`. **Ponelo en `false` antes de publicar el juego.**
2. En Studio: Play (el juego queda en el menú; el clip lo oculta al arrancar).
3. OBS: resolución de salida 1920x1080 (o la de tu ventana), 30 fps, fuente = captura de ventana/pantalla de Studio **y** "Captura de audio de aplicación" de `RobloxStudioBeta.exe` (el audio del escritorio, silenciado).
4. Studio tiene que estar a la vista y con el foco: minimizado no dibuja el 3D y sin foco Roblox lo silencia. `node dbg.js cine ...` lo trae al frente solo.

## Grabar un clip
1. REC en OBS. 2. En la terminal del proyecto: `node dbg.js cine NOMBRE`. 3. Hay 3 s de negro y arranca. 4. Al terminar (queda 2 s de negro) frená OBS.
`node dbg.js cine lista` muestra los clips; `node dbg.js cine parar` corta. `node dbg.js cine NOMBRE 8 foto` congela el clip en el segundo 8 (para encuadrar).

| Clip | Nombre | Duración |
|---|---|---|
| 1. Turno noche | `turno_noche` | 20 s |
| 2. La cinta de las 3:33 | `cinta_333` | 19 s |
| 3. No mirés arriba | `no_mires_arriba` | 15 s |
| 4. Mirá bien | `mira_bien` | 16 s |
| 5. Socio N° 0000 | `socio_0000` | 16 s |

## Vertical (9:16)
Se graba en 16:9 y se recorta el centro (`Config.Cinematicas.Vertical = true` ya compone el plano para eso: OSD en la franja central, sin texto en el 10% de arriba ni el 15% de abajo). `promo\vertical.cmd clip.mp4` recorta a 1080x1920 y arma una versión con 1 s de negro y "STAR VIDEOCLUB · Buscalo en Roblox" (necesita ffmpeg: `winget install Gyan.FFmpeg`). `Config.Cinematicas.GuiaVertical = true` dibuja el recorte sobre el cuadro para encuadrar (apagarla al grabar).

## Cambiar o crear un clip (solo datos)
Todo está en `src/ReplicatedStorage/Shared/Cinematicas.lua` (la cabecera lista todos los eventos). Un clip es una tabla con `duracion`, `osd`, `camara` (puntos con `pos`, `mira`, `t`) y `eventos` (`osd`, `luz`, `socio`, `trepador`, `casete`, `portada`, `linterna`, `sonido`, `estatica`, `negro`). Agregalo a `Cinematicas.Clips` y a `Cinematicas.orden`, `node push.js`, reiniciá el Play.
Las capturas de revisión (`promo/recortar.ps1`, `promo/montaje.ps1`) recortan a 9:16 y arman tiras; las de cada clip están en `promo/revision/`.
