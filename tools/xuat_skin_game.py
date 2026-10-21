"""Xuất 35 phụ kiện và 19 giống mèo (phong cách D) sang .glb nhẹ cho tủ đồ trong game.

Dùng mã dựng của luồng "Skin mèo và phụ kiện" (meo-3d/skins: catcore, acc, breeds, blend), không render.
Chạy:  python3 tools/xuat_skin_game.py <thư_mục_skins> assets/models/skin [phu_kien|giong|all] [id,id..]
(Cần: pip install bpy scikit-image)

Kết quả:
- phu_kien/<id>.glb: mỗi bộ phận một object, toạ độ tính từ điểm gắn của nó.
  Đồ ở chân được tách thành 4 chiếc (tên kết thúc __FL, __FR, __BL, __BR), gốc ở tâm bàn chân.
- giong/<id>_duc.glb: thân + mắt, có bộ xương cùng tên với Bơ (root, spine, head, leg_*, tail_1..4, ear_*, eye_*, scarf)
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
                lo = np.asarray(pt.lo, np.float32); hi = np.asarray(pt.hi, np.float32)
                P, o = cc.grid(lo, hi, pt.h); r = cc.mesh(pt.sdf(P), o, pt.h)
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
                                   None if C is None else C[used], 'paw' + paw))
            else:
                org = np.asarray(socks[s], np.float32)
                pieces.append((pt.name, V - org, F, C, s))
            for name, Vp, Fp, Cp, sk in pieces:
                ob = bl.make_mesh(name, Vp, Fp, Cp, smooth=pt.smooth, coll=coll)
                ob.data.materials.append(mat)
                select_only([ob])
                for md in list(ob.modifiers):
                    bpy.ops.object.modifier_apply(modifier=md.name)
                decimate(ob, 1500 if s != 'feet' else 600)
                bake_color(ob)
                objs.append(ob)
                info[ob.name] = dict(sock=sk, kind=pt.kind, alpha=pt.alpha, emit=pt.emit, metal=pt.metal)
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


def rig(cat, S, k):
    """Bộ xương 16 xương như tools/bo_game.py nhưng đặt theo số đo của giống (S), nhân cỡ k."""
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
    bones = {
        'root': ((0, 0, 0), (0, 0, .08 * k), None),
        'spine': (tuple(body + Vector((0, .13, .01)) * k), tuple(body + Vector((0, -.11, .05)) * k), 'root'),
        'head': (tuple(hc + Vector((0, .07, -.09)) * k), tuple(hc + Vector((0, 0, .07)) * k), 'spine'),
        'tail_1': (tuple(tp[0]), tuple(tp[1]), 'spine'), 'tail_2': (tuple(tp[1]), tuple(tp[2]), 'tail_1'),
        'tail_3': (tuple(tp[2]), tuple(tp[3]), 'tail_2'), 'tail_4': (tuple(tp[3]), tuple(tp[4]), 'tail_3'),
    }
    legs = {}
    for n, Lg, s in (('leg_FL', fl, -1), ('leg_FR', fl, 1), ('leg_BL', hl, -1), ('leg_BR', hl, 1)):
        x, y, top = s * Lg['x'] * k, -Lg['z'] * k, Lg['top'] * k
        bones[n] = ((x, y, top), (x, y, .01), 'spine')
        legs[n] = (x, y, top - .07 * k)
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
    bones['scarf'] = (tuple(neck + Vector((0, -.03, -.01))), tuple(neck + Vector((0, -.04, -.06))), 'spine')

    arm_data = bpy.data.armatures.new('MeoRig')
    arm = bpy.data.objects.new('MeoRig', arm_data)
    bpy.context.scene.collection.objects.link(arm)
    select_only([arm])
    bpy.ops.object.mode_set(mode='EDIT')
    for name, (h, t, parent) in bones.items():
        b = arm_data.edit_bones.new(name)
        b.head, b.tail = Vector(h), Vector(t)
        if parent:
            b.parent = arm_data.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT')

    groups = {n: cat.vertex_groups.new(name=n) for n in bones if n != 'root'}
    for v in me.vertices:
        x, y, z = v.co
        w = {}
        for n, (lx, ly, top) in legs.items():
            low = z < .06 * k  # bàn chân: nới hộp để ngón chân đi theo khi nhấc chân
            if abs(x - lx) < (.06 if low else .05) * k and abs(y - ly) < (.11 if low else .075) * k and z < top + .04 * k:
                w[n] = ramp(z, top + .04 * k, top - .06 * k)
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
        p = Vector((x, y, z))
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
        w['spine'] = w.get('spine', 0) + rest
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
json.dump(META, open(meta_path, 'w'), ensure_ascii=False, indent=1)
