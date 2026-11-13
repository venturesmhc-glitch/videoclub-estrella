"""
Arma el reel de la actualización (vertical 1080x1920, 30 fps) con ffmpeg a partir de:
  - los cuadros que renderiza Blender (blender_socio.py y blender_trepador.py),
  - capturas del local hechas en Studio (carpeta de capturas: h1_puerta.jpg, h2_pochoclos.jpg, h4_salon.jpg),
  - la imagen del juego assets/icono-512.png.
Los textos se dibujan con Pillow (letra "de píxeles" de Consolas escalada sin suavizar, parecida a la del juego) y se pegan con ffmpeg.
El sonido se sintetiza con ffmpeg (zumbido grave, estática y golpes): no usa música con copyright.

Uso:
  python promo/reel/armar_reel.py <carpeta de trabajo> <carpeta de capturas> <cuadros del Socio> <cuadros del Trepador> <salida.mp4>
Necesita ffmpeg en el PATH y Pillow (pip install pillow).
"""
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

W, H, FPS = 1080, 1920, 30
RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FUENTE = "C:/Windows/Fonts/consolab.ttf"
ESCALA = 4  # los textos se dibujan a 1/4 y se agrandan sin suavizar: letra "de píxeles"

AMARILLO = (255, 222, 90)
CIAN = (90, 235, 255)
ROJO = (255, 70, 80)
BLANCO = (245, 245, 235)
ROSA = (255, 60, 180)

TRABAJO, CAPTURAS, CUADROS_SOCIO, CUADROS_TREPADOR, SALIDA = sys.argv[1:6]
os.makedirs(TRABAJO, exist_ok=True)


def ruta(*partes):
    return os.path.join(TRABAJO, *partes).replace("\\", "/")


def ff(*args):
    cmd = ["ffmpeg", "-y", "-loglevel", "error", *map(str, args)]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print("ffmpeg falló:\n", " ".join(cmd), "\n", r.stderr[-2000:])
        sys.exit(1)


def tarjeta(nombre, lineas):
    """PNG transparente 1080x1920 con líneas de texto: [(texto, y_centro, tamaño, color)]. Tamaño en píxeles de la letra chica."""
    chico = Image.new("RGBA", (W // ESCALA, H // ESCALA), (0, 0, 0, 0))
    d = ImageDraw.Draw(chico)
    d.fontmode = "1"
    for texto, y, tam, color in lineas:
        fuente = ImageFont.truetype(FUENTE, tam)
        ancho = d.textlength(texto, font=fuente)
        x = (chico.width - ancho) / 2
        yy = y / ESCALA - tam * 0.62
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
            d.text((x + dx, yy + dy), texto, font=fuente, fill=(0, 0, 0, 255))
        d.text((x + 1, yy + 1), texto, font=fuente, fill=(*ROSA, 255))  # desfase de color: se ve "cinta"
        d.text((x - 1, yy), texto, font=fuente, fill=(*CIAN, 255))
        d.text((x, yy), texto, font=fuente, fill=(*color, 255))
    grande = chico.resize((W, H), Image.NEAREST)
    p = ruta(nombre + ".png")
    grande.save(p)
    return p


VF_COMUN = "format=yuv420p"
CODEC = ["-c:v", "libx264", "-crf", "16", "-preset", "medium", "-pix_fmt", "yuv420p", "-r", str(FPS)]


def fondo_estatica(dur, color="black", fuerza=22):
    return ["-f", "lavfi", "-i", f"color=c={color}:s={W}x{H}:r={FPS}:d={dur},noise=alls={fuerza}:allf=t"]


def con_texto(base_filtro, capas):
    """Encadena overlays de PNG: capas = [(índice de entrada, inicio, fin, jitter)] sobre [v]. Devuelve el filtro final y la etiqueta."""
    partes = [f"{base_filtro}[v0]"]
    etiqueta = "v0"
    for n, (idx, ini, fin, jitter) in enumerate(capas, start=1):
        alfa = f"[{idx}:v]format=rgba,fade=t=in:st={ini}:d=0.18:alpha=1,fade=t=out:st={fin - 0.18}:d=0.18:alpha=1[c{n}]"
        if jitter:
            x = f"if(lt(mod(t,0.7),0.07),(random(1)-0.5)*46,0)"
        else:
            x = "0"
        partes.append(alfa)
        partes.append(f"[{etiqueta}][c{n}]overlay=x='{x}':y=0:enable='between(t,{ini},{fin})'[v{n}]")
        etiqueta = f"v{n}"
    return ";".join(partes), etiqueta


# ---------------------------------------------------------------- duraciones
D_INTRO, D_SOCIO, D_TREP, D_FICHA, D_SALON, D_FIN, D_TRANS = 2.4, 3.6, 3.4, 4.0, 1.9, 3.4, 0.13
segmentos = []

# ---------------------------------------------------------------- A. intro
a_titulo = tarjeta("a_titulo", [("ACTUALIZACIÓN", 940, 30, AMARILLO), ("STAR VIDEOCLUB", 1100, 19, CIAN)])
a_rec = tarjeta("a_rec", [("● REC", 250, 14, ROJO), ("NOV 1997 · 03:16", 335, 11, BLANCO)])
fc, et = con_texto(f"[0:v]null", [(1, 0.15, D_INTRO, True), (2, 0.0, D_INTRO, False)])
ff(*fondo_estatica(D_INTRO), "-loop", "1", "-t", D_INTRO, "-i", a_titulo, "-loop", "1", "-t", D_INTRO, "-i", a_rec,
   "-filter_complex", fc, "-map", f"[{et}]", "-t", D_INTRO, *CODEC, ruta("seg_a.mp4"))
segmentos.append(("seg_a.mp4", D_INTRO))

# ---------------------------------------------------------------- B. el Socio
b_arriba = tarjeta("b_arriba", [("EL SOCIO N° 0000", 330, 24, AMARILLO), ("AHORA TE CAZA", 480, 28, ROJO)])
b_abajo = tarjeta("b_abajo", [("No lo pierdas de vista.", 1450, 13, BLANCO), ("Si te toca, te graba.", 1540, 13, BLANCO)])
flash = f"drawbox=x=0:y=0:w=iw:h=ih:color=white@0.85:t=fill:enable='between(t,{0.72 * D_SOCIO:.2f},{0.72 * D_SOCIO + 0.1:.2f})'"
fc, et = con_texto(f"[0:v]{flash}", [(1, 0.25, D_SOCIO, False), (2, 0.9, D_SOCIO, False)])
ff("-framerate", FPS, "-i", f"{CUADROS_SOCIO}/socio_%04d.png", "-loop", "1", "-t", D_SOCIO, "-i", b_arriba,
   "-loop", "1", "-t", D_SOCIO, "-i", b_abajo, "-filter_complex", fc, "-map", f"[{et}]", "-t", D_SOCIO, *CODEC, ruta("seg_b.mp4"))
segmentos.append(("seg_b.mp4", D_SOCIO))

# ---------------------------------------------------------------- C. la criatura
c_arriba = tarjeta("c_arriba", [("ALGO CAMINA POR EL TECHO", 330, 19, AMARILLO), ("TODO EL EQUIPO LO VE", 480, 20, CIAN)])
c_abajo = tarjeta("c_abajo", [("Marcala con Q antes de que salte.", 1500, 13, BLANCO)])
fc, et = con_texto("[0:v]null", [(1, 0.25, D_TREP, False), (2, 1.0, D_TREP, False)])
ff("-framerate", FPS, "-i", f"{CUADROS_TREPADOR}/trepador_%04d.png", "-loop", "1", "-t", D_TREP, "-i", c_arriba,
   "-loop", "1", "-t", D_TREP, "-i", c_abajo, "-filter_complex", fc, "-map", f"[{et}]", "-t", D_TREP, *CODEC, ruta("seg_c.mp4"))
segmentos.append(("seg_c.mp4", D_TREP))

# ---------------------------------------------------------------- D. novedades (texto)
d_nuevo = tarjeta("d_nuevo", [("NUEVO", 400, 34, ROJO)])
lineas_d = [
    ("MODO SIN FIN:", "RANKING GLOBAL", 700),
    ("DESAFÍO DIARIO", "", 1000),
    ("UN LOCAL RENOVADO", "", 1200),
]
d_tarjetas = []
for i, (t1, t2, y) in enumerate(lineas_d):
    if t2:
        d_tarjetas.append(tarjeta(f"d_{i}", [(t1, y, 21, AMARILLO), (t2, y + 110, 26, CIAN)]))
    else:
        d_tarjetas.append(tarjeta(f"d_{i}", [(t1, y, 21, AMARILLO)]))
entradas = []
capas = [(1, 0.1, D_FICHA, True)]
for i in range(len(d_tarjetas)):
    entradas += ["-loop", "1", "-t", D_FICHA, "-i", d_tarjetas[i]]
    capas.append((i + 2, 0.7 + 0.75 * i, D_FICHA, False))
fc, et = con_texto("[0:v]null", capas)
ff(*fondo_estatica(D_FICHA, "0x10081a", 28), "-loop", "1", "-t", D_FICHA, "-i", d_nuevo, *entradas,
   "-filter_complex", fc, "-map", f"[{et}]", "-t", D_FICHA, *CODEC, ruta("seg_d.mp4"))
segmentos.append(("seg_d.mp4", D_FICHA))

# ---------------------------------------------------------------- E. el local (capturas de Studio)
e_titulo = tarjeta("e_titulo", [("ASÍ SE VE", 330, 26, AMARILLO), ("EL VIDEOCLUB", 480, 26, CIAN)])
fotos = [
    ("h4_salon.jpg", "Alfombras, afiches y neones"),
    ("h2_pochoclos.jpg", "Pochoclos y arcades"),
    ("h1_puerta.jpg", "Abierto las 24 horas"),
]
for i, (foto, pie) in enumerate(fotos):
    e_pie = tarjeta(f"e_pie{i}", [(pie, 1470, 12, BLANCO)])
    foco = (
        f"[0:v]split[bg][fg];"
        f"[bg]scale=-2:{H},crop={W}:{H},boxblur=28:3,eq=brightness=-0.22:saturation=1.0[b];"
        f"[fg]crop=ih*1.5:ih,scale=2160:1440,zoompan=z='1+0.0022*on':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s={W}x720:fps={FPS}[f];"
        f"[b][f]overlay=0:(H-h)/2,"
        f"drawbox=x=0:y=598:w={W}:h=4:color=0xff2db4:t=fill,drawbox=x=0:y=1320:w={W}:h=4:color=0x28e1ff:t=fill[v0];"
        f"[1:v]format=rgba,fade=t=in:st=0.1:d=0.2:alpha=1[t];[2:v]format=rgba,fade=t=in:st=0.25:d=0.2:alpha=1[p];"
        f"[v0][t]overlay=0:0[v1];[v1][p]overlay=0:0[v2]"
    )
    ff("-loop", "1", "-framerate", FPS, "-t", D_SALON, "-i", f"{CAPTURAS}/{foto}", "-loop", "1", "-t", D_SALON, "-i", e_titulo,
       "-loop", "1", "-t", D_SALON, "-i", e_pie, "-filter_complex", foco, "-map", "[v2]", "-t", D_SALON, *CODEC, ruta(f"seg_e{i}.mp4"))
    segmentos.append((f"seg_e{i}.mp4", D_SALON))

# ---------------------------------------------------------------- F. final
f_texto = tarjeta("f_texto", [("¡JUGÁ", 1150, 34, AMARILLO), ("STAR VIDEOCLUB!", 1290, 22, AMARILLO),
                              ("Buscalo en Roblox", 1440, 16, CIAN), ("Terror analógico · 1 a 4 jugadores", 1530, 11, BLANCO)])
fc, et = con_texto(
    f"[0:v][1:v]overlay=x=(W-w)/2:y=400:enable='gte(t,0.1)'",
    [(2, 0.35, D_FIN, False)],
)
icono = ruta("icono.png")
Image.open(os.path.join(RAIZ, "assets", "icono-512.png")).convert("RGBA").resize((640, 640), Image.LANCZOS).save(icono)
ff(*fondo_estatica(D_FIN, "black", 30), "-loop", "1", "-t", D_FIN, "-i", icono, "-loop", "1", "-t", D_FIN, "-i", f_texto,
   "-filter_complex", fc, "-map", f"[{et}]", "-t", D_FIN, *CODEC, ruta("seg_f.mp4"))
segmentos.append(("seg_f.mp4", D_FIN))

# ---------------------------------------------------------------- transición: ráfaga de estática
ff("-f", "lavfi", "-i", f"color=c=0x303038:s={W}x{H}:r={FPS}:d={D_TRANS},noise=alls=100:allf=t", *CODEC, ruta("trans.mp4"))

# ---------------------------------------------------------------- unir
lista = ruta("lista.txt")
tiempos = []  # inicio de cada segmento
t = 0.0
with open(lista, "w", encoding="utf8") as f:
    for i, (nombre, dur) in enumerate(segmentos):
        f.write("file '" + ruta(nombre) + "'" + chr(10))
        tiempos.append((nombre, t))
        t += dur
        # ráfaga de estática entre bloques (entre las tres fotos del local el corte es seco)
        if i < len(segmentos) - 1 and nombre not in ("seg_e0.mp4", "seg_e1.mp4"):
            f.write("file '" + ruta("trans.mp4") + "'" + chr(10))
            t += D_TRANS
TOTAL = t
ff("-f", "concat", "-safe", "0", "-i", lista, "-c", "copy", ruta("union.mp4"))

# ---------------------------------------------------------------- audio sintetizado
ini = dict(tiempos)
golpes = [
    (ini["seg_a.mp4"], 1.0),
    (ini["seg_b.mp4"] + 0.72 * D_SOCIO, 1.5),  # se abre la cara del Socio
    (ini["seg_c.mp4"] + 0.82 * D_TREP, 1.0),  # la criatura abre la boca
    (ini["seg_d.mp4"], 0.7),
    (ini["seg_e0.mp4"], 0.6),
    (ini["seg_f.mp4"] + 0.1, 1.3),
]
clics = [ini["seg_d.mp4"] + 0.7 + 0.75 * i for i in range(4)] + [ini["seg_e0.mp4"] + k * D_SALON for k in (1, 2)]
entradas_audio = [
    "-f", "lavfi", "-i", f"sine=f=49:r=44100:d={TOTAL}",
    "-f", "lavfi", "-i", f"sine=f=73.4:r=44100:d={TOTAL}",
    "-f", "lavfi", "-i", f"anoisesrc=d={TOTAL}:c=pink:a=0.5:r=44100",
]
filtros = [
    "[0:a]volume=0.55,tremolo=f=0.33:d=0.7[g1]",
    "[1:a]volume=0.22,tremolo=f=0.21:d=0.8[g2]",
    "[2:a]highpass=f=1800,lowpass=f=7000,volume=0.05[hiss]",
]
mezcla = ["[g1]", "[g2]", "[hiss]"]
n = 3
for (momento, fuerza) in golpes:
    entradas_audio += ["-f", "lavfi", "-i",
                       f"aevalsrc='(sin(2*PI*(70-45*t)*t)*exp(-5*t)+0.5*(random(0)*2-1)*exp(-18*t))*{0.9 * fuerza}':s=44100:d=1.4"]
    filtros.append(f"[{n}:a]adelay=delays={int(momento * 1000)}:all=1[k{n}]")
    mezcla.append(f"[k{n}]")
    n += 1
for momento in clics:
    entradas_audio += ["-f", "lavfi", "-i", "aevalsrc='(random(0)*2-1)*exp(-60*t)*0.5':s=44100:d=0.2"]
    filtros.append(f"[{n}:a]adelay=delays={int(momento * 1000)}:all=1[k{n}]")
    mezcla.append(f"[k{n}]")
    n += 1
filtros.append(f"{''.join(mezcla)}amix=inputs={len(mezcla)}:normalize=0,lowpass=f=9000,alimiter=limit=0.9,afade=t=out:st={TOTAL - 0.6:.2f}:d=0.6,aformat=channel_layouts=stereo[sal]")
with open(ruta("audio.txt"), "w", encoding="utf8") as f:
    f.write(";\n".join(filtros))
ff(*entradas_audio, "-/filter_complex", ruta("audio.txt"), "-map", "[sal]", "-t", f"{TOTAL:.2f}", "-c:a", "pcm_s16le", ruta("audio.wav"))

# ---------------------------------------------------------------- acabado "cinta VHS" + audio
vhs = (
    "rgbashift=rh=-5:bh=5:gh=0,"
    "noise=alls=6:allf=t,"
    f"drawgrid=w=4000:h=4:t=1:c=black@0.20,"
    "vignette=PI/4.6,"
    "eq=contrast=1.07:saturation=1.12,"
    "format=yuv420p"
)
ff("-i", ruta("union.mp4"), "-i", ruta("audio.wav"), "-vf", vhs, "-c:v", "libx264", "-crf", "23", "-maxrate", "14M", "-bufsize", "28M", "-preset", "slow", "-pix_fmt", "yuv420p",
   "-r", str(FPS), "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", "-shortest", SALIDA)
print(f"Listo: {SALIDA} ({TOTAL:.1f} s)")
