# Reel de la actualización — plano de la criatura del techo, el Trepador (Blender 5.x, sin interfaz):
#   G:\blender.exe -b assets/trepador/trepador.blend --python promo/reel/blender_trepador.py -- <carpeta de salida> [preview]
# Vertical 1080x1920 a 30 fps: avanza hacia la cámara a pasos cortos, con la cabeza girando a tirones y la mandíbula castañeteando
# (todo "a tirones", como en el juego). Con "preview" renderiza solo 3 cuadros chicos para encuadrar.
import bpy, math, random, sys, os
from mathutils import Vector as V, Euler

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SALIDA = args[0] if args else os.path.join(os.getcwd(), "frames_trepador")
PREVIEW = "preview" in args
FPS = 30
SEG = 3.4
TOTAL = int(FPS * SEG)

sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE"
sc.render.resolution_x = 1080 if not PREVIEW else 540
sc.render.resolution_y = 1920 if not PREVIEW else 960
sc.render.resolution_percentage = 100
sc.render.fps = FPS
sc.frame_start = 1
sc.frame_end = TOTAL
sc.render.image_settings.file_format = "PNG"
os.makedirs(SALIDA, exist_ok=True)

# Texturas: el .blend las guarda con la ruta de otra máquina.
CARPETA = os.path.dirname(bpy.data.filepath)
for img in bpy.data.images:
    candidata = os.path.join(CARPETA, os.path.basename(img.filepath.replace("\\", "/"))) if img.filepath else ""
    if candidata and os.path.exists(candidata):
        img.filepath = candidata
        img.reload()

bg = sc.world.node_tree.nodes.get("Background") if sc.world and sc.world.node_tree else None
if bg:
    bg.inputs["Color"].default_value = (0.004, 0.005, 0.007, 1)

cam = bpy.data.objects["Camera"]
cam.data.lens_unit = "FOV"
cam.data.angle = math.radians(58)
cam.data.sensor_fit = "VERTICAL"
sc.camera = cam
objetivo = bpy.data.objects.new("MiraBicho", None)
sc.collection.objects.link(objetivo)
cons = cam.constraints.new("TRACK_TO")
cons.target = objetivo
cons.track_axis = "TRACK_NEGATIVE_Z"
cons.up_axis = "UP_Y"

# Más luz que en los renders de revisión: en el reel tiene que leerse (en el juego anda a oscuras).
for luz in bpy.data.objects:
    if luz.type == "LIGHT" and not luz.hide_render:
        luz.data.energy *= 2.6

rig = bpy.data.objects["Trepador_Rig"]
pb = rig.pose.bones
for n in ("Head", "Neck1", "Neck2", "Jaw", "Root"):
    pb[n].rotation_mode = "XYZ"

rng = random.Random(11)
CABEZA = V((0.0, -1.0, 1.1))  # a donde mira la cámara (la cara)
giro = (0.0, 0.0)
proximo_giro = 1
for f in range(1, TOTAL + 1):
    t = (f - 1) / (TOTAL - 1)
    # La cámara se queda más o menos quieta, baja y de frente; el bicho es el que se acerca a saltos.
    paso = round(t * 14) / 14
    avance = 3.0 * paso ** 1.2  # cuánto se acerca (m)
    fuerza = 0.006 + 0.03 * t ** 2
    cam.location = V((rng.uniform(-1, 1) * fuerza, -6.2 + rng.uniform(-1, 1) * fuerza, 0.55 + rng.uniform(-1, 1) * fuerza))
    cam.keyframe_insert("location", frame=f)
    objetivo.location = V((0.0, -1.0, 1.15 + 0.12 * t))
    objetivo.keyframe_insert("location", frame=f)
    # El cuerpo avanza hacia la cámara (-Y) a tirones.
    rig.location = V((0.0, -avance, 0.0))
    rig.keyframe_insert("location", frame=f)
    # Cabeza: cada 4 a 12 cuadros salta a un ángulo nuevo.
    if f >= proximo_giro:
        giro = (rng.uniform(-25, 25), rng.uniform(-35, 35))
        proximo_giro = f + rng.randint(4, 12)
    pb["Head"].rotation_euler = Euler((math.radians(giro[0]), 0, math.radians(giro[1])), "XYZ")
    pb["Head"].keyframe_insert("rotation_euler", frame=f)
    # Mandíbula: castañetea (abre y cierra cada 2 cuadros) y se abre del todo al final.
    final = max(0.0, (t - 0.82) / 0.18)
    abierta = (f % 4 < 2) * 10 + 55 * final
    pb["Jaw"].rotation_euler = Euler((math.radians(abierta), 0, 0), "XYZ")
    pb["Jaw"].keyframe_insert("rotation_euler", frame=f)

for ob in (cam, objetivo, rig):
    ad = ob.animation_data
    if ad and ad.action:
        for fc in ad.action.fcurves if hasattr(ad.action, "fcurves") else []:
            for kp in fc.keyframe_points:
                kp.interpolation = "CONSTANT"

if PREVIEW:
    for f in (1, TOTAL // 2, TOTAL):
        sc.frame_set(f)
        sc.render.filepath = os.path.join(SALIDA, f"prev_{f:03d}.png")
        bpy.ops.render.render(write_still=True)
else:
    sc.render.filepath = os.path.join(SALIDA, "trepador_")
    bpy.ops.render.render(animation=True)
print("LISTO", SALIDA)
