@echo off
rem Convierte un clip grabado con OBS (16:9) a vertical 9:16 (1080x1920) recortando el centro.
rem Genera dos archivos junto al original:
rem   NOMBRE_9x16.mp4       el clip recortado
rem   NOMBRE_9x16_final.mp4 el mismo + 1 s de negro al final con "STAR VIDEOCLUB · Buscalo en Roblox"
rem Uso:  promo\vertical.cmd C:\ruta\clip.mp4        (necesita ffmpeg en el PATH: winget install Gyan.FFmpeg)
setlocal EnableDelayedExpansion
if "%~1"=="" ( echo uso: promo\vertical.cmd clip.mp4 & exit /b 1 )
where ffmpeg >nul 2>&1 || ( echo No encuentro ffmpeg. Instalalo con: winget install Gyan.FFmpeg ^(y abri una terminal nueva^) & exit /b 1 )
set "ENTRADA=%~f1"
set "BASE=%~dpn1"
set "CROP=crop=ih*9/16:ih,scale=1080:1920:flags=lanczos,setsar=1"
ffmpeg -y -i "%ENTRADA%" -vf "%CROP%" -c:v libx264 -crf 18 -preset slow -pix_fmt yuv420p -c:a aac -b:a 192k "%BASE%_9x16.mp4" || exit /b 1
for /f %%d in ('ffprobe -v error -show_entries format^=duration -of csv^=p^=0 "%BASE%_9x16.mp4"') do set "DUR=%%d"
rem Texto en el centro del cuadro (fuera del 10%% de arriba y del 15%% de abajo).
ffmpeg -y -i "%BASE%_9x16.mp4" -vf "tpad=stop_mode=add:stop_duration=1:color=black,drawtext=text='STAR VIDEOCLUB · Buscalo en Roblox':fontfile=C\:/Windows/Fonts/consola.ttf:fontsize=44:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2:enable='gte(t,!DUR!)'" -af "apad=pad_dur=1" -c:v libx264 -crf 18 -preset slow -pix_fmt yuv420p -c:a aac -b:a 192k "%BASE%_9x16_final.mp4" || exit /b 1
echo Listo: "%BASE%_9x16.mp4" y "%BASE%_9x16_final.mp4"
