"""Xuất 45 phụ kiện (35 món gốc, 7 món bán theo gói trong acc_moi.py, 3 món quà Thứ Bảy trong acc_t7.py) và 19 giống mèo (phong cách D) sang .glb nhẹ cho tủ đồ trong game.

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
# Món thêm sau, đặt cạnh acc.py: acc_moi.py = 7 món bán theo gói (Sang duyệt 21/10),
# acc_t7.py = 3 món quà Thứ Bảy (G8, Sang duyệt 22/10), acc_dau.py = 13 món đội đầu làm kỹ (Sang duyệt 22/10,
# ghi đè cành mai, nón phớt, ly cà phê của hai module trước), co_duoi.py = 11 món cổ + đuôi làm kỹ,
# acc_mc.py = 11 món mặt + chân làm kỹ (Sang duyệt 22/10; đồ chân đã tách sẵn từng chiếc, tên <bộ phận>__FL...).
# Ngân sách tam giác từng bộ phận lấy theo bản đã duyệt (mon_moi/meta_<id>.json) để bản web nhẹ.
EXTRA = {}
for _mod in ('acc_moi', 'acc_t7', 'acc_dau', 'co_duoi', 'acc_mc'):
    try:
        _m = __import__(_mod)
    except ImportError:
        continue
    acc.ACC.update(_m.ACC)
    SOCK.update({k: s for k, s in getattr(_m, 'SOCK', {}).items() if s != 'face'})  # đồ mặt dựng theo đầu (Part.head)
    SOCK.update({k: 'feet' for k in getattr(_m, 'FEET', ())})
    EXTRA.update(_m.ACC)
PART_TRIS = {}
_moi = os.path.join(SKINS, 'mon_moi')
for _id in EXTRA:
    _f = os.path.join(_moi, f'meta_{_id}.json')
    if os.path.exists(_f):
        for _p in json.load(open(_f))['parts']:
            PART_TRIS[(_id, _p['name'])] = max(120, _p['tris'])
EARS_DOWN = ('mucoi', 'nonla', 'muphuthuy')
TALL_FEET = ('tatsoc', 'ungmua', 'giaypatin')
LEG_SPLIT = .045
# Sọc tất 2,2 cm, viền phản quang ủng 3 mm, chỉ khâu giày patin: tô bằng màu đỉnh nên cần lưới dày hơn ngân sách
# trên trang duyệt, giảm theo đúng ngân sách thì sọc nhoè thành vệt loang
FEET_DETAIL = {'tatsoc': 2.5, 'ungmua': 2.0, 'giaypatin': 1.6}
# Bánh xe và trục patin nhỏ: giảm theo ngân sách trang duyệt chỉ còn ~12 tam giác một bánh, lưới gãy và lật mặt
# (bánh vàng hoá đen). Giữ tối thiểu số tam giác này cho mỗi bộ phận của một chân.
PART_MIN = {('giaypatin', 'Banh_Xe'): 320, ('giaypatin', 'Truc'): 128}
# Kim loại trong game không có gì phản chiếu nên đen sì (cà mèn, 22/10): khung, trục patin dùng nhựa bóng màu bạc
METAL_GLOSS = {('giaypatin', 'Khung'), ('giaypatin', 'Truc')}
LEG_OVERLAP = .01   # phần cổ chồng xuống phần bàn 1 cm: chân gập khi chạy không hở khe
WHEEL_DZ = .03   # bánh patin: hai trục cách giữa ±3 cm theo z (acc_mc.giaypatin)


def base_name(n):
    return n[:-4] if n[-4:-2] == '__' and n[-2:] in PAWS else n
# Vành mũ rộng đổ bóng tối cả mặt trong game: phần mũ này không đổ bóng (Sang duyệt 22/10)
NO_SHADOW = {('nonla', 'Non_La'), ('mucoi', 'Mu_Coi'), ('muphuthuy', 'Mu_Phu_Thuy')}
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


# ---------------------------------------------------------------- hoa văn bằng ảnh lặp
# Ô caro nhỏ (khăn rằn, cờ đua) và chấm bi (nơ bướm) mất khi giảm lưới nếu tô bằng màu đỉnh (lỗi cũ), nên vẽ thành
# ảnh 64×64 một chu kỳ hoa văn, lặp theo UV. Toạ độ ảnh tính bằng đúng hàm hoa văn của co_duoi.py.
TEX_PX = 64


def _img(fn, px=TEX_PX):
    """fn(a, b) với a, b ∈ [0, 1) một chu kỳ -> màu sRGB (N×3)."""
    g = (np.arange(px) + .5) / px
    A, Bm = np.meshgrid(g, g)   # hàng = b (từ trên xuống), cột = a
    return np.clip(fn(A.ravel(), Bm.ravel()), 0, 1).reshape(px, px, 3)


def tex_spec(aid, name):
    """(tên ảnh, ảnh, hàm uv(V, uv_chuyển_động) -> toạ độ ảnh tính theo chu kỳ) cho bộ phận có hoa văn, hoặc None."""
    import co_duoi as cd
    from sdflib import hexc
    if aid == 'khanran' and name in ('Khan_Ran', 'Khan_Ran_Duoi'):
        cell = .0105; gm = cd.gingham(cell)
        img = ('gingham', lambda: _img(lambda a, b: gm(a * 2 * cell, b * 2 * cell)))
        if name == 'Khan_Ran':
            def uv(V, U):
                ang, hgt = cd.band_coords(V); return np.stack([ang * .055, hgt], 1) / (2 * cell)
        else:
            def uv(V, U):   # đuôi khăn: ngang theo bề rộng dải (X ∈ -1..1, nửa rộng ~2 cm), dọc theo chiều dài (~10 cm)
                return np.stack([U[:, 0] * .02, U[:, 1] * .1], 1) / (2 * cell)
        return img + (uv,)
    if aid == 'nobuom' and name == 'No_Buom':
        k = cd.neck_front(-.55, .03); side = np.array([1, 0, 0], np.float32); up = cd.nrm(cd.L()['neck'][1])
        R = np.stack([side, up, np.cross(side, up)], 1); per = 2 * np.pi / 300
        def dots(a, b):
            d = cd.sstep(.55, .75, np.sin(a * 2 * np.pi) * np.sin(b * 2 * np.pi))[:, None]
            return hexc('#2B3A67') * (1 - d) + hexc('#F4F1E8') * d
        return ('cham_bi', lambda: _img(dots), lambda V, U: cd.local(V, k, R)[:, :2] / per)
    if aid == 'coduua' and name == 'La_Co':
        def chk(a, b):
            on = ((np.floor(a * 2) + np.floor(b * 2)) % 2 == 0)[:, None]
            return np.where(on, hexc('#1F2226'), hexc('#F4F1E8'))
        return ('ca_ro', lambda: _img(chk), lambda V, U: np.stack([U[:, 1] * 3, (U[:, 0] + 1)], 1))
    return None


def save_png(path, img):
    h, w, _ = img.shape
    im = bpy.data.images.new(os.path.basename(path), w, h, alpha=False)
    lin = np.concatenate([img[::-1], np.ones((h, w, 1))], 2).astype(np.float32)   # Blender đọc ảnh từ hàng dưới lên
    im.pixels.foreach_set(lin.ravel())
    im.filepath_raw = path; im.file_format = 'PNG'; im.save()
    bpy.data.images.remove(im)


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
                r = mesh_part(pt, PART_TRIS.get((aid, pt.name)) or budget(s))
                if r is None:
                    print('EMPTY', aid, pt.name); continue
                V, F, N = r; C = pt.colorfn(V, N) if pt.colorfn else None
            s = 'head' if pt.head else SOCK.get(aid, 'back')
            mat = bl.material(pt.name, pt.color if C is None else None, attr=C is not None, kind=pt.kind,
                              rough=pt.rough, metal=pt.metal, emit=pt.emit, alpha=pt.alpha)
            pieces = []
            if s == 'feet':
                # Tách 4 chiếc theo bàn chân gần nhất, gốc ở tâm bàn chân (acc_mc đã tách sẵn: tên kết thúc __FL...)
                cen = np.array([socks['paw' + p] for p in PAWS], np.float32)
                fc = V[F].mean(1)
                if pt.name[-4:-2] == '__' and pt.name[-2:] in PAWS:
                    near = np.full(len(F), PAWS.index(pt.name[-2:]))
                    base = pt.name[:-4]
                else:
                    near = np.argmin(((fc[:, None, :] - cen[None]) ** 2).sum(-1), 1)
                    base = pt.name
                # Tất, ủng, patin cao 9–10 cm: phần cổ trên 4,5 cm theo cẳng chân (forearm/shin), phần dưới theo bàn chân
                tall = aid in TALL_FEET
                for k, paw in enumerate(PAWS):
                    for leg in ((False, True) if tall else (False,)):
                        sel = (near == k) & (((fc[:, 1] > LEG_SPLIT - LEG_OVERLAP) if leg else (fc[:, 1] <= LEG_SPLIT)) if tall else True)
                        Fk = F[sel]
                        if len(Fk) == 0:
                            continue
                        used = np.unique(Fk); remap = -np.ones(len(V), np.int64); remap[used] = np.arange(len(used))
                        Vk = V[used].copy()
                        if leg:
                            # phần chồng lùi vào trong 0,8 mm (về trục cẳng chân): đứng yên không chớp hai lớp trùng nhau
                            lo_ = Vk[:, 1] <= LEG_SPLIT
                            if lo_.any():
                                ax = Vk[~lo_][:, [0, 2]].mean(0) if (~lo_).any() else Vk[:, [0, 2]].mean(0)
                                dxz = Vk[lo_][:, [0, 2]] - ax
                                n_ = np.linalg.norm(dxz, axis=1, keepdims=True) + 1e-6
                                Vk[np.ix_(lo_, [0, 2])] = ax + dxz * np.maximum(0, 1 - .0008 / n_)
                        pieces.append((f'{base}_Co__{paw}' if leg else f'{base}__{paw}', Vk - cen[k], remap[Fk].astype(np.int32),
                                       None if C is None else C[used], ('leg' if leg else 'paw') + paw, cen[k], len(Fk) / max(1, (near == k).sum())))
            else:
                org = np.asarray(socks[s], np.float32)
                pieces.append((pt.name, V - org, F, C, s, org, 1.0))
            for name, Vp, Fp, Cp, sk, off, frac in pieces:
                ob = bl.make_mesh(name, Vp, Fp, Cp, smooth=pt.smooth, coll=coll)
                ob.data.materials.append(mat)
                select_only([ob])
                for md in list(ob.modifiers):
                    bpy.ops.object.modifier_apply(modifier=md.name)
                uv = getattr(pt, 'uv', None)
                cape = uv is not None
                if uv is None:
                    target = PART_TRIS.get((aid, pt.name))
                    target = max(int(target * frac * FEET_DETAIL.get(aid, 1.0)), PART_MIN.get((aid, base_name(pt.name)), 0)) if target else min(budget(s), max(800, len(Fp) // 5))   # bộ phận nhỏ (quai, viền) không cần đủ ngân sách
                    decimate(ob, target)
                    if pt.colorfn and Cp is not None:
                        recolor(ob, pt.colorfn, off)
                    move = getattr(pt, 'move', None) or ('vai' if getattr(pt, 'uvfn', None) else None)
                    if aid == 'giaypatin' and base_name(pt.name) in ('Banh_Xe', 'Truc'):
                        move = 'quay'
                    tx = tex_spec(aid, pt.name) if aid in getattr(sys.modules.get('co_duoi'), 'ACC', {}) else None
                    if move in ('vai', 'rung') or tx:
                        Vb = build_coords(ob, off)
                        U = pt.uvfn(Vb) if move in ('vai', 'rung') else np.zeros((len(Vb), 2), np.float32)
                        if isinstance(U, tuple):
                            U = U[0]   # khăn len (acc_moi): (UV, UV2 trống)
                        U = np.asarray(U, np.float32)
                        T2 = np.zeros_like(U)
                        if tx:
                            T2 = tx[2](Vb, U).astype(np.float32)
                            T2[:, 1] = -T2[:, 1]   # glTF lật trục dọc của UV
                        if move in ('vai', 'rung'):
                            uv = (U, T2)    # UV: chuyển động vải; UV2: hoa văn
                        else:
                            uv = (T2, np.zeros_like(T2))   # đồ đứng yên có hoa văn: UV là hoa văn
                        add_uvs(ob, uv)
                else:
                    move = 'vai'
                    tx = None
                    add_uvs(ob, uv)  # đồ vải (áo choàng): giữ nguyên lưới để shader uốn theo UV
                bake_color(ob)
                objs.append(ob)
                info[ob.name] = dict(sock=sk, kind=pt.kind, alpha=pt.alpha, emit=pt.emit, metal=pt.metal)
                if (aid, base_name(pt.name)) in METAL_GLOSS:
                    info[ob.name].update(kind='gloss', metal=0)
                if (aid, pt.name) in NO_SHADOW:
                    info[ob.name]['shadow'] = False
                if tx:
                    os.makedirs(f'{OUT}/phu_kien/tex', exist_ok=True)
                    if not os.path.exists(f'{OUT}/phu_kien/tex/{tx[0]}.png'):
                        save_png(os.path.abspath(f'{OUT}/phu_kien/tex/{tx[0]}.png'), tx[1]())
                    info[ob.name]['tex'] = f'phu_kien/tex/{tx[0]}.png'
                if move in ('vai', 'rung', 'lac', 'quay'):
                    cl = dict(hinge=[round(float(a - b), 4) for a, b in zip(pt.hinge, off)]) if move != 'quay' else {}
                    if move == 'rung':
                        cl['amp'] = .25
                    if getattr(pt, 'flagmode', False):
                        cl['mode'] = 1
                    if move == 'quay':
                        # 4 bánh patin (2 trục, cách tâm bàn chân ±3 cm theo z): quay quanh trục x theo quãng đường
                        # tâm lấy từ chính lưới bánh: giữa 4 bánh (y = tâm bánh, z = giữa hai trục)
                        cw = build_coords(ob, off)
                        cw = (cw.min(0) + cw.max(0)) / 2 - np.asarray(off)
                        cl = dict(mode=3, hinge=[round(float(c_), 4) for c_ in cw], axle=WHEEL_DZ)
                    if move == 'lac':
                        cl['mode'] = 2
                        cy = build_coords(ob, off)[:, 1].mean()
                        cl['dir'] = -1 if cy > pt.hinge[1] else 1   # bóng bay ở trên điểm treo
                    if not cape:
                        cl['ridge'] = 0   # chỉ áo choàng dùng UV2 để bung phẳng
                    info[ob.name]['cloth'] = cl
        if not objs:
            continue
        # Cả món đồ treo lắc như một khối: mọi bộ phận theo hướng của bộ phận treo đầu tiên (chuông, ông sao, bóng)
        lac = [o['cloth'] for o in info.values() if o.get('cloth', {}).get('mode') == 2]
        for c_ in lac:
            c_['dir'] = lac[0]['dir']
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
