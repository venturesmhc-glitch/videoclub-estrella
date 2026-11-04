# Pose brusca de prueba para revisar los pesos; despues deja el rig en reposo.
import bpy, math
from mathutils import Euler
rig = bpy.data.objects["Socio_Rig"]
pb = rig.pose.bones
def rot(n, x=0, y=0, z=0):
    b = pb[n]; b.rotation_mode = "XYZ"; b.rotation_euler = Euler((math.radians(x), math.radians(y), math.radians(z)), "XYZ")
rot("Jaw", 38, 0, 0); rot("Head", 22, 0, -38); rot("Neck2", 10, 0, -15); rot("Neck1", 8, 0, -10)
rot("Spine2", 12, 0, 14); rot("Spine1", 6, 0, 8)
rot("UpperArm_L", -70, 0, 25); rot("Forearm_L", -80, 0, 0); rot("Hand_L", -30, 0, 0)
rot("UpperArm_R", -20, 0, -35); rot("Forearm_R", -35, 0, 0)
for f in range(5):
    for k in (1, 2):
        rot("Finger%d_%d_L" % (f, k), -55, 0, 0)
rot("UpperLeg_L", -35, 0, 0); rot("LowerLeg_L", 55, 0, 0); rot("Foot_L", -20, 0, 0)
bpy.context.view_layer.update()
SALIDA = "C:/Users/kilic/AppData/Local/Temp/claude/C--Users-kilic-Desktop-rolbox/78401520-56c1-467b-98c5-298e9a4cae57/scratchpad/"
VISTAS = [("pose_frente", (0, -8.0, 1.6), (0, 0, 1.55), 50, 640, 900), ("pose_3q", (5.5, -4.5, 2.0), (0, 0, 1.6), 50, 640, 900)]
exec(open("C:/Users/kilic/Desktop/rolbox/blender/render.py").read())
for b in pb:
    b.rotation_euler = (0, 0, 0)
bpy.context.view_layer.update()
result = {"pose": "ok"}
