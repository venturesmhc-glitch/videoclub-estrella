# Libreria comun de las criaturas de las anomalias (Blender 5.x). La cargan trepador.py, arana.py y larguirucho.py con exec().
# Unidades: metros, pies/puntas de las patas en z=0, el frente mira hacia -Y. Lado L = +X.
# Flujo de cada criatura:  iniciar(nombre) -> materiales/piezas (commit) + huesos (hueso) -> terminar() -> hornear() -> exportar() -> foto()
import bpy, bmesh, math, os, random
from mathutils import Vector, noise

V = Vector
RAIZ = "C:/Users/kilic/Desktop/rolbox/assets/"

NOMBRE = None
COL = None
PIEZAS = []  # (objeto, regla de pesos)
HUESOS = []  # (nombre, cabeza, cola, padre)


def lerp(a, b, t):
    return a + (b - a) * t


def ss(a, b, x):
    if a == b:
        return 0.0
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def iniciar(nombre, semilla=7):
    """Limpia la escena (menos luces y camara) y prepara una coleccion nueva."""
    global NOMBRE, COL, PIEZAS, HUESOS
    random.seed(semilla)
    NOMBRE = nombre
    PIEZAS, HUESOS = [], []
    for o in list(bpy.data.objects):
        if o.type in {"MESH", "ARMATURE", "CURVE", "EMPTY"}:
            bpy.data.objects.remove(o, do_unlink=True)
    for c in list(bpy.data.collections):
        if c.name != "Collection":
            bpy.data.collections.remove(c)
    for blk in (bpy.data.meshes, bpy.data.armatures, bpy.data.materials, bpy.data.images):
        for b in list(blk):
            if b.users == 0:
                blk.remove(b)
    COL = bpy.data.collections.new(nombre)
    bpy.context.scene.collection.children.link(COL)


# ---------------------------------------------------------------- materiales procedurales
def mk_proc(name, a, b, esc, capas, rough, bump_s, bump_f, ao=True):
    """Material de nodos: mezcla a/b con ruido y capas ('n' manchas, 'g' grietas/venas). Se hornea a textura despues."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    N, L = nt.nodes, nt.links
    out = N.new("ShaderNodeOutputMaterial")
    bs = N.new("ShaderNodeBsdfPrincipled")
    L.new(bs.outputs["BSDF"], out.inputs["Surface"])
    tc = N.new("ShaderNodeTexCoord")

    def ruido(escala, detalle=7.0, aspereza=0.55):
        n = N.new("ShaderNodeTexNoise")
        n.inputs["Scale"].default_value = escala
        n.inputs["Detail"].default_value = detalle
        n.inputs["Roughness"].default_value = aspereza
        L.new(tc.outputs["Object"], n.inputs["Vector"])
        return n.outputs["Fac"]

    def rampa(sock, lo, hi):
        r = N.new("ShaderNodeValToRGB")
        r.color_ramp.elements[0].position = lo
        r.color_ramp.elements[0].color = (0, 0, 0, 1)
        r.color_ramp.elements[1].position = hi
        r.color_ramp.elements[1].color = (1, 1, 1, 1)
        L.new(sock, r.inputs["Fac"])
        return r.outputs["Color"]

    def grietas(escala, ancho):
        vr = N.new("ShaderNodeTexVoronoi")
        vr.feature = "DISTANCE_TO_EDGE"
        vr.inputs["Scale"].default_value = escala
        L.new(tc.outputs["Object"], vr.inputs["Vector"])
        r = N.new("ShaderNodeValToRGB")
        r.color_ramp.elements[0].position = 0.0
        r.color_ramp.elements[0].color = (1, 1, 1, 1)
        r.color_ramp.elements[1].position = ancho
        r.color_ramp.elements[1].color = (0, 0, 0, 1)
        L.new(vr.outputs["Distance"], r.inputs["Fac"])
        return r.outputs["Color"]

    def mezcla(A, B, fac):
        mx = N.new("ShaderNodeMix")
        mx.data_type = "RGBA"
        L.new(fac, mx.inputs[0])
        for idx, v in ((6, A), (7, B)):
            if isinstance(v, tuple):
                mx.inputs[idx].default_value = (*v, 1)
            else:
                L.new(v, mx.inputs[idx])
        return mx.outputs[2]

    col = mezcla(a, b, rampa(ruido(esc, 8.0), 0.35, 0.65))
    for capa in capas:
        if capa[0] == "n":
            _, color, escala, lo, hi = capa
            col = mezcla(col, color, rampa(ruido(escala, 6.0), lo, hi))
        else:
            _, color, escala, ancho = capa
            mk = N.new("ShaderNodeMath")
            mk.operation = "MULTIPLY"
            L.new(grietas(escala, ancho), mk.inputs[0])
            L.new(rampa(ruido(2.5, 4.0), 0.45, 0.65), mk.inputs[1])
            col = mezcla(col, color, mk.outputs[0])
    if ao:
        oc = N.new("ShaderNodeAmbientOcclusion")
        oc.inputs["Distance"].default_value = 0.06
        oc.samples = 8
        col = mezcla((0.004, 0.003, 0.003), col, rampa(oc.outputs["AO"], 0.15, 0.7))
    L.new(col, bs.inputs["Base Color"])
    bs.inputs["Roughness"].default_value = rough
    bp = N.new("ShaderNodeBump")
    bp.inputs["Strength"].default_value = bump_f
    bp.inputs["Distance"].default_value = 0.03
    L.new(ruido(bump_s, 8.0, 0.6), bp.inputs["Height"])
    L.new(bp.outputs["Normal"], bs.inputs["Normal"])
    return m


def mk_plano(name, color, rough=0.5):
    """Color liso (ojos, etc.): igual se hornea a la textura."""
    return mk_proc(name, color, color, 5, [], rough, 20, 0.0, ao=False)


# ---------------------------------------------------------------- piezas
def commit(name, bm, mat, regla, smooth=True):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    if smooth:
        for p in me.polygons:
            p.use_smooth = True
    for mm in (mat if isinstance(mat, (list, tuple)) else [mat]):
        me.materials.append(mm)
    ob = bpy.data.objects.new(name, me)
    COL.objects.link(ob)
    PIEZAS.append((ob, regla))
    return ob


def nuevo_bm():
    return bmesh.new()


def tube(bm, pts, radii, segs=8, up=None, caps=True):
    n = len(pts)
    pts = [V(p) for p in pts]
    rings = []
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        u = V(up) if up is not None else (V((0, 1, 0)) if abs(t.y) < 0.9 else V((1, 0, 0)))
        a = t.cross(u).normalized()
        b = t.cross(a).normalized()
        r = radii[i]
        rx, ry = r if isinstance(r, tuple) else (r, r)
        ring = []
        for k in range(segs):
            ang = 2 * math.pi * k / segs
            ring.append(bm.verts.new(p + a * math.cos(ang) * rx + b * math.sin(ang) * ry))
        rings.append(ring)
    for i in range(n - 1):
        for k in range(segs):
            k2 = (k + 1) % segs
            bm.faces.new((rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]))
    if caps:
        bm.faces.new(rings[0][::-1])
        bm.faces.new(rings[-1])


def line(a, b, n):
    a, b = V(a), V(b)
    return [a.lerp(b, i / (n - 1)) for i in range(n)]


def suave(pts, sub=4):
    """Catmull-Rom por los puntos: devuelve una curva suave que pasa por todos."""
    P = [V(p) for p in pts]
    if len(P) < 3:
        return line(P[0], P[-1], sub + 1)
    out = []
    ext = [P[0] * 2 - P[1]] + P + [P[-1] * 2 - P[-2]]
    for i in range(1, len(ext) - 2):
        p0, p1, p2, p3 = ext[i - 1], ext[i], ext[i + 1], ext[i + 2]
        for s in range(sub):
            t = s / sub
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    out.append(P[-1])
    return out


def rama(bm, joints, radii, sub=4, segs=8, up=None, nudos=0.0):
    """Tubo suave que pasa por las articulaciones; radii es el radio en cada articulacion (se interpola).
    nudos: engrosa un poco las articulaciones (codos, rodillas)."""
    pts = suave(joints, sub)
    n = len(pts)
    rr = []
    for i in range(n):
        f = i / sub
        k = min(int(f), len(radii) - 2)
        r = lerp(radii[k], radii[k + 1], f - k)
        if nudos:
            d = abs(f - round(f))
            r *= 1 + nudos * (1 - 2 * d) ** 4 if 0 < round(f) < len(joints) - 1 else 1
        rr.append(r)
    tube(bm, pts, rr, segs, up)


def blob(bm, c, s, segs=12, rings=8, rot=None):
    tmp = bmesh.new()
    bmesh.ops.create_uvsphere(tmp, u_segments=segs, v_segments=rings, radius=1.0)
    m = {}
    for v in tmp.verts:
        p = V((v.co.x * s[0], v.co.y * s[1], v.co.z * s[2]))
        if rot is not None:
            p = rot @ p
        m[v] = bm.verts.new(p + V(c))
    for f in tmp.faces:
        bm.faces.new([m[v] for v in f.verts])
    tmp.free()


def cono(bm, base, punta, r, segs=5):
    """Pirámide/garra/colmillo: base redonda de radio r y una punta."""
    base, punta = V(base), V(punta)
    t = (punta - base).normalized()
    u = V((0, 0, 1)) if abs(t.z) < 0.9 else V((1, 0, 0))
    a = t.cross(u).normalized()
    b = t.cross(a).normalized()
    ring = [bm.verts.new(base + a * math.cos(2 * math.pi * k / segs) * r + b * math.sin(2 * math.pi * k / segs) * r) for k in range(segs)]
    tip = bm.verts.new(punta)
    for k in range(segs):
        bm.faces.new((ring[k], ring[(k + 1) % segs], tip))
    bm.faces.new(ring[::-1])


def jitter(bm, amp, freq, seed=0.0):
    bm.normal_update()
    off = V((seed, seed * 0.7, seed * 1.3))
    for v in bm.verts:
        v.co += v.normal * (noise.noise(v.co * freq + off) * amp)


# ---------------------------------------------------------------- pesos
def rigido(bone):
    return lambda p: {bone: 1.0}


def cadena(joints, bones, blend=0.07):
    """Pesos a lo largo de una cadena de huesos: joints tiene una articulacion mas que bones."""
    J = [V(j) for j in joints]
    n = len(bones)

    def regla(p):
        a = [1.0]
        for i in range(1, n):
            d = (p - J[i]).dot((J[i + 1] - J[i - 1]).normalized())
            a.append(ss(-blend, blend, d))
        a.append(0.0)
        out = {}
        for k in range(n):
            w = a[k] * (1 - a[k + 1])
            if w > 1e-3:
                out[bones[k]] = w
        return out

    return regla


def hueso(name, head, tail, parent=None):
    HUESOS.append((name, V(head), V(tail), parent))


# ---------------------------------------------------------------- terminar: esqueleto, pesos, unir
def terminar():
    arm = bpy.data.armatures.new(NOMBRE + "_Rig")
    rig = bpy.data.objects.new(NOMBRE + "_Rig", arm)
    COL.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for nombre, cab, col, padre in HUESOS:
        b = arm.edit_bones.new(nombre)
        b.head = cab
        b.tail = col
        if (col - cab).length < 1e-4:
            b.tail = cab + V((0, 0, 0.02))
        if padre:
            b.parent = arm.edit_bones[padre]
    bpy.ops.object.mode_set(mode="OBJECT")

    for ob, regla in PIEZAS:
        for v in ob.data.vertices:
            pesos = regla(v.co)
            # Roblox admite 4 influencias por vertice: nos quedamos con las 4 mas fuertes
            top = sorted(pesos.items(), key=lambda kv: -kv[1])[:4]
            tot = sum(w for _, w in top) or 1.0
            for nombre, w in top:
                vg = ob.vertex_groups.get(nombre) or ob.vertex_groups.new(name=nombre)
                vg.add([v.index], w / tot, "REPLACE")

    lista = [o for o, _ in PIEZAS]
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in lista:
        o.select_set(True)
    bpy.context.view_layer.objects.active = lista[0]
    with bpy.context.temp_override(active_object=lista[0], selected_objects=lista, selected_editable_objects=lista):
        bpy.ops.object.join()
    malla = bpy.context.view_layer.objects.active
    malla.name = NOMBRE + "_Malla"
    malla.data.name = NOMBRE + "_Malla"
    mod = malla.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    malla.parent = rig
    tris = sum(len(p.vertices) - 2 for p in malla.data.polygons)
    return {"tris": tris, "verts": len(malla.data.vertices), "huesos": len(arm.bones),
            "materiales": [m.name for m in malla.data.materials], "dim": [round(x, 3) for x in malla.dimensions]}


# ---------------------------------------------------------------- hornear a textura (color + normal, 2048)
def hornear(tam=2048, muestras=24):
    sc = bpy.context.scene
    dest = RAIZ + NOMBRE.lower() + "/"
    os.makedirs(dest, exist_ok=True)
    malla = bpy.data.objects[NOMBRE + "_Malla"]
    for o in bpy.context.selected_objects:
        o.select_set(False)
    malla.select_set(True)
    bpy.context.view_layer.objects.active = malla
    with bpy.context.temp_override(active_object=malla, selected_objects=[malla], selected_editable_objects=[malla], object=malla):
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.004, area_weight=0.6)
        sc.tool_settings.use_uv_select_sync = True
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.pack_islands(rotate=True, margin=0.003)
        bpy.ops.object.mode_set(mode="OBJECT")

    def imagen(nombre, color):
        im = bpy.data.images.get(nombre)
        if im:
            bpy.data.images.remove(im)
        im = bpy.data.images.new(nombre, tam, tam, alpha=False, float_buffer=False)
        im.generated_color = color
        return im

    im_color = imagen(NOMBRE + "_Color", (0.02, 0.02, 0.02, 1))
    im_norm = imagen(NOMBRE + "_Normal", (0.5, 0.5, 1.0, 1))
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
    sc.cycles.samples = muestras
    sc.cycles.use_denoising = False
    b = sc.render.bake
    b.margin = 8
    b.use_clear = True
    b.use_pass_direct = False
    b.use_pass_indirect = False
    b.use_pass_color = True
    with bpy.context.temp_override(active_object=malla, selected_objects=[malla], selected_editable_objects=[malla], object=malla):
        bpy.ops.object.bake(type="DIFFUSE")
        im_color.filepath_raw = dest + NOMBRE.lower() + "_color.png"
        im_color.file_format = "PNG"
        im_color.save()
        for n in nodos:
            n.image = im_norm
        bpy.ops.object.bake(type="NORMAL")
        im_norm.filepath_raw = dest + NOMBRE.lower() + "_normal.png"
        im_norm.file_format = "PNG"
        im_norm.save()
    fin = bpy.data.materials.new(NOMBRE)
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
    return {"color": os.path.getsize(dest + NOMBRE.lower() + "_color.png"), "normal": os.path.getsize(dest + NOMBRE.lower() + "_normal.png")}


# ---------------------------------------------------------------- exportar FBX (frente -Z, Y arriba, como Roblox)
def exportar():
    dest = RAIZ + NOMBRE.lower() + "/"
    os.makedirs(dest, exist_ok=True)
    rig = bpy.data.objects[NOMBRE + "_Rig"]
    malla = bpy.data.objects[NOMBRE + "_Malla"]
    for o in bpy.context.selected_objects:
        o.select_set(False)
    rig.select_set(True)
    malla.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.fbx(
        filepath=dest + NOMBRE.lower() + ".fbx", use_selection=True, object_types={"ARMATURE", "MESH"},
        axis_forward="Z", axis_up="Y", add_leaf_bones=False, bake_anim=False,
        mesh_smooth_type="FACE", path_mode="COPY", embed_textures=True, use_armature_deform_only=True,
    )
    bpy.ops.wm.save_as_mainfile(filepath=dest + NOMBRE.lower() + ".blend")
    return {"fbx_bytes": os.path.getsize(dest + NOMBRE.lower() + ".fbx")}


# ---------------------------------------------------------------- foto de revision
def foto(archivo, camara, objetivo, lente=50, res=(900, 900), pose=None):
    """Render rapido (EEVEE) de la criatura. pose: {hueso: (rx, ry, rz) en grados} para probar poses."""
    sc = bpy.context.scene
    rig = bpy.data.objects.get(NOMBRE + "_Rig")
    if rig:
        for pb in rig.pose.bones:
            pb.rotation_mode = "XYZ"
            pb.rotation_euler = (0, 0, 0)
        for nombre, (rx, ry, rz) in (pose or {}).items():
            pb = rig.pose.bones.get(nombre)
            if pb:
                pb.rotation_mode = "XYZ"
                pb.rotation_euler = (math.radians(rx), math.radians(ry), math.radians(rz))
    cam = bpy.data.objects["Camera"]
    cam.location = V(camara)
    d = V(objetivo) - V(camara)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = lente
    sc.camera = cam
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.filepath = RAIZ + NOMBRE.lower() + "/" + archivo
    sc.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True)
    return sc.render.filepath
