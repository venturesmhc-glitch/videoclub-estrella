# Afiches de peliculas de videoclub (ficticias, estilo VHS de los 90) en un solo atlas de 4x2 afiches.
# Se corre dentro de Blender (puente MCP). Dibuja todo con mallas "emission" y renderiza una vista ortografica.
import bpy, math, os, random

SALIDA = r"C:\Users\kilic\Desktop\rolbox\assets\texturas\afiches.png"
random.seed(1997)

if "Afiches" in bpy.data.scenes:
    bpy.data.scenes.remove(bpy.data.scenes["Afiches"])
CUR = [0.0, 0.0]
escena = bpy.data.scenes.new("Afiches")
bpy.context.window.scene = escena
col = escena.collection
escena.render.engine = "BLENDER_EEVEE"
escena.render.resolution_x = 2048
escena.render.resolution_y = 1536
escena.render.resolution_percentage = 100
escena.render.film_transparent = False
escena.view_settings.view_transform = "Standard"
escena.view_settings.look = "None"
escena.display_settings.display_device = "sRGB"
mundo = bpy.data.worlds.new("MundoAfiches")
mundo.color = (0, 0, 0)
escena.world = mundo

cam_data = bpy.data.cameras.new("CamAfiches")
cam_data.type = "ORTHO"
cam_data.ortho_scale = 8.0
cam = bpy.data.objects.new("CamAfiches", cam_data)
cam.location = (0, 0, 10)
col.objects.link(cam)
escena.camera = cam

_mats = {}


def material(c):
    clave = tuple(round(v, 3) for v in c)
    if clave in _mats:
        return _mats[clave]
    m = bpy.data.materials.new("m")
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    e = nt.nodes.new("ShaderNodeEmission")
    e.inputs["Color"].default_value = (c[0], c[1], c[2], 1)
    e.inputs["Strength"].default_value = 1.0
    s = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(e.outputs["Emission"], s.inputs["Surface"])
    _mats[clave] = m
    return m


def rgb(r, g, b):
    # Los colores de la imagen salen tal cual: se pasa de sRGB a lineal para la emision.
    def lin(v):
        v /= 255
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    return (lin(r), lin(g), lin(b))


def malla(verts, c, z):
    me = bpy.data.meshes.new("p")
    lim = [(min(max(x, CUR[0] - 0.97), CUR[0] + 0.97), min(max(y, CUR[1] - 1.47), CUR[1] + 1.47)) for x, y in verts]
    me.from_pydata([(x, y, z) for x, y in lim], [], [list(range(len(lim)))])
    ob = bpy.data.objects.new("p", me)
    ob.data.materials.append(material(c))
    col.objects.link(ob)
    return ob


def rect(cx, cy, w, h, c, z, giro=0):
    pts = [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)]
    ca, sa = math.cos(giro), math.sin(giro)
    return malla([(cx + x * ca - y * sa, cy + x * sa + y * ca) for x, y in pts], c, z)


def circulo(cx, cy, r, c, z, rx=None, ry=None, seg=40):
    rx = rx or r
    ry = ry or r
    return malla([(cx + math.cos(2 * math.pi * i / seg) * rx, cy + math.sin(2 * math.pi * i / seg) * ry) for i in range(seg)], c, z)


def estrella(cx, cy, r1, r2, picos, c, z, giro=0):
    pts = []
    for i in range(picos * 2):
        a = giro + math.pi * i / picos
        r = r1 if i % 2 == 0 else r2
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return malla(pts, c, z)


def poligono(pts, c, z):
    return malla(pts, c, z)


def texto(body, cx, cy, tam, c, z, giro=0):
    cu = bpy.data.curves.new("t", "FONT")
    cu.body = body
    cu.size = tam
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    cu.space_line = 0.95
    ob = bpy.data.objects.new("t", cu)
    ob.location = (cx, cy, z)
    ob.rotation_euler = (0, 0, giro)
    ob.data.materials.append(material(c))
    col.objects.link(ob)
    return ob


def degradado(cx, cy, w, h, arriba, abajo, z, tiras=28):
    for i in range(tiras):
        t = i / (tiras - 1)
        c = tuple(arriba[k] * (1 - t) + abajo[k] * t for k in range(3))
        rect(cx, cy + h / 2 - (i + 0.5) * h / tiras, w, h / tiras + 0.004, rgb(*c), z)


def afiche(i, f):
    cx = -3 + (i % 4) * 2
    cy = 1.5 - (i // 4) * 3
    CUR[0], CUR[1] = cx, cy
    rect(cx, cy, 2.0, 3.0, rgb(240, 236, 224), 0.0)  # papel con un borde finito
    f(cx, cy)


def terror(cx, cy):
    degradado(cx, cy, 1.92, 2.92, (8, 0, 2), (110, 12, 16), 0.01)
    circulo(cx + 0.25, cy + 0.55, 0.55, rgb(246, 238, 206), 0.02)
    for dx, dy, r in ((0.05, 0.7, 0.08), (0.4, 0.4, 0.06), (0.35, 0.8, 0.05)):
        circulo(cx + dx, cy + dy, r, rgb(210, 196, 160), 0.03)
    rect(cx - 0.1, cy - 0.35, 1.1, 0.7, rgb(6, 2, 4), 0.04)
    poligono([(cx - 0.75, cy - 0.0), (cx + 0.55, cy - 0.0), (cx - 0.1, cy + 0.65)], rgb(6, 2, 4), 0.04)
    rect(cx + 0.35, cy + 0.2, 0.14, 0.5, rgb(6, 2, 4), 0.04)
    for ex, ey in ((-0.4, -0.25), (0.15, -0.25), (-0.1, 0.1)):
        rect(cx + ex, cy + ey, 0.17, 0.22, rgb(255, 200, 70), 0.05)
    for k in range(9):
        x = cx - 0.9 + k * 0.23 + random.uniform(-0.04, 0.04)
        h = random.uniform(0.15, 0.55)
        rect(x, cy + 1.46 - h / 2, 0.07, h, rgb(170, 8, 16), 0.06)
        circulo(x, cy + 1.46 - h, 0.052, rgb(170, 8, 16), 0.06)
    texto("NOCHE DE\nCUCHILLAS III", cx, cy - 0.98, 0.27, rgb(236, 230, 206), 0.07)
    texto("NO CIERRES LA PUERTA", cx, cy - 1.33, 0.095, rgb(220, 40, 40), 0.07)


def accion(cx, cy):
    degradado(cx, cy, 1.92, 2.92, (14, 14, 26), (236, 112, 20), 0.01)
    estrella(cx, cy + 0.35, 0.92, 0.5, 14, rgb(255, 208, 40), 0.02, 0.1)
    estrella(cx, cy + 0.35, 0.62, 0.34, 14, rgb(255, 128, 20), 0.03, 0.3)
    circulo(cx, cy + 0.35, 0.28, rgb(255, 252, 230), 0.04)
    circulo(cx - 0.1, cy - 0.12, 0.12, rgb(8, 8, 12), 0.05)
    poligono([(cx - 0.3, cy - 0.25), (cx + 0.08, cy - 0.25), (cx + 0.18, cy - 0.7), (cx - 0.05, cy - 0.82), (cx - 0.35, cy - 0.6)], rgb(8, 8, 12), 0.05)
    poligono([(cx - 0.3, cy - 0.45), (cx - 0.7, cy - 0.7), (cx - 0.62, cy - 0.78), (cx - 0.2, cy - 0.58)], rgb(8, 8, 12), 0.05)
    poligono([(cx + 0.02, cy - 0.7), (cx + 0.3, cy - 1.0), (cx + 0.4, cy - 0.93), (cx + 0.15, cy - 0.58)], rgb(8, 8, 12), 0.05)
    texto("EXPLOSIÓN\nFINAL", cx, cy - 1.15, 0.3, rgb(255, 214, 50), 0.07)
    texto("LA CUENTA REGRESIVA YA EMPEZÓ", cx, cy + 1.38, 0.09, rgb(255, 240, 210), 0.07)


def comedia(cx, cy):
    degradado(cx, cy, 1.92, 2.92, (255, 214, 44), (255, 120, 170), 0.01)
    for k in range(18):
        x, y = cx + random.uniform(-0.9, 0.9), cy + random.uniform(-0.2, 1.4)
        c = random.choice(((0, 170, 200), (230, 40, 130), (250, 250, 250), (110, 60, 200)))
        circulo(x, y, random.uniform(0.04, 0.09), rgb(*c), 0.02)
    for dx, cc, sombrero in ((-0.45, (30, 90, 200), False), (0.45, (220, 50, 40), True)):
        circulo(cx + dx, cy + 0.35, 0.28, rgb(250, 208, 168), 0.04)
        circulo(cx + dx - 0.09, cy + 0.4, 0.035, rgb(20, 20, 20), 0.05)
        circulo(cx + dx + 0.09, cy + 0.4, 0.035, rgb(20, 20, 20), 0.05)
        circulo(cx + dx, cy + 0.26, 0.1, rgb(150, 30, 30), 0.05, 0.1, 0.05)
        rect(cx + dx, cy - 0.25, 0.55, 0.7, rgb(*cc), 0.04)
        if sombrero:
            rect(cx + dx, cy + 0.68, 0.55, 0.07, rgb(30, 30, 40), 0.05)
            rect(cx + dx, cy + 0.82, 0.32, 0.26, rgb(30, 30, 40), 0.05)
    texto("DOS LOCOS Y\nUN DESTINO", cx, cy - 0.98, 0.25, rgb(30, 50, 150), 0.07)
    texto("¡LA COMEDIA DEL AÑO!", cx, cy - 1.35, 0.1, rgb(120, 20, 80), 0.07)


def drama(cx, cy):
    degradado(cx, cy, 1.92, 2.92, (50, 16, 66), (176, 70, 96), 0.01)
    rect(cx, cy, 1.78, 2.78, rgb(220, 170, 60), 0.015)
    rect(cx, cy, 1.72, 2.72, rgb(64, 20, 74), 0.02)
    pts = []
    for k in range(60):
        t = math.pi * 2 * k / 60
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((cx + x * 0.04, cy + 0.35 + y * 0.04))
    poligono(pts, rgb(200, 30, 54), 0.03)
    pts2 = [(cx + (x - cx) * 0.7, cy + 0.35 + (y - cy - 0.35) * 0.7) for x, y in pts]
    poligono(pts2, rgb(236, 70, 90), 0.04)
    for k in range(26):
        circulo(cx + random.uniform(-0.8, 0.8), cy + random.uniform(-0.5, 1.3), random.uniform(0.012, 0.03), rgb(240, 244, 255), 0.05)
    texto("CORAZONES\nDE INVIERNO", cx, cy - 0.95, 0.25, rgb(240, 222, 170), 0.07)
    texto("UN AMOR SIN FINAL FELIZ", cx, cy - 1.3, 0.085, rgb(220, 170, 60), 0.07)


def infantil(cx, cy):
    degradado(cx, cy, 1.92, 2.92, (70, 180, 246), (150, 236, 170), 0.01)
    circulo(cx - 0.6, cy + 1.0, 0.3, rgb(255, 226, 60), 0.02)
    circulo(cx - 0.4, cy - 0.7, 0.9, rgb(70, 190, 100), 0.02, 1.1, 0.6)
    circulo(cx + 0.7, cy - 0.8, 0.8, rgb(50, 160, 90), 0.02, 0.8, 0.55)
    for k, (x, y) in enumerate(((-0.55, -0.1), (-0.3, 0.15), (0.0, 0.25), (0.3, 0.15), (0.55, -0.05))):
        circulo(cx + x, cy + y + 0.2, 0.2 - k * 0.012, rgb(60 + k * 10, 200 - k * 10, 90), 0.04)
    circulo(cx + 0.78, cy + 0.2, 0.26, rgb(80, 220, 100), 0.05)
    circulo(cx + 0.85, cy + 0.27, 0.05, rgb(255, 255, 255), 0.06)
    circulo(cx + 0.86, cy + 0.27, 0.025, rgb(20, 20, 20), 0.07)
    estrella(cx + 0.63, cy + 0.5, 0.1, 0.045, 3, rgb(240, 70, 60), 0.05, 1.57)
    estrella(cx + 0.78, cy + 0.52, 0.1, 0.045, 3, rgb(240, 70, 60), 0.05, 1.57)
    for k in range(5):
        estrella(cx + random.uniform(-0.8, 0.8), cy + random.uniform(0.7, 1.35), 0.07, 0.03, 5, rgb(255, 230, 70), 0.04, 0.2)
    texto("PANCHITO\nY EL DRAGÓN", cx, cy - 0.95, 0.26, rgb(255, 232, 60), 0.07)
    texto("PARA TODA LA FAMILIA", cx, cy - 1.32, 0.09, rgb(30, 80, 160), 0.07)


def maldito(cx, cy):
    rect(cx, cy, 1.92, 2.92, rgb(4, 4, 6), 0.01)
    for k in range(34):
        y = cy - 1.4 + random.random() * 2.8
        w = random.uniform(0.3, 1.9)
        x = cx - 0.96 + w / 2 + random.random() * (1.92 - w)
        g = random.randint(90, 230)
        rect(x, y, w, random.uniform(0.008, 0.04), rgb(g, g, g), 0.02)
    circulo(cx, cy + 0.35, 0.8, rgb(236, 236, 230), 0.03, 0.85, 0.45)
    circulo(cx, cy + 0.35, 0.4, rgb(176, 14, 22), 0.04)
    circulo(cx, cy + 0.35, 0.17, rgb(0, 0, 0), 0.05)
    poligono([(cx - 0.9, cy + 0.35), (cx, cy + 0.82), (cx + 0.9, cy + 0.35), (cx, cy + 0.88)], rgb(4, 4, 6), 0.045)
    rect(cx, cy - 0.9, 1.92, 0.75, rgb(4, 4, 6), 0.06)
    texto("EL VIDEO\nMALDITO", cx, cy - 0.85, 0.3, rgb(240, 240, 236), 0.07)
    texto("NO LO REBOBINES", cx, cy - 1.3, 0.1, rgb(190, 20, 30), 0.07)


def estreno(cx, cy):
    rect(cx, cy, 1.92, 2.92, rgb(200, 24, 36), 0.01)
    estrella(cx, cy + 0.2, 1.1, 0.62, 18, rgb(255, 210, 44), 0.02, 0.05)
    estrella(cx, cy + 0.2, 0.8, 0.46, 18, rgb(220, 30, 40), 0.03, 0.2)
    texto("ESTRENO", cx, cy + 0.3, 0.3, rgb(255, 240, 200), 0.09, math.radians(-8))
    texto("ESTA SEMANA", cx, cy - 0.12, 0.13, rgb(255, 214, 44), 0.09, math.radians(-8))
    texto("2x1 LOS MARTES", cx, cy - 1.2, 0.2, rgb(255, 240, 200), 0.07)
    texto("STAR VIDEOCLUB", cx, cy - 1.45, 0.11, rgb(255, 214, 44), 0.07)


def socio(cx, cy):
    degradado(cx, cy, 1.92, 2.92, (2, 2, 4), (28, 6, 10), 0.01)
    poligono([(cx - 0.55, cy - 0.8), (cx - 0.3, cy + 0.2), (cx - 0.22, cy + 0.9), (cx + 0.22, cy + 0.9), (cx + 0.3, cy + 0.2), (cx + 0.55, cy - 0.8)], rgb(10, 10, 14), 0.02)
    circulo(cx, cy + 0.82, 0.3, rgb(20, 20, 26), 0.03, 0.25, 0.4)
    rect(cx - 0.1, cy + 0.88, 0.09, 0.05, rgb(255, 250, 230), 0.05)
    rect(cx + 0.1, cy + 0.88, 0.09, 0.05, rgb(255, 250, 230), 0.05)
    rect(cx, cy + 0.66, 0.2, 0.012, rgb(230, 226, 210), 0.05)
    for k in range(7):
        rect(cx - 0.09 + k * 0.03, cy + 0.66, 0.008, 0.045, rgb(230, 226, 210), 0.05)
    for k in range(40):
        circulo(cx + random.uniform(-0.9, 0.9), cy + random.uniform(-1.4, 1.4), random.uniform(0.004, 0.012), rgb(120, 120, 130), 0.03)
    texto("SOCIO\nN° 0000", cx, cy - 0.95, 0.3, rgb(200, 20, 30), 0.07)
    texto("NO LO MIRES", cx, cy - 1.33, 0.11, rgb(220, 214, 200), 0.07)


for i, f in enumerate((terror, accion, comedia, drama, infantil, maldito, estreno, socio)):
    afiche(i, f)

escena.render.filepath = SALIDA
escena.render.image_settings.file_format = "PNG"
escena.render.image_settings.color_mode = "RGB"
bpy.ops.render.render(write_still=True, scene=escena.name)
result = {"ok": os.path.exists(SALIDA)}
