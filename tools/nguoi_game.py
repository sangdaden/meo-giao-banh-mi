"""Người dân khu phố vào game: model nhẹ + bộ xương người 19 xương + animation, xuất .glb cho Godot.

Chạy:  python3 tools/nguoi_game.py <id,...|all> assets/models/nguoi [--ban=nhe|dong]
       (--ban: bản ít tam giác cho người chợ / đám đông, xem BAN)
Soát:  xvfb-run godot --path . --rendering-driver opengl3 -s tools/chup_nguoi.gd -- <thư mục ảnh> [id,...] [anim,...]
Cần:   pip install bpy numpy scikit-image   (Blender chạy headless; bản đang dùng: bpy 5.2)

Hình người lấy thẳng từ tools/khu_pho/nguoi.py (bản phác "Khu phố Lò Bánh" Sang duyệt 21/10),
dựng bằng SDF + marching cubes ở dáng A, không vẽ lại. Script này làm phần còn lại:
1. Giảm lưới còn ~3k tam giác (giữ dày quanh mặt cho miệng, mí mắt), mắt và kính dựng lại ít đỉnh.
2. Gộp thành một mesh, 3 vật liệu: Than (màu đỉnh), Mat (tròng mắt bóng), Sang (đốm sáng trong mắt).
3. Bộ xương 19 xương chung cho mọi người: hips, spine, chest, neck, head,
   clav/upperarm/forearm/hand (L, R), thigh/shin/foot (L, R).
   Trọng số tính theo bộ phận SDF gần nhất (đầu theo đầu, tay theo tay...) rồi chia mềm theo
   khoảng cách tới xương, nên khớp gập không bị kéo da sang chân kia hay sang thân.
4. Animation dựng bằng keyframe trong Blender (30 khung/giây), tất cả tính từ một bộ tư thế chung
   nên ai cũng cử động cùng kiểu nhưng mỗi người một dáng (người già chậm, trẻ con nhún nhảy).
   Tư thế nhận bánh lấy đúng từ GIAO trong nguoi.py.
"""
import sys
import os
import math
import json

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'khu_pho'))
import numpy as np
import nguoi as N
import nguoi3 as N3  # 7 người Thứ Ba (CHARS) và dáng DANG (trang "Chợ sáng Thứ Ba" Sang duyệt 21/10)
import nguoi4 as N4  # 5 người mặc áo mưa Thứ Tư (*_mua, trang G5 Sang duyệt 22/10)
import nguoi5  # noqa: F401  Chị Thu + dáng Bé Na mở cửa (trang G1 Sang duyệt 22/10), đăng ký vào N.CHARS và N3.DANG
import nguoi6  # noqa: F401  dáng Thứ Năm ngoài phố: Chú Tư ngủ gật, Anh Hùng nằm võng, Chị Mây thả giỏ (G1 bản 2)
import nguoi7  # noqa: F401  đám giỗ Bà Sáu: 6 người mới + 3 dáng Bà Sáu (trang G7 Sang duyệt 22/10)
import nguoi_p3  # người qua đường: 8 người + đổi đồ, áo mưa, nón đi xe (gói P3 Sang duyệt 22/10)
import nguoi9  # noqa: F401  Thứ Bảy: dáng chụp ảnh chung + việc nhờ, Chị Thảo không mũ (trang G9 Sang duyệt 22/10)
from sdflib import v, hexc
import bpy
from mathutils import Vector, Matrix, Quaternion

FPS = 30
FWD = Vector((0, -1, 0))   # Blender: mặt người nhìn về -Y
UP = Vector((0, 0, 1))
LEFT = Vector((1, 0, 0))   # bên trái của người (xương .L)

# ---------------------------------------------------------------- vai diễn từng người
# base: dáng nền ('dung' đứng | 'ngoi' ngồi), seat: chiều cao mặt ghế (m),
# tempo: nhịp cử động (người già chậm, trẻ con nhanh), giao: animation nhận bánh riêng.
ROLES = {
    'coba':   dict(base='dung', tempo=1.0, energy=1.0),
    'chutu':  dict(base='ngoi', seat=.45, tempo=.9, energy=.8, giao='chutu'),
    'bena':   dict(base='dung', tempo=1.25, energy=1.3, giao='bena'),
    'may':    dict(base='dung', tempo=1.05, energy=1.0, giao='may'),
    'hung':   dict(base='ngoi', seat=.28, tempo=1.0, energy=1.1, giao='hung'),
    'basau':  dict(base='ngoi', seat=.42, tempo=.75, energy=.7, giao='basau'),
    # Hai ông ngồi ghế đá 0,32 m (hông ở 0,38 như DANG), Ông Tám tay trái cầm quạt mo
    'ongbay': dict(base='ngoi', seat=.30, tempo=.8, energy=.7),
    'ongtam': dict(base='ngoi', seat=.30, tempo=.8, energy=.8, fan='L'),
    'cohai':  dict(base='dung', tempo=1.0, energy=1.0),
    'chunam': dict(base='ngoi', seat=.45, tempo=.9, energy=.9),
    # Người Thứ Ba (nguoi3.py)
    'xemco':    dict(base='dung', tempo=.8, energy=.8),
    'bancho':   dict(base='ngoi', seat=.18, tempo=1.0, energy=1.0),
    'hangrong': dict(base='dung', tempo=1.0, energy=.9),
    'ganhhang': dict(base='dung', tempo=1.05, energy=1.0),
    'dicho1':   dict(base='dung', tempo=.8, energy=.8),
    'dicho2':   dict(base='dung', tempo=1.1, energy=1.1),
    'dicho3':   dict(base='dung', tempo=1.0, energy=1.0),
    # 5 người chợ thêm (nguoi3.py cho4-cho8, Sang duyệt 21/10 17:07)
    'cho4': dict(base='dung', tempo=1.0, energy=1.0),            # Cô Năm bán hàng đứng
    'cho5': dict(base='dung', tempo=1.25, energy=1.2),           # Bé Thư
    'cho6': dict(base='dung', tempo=.75, energy=.7),             # Ông Út
    'cho7': dict(base='dung', tempo=1.05, energy=1.0),           # Chị Mai
    'cho8': dict(base='ngoi', seat=.32, tempo=.9, energy=.9),    # Chú Tám ngồi ghế đẩu (hông 0,4 như DANG)
    # Chị Thảo khách xe ôm: ngồi yên sau xe Chú Năm (hông 0,95), xuống xe thì đứng
    'khachxeom': dict(base='dung', tempo=1.0, energy=1.0),
    'khachxeom_tb': dict(base='dung', tempo=1.0, energy=1.0),  # Thứ Bảy, không mũ (nguoi9.py)
    # Chị Thu, mẹ em bé căn 3B-4 (nguoi5.py, G1)
    'chithu': dict(base='dung', tempo=.95, energy=.9),
    # Đám giỗ nhà Bà Sáu (nguoi7.py, G7): Ông Mười ngồi ghế đẩu 0,26 m ăn cỗ
    'thanh': dict(base='dung', tempo=.95, energy=.9),
    'loan':  dict(base='dung', tempo=1.0, energy=1.0),
    'muoi':  dict(base='ngoi', seat=.26, tempo=.75, energy=.7),
    'hanh':  dict(base='dung', tempo=1.05, energy=1.0),
    'bin':   dict(base='dung', tempo=1.3, energy=1.4),
    'mit':   dict(base='dung', tempo=1.25, energy=1.2),
    # Người mặc áo mưa Thứ Tư (nguoi4.py): động tác theo người gốc (N4 'base'), cộng dáng riêng ở MUA
    'may_mua':    dict(base='dung', tempo=1.05, energy=1.0, giao='may'),
    'cohai_mua':  dict(base='dung', tempo=1.0, energy=1.0),
    'bena_mua':   dict(base='dung', tempo=1.25, energy=1.3, giao='bena'),
    'chunam_mua': dict(base='ngoi', seat=.45, tempo=.9, energy=.9),
    'chutu_mua':  dict(base='dung', tempo=.9, energy=.8, giao='chutu'),  # đứng dọn bạt, khác ngày thường ngồi
}

# Người qua đường P3 (nguoi_p3.py): ai cũng đứng; bản đổi đồ, áo mưa, đi xe (base=...) cử động như người gốc
_P3 = {'qd_ongtd': (.8, .8), 'qd_vanphong': (1.05, 1.0), 'qd_hocsinh': (1.25, 1.3), 'qd_sinhvien': (1.0, 1.0),
       'qd_veso': (.8, .8), 'qd_giaohang': (1.05, 1.0), 'qd_congnhan': (.95, .9), 'qd_mehoa': (1.0, 1.0)}
for _id in nguoi_p3.IDS:
    _tp, _en = _P3[N.CHARS[_id].get('base', _id)]
    ROLES[_id] = dict(base='dung', tempo=_tp, energy=_en)

# Bản dựng: '' đủ chi tiết (~3,8k tam giác, người gần camera); 'nhe' ~1,4k cho người chợ, phố đông;
# 'dong' ~600 cho đám đông xa (không đốm sáng mắt, mắt chỉ là chấm tối). Xuất <id>_nhe.glb / <id>_dong.glb.
# body: số mặt sau khi giảm lưới; mat, sang: (segments, rings) cầu mắt và đốm sáng (None = không có);
# giu_mat: giữ lưới dày quanh mặt khi giảm.
BAN = {
    '':     dict(body=2950, mat=(16, 10), sang=(8, 5), giu_mat=True),
    'nhe':  dict(body=1100, mat=(10, 6), sang=(6, 4), giu_mat=True),
    'dong': dict(body=500, mat=(6, 4), sang=None, giu_mat=False),
}
Q = BAN['']
# Người ở chợ sáng Thứ Ba: ai cũng có 'va' (bị Bơ va) và 'di_bo' (người bán đi khỏi khi dọn sạp)
CHO = {'xemco', 'bancho', 'hangrong', 'ganhhang', 'dicho1', 'dicho2', 'dicho3', 'cho4', 'cho5', 'cho6', 'cho7', 'cho8'}

HEAD_PARTS = {'head', 'brow', 'hair', 'tie', 'must', 'goatee', 'cap', 'helmet', 'earring', 'nonla', 'quai'}
ARM_PARTS = {'delt', 'arm', 'sleeve', 'hand', 'towel'}
LEG_PARTS = {'leg', 'calf', 'pant', 'foot', 'sole', 'strap'}
UPPER_PARTS = {'chest', 'belly'}
LOWER_PARTS = {'pelvis', 'hem', 'apron', 'apronband', 'pocket', 'pack', 'packstrap', 'skirt'}


def B(p):
    """three.js (Y lên, nhìn +Z) sang Blender (Z lên, nhìn -Y)."""
    return Vector((float(p[0]), float(-p[2]), float(p[1])))


def joints(G):
    s = G['s']
    J = {}
    J['hips'] = G['Pu'] * v(1, .86, 1)
    J['spine'] = G['Pu'] + v(0, .08, 0) * s
    J['chest'] = v(0, 1.12, 0) * s
    J['neck'] = v(0, 1.2, -.01) * s
    J['head'] = G['Ph']
    J['head_top'] = G['head_c'] + v(0, G['head_r'][1], 0)
    for sd, nm in ((1, 'L'), (-1, 'R')):
        sh, el, wr, _ = G['arms'][sd]
        J['clav.' + nm] = v(sd * .05, 1.18, .0) * s
        J['upperarm.' + nm] = sh
        J['forearm.' + nm] = el
        J['hand.' + nm] = wr
        J['fingers.' + nm] = wr + N.nrm(wr - el) * .1 * s
        hp, kn, an = G['legs'][sd]
        J['thigh.' + nm] = hp
        J['shin.' + nm] = kn
        J['foot.' + nm] = an
        J['toe.' + nm] = an + v(0, -.05, .12) * s
    return J


def bone_table(J):
    t = [('hips', 'hips', 'spine', None), ('spine', 'spine', 'chest', 'hips'), ('chest', 'chest', 'neck', 'spine'),
         ('neck', 'neck', 'head', 'chest'), ('head', 'head', 'head_top', 'neck')]
    for nm in 'LR':
        t += [('clav.' + nm, 'clav.' + nm, 'upperarm.' + nm, 'chest'),
              ('upperarm.' + nm, 'upperarm.' + nm, 'forearm.' + nm, 'clav.' + nm),
              ('forearm.' + nm, 'forearm.' + nm, 'hand.' + nm, 'upperarm.' + nm),
              ('hand.' + nm, 'hand.' + nm, 'fingers.' + nm, 'forearm.' + nm),
              ('thigh.' + nm, 'thigh.' + nm, 'shin.' + nm, 'hips'),
              ('shin.' + nm, 'shin.' + nm, 'foot.' + nm, 'thigh.' + nm),
              ('foot.' + nm, 'foot.' + nm, 'toe.' + nm, 'shin.' + nm)]
    return [(n, J[a], J[b], p) for n, a, b, p in t]


COAT_PARTS = ('aomua', 'aomua2', 'taimeo')
PONCHO = False  # build_person đặt theo coat_kind của người đang dựng


def allowed_bones(part, x):
    sd = 'L' if x > 0 else 'R'
    if part in HEAD_PARTS:
        return ['head']
    if part == 'neck':
        return ['neck', 'head', 'chest']
    if part in ('trap', 'collar'):
        return ['chest', 'neck', 'clav.L', 'clav.R']
    if part in ARM_PARTS:
        extra = ['chest'] if part in ('delt', 'towel') else []
        return ['clav.' + sd, 'upperarm.' + sd, 'forearm.' + sd, 'hand.' + sd] + extra
    if part in LEG_PARTS:
        return ['thigh.' + sd, 'shin.' + sd, 'foot.' + sd, 'hips']
    if part in UPPER_PARTS:
        return ['chest', 'spine', 'hips']
    if part in LOWER_PARTS:
        return ['hips', 'spine', 'thigh.L', 'thigh.R']
    return ['hips', 'spine', 'chest']


def seg_dist(P, a, b):
    ba = b - a
    t = np.clip(((P - a) @ ba) / (ba @ ba), 0, 1)
    return np.linalg.norm(P - (a + t[:, None] * ba), axis=1)


def skin_weights(P3, parts, FR, bones):
    """P3: đỉnh theo toạ độ three.js. Trả list dict {xương: trọng số}."""
    body = [p for p in parts if not p['sep']]
    D = np.stack([p['fn'](FR[p['frame']](P3)) for p in body], 1)
    near = D.argmin(1)
    # Áo mưa (nguoi4.py) bọc ngoài: đỉnh áo theo bộ phận nằm dưới nó (tay áo theo tay, mũ trùm theo đầu).
    # Thân áo cánh dơi phủ tới gối thì theo hông và hai đùi, không tách theo từng chân.
    coat = np.array([p['name'] in COAT_PARTS for p in body])
    if coat.any():
        under = np.where(coat[None, :], np.inf, D).argmin(1)
        near = np.where(coat[near], under, near)
        in_coat = coat[D.argmin(1)]
    else:
        in_coat = np.zeros(len(P3), bool)
    seg = {n: (np.asarray(a, np.float32), np.asarray(b, np.float32)) for n, a, b, _ in bones}
    dist = {n: seg_dist(P3, a, b) for n, (a, b) in seg.items()}
    out = []
    sigma = .018
    for i in range(len(P3)):
        names = allowed_bones(body[near[i]]['name'], P3[i, 0])
        if in_coat[i] and PONCHO and body[near[i]]['name'] in LEG_PARTS:
            names = ['hips', 'spine', 'thigh.L', 'thigh.R']
        ds = np.array([dist[n][i] for n in names])
        w = np.exp(-(ds - ds.min()) / sigma)
        order = np.argsort(-w)[:3]
        w = {names[k]: float(w[k]) for k in order if w[k] > .04}
        tot = sum(w.values())
        out.append({k: x / tot for k, x in w.items()})
    return out


# ---------------------------------------------------------------- dựng model
def lin4(h, a=1.0):
    cc = N.lin(hexc(h))
    return (float(cc[0]), float(cc[1]), float(cc[2]), a)


def new_mat(name, color=None):
    m = bpy.data.materials.new(name)
    if m.node_tree is None:
        m.use_nodes = True
    nt = m.node_tree
    bs = nt.nodes['Principled BSDF']
    a = nt.nodes.new('ShaderNodeVertexColor')
    a.layer_name = 'Col'
    nt.links.new(a.outputs['Color'], bs.inputs['Base Color'])
    bs.inputs['Roughness'].default_value = .8
    if name == 'Mat':
        bs.inputs['Roughness'].default_value = .1
        bs.inputs['Coat Weight'].default_value = 1
    return m


def paint(ob, rgba):
    ca = ob.data.color_attributes.new('Col', 'FLOAT_COLOR', 'POINT')
    ca.data.foreach_set('color', list(rgba) * len(ob.data.vertices))


def build_person(cid):
    global PONCHO
    c = N.CHARS[cid]
    PONCHO = c.get('coat_kind') == 'poncho'
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scn = bpy.context.scene
    scn.render.fps = FPS
    M_THAN, M_MAT, M_SANG = new_mat('Than'), new_mat('Mat'), new_mat('Sang')
    parts, G, FR, headw = N.build(c, False)
    H = .003 * (.8 if c.get('kid') else 1.0)
    field, axes = N.make_field(parts, G, FR, False, H)
    V, F, Nn = N.mesh(field, axes, H)
    col, mats = N.colorize(c, parts, G, FR, V, Nn, False)
    me = bpy.data.meshes.new(cid)
    Vb = np.stack([V[:, 0], -V[:, 2], V[:, 1]], 1)
    me.vertices.add(len(Vb))
    me.vertices.foreach_set('co', Vb.ravel())
    me.loops.add(F.size)
    me.loops.foreach_set('vertex_index', F.ravel())
    me.polygons.add(len(F))
    me.polygons.foreach_set('loop_start', np.arange(0, F.size, 3))
    me.update()
    me.validate()
    ca = me.color_attributes.new('Col', 'FLOAT_COLOR', 'POINT')
    ca.data.foreach_set('color', np.concatenate([N.lin(col), np.ones((len(col), 1))], 1).astype(np.float32).ravel())
    me.materials.append(M_THAN)
    me.polygons.foreach_set('use_smooth', [True] * len(me.polygons))
    body = bpy.data.objects.new(cid, me)
    scn.collection.objects.link(body)
    bpy.context.view_layer.objects.active = body
    md = body.modifiers.new('Smooth', 'SMOOTH')
    md.factor = .5
    md.iterations = 7
    bpy.ops.object.modifier_apply(modifier=md.name)
    # Giảm lưới còn ~3,2k tam giác, chừa ~1/3 cho mặt: miệng cười, viền mí, má hồng là màu đỉnh,
    # giảm đều thì mặt mất miệng. Trọng số nhóm 0,45 (thử 0,3 / 0,5 / 1): 1 thì giữ nguyên mặt, nát thân.
    hc = B(G['head_c'])
    hr = G['head_r']
    keep = body.vertex_groups.new(name='giu_mat')
    for vt in body.data.vertices:
        d = vt.co - hc
        if -d.y / hr[2] > .3 and d.length < hr[1] * 1.1:
            keep.add([vt.index], .45, 'REPLACE')
    md = body.modifiers.new('Dec', 'DECIMATE')
    glasses = any(e in c.get('extras', []) for e in ('glasses', 'glasses_round'))
    md.ratio = (Q['body'] - (150 if glasses else 0)) / len(body.data.polygons)
    if Q['giu_mat']:
        md.vertex_group = 'giu_mat'
        md.vertex_group_factor = 1.0
        md.invert_vertex_group = True
    bpy.ops.object.modifier_apply(modifier=md.name)
    body.vertex_groups.remove(body.vertex_groups['giu_mat'])
    hr = G['head_r']
    extras = []
    # Mắt: tròng mắt màu đỉnh + 2 đốm sáng, ít đỉnh hơn bản phác
    Rt = G['Ru'] @ G['Rh']
    er = G['er']
    for i, sd in enumerate((-1, 1)):
        e_ = G['eyes'][i]
        nv = N.nrm((e_ - G['head_c']) / hr ** 2)
        cw = headw(e_)
        fwd = B(Rt @ nv).normalized()
        upB = B(Rt @ v(0, 1, 0))
        xr = upB.cross(fwd).normalized()
        zu = fwd.cross(xr).normalized()
        q = Quaternion(fwd, sd * .14) @ Matrix((xr, -fwd, zu)).transposed().to_quaternion()
        bpy.ops.mesh.primitive_uv_sphere_add(segments=Q['mat'][0], ring_count=Q['mat'][1], radius=1, location=B(cw))
        o = bpy.context.active_object
        o.scale = (er[0], er[2], er[1])
        o.rotation_euler = q.to_euler()
        ca = o.data.color_attributes.new('Col', 'FLOAT_COLOR', 'POINT')
        cols = []
        ic = c['eye']
        for vt in o.data.vertices:
            p = vt.co.normalized()
            f = -p.y
            rr = math.hypot(p.x, p.z)
            if f < .15:
                cc = lin4('#FBF8F2')
            elif rr < .36:
                cc = lin4('#140C08')
            elif rr < .8:
                t_ = max(0, (rr - .36) / .44)
                a_, b_ = lin4(ic[0]), lin4(ic[1])
                cc = tuple(a_[j] * (1 - t_) + b_[j] * t_ for j in range(3)) + (1,)
            else:
                cc = lin4('#2E1A10')
            cols.extend(cc)
        ca.data.foreach_set('color', cols)
        o.data.materials.append(M_MAT)
        extras.append(o)
        loc = B(cw)
        up = q @ Vector((0, 0, 1))
        rt = q @ Vector((1, 0, 0))
        for off, rad in (((.32, .3), .2), ((-.28, -.22), .12)) if Q['sang'] else ():
            bpy.ops.mesh.primitive_uv_sphere_add(segments=Q['sang'][0], ring_count=Q['sang'][1], radius=er[0] * rad,
                                                 location=loc + fwd * er[2] * .95 + up * er[1] * off[0] + rt * er[0] * off[1])
            h_ = bpy.context.active_object
            h_.data.materials.append(M_SANG)
            paint(h_, (1, 1, 1, 1))
            extras.append(h_)
    # Kính
    if any(e in c.get('extras', []) for e in ('glasses', 'glasses_round')):
        gcol = lin4('#3A2A20' if 'glasses' in c['extras'] else '#B8963E')
        M = Matrix([list(map(float, r)) for r in Rt])
        conv = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
        Mb = conv @ M @ conv.inverted()
        for i in range(2):
            e_ = G['eyes'][i] + v(0, 0, er[2] * 1.6)
            bpy.ops.mesh.primitive_torus_add(major_radius=er[0] * 1.35, minor_radius=.0035 * G['s'],
                                             major_segments=14, minor_segments=4, location=B(headw(e_)))
            t = bpy.context.active_object
            t.scale = (1, 1, .82 if 'glasses' in c['extras'] else 1)
            t.rotation_euler = (Mb @ Matrix.Rotation(math.pi / 2, 3, 'X')).to_euler()
            t.data.materials.append(M_THAN)
            paint(t, gcol)
            extras.append(t)
        a_ = headw(G['eyes'][0] + v(er[0] * 1.3, er[1] * .2, er[2] * 1.6))
        b_ = headw(G['eyes'][1] + v(-er[0] * 1.3, er[1] * .2, er[2] * 1.6))
        bpy.ops.mesh.primitive_cylinder_add(vertices=5, radius=.003 * G['s'], depth=float(np.linalg.norm(a_ - b_)), location=B((a_ + b_) / 2))
        br = bpy.context.active_object
        br.rotation_euler = (B(b_) - B(a_)).to_track_quat('Z', 'Y').to_euler()
        br.data.materials.append(M_THAN)
        paint(br, gcol)
        extras.append(br)
    # Quạt mo cầm tay (Ông Tám): nan quạt hình quạt bán kính 0,19 m quanh hướng bàn tay, cán gỗ
    hand_extras = []
    fan_side = ROLES.get(cid, {}).get('fan')
    if fan_side:
        sd = 1 if fan_side == 'L' else -1
        _, el, wr, _ = G['arms'][sd]
        s = G['s']
        d = N.nrm(wr - el)
        lat = N.nrm(np.cross(d, v(0, 0, 1)))
        c0 = wr + d * .06 * s
        pts = [c0] + [c0 + (d * math.cos(a) + lat * math.sin(a)) * .19 * s for a in np.linspace(-1, 1, 9)]
        me_f = bpy.data.meshes.new('quat')
        me_f.from_pydata([B(p) for p in pts], [], [(0, k, k + 1) for k in range(1, 9)])
        fo = bpy.data.objects.new('quat', me_f)
        scn.collection.objects.link(fo)
        bpy.context.view_layer.objects.active = fo
        sm = fo.modifiers.new('Day', 'SOLIDIFY')
        sm.thickness = .005 * s
        bpy.ops.object.modifier_apply(modifier=sm.name)
        fo.data.materials.append(M_THAN)
        paint(fo, lin4('#D8B47A'))
        a_, b_ = wr - d * .03 * s, wr + d * .08 * s
        bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=.008 * s, depth=float(np.linalg.norm(b_ - a_)), location=B((a_ + b_) / 2))
        hd = bpy.context.active_object
        hd.rotation_euler = (B(b_) - B(a_)).to_track_quat('Z', 'Y').to_euler()
        hd.data.materials.append(M_THAN)
        paint(hd, lin4('#8A5A30'))
        hand_extras = [(fo, 'hand.' + fan_side), (hd, 'hand.' + fan_side)]
    for o in extras + [h[0] for h in hand_extras]:
        bpy.context.view_layer.objects.active = o
        for oo in scn.objects:
            oo.select_set(oo is o)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # ---- bộ xương
    J = joints(G)
    bones = bone_table(J)
    arm_data = bpy.data.armatures.new('NguoiRig')
    arm = bpy.data.objects.new('NguoiRig', arm_data)
    scn.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    for oo in scn.objects:
        oo.select_set(oo is arm)
    bpy.ops.object.mode_set(mode='EDIT')
    for name, a, b, parent in bones:
        eb = arm_data.edit_bones.new(name)
        eb.head, eb.tail = B(a), B(b)
        d = (eb.tail - eb.head).normalized()
        eb.align_roll(UP if abs(d.z) < .7 else FWD * (1 if d.z > 0 else -1))
        if parent:
            eb.parent = arm_data.edit_bones[parent]
            eb.use_connect = False
    bpy.ops.object.mode_set(mode='OBJECT')

    # ---- trọng số
    P3 = np.array([(vt.co.x, vt.co.z, -vt.co.y) for vt in body.data.vertices], np.float32)
    W = skin_weights(P3, parts, FR, bones)
    groups = {n: body.vertex_groups.new(name=n) for n, *_ in bones}
    for i, w in enumerate(W):
        for n, x in w.items():
            groups[n].add([i], x, 'REPLACE')
    for o in extras:
        o.vertex_groups.new(name='head').add(list(range(len(o.data.vertices))), 1.0, 'REPLACE')
    for o, bn in hand_extras:
        o.vertex_groups.new(name=bn).add(list(range(len(o.data.vertices))), 1.0, 'REPLACE')
    for oo in scn.objects:
        oo.select_set(oo.type == 'MESH')
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    body.name = 'Nguoi_' + cid
    body.data.color_attributes.active_color = body.data.color_attributes['Col']
    body.parent = arm
    am = body.modifiers.new('Rig', 'ARMATURE')
    am.object = arm
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    print(cid, 'tris', tris)
    return dict(c=c, G=G, J=J, arm=arm, body=body, tris=tris)


# ---------------------------------------------------------------- tư thế và animation
def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def mix(a, b, k):
    """Trộn hai tư thế: Rig.solve giải từng tư thế rồi nội suy cầu (slerp) từng xương."""
    if k <= 0:
        return a
    if k >= 1:
        return b
    return {'__mix__': (a, b, k)}


def add(*poses):
    """Cộng dồn các lớp (kênh góc cộng lại, aim/pos lấy lớp sau cùng có giá trị)."""
    out = {}
    for p in poses:
        for bn, ch in p.items():
            if bn == '__mix__':
                out[bn] = ch
                continue
            o = out.setdefault(bn, {})
            if ch.get('aim') is not None:
                # Lớp sau đặt hướng hẳn cho xương: bỏ góc lớp trước, chỉ giữ góc của chính lớp này
                for key in ('fw', 'up', 'out', 'tw'):
                    o.pop(key, None)
            for key, val in ch.items():
                if key in ('aim', 'aim_ref'):
                    o[key] = val
                elif key == 'pos':
                    pv = o.get('pos', (0, 0, 0))
                    o['pos'] = tuple(pv[i] + val[i] for i in range(3))
                else:
                    o[key] = o.get(key, 0.0) + val
    return out


def both(name, **ch):
    return {name + '.L': dict(ch), name + '.R': dict(ch)}


class Rig:
    def __init__(self, info):
        self.arm = info['arm']
        self.J = info['J']
        self.G = info['G']
        bones = self.arm.data.bones
        self.order = [b.name for b in bones]  # cha luôn đứng trước con
        self.rest = {b.name: b.matrix_local.to_quaternion() for b in bones}
        self.dir = {b.name: (b.tail_local - b.head_local).normalized() for b in bones}
        self.head = {b.name: b.head_local.copy() for b in bones}
        self.parent = {b.name: (b.parent.name if b.parent else None) for b in bones}
        self.length = {b.name: b.length for b in bones}

    def _axis(self, bn, key):
        d = self.dir[bn]
        sd = -1 if bn.endswith('.R') else 1
        if key == 'fw':
            t = FWD
        elif key == 'up':
            t = UP
        elif key == 'out':
            t = LEFT * sd
        else:
            return d
        ax = d.cross(t)
        if ax.length < .25:
            return None
        return ax.normalized()

    def _local(self, pose):
        """Góc xoay từng xương so với tư thế nghỉ (trong khung armature) và độ dời hông.
        Kênh fw/up/out/tw cộng lên trên aim hoặc lên tư thế trộn (__mix__)."""
        mixed = None
        if '__mix__' in pose:
            pa, pb, k = pose['__mix__']
            la, lb = self._local(pa), self._local(pb)
            mixed = {bn: (la[bn][0].slerp(lb[bn][0], k), la[bn][1].lerp(lb[bn][1], k)) for bn in self.order}
        acc = {}
        res = {}
        for bn in self.order:
            ch = pose.get(bn, {})
            par = self.parent[bn]
            A_p = acc[par] if par else Quaternion()
            sd = -1 if bn.endswith('.R') else 1
            E0, off = mixed[bn] if mixed else (Quaternion(), Vector())
            if ch.get('aim') is not None:
                ax, ay, az = ch['aim']  # trái, lên, trước (theo người)
                tgt = (LEFT * ax * sd + UP * ay + FWD * az).normalized()
                ref = ch.get('aim_ref') or 'world'
                A_ref = acc.get(ref, Quaternion()) if ref != 'world' else Quaternion()
                t_p = A_p.inverted() @ (A_ref @ tgt)
                E0 = self.dir[bn].rotation_difference(t_p)
            Ec = Quaternion()
            for key in ('fw', 'up', 'out'):
                ang = ch.get(key, 0.0)
                if ang:
                    axis = self._axis(bn, key)
                    if axis is not None:
                        Ec = Quaternion(axis, math.radians(ang)) @ Ec
            tw = ch.get('tw', 0.0)
            if tw:
                Ec = Quaternion(self.dir[bn], math.radians(tw * sd)) @ Ec
            E = E0 @ Ec
            acc[bn] = A_p @ E
            if 'pos' in ch:
                px, py, pz = ch['pos']
                off = off + LEFT * px + UP * py + FWD * pz
            res[bn] = (E, off)
        return res

    def solve(self, pose):
        """pose: xương -> {fw, up, out, tw (độ), aim (hướng trái/lên/trước theo khung aim_ref), pos (trái, lên, trước)}.
        Trả {xương: (quaternion basis, location basis)}."""
        res = {}
        for bn, (E, off) in self._local(pose).items():
            R = self.rest[bn]
            res[bn] = (R.inverted() @ E @ R, R.inverted() @ off)
        return res

    # Ngồi: hạ hông xuống mặt ghế, đùi gần ngang, cẳng chân xuống đất (tính hình học, không đoán)
    def sit_pose(self, seat, spread=.0, knee_fwd=0.0):
        hipY = self.head['thigh.L'].z
        s = self.G['s']
        hip_y = seat + .085 * s
        drop = hipY - hip_y
        Lt = (self.head['shin.L'] - self.head['thigh.L']).length
        Ls = (self.head['foot.L'] - self.head['shin.L']).length
        ank = self.head['foot.L'].z
        knee_y = min(ank + Ls * math.cos(math.radians(8)), hip_y + Lt * .5)
        ca = max(-1, min(1, (hip_y - knee_y) / Lt))
        a = math.degrees(math.acos(ca))  # góc đùi so với phương thẳng xuống
        hz = math.sin(math.radians(a)) * Lt
        drop2 = knee_y - ank
        b = math.degrees(math.acos(max(-1, min(1, drop2 / Ls)))) if drop2 < Ls else 0.0
        p = {'hips': {'pos': (0, -drop, -.06 * s)}}
        for sd in 'LR':
            p['thigh.' + sd] = {'aim': (spread, -math.cos(math.radians(a)), math.sin(math.radians(a))), 'aim_ref': 'world'}
            p['shin.' + sd] = {'aim': (spread * .3, -math.cos(math.radians(b)), math.sin(math.radians(b)) + knee_fwd), 'aim_ref': 'world'}
            p['foot.' + sd] = {'aim': (0, -.25, 1), 'aim_ref': 'world'}
        return p

    def keyframe(self, name, frames, fn, loop=True):
        """fn(t giây) -> pose. Ghi từng khung vào action mới, đẩy vào NLA track cùng tên."""
        arm = self.arm
        arm.animation_data_create()
        act = bpy.data.actions.new(name)
        arm.animation_data.action = act
        pbs = arm.pose.bones
        for pb in pbs:
            pb.rotation_mode = 'QUATERNION'
        prev = {}
        n = frames + (1 if loop else 0)
        for f in range(n):
            t = (f % frames if loop and f == frames else f) / FPS
            if loop and f == frames:
                t = 0.0
            sol = self.solve(fn(t))
            for bn, (q, loc) in sol.items():
                pb = pbs[bn]
                if bn in prev and prev[bn].dot(q) < 0:
                    q = -q
                prev[bn] = q
                pb.rotation_quaternion = q
                pb.keyframe_insert('rotation_quaternion', frame=f + 1)
                if bn == 'hips':
                    pb.location = loc
                    pb.keyframe_insert('location', frame=f + 1)
        track = arm.animation_data.nla_tracks.new()
        track.name = name
        st = track.strips.new(name, 1, act)
        st.name = name
        arm.animation_data.action = None
        for pb in pbs:
            pb.rotation_quaternion = Quaternion()
            pb.location = Vector()
        return act

    def keyframe_world(self, name, keys):
        """keys: [(khung, dáng)], dáng = [(xương, trục thế giới 'X'/'Y'/'Z', độ)], cha trước con, xoay quanh gốc xương.
        Cách dựng dáng của trang phác thảo G6 (scripts/g6.py) để giữ đúng dáng Sang đã duyệt. Đẩy vào NLA track cùng tên."""
        arm = self.arm
        arm.animation_data_create()
        act = bpy.data.actions.new(name)
        arm.animation_data.action = act
        pbs = arm.pose.bones
        vl = bpy.context.view_layer

        def clear():
            for pb in pbs:
                pb.rotation_mode = 'QUATERNION'
                pb.rotation_quaternion = Quaternion()
                pb.location = Vector()
            vl.update()

        for f, spec in keys:
            clear()
            for bn, ax, deg in spec:
                pb = pbs[bn]
                mw = arm.matrix_world @ pb.matrix
                head = mw.to_translation()
                rm = Matrix.Translation(head) @ Matrix.Rotation(math.radians(deg), 4, ax) @ Matrix.Translation(-head)
                pb.matrix = arm.matrix_world.inverted() @ rm @ mw
                vl.update()
            for pb in pbs:
                pb.keyframe_insert('rotation_quaternion', frame=f)
                if pb.name == 'hips':
                    pb.keyframe_insert('location', frame=f)
        track = arm.animation_data.nla_tracks.new()
        track.name = name
        st = track.strips.new(name, 1, act)
        st.name = name
        arm.animation_data.action = None
        clear()
        return act


# ---------------------------------------------------------------- thư viện cử động
def osc(t, period, phase=0.0):
    return math.sin(2 * math.pi * (t / period + phase))


def stand_base(t, R, role):
    """Đứng yên mà vẫn sống: thở, dồn trọng tâm qua lại, đầu nhìn quanh, tay thả lỏng."""
    e = role['energy']
    tp = role['tempo']
    old = R.c.get('old')
    sway = osc(t, 4.0 / tp) * e
    br = osc(t, 3.3 / tp)
    look = osc(t, 6.0 / tp, .2) * 14 * e + osc(t, 2.7 / tp, .6) * 4
    p = {
        'hips': {'out': sway * 1.6, 'tw': sway * 2.5, 'pos': (sway * .012, abs(sway) * -.004, 0), 'fw': 1.5 if old else 0},
        'spine': {'out': -sway * 1.2, 'fw': br * .8 + (6 if old else 1)},
        'chest': {'fw': br * 1.6 - 1.5, 'out': -sway * .6, 'tw': look * .15},
        'neck': {'fw': 2 + br * .6 + (6 if old else 0), 'tw': look * .3},
        'head': {'fw': -1 + osc(t, 5.1 / tp, .4) * 3, 'tw': look * .55, 'out': osc(t, 7 / tp) * 3},
        'clav.L': {'up': br * 1.2}, 'clav.R': {'up': br * 1.2},
        'upperarm.L': {'out': -6 + sway * 1.5, 'fw': 4 + br * 1.5, 'tw': 8},
        'upperarm.R': {'out': -6 - sway * 1.5, 'fw': 4 + br * 1.5, 'tw': 8},
        'forearm.L': {'fw': 14 + br * 2}, 'forearm.R': {'fw': 14 + br * 2},
        'hand.L': {'fw': 6, 'tw': 10}, 'hand.R': {'fw': 6, 'tw': 10},
        # chân: gối hơi chùng bên dồn trọng tâm
        'thigh.L': {'fw': 2 + max(0, -sway) * 3, 'out': 1}, 'thigh.R': {'fw': 2 + max(0, sway) * 3, 'out': 1},
        'shin.L': {'fw': -3 - max(0, -sway) * 6}, 'shin.R': {'fw': -3 - max(0, sway) * 6},
        'foot.L': {'up': 1 + max(0, -sway) * 3}, 'foot.R': {'up': 1 + max(0, sway) * 3},
    }
    return p


def sit_base(t, R, role):
    e = role['energy']
    tp = role['tempo']
    old = R.c.get('old')
    br = osc(t, 3.6 / tp)
    look = osc(t, 6.5 / tp, .2) * 16 * e + osc(t, 2.9 / tp, .5) * 4
    p = R.sit_pose(role['seat'], spread=.12)
    p = add(p, {
        'hips': {'fw': 6},
        'spine': {'fw': 6 + br * .8 + (8 if old else 0)},
        'chest': {'fw': br * 1.5, 'tw': look * .15},
        'neck': {'fw': (4 if old else 0) + br * .5, 'tw': look * .3},
        'head': {'fw': -6 + osc(t, 5.3 / tp, .3) * 3, 'tw': look * .55, 'out': osc(t, 7.2 / tp) * 3},
        'clav.L': {'up': br * 1.2}, 'clav.R': {'up': br * 1.2},
        # tay đặt trên đùi
        'upperarm.L': {'fw': 22, 'out': -4, 'tw': 10}, 'upperarm.R': {'fw': 22, 'out': -4, 'tw': 10},
        'forearm.L': {'fw': 52 + br * 2, 'tw': 30}, 'forearm.R': {'fw': 52 + br * 2, 'tw': 30},
        'hand.L': {'fw': -8}, 'hand.R': {'fw': -8},
    })
    return p


def base(t, R, role):
    return sit_base(t, R, role) if role['base'] == 'ngoi' else stand_base(t, R, role)


def anim_idle(R, role):
    return lambda t: base(t, R, role)


def anim_talk(R, role):
    """Nói chuyện: gật gù theo câu, tay phải khoa nhẹ, nhướng người."""
    tp = role['tempo']

    def f(t):
        talk = osc(t, .55 / tp) * .5 + osc(t, 1.3 / tp, .3) * .5
        g = osc(t, 2.4 / tp)
        return add(base(t, R, role), {
            'chest': {'fw': talk * 2, 'tw': g * 5},
            'neck': {'fw': talk * 3},
            'head': {'fw': talk * 5, 'out': g * 4, 'tw': g * 6},
            'upperarm.R': {'fw': 18 + g * 8, 'out': 6},
            'forearm.R': {'fw': 50 + talk * 14, 'tw': -40 + g * 20},
            'hand.R': {'fw': -10 + talk * 10, 'up': 10},
            'upperarm.L': {'fw': 6 + max(0, -g) * 10},
            'forearm.L': {'fw': 20 + max(0, -g) * 30},
        })
    return f


def anim_wave(R, role):
    """Vẫy tay chào Bơ: giơ tay phải, cổ tay vẫy, người nghiêng theo."""
    tp = role['tempo']

    def f(t):
        up = smooth(t / .35)
        w = osc(t, .42 / tp)
        return add(base(t, R, role), {
            'chest': {'out': -4 * up, 'tw': -6 * up},
            'head': {'out': 6 * up, 'fw': -4 * up},
            'clav.R': {'up': 14 * up},
            'upperarm.R': {'out': 70 * up, 'fw': 25 * up + w * 4 * up},
            'forearm.R': {'fw': 70 * up + w * 6 * up, 'tw': -30 * up},
            'hand.R': {'out': w * 28 * up, 'fw': -10 * up},
        })
    return f


def anim_happy(R, role):
    """Vui: nhún người, hai tay đưa lên, đầu lắc lư (trẻ con nhảy cẫng)."""
    tp = role['tempo']
    e = role['energy']
    sit = role['base'] == 'ngoi'

    def f(t):
        b = abs(osc(t, .9 / tp)) * e
        sw = osc(t, 1.8 / tp)
        p = {
            'hips': {'pos': (0, b * (.0 if sit else .035 if R.c.get('kid') else .015), 0)},
            'chest': {'fw': -6 * b, 'out': sw * 4},
            'neck': {'fw': -4},
            'head': {'fw': -8 + b * 4, 'out': sw * 8},
            'clav.L': {'up': 10 * b}, 'clav.R': {'up': 10 * b},
            'upperarm.L': {'aim': (.75, .35 + .3 * b, .35), 'aim_ref': 'world'},
            'upperarm.R': {'aim': (.75, .35 + .3 * b, .35), 'aim_ref': 'world'},
            'forearm.L': {'aim': (.25 + sw * .15, 1, .2), 'aim_ref': 'world'},
            'forearm.R': {'aim': (.25 - sw * .15, 1, .2), 'aim_ref': 'world'},
            'hand.L': {'out': sw * 20}, 'hand.R': {'out': -sw * 20},
        }
        if not sit:
            p.update({'thigh.L': {'fw': 6 * (1 - b)}, 'thigh.R': {'fw': 6 * (1 - b)},
                      'shin.L': {'fw': -12 * (1 - b)}, 'shin.R': {'fw': -12 * (1 - b)},
                      'foot.L': {'up': 6 * (1 - b)}, 'foot.R': {'up': 6 * (1 - b)}})
        return add(base(t, R, role), p)
    return f


def anim_impatient(R, role):
    """Sốt ruột: chống nạnh, gõ chân (đứng) hoặc gõ ngón tay lên đùi (ngồi), ngó ra đường."""
    tp = role['tempo']
    sit = role['base'] == 'ngoi'

    def f(t):
        tap = max(0.0, osc(t, .5 / tp))
        look = osc(t, 3.2 / tp)
        p = {
            'chest': {'tw': look * 8, 'fw': -2},
            'neck': {'tw': look * 10},
            'head': {'tw': look * 18, 'fw': -3, 'out': -look * 4},
        }
        if sit:
            p.update({'hand.R': {'fw': -20 + tap * 25}, 'upperarm.L': {'fw': 10, 'out': 20}, 'forearm.L': {'fw': 70}})
        else:
            p.update({
                'upperarm.L': {'out': 40, 'fw': -10, 'tw': 30}, 'forearm.L': {'fw': 95, 'tw': 20}, 'hand.L': {'fw': -20},
                'upperarm.R': {'out': 40, 'fw': -10, 'tw': 30}, 'forearm.R': {'fw': 95, 'tw': 20}, 'hand.R': {'fw': -20},
                'foot.R': {'up': 16 * tap}, 'thigh.R': {'fw': 4}, 'shin.R': {'fw': -6},
                'hips': {'out': -2, 'tw': look * 3},
            })
        return add(base(t, R, role), p)
    return f


def anim_walk(R, role):
    """Đi bộ tại chỗ (game tự đẩy người đi): bước đều, đánh tay ngược chân, nhún, lắc hông."""
    tp = role['tempo']
    old = R.c.get('old')
    period = 1.05 / tp

    def f(t):
        ph = 2 * math.pi * t / period
        s = math.sin(ph)
        c = math.cos(ph)
        st = .8 if old else 1.0
        lift_l = max(0.0, math.sin(ph + math.pi / 2))
        lift_r = max(0.0, math.sin(ph - math.pi / 2))
        p = {
            'hips': {'pos': (0, -.012 + abs(c) * .018, 0), 'tw': -s * 5 * st, 'out': c * 2, 'fw': 3 + (5 if old else 0)},
            'spine': {'tw': s * 3, 'fw': 2 + (6 if old else 0)},
            'chest': {'tw': s * 4, 'fw': -1},
            'neck': {'fw': 3 + (6 if old else 0)},
            'head': {'tw': -s * 3, 'fw': abs(c) * 2 - 2},
            'thigh.L': {'fw': s * 24 * st + 4}, 'thigh.R': {'fw': -s * 24 * st + 4},
            'shin.L': {'fw': -(6 + lift_l * 40 * st)}, 'shin.R': {'fw': -(6 + lift_r * 40 * st)},
            'foot.L': {'up': -s * 10 + lift_l * 8}, 'foot.R': {'up': s * 10 + lift_r * 8},
            'upperarm.L': {'fw': -s * 20 * st + 4, 'out': -6}, 'upperarm.R': {'fw': s * 20 * st + 4, 'out': -6},
            'forearm.L': {'fw': 18 + max(0, -s) * 18}, 'forearm.R': {'fw': 18 + max(0, s) * 18},
            'hand.L': {'fw': 6}, 'hand.R': {'fw': 6},
        }
        return p
    return f


# ---- tư thế nhận bánh (GIAO trong nguoi.py) chuyển thành kênh xương
def giao_pose(R, cid):
    return dang_pose(R, cid, N.GIAO[cid])


def dang_pose(R, cid, g):
    """Dáng phác (GIAO trong nguoi.py, DANG trong nguoi3.py) thành kênh xương: cúi, gật, quay đầu, hai tay."""
    G = R.G
    s = G['s']
    p = {}
    bend = math.degrees(g.get('bend', 0))
    p['spine'] = {'fw': bend * .45}
    p['chest'] = {'fw': bend * .55}
    p['neck'] = {'fw': math.degrees(g.get('nod', 0)) * .4}
    p['head'] = {'fw': math.degrees(g.get('nod', 0)) * .6 - bend * .5, 'tw': math.degrees(g.get('yaw', 0)), 'out': -math.degrees(g.get('tilt', 0))}
    for side, key in ((1, 'armL'), (-1, 'armR')):
        a = g.get(key)
        if not a:
            continue
        nm = 'L' if side > 0 else 'R'
        sh = np.asarray(R.J['upperarm.' + nm], np.float32)
        bw = N.CHARS[cid]['build']['bw']
        el = v(a['e'][0] * (bw if abs(a['e'][0]) > .2 else 1), *a['e'][1:]) * s
        wr = v(*a['w']) * s
        for bn, x0, x1 in (('upperarm.' + nm, sh, el), ('forearm.' + nm, el, wr)):
            d = x1 - x0  # three: x trái, y lên, z trước
            p[bn] = {'aim': (float(d[0]) * side, float(d[1]), float(d[2])), 'aim_ref': 'chest'}
        p['hand.' + nm] = {'fw': 10 if a['n'][1] > .5 else 0, 'tw': -60 if a['n'][1] > .5 else 0}
    return p


def anim_reach(R, role, cid):
    """Chờ bánh: chìa tay theo tư thế nhận bánh đã duyệt, tay nhấp nhẹ mời Bơ lại."""
    tp = role['tempo']
    gp = giao_pose(R, cid) if cid in N.GIAO else generic_reach()

    def f(t):
        k = smooth(t / .5)
        bob = osc(t, 1.1 / tp) * k
        b = base(t * .4, R, role)
        return add(mix(b, add(b, gp), k), {
            'forearm.R': {'fw': bob * 6}, 'forearm.L': {'fw': bob * 6},
            'head': {'fw': bob * 2, 'out': osc(t, 2.3 / tp) * 4},
        })
    return f


def generic_reach():
    return {
        'chest': {'fw': 10}, 'head': {'fw': 8},
        'upperarm.R': {'fw': 50, 'out': -6}, 'forearm.R': {'fw': 25, 'tw': -60}, 'hand.R': {'fw': 10},
    }


def anim_receive(R, role, cid):
    """Nhận bánh (một lần, 2,4 s): đưa tay ra, cầm, kéo bánh về ôm trước ngực, cười gật đầu."""
    tp = role['tempo']
    gp = giao_pose(R, cid) if cid in N.GIAO else generic_reach()
    hug = {
        'chest': {'fw': -4}, 'head': {'fw': 10},
        'upperarm.L': {'aim': (.15, -1, .35), 'aim_ref': 'chest'}, 'forearm.L': {'aim': (-.55, .25, 1), 'aim_ref': 'chest'}, 'hand.L': {'fw': -10},
        'upperarm.R': {'aim': (.15, -1, .35), 'aim_ref': 'chest'}, 'forearm.R': {'aim': (-.55, .25, 1), 'aim_ref': 'chest'}, 'hand.R': {'fw': -10},
    }

    def f(t):
        t = t * tp
        b = base(t * .5, R, role)
        reach = add(b, gp)
        held = add(b, hug)
        if t < .5:
            p = mix(b, reach, smooth(t / .5))
        elif t < .9:
            p = add(reach, {'hand.R': {'fw': 20 * smooth((t - .5) / .2)}, 'hand.L': {'fw': 20 * smooth((t - .5) / .2)}})
        elif t < 1.5:
            p = mix(reach, held, smooth((t - .9) / .6))
        else:
            nod = osc(t - 1.5, .5) * smooth((t - 1.5) / .2) * (1 - smooth((t - 2.1) / .3))
            p = add(held, {'head': {'fw': nod * 10}, 'neck': {'fw': nod * 4}})
        return p
    return f


def anim_special(R, role, cid):
    """Việc riêng của từng người, phát khi đứng chờ (idle chính trong game)."""
    tp = role['tempo']
    if cid == 'chutu':
        # Đọc báo: hai tay cầm báo trước mặt, lật trang, gật gù
        def f(t):
            turn = smooth((t % 6 - 4.6) / .4) * (1 - smooth((t % 6 - 5.4) / .4))
            return add(base(t, R, role), {
                'chest': {'fw': -4}, 'head': {'fw': 10 + osc(t, 3) * 3, 'tw': osc(t, 6) * 8},
                'upperarm.L': {'fw': 40, 'out': 8}, 'forearm.L': {'fw': 70, 'tw': -50, 'out': 10}, 'hand.L': {'fw': -10},
                'upperarm.R': {'fw': 40 + turn * 10, 'out': 8 + turn * 15}, 'forearm.R': {'fw': 70, 'tw': -50, 'out': 10 + turn * 20}, 'hand.R': {'fw': -10},
            })
        return f, 6.0
    if cid == 'coba' or cid == 'may':
        # Lau tủ bánh / lau quầy: tay phải xoay vòng, người nghiêng theo
        def f(t):
            a = 2 * math.pi * t / (1.6 / tp)
            return add(base(t, R, role), {
                'spine': {'fw': 8}, 'chest': {'fw': 6, 'tw': math.sin(a) * 5},
                'head': {'fw': 12, 'tw': math.sin(a) * 6},
                'upperarm.R': {'aim': (.15 + math.sin(a) * .15, -.75, .8 + math.cos(a) * .15), 'aim_ref': 'chest'},
                'forearm.R': {'aim': (-.25 + math.sin(a) * .35, -.55, 1), 'aim_ref': 'chest', 'tw': 40}, 'hand.R': {'up': -10},
                'upperarm.L': {'aim': (.12, -1, .45), 'aim_ref': 'chest'}, 'forearm.L': {'aim': (-.25, -.55, 1), 'aim_ref': 'chest', 'tw': 40},
            })
        return f, 3.2
    if cid == 'hung':
        # Sửa xe: cúi người, tay phải vặn cờ lê dưới gầm xe bên phải
        def f(t):
            a = osc(t, .7 / tp)
            return add(base(t, R, role), {
                'spine': {'fw': 18, 'out': -6}, 'chest': {'fw': 14, 'tw': -14},
                'head': {'fw': 10, 'tw': -20},
                'upperarm.R': {'fw': 55, 'out': 18}, 'forearm.R': {'fw': 20 + a * 10, 'tw': -40 + a * 35}, 'hand.R': {'fw': a * 15},
                'upperarm.L': {'fw': 35, 'out': 6}, 'forearm.L': {'fw': 40},
            })
        return f, 2.8
    if cid == 'bena':
        # Tựa lan can nhìn xuống đường, đung đưa người, chân nhón
        def f(t):
            sw = osc(t, 1.6 / tp)
            return add(base(t, R, role), {
                'spine': {'fw': 10}, 'chest': {'fw': 8, 'out': sw * 4},
                'head': {'fw': 22, 'out': sw * 8},
                'upperarm.L': {'aim': (.1, -.55, 1), 'aim_ref': 'chest'}, 'forearm.L': {'aim': (-.6, -.05, 1), 'aim_ref': 'chest'}, 'hand.L': {'fw': -10},
                'upperarm.R': {'aim': (.1, -.55, 1), 'aim_ref': 'chest'}, 'forearm.R': {'aim': (-.6, -.05, 1), 'aim_ref': 'chest'}, 'hand.R': {'fw': -10},
                'foot.L': {'up': -10 * max(0, sw)}, 'foot.R': {'up': -10 * max(0, -sw)},
            })
        return f, 3.2
    if cid == 'basau':
        # Phe phẩy quạt tay phải, lắc lư ghế
        def f(t):
            fan = osc(t, .6 / tp)
            rock = osc(t, 3.5 / tp)
            return add(base(t, R, role), {
                'spine': {'fw': rock * 3}, 'chest': {'fw': rock * 2},
                'upperarm.R': {'fw': 40, 'out': 15}, 'forearm.R': {'fw': 90, 'tw': -20 + fan * 25}, 'hand.R': {'out': fan * 30},
            })
        return f, 4.2
    if cid in ('ongbay', 'ongtam'):
        # Đánh cờ: chống cằm suy nghĩ rồi với tay đi một nước
        def f(t):
            u = t % 8
            move = smooth((u - 5.5) / .5) * (1 - smooth((u - 7.0) / .5))
            k = 1 - move
            return add(base(t, R, role), {
                'spine': {'fw': 14 + move * 8}, 'chest': {'fw': 8},
                'head': {'fw': 14 + osc(t, 2.5) * 3, 'tw': osc(t, 5) * 6},
                'upperarm.L': {'fw': 50 * k, 'out': 10 * k}, 'forearm.L': {'fw': 120 * k, 'tw': -30 * k}, 'hand.L': {'fw': -30 * k},
                'upperarm.R': {'fw': 30 + move * 40}, 'forearm.R': {'fw': 40 - move * 20, 'tw': -40 * move}, 'hand.R': {'fw': move * 20},
            })
        return f, 8.0
    if cid == 'cohai':
        # Bấm máy tính tính tiền, ngước lên mời khách
        def f(t):
            tap = max(0.0, osc(t, .3 / tp))
            up = smooth((t % 5 - 3.8) / .3) * (1 - smooth((t % 5 - 4.7) / .3))
            return add(base(t, R, role), {
                'chest': {'fw': 6 - up * 6}, 'head': {'fw': 18 - up * 22, 'tw': up * 10},
                'upperarm.L': {'aim': (.12, -1, .3), 'aim_ref': 'chest'}, 'forearm.L': {'aim': (-.45, .25, 1), 'aim_ref': 'chest', 'tw': 50},
                'upperarm.R': {'aim': (.12, -1, .35), 'aim_ref': 'chest'}, 'forearm.R': {'aim': (-.5, .3 + tap * .12, 1), 'aim_ref': 'chest', 'tw': 40},
                'hand.R': {'fw': 10 + tap * 18},
            })
        return f, 5.0
    if cid == 'chunam':
        # Xe ôm chờ khách: khoanh tay, thỉnh thoảng giơ tay gọi "xe ôm không?"
        def f(t):
            u = t % 7
            call = smooth((u - 5) / .3) * (1 - smooth((u - 6.4) / .3))
            k = 1 - call
            return add(base(t, R, role), {
                'chest': {'fw': -3}, 'head': {'fw': 2, 'tw': osc(t, 7) * 25 + call * 10},
                'upperarm.L': {'fw': 35, 'out': 5}, 'forearm.L': {'fw': 110, 'out': 25}, 'hand.L': {'fw': -10},
                'upperarm.R': {'fw': 35 * k + call * 20, 'out': 5 + call * 60}, 'forearm.R': {'fw': 110 * k + call * 50, 'out': 25 * k},
                'hand.R': {'out': call * osc(t, .4) * 25},
            })
        return f, 7.0
    return anim_idle(R, role), 4.0


def anim_rope(R, role):
    """Bé Na thả giỏ: hai tay luân phiên kéo dây (dùng khi giỏ đang thòng xuống/kéo lên)."""
    tp = role['tempo']

    def f(t):
        a = osc(t, .8 / tp)
        return add(base(t, R, role), {
            'spine': {'fw': 14}, 'chest': {'fw': 10}, 'head': {'fw': 25},
            'upperarm.L': {'fw': 70 + a * 15, 'out': -4}, 'forearm.L': {'fw': 30 - a * 20}, 'hand.L': {'fw': -20},
            'upperarm.R': {'fw': 70 - a * 15, 'out': -4}, 'forearm.R': {'fw': 30 + a * 20}, 'hand.R': {'fw': -20},
        })
    return f


def anim_call(R, role):
    """Bà Sáu gọi vọng ra hẻm: quay người, tay khum miệng."""
    tp = role['tempo']

    def f(t):
        k = smooth(t / .5) * (1 - smooth((t - 2.6) / .5))
        sh = osc(t, .5 / tp) * k
        return add(base(t, R, role), {
            'chest': {'tw': 25 * k, 'fw': -4 * k}, 'neck': {'tw': 15 * k}, 'head': {'tw': 20 * k, 'fw': -10 * k + sh * 3},
            'upperarm.R': {'fw': 50 * k, 'out': 30 * k}, 'forearm.R': {'fw': 120 * k}, 'hand.R': {'fw': -20 * k},
        })
    return f


# ---------------------------------------------------------------- Thứ Ba (dáng DANG trong nguoi3.py, trang Sang duyệt 21/10)
def dp(R, cid, key):
    return dang_pose(R, cid, N3.DANG(cid + ':' + key))


def enter_hold(t, t_in, t_out, length, fade=.25):
    """Hệ số 0..1: vào dáng trong t_in giây, giữ, rời dáng từ length - t_out."""
    return smooth(t / t_in) * (1 - smooth((t - (length - t_out)) / t_out))


def anim_chess(R, role, cid):
    """Đánh cờ (3 s lặp): chống cằm nghĩ, với tay nhấc quân, đập xuống bàn ở 2,4 s ("cách"), về nghĩ."""
    danh = dp(R, cid, 'danh')
    fan = role.get('fan')
    think = {
        'spine': {'fw': 10}, 'chest': {'fw': 8}, 'head': {'fw': 12},
        'upperarm.R': {'aim': (.2, -.45, .85), 'aim_ref': 'chest'},
        'forearm.R': {'aim': (-.45, 1, .45), 'aim_ref': 'chest'}, 'hand.R': {'fw': -25},
    }
    if not fan:
        think['upperarm.L'] = {'aim': (.15, -.9, .5), 'aim_ref': 'chest'}
        think['forearm.L'] = {'aim': (-.3, -.35, 1), 'aim_ref': 'chest'}

    def f(t):
        b = base(t, R, role)
        th = add(b, danh, think)
        mv = add(b, danh)
        if t < 1.2:
            p = th
        elif t < 1.9:
            p = mix(th, mv, smooth((t - 1.2) / .5))
        elif t < 2.4:
            lift = smooth((t - 1.9) / .3) * (1 - smooth((t - 2.25) / .15))
            p = add(mv, {'forearm.R': {'fw': -14 * lift}, 'hand.R': {'fw': -10 * lift}})
        else:
            p = mix(mv, th, smooth((t - 2.5) / .5))
        if fan:
            fl = osc(t, .7)
            p = add(p, {'hand.' + fan: {'out': fl * 22}, 'forearm.' + fan: {'tw': fl * 10}})
        return p
    return f


def anim_dang_once(R, role, cid, key, length, t_in=.25, t_out=.3, extra=None):
    """Clip một lần: vào dáng phác, giữ (có cử động phụ extra(t)), rời về dáng nền."""
    g = dp(R, cid, key)

    def f(t):
        b = base(t, R, role)
        k = enter_hold(t, t_in, t_out, length)
        p = mix(b, add(b, g), k)
        if extra:
            p = add(p, extra(t, k))
        return p
    return f


def chess_clips(R, role, cid):
    fan = role.get('fan')
    shake = lambda t, k: {'forearm.R': {'fw': osc(t, .16) * 8 * k}, 'hand.R': {'out': osc(t, .16, .2) * 10 * k}}  # noqa: E731
    if fan:  # Ông Tám mắng: phẩy quạt trên cao
        shake = lambda t, k: {'hand.L': {'out': osc(t, .22) * 30 * k}, 'forearm.L': {'tw': osc(t, .22) * 12 * k}}  # noqa: E731
    bob = lambda t, k: {'hips': {'pos': (0, 0, 0)}, 'chest': {'fw': -abs(osc(t, .5)) * 5 * k},  # noqa: E731
                        'hand.L': {'out': osc(t, .25) * 25 * k}, 'hand.R': {'out': -osc(t, .25) * 25 * k}, 'head': {'fw': -abs(osc(t, .5)) * 6 * k}}
    hush = lambda t, k: {'head': {'fw': osc(t, .5) * 2 * k}}  # noqa: E731
    return [('suyt', 1.0, anim_dang_once(R, role, cid, 'suyt', 1.0, .2, .2, hush)),
            ('mang', 1.5, anim_dang_once(R, role, cid, 'mang', 1.5, .2, .3, shake)),
            ('reo', 2.0, anim_dang_once(R, role, cid, 'reo', 2.0, .25, .35, bob))]


def bike_legs(R, key='chunam:choxe'):
    """Ngồi trên xe máy theo knee, ankle trong DANG: Chú Năm tựa yên (hông 0,86) chân chống đất,
    Chị Thảo ngồi yên sau (khachxeom:ngoisau, hông 0,95) chân gác lên gác chân."""
    g = N3.DANG(key)
    s = R.G['s']
    hip = R.head['thigh.L']
    p = {'hips': {'pos': (0, -(hip.z - g['sit']), -.04 * s)}}
    kx = g.get('kx', .12) * s
    knee = Vector((kx, g['knee'][0], g['knee'][1]))     # (trái, lên, trước)
    ank = Vector((kx * 1.05, g['ankle'][0], g['ankle'][1]))
    h = Vector((abs(hip.x), g['sit'], .04 * s))
    for sd in 'LR':
        p['thigh.' + sd] = {'aim': tuple(knee - h), 'aim_ref': 'world'}
        p['shin.' + sd] = {'aim': tuple(ank - knee), 'aim_ref': 'world'}
        p['foot.' + sd] = {'aim': (0, -.2, 1), 'aim_ref': 'world'}
    return p


def anim_bike_wait(R, role, cid):
    """Chờ khách (4 s lặp): tựa yên, tay trên đùi, ngó ra đường; cuối chu kỳ giơ tay mời "xe ôm không?"."""
    legs = bike_legs(R)
    g = dp(R, cid, 'choxe')

    def f(t):
        br = osc(t, 3.6)
        look = osc(t, 4.0) * 25
        call = smooth((t - 2.6) / .3) * (1 - smooth((t - 3.6) / .3))
        p = add(legs, g, {
            'spine': {'fw': br * .8}, 'chest': {'fw': br * 1.5},
            'head': {'tw': look, 'fw': osc(t, 2.0, .3) * 3},
        })
        if call > 0:
            raise_r = {'clav.R': {'up': 12}, 'upperarm.R': {'aim': (.8, .45, .35), 'aim_ref': 'chest'},
                       'forearm.R': {'aim': (.2, 1, .25), 'aim_ref': 'chest'}}
            p = add(mix(p, add(p, raise_r), call), {'hand.R': {'out': osc(t, .4) * 25 * call}})
        return p
    return f


def anim_bike_receive(R, role, cid):
    """Nhận bánh từ baga (1,2 s): xoay người sang phải về phía baga, chìa tay phải ra sau, cầm bánh về trước ngực."""
    legs = bike_legs(R)
    g = dp(R, cid, 'choxe')
    reach = {'chest': {'tw': -35}, 'neck': {'tw': -15}, 'head': {'tw': -30, 'fw': 10},
             'upperarm.R': {'aim': (.75, -.15, -.6), 'aim_ref': 'world'},
             'forearm.R': {'aim': (.5, .1, -.85), 'aim_ref': 'world'}, 'hand.R': {'fw': 15}}
    hold = {'upperarm.R': {'aim': (.15, -1, .3), 'aim_ref': 'chest'}, 'forearm.R': {'aim': (-.6, .3, 1), 'aim_ref': 'chest'}, 'head': {'fw': 8}}

    def f(t):
        b = add(legs, g)
        if t < .5:
            return mix(b, add(b, reach), smooth(t / .4))
        if t < .8:
            return add(b, reach)
        return mix(add(b, reach), add(b, hold), smooth((t - .8) / .35))
    return f


def anim_bike_ride(R, role, cid):
    """Chở khách (2 s lặp): quay người theo xe, ngồi giữa yên, hai tay cầm lái, xe xóc nhẹ."""
    g = N3.DANG('chunam:choxe')
    s = R.G['s']
    hip = R.head['thigh.L']

    def f(t):
        bump = osc(t, .5) * .006 + osc(t, 1.3, .3) * .004
        return {
            'hips': {'pos': (0, -(hip.z - g['sit'] - .02) + bump, 0), 'tw': 90},
            'spine': {'fw': 10}, 'chest': {'fw': 6 + osc(t, 2.0) * 2},
            'neck': {'fw': -2}, 'head': {'fw': -6, 'tw': osc(t, 2.0, .4) * 8},
            'thigh.L': {'aim': (.35, -.12, 1), 'aim_ref': 'hips'}, 'thigh.R': {'aim': (.35, -.12, 1), 'aim_ref': 'hips'},
            'shin.L': {'aim': (.05, -1, -.1), 'aim_ref': 'hips'}, 'shin.R': {'aim': (.05, -1, -.1), 'aim_ref': 'hips'},
            'foot.L': {'aim': (0, -.2, 1), 'aim_ref': 'hips'}, 'foot.R': {'aim': (0, -.2, 1), 'aim_ref': 'hips'},
            'upperarm.L': {'aim': (.3, -.4, 1), 'aim_ref': 'chest'}, 'upperarm.R': {'aim': (.3, -.4, 1), 'aim_ref': 'chest'},
            'forearm.L': {'aim': (.05, -.15, 1), 'aim_ref': 'chest'}, 'forearm.R': {'aim': (.05, -.15, 1), 'aim_ref': 'chest'},
            'hand.L': {'fw': 10}, 'hand.R': {'fw': 10},
        }
    return f


# Hai tay đặt trên đùi khi ngồi yên sau (dang_pose tính tay từ vai lúc đứng nên tay nổi lên ngực)
PILLION_HANDS = {
    'upperarm.L': {'aim': (.12, -1, .25), 'aim_ref': 'chest'}, 'forearm.L': {'aim': (-.1, -.45, 1), 'aim_ref': 'chest'},
    'upperarm.R': {'aim': (.12, -1, .25), 'aim_ref': 'chest'}, 'forearm.R': {'aim': (-.1, -.45, 1), 'aim_ref': 'chest'},
}


def anim_pillion(R, role, cid):
    """Chị Thảo ngồi sau (3 s lặp): hai tay vịn đùi, thở, ngó quanh, xe xóc nhẹ."""
    legs = bike_legs(R, 'khachxeom:ngoisau')
    g = add(dp(R, cid, 'ngoisau'), PILLION_HANDS)

    def f(t):
        br = osc(t, 3.0)
        return add(legs, g, {
            'hips': {'pos': (0, abs(osc(t, 1.5)) * .004, 0)},  # pos cộng dồn với dáng ngồi
            'spine': {'fw': br * .8}, 'chest': {'fw': br * 1.5},
            'head': {'tw': osc(t, 3.0, .2) * 18, 'fw': osc(t, 1.5) * 2},
        })
    return f


def anim_pillion_receive(R, role, cid):
    """Nhận bánh trên yên sau (1,2 s): quay người sang phải, ngửa tay phải đón ổ bánh (cầm ở 0,8 s), về ngồi."""
    legs = bike_legs(R, 'khachxeom:ngoisau')
    sit = add(legs, dp(R, cid, 'ngoisau'), PILLION_HANDS)
    take = add(legs, dp(R, cid, 'nhanbanh'), {k: PILLION_HANDS[k] for k in ('upperarm.L', 'forearm.L')}, {'chest': {'tw': -12}})

    def f(t):
        k = smooth(t / .4) * (1 - smooth((t - .85) / .35))
        return mix(sit, take, k)
    return f


def anim_pillion_off(R, role, cid):
    """Xuống xe (1,6 s): từ yên sau bước xuống đứng bên phải xe (xe ở bên trái như trang phác thảo), tay phải tháo quai nón."""
    sit = add(bike_legs(R, 'khachxeom:ngoisau'), dp(R, cid, 'ngoisau'), PILLION_HANDS)

    def f(t):
        stand = add(base(t, R, role), dp(R, cid, 'xuongxe'), {'hips': {'pos': (-.45, 0, .1)}})
        return mix(sit, stand, smooth(t / .9))
    return f


# ---------------------------------------------------------------- Cô Ba đứng bếp (trang "Cô Ba đứng bếp" Sang duyệt 21/10)
# Quầy cao 0,85 m, đồ đặt ~0,35 m trước mặt. Dao, khay, đũa game gắn vào hand.* bằng Nguoi.attach.
BEP_LUNG = {'spine': {'fw': 7}, 'chest': {'fw': 8}, 'neck': {'fw': 6}, 'head': {'fw': 14}}


def anim_knead(R, role):
    """Nhào bột (2,4 s): khom lưng, hai tay ấn xuống thau, cổ tay gập, vai nhún; nửa sau kéo mép bột gập vào giữa."""
    def f(t):
        ph = (t % 1.2) / 1.2
        push = math.sin(math.pi * min(ph / .55, 1.0))  # ấn xuống rồi nhả
        pull = smooth((ph - .55) / .25) * (1 - smooth((ph - .85) / .15))  # kéo mép vào giữa
        return add(base(t * .5, R, role), BEP_LUNG, {
            'hips': {'pos': (0, -.012 * push, 0)},
            'chest': {'fw': 4 * push},
            'clav.L': {'up': -6 * push}, 'clav.R': {'up': -6 * push},
            'upperarm.L': {'aim': (.2 + .12 * pull, -.72 - .1 * push, .55), 'aim_ref': 'world'},
            'forearm.L': {'aim': (-.18 + .3 * pull, -.55 - .3 * push, .8 - .2 * pull), 'aim_ref': 'world'},
            'upperarm.R': {'aim': (.2 + .12 * pull, -.72 - .1 * push, .55), 'aim_ref': 'world'},
            'forearm.R': {'aim': (-.18 + .3 * pull, -.55 - .3 * push, .8 - .2 * pull), 'aim_ref': 'world'},
            'hand.L': {'fw': 35 * push - 20 * pull}, 'hand.R': {'fw': 35 * push - 20 * pull},
        })
    return f


def anim_chop(R, role):
    """Thái chả (2,0 s, 4 nhát): tay trái đè khúc chả, tay phải cầm dao chặt lên xuống, mỗi nhát tay trái lùi chút."""
    def f(t):
        k = t % .5
        lift = smooth(k / .3) * (1 - smooth((k - .32) / .1))  # nhấc dao chậm, chặt nhanh
        back = (int(t / .5) + smooth((k - .4) / .1)) / 4.0   # tay trái lùi dần sau mỗi nhát
        return add(base(t * .5, R, role), BEP_LUNG, {
            'chest': {'tw': 6},
            'upperarm.L': {'aim': (-.05, -.75, .6 - .12 * back), 'aim_ref': 'world'},
            'forearm.L': {'aim': (-.45, -.3, .8), 'aim_ref': 'world'}, 'hand.L': {'fw': 10},
            'upperarm.R': {'aim': (.22, -.6 + .25 * lift, .6), 'aim_ref': 'world'},
            'forearm.R': {'aim': (-.1, -.45 + .9 * lift, .8), 'aim_ref': 'world'},
            'hand.R': {'fw': -15 * lift},
        })
    return f


def anim_pickle(R, role):
    """Trộn đồ chua (4,8 s = 3 vòng 1,6 s): nghiêng trái, tay trái ôm hũ, tay phải khuấy vòng; cuối vòng 3 nhấc đũa lên nếm."""
    def f(t):
        a = 2 * math.pi * t / 1.6
        taste = smooth((t - 3.9) / .3) * (1 - smooth((t - 4.5) / .25))
        stir = {'upperarm.R': {'aim': (.15 + .08 * math.cos(a), -.8, .5 + .08 * math.sin(a)), 'aim_ref': 'world'},
                'forearm.R': {'aim': (-.35 + .2 * math.cos(a), -.45, .8 + .2 * math.sin(a)), 'aim_ref': 'world'}}
        sip = {'upperarm.R': {'aim': (.1, -.55, .6), 'aim_ref': 'world'},
               'forearm.R': {'aim': (-.45, .85, .3), 'aim_ref': 'world'}, 'head': {'fw': -10}}
        b = add(base(t * .5, R, role), BEP_LUNG, {
            'spine': {'out': 5}, 'chest': {'out': 3},
            'upperarm.L': {'aim': (.25, -.9, .3), 'aim_ref': 'world'},
            'forearm.L': {'aim': (-.75, -.05, .65), 'aim_ref': 'world'}, 'hand.L': {'fw': 15},
        })
        return mix(add(b, stir), add(b, sip), taste)
    return f


def anim_tray(R, role):
    """Bưng khay (theo nhịp di_bo): chân và thân như đi bộ, hai tay khóa ngang bụng, cẳng tay nằm ngang."""
    walk = anim_walk(R, role)
    hold = {'clav.L': {'up': 0}, 'clav.R': {'up': 0},
            'upperarm.L': {'aim': (.12, -1, .15), 'aim_ref': 'chest'}, 'forearm.L': {'aim': (-.2, 0, 1), 'aim_ref': 'chest'},
            'upperarm.R': {'aim': (.12, -1, .15), 'aim_ref': 'chest'}, 'forearm.R': {'aim': (-.2, 0, 1), 'aim_ref': 'chest'},
            'hand.L': {'fw': 0}, 'hand.R': {'fw': 0}, 'head': {'fw': 6}}
    return lambda t: add(walk(t), hold)


def anim_bargain(R, role, cid):
    """Mặc cả (3 s lặp, dáng 'macca'): tay trái giơ ra phẩy phẩy, đầu lắc nhẹ, người xoay qua lại."""
    g = dp(R, cid, 'macca')

    def f(t):
        return add(base(t, R, role), g, {
            'hand.L': {'out': osc(t, .5) * 22}, 'forearm.L': {'fw': osc(t, 1.0) * 8},
            'head': {'tw': osc(t, 1.5) * 10, 'fw': osc(t, .75) * 4}, 'chest': {'tw': osc(t, 3.0) * 5},
        })
    return f


def anim_watch(R, role, cid):
    """Đứng xem cờ (4 s lặp): chắp tay sau lưng (Ông Chín) hoặc khoanh tay, nghiêng người nhìn bàn, gật gù."""
    g = dp(R, cid, 'dang') if cid == 'xemco' else {
        'spine': {'fw': 6}, 'chest': {'fw': 6}, 'head': {'fw': 16},
        'upperarm.L': {'aim': (.15, -1, .35), 'aim_ref': 'chest'}, 'forearm.L': {'aim': (-.7, .1, 1), 'aim_ref': 'chest'},
        'upperarm.R': {'aim': (.15, -1, .3), 'aim_ref': 'chest'}, 'forearm.R': {'aim': (-.7, .2, 1), 'aim_ref': 'chest'}}

    def f(t):
        nod = max(0.0, osc(t, 1.0)) * smooth((t - 2.2) / .2) * (1 - smooth((t - 3.4) / .2))
        return add(base(t, R, role), g, {'head': {'fw': nod * 8, 'tw': osc(t, 4.0) * 6}, 'spine': {'out': osc(t, 4.0, .25) * 2}})
    return f


def anim_watch_cheer(R, role, cid):
    """Reo khi chiếu tướng (2 s): giơ tay phải vẫy, người nhún."""
    if cid == 'xemco':
        return anim_dang_once(R, role, cid, 'reo', 2.0, .25, .35, lambda t, k: {'hand.R': {'out': osc(t, .3) * 25 * k}, 'hips': {'pos': (0, abs(osc(t, .5)) * .012 * k, 0)}})
    up = {'upperarm.R': {'aim': (.4, 1, .15), 'aim_ref': 'world'}, 'forearm.R': {'aim': (.15, 1, .1), 'aim_ref': 'world'}, 'head': {'fw': -6}}

    def f(t):
        b = base(t, R, role)
        k = enter_hold(t, .25, .35, 2.0)
        return add(mix(b, add(b, up), k), {'hand.R': {'out': osc(t, .3) * 25 * k}, 'hips': {'pos': (0, abs(osc(t, .5)) * .012 * k, 0)}})
    return f


def anim_sell(R, role, cid):
    """Cô Tư bán rau (3 s lặp): ngồi thấp, giơ bó rau lên mời, ngó qua lại rao hàng."""
    g = dp(R, cid, 'dang')

    def f(t):
        lift = max(0.0, osc(t, 3.0))
        return add(base(t, R, role), g, {'forearm.L': {'fw': -lift * 12}, 'forearm.R': {'fw': -lift * 12},
                                          'head': {'tw': osc(t, 3.0, .25) * 25, 'fw': -lift * 6}, 'chest': {'tw': osc(t, 3.0, .25) * 6}})
    return f


def anim_push(R, role, cid):
    """Chú Sáu đẩy xe bắp (1 s lặp, game đẩy người đi 1 m/s): bước đi, hai tay nắm tay đẩy trước bụng."""
    walk = anim_walk(R, dict(role, tempo=1.05))
    g = dp(R, cid, 'dang')
    arms = {k: val for k, val in g.items() if k.startswith(('upperarm', 'forearm', 'hand'))}

    def f(t):
        return add(walk(t), {'spine': {'fw': 6}, 'chest': {'fw': 4}}, arms)
    return f


def anim_fan_coal(R, role, cid):
    """Chú Sáu đứng quạt than (3 s lặp): tay phải phẩy xuống bếp than trên xe, tay trái chống hông."""
    def f(t):
        fl = osc(t, .45)
        return add(base(t, R, role), {
            'spine': {'fw': 10}, 'chest': {'fw': 6}, 'head': {'fw': 14, 'tw': osc(t, 3.0) * 10},
            'upperarm.R': {'aim': (.25, -.6, .8), 'aim_ref': 'chest'}, 'forearm.R': {'aim': (.1, -.45 + fl * .25, 1), 'aim_ref': 'chest'},
            'hand.R': {'up': fl * 25},
            'upperarm.L': {'aim': (.8, -.6, -.1), 'aim_ref': 'chest'}, 'forearm.L': {'aim': (-.6, -.1, .4), 'aim_ref': 'chest'},
        })
    return f


def anim_carry_pole(R, role, cid):
    """Cô Bảy gánh (0,9 s lặp): bước nhanh, tay phải giữ đòn gánh trên vai, đòn nhún theo bước."""
    walk = anim_walk(R, dict(role, tempo=1.15))
    g = dp(R, cid, 'dang')
    arm = {k: val for k, val in g.items() if k.endswith('.R') and k.startswith(('upperarm', 'forearm', 'hand'))}

    def f(t):
        return add(walk(t), arm, {'clav.R': {'up': -4 + abs(osc(t, .9 / 1.15)) * 3}, 'chest': {'out': 3}, 'neck': {'out': -3}})
    return f


def anim_shop(R, role, cid):
    """Người đi chợ đứng lựa hàng (4 s lặp): cúi nhìn, tay phải lật lựa, thỉnh thoảng ngẩng lên."""
    def f(t):
        pick = osc(t, 1.3)
        up = smooth((t - 3.0) / .3) * (1 - smooth((t - 3.7) / .3))
        return add(base(t, R, role), {
            'spine': {'fw': 16 * (1 - up)}, 'chest': {'fw': 10 * (1 - up)}, 'head': {'fw': 20 * (1 - up), 'tw': up * 15},
            'upperarm.R': {'aim': (.1, -.6 - pick * .1, .8), 'aim_ref': 'chest'}, 'forearm.R': {'aim': (-.2, -.7 + pick * .2, 1), 'aim_ref': 'chest'},
            'hand.R': {'fw': pick * 20},
        })
    return f


def anim_startle(R, role, cid):
    """Bị Bơ va (0,6 s): giật mình, ngửa người, tay hất lên, cúi nhìn xuống chân."""
    def f(t):
        k = smooth(t / .12) * (1 - smooth((t - .35) / .25))
        look = smooth((t - .15) / .2)
        return add(base(t, R, role), {
            'hips': {'pos': (0, .01 * k, -.02 * k)}, 'spine': {'fw': -6 * k}, 'chest': {'fw': -6 * k},
            'head': {'fw': 25 * look - 10 * k},
            'upperarm.L': {'out': 30 * k, 'fw': 20 * k}, 'upperarm.R': {'out': 30 * k, 'fw': 20 * k},
            'forearm.L': {'fw': 50 * k}, 'forearm.R': {'fw': 50 * k},
            'thigh.L': {'fw': 6 * k}, 'shin.L': {'fw': -12 * k},
        })
    return f


def thu_ba_clips(R, role, cid):
    """[(tên, giây, hàm, lặp)] riêng của từng người cho Thứ Ba."""
    if cid in ('ongbay', 'ongtam'):
        return [(n, sec, fn, False) for n, sec, fn in chess_clips(R, role, cid)]
    if cid == 'cohai':
        return [('dua_tui', 1.4, anim_dang_once(R, role, cid, 'duatui', 1.4, .45, .4), False)]
    if cid == 'chunam':
        return [('cho_khach', 4.0, anim_bike_wait(R, role, cid), True),
                ('nhan_xe', 1.2, anim_bike_receive(R, role, cid), False),
                ('cho_di', 2.0, anim_bike_ride(R, role, cid), True)]
    if cid == 'khachxeom':
        return [('ngoi_sau', 3.0, anim_pillion(R, role, cid), True),
                ('nhan_banh', 1.2, anim_pillion_receive(R, role, cid), False),
                ('xuong_xe', 1.6, anim_pillion_off(R, role, cid), False)]
    if cid in ('xemco', 'dicho1', 'dicho2', 'dicho3'):
        out = [('xem', 4.0, anim_watch(R, role, cid), True), ('reo', 2.0, anim_watch_cheer(R, role, cid), False)]
        if cid != 'xemco':
            out += [('dung_chon', 4.0, anim_shop(R, role, cid), True), ('va', .6, anim_startle(R, role, cid), False)]
        return out
    if cid in ('cho4', 'cho5', 'cho6', 'cho7', 'cho8'):
        out = [('mac_ca', 3.0, anim_bargain(R, role, cid), True),
               ('va', .8, anim_dang_once(R, role, cid, 'giatminh', .8, .1, .35), False)]  # giật mình theo dáng phác
        if cid != 'cho8':  # người đứng: lựa hàng (Cô Năm thì sắp hàng), xem, reo
            out += [('dung_chon', 4.0, anim_shop(R, role, cid), True),
                    ('xem', 4.0, anim_watch(R, role, cid), True), ('reo', 2.0, anim_watch_cheer(R, role, cid), False)]
        return out
    if cid == 'bancho':
        return [('ngoi_rao', 3.0, anim_sell(R, role, cid), True)]
    if cid == 'hangrong':
        return [('day_xe', 1.0, anim_push(R, role, cid), True), ('quat_than', 3.0, anim_fan_coal(R, role, cid), True),
                ('va', .6, anim_startle(R, role, cid), False)]
    if cid == 'ganhhang':
        return [('ganh_di', .9, anim_carry_pole(R, role, cid), True), ('va', .6, anim_startle(R, role, cid), False)]
    return []


# ---------------------------------------------------------------- Anh Hùng Thứ Sáu (trang G6 "Tiệm xe chiều tà", Sang duyệt 22/10)
# Chép nguyên từ scripts/g6.py của trang phác thảo. Dáng đứng cạnh cầu nâng, mặt nhìn -y; tay phải (.R) ở phía -x.
# Trục X âm đưa tay ra trước; X dương cúi người tới trước; Z âm quay sang phải anh.
H_STAND = [('upperarm.L', 'Y', -6), ('upperarm.R', 'Y', 6)]


def H_SUA(t=0.):
    w = 22 * math.sin(t * 2 * math.pi)
    return [('spine', 'X', 9), ('chest', 'X', 5), ('head', 'X', 8),
            ('upperarm.R', 'X', -58), ('upperarm.R', 'Z', 24), ('forearm.R', 'X', -42), ('forearm.R', 'Y', w), ('hand.R', 'X', -10),
            ('upperarm.L', 'X', -52), ('upperarm.L', 'Z', -22), ('forearm.L', 'X', -48), ('hand.L', 'Y', -20),
            ('thigh.L', 'X', -4), ('thigh.R', 'X', 3)]


def H_GOI1(k=1.):
    return [('spine', 'Z', -12 * k), ('chest', 'Z', -16 * k), ('neck', 'Z', -14 * k), ('head', 'X', -10 * k),
            ('upperarm.R', 'X', -95 * k), ('upperarm.R', 'Z', 30 * k), ('forearm.R', 'X', -115 * k), ('forearm.R', 'Z', 20 * k), ('hand.R', 'Y', 30 * k),
            ('upperarm.L', 'X', -50), ('upperarm.L', 'Z', 14), ('forearm.L', 'X', -48)]


def H_GOI2(t=0.):
    w = 18 * math.sin(t * 2 * math.pi)
    return [('spine', 'Z', -14), ('chest', 'Z', -10), ('chest', 'X', -6), ('neck', 'Z', -12), ('head', 'X', -14),
            ('upperarm.R', 'Y', 140 + w), ('forearm.R', 'Y', 25 + w), ('upperarm.L', 'Y', -40), ('upperarm.L', 'X', -60), ('forearm.L', 'X', -60), ('forearm.L', 'Z', 40),
            ('thigh.R', 'X', -10), ('shin.R', 'X', 14)]


def H_NHAN(k=1., hold=0.):
    return [('spine', 'X', 14 * k), ('chest', 'X', 6 * k), ('head', 'X', (10 - 18 * hold) * k),
            ('upperarm.R', 'X', -(55 + 10 * hold) * k), ('upperarm.R', 'Z', 30), ('forearm.R', 'X', -(15 + 55 * hold) * k), ('hand.R', 'X', 10),
            ('upperarm.L', 'X', -(55 + 10 * hold) * k), ('upperarm.L', 'Z', -30), ('forearm.L', 'X', -(15 + 55 * hold) * k), ('hand.L', 'X', 10),
            ('thigh.L', 'X', -6 * k), ('shin.L', 'X', 8 * k)]


def hung_thu_sau(R):
    """5 clip đứng ở tiệm xe Thứ Sáu. goi_1, goi_2, nhan_banh_cau chạy một lần rồi về sua_xe (Nguoi.ONE_SHOT)."""
    S = lambda d: H_STAND + d  # noqa: E731
    R.keyframe_world('sua_xe', [(1 + i * 6, S(H_SUA(i / 10))) for i in range(11)])
    R.keyframe_world('goi_1', [(1, S(H_SUA(0))), (8, S(H_GOI1(1))), (30, S(H_GOI1(1.05))), (45, S(H_SUA(0)))])
    R.keyframe_world('goi_2', [(1, S(H_SUA(0)))] + [(6 + i * 6, S(H_GOI2(i / 4))) for i in range(9)] + [(60, S(H_SUA(0)))])
    R.keyframe_world('nhan_banh_cau', [(1, S(H_SUA(0))), (10, S(H_NHAN(1, 0))), (20, S(H_NHAN(1, 0))), (30, S(H_NHAN(1, 1))), (45, S(H_NHAN(.4, 1)))])
    R.keyframe_world('dung_cho', [(1, S([])), (30, S([('chest', 'X', -2), ('head', 'Z', -8)])), (60, S([]))])


def thu_nam_clips(R, role, cid):
    """[(tên, giây, hàm, lặp)] cho Thứ Năm (trang G1): dáng lấy từ nguoi5.py / nguoi6.py qua N3.DANG."""
    calm = dict(role, energy=0)  # ngủ, nằm: không ngó quanh
    if cid == 'chithu':
        hush = lambda t, k: {'head': {'fw': osc(t, .5) * 2 * k}}  # noqa: E731
        rock = lambda t, k: {'upperarm.R': {'fw': osc(t, 2.4) * 12 * k}, 'forearm.R': {'fw': osc(t, 2.4, .1) * 8 * k},  # noqa: E731
                             'chest': {'fw': osc(t, 2.4) * 2 * k}, 'head': {'tw': osc(t, 4.8) * 6 * k}}
        bow = lambda t, k: {'chest': {'fw': abs(osc(t, .8)) * 6 * k}, 'head': {'fw': abs(osc(t, .8)) * 8 * k}}  # noqa: E731
        return [('suyt', 1.4, anim_dang_once(R, role, cid, 'suyt', 1.4, .25, .3, hush), False),
                ('ru_vong', 2.4, anim_dang_once(R, role, cid, 'ru', 1e9, .3, .3, rock), True),
                ('cam_on', 1.6, anim_dang_once(R, role, cid, 'camon', 1.6, .3, .35, bow), False)]
    if cid == 'bena':  # mở cửa 5B-1: giữ nắm cửa, chìa tay nhận bánh
        return [('mo_cua', 1.2, anim_dang_once(R, role, cid, 'mocua', 1.2, .3, .3), False)]
    if cid in ('chutu', 'hung'):
        key = 'ngugat' if cid == 'chutu' else 'namvong'
        g = dp(R, cid, key)

        def sleep(t):  # thở chậm, đầu gục gật nhẹ
            br = osc(t, 4.0)
            return add(base(t, R, calm), g, {'chest': {'fw': br * 2}, 'head': {'fw': br * 3 + osc(t, 8.0, .3) * 2}})

        def wake(t):  # giật mình (Chú Tư) / vươn dậy (Anh Hùng) rồi về dáng ngồi
            k = 1 - smooth((t - .2) / .5)
            jolt = smooth(t / .15) * (1 - smooth((t - .25) / .4))
            p = mix(base(t, R, role), add(base(t, R, calm), g), k)
            return add(p, {'head': {'fw': -14 * jolt}, 'chest': {'fw': -5 * jolt}} if cid == 'chutu' else
                       {'upperarm.L': {'up': 20 * jolt}, 'upperarm.R': {'up': 20 * jolt}, 'chest': {'fw': -8 * jolt}})
        if cid == 'chutu':
            return [('ngu_gat', 4.0, sleep, True), ('thuc_day', 1.4, wake, False)]
        return [('nam_vong', 4.0, sleep, True), ('ngoi_day', 1.4, wake, False)]
    if cid == 'may':  # ngồi ghế đẩu 0,32 m trên gác, thả / kéo dây giỏ bằng hai tay so le
        sit = dict(role, base='ngoi', seat=.32, energy=.3)
        g = dp(R, cid, 'thagio')

        def rope(period, amp, lift):
            def f(t):
                a = osc(t, period)
                return add(base(t, R, sit), g, {
                    'upperarm.R': {'fw': a * amp * .6}, 'forearm.R': {'fw': a * amp},
                    'upperarm.L': {'fw': -a * amp * .6}, 'forearm.L': {'fw': -a * amp},
                    'chest': {'fw': -abs(a) * lift}, 'head': {'fw': osc(t, period * 2) * 3},
                })
            return f
        return [('tha_gio', 2.0, rope(2.0, 14, 0), True), ('keo_gio', 1.4, rope(1.4, 22, 5), True)]
    return []


GIO = ('thanh', 'loan', 'muoi', 'hanh', 'bin', 'mit')


def gio_clips(R, role, cid):
    """[(tên, giây, hàm, lặp)] cho đám giỗ nhà Bà Sáu (trang G7): dáng lấy từ nguoi7.py qua N3.DANG.
    Nhang, chén đũa, mâm cỗ, bình tưới là đồ rời, gắn vào tay trong Godot."""
    stand = dict(role, base='dung')
    sit = dict(role, base='ngoi', seat=.26)

    def hold(key, r=role, extra=None, legs=None):
        g = dp(R, cid, key)
        return lambda t: add(base(t, R, r), legs or {}, g, extra(t) if extra else {})

    def pray(t):  # khấn: vái ba lần mỗi chu kỳ, nhang giơ ngang trán
        b = max(0.0, osc(t, 1.2)) * smooth((t % 3.6) / .2)
        return {'spine': {'fw': b * 10}, 'chest': {'fw': b * 6}, 'head': {'fw': b * 6}}

    def talk(t):  # nói chuyện: tay đưa nhẹ, gật gù
        return {'forearm.R': {'fw': osc(t, 1.3) * 10}, 'hand.R': {'out': osc(t, .65) * 12}, 'head': {'fw': osc(t, 1.7, .2) * 4}}

    def eat(t):  # ăn cỗ: và cơm lên miệng mỗi 2 s
        k = max(0.0, osc(t, 2.0))
        return {'upperarm.R': {'fw': k * 18}, 'forearm.R': {'fw': k * 25}, 'head': {'fw': -k * 6}, 'chest': {'fw': -k * 3}}
    out = []
    if cid == 'basau':
        walk = anim_walk(R, stand)
        racong = dp(R, cid, 'racong')
        out += [('tuoi_cay', 3.0, hold('tuoi', stand, lambda t: {'hand.R': {'fw': osc(t, 1.5) * 6}, 'chest': {'tw': osc(t, 3.0) * 4}}), True),
                ('ra_cong_nhan', 1.2, lambda t: add(walk(t), racong), True),
                ('chao_tien', 2.0, hold('chao', stand, lambda t: {'hand.R': {'out': osc(t, .5) * 28}, 'forearm.R': {'fw': osc(t, .5) * 6}}), True)]
    if cid == 'thanh':
        out += [('chap_tay_khan', 3.6, hold('dang', extra=pray), True), ('dung_noi_chuyen', 2.6, hold('noichuyen', extra=talk), True)]
    if cid == 'loan':
        mam = dp(R, cid, 'dang')
        walk = anim_walk(R, role)
        out += [('bung_mam_di', 1.05 / role['tempo'], lambda t: add(walk(t), mam), True),
                ('dat_mam', 1.4, anim_dang_once(R, role, cid, 'dang', 1.4, .1, .6,
                                                lambda t, k: {'spine': {'fw': 22 * smooth((t - .2) / .5) * k}, 'chest': {'fw': 10 * smooth((t - .2) / .5) * k}}), False),
                ('chap_tay_khan', 3.6, hold('chaptay', extra=pray), True)]
    if cid == 'muoi':
        out += [('ngoi_an', 2.0, hold('dang', sit, eat), True), ('dung_noi_chuyen', 2.6, hold('noichuyen', stand, talk), True)]
    if cid == 'hanh':
        out += [('dung_noi_chuyen', 2.6, hold('dang', extra=talk), True), ('ngoi_an', 2.0, hold('ngoian', sit, eat), True)]
    if cid == 'bin':
        run = anim_walk(R, dict(role, tempo=role['tempo'] * 1.9))

        def trip(t):  # vấp nhẹ: chúi tới, hai tay chới với rồi đứng lại cười
            k = smooth(t / .15) * (1 - smooth((t - .45) / .45))
            return add(base(t, R, role), {'spine': {'fw': 28 * k}, 'chest': {'fw': 12 * k}, 'head': {'fw': -18 * k},
                                          'upperarm.L': {'fw': 70 * k, 'out': 20 * k}, 'upperarm.R': {'fw': 70 * k, 'out': 20 * k},
                                          'thigh.R': {'fw': 25 * k}, 'shin.R': {'fw': -30 * k}})
        out += [('chay_theo', .55, lambda t: add(run(t), {'spine': {'fw': 10}, 'chest': {'fw': 4}}), True),
                ('vap_nhe', 1.1, trip, False),
                ('cuoi_om_bung', 1.2, hold('cuoi', extra=lambda t: {'chest': {'fw': abs(osc(t, .3)) * 6}, 'head': {'fw': -abs(osc(t, .3)) * 6}}), True)]
    if cid == 'mit':
        squat = bike_legs(R, 'mit:dang')  # ngồi xổm theo knee, ankle trong DANG
        out += [('ngoi_xom_vuot', 2.0, hold('dang', extra=lambda t: {'forearm.L': {'fw': osc(t, 1.0) * 14}, 'forearm.R': {'fw': osc(t, 1.0, .5) * 14},
                                                                     'head': {'out': osc(t, 2.0) * 6}}, legs=squat), True),
                ('vay_tay', 1.2, hold('cuoi', extra=lambda t: {'hand.R': {'out': osc(t, .4) * 28}, 'hand.L': {'out': -osc(t, .4) * 28}}), True)]
    return out


# ---------------------------------------------------------------- Thứ Bảy (trang G9 "Người dân Thứ Bảy", Sang duyệt 22/10)
# Dáng khoá lấy từ nguoi9.py qua N3.DANG; cử chỉ bằng cả cánh tay (rig không có ngón).
# Ai cũng có 'chup_chung' (lặp) để đứng chụp ảnh chung với Bơ. Người thường ngồi (Chú Tư, Anh Hùng, Bà Sáu,
# Chú Năm) làm việc nhờ thì đứng: các clip đó dùng dáng nền đứng.
G9_CHUP = {'bena': 1.6, 'basau': 2.4}


def g9_clips(R, role, cid):
    """[(tên, giây, hàm, lặp)] cho Thứ Bảy. Ly cà phê, bánh, con ốc, bông giấy, mũ là đồ rời (do_cam_g9.py)."""
    stand = dict(role, base='dung')
    keys = {k.split(':')[1] for k in nguoi9.ALL if k.startswith(cid + ':')}
    if not keys:
        return []

    def hold(key, r=stand, extra=None, legs=None):
        g = dp(R, cid, key)
        return lambda t: add(base(t, R, r), legs or {}, g, extra(t) if extra else {})

    def once(name, key, sec, r=stand, extra=None, t_in=.3, t_out=.35):
        return (name, sec, anim_dang_once(R, r, cid, key, sec, t_in, t_out, extra), False)

    def breathe(period):  # đứng tạo dáng chụp: thở, nghiêng đầu nhẹ, cười
        return lambda t: {'chest': {'fw': osc(t, period) * 1.5}, 'head': {'out': osc(t, period, .25) * 4, 'fw': osc(t, period / 2) * 1.5}}

    def clap(t, k=1.0):  # vỗ tay: hai cẳng tay khép mở 4 lần mỗi giây
        a = abs(osc(t, .25)) * k
        return {'forearm.L': {'out': -a * 14}, 'forearm.R': {'out': -a * 14}, 'head': {'fw': a * 3}}

    def point(side, period=2.0):  # chỉ tay: nhấn ngón trỏ (cả cánh tay) hai nhịp mỗi chu kỳ
        nm = 'L' if side > 0 else 'R'
        return lambda t: {'forearm.' + nm: {'fw': max(0.0, osc(t, period / 2)) * 10}, 'head': {'tw': osc(t, period) * 4}}

    sec = G9_CHUP.get(cid, 2.0)
    seat = role if role['base'] == 'ngoi' and cid not in ('chutu', 'hung') else stand  # Chú Tư, Anh Hùng đứng chụp
    legs = bike_legs(R, 'chunam:chup') if cid == 'chunam' else None
    out = [('chup_chung', sec, hold('chup', seat, breathe(sec), legs), True)]
    if cid == 'coba':
        out += [once('nem_banh', 'nem', 2.4, extra=lambda t, k: {'head': {'fw': max(0.0, osc(t, .6)) * 5 * k}}),  # nhai
                once('khen_ngon', 'khen', 1.6, extra=lambda t, k: clap(t, k))]
    if cid == 'chutu':
        walk = anim_walk(R, dict(stand, tempo=stand['tempo'] * 1.4))
        duoi = dp(R, cid, 'duoi')
        out += [('voi_bao', 1.2, lambda t: add(walk(t), duoi, {'upperarm.R': {'up': osc(t, .6) * 12}}), True),
                ('chi_len', 2.0, hold('chi', extra=point(1)), True),
                once('nhan_bao', 'camon', 2.0, extra=lambda t, k: {'chest': {'fw': abs(osc(t, .9)) * 8 * k}, 'head': {'fw': abs(osc(t, .9)) * 8 * k}}),
                ('dung_cho', 4.0, lambda t: base(t, R, stand), True)]
    if cid == 'bena':
        squat = bike_legs(R, 'bena:tron')
        tron = dict(role, base='ngoi', seat=.3)
        out += [('nup', 1.6, hold('tron', tron, lambda t: {'chest': {'fw': osc(t, 1.6) * 2}, 'head': {'tw': osc(t, 3.2) * 5}}, squat), True),
                ('lo_dau', 1.0, hold('lo', extra=lambda t: {'spine': {'out': -osc(t, 1.0) * 4}, 'head': {'out': -osc(t, 1.0) * 6}}), True),
                once('bi_tim_thay', 'cuoi', 1.4, t_in=.15, extra=lambda t, k: {'chest': {'fw': -abs(osc(t, .35)) * 5 * k}, 'head': {'fw': -abs(osc(t, .35)) * 6 * k}}),
                ('chay_tron', 1.05 / (role['tempo'] * 1.4), anim_walk(R, dict(role, tempo=role['tempo'] * 1.4)), True)]
    if cid == 'may':
        chib = dp(R, cid, 'chibang')
        out += [('chi_bang', 2.0, hold('chibang', extra=point(-1)), True),
                once('vo_tay', 'votay', 1.2, t_in=.15, t_out=.25, extra=lambda t, k: clap(t, k)),
                ('lac_dau_cuoi', 1.0, lambda t: add(base(t, R, stand), chib, {'head': {'tw': osc(t, .5) * 14 * smooth(t / .15) * (1 - smooth((t - .75) / .25))}}), False)]
    if cid == 'hung':
        out += [('cui_tim', 2.4, hold('cui', extra=lambda t: {'head': {'tw': osc(t, 2.4) * 18}, 'chest': {'tw': osc(t, 2.4, .1) * 6}}), True),
                once('nhan_oc', 'nhan', 1.6, extra=lambda t, k: {'forearm.R': {'up': osc(t, .8) * 10 * k}, 'head': {'out': osc(t, .8) * 4 * k}})]
    if cid == 'basau':
        out += [('chi_gian', 2.0, hold('chi', extra=point(-1)), True),
                once('nhan_bong', 'nhan', 2.0, extra=lambda t, k: {'head': {'fw': abs(osc(t, 1.0)) * 8 * k}, 'chest': {'fw': abs(osc(t, 1.0)) * 4 * k}})]
    if cid in ('ongbay', 'ongtam'):
        side = -1 if cid == 'ongbay' else 1
        out += [('chi_quan_co', 2.0, hold('chi', role, point(side)), True)]
    if cid == 'ongbay':  # G1: đứng xách lồng chim chờ thang máy chung cư (khung đứng, tay phải gập ra trước)
        xach = {'upperarm.R': {'fw': 25, 'out': 8}, 'forearm.R': {'fw': 75}, 'hand.R': {'fw': -15}}
        out += [('xach_long', 3.0, lambda t: add(base(t, R, stand), xach, breathe(3.0)(t)), True)]
    if cid == 'cohai':
        out += [('chong_nanh', 2.4, hold('chongnanh', extra=lambda t: {'head': {'out': osc(t, 1.2) * 6}, 'spine': {'tw': osc(t, 2.4) * 3}}), True),
                once('vo_tay', 'votay', 1.2, t_in=.15, t_out=.25, extra=lambda t, k: clap(t, k))]
    if cid == 'chunam':
        out += [('gai_dau', 2.0, hold('gaidau', extra=lambda t: {'forearm.R': {'out': osc(t, .4) * 12}, 'hand.R': {'fw': osc(t, .4) * 10}}), True),
                ('chi_mai', 2.0, hold('chimai', extra=point(1)), True)]
    if cid == 'khachxeom':
        out += [('tim_mu', 2.4, hold('tim', extra=lambda t: {'head': {'tw': osc(t, 2.4) * 22}, 'chest': {'tw': osc(t, 2.4, .1) * 8}}), True),
                once('nhan_mu', 'nhanmu', 2.0, extra=lambda t, k: {'chest': {'fw': abs(osc(t, 1.0)) * 6 * k}, 'head': {'fw': abs(osc(t, 1.0)) * 8 * k}})]
    return out


# ---------------------------------------------------------------- người qua đường (trang P3 "Người qua đường và xe ra vào", Sang duyệt 22/10)
# Dáng khoá trong nguoi_p3.py; '@người' mượn dáng người khác (điện thoại, ghế nhựa, lái xe dùng chung).
# Điện thoại, ly trà đá, vé số, hộp cơm, túi che đầu là đồ rời (do_cam_p3.py), xe máy và xe buýt do cảnh dựng.
P3_LAI = ('qd_giaohang', 'qd_mehoa', 'qd_sinhvien')  # có clip lái xe (Anh Phúc lái ở bản đội nón qd_sinhvien_xe)
P3_BUOC = .35                              # bậc cửa xe buýt (m)
P3_GHE = .26                               # ghế nhựa thấp quán cà phê, trà đá (P4)


def p3_clips(R, role, cid, goc):
    """[(tên, giây, hàm, lặp)] cho người qua đường; cid là người gốc, goc là id đang dựng (_b, _mua, _xe)."""
    kid = R.c.get('kid')
    stand = dict(role, base='dung')
    ghe = dict(role, base='ngoi', seat=P3_GHE)

    def hold(key, r=stand, extra=None, legs=None):
        g = dp(R, cid, key)
        return lambda t: add(base(t, R, r), legs or {}, g, extra(t) if extra else {})

    def walk_with(key, tempo=1.0, lean=0.0):  # bước chân đi bộ, tay giữ theo dáng (quai cặp, bảng vé số...)
        w = anim_walk(R, dict(role, tempo=role['tempo'] * tempo))
        g = dp(R, cid, key) if key else {}
        arms = {k: val for k, val in g.items() if k.split('.')[0] in ('upperarm', 'forearm', 'hand')}
        return lambda t: add(w(t), arms, {'spine': {'fw': lean}, 'chest': {'fw': lean * .5}})

    def once(name, key, sec, extra=None, t_in=.3, t_out=.35, r=stand):
        return (name, sec, anim_dang_once(R, r, cid, key, sec, t_in, t_out, extra), False)

    def step(up):  # lên / xuống bậc xe buýt: chân trước nhấc lên bậc, hông lên (xuống) P3_BUOC
        g = dp(R, cid, 'lenxe@qd_vanphong')

        def f(t):
            u = t / (1.2 if up else 1.0)
            h = smooth((u - .15) / .6)
            h = h if up else 1 - h
            lift = math.sin(math.pi * min(1.0, max(0.0, (u - .05) / .5)))
            follow = math.sin(math.pi * min(1.0, max(0.0, (u - .45) / .45)))
            return add(base(t, R, stand), g, {'hips': {'pos': (0, P3_BUOC * h, 0)}, 'spine': {'fw': 8 * lift},
                                              'thigh.L': {'fw': 55 * lift}, 'shin.L': {'fw': -60 * lift},
                                              'thigh.R': {'fw': 40 * follow}, 'shin.R': {'fw': -50 * follow}})
        return f

    out = []
    walk_key = {'qd_hocsinh': 'dibo', 'qd_sinhvien': 'dibo', 'qd_veso': 'dibo'}.get(cid)
    out += [('di_bo', 1.05 / role['tempo'], walk_with(walk_key), True),
            ('chay', .6, walk_with('chay@qd_hocsinh' if kid else None, 1.75, 10), True),
            ('dung_cho', 3.0, hold('dungcho') if cid == 'qd_veso' else (lambda t: base(t, R, stand)), True),
            ('ne_bo', .8, anim_startle(R, stand, cid), False),
            ('len_xe_buyt', 1.2, step(True), False), ('xuong_xe_buyt', 1.0, step(False), False),
            ('che_mua', .6, walk_with('chemua@qd_vanphong', 1.75, 8), True)]
    if cid in ('qd_ongtd', 'qd_veso'):
        out.append(('di_cham', 1.3, walk_with(walk_key, 1.05 / (1.3 * role['tempo'])), True))
    if not kid:
        out += [('nhin_dt', 2.4, hold('nhindt@qd_vanphong', extra=lambda t: {'head': {'tw': osc(t, 2.4) * 4}, 'hand.R': {'fw': max(0.0, osc(t, 1.2)) * 8}}), True),
                ('goi_dt', 2.4, hold('goidt@qd_giaohang', extra=lambda t: {'head': {'out': osc(t, 2.4) * 5}, 'forearm.L': {'fw': osc(t, 1.2) * 10}}), True),
                ('ngoi_ghe', 2.4, hold('ngoighe@' + ('qd_ongtd' if R.c.get('old') else 'qd_sinhvien'), ghe,
                                       lambda t: {'forearm.R': {'fw': max(0.0, osc(t, 2.4)) * 25}, 'head': {'fw': -max(0.0, osc(t, 2.4)) * 6}}), True)]
    if cid == 'qd_ongtd':
        out.append(once('vuon_vai', 'vuonvai', 2.0, lambda t, k: {'chest': {'fw': -osc(t, 2.0) * 4 * k}}))
    if cid == 'qd_veso':
        out.append(once('moi_ve', 'moive', 1.6, lambda t, k: {'forearm.R': {'fw': osc(t, .8) * 8 * k}}))
    if cid == 'qd_congnhan':
        out += [('ngoi_an', 2.0, hold('ngoian', ghe, lambda t: {'upperarm.R': {'fw': max(0.0, osc(t, 2.0)) * 18}, 'forearm.R': {'fw': max(0.0, osc(t, 2.0)) * 25},
                                                                 'head': {'fw': -max(0.0, osc(t, 2.0)) * 6}}), True),
                once('lau_mo_hoi', 'laumohoi', 1.6, lambda t, k: {'forearm.R': {'tw': osc(t, .5) * 20 * k}})]
    if cid == 'qd_mehoa':
        out.append(('vay_con', 1.2, hold('vaycon', extra=lambda t: {'hand.R': {'out': osc(t, .4) * 28}, 'forearm.R': {'fw': osc(t, .4) * 6}}), True))
    if cid == 'qd_hocsinh':
        out += [('vay_bo', 1.2, hold('vaybo', extra=lambda t: {'hand.R': {'out': osc(t, .3) * 30}, 'head': {'out': osc(t, .6) * 5}}), True),
                ('ngoi_sau', 2.0, hold('ngoisau', stand, lambda t: {'head': {'tw': osc(t, 4.0) * 12}, 'chest': {'fw': osc(t, 2.0) * 1.5}},
                                       bike_legs(R, 'qd_hocsinh:ngoisau')), True)]
    if cid in P3_LAI:
        lai = dp(R, cid, 'laixe')
        legs = bike_legs(R, cid + ':laixe')

        def ride(t):
            return add(base(t, R, stand), legs, lai, {'chest': {'fw': osc(t, 1.0) * 1.2}, 'head': {'tw': osc(t, 4.0) * 10}})

        def mount(on):  # đứng cạnh yên <-> ngồi lái (1 s)
            def f(t):
                k = smooth(t / 1.0)
                k = k if on else 1 - k
                return mix(base(t, R, stand), ride(t), k)
            return f
        out += [('lai_xe', 2.0, ride, True), ('len_xe', 1.0, mount(True), False), ('xuong_xe', 1.0, mount(False), False),
                ('dat_xe', 1.1, walk_with('datxe@' + (cid if cid != 'qd_sinhvien' else 'qd_giaohang'), 1.05 / (1.1 * role['tempo'])), True)]
    return out


def mua_clips(R, role, cid):
    """Dáng riêng của người mặc áo mưa (trang G5 Thứ Tư): 'dang_mua' giữ dáng đã duyệt (lặp, có thở),
    Chú Tư thêm 'cuon_bat' cuộn bạt sạp báo. Dù, giỏ, cuộn bạt là đồ rời gắn vào tay trong Godot."""
    g = dang_pose(R, cid, N4.POSES[cid]())
    legs = bike_legs(R) if cid == 'chunam_mua' else {}

    def hold(t):
        br = osc(t, 3.0)
        return add(base(t, R, role), legs, g, {'chest': {'fw': br * 1.2}, 'head': {'tw': osc(t, 6.0) * 6, 'fw': br}})
    out = [('dang_mua', 6.0, hold, True)]
    if cid == 'chutu_mua':
        def roll(t):
            a = 2 * math.pi * t / 1.2
            return add(base(t, R, role), g, {
                'spine': {'fw': 22}, 'chest': {'fw': 12}, 'head': {'fw': 15},
                'upperarm.L': {'aim': (.25, -.55 + math.sin(a) * .15, 1), 'aim_ref': 'chest'},
                'upperarm.R': {'aim': (.25, -.55 + math.sin(a) * .15, 1), 'aim_ref': 'chest'},
                'forearm.L': {'aim': (-.35, -.2 + math.cos(a) * .3, 1), 'aim_ref': 'chest'},
                'forearm.R': {'aim': (-.35, -.2 + math.cos(a) * .3, 1), 'aim_ref': 'chest'},
            })
        out.append(('cuon_bat', 2.4, roll, True))
    return out


def build_anims(info, cid):
    R = Rig(info)
    R.c = info['c']
    role = ROLES[cid]
    mua = cid if cid in N4.POSES else None
    goc = cid
    cid = N.CHARS[cid].get('base', cid)  # người áo mưa, Chị Thảo không mũ cử động như người gốc
    tp = role['tempo']
    L = lambda sec: int(round(sec * FPS))  # noqa: E731
    R.keyframe('dung_yen', L(12.0 / tp), anim_idle(R, role))  # chu kỳ dài để không thấy lặp
    R.keyframe('noi', L(2.6 / tp), anim_talk(R, role))
    R.keyframe('vay', L(2.1 / tp), anim_wave(R, role))
    R.keyframe('vui', L(1.8 / tp), anim_happy(R, role))
    qua_duong = goc in nguoi_p3.IDS  # người qua đường không nhận bánh, có di_bo riêng (p3_clips)
    if not qua_duong:
        R.keyframe('sot_ruot', L(6.4 / tp), anim_impatient(R, role))
        R.keyframe('cho_banh', L(2.2 / tp), anim_reach(R, role, cid))
    if cid != 'khachxeom' and not qua_duong:  # Chị Thảo nhận bánh trên yên sau (thu_ba_clips)
        R.keyframe('nhan_banh', L(2.6 / tp), anim_receive(R, role, cid), loop=False)
    # người bán ngồi cũng phải đứng dậy đi khi dọn sạp; Bà Sáu ra cổng ngày giỗ; Thứ Bảy đi làm việc nhờ
    if not qua_duong and (role['base'] == 'dung' or cid in CHO or cid in ('basau', 'chutu', 'hung', 'chunam')):
        R.keyframe('di_bo', L(1.05 / tp), anim_walk(R, dict(role, base='dung')))
    if cid in ('ongbay', 'ongtam'):
        fn, sec = anim_chess(R, role, cid), 3.0  # đánh cờ theo dáng "đi cờ" đã duyệt
    else:
        fn, sec = anim_special(R, role, cid)
    R.keyframe('viec_rieng', L(sec), fn)
    clips = thu_ba_clips(R, role, cid)
    if not mua:
        clips += thu_nam_clips(R, role, cid) + gio_clips(R, role, cid)
        if goc != 'khachxeom':  # Chị Thảo có mũ chỉ đi xe Thứ Ba; dáng Thứ Bảy ở bản không mũ khachxeom_tb
            clips += g9_clips(R, role, cid)
        if qua_duong:
            clips += p3_clips(R, role, cid, goc)
    if cid in CHO and 'va' not in [n for n, *_ in clips]:  # người chợ nào cũng giật mình khi bị Bơ va
        clips.append(('va', .6, anim_startle(R, role, cid), False))
    for name, sec, fn, loop in clips:
        R.keyframe(name, L(sec), fn, loop=loop)
    if cid == 'coba':  # đứng bếp
        R.keyframe('nhao_bot', L(2.4), anim_knead(R, role))
        R.keyframe('thai_cha', L(2.0), anim_chop(R, role))
        R.keyframe('tron_do_chua', L(4.8), anim_pickle(R, role))
        R.keyframe('bung_khay', L(1.05 / tp), anim_tray(R, role))
    if cid == 'bena':
        R.keyframe('keo_day', L(1.6 / tp), anim_rope(R, role))
    if cid == 'basau':
        R.keyframe('goi_muc', L(3.2), anim_call(R, role), loop=False)
    if mua:
        for name, sec, fn, loop in mua_clips(R, role, mua):
            R.keyframe(name, L(sec), fn, loop=loop)
    if cid == 'hung':
        hung_thu_sau(R)
    return R


# ---------------------------------------------------------------- xuất và ảnh kiểm tra
def export(info, path, clip=True):
    scn = bpy.context.scene
    for o in scn.objects:
        o.select_set(o in (info['arm'], info['body']))
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_apply=False, export_vertex_color='ACTIVE',
                              export_animations=clip, export_animation_mode='NLA_TRACKS', export_skins=True,
                              export_optimize_animation_size=True, export_force_sampling=True, export_frame_step=1,
                              export_def_bones=False, export_yup=True, export_normals=True, export_texcoords=False,
                              export_tangents=False, export_materials='EXPORT')
    print('xuất', path, os.path.getsize(path) // 1024, 'KB')


def main():
    global Q
    args = [a for a in sys.argv[1:] if not a.startswith('--ban=')]
    ban = next((a[6:] for a in sys.argv[1:] if a.startswith('--ban=')), '')
    Q = BAN[ban]
    ids = args[0]
    out = args[1]
    ids = list(N.CHARS) if ids == 'all' else ids.split(',')
    os.makedirs(out, exist_ok=True)
    report = {}
    for cid in ids:
        info = build_person(cid)
        # Người qua đường: chỉ bản nhẹ của người gốc mang clip, các bản khác mượn trong game (Nguoi.anim_source)
        clip = cid not in nguoi_p3.IDS or (cid in nguoi_p3.GOC and ban == 'nhe')
        if clip:
            build_anims(info, cid)
        path = os.path.join(out, cid + ('_' + ban if ban else '') + '.glb')
        export(info, path, clip)
        ad = info['arm'].animation_data
        report[cid] = dict(tris=info['tris'], kb=os.path.getsize(path) // 1024,
                           anims=[t.name for t in ad.nla_tracks] if ad else [], h=info['c']['h'])
    print(json.dumps(report, ensure_ascii=False))


if __name__ == '__main__':
    main()
