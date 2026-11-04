# Socio N° 0000 v2: cuerpo completo con esqueleto, calavera real y carne/piel (Blender 5.x).
# Se corre dentro de Blender (puente blender-mcp.js). Reconstruye todo desde cero cada vez.
# Unidades: metros, ~3.2 de alto, pies en z=0, el frente mira hacia -Y. Lado L = +X.
# Referencia: calavera alargada con orbitas cuadradas y ojos que brillan, capucha de piel oscura pegada al craneo,
# costillas gruesas con carne, puas irregulares en los hombros, brazos largos con tiras de carne.
import bpy, bmesh, math, random
from mathutils import Vector, noise

V = Vector
random.seed(11)


def lerp(a, b, t):
    return a + (b - a) * t


def ss(a, b, x):
    if a == b:
        return 0.0
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


# ---------------------------------------------------------------- limpiar
for o in list(bpy.data.objects):
    if o.type in {"MESH", "ARMATURE", "CURVE", "EMPTY"}:
        bpy.data.objects.remove(o, do_unlink=True)
for c in list(bpy.data.collections):
    if c.name.startswith("Socio"):
        bpy.data.collections.remove(c)
for blk in (bpy.data.meshes, bpy.data.armatures, bpy.data.materials, bpy.data.images):
    for b in list(blk):
        if b.users == 0:
            blk.remove(b)

COL = bpy.data.collections.new("Socio")
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
        col = mezcla((0.004, 0.002, 0.002), col, rampa(oc.outputs["AO"], 0.15, 0.7))
    L.new(col, bs.inputs["Base Color"])
    bs.inputs["Roughness"].default_value = rough
    bp = N.new("ShaderNodeBump")
    bp.inputs["Strength"].default_value = bump_f
    bp.inputs["Distance"].default_value = 0.03
    L.new(ruido(bump_s, 8.0, 0.6), bp.inputs["Height"])
    L.new(bp.outputs["Normal"], bs.inputs["Normal"])
    return m


M_CRANEO = mk_proc("Socio_Craneo", (0.20, 0.15, 0.09), (0.045, 0.03, 0.02), 7,
                   [("n", (0.12, 0.015, 0.012), 4.0, 0.5, 0.7), ("g", (0.03, 0.02, 0.015), 24.0, 0.018),
                    ("n", (0.02, 0.015, 0.012), 35.0, 0.45, 0.7)], 0.55, 45, 0.6)
M_HUESO = mk_proc("Socio_Hueso", (0.10, 0.06, 0.04), (0.025, 0.014, 0.012), 6,
                  [("n", (0.14, 0.02, 0.015), 3.5, 0.5, 0.68), ("n", (0.2, 0.04, 0.03), 11.0, 0.64, 0.74),
                   ("g", (0.03, 0.015, 0.012), 22.0, 0.016)], 0.6, 40, 0.6)
M_CARNE = mk_proc("Socio_Carne", (0.20, 0.025, 0.02), (0.04, 0.006, 0.007), 9,
                  [("n", (0.38, 0.08, 0.06), 16.0, 0.64, 0.8), ("g", (0.07, 0.004, 0.01), 18.0, 0.04),
                   ("n", (0.015, 0.006, 0.006), 6.0, 0.5, 0.68)], 0.3, 35, 0.7)
M_PIEL = mk_proc("Socio_Piel", (0.026, 0.011, 0.011), (0.006, 0.003, 0.003), 5,
                 [("n", (0.06, 0.028, 0.024), 3.0, 0.62, 0.82), ("n", (0.06, 0.006, 0.006), 6.0, 0.58, 0.72),
                  ("g", (0.004, 0.002, 0.002), 32.0, 0.02)], 0.5, 28, 0.6)
M_DIENTE = mk_proc("Socio_Diente", (0.45, 0.38, 0.24), (0.15, 0.10, 0.05), 25,
                   [("n", (0.12, 0.02, 0.015), 8.0, 0.55, 0.75)], 0.4, 60, 0.4)


M_BOCA = mk_proc("Socio_Boca", (0.30, 0.018, 0.028), (0.06, 0.004, 0.008), 6,
                 [("n", (0.55, 0.14, 0.15), 9.0, 0.6, 0.78), ("g", (0.12, 0.004, 0.012), 14.0, 0.05),
                  ("n", (0.02, 0.004, 0.006), 5.0, 0.5, 0.68)], 0.22, 28, 0.7, ao=True)


def mk_ojo():
    m = bpy.data.materials.new("Socio_Ojo")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (1, 1, 1, 1)
    em.inputs["Strength"].default_value = 10.0
    nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
    return m


M_OJO = mk_ojo()
M_HUECO = mk_proc("Socio_Hueco", (0.02, 0.012, 0.008), (0.006, 0.003, 0.003), 8,
                  [("n", (0.05, 0.006, 0.006), 5.0, 0.55, 0.75)], 0.8, 30, 0.4, ao=False)

PIEZAS = []  # (objeto, regla de pesos)


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


# ---------------------------------------------------------------- geometria
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


def limb(bm, a, b, r0, r1, n=8, segs=8, ridges=0.0, bow=(0, 0, 0)):
    pts = line(a, b, n)
    for i, p in enumerate(pts):
        p += V(bow) * math.sin(math.pi * i / (n - 1))
    radii = [lerp(r0, r1, i / (n - 1)) * (1 + ridges * math.sin(i * 2.1)) for i in range(n)]
    tube(bm, pts, radii, segs)


def blob(bm, c, s, segs=12, rings=8):
    tmp = bmesh.new()
    bmesh.ops.create_uvsphere(tmp, u_segments=segs, v_segments=rings, radius=1.0)
    m = {}
    for v in tmp.verts:
        m[v] = bm.verts.new(V((v.co.x * s[0], v.co.y * s[1], v.co.z * s[2])) + V(c))
    for f in tmp.faces:
        bm.faces.new([m[v] for v in f.verts])
    tmp.free()


def jitter(bm, amp, freq, seed=0.0):
    bm.normal_update()
    off = V((seed, seed * 0.7, seed * 1.3))
    for v in bm.verts:
        v.co += v.normal * (noise.noise(v.co * freq + off) * amp)


def sheet(bm, rows, cols, fn):
    g = [[bm.verts.new(fn(i, j)) for j in range(cols + 1)] for i in range(rows + 1)]
    for i in range(rows):
        for j in range(cols):
            try:
                bm.faces.new((g[i][j], g[i][j + 1], g[i + 1][j + 1], g[i + 1][j]))
            except ValueError:
                pass
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)


def solidify(bm, th):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=th)


def cinta(bm, a, b, w0, w1, n=6, caida=(0, 0, 0), seed=0.0, rasg=0.35):
    """Tira de carne/piel colgando entre a y b, con bordes rotos."""
    a, b = V(a), V(b)
    lado = (b - a).cross(V((0, 1, 0)))
    if lado.length < 1e-4:
        lado = V((1, 0, 0))
    lado.normalize()

    def pt(i, j):
        t = i / n
        c = a.lerp(b, t) + V(caida) * math.sin(math.pi * t)
        w = lerp(w0, w1, t) * (1 + rasg * noise.noise(V((seed + i * 0.7, j * 1.3, seed))))
        return c + lado * w * (j - 1) + V((0, -0.012 * math.sin(i * 2 + seed), 0))

    sheet(bm, n, 2, pt)


# ---------------------------------------------------------------- reglas de pesos
def rigido(bone):
    return lambda p: {bone: 1.0}


def cadena(joints, bones, blend=0.07):
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


def espejo(p, s):
    return (p[0] * s, p[1], p[2])


# ---------------------------------------------------------------- esqueleto (posiciones)
LADO = {
    "hip": (0.12, 0.02, 1.45),
    "knee": (0.13, -0.05, 0.78),
    "ankle": (0.14, 0.0, 0.10),
    "toe": (0.14, -0.26, 0.03),
    "hombro0": (0.04, 0.03, 2.32),
    "hombro": (0.38, 0.03, 2.33),
    "elbow": (0.46, -0.01, 1.70),
    "wrist": (0.50, -0.07, 1.10),
    "handend": (0.50, -0.09, 0.98),
}
SPINE = [(0, 0.02, 1.40), (0, 0.03, 1.62), (0, 0.06, 1.95), (0, 0.06, 2.30), (0, 0.05, 2.46), (0, 0.05, 2.60)]
CADENA_COLUMNA = (SPINE, ["Pelvis", "Spine1", "Spine2", "Neck1", "Neck2"])

# ---------------------------------------------------------------- calavera
HC, HZU, HZL, HX, HY = 2.90, 0.27, 0.36, 0.165, 0.19  # centro, semieje sup., inf., ancho, fondo


def kfac(zr):
    return 1.0 if zr >= 0 else 1 - 0.28 * ss(-0.15, -1.0, zr)


def head_r(zw):
    zr = (zw - HC) / (HZU if zw >= HC else HZL)
    if abs(zr) >= 1:
        return 0.0, 0.0
    e = math.sqrt(1 - zr * zr)
    k = kfac(zr)
    return HX * e * k, HY * e * k


def gauss(d2, s):
    return math.exp(-d2 / (s * s))


def rect(u, w, p=4):
    return (abs(u) ** p + abs(w) ** p) ** (1.0 / p)


def rasgos(p):
    """Desplazamiento (+ afuera, - adentro) del frente del craneo: orbitas cuadradas, nariz, pomulos."""
    if p.y > -0.02:
        return 0.0
    front = ss(-0.02, -0.08, p.y)
    d = 0.0
    for sx in (1, -1):
        r = rect((p.x - sx * 0.077) / 0.048, (p.z - 2.88) / 0.034)
        d -= 0.066 * ss(1.0, 0.5, r) * front
        d += 0.011 * ss(0.95, 1.12, r) * ss(1.55, 1.25, r) * front  # reborde de la orbita
        d += 0.020 * gauss((p.x - sx * 0.102) ** 2 + (p.z - 2.775) ** 2, 0.035) * front  # pomulo
        d -= 0.020 * gauss((p.x - sx * 0.088) ** 2 + (p.z - 2.70) ** 2, 0.032) * front  # mejilla hundida
        d -= 0.013 * gauss((p.x - sx * 0.145) ** 2 + (p.z - 2.90) ** 2 + (p.y + 0.03) ** 2, 0.05)  # sien
    d += 0.020 * gauss((p.z - 2.94) ** 2, 0.016) * ss(0.14, 0.09, abs(p.x)) * front  # ceja
    hw = 0.008 + 0.022 * ss(2.80, 2.72, p.z)
    nariz = ss(1.0, 0.55, abs(p.x) / hw) * ss(2.695, 2.72, p.z) * ss(2.825, 2.80, p.z)
    d -= 0.062 * nariz * front
    d += 0.012 * gauss((p.z - 2.665) ** 2, 0.02) * ss(0.08, 0.045, abs(p.x)) * front  # encia/maxilar
    return d


bm = bmesh.new()
bmesh.ops.create_uvsphere(bm, u_segments=40, v_segments=26, radius=1.0)
for v in bm.verts:
    x, y, z = v.co
    k = kfac(z)
    v.co = V((x * HX * k, y * HY * k, HC + z * (HZU if z >= 0 else HZL)))
bm.normal_update()
dsp = {}
for v in bm.verts:
    dsp[v] = rasgos(v.co)
    v.co = v.co + v.normal * dsp[v]
for f in bm.faces:
    if sum(dsp[v] for v in f.verts) / len(f.verts) < -0.04:
        f.material_index = 1
jitter(bm, 0.0025, 14.0, 3.0)

# ---- la cara se parte por el medio: dos mitades (con su hueso cada una) que se abren hacia los lados, como en IT
from mathutils.bvhtree import BVHTree

bvh = BVHTree.FromBMesh(bm)  # superficie de la calavera entera, para apoyar los colmillos
CENTRO_CABEZA = V((0, 0, HC))


def grupo(f):
    c = f.calc_center_median()
    if c.y < -0.015 and c.z < 2.975:
        return "L" if c.x > 0 else "R"
    return "C"


grupos = [grupo(f) for f in bm.faces]


def pared_hueca(g, nombre, hueso):
    """Copia solo las caras del grupo g y les da grosor: afuera hueso, adentro carne (se ve al abrirse la cara)."""
    b = bm.copy()
    borrar = [f for f, gg in zip(b.faces, grupos) if gg != g]
    bmesh.ops.delete(b, geom=borrar, context="FACES")
    # sin recalcular normales: en una cáscara abierta saldrían al revés; las de la esfera ya miran hacia afuera
    bmesh.ops.solidify(b, geom=b.faces[:], thickness=-0.02)
    # ahora es un sólido cerrado: recalcular deja las normales hacia afuera (commit hace lo mismo, así la clasificación coincide)
    bmesh.ops.recalc_face_normals(b, faces=b.faces[:])
    b.normal_update()
    for f in b.faces:
        n = f.normal
        c = f.calc_center_median()
        r = c - CENTRO_CABEZA
        if r.length > 1e-6 and n.dot(r.normalized()) < -0.25:
            f.material_index = 2  # interior: carne
    commit(nombre, b, [M_CRANEO, M_HUECO, M_BOCA], rigido(hueso))


pared_hueca("C", "Cabeza", "Head")
pared_hueca("L", "CaraL", "FaceL")
pared_hueca("R", "CaraR", "FaceR")


# ---- colmillos: una fila en el borde del corte de cada mitad (se cruzan al cerrarse) y otros adentro, sobre la pared
def colmillo(bmx, base, direccion, largo, grosor):
    tip = base + direccion * largo
    tube(bmx, [base, tip], [(grosor, grosor * 0.8), (grosor * 0.12, grosor * 0.1)], 4)


rng_c = random.Random(5)
for lado, nombre, hueso in ((1, "ColmillosL", "FaceL"), (-1, "ColmillosR", "FaceR")):
    bmx = bmesh.new()
    pasos = 18
    for i in range(pasos):
        z = 2.965 - i * 0.0235 - (0.012 if lado < 0 else 0.0)
        hit = bvh.ray_cast(V((lado * 0.004, -0.6, z)), V((0, 1, 0)))
        if hit[0] is None:
            continue
        p = hit[0] + V((0, 0.012, 0))
        centro = 1 - abs(i - pasos * 0.55) / (pasos * 0.55)
        largo = 0.035 + 0.045 * centro * rng_c.uniform(0.7, 1.1)
        dirv = V((-lado * 0.9, 0.3, -0.12 + rng_c.uniform(-0.1, 0.1))).normalized()
        colmillo(bmx, p, dirv, largo, 0.0075 + 0.003 * centro)
    for _ in range(12):  # sobre la pared de adentro
        x = lado * rng_c.uniform(0.025, 0.115)
        z = rng_c.uniform(2.58, 2.94)
        hit = bvh.ray_cast(V((x, -0.6, z)), V((0, 1, 0)))
        if hit[0] is None:
            continue
        p = hit[0] + V((0, 0.02, 0))
        dirv = (V((0, 0.0, 2.78)) - p).normalized()
        colmillo(bmx, p, dirv, rng_c.uniform(0.025, 0.05), 0.0065)
    jitter(bmx, 0.0008, 40.0, 2.0 + lado)
    commit(nombre, bmx, M_DIENTE, rigido(hueso))
# corona de colmillos en la pared del fondo, apuntando hacia adelante (se ven al abrirse la cara)
bmx = bmesh.new()
for i in range(22):
    ang = 2 * math.pi * i / 22
    x, z = 0.062 * math.cos(ang), 2.775 + 0.13 * math.sin(ang)
    hit = bvh.ray_cast(V((x, 0.0, z)), V((0, 1, 0)))
    if hit[0] is None:
        continue
    base = hit[0] - V((0, 0.03, 0))
    dirv = V((-x * 2.0, -1.0, (2.775 - z) * 1.5)).normalized()
    colmillo(bmx, base, dirv, rng_c.uniform(0.04, 0.07), 0.0085)
jitter(bmx, 0.0008, 40.0, 3.0)
commit("ColmillosFondo", bmx, M_DIENTE, rigido("Head"))
bm.free()

# ---- mandibula partida: cada mitad se va con su lado de la cara
U = [(-0.105, 0.03, 2.80), (-0.108, 0.02, 2.70), (-0.100, 0.0, 2.60), (-0.083, -0.035, 2.545),
     (-0.045, -0.062, 2.52), (0.0, -0.070, 2.515)]
rad = [(0.015, 0.011)] * 3 + [(0.016, 0.012), (0.019, 0.014), (0.021, 0.015)]
for signo, nombre, hueso in ((-1, "MandibulaR", "FaceR"), (1, "MandibulaL", "FaceL")):
    bmx = bmesh.new()
    tube(bmx, [(x * -signo, y, z) for x, y, z in U], rad, 6, up=(0, 0, 1))
    jitter(bmx, 0.0025, 14.0, 4.0 + signo)
    commit(nombre, bmx, M_CRANEO, rigido(hueso))

# ojos: dos rectangulos que brillan dentro de las orbitas (objeto aparte, el juego pone los suyos)
bm = bmesh.new()
for sx in (1, -1):
    tmp = bmesh.new()
    bmesh.ops.create_cube(tmp, size=1.0)
    m = {}
    for v in tmp.verts:
        m[v] = bm.verts.new(V((v.co.x * 0.050 + sx * 0.077, v.co.y * 0.018 - 0.13, v.co.z * 0.019 + 2.88)))
    for f in tmp.faces:
        bm.faces.new([m[v] for v in f.verts])
    tmp.free()
ojos = commit("Socio_Ojos", bm, M_OJO, rigido("Head"), smooth=False)
PIEZAS.pop()

# ---------------------------------------------------------------- capucha (piel oscura pegada al craneo)
G = math.radians(40)


def hood_r(z):
    if z >= 2.66:
        zz = min(z, 3.12)
        rx, ry = head_r(zz)
        if z > 3.12:
            f = max(0.0, (3.25 - z) / (3.25 - 3.12))
            rx, ry = rx * f, ry * f
        return rx * 1.1 + 0.014 * (1 if z < 3.24 else 0), ry * 1.1 + 0.014 * (1 if z < 3.24 else 0)
    rx0, ry0 = head_r(2.66)
    rx0, ry0 = rx0 * 1.1 + 0.014, ry0 * 1.1 + 0.014
    t = ss(2.66, 2.30, z)
    u = ss(2.28, 2.05, z)
    return lerp(lerp(rx0, 0.43, t), 0.335, u), lerp(lerp(ry0, 0.27, t), 0.25, u)


def hood_pt(i, j, rows=22, cols=30):
    s = i / rows
    phi = G + (2 * math.pi - 2 * G) * j / cols
    zb = 1.60 - 0.20 * (abs(math.sin(phi * 2.6 + 0.7)) ** 0.9) - 0.13 * (abs(math.sin(phi * 7.0 + 1.1)) ** 2) - 0.08 * noise.noise(V((phi * 1.7, 4.0, 0)))
    zb -= 0.45 * ss(0.6, 0.0, min(phi - G, 2 * math.pi - G - phi)) ** 1.3
    zb -= 0.10 * (abs(math.sin(phi * 5.0 + 2.0)) ** 2.5)
    z = lerp(3.25, zb, s ** 0.85)
    rx, ry = hood_r(z)
    f = 1 + 0.10 * ss(2.66, 2.25, z) * math.sin(phi * 8 + 1.3 + math.sin(phi * 2) * 1.5) + 0.035 * math.sin(phi * 11 + 0.5) * ss(2.3, 1.8, z)
    f += 0.014 * noise.noise(V((phi * 2, z * 5, 1.0)))
    return V((rx * f * math.sin(phi), 0.015 - ry * f * math.cos(phi), z))


bm = bmesh.new()
sheet(bm, 22, 30, hood_pt)
solidify(bm, 0.018)
jitter(bm, 0.006, 20.0, 6.0)
def reg_capa(p):
    a = ss(2.42, 2.74, p.z)
    b = ss(1.5, 1.95, p.z)
    w = {"Head": a, "Spine2": (1 - a) * b, "Spine1": (1 - a) * (1 - b)}
    # el borde delantero de la capucha acompaña a las mitades de la cara cuando se abren
    k = ss(0.06, 0.11, abs(p.x)) * ss(-0.02, -0.08, p.y) * ss(2.50, 2.60, p.z) * ss(3.05, 2.95, p.z)
    if k > 0:
        for n in list(w):
            w[n] *= 1 - k
        w["FaceL" if p.x > 0 else "FaceR"] = k
    return w


commit("Capucha", bm, M_PIEL, reg_capa)


# ---------------------------------------------------------------- falda andrajosa
def skirt_pt(i, j, rows=8, cols=24):
    s = i / rows
    phi = math.radians(30) + (2 * math.pi - 2 * math.radians(30)) * j / cols
    tat = 0.34 * (abs(math.sin(phi * 3.5 + 0.4)) ** 1.6) + 0.10 * (abs(math.sin(phi * 9.0)) ** 2) + 0.05 * noise.noise(V((phi * 2.3, 7.0, 0)))
    zb = 0.52 - tat
    z = lerp(1.62, zb, s)
    t = ((1.62 - z) / 1.3) ** 0.8
    rx, ry = lerp(0.20, 0.44, t), lerp(0.16, 0.30, t)
    f = 1 + 0.09 * math.sin(phi * 9) * ss(0, 0.6, s) + 0.012 * noise.noise(V((phi * 3, z * 4, 2.0)))
    return V((rx * f * math.sin(phi), 0.02 - ry * f * math.cos(phi), z))


bm = bmesh.new()
sheet(bm, 8, 24, skirt_pt)
solidify(bm, 0.012)


def reg_falda(p):
    k = 0.55 * ss(1.4, 0.4, p.z)
    return {"Pelvis": 1 - k, ("UpperLeg_L" if p.x >= 0 else "UpperLeg_R"): k}


commit("Falda", bm, M_PIEL, reg_falda)

# ---------------------------------------------------------------- columna + cuello (vertebras)
bm = bmesh.new()
pts, rad = [], []
N = 46
for i in range(N):
    t = i / (N - 1)
    z = lerp(1.38, 2.60, t)
    y = lerp(0.03, 0.07, ss(1.38, 1.95, z)) - 0.02 * ss(2.3, 2.60, z)
    pts.append((0, y, z))
    neck = ss(2.28, 2.36, z)
    rad.append(lerp(0.044, 0.05, neck) if i % 2 == 0 else lerp(0.033, 0.040, neck))
tube(bm, pts, rad, 8, up=(1, 0, 0))
jitter(bm, 0.003, 8.0, 5.0)
commit("Columna", bm, M_HUESO, cadena(*CADENA_COLUMNA, 0.05))

# ---------------------------------------------------------------- caja toracica gruesa + relleno de carne
bm = bmesh.new()
NR = 5
for i in range(NR):
    zc = 2.22 - i * 0.105
    barril = math.sin(math.pi * (i + 0.9) / (NR + 0.6))
    rx = 0.11 + 0.085 * barril
    ry = 0.08 + 0.07 * barril
    for sx in (1, -1):
        pts, rad = [], []
        steps = 10
        for k in range(steps):
            th = lerp(0.18, 2.78, k / (steps - 1))
            pts.append((sx * rx * math.sin(th), 0.075 + ry * math.cos(th), zc - 0.03 * (k / (steps - 1))))
            e = 0.040 * (0.62 + 0.38 * math.sin(math.pi * k / (steps - 1))) + 0.005
            rad.append((e * 0.7, e * 1.25))
        tube(bm, pts, rad, 8, up=(0, 0, 1))
jitter(bm, 0.012, 12.0, 8.0)
commit("Costillas", bm, M_HUESO, cadena(*CADENA_COLUMNA, 0.05))

bm = bmesh.new()
blob(bm, (0, 0.075, 2.0), (0.135, 0.095, 0.27), 20, 14)
jitter(bm, 0.012, 11.0, 9.0)
commit("PechoCarne", bm, M_CARNE, cadena(*CADENA_COLUMNA, 0.05))

bm = bmesh.new()
for k, sx in enumerate((1, -1)):
    cinta(bm, (sx * 0.15, -0.07, 2.10), (sx * 0.12, -0.085, 1.82), 0.026, 0.008, 6, (sx * 0.02, -0.03, 0), 20.0 + k, 0.6)
solidify(bm, 0.008)
commit("PielPecho", bm, M_CARNE, cadena(*CADENA_COLUMNA, 0.05))

# ---------------------------------------------------------------- pelvis
bm = bmesh.new()
blob(bm, (0, 0.03, 1.46), (0.15, 0.09, 0.08))
for sx in (1, -1):
    blob(bm, (sx * 0.14, 0.03, 1.52), (0.085, 0.05, 0.13))
jitter(bm, 0.004, 8.0, 2.0)
commit("Pelvis", bm, M_HUESO, rigido("Pelvis"))

# ---------------------------------------------------------------- cuello: tiras de piel
bm = bmesh.new()
for k, sx in enumerate((1, -1)):
    cinta(bm, (sx * 0.05, -0.03, 2.50), (sx * 0.07, -0.05, 2.28), 0.022, 0.012, 5, (sx * 0.015, -0.015, 0), 3.0 + k)
solidify(bm, 0.008)
commit("CuelloCarne", bm, M_CARNE, cadena(*CADENA_COLUMNA, 0.05))

# ---------------------------------------------------------------- brazos, hombros, manos, piernas
FINGER_BASES = [-0.036, -0.012, 0.012, 0.036]
FINGER_LEN = [0.30, 0.36, 0.34, 0.26]

for s in (1, -1):
    S = "L" if s > 0 else "R"
    P = {k: espejo(v, s) for k, v in LADO.items()}

    # hombro: clavicula + puas irregulares como la referencia
    bm = bmesh.new()
    limb(bm, (s * 0.04, -0.015, 2.335), P["hombro"], 0.028, 0.034, 6, 6, bow=(0, -0.03, -0.03))
    for (a, b, r) in (((0.30, 0.04, 2.36), (0.66, 0.04, 2.52), 0.075),
                      ((0.32, 0.11, 2.34), (0.60, 0.17, 2.42), 0.058),
                      ((0.30, -0.02, 2.34), (0.57, -0.07, 2.37), 0.05),
                      ((0.36, 0.04, 2.40), (0.44, 0.05, 2.60), 0.034)):
        a, b = V((a[0] * s, a[1], a[2])), V((b[0] * s, b[1], b[2]))
        pts = [a.lerp(b, t / 4) + V((0, 0, 0.05 * (t / 4) ** 2)) for t in range(5)]
        tube(bm, pts, [r * (1 - t / 4) ** 0.9 * (0.75 + 0.5 * random.random()) + 0.003 for t in range(5)], 6, up=(0, 1, 0))
        for tt in (0.35, 0.6):
            c = a.lerp(b, tt)
            e = c + V((s * 0.02, 0.0, 0.0)) + V((0, 0.05 * (1 if random.random() > 0.5 else -1), 0.07))
            tube(bm, [c, c.lerp(e, 0.5), e], [r * 0.25, r * 0.15, 0.003], 4, up=(0, 0, 1))
    jitter(bm, 0.014, 14.0, 4.0 + s)
    commit("Hombro_" + S, bm, M_HUESO, rigido("Shoulder_" + S))

    # brazo
    bm = bmesh.new()
    limb(bm, P["hombro"], P["elbow"], 0.052, 0.036, 9, 7, 0.05, bow=(0.01 * s, 0.02, 0))
    blob(bm, P["hombro"], (0.07, 0.07, 0.07))
    blob(bm, P["elbow"], (0.052, 0.055, 0.058))
    tube(bm, line(P["elbow"], (P["elbow"][0] - s * 0.005, P["elbow"][1] + 0.08, P["elbow"][2] + 0.03), 4), [0.03, 0.026, 0.018, 0.006], 6)
    for off in (-0.017, 0.017):
        a = (P["elbow"][0] + off, P["elbow"][1], P["elbow"][2] - 0.03)
        b = (P["wrist"][0] + off * 0.7, P["wrist"][1], P["wrist"][2] + 0.02)
        limb(bm, a, b, 0.021, 0.016, 9, 6, 0.08, bow=(0, -0.012, 0))
    blob(bm, P["wrist"], (0.045, 0.034, 0.04))
    blob(bm, (P["wrist"][0], P["wrist"][1] - 0.005, P["wrist"][2] - 0.05), (0.052, 0.016, 0.058))
    jitter(bm, 0.004, 10.0, 6.0 + s)
    reg_brazo = cadena([P["hombro"], P["elbow"], P["wrist"], P["handend"]], ["UpperArm_" + S, "Forearm_" + S, "Hand_" + S], 0.07)
    commit("Brazo_" + S, bm, M_HUESO, reg_brazo)

    # tiras de carne colgando del brazo
    bm = bmesh.new()
    cinta(bm, (s * 0.36, 0.0, 2.30), (s * 0.45, -0.03, 1.92), 0.05, 0.016, 7, (s * 0.02, -0.04, 0), 10.0 + s)
    cinta(bm, (s * 0.40, 0.05, 2.28), (s * 0.49, 0.04, 1.80), 0.04, 0.012, 7, (s * 0.02, 0.04, 0), 12.0 + s)
    cinta(bm, (s * 0.47, -0.04, 1.68), (s * 0.51, -0.09, 1.30), 0.04, 0.012, 6, (s * 0.02, -0.03, 0), 14.0 + s)
    cinta(bm, (s * 0.46, 0.03, 1.66), (s * 0.49, 0.06, 1.38), 0.03, 0.01, 6, (s * 0.01, 0.03, 0), 16.0 + s)
    solidify(bm, 0.008)
    commit("CarneBrazo_" + S, bm, M_CARNE, reg_brazo)

    # dedos
    wr = V(P["wrist"])
    dedos = []
    for fi in range(4):
        base = wr + V((s * FINGER_BASES[fi], -0.012, -0.095))
        dedos.append((fi + 1, base, V((0, -0.12, -1)).normalized(), V((0, -0.55, -1)).normalized(),
                      FINGER_LEN[fi] * 0.55, FINGER_LEN[fi] * 0.45, 0.0135))
    base = wr + V((-s * 0.05, -0.012, -0.05))
    dedos.append((0, base, V((-s * 0.55, -0.25, -0.8)).normalized(), V((-s * 0.35, -0.7, -0.6)).normalized(), 0.12, 0.10, 0.015))
    for fi, base, d1, d2, l1, l2, r in dedos:
        mid = base + d1 * l1
        tip = mid + d2 * l2
        bm = bmesh.new()
        tube(bm, line(base, mid, 3), [r, r * 0.88, r * 0.78], 4)
        blob(bm, mid, (r * 1.15, r * 1.15, r * 1.15), 6, 4)
        tube(bm, line(mid, tip, 4), [r * 0.78, r * 0.66, r * 0.5, r * 0.18], 4)
        commit("Dedo%d_%s" % (fi, S), bm, M_HUESO, cadena([base, mid, tip], ["Finger%d_1_%s" % (fi, S), "Finger%d_2_%s" % (fi, S)], 0.02))
        LADO.setdefault("dedos_" + S, []).append((fi, base[:], mid[:], tip[:]))

    # pierna
    bm = bmesh.new()
    limb(bm, P["hip"], P["knee"], 0.064, 0.044, 9, 7, 0.04, bow=(0, -0.025, 0))
    blob(bm, P["hip"], (0.07, 0.07, 0.07))
    blob(bm, P["knee"], (0.05, 0.055, 0.055))
    limb(bm, P["knee"], P["ankle"], 0.046, 0.032, 11, 7, 0.07, bow=(0, 0.02, 0))
    blob(bm, P["ankle"], (0.036, 0.04, 0.04))
    limb(bm, P["ankle"], (P["ankle"][0], P["ankle"][1] - 0.13, 0.04), 0.034, 0.024, 5, 6)
    blob(bm, (P["ankle"][0], P["ankle"][1] - 0.15, 0.035), (0.035, 0.11, 0.028), 8, 6)
    for tx in (-0.02, 0.0, 0.02):
        tube(bm, line((P["toe"][0] + tx * s, P["toe"][1] + 0.05, 0.035), (P["toe"][0] + tx * s * 1.6, P["toe"][1] - 0.10, 0.015), 4),
             [0.012, 0.011, 0.009, 0.004], 5)
    jitter(bm, 0.003, 10.0, 7.0 + s)
    commit("Pierna_" + S, bm, M_HUESO, cadena([P["hip"], P["knee"], P["ankle"], P["toe"]], ["UpperLeg_" + S, "LowerLeg_" + S, "Foot_" + S], 0.07))

# ---------------------------------------------------------------- armature
arm = bpy.data.armatures.new("Socio_Rig")
rig = bpy.data.objects.new("Socio_Rig", arm)
COL.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
EB = arm.edit_bones


def bone(name, head, tail, parent=None):
    b = EB.new(name)
    b.head = V(head)
    b.tail = V(tail)
    if parent:
        b.parent = EB[parent]
    return b


bone("Root", (0, 0, 0), (0, 0, 0.2))
bone("Pelvis", SPINE[0], SPINE[1], "Root")
bone("Spine1", SPINE[1], SPINE[2], "Pelvis")
bone("Spine2", SPINE[2], SPINE[3], "Spine1")
bone("Neck1", SPINE[3], SPINE[4], "Spine2")
bone("Neck2", SPINE[4], SPINE[5], "Neck1")
bone("Head", SPINE[5], (0, 0.03, 3.20), "Neck2")
bone("FaceL", (0.14, -0.01, 3.00), (0.14, -0.01, 2.56), "Head")
bone("FaceR", (-0.14, -0.01, 3.00), (-0.14, -0.01, 2.56), "Head")
for s in (1, -1):
    S = "L" if s > 0 else "R"
    P = {k: espejo(v, s) for k, v in LADO.items() if not k.startswith("dedos")}
    bone("Shoulder_" + S, P["hombro0"], P["hombro"], "Spine2")
    bone("UpperArm_" + S, P["hombro"], P["elbow"], "Shoulder_" + S)
    bone("Forearm_" + S, P["elbow"], P["wrist"], "UpperArm_" + S)
    bone("Hand_" + S, P["wrist"], P["handend"], "Forearm_" + S)
    for fi, base, mid, tip in LADO["dedos_" + S]:
        bone("Finger%d_1_%s" % (fi, S), base, mid, "Hand_" + S)
        bone("Finger%d_2_%s" % (fi, S), mid, tip, "Finger%d_1_%s" % (fi, S))
    bone("UpperLeg_" + S, P["hip"], P["knee"], "Pelvis")
    bone("LowerLeg_" + S, P["knee"], P["ankle"], "UpperLeg_" + S)
    bone("Foot_" + S, P["ankle"], P["toe"], "LowerLeg_" + S)
bpy.ops.object.mode_set(mode="OBJECT")

# ---------------------------------------------------------------- pesos + unir
for ob, regla in PIEZAS:
    for v in ob.data.vertices:
        for nombre, w in regla(v.co).items():
            vg = ob.vertex_groups.get(nombre) or ob.vertex_groups.new(name=nombre)
            vg.add([v.index], w, "REPLACE")

lista = [o for o, _ in PIEZAS]
for o in bpy.context.selected_objects:
    o.select_set(False)
for o in lista:
    o.select_set(True)
bpy.context.view_layer.objects.active = lista[0]
with bpy.context.temp_override(active_object=lista[0], selected_objects=lista, selected_editable_objects=lista):
    bpy.ops.object.join()
malla = bpy.context.view_layer.objects.active
malla.name = "Socio_Malla"
malla.data.name = "Socio_Malla"
mod = malla.modifiers.new("Armature", "ARMATURE")
mod.object = rig
malla.parent = rig
ojos.parent = rig
vg = ojos.vertex_groups.new(name="Head")
vg.add([v.index for v in ojos.data.vertices], 1.0, "REPLACE")
mod = ojos.modifiers.new("Armature", "ARMATURE")
mod.object = rig

tris = sum(len(p.vertices) - 2 for p in malla.data.polygons)
result = {
    "tris": tris,
    "verts": len(malla.data.vertices),
    "huesos": len(arm.bones),
    "grupos": len(malla.vertex_groups),
    "materiales": [m.name for m in malla.data.materials],
    "dim": [round(x, 3) for x in malla.dimensions],
}
