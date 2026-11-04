# Pose de boca abierta (cara partida en dos) y renders de la cara; deja el rig en reposo al terminar.
import bpy, math
from mathutils import Euler
ANG = globals().get("ANG_BOCA", -70)
pb = bpy.data.objects["Socio_Rig"].pose.bones
for n, s in (("FaceL", 1), ("FaceR", -1)):
    pb[n].rotation_mode = "XYZ"
    pb[n].rotation_euler = Euler((0, math.radians(ANG) * s, 0), "XYZ")
bpy.context.view_layer.update()
SALIDA = "C:/Users/kilic/AppData/Local/Temp/claude/C--Users-kilic-Desktop-rolbox/78401520-56c1-467b-98c5-298e9a4cae57/scratchpad/"
VISTAS = [("boca_frente", (0.0, -2.4, 2.78), (0, 0, 2.74), 55, 1000, 1000),
          ("boca_3q", (1.1, -2.1, 2.9), (0, 0, 2.74), 55, 1000, 1000)]
exec(open("C:/Users/kilic/Desktop/rolbox/blender/render.py").read())
for b in pb:
    b.rotation_euler = (0, 0, 0)
bpy.context.view_layer.update()
result = {"ok": True}
