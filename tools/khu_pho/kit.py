"""Bộ dựng nhà, mái, đồ đường phố cho khu phố Mèo Giao Bánh Mì (Blender, phong cách D).
Khối cứng dựng bằng hộp/trụ có bevel 1–2 cm, màu ấm Sài Gòn, trầm hơn nhân vật một bậc.
Toạ độ Blender: Z lên, mặt tiền nhà quay về -Y (về phía camera), x chạy dọc mặt tiền."""
import bpy, bmesh, math, random
import numpy as np
from mathutils import Vector, Matrix, Euler

FONT = '/usr/share/fonts/opentype/inter/Inter-ExtraBold.otf'
_MATS = {}
PARENT = [None]

def lin(h):
    h = h.lstrip('#'); c = np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)])
    c = np.where(c <= .04045, c / 12.92, ((c + .055) / 1.055) ** 2.4); return (*c, 1)

def M(hexc, rough=.8, metal=0.0, emit=0.0, sheen=0.0, alpha=1.0, coat=0.0):
    key = (hexc, rough, metal, emit, sheen, alpha, coat)
    if key in _MATS: return _MATS[key]
    m = bpy.data.materials.new(f'm{len(_MATS)}_{hexc}')
    if m.node_tree is None: m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = lin(hexc); b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metal; b.inputs['Sheen Weight'].default_value = sheen
    b.inputs['Coat Weight'].default_value = coat
    if emit:
        b.inputs['Emission Color'].default_value = lin(hexc); b.inputs['Emission Strength'].default_value = emit
    if alpha < 1:
        b.inputs['Alpha'].default_value = alpha
        try: m.surface_render_method = 'BLENDED'
        except Exception: pass
    _MATS[key] = m; return m

def _link(o, name=None):
    bpy.context.scene.collection.objects.link(o) if o.name not in bpy.context.scene.collection.objects else None
    if PARENT[0] is not None: o.parent = PARENT[0]
    if name: o.name = name
    return o

def group(name, loc=(0, 0, 0), rot=0.0):
    e = bpy.data.objects.new(name, None); bpy.context.scene.collection.objects.link(e)
    e.location = loc; e.rotation_euler = (0, 0, rot)
    if PARENT[0] is not None: e.parent = PARENT[0]
    return e

class at:
    """with at(group): mọi vật tạo trong khối này gắn vào group."""
    def __init__(self, g): self.g = g
    def __enter__(self): self.prev = PARENT[0]; PARENT[0] = self.g; return self.g
    def __exit__(self, *a): PARENT[0] = self.prev

def mesh_obj(name, verts, faces, mat, loc=(0, 0, 0), rot=(0, 0, 0), smooth=False):
    me = bpy.data.meshes.new(name); me.from_pydata([tuple(map(float, v)) for v in verts], [], [tuple(f) for f in faces]); me.update()
    o = bpy.data.objects.new(name, me); o.location = loc; o.rotation_euler = rot
    if mat: me.materials.append(mat)
    if smooth: me.polygons.foreach_set('use_smooth', [True] * len(me.polygons))
    return _link(o)

def bevel(o, w=.015, seg=2):
    md = o.modifiers.new('Bevel', 'BEVEL'); md.width = w; md.segments = seg; md.limit_method = 'ANGLE'
    try: md.harden_normals = False
    except Exception: pass
    return o

def box(size, loc, mat, bv=.015, rot=(0, 0, 0), name='hop'):
    """size (x, y, z), loc là tâm."""
    sx, sy, sz = [s / 2 for s in size]
    V = [(-sx, -sy, -sz), (sx, -sy, -sz), (sx, sy, -sz), (-sx, sy, -sz), (-sx, -sy, sz), (sx, -sy, sz), (sx, sy, sz), (-sx, sy, sz)]
    F = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    o = mesh_obj(name, V, F, mat, loc, rot)
    if bv: bevel(o, min(bv, min(size) * .45))
    return o

def boxab(a, b, mat, bv=.015, name='hop'):
    a = np.array(a, float); b = np.array(b, float)
    return box(tuple(np.abs(b - a)), tuple((a + b) / 2), mat, bv, name=name)

def cyl(r, h, loc, mat, rot=(0, 0, 0), n=24, r2=None, bv=.01, name='tru', smooth=True):
    r2 = r if r2 is None else r2
    V = [(r * math.cos(2 * math.pi * i / n), r * math.sin(2 * math.pi * i / n), -h / 2) for i in range(n)] + \
        [(r2 * math.cos(2 * math.pi * i / n), r2 * math.sin(2 * math.pi * i / n), h / 2) for i in range(n)]
    F = [tuple(range(n))[::-1], tuple(range(n, 2 * n))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    o = mesh_obj(name, V, F, mat, loc, rot)
    if smooth:
        md = o.modifiers.new('ws', 'WEIGHTED_NORMAL') if False else None
        o.data.polygons.foreach_set('use_smooth', [False, False] + [True] * n)
    if bv: bevel(o, bv)
    return o

def ball(r, loc, mat, scale=(1, 1, 1), sub=2, name='cau'):
    bm = bmesh.new(); bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); o.location = loc; o.scale = scale
    me.materials.append(mat); me.polygons.foreach_set('use_smooth', [True] * len(me.polygons))
    return _link(o)

def torus(R, r, loc, mat, rot=(0, 0, 0), n=32, m=12, name='vong'):
    V = []; F = []
    for i in range(n):
        a = 2 * math.pi * i / n
        for j in range(m):
            b = 2 * math.pi * j / m
            V.append(((R + r * math.cos(b)) * math.cos(a), (R + r * math.cos(b)) * math.sin(a), r * math.sin(b)))
    for i in range(n):
        for j in range(m):
            F.append((i * m + j, ((i + 1) % n) * m + j, ((i + 1) % n) * m + (j + 1) % m, i * m + (j + 1) % m))
    return mesh_obj(name, V, F, mat, loc, rot, smooth=True)

def corrugated(w, l, mat, loc, rot=(0, 0, 0), period=.076, amp=.012, thick=.006, name='ton'):
    """Tấm sóng (tôn, cửa cuốn, ngói): sóng chạy theo x, dài theo y."""
    nx = max(2, int(w / period * 6)); xs = np.linspace(0, w, nx); V = []; F = []
    for j, y in enumerate((0, l)):
        for x in xs: V.append((x - w / 2, y - l / 2, amp * math.sin(2 * math.pi * x / period)))
    for i in range(nx - 1): F.append((i, i + 1, nx + i + 1, nx + i))
    o = mesh_obj(name, V, F, mat, loc, rot, smooth=True)
    md = o.modifiers.new('S', 'SOLIDIFY'); md.thickness = thick
    return o

def text(body, size, loc, mat, rot=(math.pi / 2, 0, 0), extrude=.012, align='CENTER', name='chu'):
    cu = bpy.data.curves.new(name, 'FONT'); cu.body = body; cu.size = size; cu.extrude = extrude
    try: cu.font = bpy.data.fonts.load(FONT, check_existing=True)
    except Exception: pass
    cu.align_x = align; cu.align_y = 'CENTER'
    o = bpy.data.objects.new(name, cu); o.location = loc; o.rotation_euler = rot; cu.materials.append(mat)
    return _link(o)

def curve(points, r, mat, name='day'):
    cu = bpy.data.curves.new(name, 'CURVE'); cu.dimensions = '3D'; cu.bevel_depth = r; cu.bevel_resolution = 2
    sp = cu.splines.new('POLY'); sp.points.add(len(points) - 1)
    for i, p in enumerate(points): sp.points[i].co = (*p, 1)
    o = bpy.data.objects.new(name, cu); cu.materials.append(mat)
    return _link(o)

def sag(a, b, drop, n=16, wob=0.0, seed=0):
    rnd = random.Random(seed); a = np.array(a, float); b = np.array(b, float); pts = []
    for i in range(n + 1):
        t = i / n; p = a + (b - a) * t; p[2] -= drop * 4 * t * (1 - t)
        if wob and 0 < i < n: p += np.array([rnd.uniform(-wob, wob) for _ in range(3)]) * math.sin(math.pi * t)
        pts.append(tuple(p))
    return pts

# ---------------------------------------------------------------- bảng màu phố (trầm hơn nhân vật 1 bậc)
C = dict(mustard='#E2C07E', teal='#77AD9C', salmon='#DB957A', mint='#B6CFC8', cream='#EEDDB2', pink='#CFA0BA', blue='#9FBEDD',
         shutter='#2E7C80', shutter2='#5D6F70', iron='#2F3A3A', wood='#8A5A30', wood2='#B07C46', tile='#B4553A', tile2='#9A4430',
         ton_blue='#4F7FA0', ton_red='#A8473A', ton_rust='#9C6A48', concrete='#B9B3A6', concrete2='#9C978C', glass='#7FA8B0', dark='#262B2B',
         sidewalk='#C9C3B3', road='#8F8B80', curb='#D8D2C2', grass='#7DB46C', leaf='#4E8A4A', leaf2='#3E7A3E', boug='#D2368A', boug2='#E45AA6',
         red='#C8412F', yellow='#F2B33D', white='#F1ECE2', steel='#AEB6B8', black='#222222', plastic_red='#C9372C', plastic_blue='#3A6EA5')

# ---------------------------------------------------------------- chi tiết mặt tiền
def railing(x0, x1, y, z, h=1.0, mat=None, bar=.12, deco=True):
    mat = mat or M(C['iron'], .5, .6)
    boxab((x0, y - .025, z + h - .05), (x1, y + .025, z + h), mat, .01)
    boxab((x0, y - .02, z + .08), (x1, y + .02, z + .12), mat, .005)
    n = int((x1 - x0) / bar)
    for i in range(1, n):
        x = x0 + i * (x1 - x0) / n
        boxab((x - .01, y - .01, z + .12), (x + .01, y + .01, z + h - .05), mat, 0)
    if deco:
        for i in range(int((x1 - x0) / .5)):
            torus(.07, .008, (x0 + .25 + i * .5, y, z + h - .22), mat, rot=(math.pi / 2, 0, 0), n=16, m=6)

def louver_window(x, z, w, h, y, wall, col, open_=0.6):
    """Cửa sổ khung gỗ + 2 cánh chớp lá sách."""
    fm = M(C['white'], .7)
    for (a0, a1) in (((x - w / 2 - .08, z - .08), (x + w / 2 + .08, z)), ((x - w / 2 - .08, z + h), (x + w / 2 + .08, z + h + .08)),
                     ((x - w / 2 - .08, z), (x - w / 2, z + h)), ((x + w / 2, z), (x + w / 2 + .08, z + h)), ((x - .02, z), (x + .02, z + h))):
        boxab((a0[0], y - .07, a0[1]), (a1[0], y + .02, a1[1]), fm, .008)
    boxab((x - w / 2, y + .0, z), (x + w / 2, y + .05, z + h), M('#26302F', .25), 0)
    for k in range(1, 3): boxab((x - w / 2, y - .01, z + k * h / 3 - .01), (x + w / 2, y + .01, z + k * h / 3 + .01), fm, 0)
    sm = M(col, .7)
    for sd in (-1, 1):
        g = group('canh', (x + sd * w / 2, y - .06, z), rot=-sd * open_ * math.pi / 2 * 1.0)
        with at(g):
            boxab((min(0, -sd * w / 2), -.02, 0), (max(0, -sd * w / 2), .02, h), sm, .006)
            for k in range(int(h / .09)):
                box((w / 2 - .06, .05, .012), (-sd * w / 4, -.03, .06 + k * .09), M(col, .6), 0, rot=(.5, 0, 0))
    boxab((x - w / 2 - .14, y - .22, z - .14), (x + w / 2 + .14, y + .0, z - .06), M(wall, .85), .01)  # bậu cửa

def ac_unit(loc, rot=0):
    g = group('cuc_nong', loc, rot)
    with at(g):
        box((.8, .28, .55), (0, 0, 0), M('#E9E6DE', .5), .03)
        cyl(.2, .02, (-.12, -.145, 0), M('#3A3F40', .6), rot=(math.pi / 2, 0, 0), bv=.005)
        for i in range(5): box((.38, .012, .012), (-.12, -.16, -.16 + i * .08), M('#9AA0A0', .5), 0)
        for sx in (-.3, .3): box((.04, .4, .04), (sx, .1, -.3), M(C['iron'], .5, .6), 0)
    return g

def plant_pot(loc, h=.45, kind='bush', s=1.0, potc='#B4553A'):
    g = group('chau', loc)
    with at(g):
        cyl(.18 * s, h * .55 * s, (0, 0, h * .275 * s), M(potc, .8), n=20, r2=.22 * s, bv=.015)
        if kind == 'bush':
            for i, (dx, dy, dz, r) in enumerate([(0, 0, .55, .26), (.12, .05, .48, .18), (-.13, -.04, .5, .19), (.02, -.1, .66, .17)]):
                ball(r * s, (dx * s, dy * s, dz * s + h * .2), M(C['leaf'] if i % 2 else C['leaf2'], .85, sheen=.3), sub=2)
        elif kind == 'boug':
            rnd = random.Random(int(loc[0] * 10 + loc[1] * 7))
            for i in range(22):
                a = rnd.uniform(0, 6.28); r = rnd.uniform(0, .26); z = rnd.uniform(.35, .85)
                ball(rnd.uniform(.06, .1) * s, (math.cos(a) * r * s, math.sin(a) * r * s, z * s + h * .1), M(C['boug'] if i % 3 else C['leaf'], .85, sheen=.3), sub=1)
        elif kind == 'palm':  # cau kiểng
            for i in range(6):
                a = i * 1.05
                curve([(0, 0, .3 * s), (math.cos(a) * .25 * s, math.sin(a) * .25 * s, .9 * s), (math.cos(a) * .55 * s, math.sin(a) * .55 * s, .75 * s)], .025 * s, M(C['leaf'], .8), name='la')
            cyl(.03 * s, .7 * s, (0, 0, .5 * s), M('#7A6A40', .8), bv=0)
    return g

def boug_cascade(x0, x1, y, ztop, drop=1.6, seed=1):
    """Giàn bông giấy rủ từ ban công."""
    rnd = random.Random(seed)
    for i in range(int((x1 - x0) * 26)):
        x = rnd.uniform(x0, x1); t = rnd.random() ** 1.6
        z = ztop - t * drop * (0.6 + .4 * math.sin(x * 3.1 + seed))
        ball(rnd.uniform(.06, .13), (x, y - rnd.uniform(.0, .25), z), M(C['boug'] if rnd.random() < .62 else (C['boug2'] if rnd.random() < .5 else C['leaf']), .85, sheen=.3), sub=1)

def sign_board(x, z, w, h, y, bg, fg, txt, sub=None, size=None):
    boxab((x - w / 2, y - .1, z - h / 2), (x + w / 2, y, z + h / 2), M(bg, .55), .02)
    boxab((x - w / 2 - .03, y - .11, z - h / 2 - .03), (x + w / 2 + .03, y - .085, z - h / 2 + .02), M(fg, .5), .005)
    size = size or h * .48
    text(txt, size, (x, y - .11, z + (h * .08 if sub else 0)), M(fg, .45), extrude=.01)
    if sub: text(sub, h * .2, (x, y - .11, z - h * .3), M(fg, .45), extrude=.008)

def awning(x0, x1, z, y, depth=1.1, stripes=('#D9553F', '#F1ECE2'), drop=.35):
    n = max(2, int((x1 - x0) / .35)); w = (x1 - x0) / n
    for i in range(n):
        mat = M(stripes[i % 2], .9, sheen=.6)
        V = [(x0 + i * w, y, z), (x0 + (i + 1) * w, y, z), (x0 + (i + 1) * w, y - depth, z - drop), (x0 + i * w, y - depth, z - drop)]
        o = mesh_obj('bat', V, [(0, 1, 2, 3)], mat); s_ = o.modifiers.new('S', 'SOLIDIFY'); s_.thickness = .01
        # diềm lượn
        Vv = [(x0 + i * w, y - depth, z - drop), (x0 + (i + 1) * w, y - depth, z - drop), (x0 + (i + .5) * w, y - depth, z - drop - .18)]
        o2 = mesh_obj('diem', Vv, [(0, 1, 2)], mat); s2 = o2.modifiers.new('S', 'SOLIDIFY'); s2.thickness = .01
    for sx in (x0, x1): boxab((sx - .015, y - depth - .015, z - drop - .02), (sx + .015, y, z - drop + .015), M(C['iron'], .5, .6), 0)

def rolling_shutter(x0, x1, z0, z1, y, open_frac=.6, col=None):
    col = col or C['shutter']
    zt = z1; zb = z0 + (z1 - z0) * open_frac
    o = corrugated(z1 - zb, x1 - x0, M(col, .55, .4), ((x0 + x1) / 2, y, (zt + zb) / 2), rot=(0, math.pi / 2, math.pi / 2), period=.07, amp=.01)
    boxab((x0 - .05, y - .25, z1), (x1 + .05, y + .05, z1 + .35), M(col, .55, .4), .02)  # hộp cuốn
    boxab((x0, y - .03, zb - .04), (x1, y + .03, zb), M(C['iron'], .5, .6), .005)
    for sx in (x0 - .04, x1 + .04): boxab((sx - .03, y - .04, z0), (sx + .03, y + .04, z1), M(C['iron'], .5, .6), .005)

def folding_gate(x0, x1, z0, z1, y):
    m = M(C['iron'], .5, .6)
    n = int((x1 - x0) / .14)
    for i in range(n + 1):
        x = x0 + i * (x1 - x0) / n
        boxab((x - .012, y - .012, z0), (x + .012, y + .012, z1), m, 0)
    for z in np.arange(z0 + .3, z1, .45):
        for i in range(n):
            xa = x0 + i * (x1 - x0) / n; xb = xa + (x1 - x0) / n
            curve([(xa, y - .015, z), (xb, y - .015, z + .2)], .008, m)
            curve([(xa, y - .015, z + .2), (xb, y - .015, z)], .008, m)

def interior_box(x0, x1, z0, z1, y, d=2.5, wall='#6D6152', floor='#9A8C78', back=True):
    if back: boxab((x0, y + d - .05, z0), (x1, y + d, z1), M(wall, .9), 0)
    boxab((x0, y, z0 - .02), (x1, y + d, z0 + .01), M(floor, .8), 0)
    boxab((x0, y, z1 - .02), (x1, y + d, z1), M('#5A5045', .9), 0)
    for sx in (x0, x1 - .05): boxab((sx, y, z0), (sx + .05, y + d, z1), M(wall, .9), 0)

def laundry(x0, x1, y, z, seed=3):
    rnd = random.Random(seed); m = M(C['steel'], .4, .7)
    cyl(.012, x1 - x0, ((x0 + x1) / 2, y, z), m, rot=(0, math.pi / 2, 0), bv=0)
    cols = ['#E9E2D2', '#C8412F', '#3A6EA5', '#F2B33D', '#7FB7A4', '#D7A9C4', '#FFFFFF']
    x = x0 + .15
    while x < x1 - .3:
        w = rnd.uniform(.25, .5); h = rnd.uniform(.35, .7)
        o = box((w, .015, h), (x + w / 2, y, z - h / 2 - .02), M(rnd.choice(cols), .95, sheen=.7), .004)
        o.rotation_euler = (rnd.uniform(-.08, .08), 0, rnd.uniform(-.1, .1)); x += w + rnd.uniform(.08, .2)

def water_tank(loc, horizontal=True):
    g = group('bon_nuoc', loc)
    with at(g):
        st = M(C['steel'], .3, .9)
        if horizontal:
            cyl(.5, 1.6, (0, 0, .7), st, rot=(0, math.pi / 2, 0), n=28, bv=.06)
            for sx in (-.55, .55): boxab((sx - .05, -.45, 0), (sx + .05, .45, .3), M(C['iron'], .5, .6), .01)
            for k in (-.4, 0, .4): torus(.5, .012, (k, 0, .7), st, rot=(0, math.pi / 2, 0), n=28, m=6)
        else:
            cyl(.45, 1.3, (0, 0, .85), st, n=28, bv=.06); ball(.45, (0, 0, 1.45), st, (1, 1, .35))
            boxab((-.5, -.5, 0), (.5, .5, .2), M(C['iron'], .5, .6), .01)
    return g

def antenna(loc):
    g = group('anten', loc)
    with at(g):
        m = M(C['steel'], .4, .8); cyl(.02, 2.0, (0, 0, 1.0), m, n=8, bv=0)
        for i, l in enumerate((1.2, 1.0, .8, .6)): cyl(.008, l, (0, 0, 1.4 + i * .18), m, rot=(0, math.pi / 2, .3), n=6, bv=0)
    return g

# ---------------------------------------------------------------- mái
def roof_flat(w, d, z, wall, tank=True, hut=True, seed=1):
    boxab((0, 0, z), (w, d, z + .15), M(C['concrete'], .9), .01)
    for (a, b) in [((0, 0), (w, .15)), ((0, d - .15), (w, d)), ((0, 0), (.15, d)), ((w - .15, 0), (w, d))]:
        boxab((a[0], a[1], z), (b[0], b[1], z + .9), M(wall, .85), .02)
        boxab((a[0] - .03, a[1] - .03, z + .9), (b[0] + .03, b[1] + .03, z + 1.0), M(C['white'], .8), .015)
    if hut:  # tum cầu thang
        boxab((w - 2.2, d - 2.6, z), (w - .15, d - .15, z + 2.5), M(wall, .85), .02)
        boxab((w - 2.35, d - 2.75, z + 2.5), (w - .05, d - .05, z + 2.65), M(C['concrete'], .9), .02)
        boxab((w - 1.6, d - 2.62, z + .1), (w - .8, d - 2.58, z + 2.1), M(C['wood'], .7), .01)
    if tank: water_tank((w - 1.2, d - 1.4, z + 2.65), horizontal=bool(seed % 2))
    laundry(.4, min(w - 2.4, 3.2), d * .45, z + 1.7, seed)
    for sx in (.3, w - 2.6): boxab((sx, d * .45 - .02, z), (sx + .04, d * .45 + .02, z + 1.75), M(C['steel'], .4, .7), 0)
    plant_pot((.6, .6, z + .15), kind='bush', s=.8)

def roof_ton(w, d, z, col=None, front_lip=.4):
    col = col or C['ton_blue']
    pitch = .12
    for i in range(3): boxab((0 if i == 0 else w * i / 2 - .05, -front_lip, z), (.1 if i == 0 else w * i / 2 + .05, d, z + .1), M(C['iron'], .5, .6), .005)
    ang = math.atan2(pitch * d, d)
    corrugated(w + .2, d + front_lip + .3, M(col, .45, .5), (w / 2, d / 2 - front_lip / 2, z + .25 + pitch * d / 2 * 0), rot=(-ang, 0, 0), period=.2, amp=.025)
    boxab((-.05, -front_lip - .1, z), (w + .05, -front_lip, z + .3), M(C['white'], .7), .01)

def roof_ngoi(w, d, z, ridge_h=1.6, col=None, along='x'):
    """Mái ngói hai mái, nóc chạy dọc mặt tiền."""
    col = col or C['tile']
    ov = .35; dy = d / 2 + ov; dz = ridge_h * dy / (d / 2); L = math.hypot(dy, dz)
    for sd in (-1, 1):
        a = math.atan2(-dz, sd * dy)
        cy = d / 2 + sd * dy / 2; cz = z + ridge_h - dz / 2
        corrugated(w + .5, L, M(col, .75), (w / 2, cy, cz + .03), rot=(a, 0, 0), period=.24, amp=.04, thick=.03)
    cyl(.12, w + .55, (w / 2, d / 2, z + ridge_h + .06), M(C['tile2'], .75), rot=(0, math.pi / 2, 0), n=16, bv=.01)
    for sx in (-.25, w + .25): ball(.16, (sx, d / 2, z + ridge_h + .1), M(C['tile2'], .75), (1, 1, .8))
    # tường hồi
    for sx in (0, w - .15):
        mesh_obj('hoi', [(sx, 0, z), (sx, d, z), (sx, d / 2, z + ridge_h), (sx + .15, 0, z), (sx + .15, d, z), (sx + .15, d / 2, z + ridge_h)],
                 [(0, 2, 1), (3, 4, 5), (0, 1, 4, 3), (1, 2, 5, 4), (2, 0, 3, 5)], M(C['cream'], .85))

def roof_pediment(w, z, wall, year='1968'):
    """Mặt tiền có trán tường kiểu phố cũ, che mái ngói phía sau."""
    boxab((0, -.05, z), (w, .25, z + .9), M(wall, .85), .03)
    mesh_obj('tran', [(w * .2, -.05, z + .9), (w * .8, -.05, z + .9), (w / 2, -.05, z + 1.6), (w * .2, .25, z + .9), (w * .8, .25, z + .9), (w / 2, .25, z + 1.6)],
             [(0, 2, 1), (3, 4, 5), (0, 1, 4, 3), (1, 2, 5, 4), (2, 0, 3, 5)], M(wall, .85))
    boxab((-.08, -.12, z + .85), (w + .08, .28, z + .95), M(C['white'], .8), .02)
    text(year, .28, (w / 2, -.07, z + 1.15), M(C['white'], .6), extrude=.01)

# ---------------------------------------------------------------- nhà ống
def nha_ong(name, loc, w=4.0, floors=3, depth=7.3, wall='mustard', ground='shutter', uppers=None, roof='flat', sign=None, awn=None, seed=1, rot=0.0,
            shop_d=None, back_door=None):
    """shop_d: tầng trệt rỗng sâu tới đó (tiệm đi vào được, vd. tạp hóa), mặc định chỉ sâu 2,7 m.
    back_door: (x0, x1, cao) cửa sau trổ qua tường sau tầng trệt khi có shop_d."""
    g = group(name, loc, rot); wallc = C.get(wall, wall)
    rnd = random.Random(seed)
    with at(g):
        G0 = 3.4; F = 3.1; H = G0 + F * (floors - 1)
        if shop_d is None:
            boxab((.12, 2.7, 0), (w - .12, depth, G0), M(wallc, .88), .02)                    # khối chính (trệt lùi sau gian hàng)
        elif back_door is None:
            boxab((.12, shop_d, 0), (w - .12, depth, G0), M(wallc, .88), .02)                 # tường sau tiệm
        else:
            dx0, dx1, dh = back_door
            boxab((.12, shop_d, 0), (dx0, depth, G0), M(wallc, .88), .02)
            boxab((dx1, shop_d, 0), (w - .12, depth, G0), M(wallc, .88), .02)
            boxab((dx0, shop_d, dh), (dx1, depth, G0), M(wallc, .88), .02)
        boxab((.12, .3, G0 - .32), (w - .12, depth, H), M(wallc, .88), .02)
        for sx in (0, w - .28): boxab((sx, 0, 0), (sx + .28, .45, H + .02), M(wallc, .88), .025)   # hai trụ
        # tầng trệt
        interior_box(.28, w - .28, 0, G0 - .3, .3, 2.4 if shop_d is None else shop_d - .3, back=shop_d is None)
        if ground == 'shutter': rolling_shutter(.35, w - .35, 0, G0 - .4, .2, open_frac=.62)
        elif ground == 'gate': folding_gate(.35, w - .35, 0, G0 - .4, .22)
        boxab((0, 0, G0 - .4), (w, .45, G0), M(wallc, .88), .02)
        boxab((.05, -.02, -.02), (w - .05, .5, .12), M(C['concrete2'], .9), .01)   # bậc thềm
        uppers = uppers or ['balcony'] * (floors - 1)
        for f in range(1, floors):
            z = G0 + F * (f - 1); kind = uppers[min(f - 1, len(uppers) - 1)]
            boxab((-.05, -.25, z - .1), (w + .05, .45, z + .1), M(C['white'], .8), .03)     # gờ sàn
            if kind == 'balcony':
                boxab((.05, -1.0, z - .05), (w - .05, .3, z + .1), M(C['concrete'], .9), .02)
                railing(.12, w - .12, -.95, z + .1, mat=M(C['iron'], .5, .6))
                for sx in (.12, w - .16): boxab((sx, -1.0, z + .1), (sx + .04, -.96, z + 1.1), M(C['iron'], .5, .6), 0)
                # cửa đi kiểu Pháp
                dw = min(2.4, w - 1.0)
                boxab((w / 2 - dw / 2 - .1, .28, z + .1), (w / 2 + dw / 2 + .1, .32, z + 2.4), M(C['white'], .7), .01)
                for k in range(4):
                    xk = w / 2 - dw / 2 + (k + .5) * dw / 4
                    boxab((xk - dw / 8 + .02, .25, z + .15), (xk + dw / 8 - .02, .29, z + 2.3), M(C['shutter'] if seed % 2 else '#6E8F5E', .6), .01)
                    for j in range(14): box((dw / 4 - .1, .03, .01), (xk, .24, z + .3 + j * .14), M('#1F2A2A', .7), 0, rot=(.6, 0, 0))
                if rnd.random() < .7: plant_pot((.45, -.65, z + .1), kind=rnd.choice(['bush', 'palm', 'boug']), s=.7)
                if rnd.random() < .5: plant_pot((w - .45, -.65, z + .1), kind='bush', s=.6)
                if rnd.random() < .6: ac_unit((w - .55, -.1 if False else .1, z + 2.55 - .02), 0)
            elif kind == 'window':
                louver_window(w / 2, z + .8, min(1.6, w - 1.2), 1.5, .3, wallc, C['shutter'] if seed % 2 else '#6E8F5E')
                if rnd.random() < .6: ac_unit((w - .7, .1, z + .6), 0)
            elif kind == 'cage':  # chuồng cọp
                louver_window(w / 2, z + .8, min(1.6, w - 1.2), 1.5, .3, wallc, C['shutter'])
                m = M(C['iron'], .5, .6); cw = min(2.0, w - .8)
                for xx in np.linspace(w / 2 - cw / 2, w / 2 + cw / 2, 12): boxab((xx - .012, -.5, z + .5), (xx + .012, -.47, z + 2.6), m, 0)
                for zz in (z + .5, z + 2.6): boxab((w / 2 - cw / 2, -.5, zz - .02), (w / 2 + cw / 2, .3, zz + .02), m, 0)
                for xx in (w / 2 - cw / 2, w / 2 + cw / 2): boxab((xx - .02, -.5, z + .5), (xx + .02, .3, z + .54), m, 0)
                plant_pot((w / 2 - .4, -.2, z + .5), kind='bush', s=.5)
        top = H
        if roof == 'flat': roof_flat(w, depth, top, wallc, seed=seed)
        elif roof == 'ton':
            boxab((0, 0, top), (w, .3, top + .5), M(wallc, .88), .02); roof_ton(w, depth, top + .5, C['ton_blue'] if seed % 2 else C['ton_red'])
        elif roof == 'ngoi':
            boxab((-.05, -.05, top), (w + .05, depth + .05, top + .25), M(C['white'], .8), .02); roof_ngoi(w, depth, top + .25)
        elif roof == 'pediment':
            roof_pediment(w, top, wallc); roof_ngoi(w, depth - .3, top + .3);
        if sign:
            sign_board(w / 2, G0 + .0 - .15 if not awn else G0 + .35, w - .5, .7, -.25 if roof != 'x' else 0, *sign)
        if awn: awning(.3, w - .3, G0 - .45, -.05, stripes=awn)
    return g

# ---------------------------------------------------------------- đồ đường phố
def xe_may(loc, rot=0.0, col='#C8412F', name='xe_may'):
    """Xe số kiểu Wave/Cub, dài 1,85 m."""
    g = group(name, loc, rot)
    with at(g):
        tire = M('#232323', .8); rim = M(C['steel'], .3, .9); body = M(col, .35, coat=.6); dark = M('#2A2A2A', .6)
        for x in (-.64, .62):
            torus(.25, .055, (x, 0, .3), tire, rot=(math.pi / 2, 0, 0), n=28, m=10)
            cyl(.18, .05, (x, 0, .3), rim, rot=(math.pi / 2, 0, 0), n=20, bv=.005)
            cyl(.05, .14, (x, 0, .3), rim, rot=(math.pi / 2, 0, 0), n=12, bv=.005)
        box((.5, .2, .1), (.62, 0, .6), body, .04, rot=(0, -.2, 0))                                    # chắn bùn trước
        box((.16, .16, .8), (.47, 0, .72), body, .06, rot=(0, -.42, 0))                                 # thân trước
        box((.75, .28, .32), (-.25, 0, .68), body, .12)                                                 # thân sau
        box((.68, .27, .1), (-.28, 0, .88), dark, .045)                                                 # yên
        box((.36, .2, .2), (-.02, 0, .44), M(C['steel'], .4, .7), .05)                                  # máy
        cyl(.035, .7, (-.35, .14, .32), M(C['steel'], .3, .9), rot=(0, math.pi / 2 - .1, 0), n=12)     # ống xả
        cyl(.018, .62, (.3, 0, 1.08), M(C['steel'], .3, .9), rot=(math.pi / 2, 0, 0), n=10, bv=0)     # ghi đông
        box((.18, .32, .14), (.34, 0, 1.06), body, .05)                                                 # đầu đèn
        ball(.07, (.43, 0, 1.06), M('#FFF2C0', .2, emit=.4), (1, 1.2, .8))
        for sd in (-1, 1):
            cyl(.006, .25, (.28, sd * .2, 1.2), dark, rot=(.2 * sd, 0, 0), n=6, bv=0); ball(.045, (.28, sd * .24, 1.33), M(C['steel'], .2, .9), (1, 1, .7))
        box((.3, .26, .05), (-.72, 0, .82), M(C['iron'], .5, .6), .01)                                  # baga
        box((.05, .2, .06), (-.77, 0, .7), M('#D23A2A', .4, emit=.3), .01)
    return g

def ghe_nhua(loc, col=None, rot=0.0, low=True):
    g = group('ghe', loc, rot); col = col or C['plastic_red']; h = .27 if low else .45
    with at(g):
        m = M(col, .45, coat=.3)
        box((.3, .3, .04), (0, 0, h), m, .015)
        for sx in (-1, 1):
            for sy in (-1, 1):
                cyl(.02, h, (sx * .12, sy * .12, h / 2), m, r2=.016, n=10, rot=(sy * .1, -sx * .1, 0), bv=0)
    return g

def ban_nhua(loc, col='#3A6EA5'):
    g = group('ban', loc)
    with at(g):
        m = M(col, .45, coat=.3); box((.6, .6, .04), (0, 0, .45), m, .02)
        for sx in (-1, 1):
            for sy in (-1, 1): cyl(.022, .45, (sx * .25, sy * .25, .225), m, n=10, bv=0)
    return g

def cot_dien(loc, h=8.5, wires_to=None, seed=1):
    g = group('cot_dien', loc)
    with at(g):
        cm = M(C['concrete'], .9); cyl(.14, h, (0, 0, h / 2), cm, r2=.09, n=8, bv=.01)
        for z, l in ((h - .4, 1.6), (h - 1.1, 1.2)):
            box((l, .1, .1), (0, 0, z), M(C['iron'], .5, .6), .01)
            for x in np.linspace(-l / 2 + .1, l / 2 - .1, 4): cyl(.03, .12, (x, 0, z + .1), M('#E8E2D0', .3), n=8, bv=.005)
        box((.5, .4, .7), (0, -.32, h - 2.6), M('#7E8B88', .5, .4), .03)                             # hộp biến thế
        cyl(.2, .6, (.0, .25, h - 2.0), M('#7E8B88', .5, .4), n=16)
        rnd = random.Random(seed); wm = M('#1E1E1E', .7)
        for i in range(9):  # bó dây rối quanh cột
            z = h - 3.2 + rnd.uniform(-.4, .4)
            pts = [(math.cos(a) * (.18 + rnd.uniform(0, .12)), math.sin(a) * (.18 + rnd.uniform(0, .12)), z + a * .05 + rnd.uniform(-.1, .1)) for a in np.linspace(0, 6.3 * 1.5, 14)]
            curve(pts, .012, wm)
        for i in range(4): box((.04, .2, .3), (0, -.16, 1.6 + i * .35), M(C['white'], .8), .005)   # tờ rơi dán cột
    return g

def wires(a, b, n=7, drop=1.2, seed=2):
    rnd = random.Random(seed); wm = M('#1E1E1E', .7)
    for i in range(n):
        da = np.array(a) + np.array([0, rnd.uniform(-.2, .2), rnd.uniform(-.8, .3)]); db = np.array(b) + np.array([0, rnd.uniform(-.2, .2), rnd.uniform(-.8, .3)])
        curve(sag(da, db, drop * rnd.uniform(.7, 1.3), 20, wob=.05, seed=i + seed), .012, wm)

def den_duong(loc, rot=0.0, h=6.5):
    g = group('den_duong', loc, rot)
    with at(g):
        m = M('#5E6B6B', .45, .6); cyl(.08, h, (0, 0, h / 2), m, r2=.05, n=12, bv=0)
        curve([(0, 0, h - .1), (0, -.4, h + .25), (0, -1.3, h + .3)], .04, m)
        box((.3, .55, .12), (0, -1.45, h + .25), m, .04); box((.24, .45, .03), (0, -1.45, h + .18), M('#FFF2C0', .2, emit=1.0), .01)
    return g

def bien_ten_duong(loc, txt='ĐƯỜNG LÒ BÁNH', rot=0.0):
    g = group('bien_duong', loc, rot)
    with at(g):
        cyl(.04, 2.9, (0, 0, 1.45), M(C['steel'], .4, .7), n=10, bv=0)
        box((1.3, .04, .32), (0, -.04, 2.75), M('#2457A0', .5), .02)
        text(txt, .14, (0, -.065, 2.75), M(C['white'], .5), extrude=.004)
        box((1.34, .03, .36), (0, -.02, 2.75), M(C['white'], .5), .02)
    return g

def thung_rac(loc, rot=0.0):
    g = group('thung_rac', loc, rot)
    with at(g):
        m = M('#3F7F4A', .55, coat=.2); box((.58, .72, .95), (0, 0, .55), m, .06)
        box((.62, .78, .06), (0, -.02, 1.05), M('#356E40', .5), .03)
        for sx in (-.22, .22): torus(.08, .03, (sx, .36, .1), M('#222222', .8), rot=(0, math.pi / 2, 0), n=16, m=8)
        text('RÁC', .14, (0, -.37, .7), M(C['white'], .5), extrude=.004)
    return g

def thung_hang(loc, s=.8, rot=0.0, kind='go'):
    g = group('thung', loc, rot)
    with at(g):
        if kind == 'go':
            m = M('#9B6A3A', .85); box((s, s, s), (0, 0, s / 2), M('#A8784A', .85), .02)
            for z in (.08, s - .08):
                for sy in (-1, 1): box((s + .02, .03, .1), (0, sy * s / 2, z), m, .005)
            box((s + .02, .03, .1), (0, -s / 2, s / 2), m, .005, rot=(0, .78, 0))
        else:  # thùng xốp
            box((s * .9, s * .6, s * .5), (0, 0, s * .25), M('#F4F2EC', .9), .02)
            box((s * .92, s * .62, .04), (0, 0, s * .52), M('#EAE7DE', .9), .015)
            text('TƯƠI', s * .1, (0, -s * .31, s * .25), M('#2457A0', .5), extrude=.003)
    return g

def cay_xanh(loc, h=5.5, seed=1):
    g = group('cay', loc)
    with at(g):
        rnd = random.Random(seed)
        cyl(.18, h * .55, (0, 0, h * .275), M('#7A5E46', .9), r2=.13, n=12)
        cyl(.185, 1.0, (0, 0, .5), M(C['white'], .9), n=12)
        boxab((-.6, -.6, 0), (.6, .6, .1), M(C['concrete2'], .9), .02)
        for i in range(12):
            a = rnd.uniform(0, 6.28); r = rnd.uniform(.3, 1.6)
            ball(rnd.uniform(.6, 1.1), (math.cos(a) * r, math.sin(a) * r, h * .62 + rnd.uniform(0, h * .3)), M(C['leaf'] if i % 2 else C['leaf2'], .85, sheen=.3), sub=2)
    return g

def tru_cuu_hoa(loc):
    g = group('cuu_hoa', loc)
    with at(g):
        m = M('#C8412F', .4, coat=.3); cyl(.12, .6, (0, 0, .3), m, n=16); ball(.12, (0, 0, .6), m, (1, 1, .7))
        for a in (0, math.pi / 2): cyl(.05, .38, (0, 0, .42), m, rot=(0, math.pi / 2, a), n=12)
        cyl(.18, .06, (0, 0, .03), m, n=16)
    return g

def binh_gas(loc, col='#C8412F'):
    g = group('gas', loc)
    with at(g):
        m = M(col, .4, coat=.3); cyl(.16, .5, (0, 0, .3), m, n=20, bv=.05); ball(.16, (0, 0, .55), m, (1, 1, .5))
        torus(.08, .015, (0, 0, .68), M(C['steel'], .3, .9), n=16, m=6); cyl(.17, .06, (0, 0, .03), M(C['iron'], .5, .6), n=20)
    return g

def long_chim(loc):
    g = group('long_chim', loc)
    with at(g):
        m = M('#C9A06A', .7); n = 18
        for i in range(n):
            a = 2 * math.pi * i / n; curve([(math.cos(a) * .18, math.sin(a) * .18, 0), (math.cos(a) * .18, math.sin(a) * .18, .38), (math.cos(a) * .06, math.sin(a) * .06, .5)], .005, m)
        cyl(.2, .04, (0, 0, 0), M('#8A5A30', .7), n=24); torus(.18, .01, (0, 0, .2), m, n=24, m=6)
        cyl(.004, .5, (0, 0, .75), M(C['iron'], .5, .6), n=6, bv=0); torus(.04, .006, (0, 0, 1.0), m, rot=(math.pi / 2, 0, 0), n=12, m=6)
        ball(.05, (0, 0, .14), M('#F2B33D', .6), (1, 1.4, 1)); ball(.03, (0, -.06, .19), M('#F2B33D', .6))
    return g

def den_long(loc, col='#C8412F'):
    g = group('den_long', loc)
    with at(g):
        ball(.22, (0, 0, 0), M(col, .6, emit=.3), (1, 1, .85)); cyl(.12, .05, (0, 0, .2), M(C['yellow'], .4, .6), n=16); cyl(.12, .05, (0, 0, -.2), M(C['yellow'], .4, .6), n=16)
        for i in range(6): cyl(.004, .25, (math.cos(i) * .03, math.sin(i) * .03, -.35), M(C['yellow'], .6), n=4, bv=0)
        cyl(.004, .6, (0, 0, .5), M(C['iron'], .5), n=4, bv=0)
    return g

def sap_bao(loc, rot=0.0):
    """Sạp báo Chú Tư: tủ gỗ, kệ báo kẹp, dù che, ghế."""
    g = group('sap_bao', loc, rot)
    with at(g):
        wm = M('#2E7C80', .6); wd = M('#8A5A30', .7)
        box((1.6, .7, .9), (0, 0, .45), wm, .03); box((1.7, .8, .05), (0, 0, .92), wd, .02)
        box((1.6, .08, 1.3), (0, .36, 1.6), wm, .02)                                          # bảng kẹp báo phía sau
        rnd = random.Random(4); cols = ['#EDE6D3', '#F2E3B8', '#E9C8A0', '#D9E3E8', '#F6D6D0', '#E6E0C8']
        for r_ in range(3):
            for k in range(5):
                box((.26, .02, .34), (-.6 + k * .3, .31, 1.15 + r_ * .4), M(rnd.choice(cols), .9), .004, rot=(0, rnd.uniform(-.05, .05), 0))
                box((.18, .021, .04), (-.6 + k * .3, .30, 1.26 + r_ * .4), M(rnd.choice(['#C8412F', '#2457A0', '#222222']), .7), 0)
        for k in range(6): box((.38, .3, .03), (-.6 + k * .24, -.05, .96 + (k % 2) * .02), M(rnd.choice(cols), .9), .004, rot=(0, 0, rnd.uniform(-.2, .2)))
        cyl(.025, 2.4, (.9, .1, 1.2), M(C['steel'], .4, .7), n=8, bv=0)
        for i in range(8):  # dù
            a0 = i * math.pi / 4; a1 = a0 + math.pi / 4
            mesh_obj('du', [(.9, .1, 2.55), (.9 + math.cos(a0) * 1.3, .1 + math.sin(a0) * 1.3, 2.15), (.9 + math.cos(a1) * 1.3, .1 + math.sin(a1) * 1.3, 2.15)], [(0, 1, 2)], M('#C8412F' if i % 2 else '#F1ECE2', .9, sheen=.6))
        text('BÁO', .22, (0, -.36, .5), M(C['white'], .5), extrude=.006)
    return g

def ban_co(loc, rot=0.0):
    """Bàn cờ tướng gỗ thấp + quân cờ."""
    g = group('ban_co', loc, rot)
    with at(g):
        box((.6, .6, .04), (0, 0, .38), M('#B07C46', .6), .01)
        for sx in (-1, 1):
            for sy in (-1, 1): box((.04, .04, .36), (sx * .25, sy * .25, .18), M('#8A5A30', .7), .005)
        box((.48, .52, .006), (0, 0, .403), M('#E8C98A', .6), .002)
        for i in range(9): box((.002, .45, .002), (-.2 + i * .05, 0, .407), M('#5A3A20', .6), 0)
        for j in range(10): box((.4, .002, .002), (0, -.225 + j * .05, .407), M('#5A3A20', .6), 0)
        rnd = random.Random(7)
        for side, colr in ((-1, '#C8412F'), (1, '#222222')):
            for k in range(11):
                x = rnd.choice(range(9)) * .05 - .2; y = side * (rnd.choice(range(1, 5)) * .05 + .0)
                cyl(.022, .016, (x, y, .418), M('#E8D9B5', .5), n=16, bv=.003); cyl(.016, .004, (x, y, .427), M(colr, .5), n=12, bv=0)
        box((.05, .07, .1), (.27, .2, .45), M('#E9E2D2', .5), .005)  # ly trà
    return g

def ke_tap_hoa(loc, rot=0.0, w=1.8, h=2.0, seed=5):
    g = group('ke', loc, rot)
    with at(g):
        m = M(C['steel'], .4, .7); rnd = random.Random(seed)
        for sx in (-w / 2, w / 2): box((.04, .45, h), (sx, 0, h / 2), m, .005)
        cols = ['#C8412F', '#F2B33D', '#3A6EA5', '#3F8A5C', '#E9E2D2', '#D7A9C4', '#E8913A', '#7A5236']
        for k in range(5):
            z = .1 + k * h / 5; box((w, .45, .025), (0, 0, z), m, .004)
            x = -w / 2 + .06
            while x < w / 2 - .12:
                kind = rnd.random(); cw = rnd.uniform(.08, .16); ch = rnd.uniform(.12, h / 5 - .08)
                if kind < .4: cyl(cw / 2, ch, (x + cw / 2, rnd.uniform(-.1, .1), z + ch / 2 + .015), M(rnd.choice(cols), .5), n=12, bv=.005)
                else: box((cw, .2, ch), (x + cw / 2, rnd.uniform(-.08, .08), z + ch / 2 + .015), M(rnd.choice(cols), .7), .005)
                x += cw + .015
    return g

def be_cau(loc, rot=0.0):
    """Cầu nâng xe ở tiệm sửa xe."""
    g = group('ban_nang', loc, rot)
    with at(g):
        box((2.0, .7, .1), (0, 0, .55), M('#C8412F', .5, .3), .02)
        for sx in (-.7, .7): box((.12, .5, .5), (sx, 0, .27), M(C['iron'], .5, .6), .01)
        box((2.2, .9, .05), (0, 0, .025), M(C['iron'], .5, .6), .01)
    return g

def lop_xe_chong(loc, n=4):
    g = group('lop', loc)
    with at(g):
        for i in range(n): torus(.24, .07, (0, 0, .07 + i * .14), M('#232323', .8), n=24, m=10)
    return g

def may_nen_khi(loc, rot=0.0):
    g = group('may_nen', loc, rot)
    with at(g):
        cyl(.22, .9, (0, 0, .3), M('#C8412F', .4, .3), rot=(0, math.pi / 2, 0), n=20, bv=.04)
        box((.4, .3, .3), (0, 0, .65), M('#3D3F40', .5), .03); cyl(.12, .06, (-.1, -.16, .65), M('#7E8B88', .4, .5), rot=(math.pi / 2, 0, 0), n=16)
        for sx in (-.35, .35): torus(.07, .025, (sx, .18, .07), M('#222222', .8), rot=(0, math.pi / 2, 0), n=12, m=6)
        curve([(.3, 0, .3), (.6, -.3, .1), (.9, -.2, .02), (1.3, .2, .02), (1.2, .5, .2)], .012, M('#E9B43D', .5))
    return g

def xe_ba_gac(loc, rot=0.0, load=True):
    """Xe ba gác máy: đầu xe máy + thùng chở 2,0 × 1,3 m. Gầm thùng cao 0,32 m: Bơ chui lọt, Chó Mực thì không."""
    g = group('ba_gac', loc, rot)
    with at(g):
        tire = M('#232323', .8); rim = M(C['steel'], .3, .9); body = M('#3A6EA5', .45, coat=.3); iron = M(C['iron'], .55, .6)
        wood = M(C['wood2'], .8)
        for (x, y) in ((1.55, 0), (-.55, -.62), (-.55, .62)):
            torus(.24, .055, (x, y, .29), tire, rot=(math.pi / 2, 0, 0), n=26, m=10)
            cyl(.16, .05, (x, y, .29), rim, rot=(math.pi / 2, 0, 0), n=18, bv=.005)
        cyl(.03, 1.36, (-.55, 0, .29), iron, rot=(math.pi / 2, 0, 0), n=10, bv=0)            # trục sau
        # khung + sàn thùng (mặt dưới ở 0,32 m)
        boxab((-1.35, -.68, .32), (.75, .68, .42), iron, .01)
        boxab((-1.33, -.66, .42), (.73, .66, .47), wood, .01)
        for y0, y1 in ((-.68, -.62), (.62, .68)): boxab((-1.35, y0, .47), (.75, y1, .82), body, .01)   # thành bên
        boxab((-1.35, -.68, .47), (-1.29, .68, .82), body, .01); boxab((.69, -.68, .47), (.75, .68, 1.1), body, .01)
        for x in (-1.0, -.5, 0, .45): boxab((x, -.7, .5), (x + .04, .7, .8), iron, .005)
        # cổ xe nối thùng với đầu xe
        box((.9, .14, .12), (1.15, 0, .48), iron, .02, rot=(0, -.15, 0))
        box((.16, .16, .7), (1.5, 0, .7), body, .05, rot=(0, -.35, 0))
        box((.5, .2, .1), (1.55, 0, .58), body, .04, rot=(0, -.2, 0))
        box((.6, .26, .1), (1.05, 0, .72), M('#2A2A2A', .6), .04)                              # yên
        cyl(.018, .64, (1.38, 0, 1.08), rim, rot=(math.pi / 2, 0, 0), n=10, bv=0)
        box((.18, .3, .14), (1.45, 0, 1.04), body, .05); ball(.065, (1.54, 0, 1.04), M('#FFF2C0', .2, emit=.4), (1, 1.2, .8))
        if load:
            for i, (x, y, z) in enumerate(((-1.0, -.3, .47), (-1.0, .3, .47), (-.45, -.3, .47), (-1.0, 0, .92))):
                box((.5, .55, .45), (x, y, .47 + .225 + (z - .47)), M('#F1EEE6', .9), .03)              # thùng xốp
            box((.6, .5, .25), (.2, .1, .6), M('#C9A26B', .85), .02)                                       # bao gạo
    return g

def o_cho(loc, rot=0.0):
    """Ổ Chó Mực: thùng gỗ cũ lật nghiêng, chiếu cói, chén nước inox, bảng tên."""
    g = group('o_cho', loc, rot)
    with at(g):
        wd = M('#9C6A40', .85); wd2 = M('#7E5232', .85)
        for i in range(5): boxab((-.5, -.45 + i * .18, 0), (.5, -.45 + i * .18 + .16, .05), wd if i % 2 else wd2, .01)
        for sx in (-1, 1):
            for i in range(4): boxab((sx * .5 - .03, -.45, .05 + i * .17), (sx * .5 + .03, .45, .05 + i * .17 + .15), wd if i % 2 else wd2, .01)
        for i in range(5): boxab((-.53, .42, .05 + i * .14), (.53, .48, .05 + i * .14 + .12), wd2 if i % 2 else wd, .01)
        for i in range(6): boxab((-.53 + i * .18, -.47, .73), (-.53 + i * .18 + .16, .48, .79), wd if i % 2 else wd2, .01)
        box((.82, .7, .02), (0, -.02, .06), M('#D8C38E', .95), .005)                            # chiếu cói
        cyl(.11, .06, (.62, -.62, .03), M(C['steel'], .25, .9), n=20, bv=.01)                   # chén nước
        box((.46, .03, .14), (0, -.49, .62), M('#E9E2D2', .6), .01)
        text('MỰC', .1, (0, -.51, .6), M(C['red'], .5), extrude=.004)
    return g
