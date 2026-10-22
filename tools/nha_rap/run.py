"""Render + xuất bản game cho P2. Dùng: python3 run.py manh|nha|moc|xa <outdir> [tên,...]
LITE=1 python3 run.py ... : chỉ xuất .glb bản game (một vật liệu + màu đỉnh, vật liệu "son" cho tường) + meta JSON."""
import sys, os, math, json
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
from bo_rap import *
import bo_rap, kit
import bpy
from mathutils import Vector

MODE = sys.argv[1]; OUT = sys.argv[2]; ONLY = sys.argv[3].split(',') if len(sys.argv) > 3 else None
os.makedirs(OUT, exist_ok=True)
_BO = {}

def reset(night=False):
    bpy.ops.wm.read_factory_settings(use_empty=True); kit._MATS.clear(); kit.PARENT[0] = None; _BO.clear()
    NIGHT[0] = night
    sc = bpy.context.scene
    w = bpy.data.worlds.new('W'); sc.world = w
    if w.node_tree is None: w.use_nodes = True
    bg = w.node_tree.nodes['Background']
    bg.inputs['Color'].default_value = lin('#1E2A44' if night else '#B9D9D2'); bg.inputs['Strength'].default_value = .25 if night else .5
    l = bpy.data.lights.new('Sun', 'SUN'); l.energy = .25 if night else 2.8; l.angle = .12; l.color = (.7, .8, 1) if night else (1, .95, .86)
    o = bpy.data.objects.new('Sun', l); sc.collection.objects.link(o); o.rotation_euler = (math.radians(50), 0, math.radians(-35))
    sc.render.engine = 'BLENDER_EEVEE'
    try: sc.eevee.taa_render_samples = 32
    except Exception: pass
    try: sc.eevee.use_shadows = True; sc.eevee.use_raytracing = False
    except Exception: pass
    sc.view_settings.view_transform = 'Standard'; sc.view_settings.look = 'None'
    cd = bpy.data.cameras.new('Cam'); cam = bpy.data.objects.new('Cam', cd); sc.collection.objects.link(cam); sc.camera = cam
    sc.render.film_transparent = False
    return sc, cam, cd

def ground(size=300, col='#ABA593'):
    bpy.ops.mesh.primitive_plane_add(size=size); g = bpy.context.active_object; g.data.materials.append(M(col, .95)); g.location.z = -.005; g.name = 'nen'
    return g

def bo(loc, rot=0.0):
    sc = bpy.context.scene
    if 'c' not in _BO:
        c = bpy.data.collections.new('BoSrc'); before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=os.path.join(HERE, 'chung2.glb'))
        for o in set(bpy.data.objects) - before:
            for cl in o.users_collection: cl.objects.unlink(o)
            c.objects.link(o)
        _BO['c'] = c
    e = bpy.data.objects.new('Bo', None); e.instance_type = 'COLLECTION'; e.instance_collection = _BO['c']
    e.location = loc; e.rotation_euler = (0, 0, rot); sc.collection.objects.link(e)
    return e

def look(cam, cd, loc, tgt, lens=35, ortho=None):
    cam.location = Vector(loc); cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    if ortho: cd.type = 'ORTHO'; cd.ortho_scale = ortho
    else: cd.type = 'PERSP'; cd.lens = lens
    cd.clip_end = 1000

def render(path, w=1000, h=1000):
    sc = bpy.context.scene; sc.render.resolution_x = w; sc.render.resolution_y = h
    sc.render.filepath = path; bpy.ops.render.render(write_still=True); print('saved', path, flush=True)

def views(cam, cd, name, w, h, d=D, front=True, side=True, back=True, q34=True, res=900, cx=None, front_y=-1.5):
    cx = w / 2 if cx is None else cx; s = max(w, h, d) * 1.18; cz = h / 2
    if front: look(cam, cd, (cx, -60, cz), (cx, 0, cz), ortho=max(w, h) * 1.18); render(f'{OUT}/{name}_truoc.png', res, res)
    if side: look(cam, cd, (cx + 60, d / 2 + front_y / 2, cz), (cx, d / 2 + front_y / 2, cz), ortho=max(d - front_y, h) * 1.18); render(f'{OUT}/{name}_ngang.png', res, res)
    if back: look(cam, cd, (cx, 60, cz), (cx, 0, cz), ortho=max(w, h) * 1.18); render(f'{OUT}/{name}_sau.png', res, res)
    if q34:
        dist = s * 1.6
        look(cam, cd, (cx - dist * .62, -dist * .78, cz + dist * .42), (cx, d * .3, cz * .9), lens=40); render(f'{OUT}/{name}_q34.png', res, res)

# ---------------------------------------------------------------- xuất bản game
def _flat(m):
    if m is None: return (.8, .8, .8)
    b = m.node_tree.nodes.get('Principled BSDF') if m.node_tree else None
    return tuple(b.inputs['Base Color'].default_value[:3]) if b else (.8, .8, .8)

_dem = {}
def export(name, target, paint=None, extra=None):
    sc = bpy.context.scene
    bpy.context.view_layer.update(); marks = {}
    for o in sc.objects:
        if o.type == 'EMPTY' and o.name.startswith('gan_'):
            p = o.matrix_world.translation; marks.setdefault(o.name.split('.')[0], []).append([round(p.x, 2), round(p.z, 2), round(-p.y, 2)])
    for o in sc.objects:
        for md in list(o.modifiers):
            if md.type == 'BEVEL': o.modifiers.remove(md)
        if o.type == 'FONT': o.data.resolution_u = 1; o.data.bevel_depth = 0
        if o.type == 'CURVE': o.data.bevel_resolution = 0; o.data.use_fill_caps = False
    dg = bpy.context.evaluated_depsgraph_get(); parts = []
    for o in list(sc.objects):
        if o.type not in ('MESH', 'FONT', 'CURVE') or o.name.startswith('nen'): continue
        me = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
        if len(me.polygons) == 0: continue
        me.transform(o.matrix_world)
        cols = [_flat(s.material) for s in o.material_slots] or [_flat(o.active_material)]
        col = np.zeros((len(me.vertices), 4), np.float32); col[:, 3] = 1
        for p in me.polygons: col[list(p.vertices), :3] = cols[min(p.material_index, len(cols) - 1)]
        ca = me.color_attributes.new('Col', 'FLOAT_COLOR', 'POINT'); ca.data.foreach_set('color', col.ravel()); me.materials.clear()
        p = bpy.data.objects.new(name, me); sc.collection.objects.link(p); parts.append(p)
        if os.environ.get('DEM'): _dem[o.name.split('.')[0]] = _dem.get(o.name.split('.')[0], 0) + sum(len(q.vertices) - 2 for q in me.polygons)
    if os.environ.get('DEM'): print('dem', name, sorted(_dem.items(), key=lambda kv: -kv[1])[:8]); _dem.clear()
    for o in list(sc.objects):
        if o not in parts: bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.object.select_all(action='DESELECT')
    for p in parts: p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    if len(parts) > 1: bpy.ops.object.join()
    g = bpy.context.active_object; g.name = name; me = g.data
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.remove_doubles(threshold=.0005); bpy.ops.object.mode_set(mode='OBJECT')
    raw = sum(len(pl.vertices) - 2 for pl in me.polygons)
    if raw > target:
        md = g.modifiers.new('Dec', 'DECIMATE'); md.ratio = target / raw; md.use_collapse_triangulate = True; bpy.ops.object.modifier_apply(modifier='Dec')
    me.materials.append(bpy.data.materials.new('pho_mausac'))
    if paint:   # mặt tường mang màu sơn -> vật liệu thứ hai "son" để game đổi 10 màu
        me.materials.append(bpy.data.materials.new('son'))
        son = np.array(lin(SON.get(paint, paint))[:3], np.float32); cc = np.empty(len(me.vertices) * 4, np.float32)
        me.color_attributes['Col'].data.foreach_get('color', cc); cc = cc.reshape(-1, 4)
        for pl in me.polygons:
            if all(np.abs(cc[v, :3] - son).max() < .02 for v in pl.vertices): pl.material_index = 1
    me.color_attributes.active_color = me.color_attributes['Col']
    me.polygons.foreach_set('use_smooth', [False] * len(me.polygons))
    co = np.empty(len(me.vertices) * 3, np.float32); me.vertices.foreach_get('co', co); co = co.reshape(-1, 3); lo, hi = co.min(0), co.max(0)
    tris = sum(len(pl.vertices) - 2 for pl in me.polygons)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + '.glb'), use_selection=True, export_apply=True, export_vertex_color='ACTIVE',
                              export_texcoords=False, export_normals=True, export_materials='EXPORT', export_yup=True)
    meta = dict(tris=tris, tho=raw, muc_tieu=target, min=[round(float(lo[0]), 2), round(float(lo[2]), 2), round(float(-hi[1]), 2)],
                max=[round(float(hi[0]), 2), round(float(hi[2]), 2), round(float(-lo[1]), 2)], gan=marks)
    if extra: meta.update(extra)
    json.dump(meta, open(os.path.join(OUT, name + '.json'), 'w'), ensure_ascii=False, indent=1); print('exported', name, tris, raw, flush=True)
    return meta

def want(n): return ONLY is None or n in ONLY

PAINTS = list(SON)

# ---------------------------------------------------------------- các chế độ
def do_manh():
    i = 0
    for kind, table, names in (('tret', TRET, TRET_TEN), ('lau', LAU, LAU_TEN), ('mai', MAI, MAI_TEN)):
        for k, fn in table.items():
            nm = f'{kind}_{k}'; paint = PAINTS[i % len(PAINTS)]; i += 1
            if not want(nm): continue
            for wd in ((4.0,) if not LITE else WIDTHS if os.environ.get('ALLW') else (4.0,)):
                sc, cam, cd = reset()
                prof = None
                if kind == 'tret':
                    if k in BANG: fn(wd, paint, 1, *BANG[k][0])
                    else: fn(wd, paint, 1)
                elif kind == 'lau': fn(wd, 0.0, paint, 1)
                else:
                    if not LITE: boxab((0, 0, -.6), (wd, D, 0), W(paint), 0).name = 'nen_tuong'   # đoạn tường để mái có chỗ đặt (không xuất)
                    prof = fn(wd, 0.0, paint, 1)
                if LITE:
                    tgt = 900 if kind == 'tret' else 600
                    export(f'{nm}_{int(wd * 10)}', tgt, paint, dict(kieu=kind, ten=names[k], rong=wd, mai=prof))
                    continue
                ground(); h = G0 if kind == 'tret' else (F if kind == 'lau' else 3.0)
                if kind == 'tret': bo((wd * .8, -1.2, 0), math.radians(-20))
                look(cam, cd, (wd / 2, -40, h / 2 + .3), (wd / 2, 0, h / 2 + .3), ortho=max(wd, h) * 1.3); render(f'{OUT}/{nm}_truoc.png', 700, 700)
                look(cam, cd, (wd / 2 - 3.4, -4.6, h * .5 + 2.2), (wd / 2, .8, h * .45), lens=24); render(f'{OUT}/{nm}_q34.png', 700, 700)

def do_nha():
    if LITE:
        for i, s in enumerate(NHA12):
            nm = f'nha_{i + 1:02d}'
            if not want(nm): continue
            reset(); g, prof, top = nha(nm, s)
            export(nm, 900 * (2 + len(s['lau'])), s['son'], dict(spec=s, cao=top))
        return
    sc, cam, cd = reset(); ground()
    x = 0; xs = []
    for i, s in enumerate(NHA12):
        nha(f'nha_{i + 1:02d}', s, (x, 0, 0)); xs.append(x); x += s['w']
    L = x
    boxab((-2, -3.4, 0), (L + 2, 0, .12), M(C['sidewalk'], .9), .01)
    boxab((-2, -3.5, 0), (L + 2, -3.3, .16), M(C['curb'], .9), .01)
    bo((xs[0] + 2.2, -2.2, .12), math.radians(-30))
    if want('pho_truoc'):
        look(cam, cd, (L / 2, -120, 8), (L / 2, 0, 8), ortho=L * 1.04); render(f'{OUT}/pho_truoc.png', 2400, 800)
    if want('pho_via_he'):
        look(cam, cd, (xs[0] - 1.5, -6.5, 1.5), (xs[4], 0, 4.5), lens=24); render(f'{OUT}/pho_via_he.png', 1600, 1000)
    if want('pho_q34'):
        look(cam, cd, (L * .15, -38, 30), (L * .5, 4, 3), lens=30); render(f'{OUT}/pho_q34.png', 1800, 1000)
    if want('pho_mai'):
        look(cam, cd, (L / 2, 2, 90), (L / 2, 3.6, 0), ortho=L * 1.04); render(f'{OUT}/pho_mai.png', 2400, 700)
    if want('pho_dem'):
        sc, cam, cd = reset(True); ground(col='#5E5B54')
        x = 0
        for i, s in enumerate(NHA12): nha(f'nha_{i + 1:02d}', s, (x, 0, 0)); x += s['w']
        boxab((-2, -3.4, 0), (L + 2, 0, .12), M(C['sidewalk'], .9), .01)
        look(cam, cd, (L * .15, -38, 30), (L * .5, 4, 3), lens=30); render(f'{OUT}/pho_dem.png', 1800, 1000)
    if want('tach'):
        for idx in (0, 6):
            sc, cam, cd = reset(); ground()
            s = NHA12[idx]; nha('tach', s, (0, 0, 0), explode=1.6)
            n = len(s['lau']); H = G0 + F * n + 3 + 1.6 * (n + 1)
            look(cam, cd, (s['w'] / 2 - 14, -17, H * .6 + 3), (s['w'] / 2, 2, H * .45), lens=40); render(f'{OUT}/tach_{idx + 1:02d}.png', 900, 1100)

def do_moc():
    for k, fn in MOC.items():
        if not want(k): continue
        sc, cam, cd = reset();
        if not LITE: ground()
        g, info = fn(k)
        if LITE:
            export(k, dict(nha_dang_xay=5000, biet_thu=8000, mieu=2500, mau_giao=7000, chung_cu_2=12000)[k], None, dict(ten=MOC_TEN[k], info=info))
            continue
        bpy.context.view_layer.update()
        lo = np.array([1e9] * 3); hi = -lo
        for o in sc.objects:
            if o.type in ('MESH', 'FONT', 'CURVE') and o.name != 'nen':
                for c in o.bound_box:
                    p = o.matrix_world @ Vector(c); lo = np.minimum(lo, p); hi = np.maximum(hi, p)
        w = hi[0] - lo[0]; h = hi[2]; d = hi[1] - lo[1]; cx = (lo[0] + hi[0]) / 2
        if k == 'nha_dang_xay': bo((2.9, -.9, 4.47), math.radians(-60))
        if k == 'mieu': bo((.5, -.9, 0), math.radians(-40))
        if k in ('biet_thu', 'mau_giao'): bo((cx + 1.5, lo[1] - .4, 0), math.radians(-30))
        res = 900
        s = max(w, h, d) * 1.15
        look(cam, cd, (cx, -80, h / 2), (cx, 0, h / 2), ortho=max(w, h) * 1.15); render(f'{OUT}/{k}_truoc.png', res, res)
        look(cam, cd, (80, (lo[1] + hi[1]) / 2, h / 2), (0, (lo[1] + hi[1]) / 2, h / 2), ortho=max(d, h) * 1.15); render(f'{OUT}/{k}_ngang.png', res, res)
        look(cam, cd, (cx, 80, h / 2), (cx, 0, h / 2), ortho=max(w, h) * 1.15); render(f'{OUT}/{k}_sau.png', res, res)
        dist = s * 1.5
        look(cam, cd, (cx - dist * .6, lo[1] - dist * .75, h * .5 + dist * .4), (cx, (lo[1] + hi[1]) / 2, h * .42), lens=40); render(f'{OUT}/{k}_q34.png', 1200, 900)
        if k == 'nha_dang_xay':
            look(cam, cd, (-4.5, -6.5, 3.5), (3, -.9, 4.5), lens=30); render(f'{OUT}/{k}_leo.png', 1200, 900)
        if k == 'chung_cu_2':
            sc, cam, cd = reset(True); ground(col='#5E5B54'); fn(k)
            look(cam, cd, (cx - dist * .6, lo[1] - dist * .75, h * .5 + dist * .4), (cx, (lo[1] + hi[1]) / 2, h * .42), lens=40); render(f'{OUT}/{k}_dem.png', 1200, 900)

def do_xa():
    if LITE:
        for i, s in enumerate(NHA12):
            for fo in (False, True):
                nm = f'xa_{i + 1:02d}' + ('_mong' if fo else '')
                if not want(nm): continue
                reset(); nha_xa(nm, s, front_only=fo)
                export(nm, 400, s['son'], dict(spec=s))
        return
    sc, cam, cd = reset(); ground()
    x = 0
    for i, s in enumerate(NHA12[:6]): nha(f'n{i}', s, (x, 0, 0)); x += s['w']
    L = x; x = 0
    for i, s in enumerate(NHA12[:6]): nha_xa(f'x{i}', s, (x + L + 4, 0, 0)); x += s['w']
    look(cam, cd, (L + 2, -90, 25), (L + 2, 0, 5), lens=50); render(f'{OUT}/xa_so_sanh.png', 1800, 800)
    look(cam, cd, (L + 2, -30, 12), (L + 2, 0, 5), lens=35); render(f'{OUT}/xa_gan.png', 1800, 800)

def do_mau():
    """Tờ bảng màu: 10 màu sơn trên cùng một căn."""
    sc, cam, cd = reset(); ground()
    x = 0
    for i, p in enumerate(PAINTS):
        s = dict(w=3.2, tret='nha_o', lau=['cua_chop'], mai='san_thuong', son=p, seed=i)
        nha(f'm{i}', s, (x, 0, 0)); x += 3.4
    look(cam, cd, (x / 2, -80, 4.5), (x / 2, 0, 4.5), ortho=x * 1.03); render(f'{OUT}/bang_mau.png', 2400, 650)

def do_bang():
    """Tờ 21 bảng hiệu: mỗi hàng một kiểu tiệm, ba cột ba bảng, ngang 4,0 m. Thêm bản nhìn chéo và bản tối."""
    for night in (False, True):
        sc, cam, cd = reset(night)
        rows = list(BANG.items())
        for r, (shop, lst) in enumerate(rows):
            for c, (nm, sb) in enumerate(lst):
                g = group(f'b{r}{c}', (c * 4.4, 0, -r * 1.2 - 2.92 + 8.4))
                with at(g):
                    boxab((-.1, 0, 2.4), (4.1, .2, 3.45), M('#D6D0C2' if not night else '#8E897E', .9), 0)
                    boxab((-.1, -.05, 2.42), (4.1, .2, 2.52), M(TRIM, .8), 0)
                    bang_hieu(nm, sb, 4.0)
        W_, H_ = 3 * 4.4, 7 * 1.2
        cx, cz = W_ / 2 - .2, 8.4 - H_ / 2 + .6
        if not night:
            look(cam, cd, (cx, -60, cz), (cx, 0, cz), ortho=W_ * 1.04); render(f'{OUT}/bang_tat_ca.png', 1800, 1250)
            look(cam, cd, (cx - 7, -9, cz - 3.5), (cx, 0, cz), lens=30); render(f'{OUT}/bang_cheo.png', 1800, 1250)
        else:
            look(cam, cd, (cx, -60, cz), (cx, 0, cz), ortho=W_ * 1.04); render(f'{OUT}/bang_dem.png', 1800, 1250)


# ---------------------------------------------------------------- bản cho game Godot (GAME=1 LITE=1, tools/nha_rap/README.md)
def slug(t):
    import unicodedata
    t = unicodedata.normalize('NFD', t.replace('Đ', 'D').replace('đ', 'd'))
    return '_'.join(''.join(c for c in t if unicodedata.category(c) != 'Mn').lower().split())

def do_tret_game():
    """8 mảnh trệt x 4 bề ngang, không bạt, không bảng hiệu (game tự đặt mái hiên và bảng)."""
    for i, (k, fn) in enumerate(TRET.items()):
        if not want(f'tret_{k}'): continue
        paint = PAINTS[i % len(PAINTS)]
        for wd in WIDTHS:
            reset()
            if k in BANG: fn(wd, paint, 1, *BANG[k][0])
            else: fn(wd, paint, 1)
            export(f'tret_{k}_{int(wd * 10)}', 900, paint, dict(kieu='tret', ten=TRET_TEN[k], rong=wd, mai=None))

def do_bang_game():
    """21 bảng hiệu x 4 bề ngang, mỗi tấm một .glb (khung + hình vẽ, không chữ) + chu.json (khung chữ cho atlas)."""
    chu = {}
    for k, lst in BANG.items():
        for nm, sb in lst:
            sl = slug(nm)
            for wd in WIDTHS:
                reset(); BH.GAME_CHU = []
                bang_hieu(nm, sb, wd)
                export(f'bang_{sl}_{int(wd * 10)}', 500, None, dict(kieu='bang', tiem=k, ten=nm, phu=sb, rong=wd))
                chu[f'bang_{sl}_{int(wd * 10)}'] = BH.GAME_CHU
            BH.GAME_CHU = None
    json.dump(chu, open(os.path.join(OUT, 'chu.json'), 'w'), ensure_ascii=False, indent=1)

dict(tret_game=do_tret_game, bang_game=do_bang_game, bang=do_bang, manh=do_manh, nha=do_nha, moc=do_moc, xa=do_xa, mau=do_mau)[MODE]()
