# Renders de revision del Socio (fondo negro, luz fria). Variables opcionales antes de ejecutar: VISTAS, SALIDA.
import bpy, math
from mathutils import Vector as V

SALIDA = globals().get("SALIDA", "C:/Users/kilic/AppData/Local/Temp/claude/C--Users-kilic-Desktop-rolbox/78401520-56c1-467b-98c5-298e9a4cae57/scratchpad/")
VISTAS = globals().get("VISTAS", [
    ("completo_frente", (0, -8.0, 1.6), (0, 0, 1.55), 50, 640, 900),
    ("completo_3q", (4.6, -5.0, 1.8), (0, 0, 1.5), 50, 640, 900),
    ("cabeza", (0.0, -2.0, 2.6), (0, 0, 2.55), 40, 900, 900),
])

sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE"
sc.render.image_settings.file_format = "PNG"
w = bpy.data.worlds.get("SocioMundo") or bpy.data.worlds.new("SocioMundo")
sc.world = w
w.use_nodes = True
bg = w.node_tree.nodes.get("Background")
if bg is None:
    w.node_tree.nodes.clear()
    bg = w.node_tree.nodes.new("ShaderNodeBackground")
    sal = w.node_tree.nodes.new("ShaderNodeOutputWorld")
    w.node_tree.links.new(bg.outputs["Background"], sal.inputs["Surface"])
bg.inputs["Color"].default_value = (0.004, 0.005, 0.007, 1)
bg.inputs["Strength"].default_value = 1.0


def luz(nombre, loc, energia, color, tam=2.0):
    o = bpy.data.objects.get(nombre)
    if o is None:
        d = bpy.data.lights.new(nombre, "AREA")
        o = bpy.data.objects.new(nombre, d)
        sc.collection.objects.link(o)
    o.location = loc
    o.data.energy = energia
    o.data.color = color
    o.data.size = tam
    d = V((0, 0, 1.6)) - V(loc)
    o.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


luz("Socio_Key", (-3.0, -4.0, 3.4), 260, (0.75, 0.85, 1.0), 3.0)
luz("Socio_Rim", (3.5, 3.5, 3.0), 500, (0.6, 0.7, 1.0), 3.0)
luz("Socio_Relleno", (2.5, -3.0, 0.8), 50, (1.0, 0.85, 0.75), 3.0)
for n in ("Light",):
    o = bpy.data.objects.get(n)
    if o:
        o.hide_render = True

cam = bpy.data.objects.get("Camera")
for nombre, pos, mira, lente, rx, ry in VISTAS:
    cam.location = pos
    cam.rotation_euler = (V(mira) - V(pos)).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = lente
    cam.data.sensor_width = 36
    sc.camera = cam
    sc.render.resolution_x = rx
    sc.render.resolution_y = ry
    sc.render.filepath = SALIDA + nombre + ".png"
    bpy.ops.render.render(write_still=True)
result = {"ok": [v[0] for v in VISTAS]}
