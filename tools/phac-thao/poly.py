"""Bơ dựng theo quy trình 7 bước của ảnh tham khảo (lưới đa giác + subdivision, không SDF).
Toạ độ Blender: X phải, mèo nhìn về -Y, Z lên, đơn vị mét.
Dùng: python3 poly.py <outdir> [views] [--glb] [--steps]"""
import sys, math, bpy, bmesh, numpy as np
from mathutils import Vector, Matrix, Quaternion

OUT = sys.argv[1]
VIEWS = [x for x in (sys.argv[2].split(',') if len(sys.argv) > 2 else ['q34']) if x]
bpy.ops.wm.read_factory_settings(use_empty=True); sc = bpy.context.scene

def lin(h, a=1.0):
    h = h.lstrip('#'); c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= .04045 else ((x + .055) / 1.055) ** 2.4 for x in c) + (a,)

def new_obj(name, bm):
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me); sc.collection.objects.link(ob); return ob

def subsurf(ob, lv=2):
    m = ob.modifiers.new('Subdivision', 'SUBSURF'); m.levels = lv; m.render_levels = lv
    ob.data.polygons.foreach_set('use_smooth', [True] * len(ob.data.polygons))

def extrude(bm, faces, move, scale=1.0, axis_scale=None, rot=None):
    """Đùn một vùng mặt: dời theo move, co giãn quanh tâm vùng (bước 3, 4 trong ảnh)."""
    r = bmesh.ops.extrude_face_region(bm, geom=faces)
    verts = [e for e in r['geom'] if isinstance(e, bmesh.types.BMVert)]
    nf = [e for e in r['geom'] if isinstance(e, bmesh.types.BMFace)]
    bmesh.ops.delete(bm, geom=faces, context='FACES_ONLY') if False else None
    c = sum((v.co for v in verts), Vector()) / len(verts)
    for v in verts:
        d = v.co - c
        if rot is not None: d = rot @ d
        if axis_scale is not None: d = Vector((d.x * axis_scale[0], d.y * axis_scale[1], d.z * axis_scale[2]))
        else: d = d * scale
        v.co = c + d + Vector(move)
    return nf

def center(faces):
    vs = {v for f in faces for v in f.verts}; return sum((v.co for v in vs), Vector()) / len(vs)

# ---------- Bước 1 + 3: thân và chân (khối hộp chia 3x3, đùn chân, vuốt bằng loop cut) ----------
bm = bmesh.new()
bmesh.ops.create_cube(bm, size=1.0)
bmesh.ops.scale(bm, vec=(.26, .44, .26), verts=bm.verts)
bmesh.ops.translate(bm, vec=(0, .03, .24), verts=bm.verts)
bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=2, use_grid_fill=True)
bm.faces.ensure_lookup_table()
# bo tròn khối hộp thành hình trứng (như "elongated sphere" ở bước 1)
for v in bm.verts:
    p = v.co - Vector((0, .03, .24)); n = Vector((p.x / .13, p.y / .22, p.z / .13))
    if n.length > 0:
        k = 1 / max(abs(n.x), abs(n.y), abs(n.z)); s = n * k
        sph = s.normalized()
        v.co = Vector((0, .03, .24)) + Vector((sph.x * .135, sph.y * .23, sph.z * .125))
# ngực đầy hơn ở trước, lưng hơi võng
for v in bm.verts:
    if v.co.y < -.05: v.co.z += .02 * (-.05 - v.co.y) / .15; v.co.x *= 1.04
    if v.co.z > .33 and -.05 < v.co.y < .12: v.co.z -= .008

def pick(pred):
    bm.faces.ensure_lookup_table()
    return [f for f in bm.faces if pred(f.calc_center_median(), f.normal)]

legs = {
    'FL': dict(sx=-1, front=True), 'FR': dict(sx=1, front=True),
    'BL': dict(sx=-1, front=False), 'BR': dict(sx=1, front=False)}
for k, L in legs.items():
    ys = (-.2, -.03) if L['front'] else (.09, .27)
    fs = pick(lambda c, n: n.z < -.6 and c.x * L['sx'] > .03 and ys[0] < c.y < ys[1])
    if not fs: continue
    c0 = center(fs); x = L['sx'] * (.056 if L['front'] else .064); yb = -.1 if L['front'] else .15
    # gom vùng mặt về đúng chỗ đặt chân
    vs = {v for f in fs for v in f.verts}
    for v in vs: v.co.x += x - c0.x; v.co.y += yb - c0.y
    # nong vùng gốc chân cho đủ to (vai/đùi khoảng 7–8 cm)
    hw = max(abs(v.co.x - x) for v in vs) or 1; hl = max(abs(v.co.y - yb) for v in vs) or 1
    tw = .052 if L['front'] else .058; tl = .056 if L['front'] else .07
    for v in vs: v.co.x = x + (v.co.x - x) * tw / hw; v.co.y = yb + (v.co.y - yb) * tl / hl
    step = fs
    if L['front']:
        # vai -> khuỷu -> cổ tay -> bàn chân
        step = extrude(bm, step, (0, 0, -.07), .9)
        step = extrude(bm, step, (0, .005, -.07), .88)
        step = extrude(bm, step, (0, -.008, -.06), .94)
        step = extrude(bm, step, (0, -.022, -.03), 1.0, axis_scale=(1.15, 1.6, .55))
    else:
        # đùi to -> gối (đưa ra trước) -> gót (đưa ra sau) -> bàn chân
        step = extrude(bm, step, (0, -.01, -.06), 1.0)
        step = extrude(bm, step, (0, -.025, -.05), .8)
        step = extrude(bm, step, (0, .03, -.05), .88)
        step = extrude(bm, step, (0, -.012, -.055), .95)
        step = extrude(bm, step, (0, -.02, -.025), 1.0, axis_scale=(1.15, 1.6, .55))
# đặt bàn chân chạm sàn
for v in bm.verts:
    if v.co.z < .0: v.co.z = 0.0

# ---------- Bước 4: đuôi (đùn từ mặt sau theo đường cong, thon dần) ----------
tail3 = [(0, .27, -.2), (0, .25, -.285), (0, .29, -.35), (.012, .36, -.385), (.02, .42, -.375)]  # toạ độ three.js đã duyệt
T = [Vector((p[0], -p[2], p[1])) for p in tail3]
body = new_obj('Bo_Than', bm); subsurf(body, 2)

def catmull(P, n=10):
    P = [P[0] + (P[0] - P[1])] + P + [P[-1] + (P[-1] - P[-2])]; out = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for k in range(n):
            t = k / n
            out.append(.5 * (2 * p1 + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    return out + [P[-2]]
# ống trụ cong 8 cạnh chạy dọc đường cong đuôi, thon từ 3 cm xuống 2,2 cm, chóp bo tròn
C = catmull([T[0] + Vector((0, -.06, -.01))] + T); bm = bmesh.new(); rings = []; SEG = 8
for i, p in enumerate(C):
    d = (C[min(i + 1, len(C) - 1)] - C[max(i - 1, 0)]).normalized()
    t = i / (len(C) - 1); rr = .032 * (1 - t) + .022 * t
    if t > .93: rr *= math.sqrt(max(.05, 1 - ((t - .93) / .07) ** 2))
    q = Vector((0, 0, 1)).rotation_difference(d)
    rings.append([bm.verts.new(p + q @ Vector((math.cos(2 * math.pi * j / SEG), math.sin(2 * math.pi * j / SEG), 0)) * rr) for j in range(SEG)])
for a_, b_ in zip(rings, rings[1:]):
    for j in range(SEG): bm.faces.new((a_[j], a_[(j + 1) % SEG], b_[(j + 1) % SEG], b_[j]))
tipv = bm.verts.new(C[-1] + (C[-1] - C[-2]).normalized() * .008)
for j in range(SEG): bm.faces.new((rings[-1][j], rings[-1][(j + 1) % SEG], tipv))
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
tailo = new_obj('Bo_Duoi', bm); subsurf(tailo, 2)

# ---------- Bước 2: đầu (UV sphere, đùn tai, má, mõm bằng cầu co giãn) ----------
HC3 = (0, .43, .17); HC = Vector((HC3[0], -HC3[2], HC3[1]))
bm = bmesh.new()
bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=16, radius=1)
for v in bm.verts:
    v.co = Vector((v.co.x * .125, v.co.y * .118, v.co.z * .108))
    if v.co.z < -.02 and v.co.y < 0: v.co.x *= 1.0 + .25 * min(1, (-.02 - v.co.z) / .06)   # má phúng phía dưới
    if v.co.y < -.09: v.co.y += .01                                                        # mặt hơi phẳng
bmesh.ops.translate(bm, vec=HC, verts=bm.verts)
bm.faces.ensure_lookup_table()
for sx in (-1, 1):
    tgt = HC + Vector((sx * .075, .0, .085))
    fs = sorted(bm.faces, key=lambda f: (f.calc_center_median() - tgt).length)[:4]
    up = Vector((sx * .42, .06, .9)).normalized()
    s1 = extrude(bm, fs, tuple(up * .035), .85)
    s2 = extrude(bm, s1, tuple(up * .032), .55)
    s3 = extrude(bm, s2, tuple(up * .018), .25)
    # ép tai mỏng theo hướng nhìn của mặt
    for f in s1 + s2 + s3:
        for v in f.verts:
            cc = center(s1)
            v.co.y = cc.y + (v.co.y - cc.y) * .45
head = new_obj('Bo_Dau', bm); subsurf(head, 2)

def ellip(name, loc, r, seg=24):
    b = bmesh.new(); bmesh.ops.create_uvsphere(b, u_segments=seg, v_segments=seg // 2, radius=1)
    for v in b.verts: v.co = Vector((v.co.x * r[0], v.co.y * r[1], v.co.z * r[2])) + Vector(loc)
    o = new_obj(name, b); subsurf(o, 1); return o

def B3(p): return Vector((p[0], -p[2], p[1]))
muz = [ellip('Bo_Mom_T', B3((-.02, .385, .262)), (.028, .024, .022)),
       ellip('Bo_Mom_P', B3((.02, .385, .262)), (.028, .024, .022)),
       ellip('Bo_Cam', B3((0, .365, .25)), (.024, .02, .016))]
nose = ellip('Bo_Mui', B3((0, .405, .28)), (.013, .008, .009), 16)

# ---------- Bước 5: mắt to bóng ----------
def eye(sx):
    c = B3((sx * .05, .44, .256)); fwd = (c - HC); fwd = Vector((fwd.x / .125 ** 2, fwd.y / .118 ** 2, fwd.z / .108 ** 2)).normalized()
    fwd = (fwd + Vector((0, -.6, 0))).normalized()
    b = bmesh.new(); bmesh.ops.create_uvsphere(b, u_segments=96, v_segments=64, radius=1)
    o = new_obj(f'Bo_Mat_{"T" if sx < 0 else "P"}', b)
    up = Vector((0, 0, 1)); xr = up.cross(fwd).normalized(); zu = fwd.cross(xr).normalized()
    q = Matrix((xr, -fwd, zu)).transposed().to_quaternion()
    q = Quaternion(fwd, sx * .12) @ q
    o.location = c; o.rotation_mode = 'QUATERNION'; o.rotation_quaternion = q; o.scale = (.033, .017, .03)
    o.data.polygons.foreach_set('use_smooth', [True] * len(o.data.polygons))
    hl = []
    for off, rr in (((.35, .42), .22), ((-.3, -.35), .1)):
        b = bmesh.new(); bmesh.ops.create_uvsphere(b, u_segments=12, v_segments=8, radius=1)
        h = new_obj('Bo_Sang', b); h.location = c + q @ Vector((off[0] * .033, -.0165, off[1] * .03)); h.scale = (rr * .034,) * 3
        hl.append(h)
    return o, hl
eyes = [eye(-1), eye(1)]

# ---------- khăn đỏ (cuộn vải ôm cổ, nút thắt, 2 đuôi khăn) ----------
bpy.ops.mesh.primitive_torus_add(major_radius=.092, minor_radius=.024, major_segments=32, minor_segments=12)
scarf = bpy.context.active_object; scarf.name = 'Bo_Khan'
scarf.location = B3((0, .335, .13)); scarf.rotation_euler = (math.radians(-26), 0, 0); scarf.scale = (1.0, 1.0, 1.0)
subsurf(scarf, 1)
knot = ellip('Bo_Khan_Nut', B3((-.075, .31, .19)), (.03, .026, .026))
tails = []
for i, (dx, dz) in enumerate(((-.0, .0), (.018, -.01))):
    cu = bpy.data.curves.new(f'duoikhan{i}', 'CURVE'); cu.dimensions = '3D'; cu.bevel_depth = .013; cu.bevel_resolution = 4
    sp = cu.splines.new('BEZIER'); sp.bezier_points.add(2)
    pts = [(-.075 + dx, .3, .2 + dz), (-.085 + dx, .26, .21 + dz), (-.09 + dx, .22, .2 + dz)]
    for j, p in enumerate(pts):
        bp = sp.bezier_points[j]; bp.co = B3(p); bp.handle_left_type = bp.handle_right_type = 'AUTO'
    sp.bezier_points[0].radius = 1.0; sp.bezier_points[2].radius = 1.15
    o = bpy.data.objects.new('Bo_Duoi_Khan', cu); sc.collection.objects.link(o); tails.append(o)

# ---------- Bước 6: vật liệu pastel, tô màu theo vùng ----------
FUR, WHITE, PINK, STRIPE = '#F2A04E', '#FFF5E8', '#F4A3A8', '#D9772E'
def apply_and_paint(o, rule):
    bpy.context.view_layer.objects.active = o
    for m in list(o.modifiers): bpy.ops.object.modifier_apply(modifier=m.name)
    me = o.data; ca = me.color_attributes.new('Col', 'FLOAT_COLOR', 'POINT')
    V = np.array([(o.matrix_world @ v.co)[:] for v in me.vertices]); N = np.array([v.normal[:] for v in me.vertices])
    C = rule(V, N); ca.data.foreach_set('color', np.concatenate([C, np.ones((len(C), 1))], 1).astype(np.float32).ravel())
    me.polygons.foreach_set('use_smooth', [True] * len(me.polygons))

def ss(a, b, x): t = np.clip((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t)
L = lambda h: np.array(lin(h)[:3])
def mix(C, m, col): return C * (1 - m[:, None]) + L(col) * m[:, None]

def body_rule(V, N):
    x, y, z = V[:, 0], V[:, 1], V[:, 2]; C = np.tile(L(FUR), (len(V), 1))
    # vằn: dải ngang trên lưng/hông, vòng trên chân và đuôi
    back = ss(.1, .2, z) * ss(-.12, -.05, y) * ss(.27, .2, y) * ss(-.2, .3, N[:, 2])
    C = mix(C, ss(.45, .8, np.sin(y * 105 + 1)) * back, STRIPE)
    leg = ss(.17, .12, z) * ss(.05, .07, z) * ss(.3, .6, np.abs(N[:, 0]))
    C = mix(C, ss(.55, .85, np.sin(z * 120)) * leg * .85, STRIPE)
    tail = ss(.24, .27, y)
    C = mix(C, ss(.55, .85, np.sin((z + y * .5) * 75)) * tail, STRIPE)
    # trắng: ngực, bụng, bàn chân, chóp đuôi
    chest = ss(-.12, -.18, y) * ss(.36, .3, z) * ss(.08, .05, np.abs(x))
    belly = ss(-.1, -.5, N[:, 2]) * ss(.07, .1, z)
    paw = ss(.045, .03, z)
    tip = ss(.05, .03, np.linalg.norm(V - np.array(B3((.02, .42, -.375))[:]), axis=1))
    return mix(C, np.clip(np.maximum.reduce([chest, belly, paw, tip]), 0, 1), WHITE)

def head_rule(V, N):
    x, y, z = V[:, 0], V[:, 1], V[:, 2]; C = np.tile(L(FUR), (len(V), 1))
    hc = np.array(HC[:]); p = V - hc
    # 3 vạch trán + vạch má
    fore = ss(.05, .08, p[:, 2]) * ss(-.04, -.09, p[:, 1]) * ss(.045, .03, np.abs(p[:, 0]))
    C = mix(C, ss(.5, .85, np.cos(p[:, 0] * 190)) * fore, STRIPE)
    ck = ss(.08, .1, np.abs(p[:, 0])) * ss(-.03, -.01, p[:, 2]) * ss(.03, .01, p[:, 2]) * ss(0, -.04, p[:, 1])
    C = mix(C, ss(.55, .85, np.sin(p[:, 2] * 260 + 1.2)) * ck, STRIPE)
    # mảng trắng giữa mặt kiểu ảnh tham khảo (sống mũi + quanh mõm)
    blaze = ss(.03, .012, np.abs(p[:, 0]) - np.clip(-p[:, 2] * .9, 0, .05)) * ss(-.06, -.1, p[:, 1]) * ss(.05, .0, p[:, 2])
    lower = ss(-.02, -.05, p[:, 2]) * ss(-.04, -.09, p[:, 1])
    C = mix(C, np.clip(blaze + lower, 0, 1), WHITE)
    # trong tai hồng
    ell = np.sqrt((p[:, 0] / .125) ** 2 + (p[:, 1] / .118) ** 2 + (p[:, 2] / .108) ** 2)
    ear = ss(1.12, 1.3, ell) * ss(.1, .45, -N[:, 1]) * ss(.06, .08, p[:, 2])
    C = mix(C, ear, PINK)
    return C

apply_and_paint(body, body_rule); apply_and_paint(tailo, body_rule); apply_and_paint(head, head_rule)
for o in muz: apply_and_paint(o, lambda V, N: np.tile(L(WHITE), (len(V), 1)))
apply_and_paint(nose, lambda V, N: np.tile(L(PINK), (len(V), 1)))

def mat(name, attr=False, color=None, rough=.6, sheen=0., coat=0., emit=False):
    m = bpy.data.materials.new(name)
    if m.node_tree is None: m.use_nodes = True
    nt = m.node_tree; bs = nt.nodes['Principled BSDF']
    if emit:
        em = nt.nodes.new('ShaderNodeEmission'); em.inputs['Color'].default_value = lin(color)
        nt.links.new(em.outputs[0], nt.nodes['Material Output'].inputs['Surface']); return m
    if attr:
        a = nt.nodes.new('ShaderNodeVertexColor'); a.layer_name = 'Col'; nt.links.new(a.outputs['Color'], bs.inputs['Base Color'])
    else: bs.inputs['Base Color'].default_value = lin(color)
    bs.inputs['Roughness'].default_value = rough; bs.inputs['Sheen Weight'].default_value = sheen; bs.inputs['Coat Weight'].default_value = coat
    bs.inputs['Specular IOR Level'].default_value = .35
    return m
fur = mat('Long', attr=True, rough=.75, sheen=.6)
for o in [body, tailo, head] + muz + [nose]: o.data.materials.append(fur)
eyem = mat('Mat', color='#FFFFFF', rough=.04, coat=1.)
def eye_nodes(m):
    nt = m.node_tree; N_ = nt.nodes.new; Lk = nt.links.new
    tc = N_('ShaderNodeTexCoord'); sp = N_('ShaderNodeSeparateXYZ'); Lk(tc.outputs['Object'], sp.inputs[0])
    def M(op, a, b=None, v=None):
        n = N_('ShaderNodeMath'); n.operation = op
        for k, x in enumerate((a, b)):
            if x is None: continue
            if isinstance(x, (int, float)): n.inputs[k].default_value = x
            else: Lk(x, n.inputs[k])
        return n.outputs[0]
    X, Y, Z = sp.outputs
    r = M('SQRT', M('ADD', M('MULTIPLY', X, X), M('MULTIPLY', Z, Z)))
    ramp = N_('ShaderNodeValToRGB'); Lk(r, ramp.inputs[0]); el = ramp.color_ramp.elements
    el[0].position = .25; el[0].color = lin('#F7D35E'); el[1].position = .8; el[1].color = lin('#CC8E2C')
    for pos, col in ((.84, '#7A4A18'), (.96, '#7A4A18'), (.985, '#FFFFFF')):
        e = el.new(pos); e.color = lin(col)
    pup = M('LESS_THAN', M('ADD', M('POWER', M('DIVIDE', X, .2), 2.), M('POWER', M('DIVIDE', Z, .5), 2.)), 1.)
    pup = M('MULTIPLY', pup, M('LESS_THAN', Y, 0.))
    mx = N_('ShaderNodeMix'); mx.data_type = 'RGBA'; Lk(pup, mx.inputs['Factor']); Lk(ramp.outputs['Color'], mx.inputs[6])
    mx.inputs[7].default_value = lin('#1A0F0A'); Lk(mx.outputs[2], nt.nodes['Principled BSDF'].inputs['Base Color'])
eye_nodes(eyem)
for o, hl in eyes:
    o.data.materials.append(eyem)
    for h in hl: h.data.materials.append(mat('Sang', color='#FFFFFF', emit=True))
red = mat('Khan', color='#C8412F', rough=.9, sheen=1.)
for o in [scarf, knot] + tails: o.data.materials.append(red)
wh = mat('Ria', color='#F4EEE2', rough=.4)
for sx in (-1, 1):
    for i, dz in enumerate((.008, 0, -.008)):
        cu = bpy.data.curves.new('ria', 'CURVE'); cu.dimensions = '3D'; cu.bevel_depth = .0007
        sp = cu.splines.new('POLY'); sp.points.add(1)
        sp.points[0].co = (*B3((sx * .035, .385 + dz, .272)), 1); sp.points[1].co = (*B3((sx * .15, .39 + dz * 2.2, .24)), 1)
        o = bpy.data.objects.new('Bo_Ria', cu); sc.collection.objects.link(o); cu.materials.append(wh)

# ---------- Bước 7: đèn 3 điểm + camera + Eevee ----------
bpy.ops.mesh.primitive_plane_add(size=400); fl = bpy.context.active_object
fl.data.materials.append(mat('San', color='#8CBFB4', rough=1))
w = bpy.data.worlds.new('W'); sc.world = w
if w.node_tree is None: w.use_nodes = True
w.node_tree.nodes['Background'].inputs['Color'].default_value = lin('#9CCBC1'); w.node_tree.nodes['Background'].inputs['Strength'].default_value = .55
def light(name, kind, loc, power, size=1., color=(1, 1, 1)):
    l = bpy.data.lights.new(name, kind); l.energy = power; l.color = color
    if kind == 'AREA': l.size = size
    if kind == 'SUN': l.angle = .25
    o = bpy.data.objects.new(name, l); sc.collection.objects.link(o); o.location = loc
    o.rotation_euler = (Vector((0, 0, .25)) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
light('Key', 'SUN', (1.2, -1.2, 2.0), 1.7, color=(1, .97, .92))
light('Fill', 'AREA', (-1.5, -.8, .9), 60, 2.0, (.9, .95, 1))
light('Rim', 'AREA', (-.3, 1.6, 1.2), 90, 1.0)
sc.render.engine = 'BLENDER_EEVEE'
try: sc.eevee.taa_render_samples = 32
except Exception: pass
sc.render.resolution_x = 900; sc.render.resolution_y = 720; sc.view_settings.view_transform = 'Standard'
cd = bpy.data.cameras.new('Cam'); cam = bpy.data.objects.new('Cam', cd); sc.collection.objects.link(cam); sc.camera = cam; cd.clip_end = 1000
VD = {'q34': ((.95, -1.15, .6), None, 55, (0, 0, .27)), 'side': ((1.6, 0, .3), .98, 0, (0, 0, .27)),
      'front': ((0, -1.6, .3), .98, 0, (0, 0, .27)), 'face': ((.12, -.75, .45), None, 80, (0, -.2, .43)),
      'wire': ((.95, -1.15, .6), None, 55, (0, 0, .27))}
for vn in VIEWS:
    loc, ortho, lens, tgt = VD[vn]
    cam.location = loc; cam.rotation_euler = (Vector(tgt) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    if ortho: cd.type = 'ORTHO'; cd.ortho_scale = ortho
    else: cd.type = 'PERSP'; cd.lens = lens
    sc.render.filepath = f'{OUT}/poly_{vn}.png'; bpy.ops.render.render(write_still=True); print('rendered', vn)
if '--glb' in sys.argv:
    fl.hide_set(True)
    # glTF không mang node thủ tục: chép màu mắt ra màu đỉnh (cùng công thức với eye_nodes)
    for o, _ in eyes:
        me = o.data; ca = me.color_attributes.new('Col', 'FLOAT_COLOR', 'POINT'); cols = []
        st = [(.25, '#F7D35E'), (.8, '#CC8E2C'), (.84, '#7A4A18'), (.96, '#7A4A18'), (.985, '#FFFFFF')]
        for vt in me.vertices:
            X, Y, Z = vt.co; r = math.hypot(X, Z)
            if Y < 0 and (X / .2) ** 2 + (Z / .5) ** 2 < 1: cc = lin('#1A0F0A')[:3]
            else:
                cc = lin(st[-1][1])[:3]
                for (p0, c0), (p1, c1) in zip(st, st[1:]):
                    if r <= p0: cc = lin(c0)[:3]; break
                    if r <= p1:
                        t = (r - p0) / (p1 - p0); a, b_ = lin(c0), lin(c1); cc = tuple(a[i] * (1 - t) + b_[i] * t for i in range(3)); break
            cols.extend(cc + (1,))
        ca.data.foreach_set('color', cols)
    for o in sc.objects: o.select_set(o.type in ('MESH', 'CURVE') and o is not fl)
    bpy.ops.export_scene.gltf(filepath=f'{OUT}/poly.glb', use_selection=True, export_apply=True, export_vertex_color='ACTIVE')
    bpy.ops.wm.save_as_mainfile(filepath=f'{OUT}/poly.blend'); print('glb done')
