# Reel de la actualización — plano del Socio N° 0000 (Blender 5.x, se corre sin abrir la interfaz):
#   G:\blender.exe -b assets/socio/socio.blend --python promo/reel/blender_socio.py -- <carpeta de salida> [preview]
# Vertical 1080x1920 a 30 fps: la cámara se acerca a tirones a la cara y, de golpe, la cara se parte en dos (como en el juego).
# Con "preview" renderiza solo 3 cuadros chicos para encuadrar.
import bpy, math, random, sys, os
from mathutils import Vector as V, Euler

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SALIDA = args[0] if args else os.path.join(os.getcwd(), "frames_socio")
PREVIEW = "preview" in args
FPS = 30
SEG = 3.6
TOTAL = int(FPS * SEG)
ABRE = int(TOTAL * 0.72)  # cuadro en que la cara se abre
ANG = -70  # grados que gira cada mitad (igual que render_boca.py)

sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE"
sc.render.resolution_x = 1080 if not PREVIEW else 540
sc.render.resolution_y = 1920 if not PREVIEW else 960
sc.render.resolution_percentage = 100
sc.render.fps = FPS
sc.frame_start = 1
sc.frame_end = TOTAL
sc.render.image_settings.file_format = "PNG"
sc.render.film_transparent = False
os.makedirs(SALIDA, exist_ok=True)

# El .blend guarda las texturas con la ruta de la máquina donde se armó: se vuelven a enlazar a las de assets/socio/.
CARPETA = os.path.dirname(bpy.data.filepath)
for img in bpy.data.images:
    candidata = os.path.join(CARPETA, os.path.basename(img.filepath.replace("\\", "/"))) if img.filepath else ""
    if candidata and os.path.exists(candidata):
        img.filepath = candidata
        img.reload()

# Fondo casi negro y luz fría, igual que los renders de revisión.
bg = sc.world.node_tree.nodes.get("Background")
if bg:
    bg.inputs["Color"].default_value = (0.004, 0.005, 0.007, 1)

cam = bpy.data.objects["Camera"]
cam.data.lens_unit = "FOV"
cam.data.angle = math.radians(52)
cam.data.sensor_fit = "VERTICAL"
sc.camera = cam
objetivo = bpy.data.objects.new("MiraCara", None)
sc.collection.objects.link(objetivo)
cons = cam.constraints.new("TRACK_TO")
cons.target = objetivo
cons.track_axis = "TRACK_NEGATIVE_Z"
cons.up_axis = "UP_Y"

rig = bpy.data.objects["Socio_Rig"]
pb = rig.pose.bones
for n in ("FaceL", "FaceR"):
    pb[n].rotation_mode = "XYZ"

rng = random.Random(7)
CENTRO = V((0.0, 0.0, 2.86))  # mira por encima de la cara: así la cara queda en la mitad de abajo y el texto de arriba no la tapa
for f in range(1, TOTAL + 1):
    t = (f - 1) / (TOTAL - 1)
    # Se acerca a saltos (cada ~4 cuadros): se siente cinta, no suavidad.
    paso = round(t * 22) / 22
    dist = 4.6 - 2.9 * paso ** 1.4
    if f >= ABRE:
        dist -= 0.25 * min(1.0, (f - ABRE) / 6.0)  # el tirón final
    # Temblor de cámara que sube con el tiempo.
    fuerza = 0.012 + 0.05 * t ** 2 + (0.07 if ABRE <= f < ABRE + 8 else 0)
    desde = V((rng.uniform(-1, 1) * fuerza, -dist, 2.90 + rng.uniform(-1, 1) * fuerza))
    cam.location = desde
    cam.keyframe_insert("location", frame=f)
    objetivo.location = CENTRO + V((rng.uniform(-1, 1) * fuerza * 0.5, 0, rng.uniform(-1, 1) * fuerza * 0.5))
    objetivo.keyframe_insert("location", frame=f)
    # La cara: cerrada, y a los 5 cuadros de ABRE se abre de par en par; después tiembla.
    k = max(0.0, min(1.0, (f - ABRE) / 5.0))
    k = 1 - (1 - k) ** 3
    temblor = rng.uniform(-3, 3) if f > ABRE + 5 else 0
    for n, s in (("FaceL", 1), ("FaceR", -1)):
        pb[n].rotation_euler = Euler((0, math.radians(ANG * k + temblor) * s, 0), "XYZ")
        pb[n].keyframe_insert("rotation_euler", frame=f)

# Las interpolaciones en "constante" dejan los saltos (nada de movimiento suave).
for ob in (cam, objetivo, rig):
    ad = ob.animation_data
    if ad and ad.action:
        for fc in ad.action.fcurves if hasattr(ad.action, "fcurves") else []:
            for kp in fc.keyframe_points:
                kp.interpolation = "CONSTANT"

if PREVIEW:
    for f in (1, ABRE - 1, ABRE + 8):
        sc.frame_set(f)
        sc.render.filepath = os.path.join(SALIDA, f"prev_{f:03d}.png")
        bpy.ops.render.render(write_still=True)
else:
    sc.render.filepath = os.path.join(SALIDA, "socio_")
    bpy.ops.render.render(animation=True)
print("LISTO", SALIDA)
