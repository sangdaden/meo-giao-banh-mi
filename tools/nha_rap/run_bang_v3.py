"""Bảng hiệu vòng 3 (Sang duyệt 27/10): render cho trang duyệt và xuất bản game. Hình bảng ở bang_v3.py.
python3 run_bang_v3.py <che_do> <outdir> [ten,...]
  che_do: thu | hero | gen | pho | glb (trang duyệt; pho cần chung2.glb của gói phác thảo đặt cạnh script)
          game (LITE=1: mỗi bảng một .glb không chữ + chu.json cho atlas_chu_v3.py), xem README.md"""
import sys, os, math, json
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
os.environ.setdefault('GAME', '1')            # mảnh trệt kiểu game: không bạt riêng, không bảng cũ
import bo_rap
from bo_rap import nha, G0, F
import kit
from kit import M, C, box, boxab, cyl, group, at, lin
import bang_hieu as BH
import bang_v3 as V
import bpy
from mathutils import Vector

MODE = sys.argv[1]; OUT = sys.argv[2]; ONLY = sys.argv[3].split(',') if len(sys.argv) > 3 else None
os.makedirs(OUT, exist_ok=True)
_BO = {}
SB = 3.02     # đáy bảng trong game

def reset(night=False, bg=None):
    bpy.ops.wm.read_factory_settings(use_empty=True); kit._MATS.clear(); kit.PARENT[0] = None; _BO.clear()
    BH.NIGHT[0] = night
    sc = bpy.context.scene
    w = bpy.data.worlds.new('W'); sc.world = w
    if w.node_tree is None: w.use_nodes = True
    b = w.node_tree.nodes['Background']
    b.inputs['Color'].default_value = lin(bg or ('#1E2A44' if night else '#B9D9D2')); b.inputs['Strength'].default_value = .2 if night else .55
    l = bpy.data.lights.new('Sun', 'SUN'); l.energy = .2 if night else 2.8; l.angle = .12; l.color = (.7, .8, 1) if night else (1, .95, .86)
    o = bpy.data.objects.new('Sun', l); sc.collection.objects.link(o); o.rotation_euler = (math.radians(52), 0, math.radians(-30))
    sc.render.engine = 'BLENDER_EEVEE'
    try: sc.eevee.taa_render_samples = 24
    except Exception: pass
    try: sc.eevee.use_shadows = True; sc.eevee.use_raytracing = False
    except Exception: pass
    sc.view_settings.view_transform = 'Standard'; sc.view_settings.look = 'None'
    cd = bpy.data.cameras.new('Cam'); cam = bpy.data.objects.new('Cam', cd); sc.collection.objects.link(cam); sc.camera = cam
    return sc, cam, cd

def ground(col='#B8B2A2', size=300):
    bpy.ops.mesh.primitive_plane_add(size=size); g = bpy.context.active_object; g.data.materials.append(M(col, .95)); g.location.z = -.005; g.name = 'nen'

def wall(x0, x1, z0, z1, col='#D6D0C2', y=.02):
    boxab((x0, y, z0), (x1, y + .3, z1), M(col, .9), 0)

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

def look(cam, cd, loc, tgt, lens=35, ortho=None):
    cam.location = Vector(loc); cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    if ortho: cd.type = 'ORTHO'; cd.ortho_scale = ortho
    else: cd.type = 'PERSP'; cd.lens = lens
    cd.clip_end = 1000

def render(path, w=1000, h=1000):
    sc = bpy.context.scene; sc.render.resolution_x = w; sc.render.resolution_y = h
    sc.render.filepath = path; bpy.ops.render.render(write_still=True); print('saved', path, flush=True)

def want(n): return ONLY is None or n in ONLY

def awning_strip(x0, x1, y_face, col=('#D9553F', '#F1ECE2')):
    """Mái hiên game: mặt trên 2,96 m, sâu 1 m."""
    n = int((x1 - x0) / .4)
    for k in range(n):
        boxab((x0 + k * (x1 - x0) / n, y_face - 1.0, 2.86), (x0 + (k + 1) * (x1 - x0) / n, y_face, 2.96), M(col[k % 2], .7), 0)

# ---------------------------------------------------------------- một bảng (4 góc, tách, đêm, cạnh Bơ)
def one(key, w=None):
    w = w or (V.HERO[key][2] if key in V.HERO else 4.0)
    hz = 3.0 if key in V.HERO else 2.8
    for night in (False, True):
        sc, cam, cd = reset(night, '#9DB7B0' if not night else None)
        ground('#8F8B80')
        wall(-.3, w + .3, -.6, 3.6, '#C9BFA8' if not night else '#6E685C')
        V.make(key, w, (0, 0, .6))
        cz = .6 + hz / 2 - .1
        if not night:
            look(cam, cd, (w / 2, -40, cz), (w / 2, 0, cz), ortho=max(w, hz) * 1.12); render(f'{OUT}/{key}_truoc.png', 1200, 800)
            look(cam, cd, (w / 2 - 6.0, -6.2, cz + 1.4), (w / 2, -.2, cz), lens=40); render(f'{OUT}/{key}_q34.png', 1200, 800)
            # nhìn dọc phố (góc người chơi chạy vỉa hè): rất xiên
            look(cam, cd, (w + 7.5, -2.2, 1.0), (w / 2, -.3, cz), lens=32); render(f'{OUT}/{key}_doc_pho.png', 1200, 800)
            # ngang + sau: bỏ tường
            for o in list(sc.objects):
                if o.type == 'MESH' and o.dimensions.y > .29 and abs(o.dimensions.y - .3) < .01: bpy.data.objects.remove(o, do_unlink=True)
            look(cam, cd, (w + 30, -.5, cz), (w / 2, -.5, cz), ortho=hz * 1.25); render(f'{OUT}/{key}_ngang.png', 800, 800)
            look(cam, cd, (w / 2, 40, cz), (w / 2, 0, cz), ortho=max(w, hz) * 1.12); render(f'{OUT}/{key}_sau.png', 1200, 800)
        else:
            look(cam, cd, (w / 2 - 6.0, -6.2, cz + 1.4), (w / 2, -.2, cz), lens=40); render(f'{OUT}/{key}_dem.png', 1200, 800)
    # tách bộ phận
    sc, cam, cd = reset(False, '#E9E4D8'); ground('#E9E4D8')
    V.make(key, w, (0, 0, .6), explode=1.0)
    look(cam, cd, (w / 2 - 9.0, -12.0, 5.5), (w / 2 + .5, -1.0, 3.0), lens=32); render(f'{OUT}/{key}_tach.png', 1200, 900)

# ---------------------------------------------------------------- cạnh Bơ trên nhà thật (đáy bảng 3,02 m như game)
def on_house(key, spec, w=None):
    w = w or spec['w']
    sc, cam, cd = reset(False); ground('#C9C3B3')
    g, prof, top = nha('nha', dict(spec, w=w))
    front = -1.0 if spec['lau'] and spec['lau'][0] == 'ban_cong' else -.45
    awning_strip(0, w, -.0)
    V.make(key, w, (0, front, SB))
    bo((w * .35, -.6, 2.97), math.radians(200))      # Bơ trên mái hiên
    bo((w * .7, -1.6, 0.0), math.radians(160))       # Bơ dưới vỉa hè
    look(cam, cd, (w / 2 - 4.0, -9.5, 2.4), (w / 2, 0, 4.0), lens=30); render(f'{OUT}/{key}_canh_bo.png', 1000, 1200)

def do_thu():
    for k in (ONLY or ['lo_banh']): one(k)

def do_hero():
    specs = {'lo_banh': dict(w=5.2, tret='nha_o', lau=['cua_chop'], mai='ngoi', son='vang_nghe'),
             'cafe_may': dict(w=6.0, tret='nha_o', lau=['ban_cong'], mai='san_thuong', son='da_troi'),
             'tiem_xe': dict(w=5.5, tret='gui_xe', lau=['cua_chop'], mai='ton', son='xam_trang'),
             'tap_hoa_co_hai': dict(w=4.4, tret='tap_hoa', lau=['lo_gia', 'cua_chop'], mai='ton', son='kem')}
    for k in V.HERO:
        if not want(k): continue
        one(k); on_house(k, specs[k])

def do_gen():
    """Tờ 21 bảng: 7 hàng nghề × 3, ngang 4,0 m, ảnh thẳng + nhìn dọc phố + đêm, và từng bảng 4 góc."""
    names = list(V.GEN)
    for night in (False, True):
        sc, cam, cd = reset(night, '#7F9C9A' if not night else None)
        for i, nm in enumerate(names):
            r, c = divmod(i, 3); x = c * 4.6; z = -r * 3.2
            boxab((x - .2, .02, z - .3), (x + 4.2, .3, z + 2.9), M('#D6D0C2' if not night else '#77736A', .9), 0)
            V.make(nm, 4.0, (x, 0, z))
        W_, H_ = 3 * 4.6, 7 * 3.2
        cx, cz = W_ / 2 - .3, -H_ / 2 + 2.9
        if not night:
            look(cam, cd, (cx, -80, cz), (cx, 0, cz), ortho=H_ * 1.0); render(f'{OUT}/gen_tat_ca.png', 1300, 2000)
        else:
            look(cam, cd, (cx, -80, cz), (cx, 0, cz), ortho=H_ * 1.0); render(f'{OUT}/gen_dem.png', 1300, 2000)
    for nm in names:
        if ONLY and nm not in ONLY: continue
        sc, cam, cd = reset(False, '#9DB7B0'); ground('#8F8B80'); wall(-.3, 4.3, -.6, 3.4, '#C9BFA8')
        V.make(nm, 4.0, (0, 0, .6))
        sl = slug(nm)
        look(cam, cd, (2.0, -40, 1.9), (2.0, 0, 1.9), ortho=4.5); render(f'{OUT}/g_{sl}_truoc.png', 900, 600)
        look(cam, cd, (2.0 - 5.0, -5.5, 3.0), (2.0, -.2, 1.8), lens=40); render(f'{OUT}/g_{sl}_q34.png', 900, 600)
        for o in list(sc.objects):
            if o.type == 'MESH' and abs(o.dimensions.y - .3) < .01: bpy.data.objects.remove(o, do_unlink=True)
        look(cam, cd, (40, -.5, 1.9), (2, -.5, 1.9), ortho=3.4); render(f'{OUT}/g_{sl}_ngang.png', 600, 600)
        look(cam, cd, (2.0, 40, 1.9), (2.0, 0, 1.9), ortho=4.5); render(f'{OUT}/g_{sl}_sau.png', 900, 600)

def slug(t):
    import unicodedata
    t = unicodedata.normalize('NFD', t.replace('Đ', 'D').replace('đ', 'd'))
    return '_'.join(''.join(c for c in t if unicodedata.category(c) != 'Mn').lower().split())

def do_pho():
    """Dãy 7 căn có bảng vòng 3, nhìn từ vỉa hè như camera game; bản ngày + đêm; Bơ đứng vỉa hè và trên mái hiên."""
    row = [('lo_banh', dict(w=5.2, tret='nha_o', lau=['cua_chop'], mai='ngoi', son='vang_nghe')),
           ('HỚT TÓC BÌNH DÂN', dict(w=4.0, tret='hot_toc', lau=['ban_cong', 'cua_chop'], mai='san_thuong', son='bac_ha')),
           ('SỬA ĐIỆN THOẠI TUẤN', dict(w=4.0, tret='sua_dt', lau=['cua_chop', 'chuong_cop'], mai='ton', son='la_non')),
           ('TIỆM MAY HỒNG NHUNG', dict(w=3.2, tret='tiem_may', lau=['ban_cong'], mai='ngoi', son='hong_phan')),
           ('NHÀ THUỐC TÂM AN', dict(w=4.8, tret='tiem_thuoc', lau=['lo_gia', 'kinh_lua'], mai='tum', son='vang_chanh')),
           ('PHỞ BÀ TÁM', dict(w=4.0, tret='quan_pho', lau=['tuong_kin'], mai='ton', son='cam_dat')),
           ('cafe_may', dict(w=6.0, tret='nha_o', lau=['ban_cong'], mai='san_thuong', son='da_troi')),
           ('GIỮ XE', dict(w=4.0, tret='gui_xe', lau=['cua_chop', 'cua_chop'], mai='luoi', son='xanh_ngoc'))]
    for night in (False, True):
        sc, cam, cd = reset(night); ground('#8F8B80')
        boxab((-2, -2.0, 0), (60, 0, .04), M('#C9C3B3', .95), 0)
        x = 0.0; xs = []
        for k, (key, spec) in enumerate(row):
            if key in V.HERO: V.HERO[key]
            g, prof, top = nha(f'n{k}', dict(spec, seed=k + 3), (x, 0, 0))
            front = -1.0 if spec['lau'][0] == 'ban_cong' else (-.6 if spec['lau'][0] == 'chuong_cop' else -.45)
            awning_strip(x, x + spec['w'], 0, (('#D9553F', '#F1ECE2'), ('#3F8A5C', '#F1ECE2'), ('#2457A0', '#F1ECE2'))[k % 3])
            V.make(key, spec['w'], (x, front, SB), name=f'b{k}')
            xs.append(x); x += spec['w']
        L = x
        bo((xs[1] + 1.0, -.55, 2.97), math.radians(250)); bo((3.0, -1.4, .04), math.radians(230))
        tag = '_dem' if night else ''
        look(cam, cd, (-3.0, -3.4, 1.4), (14.0, -.6, 3.6), lens=24); render(f'{OUT}/pho_via_he{tag}.png', 1600, 900)
        if not night:
            look(cam, cd, (L / 2, -70, 4.5), (L / 2, 0, 4.5), ortho=L * 1.02); render(f'{OUT}/pho_truoc.png', 2400, 700)
            look(cam, cd, (L + 4.0, -3.4, 1.4), (L - 16.0, -.6, 3.6), lens=24); render(f'{OUT}/pho_via_he_nguoc.png', 1600, 900)
            look(cam, cd, (L * .25, -16, 6.5), (L * .5, 0, 3.8), lens=24); render(f'{OUT}/pho_q34.png', 1800, 900)

# ---------------------------------------------------------------- .glb cho khung xoay (vật liệu thật, chữ là lưới)
def glb2json(src, dst):
    """GLB -> glTF JSON có buffer base64 (trang artifact không phục vụ .glb)."""
    import struct, base64
    d = open(src, 'rb').read(); off = 12; js = bin_ = None
    while off < len(d):
        ln, typ = struct.unpack_from('<II', d, off); chunk = d[off + 8:off + 8 + ln]; off += 8 + ln
        if typ == 0x4E4F534A: js = json.loads(chunk)
        else: bin_ = chunk
    js['buffers'][0]['uri'] = 'data:application/octet-stream;base64,' + base64.b64encode(bin_).decode()
    json.dump(js, open(dst, 'w'), separators=(',', ':'))

def do_glb():
    keys = list(V.HERO) + list(V.GEN)
    stats = {}
    for k in keys:
        if ONLY and k not in ONLY: continue
        reset()
        V.make(k)
        dg = bpy.context.evaluated_depsgraph_get(); tris = {}
        for o in bpy.context.scene.objects:
            if o.type in ('MESH', 'FONT', 'CURVE'):
                me = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
                layer = o.parent.name.split('.')[0] if o.parent else '?'
                while o.parent and o.parent.parent: o = o.parent
                tris[layer] = tris.get(layer, 0) + sum(len(p.vertices) - 2 for p in me.polygons)
        sl = k if k in V.HERO else slug(k)
        stats[sl] = tris
        for o in bpy.context.scene.objects:
            if o.type == 'FONT': o.data.resolution_u = 2
        bpy.ops.object.select_all(action='SELECT')
        gp = os.path.join(OUT, sl + '.glb')
        bpy.ops.export_scene.gltf(filepath=gp, export_format='GLB', use_selection=True, export_apply=True, export_yup=True)
        glb2json(gp, os.path.join(OUT, sl + '.json'))
        print('glb', sl, tris, flush=True)
    json.dump(stats, open(os.path.join(OUT, 'tam_giac.json'), 'w'), ensure_ascii=False, indent=1)


# ---------------------------------------------------------------- bản game Godot (LITE=1 python3 run_v3.py game <outdir>)
import numpy as np
from bo_rap import SON
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


GAME_W = [3.2, 4.0, 4.8, 6.0]

def do_game():
    """25 bảng: quán thường x 4 bề ngang, quán truyện đúng bề ngang ô của nó. Mỗi tấm một .glb (khung, hình, bảng dọc,
    không chữ) + chu.json (4 góc từng dòng chữ, toạ độ Godot) cho atlas_chu_v3.py."""
    chu = {}
    jobs = [(k, V.HERO[k][2], k) for k in V.HERO] + [(n, wd, slug(n)) for n in V.GEN for wd in GAME_W]
    for key, wd, sl in jobs:
        name = f'bang_{sl}_{int(round(wd * 10))}'
        if ONLY and sl not in ONLY: continue
        reset(); V.GAME_CHU = []
        V.make(key, wd)
        meta = export(name, 1100 if key in V.HERO else 650, None, dict(kieu='bang', ten=key if key in V.HERO else key, rong=wd,
                      tiem=None if key in V.HERO else next(t for t, lst in bo_rap.BANG.items() if any(nm == key for nm, _ in lst))))
        chu[name] = V.GAME_CHU; V.GAME_CHU = None
        json.dump(meta, open(os.path.join(OUT, name + '.json'), 'w'), ensure_ascii=False, indent=1)
    json.dump(chu, open(os.path.join(OUT, 'chu.json'), 'w'), ensure_ascii=False, indent=1)

dict(game=do_game, thu=do_thu, hero=do_hero, gen=do_gen, pho=do_pho, glb=do_glb)[MODE]()
