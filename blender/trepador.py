# Trepador: la criatura de la anomalia "FiguraAlFondo" (reemplaza a la arana hecha de partes).
# Mezcla de tres referencias: piel gris palida y seis extremidades larguisimas (4 brazos de manos enormes + 2 patas),
# patas finas y secas como ramas con los codos muy altos, y cara larga y angulosa con la boca abierta.
# Pose de reposo = pose de trepar sobre una superficie (z=0): las manos y pies tocan la superficie, el cuerpo flota ~1.1 m.
# Correr con:  exec(compile(open(r"C:/Users/kilic/Desktop/rolbox/blender/comun.py").read(), "comun", "exec"), globals())
#              exec(compile(open(r"C:/Users/kilic/Desktop/rolbox/blender/trepador.py").read(), "trepador", "exec"), globals())
iniciar("Trepador", 5)

# ---------------------------------------------------------------- materiales
M_PIEL = mk_proc("Trep_Piel", (0.050, 0.047, 0.046), (0.014, 0.013, 0.013), 5,
                 [("n", (0.105, 0.095, 0.090), 2.6, 0.58, 0.82),     # polvo de ceniza en manchas grandes
                  ("n", (0.060, 0.028, 0.034), 6.0, 0.60, 0.78),     # venas / moretones violaceos oscuros
                  ("g", (0.20, 0.185, 0.17), 34.0, 0.010),           # cicatrices finas y claras
                  ("g", (0.004, 0.003, 0.003), 16.0, 0.030),         # grietas hondas casi negras
                  ("n", (0.020, 0.018, 0.017), 38.0, 0.50, 0.72),    # poros
                  ("n", (0.16, 0.15, 0.14), 55.0, 0.70, 0.80)], 0.38, 55, 0.5)
M_HUECO = mk_proc("Trep_Hueco", (0.012, 0.010, 0.010), (0.004, 0.003, 0.003), 8, [], 0.8, 30, 0.2, ao=False)
M_OJO = mk_plano("Trep_Ojo", (0.9, 0.9, 0.85), 0.3)
M_DIENTE = mk_proc("Trep_Diente", (0.62, 0.57, 0.44), (0.30, 0.26, 0.18), 25, [("n", (0.18, 0.12, 0.08), 8.0, 0.55, 0.75)], 0.4, 60, 0.4)
M_BOCA = mk_proc("Trep_Boca", (0.16, 0.025, 0.03), (0.05, 0.008, 0.01), 6, [("n", (0.30, 0.06, 0.07), 9.0, 0.6, 0.78)], 0.25, 28, 0.6)
M_UNA = mk_proc("Trep_Una", (0.16, 0.14, 0.11), (0.06, 0.05, 0.04), 12, [], 0.35, 40, 0.3, ao=False)

# ---------------------------------------------------------------- columna, cuello, cabeza (huesos)
SP = [V(p) for p in [(0, 0.60, 1.05), (0, 0.20, 1.09), (0, -0.22, 1.15), (0, -0.62, 1.20), (0, -0.86, 1.16), (0, -1.00, 1.08)]]
hueso("Root", (0, 0, 0), (0, 0, 0.2))
hueso("Pelvis", SP[0], SP[1], "Root")
hueso("Spine1", SP[1], SP[2], "Pelvis")
hueso("Spine2", SP[2], SP[3], "Spine1")
hueso("Neck1", SP[3], SP[4], "Spine2")
hueso("Neck2", SP[4], SP[5], "Neck1")
HEAD_C = V((0, -1.04, 1.07))
hueso("Head", SP[5], (0, -1.22, 1.06), "Neck2")
hueso("Jaw", (0, -0.95, 1.0), (0, -1.16, 0.80), "Head")

COLUMNA = cadena([SP[0] + V((0, 0.3, 0)), SP[1], SP[2], SP[3], SP[3] + V((0, -0.3, 0))], ["Pelvis", "Spine1", "Spine2"], 0.1)

# torso: pecho largo y estrecho + vientre + costillas a la vista + vertebras
bm = nuevo_bm()
blob(bm, (0, -0.22, 1.15), (0.25, 0.44, 0.23), 16, 10)
blob(bm, (0, 0.45, 1.05), (0.19, 0.30, 0.17), 14, 9)
blob(bm, (0, 0.02, 1.08), (0.18, 0.25, 0.15), 12, 8)
jitter(bm, 0.008, 6.0, 3.0)
commit("Torso", bm, M_PIEL, COLUMNA)

bm = nuevo_bm()
for s in (1, -1):
    for i in range(7):
        y = -0.52 + 0.115 * i
        z0 = 1.15 + 0.0 - 0.0
        rama(bm, [(s * 0.02, y, 0.93), (s * 0.23, y + 0.02, 1.0), (s * 0.265, y + 0.03, 1.15), (s * 0.15, y + 0.02, 1.33)],
             [0.02, 0.019, 0.018, 0.014], sub=3, segs=5)
commit("Costillas", bm, M_PIEL, COLUMNA)

bm = nuevo_bm()
for i in range(9):
    y = -0.60 + 0.115 * i
    blob(bm, (0, y, 1.37 - 0.02 * math.sin(i * 0.3)), (0.03, 0.034, 0.034), 6, 5)
commit("Vertebras", bm, M_PIEL, COLUMNA)

# cuello largo y fino
bm = nuevo_bm()
rama(bm, [SP[3] + V((0, 0.15, 0)), SP[3], SP[4], SP[5] + V((0, -0.02, 0.0))], [0.07, 0.05, 0.042, 0.05], sub=4, segs=8)
commit("Cuello", bm, M_PIEL, cadena([SP[3] + V((0, 0.15, 0)), SP[3], SP[4], SP[5], SP[5] + V((0, -0.1, 0))], ["Neck1", "Neck2", "Head"], 0.05))

# cabeza: malla densa deformada (como el craneo del Socio): orbitas, nariz, mejillas y boca hundidas de verdad;
# lo hundido se pinta oscuro por regiones (material 1) en vez de pegar bolas negras.
def gauss3(p, c, r):
    d = V(((p.x - c.x) / r[0], (p.y - c.y) / r[1], (p.z - c.z) / r[2]))
    return math.exp(-d.length_squared * 2.0)


HC = HEAD_C
K = 0.85  # escala de la cabeza
PROF = 2.0  # cuanto mas hondo se hunden los rasgos
# (centro, radios, profundidad, oscuro) en el marco de la cabeza (frente = -Y); s = lado
def rasgos_cabeza():
    r = []
    for s in (1, -1):
        r.append((V((s * 0.047, -0.15, 0.065)), (0.042, 0.045, 0.03), 0.040, 0.30))    # orbita
        r.append((V((s * 0.078, -0.09, -0.04)), (0.04, 0.06, 0.075), 0.026, 9))         # mejilla hueca
        r.append((V((s * 0.05, -0.04, 0.17)), (0.05, 0.08, 0.05), 0.018, 9))            # sien
        r.append((V((s * 0.05, -0.15, 0.115)), (0.05, 0.03, 0.016), -0.014, 9))         # arco de la ceja (sale)
    r.append((V((0, -0.17, -0.03)), (0.016, 0.03, 0.03), 0.028, 0.30))                  # fosas nasales
    r.append((V((0, -0.165, 0.045)), (0.014, 0.03, 0.06), -0.012, 9))                   # puente de la nariz (sale)
    r.append((V((0, -0.15, -0.115)), (0.07, 0.055, 0.062), 0.075, 0.30))                 # boca (hueco profundo)
    return [(c * K, tuple(x * K for x in rad), prof * K * (PROF if prof > 0 else 1.0), um) for c, rad, prof, um in r]


bm = nuevo_bm()
tmp = bmesh.new()
bmesh.ops.create_uvsphere(tmp, u_segments=36, v_segments=26, radius=1.0)
mapa = {}
for v in tmp.verts:
    p = V((v.co.x * 0.105, v.co.y * 0.155, v.co.z * 0.20)) * K
    if p.z < 0:                       # cara larga: el menton se estira hacia abajo y adelante
        p.y -= 0.05 * K * ss(0.0, -0.2 * K, p.z) * (1 - abs(p.x) / (0.105 * K) * 0.4)
        p.z *= 1.18
        p.x *= 1 - 0.28 * ss(0.0, -0.22 * K, p.z)
    mapa[v] = bm.verts.new(p + HC)
for f in tmp.faces:
    bm.faces.new([mapa[v] for v in f.verts])
tmp.free()
rg = rasgos_cabeza()
# region oscura segun la posicion ORIGINAL de cada cara
for f in bm.faces:
    c = f.calc_center_median()
    f.material_index = 0
    for cen, rad, prof, umbral in rg:
        if prof > 0 and umbral < 1 and gauss3(c, HC + cen, rad) > umbral:
            f.material_index = 1
bm.normal_update()
for cen, rad, prof, umbral in rg:
    for v in bm.verts:
        g = gauss3(v.co, HC + cen, rad)
        if g > 0.02:
            v.co -= v.normal * prof * g
jitter(bm, 0.0025, 18.0, 1.0)
commit("Cabeza", bm, [M_PIEL, M_HUECO], rigido("Head"))


def punto_frente(x, z):
    mejor, md = None, 1e9
    for v in HEAD_BM_VERTS:
        if v.y < HC.y:
            d = (v.x - x) ** 2 + (v.z - z) ** 2
            if d < md:
                mejor, md = v, d
    return mejor


HEAD_BM_VERTS = [HC + V(p) for p in [(0, 0, 0)]]
ob_cabeza = PIEZAS[-1][0]
HEAD_BM_VERTS = [v.co.copy() for v in ob_cabeza.data.vertices]

bm = nuevo_bm()
for s in (1, -1):
    c = punto_frente(HC.x + s * 0.036 * K, HC.z + 0.058 * K)
    blob(bm, c + V((0, -0.006, 0)), (0.0075, 0.004, 0.0075), 6, 5)    # una chispa de pupila al fondo de la orbita
commit("Pupilas", bm, M_OJO, rigido("Head"))

# dientes de arriba: en el borde alto de la boca
bm = nuevo_bm()
for i in range(-4, 5):
    x = i * 0.0125 * K
    c = punto_frente(HC.x + x, HC.z - 0.07 * K)
    cono(bm, c + V((0, 0.004, 0)), c + V((0, 0.0, -0.034 - 0.012 * (i % 2))), 0.0068, 4)
commit("DientesArriba", bm, M_DIENTE, rigido("Head"))

# mandibula abierta con dientes y lengua oscura
bm = nuevo_bm()
JAW0 = V((0, -0.95, 1.0))
rama(bm, [JAW0 + V((0.09, 0.0, 0.0)), JAW0 + V((0.075, -0.1, -0.075)), JAW0 + V((0.03, -0.2, -0.15)), JAW0 + V((0, -0.21, -0.165))], [0.022, 0.02, 0.017, 0.016], sub=3, segs=6)
rama(bm, [JAW0 + V((-0.09, 0.0, 0.0)), JAW0 + V((-0.075, -0.1, -0.075)), JAW0 + V((-0.03, -0.2, -0.15)), JAW0 + V((0, -0.21, -0.165))], [0.022, 0.02, 0.017, 0.016], sub=3, segs=6)
blob(bm, JAW0 + V((0, -0.1, -0.1)), (0.055, 0.09, 0.025), 8, 6)
commit("Mandibula", bm, M_PIEL, rigido("Jaw"))
bm = nuevo_bm()
for i in range(-3, 4):
    x = i * 0.02
    cono(bm, JAW0 + V((x, -0.17 - 0.003 * i * i, -0.125)), JAW0 + V((x, -0.17 - 0.003 * i * i, -0.125 + 0.03 + 0.01 * (i % 2))), 0.007, 4)
commit("DientesAbajo", bm, M_DIENTE, rigido("Jaw"))
bm = nuevo_bm()
blob(bm, JAW0 + V((0, -0.08, -0.105)), (0.04, 0.08, 0.018), 8, 5)
commit("Lengua", bm, M_BOCA, rigido("Jaw"))


# ---------------------------------------------------------------- manos y pies
def dedos_de(bm_dedos, nombre_mano, lado, muneca, d, n, largo, rad_, huesos_extra=True):
    """Crea n dedos que abren en abanico sobre la superficie; devuelve [(i, base, medio, punta)]."""
    d = V(d).normalized()
    lat = d.cross(V((0, 0, 1))).normalized()
    res = []
    for i in range(n):
        f = (i - (n - 1) / 2) / ((n - 1) / 2)       # -1..1
        ang = f * math.radians(62)
        dir_ = (d * math.cos(ang) + lat * math.sin(ang)).normalized()
        base = V(muneca) + d * 0.075 + lat * f * 0.05 + V((0, 0, 0.012))
        l1 = largo * (1.0 - 0.18 * abs(f)) * (0.82 if i == 0 else 1.0)
        mid = base + dir_ * l1 * 0.55 + V((0, 0, 0.012))
        tip = mid + dir_ * l1 * 0.50 + V((0, 0, 0.035))
        res.append((i, base, mid, tip))
    return res


def mano(sufijo, hueso_mano, muneca, d, escala=1.0):
    d = V(d).normalized()
    dedos = dedos_de(None, hueso_mano, sufijo, muneca, d, 5, 0.40 * escala, 0.012)
    # palma
    bm = nuevo_bm()
    rot = d.to_track_quat("Y", "Z").to_matrix()
    blob(bm, V(muneca) + d * 0.05 + V((0, 0, 0.02)), (0.075 * escala, 0.095 * escala, 0.03), 10, 6, rot=rot)
    commit("Palma_" + sufijo, bm, M_PIEL, rigido(hueso_mano))
    for i, base, mid, tip in dedos:
        n1, n2 = "D%d_1_%s" % (i, sufijo), "D%d_2_%s" % (i, sufijo)
        hueso(n1, base, mid, hueso_mano)
        hueso(n2, mid, tip, n1)
        bm = nuevo_bm()
        rama(bm, [base - (mid - base).normalized() * 0.03, base, mid, tip], [0.024 * escala, 0.020 * escala, 0.014 * escala, 0.009 * escala], sub=2, segs=6)
        commit("Dedo_%d_%s" % (i, sufijo), bm, M_PIEL, cadena([base - (mid - base).normalized() * 0.03, base, mid, tip + (tip - mid)], [n1, n2], 0.025))
        bm = nuevo_bm()
        cono(bm, tip, tip + (tip - mid).normalized() * 0.055 * escala + V((0, 0, -0.01)), 0.007 * escala, 4)
        commit("Una_%d_%s" % (i, sufijo), bm, M_UNA, rigido(n2))


def brazo(k, padre, sh, codo, mun, ancho_dedos=1.0):
    S = V(sh)
    E, W = V(codo), V(mun)
    d = V((W.x - E.x, W.y - E.y, 0)).normalized()
    cab = V((S.x * 0.2, S.y, S.z - 0.02))
    hueso("Sh_" + k, cab, S, padre)
    hueso("Up_" + k, S, E, "Sh_" + k)
    hueso("Fo_" + k, E, W, "Up_" + k)
    hueso("Ma_" + k, W, W + d * 0.1, "Fo_" + k)
    bm = nuevo_bm()
    blob(bm, S, (0.10, 0.12, 0.10), 8, 6)
    commit("Hombro_" + k, bm, M_PIEL, rigido("Sh_" + k))
    bm = nuevo_bm()
    rama(bm, [S, E, W + V((0, 0, 0.012))], [0.074, 0.054, 0.036], sub=6, segs=8, nudos=0.40)
    jitter(bm, 0.003, 9.0, 2.0)
    commit("Brazo_" + k, bm, M_PIEL, cadena([S, E, W, W + d * 0.1], ["Up_" + k, "Fo_" + k, "Ma_" + k], 0.06))
    mano(k, "Ma_" + k, W, d, ancho_dedos)


# dos pares de brazos
brazo("AL", "Spine2", (0.17, -0.34, 1.20), (0.85, -0.62, 1.55), (1.50, -1.12, 0.10))
brazo("AR", "Spine2", (-0.17, -0.34, 1.20), (-0.85, -0.62, 1.55), (-1.50, -1.12, 0.10))
brazo("BL", "Spine1", (0.18, 0.02, 1.14), (0.98, 0.12, 1.58), (1.78, -0.30, 0.10))
brazo("BR", "Spine1", (-0.18, 0.02, 1.14), (-0.98, 0.12, 1.58), (-1.78, -0.30, 0.10))

# dos patas traseras: rodilla alta, pie con tres dedos largos
for s, S_ in ((1, "L"), (-1, "R")):
    cadera = V((s * 0.15, 0.55, 1.0))
    rod = V((s * 0.72, 0.98, 1.36))
    tob = V((s * 0.96, 1.55, 0.18))
    pun = V((s * 0.96, 1.30, 0.03))
    hueso("Mu_" + S_, cadera, rod, "Pelvis")
    hueso("Pi_" + S_, rod, tob, "Mu_" + S_)
    hueso("Pie_" + S_, tob, pun, "Pi_" + S_)
    bm = nuevo_bm()
    blob(bm, cadera, (0.085, 0.10, 0.085), 8, 6)
    rama(bm, [cadera, rod, tob], [0.078, 0.056, 0.036], sub=6, segs=8, nudos=0.4)
    jitter(bm, 0.003, 9.0, 4.0)
    commit("Pata_" + S_, bm, M_PIEL, cadena([cadera, rod, tob, pun], ["Mu_" + S_, "Pi_" + S_, "Pie_" + S_], 0.06))
    bm = nuevo_bm()
    blob(bm, tob + V((0, -0.06, 0.02)), (0.04, 0.07, 0.025), 8, 6)
    for f in (-1, 0, 1):
        base = tob + V((f * 0.03, -0.1, 0.02))
        punta = base + V((f * 0.09, -0.30, 0.0))
        rama(bm, [base, (base + punta) / 2 + V((0, 0, 0.015)), punta + V((0, 0, 0.04))], [0.013, 0.010, 0.007], sub=2, segs=5)
        cono(bm, punta + V((0, 0, 0.04)), punta + V((f * 0.01, -0.06, 0.02)), 0.007, 4)
    commit("Pie_" + S_, bm, M_PIEL, rigido("Pie_" + S_))

result = terminar()
