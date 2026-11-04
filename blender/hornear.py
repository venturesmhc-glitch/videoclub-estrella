# Desenvuelve UVs y hornea color + normales de los materiales procedurales a texturas 2048 (Cycles).
# Correr despues de socio.py. Deja la malla con un solo material "Socio" que usa las texturas horneadas.
import bpy, math, os
DEST = "C:/Users/kilic/Desktop/rolbox/assets/socio/"
os.makedirs(DEST, exist_ok=True)
TAM = 2048
sc = bpy.context.scene
malla = bpy.data.objects["Socio_Malla"]
for o in bpy.context.selected_objects:
    o.select_set(False)
malla.select_set(True)
bpy.context.view_layer.objects.active = malla

# UVs
with bpy.context.temp_override(active_object=malla, selected_objects=[malla], selected_editable_objects=[malla], object=malla):
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.004, area_weight=0.6)
    # mas pixeles para el craneo, la mandibula y los dientes (materiales 0, 1 y 2 antes de unificar)
    import bmesh
    bm = bmesh.from_edit_mesh(malla.data)
    uv = bm.loops.layers.uv.active
    for f in bm.faces:
        if f.material_index in (0, 1, 2):
            for l in f.loops:
                l[uv].uv *= 2.4
    bmesh.update_edit_mesh(malla.data)
    sc.tool_settings.use_uv_select_sync = True
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.pack_islands(rotate=True, margin=0.003)
    bpy.ops.object.mode_set(mode="OBJECT")

def imagen(nombre, color):
    im = bpy.data.images.get(nombre)
    if im:
        bpy.data.images.remove(im)
    im = bpy.data.images.new(nombre, TAM, TAM, alpha=False, float_buffer=False)
    im.generated_color = color
    return im

im_color = imagen("Socio_Color", (0.02, 0.01, 0.01, 1))
im_norm = imagen("Socio_Normal", (0.5, 0.5, 1.0, 1))
im_norm.colorspace_settings.name = "Non-Color"

nodos = []
for m in malla.data.materials:
    n = m.node_tree.nodes.new("ShaderNodeTexImage")
    n.image = im_color
    m.node_tree.nodes.active = n
    n.select = True
    nodos.append(n)

sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = 24
sc.cycles.use_denoising = False
b = sc.render.bake
b.margin = 8
b.use_clear = True
b.use_pass_direct = False
b.use_pass_indirect = False
b.use_pass_color = True

with bpy.context.temp_override(active_object=malla, selected_objects=[malla], selected_editable_objects=[malla], object=malla):
    bpy.ops.object.bake(type="DIFFUSE")
    im_color.filepath_raw = DEST + "socio_color.png"
    im_color.file_format = "PNG"
    im_color.save()
    for n in nodos:
        n.image = im_norm
    bpy.ops.object.bake(type="NORMAL")
    im_norm.filepath_raw = DEST + "socio_normal.png"
    im_norm.file_format = "PNG"
    im_norm.save()

# material final unico con las texturas horneadas
for m in list(malla.data.materials):
    pass
fin = bpy.data.materials.new("Socio")
fin.use_nodes = True
nt = fin.node_tree
nt.nodes.clear()
out = nt.nodes.new("ShaderNodeOutputMaterial")
bs = nt.nodes.new("ShaderNodeBsdfPrincipled")
bs.inputs["Roughness"].default_value = 0.55
nt.links.new(bs.outputs["BSDF"], out.inputs["Surface"])
tc = nt.nodes.new("ShaderNodeTexImage")
tc.image = im_color
nt.links.new(tc.outputs["Color"], bs.inputs["Base Color"])
tn = nt.nodes.new("ShaderNodeTexImage")
tn.image = im_norm
nm = nt.nodes.new("ShaderNodeNormalMap")
nt.links.new(tn.outputs["Color"], nm.inputs["Color"])
nt.links.new(nm.outputs["Normal"], bs.inputs["Normal"])
malla.data.materials.clear()
malla.data.materials.append(fin)
for p in malla.data.polygons:
    p.material_index = 0
sc.render.engine = "BLENDER_EEVEE"
result = {"color": os.path.getsize(DEST + "socio_color.png"), "normal": os.path.getsize(DEST + "socio_normal.png")}
