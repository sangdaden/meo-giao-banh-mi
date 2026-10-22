"""Xuất 42 phụ kiện (35 món gốc + 7 món bán theo gói trong acc_moi.py) và 19 giống mèo (phong cách D) sang .glb nhẹ cho tủ đồ trong game.

Dùng mã dựng của luồng "Skin mèo và phụ kiện" (meo-3d/skins: catcore, acc, breeds, blend), không render.
Chạy:  python3 tools/xuat_skin_game.py <thư_mục_skins> assets/models/skin [phu_kien|giong|giong_cai|all] [id,id..]
(Cần: pip install bpy scikit-image)

Kết quả:
- phu_kien/<id>.glb: mỗi bộ phận một object, toạ độ tính từ điểm gắn của nó.
  Đồ ở chân được tách thành 4 chiếc (tên kết thúc __FL, __FR, __BL, __BR), gốc ở tâm bàn chân.
- giong/<id>_duc.glb, giong/<id>_cai.glb: thân + mắt, có bộ xương chính thức 22 xương cùng tên với Bơ (root, hips, chest, head,
  3 xương mỗi chân, tail_1..4, ear_*; thêm eye_*, scarf)
  để player.gd chạy được động tác; xương đặt theo số đo của từng giống, không lấy cứng của Bơ.
- skin.json: điểm gắn của từng giống (sockets, tâm đầu, ma trận xoay đầu) và điểm gắn của từng object phụ kiện.
"""
import sys, os, json, math
import numpy as np

SKINS, OUT = sys.argv[1], sys.argv[2]
WHAT = sys.argv[3] if len(sys.argv) > 3 else 'all'
ONLY = sys.argv[4].split(',') if len(sys.argv) > 4 else None
sys.path.insert(0, SKINS)
import bpy
from mathutils import Vector
import catcore as cc, blend as bl, acc
from breeds import BREEDS, ORDER, lion_parts
from parts import build_part

# Điểm gắn của từng phụ kiện (theo run_acc.py); đồ đội đầu tự nhận "head" từ Part.head
SOCK = dict(khando='neck', khanran='neck', chuong='neck', nobuom='neck', vonghoa='neck', tuibanh='back', thung='back', dongganh='back', aochoang='back',
            canhthienthan='back', phaovit='back', noduoi='tail_mid', denlong='tail_tip', coduua='tail_tip', bongbay='tail_tip',
            tatsoc='feet', ungmua='feet', giaypatin='feet', deptoong='feet')
# 7 món bán theo gói (luồng "Bán mèo và phụ kiện", Sang duyệt 21/10): acc_moi.py đặt cạnh acc.py.
# Ngân sách tam giác từng bộ phận lấy theo bản đã duyệt (meta_<id>.json) để bản web nhẹ.
try:
    import acc_moi
    acc.ACC.update(acc_moi.ACC)
    SOCK.update(acc_moi.SOCK)
except ImportError:
    acc_moi = None
PART_TRIS = {}
_moi = os.path.join(SKINS, 'mon_moi')
for _id in (acc_moi.ACC if acc_moi else ()):
    _f = os.path.join(_moi, f'meta_{_id}.json')
    if os.path.exists(_f):
        for _p in json.load(open(_f))['parts']:
            PART_TRIS[(_id, _p['name'])] = max(120, _p['tris'])
EARS_DOWN = ('mucoi', 'nonla', 'muphuthuy')
PAWS = ('FL', 'FR', 'BL', 'BR')

os.makedirs(f'{OUT}/phu_kien', exist_ok=True)
os.makedirs(f'{OUT}/giong', exist_ok=True)
meta_path = f'{OUT}/skin.json'
META = json.load(open(meta_path)) if os.path.exists(meta_path) else {'giong': {}, 'phu_kien': {}}


def head_info():
    """Tâm đầu, tâm xoay và ma trận xoay đầu (cột) theo dáng nghỉ của giống đang cấu hình."""
    return dict(hc=[float(a) for a in cc.S['head'][0]], hr=[float(a) for a in cc.S['head'][1]],
                pivot=[float(a) for a in cc.HPIV], basis=[float(a) for a in cc.HR.T.ravel()])  # Godot Basis nhận 3 cột = 3 hàng của HR.T


def select_only(objs):
    for o in bpy.context.scene.objects:
        o.select_set(o in objs)
    bpy.context.view_layer.objects.active = objs[0]


def decimate(o, target):
    tris = len(o.data.polygons)
    if tris > target:
        md = o.modifiers.new('Dec', 'DECIMATE')
        md.ratio = target / tris
        select_only([o])
        bpy.ops.object.modifier_apply(modifier=md.name)


def bake_color(o):
    """Godot chỉ đọc một lớp màu đỉnh: món một màu thì tô màu vật liệu vào màu đỉnh."""
    if o.data.color_attributes:
        o.data.color_attributes.active_color = o.data.color_attributes[0]
        return
    m = o.data.materials[0]
    nt = m.node_tree
    rgb = [n for n in nt.nodes if n.type == 'RGB']
    col = tuple(rgb[0].outputs[0].default_value) if rgb else tuple(nt.nodes['Principled BSDF'].inputs['Base Color'].default_value)
    a = o.data.color_attributes.new('Col', 'FLOAT_COLOR', 'POINT')
    a.data.foreach_set('color', list(col) * len(o.data.vertices))
    o.data.color_attributes.active_color = a


def export(path, objs, skins=False):
    select_only(objs)
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_apply=True, export_vertex_color='ACTIVE',
                              export_yup=True, export_skins=skins, export_animations=False, export_materials='EXPORT')


# ---------------------------------------------------------------- phụ kiện

def budget(sock):
    """Số tam giác tối đa mỗi bộ phận: đồ đội đầu nhìn gần nhất trong tủ đồ nên được nhiều hơn."""
    return {'head': 2500, 'feet': 600}.get(sock, 1500)


def mesh_part(pt, target):
    """Dựng lưới từ SDF. Lưới mịn gấp nhiều lần ngân sách thì dựng lại với ô thưa hơn (tối đa 1,6 lần)
    để giảm lưới nhẹ tay hơn: giảm 25–100 lần làm nón sinh nhật, mũ bảo hiểm... mất hình (Sang báo 21/10)."""
    lo = np.asarray(pt.lo, np.float32); hi = np.asarray(pt.hi, np.float32)
    P, o = cc.grid(lo, hi, pt.h); d = pt.sdf(P); r = cc.mesh(d, o, pt.h)
    if r is None or len(r[1]) <= 4 * target:
        return r
    h2 = pt.h * min(1.6, math.sqrt(len(r[1]) / (4 * target)))   # thưa hơn nữa thì vành mỏng (mũ phù thủy) bị rách
    P2, o2 = cc.grid(lo, hi, h2); r2 = cc.mesh(pt.sdf(P2), o2, h2)
    # Ô thưa làm đứt chi tiết mảnh (quai, viền) thì giữ lưới mịn
    if r2 is None or len(r2[1]) < .15 * len(r[1]) * (pt.h / h2) ** 2:
        return r
    return r2


def recolor(o, colorfn, off):
    """Giảm lưới làm nhoè màu đỉnh (sọc, hoa văn): tô lại theo hàm màu tại vị trí đỉnh mới."""
    me = o.data
    n = len(me.vertices)
    co = np.zeros(n * 3, np.float32); me.vertices.foreach_get('co', co); co = co.reshape(-1, 3)
    no = np.zeros(n * 3, np.float32); me.vertices.foreach_get('normal', no); no = no.reshape(-1, 3)
    V = np.stack([co[:, 0], co[:, 2], -co[:, 1]], 1) + off   # Blender -> toạ độ dựng
    N = np.stack([no[:, 0], no[:, 2], -no[:, 1]], 1)
    C = np.clip(colorfn(V, N), 0, 1)
    L = np.where(C <= .04045, C / 12.92, ((C + .055) / 1.055) ** 2.4)
    ca = me.color_attributes.get('Col') or me.color_attributes.new('Col', 'FLOAT_COLOR', 'POINT')
    if ca.domain != 'POINT':
        return
    ca.data.foreach_set('color', np.concatenate([L, np.ones((n, 1))], 1).astype(np.float32).ravel())


def build_coords(o, off):
    """Toạ độ dựng (như hàm SDF) của các đỉnh object."""
    me = o.data
    co = np.zeros(len(me.vertices) * 3, np.float32); me.vertices.foreach_get('co', co); co = co.reshape(-1, 3)
    return np.stack([co[:, 0], co[:, 2], -co[:, 1]], 1) + off


def add_uvs(o, uv):
    """Gán UV theo đỉnh (mảng N×2 mỗi lớp) vào từng góc mặt."""
    me = o.data
    vi = np.zeros(len(me.loops), np.int64)
    me.loops.foreach_get('vertex_index', vi)
    for name, arr in zip(('UVMap', 'UV2'), uv):
        lay = me.uv_layers.new(name=name)
        lay.data.foreach_set('uv', arr[vi].ravel())


def export_acc(ids):
    S = cc.make_S(BREEDS['bo'], 'duc')
    cc.configure(S)
    socks = cc.sockets()
    META['bo_head'] = head_info()
    META['bo_sockets'] = socks
    for aid in ids:
        bl.reset()
        parts, opt = acc.ACC[aid]()
        coll = bpy.data.collections.new('PK')
        bpy.context.scene.collection.children.link(coll)
        objs, info = [], {}
        for pt in parts:
            if getattr(pt, 'mesh', None) is not None:
                V, F, C = pt.mesh
            else:
                s = 'head' if pt.head else SOCK.get(aid, 'back')
                r = mesh_part(pt, budget(s))
                if r is None:
                    print('EMPTY', aid, pt.name); continue
                V, F, N = r; C = pt.colorfn(V, N) if pt.colorfn else None
            s = 'head' if pt.head else SOCK.get(aid, 'back')
            mat = bl.material(pt.name, pt.color if C is None else None, attr=C is not None, kind=pt.kind,
                              rough=pt.rough, metal=pt.metal, emit=pt.emit, alpha=pt.alpha)
            pieces = []
            if s == 'feet':
                # Tách 4 chiếc theo bàn chân gần nhất, gốc ở tâm bàn chân
                cen = np.array([socks['paw' + p] for p in PAWS], np.float32)
                fc = V[F].mean(1)
                near = np.argmin(((fc[:, None, :] - cen[None]) ** 2).sum(-1), 1)
                for k, paw in enumerate(PAWS):
                    Fk = F[near == k]
                    if len(Fk) == 0:
                        continue
                    used = np.unique(Fk); remap = -np.ones(len(V), np.int64); remap[used] = np.arange(len(used))
                    pieces.append((f'{pt.name}__{paw}', V[used] - cen[k], remap[Fk].astype(np.int32),
                                   None if C is None else C[used], 'paw' + paw, cen[k]))
            else:
                org = np.asarray(socks[s], np.float32)
                pieces.append((pt.name, V - org, F, C, s, org))
            for name, Vp, Fp, Cp, sk, off in pieces:
                ob = bl.make_mesh(name, Vp, Fp, Cp, smooth=pt.smooth, coll=coll)
                ob.data.materials.append(mat)
                select_only([ob])
                for md in list(ob.modifiers):
                    bpy.ops.object.modifier_apply(modifier=md.name)
                uv = getattr(pt, 'uv', None)
                if uv is None:
                    target = PART_TRIS.get((aid, pt.name)) or min(budget(s), max(800, len(Fp) // 5))   # bộ phận nhỏ (quai, viền) không cần đủ ngân sách
                    decimate(ob, target)
                    if pt.colorfn and Cp is not None:
                        recolor(ob, pt.colorfn, off)
                    if getattr(pt, 'uvfn', None):
                        uv = pt.uvfn(build_coords(ob, off))  # đuôi khăn bay: UV tính lại trên lưới đã giảm
                        add_uvs(ob, uv)
                else:
                    add_uvs(ob, uv)  # đồ vải (áo choàng): giữ nguyên lưới để shader uốn theo UV
                bake_color(ob)
                objs.append(ob)
                info[ob.name] = dict(sock=sk, kind=pt.kind, alpha=pt.alpha, emit=pt.emit, metal=pt.metal)
                if uv is not None:
                    info[ob.name]['cloth'] = dict(hinge=[round(float(a - b), 4) for a, b in zip(pt.hinge, org)])
        if not objs:
            continue
        export(f'{OUT}/phu_kien/{aid}.glb', objs)
        META['phu_kien'][aid] = dict(objects=info, ears='down' if aid in EARS_DOWN else '', lift=opt.get('lift', 0),
                                     tris=sum(len(o.data.polygons) for o in objs))
        print('phu_kien', aid, META['phu_kien'][aid]['tris'], flush=True)
        json.dump(META, open(meta_path, 'w'), ensure_ascii=False, indent=1)


# ---------------------------------------------------------------- giống mèo

def ramp(v, a, b):
    t = max(0.0, min(1.0, (v - a) / (b - a)))
    return t * t * (3 - 2 * t)


def B(p):  # toạ độ dựng (three.js, Y lên, mèo nhìn +Z) -> Blender
    return Vector((p[0], -p[2], p[1]))


def nearest_seg(p, segs):
    """Các đoạn xương sắp theo khoảng cách từ p: (khoảng cách, tên)."""
    d = []
    for n, h, t in segs:
        sg = t - h
        kk = max(0.0, min(1.0, (p - h).dot(sg) / sg.length_squared))
        d.append(((p - (h + sg * kk)).length, n))
    d.sort()
    return d


def split2(d, w, total):
    """Chia trọng số total cho đoạn gần nhất và đoạn kề nó để chỗ gập mềm."""
    inv = [1.0 / (dist + .004) ** 3 for dist, _ in d[:2]]
    for (dist, n), iv in zip(d[:2], inv):
        w[n] = w.get(n, 0) + total * iv / sum(inv)


def rig(cat, S, k):
    """Bộ xương chính thức 22 xương như tools/bo_game.py (+ mắt, khăn) nhưng đặt theo số đo của giống (S), nhân cỡ k."""
    hc = B(S['head'][0]) * k; body = B(S['body'][0]) * k
    fl, hl = S['fl'], S['hl']
    tail = [B(p) * k for p in cc.catmull(S['tail'][0], 8)]
    # chia đuôi thành 4 đốt dài bằng nhau theo đường cong
    L = [0.0]
    for a, b in zip(tail, tail[1:]):
        L.append(L[-1] + (b - a).length)
    def at(f):
        d = f * L[-1]
        for i in range(1, len(L)):
            if L[i] >= d:
                t = (d - L[i - 1]) / max(L[i] - L[i - 1], 1e-6)
                return tail[i - 1].lerp(tail[i], t)
        return tail[-1]
    tp = [at(i / 4) for i in range(5)]
    hip = Vector((0, -hl['z'], hl['top'])) * k
    mid = Vector((0, body.y - .01 * k, body.z + .02 * k))
    bones = {
        'root': ((0, 0, 0), (0, 0, .08 * k), None),
        'hips': (tuple(hip), tuple(mid), 'root'),
        'chest': (tuple(mid), tuple(Vector((0, -fl['z'] - .02, fl['top'] + .04)) * k), 'hips'),
        'head': (tuple(hc + Vector((0, .07, -.09)) * k), tuple(hc + Vector((0, 0, .07)) * k), 'chest'),
        'tail_1': (tuple(tp[0]), tuple(tp[1]), 'hips'), 'tail_2': (tuple(tp[1]), tuple(tp[2]), 'tail_1'),
        'tail_3': (tuple(tp[2]), tuple(tp[3]), 'tail_2'), 'tail_4': (tuple(tp[3]), tuple(tp[4]), 'tail_3'),
    }
    # Chân: vai/háng -> khuỷu/gối -> cổ chân (cao 4 cm) -> mũi bàn chân, như cột chân của catcore.legs_sdf.
    # Khớp giữa đặt theo tỉ lệ đoạn trên của Bơ (trước 0,51, sau 0,52), lệch nhẹ về hướng gập.
    legs = {}
    for leg, Lg, s, names, parent, frac, bend in (
            ('FL', fl, -1, ('upperarm', 'forearm', 'paw'), 'chest', .508, .006),
            ('FR', fl, 1, ('upperarm', 'forearm', 'paw'), 'chest', .508, .006),
            ('BL', hl, -1, ('thigh', 'shin', 'paw'), 'hips', .516, -.006),
            ('BR', hl, 1, ('thigh', 'shin', 'paw'), 'hips', .516, -.006)):
        x = s * Lg['x']; dz = Lg.get('off', (0, 0))[0 if s < 0 else 1]
        top = B((x, Lg['top'], Lg['z'])) * k
        ankle = B((x, .04, Lg['z'] + .005 + dz)) * k
        joint = top.lerp(ankle, frac) + Vector((0, bend, 0)) * k
        toe = ankle + Vector((0, -.045, -.028)) * k
        segs = [(f'{names[0]}_{leg}', top, joint), (f'{names[1]}_{leg}', joint, ankle), (f'{names[2]}_{leg}', ankle, toe)]
        prev = parent
        for n, h, t in segs:
            bones[n] = (tuple(h), tuple(t), prev)
            prev = n
        legs[leg] = segs
    TAIL = ['tail_1', 'tail_2', 'tail_3', 'tail_4']
    me = cat.data
    mat_of = {}
    for poly in me.polygons:
        nm = me.materials[poly.material_index].name
        for vi in poly.vertices:
            mat_of[vi] = nm
    eye_pts = {'eye_L': [], 'eye_R': []}
    for v in me.vertices:
        m = mat_of.get(v.index, '')
        if m.startswith('Mat') or m.startswith('Sang'):
            eye_pts['eye_L' if v.co.x < 0 else 'eye_R'].append(v.co.copy())
    for n, pts in eye_pts.items():
        c = sum(pts, Vector()) / max(len(pts), 1)
        bones[n] = (tuple(c), tuple(c + Vector((0, 0, .03))), 'head')
    ear_z = S['ear']['base'][1] * k
    ear_pts = [v.co.copy() for v in me.vertices if v.co.z > ear_z + .01 and v.co.y < hc.y + .07 and not mat_of.get(v.index, '').startswith(('Mat', 'Sang', 'Lan'))]
    for n, side in (('ear_L', -1), ('ear_R', 1)):
        pts = [p for p in ear_pts if p.x * side > .02] or [hc + Vector((side * .07, 0, .08))]
        c = sum(pts, Vector()) / len(pts); tip = max(pts, key=lambda p: p.z)
        bones[n] = ((c.x, c.y, ear_z), tuple(tip), 'head')
    neck = B(S['neck'][0]) * k
    bones['scarf'] = (tuple(neck + Vector((0, -.03, -.01))), tuple(neck + Vector((0, -.04, -.06))), 'chest')

    arm_data = bpy.data.armatures.new('MeoRig')
    arm = bpy.data.objects.new('MeoRig', arm_data)
    bpy.context.scene.collection.objects.link(arm)
    select_only([arm])
    bpy.ops.object.mode_set(mode='EDIT')
    for name, (h, t, parent) in bones.items():
        b = arm_data.edit_bones.new(name)
        b.head, b.tail = Vector(h), Vector(t)
        d = b.tail - b.head
        if abs(d.x) < 1e-3:
            b.align_roll(Vector((0, -d.z, d.y)))  # trục X cục bộ = +X của model, như tools/bo_game.py
        if parent:
            b.parent = arm_data.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT')

    groups = {n: cat.vertex_groups.new(name=n) for n in bones if n != 'root'}
    for v in me.vertices:
        x, y, z = v.co
        w = {}
        p = Vector((x, y, z))
        for leg, segs in legs.items():
            # Phần thấp theo hẳn chân, lên gần thân chuyển dần sang chest/hips; chỉ lấy đỉnh quanh ống chân.
            # Trong chân, mỗi đỉnh chia cho 2 đoạn gần nhất (trên, dưới, bàn chân) để khuỷu/gối gập mềm.
            a_, e_ = segs[0][1], segs[1][2]
            top = a_.z - .07 * k
            ly = (a_.y + e_.y) / 2
            if abs(x - a_.x) < .06 * k and abs(y - ly) < .11 * k and z < top + .04 * k:
                d = nearest_seg(p, segs)
                r_in, r_out = ((.042, .062) if leg[0] == 'F' else (.05, .075))
                split2(d, w, ramp(z, top + .04 * k, top - .06 * k) * ramp(d[0][0], r_out * k, r_in * k))
        if y < hc.y + .12 * k and z > hc.z - .13 * k:
            w['head'] = ramp(z, hc.z - .12 * k, hc.z - .06 * k) * ramp(y, hc.y + .12 * k, hc.y + .06 * k)
        m = mat_of.get(v.index, '')
        if m.startswith('Mat') or m.startswith('Sang'):
            w = {'eye_L' if x < 0 else 'eye_R': 1.0}
        elif m.startswith('Lan_Tua'):
            pass
        elif m.startswith('Lan'):
            w = {'head': 1.0}
        elif z > ear_z and y < hc.y + .07 and abs(x) > .035 * k:
            e = 'ear_L' if x < 0 else 'ear_R'
            kk = ramp(z, ear_z, ear_z + .045 * k)
            w = {e: kk, 'head': 1.0 - kk}
        d = []
        for n in TAIL:
            h, t = Vector(bones[n][0]), Vector(bones[n][1]); sg = t - h
            kk = max(0.0, min(1.0, (p - h).dot(sg) / sg.length_squared))
            d.append(((p - (h + sg * kk)).length, n, kk))
        d.sort()
        if d[0][0] < .07 * k and y > tp[0].y - .02 * k:
            inv = [1.0 / (dist + .004) ** 3 for dist, _, _ in d[:2]]
            base = ramp(y, tp[0].y - .02 * k, tp[0].y + .02 * k) if d[0][1] == 'tail_1' else 1.0
            w = {n: val * (1 - base) for n, val in w.items()}
            for (dist, n, _), iv in zip(d[:2], inv):
                w[n] = w.get(n, 0) + base * iv / sum(inv)
        rest = max(0.0, 1.0 - sum(w.values()))
        if rest > 0:
            kc = ramp(y, mid.y + .06 * k, mid.y - .06 * k)  # nửa trước theo chest, nửa sau theo hips
            w['chest'] = w.get('chest', 0) + rest * kc
            w['hips'] = w.get('hips', 0) + rest * (1 - kc)
        for n, val in w.items():
            if val > 0.001:
                groups[n].add([v.index], val, 'REPLACE')
    cat.parent = arm
    md = cat.modifiers.new('Armature', 'ARMATURE'); md.object = arm
    return arm


def export_breeds(ids, gender='duc'):
    from parts import to_blender
    for bid in ids:
        S = cc.make_S(BREEDS[bid], gender)
        if BREEDS[bid].get('ear', {}).get('fold'):
            S['ear']['fold'] = True
        cc.configure(S)
        (V, F, N, C), _ = cc.build_body()
        bl.reset()
        coll = bpy.data.collections.new('Meo'); bpy.context.scene.collection.children.link(coll)
        kind = S['mat']
        ob = bl.make_mesh('Than', V, F, C, coll=coll)
        ob.data.materials.append(bl.material('Long', attr=True, kind={'fur': 'fur', 'skin': 'skin', 'metal': 'metal'}[kind]))
        bl.eyes(coll)
        if S.get('lion'):
            for pt in lion_parts():
                to_blender(pt, coll)
        k = S['size']
        meshes = [o for o in coll.objects if o.type == 'MESH']
        eye_c = []
        for o in meshes:
            select_only([o])
            for m_ in list(o.modifiers):
                bpy.ops.object.modifier_apply(modifier=m_.name)
            o.scale = tuple(x * k for x in o.scale); o.location = o.location * k
            bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
            if o.name.startswith('Mat'):
                eye_c.append(sum((v.co for v in o.data.vertices), Vector()) / len(o.data.vertices))
        # Giảm tam giác như bản Bơ: thân 9000 (giữ quanh mắt), tròng mắt 2400 để còn đồng tử, đốm sáng 40
        for o in meshes:
            nm = o.name
            target = 9000 if nm.startswith('Than') else 2400 if nm.startswith('Mat') else 40 if nm.startswith('Sang') else 1500
            tris = len(o.data.polygons)
            if tris > target:
                md = o.modifiers.new('Dec', 'DECIMATE'); md.ratio = target / tris
                if nm.startswith('Than') and eye_c:
                    g = o.vertex_groups.new(name='giu_mat')
                    for v in o.data.vertices:
                        dd = min((v.co - c).length for c in eye_c)
                        if dd < .08:
                            g.add([v.index], 1.0 - dd / .08, 'REPLACE')
                    md.vertex_group = 'giu_mat'; md.vertex_group_factor = 1.5; md.invert_vertex_group = True
                select_only([o]); bpy.ops.object.modifier_apply(modifier=md.name)
            bake_color(o)
        select_only(meshes)
        bpy.ops.object.join()
        cat = bpy.context.active_object; cat.name = 'Meo'
        cat.data.color_attributes.active_color = cat.data.color_attributes[0]
        arm = rig(cat, S, k)
        export(f'{OUT}/giong/{bid}_{gender}.glb', [cat, arm], skins=True)
        info = head_info()
        for key in ('hc', 'hr', 'pivot'):  # model đã nhân cỡ k (mèo cái nhỏ hơn 7%, Lân Tết to hơn 6%)
            info[key] = [a * k for a in info[key]]
        info['sockets'] = {kk: [float(a) * k for a in vv] for kk, vv in cc.sockets().items()}
        info['size'] = k
        info['tris'] = len(cat.data.polygons)
        META['giong'][f'{bid}_{gender}'] = info
        print('giong', bid, gender, info['tris'], flush=True)
        json.dump(META, open(meta_path, 'w'), ensure_ascii=False, indent=1)


if WHAT in ('phu_kien', 'all'):
    export_acc(ONLY or list(acc.ACC))
if WHAT in ('giong', 'all'):
    export_breeds(ONLY or ORDER)
if WHAT in ('giong_cai', 'all'):
    export_breeds(ONLY or ORDER, 'cai')
json.dump(META, open(meta_path, 'w'), ensure_ascii=False, indent=1)
