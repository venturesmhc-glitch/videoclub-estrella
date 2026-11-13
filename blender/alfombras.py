# Alfombras estampadas de videoclub de los 90 (texturas que se repiten sin costura).
# Se corre dentro de Blender (puente MCP): genera assets/texturas/alfombra_*.png con numpy, sin renderizar.
import bpy, numpy as np, os, math

SALIDA = r"C:\Users\kilic\Desktop\rolbox\assets\texturas"
os.makedirs(SALIDA, exist_ok=True)
N = 1024

def rng_for(nombre):
    return np.random.default_rng(abs(hash(nombre)) % (2**32) if False else sum(ord(c) * (i + 3) for i, c in enumerate(nombre)))

YY, XX = np.mgrid[0:N, 0:N]
U = (XX + 0.5) / N
V = (YY + 0.5) / N

def envuelto(a, c):
    return ((a - c + 0.5) % 1.0) - 0.5

def suave(d, borde=1.5 / N):
    return np.clip(0.5 - d / borde, 0.0, 1.0)

def rot(dx, dy, a):
    c, s = math.cos(a), math.sin(a)
    return dx * c + dy * s, -dx * s + dy * c

def sdf_circulo(dx, dy, r):
    return np.hypot(dx, dy) - r

def sdf_triangulo(dx, dy, r, a):
    x, y = rot(dx, dy, a)
    k = math.sqrt(3.0)
    x = np.abs(x) - r
    y = y + r / k
    m = x + k * y > 0
    x2 = np.where(m, (x - k * y) / 2, x)
    y2 = np.where(m, (-k * x - y) / 2, y)
    x2 = x2 - np.clip(x2, -2 * r, 0)
    return -np.hypot(x2, y2) * np.sign(y2)

def sdf_caja(dx, dy, w, h, a):
    x, y = rot(dx, dy, a)
    qx, qy = np.abs(x) - w, np.abs(y) - h
    return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0)

def sdf_ondita(dx, dy, largo, amp, grosor, a):
    x, y = rot(dx, dy, a)
    onda = amp * np.sin(x / largo * 2 * math.pi * 1.5)
    d = np.abs(y - onda) - grosor
    return np.maximum(d, np.abs(x) - largo)

def sdf_estrella(dx, dy, r, a):
    x, y = rot(dx, dy, a)
    ang = np.arctan2(y, x)
    rad = np.hypot(x, y)
    k = 0.5 + 0.5 * np.cos(5 * ang)
    return rad - r * (0.45 + 0.55 * k ** 0.6)

def dibujar(img, mascara, color):
    m = mascara[..., None]
    img[:] = img * (1 - m) + np.array(color, dtype=np.float32) * m

def fibra(img, rng, fuerza=0.09):
    # Pelo de la alfombra: ruido fino, rayitas cortas y manchas suaves de desgaste.
    ruido = rng.normal(0, 1, (N, N)).astype(np.float32)
    ruido = (ruido + np.roll(ruido, 1, 0) * 0.5 + np.roll(ruido, 1, 1) * 0.5) / 2
    rayas = rng.normal(0, 1, (N, 1)).astype(np.float32) * 0.35
    grande = rng.normal(0, 1, (16, 16)).astype(np.float32)
    grande = np.kron(grande, np.ones((N // 16, N // 16), dtype=np.float32))
    for _ in range(3):
        grande = (grande + np.roll(grande, 7, 0) + np.roll(grande, 7, 1) + np.roll(grande, -7, 0) + np.roll(grande, -7, 1)) / 5
    f = 1.0 + (ruido * fuerza + rayas * fuerza * 0.5 + grande * 0.045)
    img[:] = np.clip(img * f[..., None], 0, 1)

def guardar(nombre, img):
    rgba = np.ones((N, N, 4), dtype=np.float32)
    rgba[..., :3] = np.clip(img, 0, 1) ** (1 / 1.0)
    # Blender espera filas de abajo hacia arriba
    rgba = rgba[::-1]
    imagen = bpy.data.images.new(nombre, N, N, alpha=False)
    imagen.colorspace_settings.name = "sRGB"
    imagen.pixels.foreach_set(rgba.reshape(-1))
    imagen.filepath_raw = os.path.join(SALIDA, nombre + ".png")
    imagen.file_format = "PNG"
    imagen.save()
    bpy.data.images.remove(imagen)

def rgb(r, g, b):
    return (r / 255, g / 255, b / 255)

def esparcir(img, rng, cantidad, paleta, forma, tam, minsep=0.11):
    centros = []
    intentos = 0
    while len(centros) < cantidad and intentos < 4000:
        intentos += 1
        c = (rng.random(), rng.random())
        ok = True
        for o in centros:
            if math.hypot(envuelto(c[0], o[0]), envuelto(c[1], o[1])) < minsep:
                ok = False
                break
        if ok:
            centros.append(c)
    for i, (cx, cy) in enumerate(centros):
        dx, dy = envuelto(U, cx), envuelto(V, cy)
        col = paleta[int(rng.integers(0, len(paleta)))]
        a = rng.random() * math.pi * 2
        t = tam * (0.75 + rng.random() * 0.5)
        f = forma[int(rng.integers(0, len(forma)))]
        if f == "c":
            d = sdf_circulo(dx, dy, t * 0.55)
        elif f == "t":
            d = sdf_triangulo(dx, dy, t * 0.7, a)
        elif f == "q":
            d = sdf_caja(dx, dy, t * 0.5, t * 0.5, a)
        elif f == "b":
            d = sdf_caja(dx, dy, t * 1.1, t * 0.18, a)
        elif f == "w":
            d = sdf_ondita(dx, dy, t * 1.2, t * 0.28, t * 0.13, a)
        elif f == "s":
            d = sdf_estrella(dx, dy, t * 0.8, a)
        else:
            d = sdf_circulo(dx, dy, t * 0.3)
        dibujar(img, suave(d), col)

def base(color, rng, vari=0.05):
    img = np.ones((N, N, 3), dtype=np.float32) * np.array(color, dtype=np.float32)
    return img

def hacer(nombre, bg, paleta, formas, cant, tam, extra=None, minsep=0.11):
    rng = np.random.default_rng(sum(ord(c) * (i + 3) for i, c in enumerate(nombre)))
    img = base(bg, rng)
    if extra:
        extra(img, rng)
    esparcir(img, rng, cant, paleta, formas, tam, minsep)
    fibra(img, rng)
    guardar(nombre, img)

# 1) Salón: confeti noventoso sobre azul noche (la clásica de los locales de alquiler de películas).
hacer("alfombra_confeti", rgb(22, 24, 78),
      [rgb(0, 190, 185), rgb(226, 40, 150), rgb(255, 208, 44), rgb(246, 110, 28), rgb(240, 240, 250), rgb(120, 60, 200)],
      "ctqwbs", 34, 0.085, minsep=0.14)

# 2) Acción: rojo oscuro con rombos y barras negras y naranjas.
def rombos(img, rng):
    d = np.abs(envuelto(U * 4, 0.0)) + np.abs(envuelto(V * 4, 0.0))
    dibujar(img, suave((d - 0.34) / 4, 3 / N / 1), rgb(36, 8, 10))
hacer("alfombra_accion", rgb(104, 14, 20), [rgb(14, 14, 16), rgb(255, 128, 20), rgb(210, 200, 190)], "tbq", 26, 0.075, rombos, 0.16)

# 3) Terror: verde casi negro con salpicaduras violetas y ondas verdosas.
hacer("alfombra_terror", rgb(14, 26, 22), [rgb(84, 30, 120), rgb(70, 150, 90), rgb(150, 20, 28), rgb(36, 54, 46)], "wcq", 30, 0.085, minsep=0.12)

# 4) Comedia: amarillo mostaza con globos magenta y ondas celestes.
hacer("alfombra_comedia", rgb(222, 160, 24), [rgb(226, 40, 130), rgb(10, 170, 200), rgb(255, 255, 240), rgb(240, 90, 30)], "cwqs", 30, 0.08, minsep=0.13)

# 5) Drama: bordó violáceo con ondas doradas y rombos turquesa.
hacer("alfombra_drama", rgb(84, 24, 68), [rgb(220, 170, 60), rgb(20, 150, 150), rgb(240, 220, 190), rgb(150, 50, 110)], "wqtb", 28, 0.08, minsep=0.14)

# 6) Infantil: celeste con estrellas, círculos y triángulos primarios.
hacer("alfombra_infantil", rgb(40, 110, 200), [rgb(255, 214, 40), rgb(238, 56, 64), rgb(60, 200, 110), rgb(255, 255, 255), rgb(250, 130, 40)], "sctq", 38, 0.085, minsep=0.12)

result = {"ok": True, "archivos": sorted(os.listdir(SALIDA))}
