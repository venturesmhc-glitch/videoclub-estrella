# Exporta Socio_Malla + Socio_Rig a FBX (frente -Z, Y arriba, como Roblox) y guarda el .blend.
import bpy, os
from bpy_extras.io_utils import axis_conversion
from mathutils import Vector as V
DEST = "C:/Users/kilic/Desktop/rolbox/assets/socio/"
os.makedirs(DEST, exist_ok=True)
conv = axis_conversion(from_forward="Y", from_up="Z", to_forward="Z", to_up="Y").to_4x4()
frente = conv @ V((0, -1, 0))
arriba = conv @ V((0, 0, 1))
rig = bpy.data.objects["Socio_Rig"]
malla = bpy.data.objects["Socio_Malla"]
for o in bpy.context.selected_objects:
    o.select_set(False)
rig.select_set(True); malla.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.fbx(
    filepath=DEST + "socio.fbx", use_selection=True, object_types={"ARMATURE", "MESH"},
    axis_forward="Z", axis_up="Y", add_leaf_bones=False, bake_anim=False,
    mesh_smooth_type="FACE", path_mode="COPY", embed_textures=True, use_armature_deform_only=True,
)
bpy.ops.wm.save_as_mainfile(filepath=DEST + "socio.blend")
result = {"frente_en_fbx": [round(x, 3) for x in frente], "arriba_en_fbx": [round(x, 3) for x in arriba],
          "fbx_bytes": os.path.getsize(DEST + "socio.fbx")}
