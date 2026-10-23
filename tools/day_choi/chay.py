"""Render và xuất bản game cho 6 món sân sau lò bánh (màn dạy chơi B1, Sang duyệt 23/10/2026:
https://claude.ai/artifact/TX3MsCCPYfw4SdBqzAsixc). Món ở san_sau.py; bản game chép vào assets/models/day_choi/
(cong_sau__mo.glb đổi tên cong_sau_mo.glb). Cần pip install bpy. Chế độ render cần chung2.glb (Bơ so tỉ lệ)
để cạnh file này; bản trong /mnt/project-files/cai-thien/b1-man-day-choi/scripts/.
Dùng: python3 chay.py <id,id,...|all> <outdir> [render|game|both]
  render: ảnh trước/ngang/sau/3/4 (có Bơ so tỉ lệ) + mỗi trạng thái phụ một ảnh 3/4
  game:   bản nhẹ (≤ ngân sách tam giác, một vật liệu màu đỉnh, không chữ, không bối cảnh) .glb + .json cho trang xoay
In manifest_<id>.json cạnh ảnh."""
import sys, os, math, json
import numpy as np
import bpy, bmesh
from mathutils import Vector
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import kit
kit.FONT = '/usr/share/fonts/opentype/inter/Inter-ExtraBold.otf'
import san_sau as do_pho

if __name__ == '__main__':
    IDS = [i[0] for i in do_pho.ITEMS] if sys.argv[1] == 'all' else sys.argv[1].split(',')
    OUT = sys.argv[2]; MODE = sys.argv[3] if len(sys.argv) > 3 else 'both'
    os.makedirs(OUT, exist_ok=True)
NO_GAME_STATE = {"toi"}   # cùng lưới, chỉ đổi độ sáng


def reset(night=False):
    bpy.ops.wm.read_factory_settings(use_empty=True); kit._MATS.clear(); kit.PARENT[0] = None; _BO.clear()
    sc = bpy.context.scene
    w = bpy.data.worlds.new('W'); sc.world = w
    if w.node_tree is None: w.use_nodes = True
    bg = w.node_tree.nodes['Background']
    bg.inputs['Color'].default_value = kit.lin('#1E2A44' if night else '#C9DCD6'); bg.inputs['Strength'].default_value = .25 if night else .55
    l = bpy.data.lights.new('Sun', 'SUN'); l.energy = .25 if night else 2.8; l.angle = .15
    l.color = (.7, .8, 1.0) if night else (1, .95, .86)
    o = bpy.data.objects.new('Sun', l); sc.collection.objects.link(o); o.rotation_euler = (math.radians(48), 0, math.radians(-32))
    sc.render.engine = 'BLENDER_EEVEE'
    try: sc.eevee.taa_render_samples = 48
    except Exception: pass
    try: sc.eevee.use_shadows = True; sc.eevee.use_raytracing = False
    except Exception: pass
    try: sc.eevee.shadow_pool_size = '1024'
    except Exception: pass
    if night:
        try: sc.eevee.use_bloom = True
        except Exception: pass
    sc.view_settings.view_transform = 'Standard'; sc.view_settings.look = 'None'
    sc.render.film_transparent = False
    cd = bpy.data.cameras.new('Cam'); cam = bpy.data.objects.new('Cam', cd); sc.collection.objects.link(cam); sc.camera = cam
    return sc, cam, cd


def ground(night=False):
    """Sàn lưới 0,5 m để đo kích thước."""
    me = bpy.data.meshes.new('San'); s = 60
    me.from_pydata([(-s, -s, -.06), (s, -s, -.06), (s, s, -.06), (-s, s, -.06)], [], [(0, 1, 2, 3)])
    o = bpy.data.objects.new('San', me); bpy.context.scene.collection.objects.link(o)
    m = bpy.data.materials.new('san'); m.use_nodes = True; nt = m.node_tree
    ck = nt.nodes.new('ShaderNodeTexChecker'); ck.inputs['Scale'].default_value = 2.0
    ck.inputs['Color1'].default_value = kit.lin('#D9D3C4'); ck.inputs['Color2'].default_value = kit.lin('#CDC6B5')
    tc = nt.nodes.new('ShaderNodeTexCoord'); nt.links.new(tc.outputs['Object'], ck.inputs['Vector'])
    bs = nt.nodes['Principled BSDF']; nt.links.new(ck.outputs['Color'], bs.inputs['Base Color']); bs.inputs['Roughness'].default_value = .95
    me.materials.append(m)
    return o


_BO = {}
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


def bbox(objs):
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    lo = Vector([min(p[i] for p in pts) for i in range(3)]); hi = Vector([max(p[i] for p in pts) for i in range(3)])
    return lo, hi, pts


def item_objs():
    return [o for o in bpy.context.scene.objects if o.type in ('MESH', 'CURVE', 'FONT') and o.name != 'San']


def shoot(cam, cd, path, dirv, pts, res=(900, 900), pad=1.12, persp=False):
    sc = bpy.context.scene; d = Vector(dirv).normalized()
    lo = Vector([min(p[i] for p in pts) for i in range(3)]); hi = Vector([max(p[i] for p in pts) for i in range(3)])
    ctr = (lo + hi) / 2; size = (hi - lo).length
    cam.location = ctr + d * (size * 3 + 5); cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler(); bpy.context.view_layer.update()
    inv = cam.matrix_world.inverted(); pc = [inv @ p for p in pts]
    w = max(p.x for p in pc) - min(p.x for p in pc); h = max(p.y for p in pc) - min(p.y for p in pc)
    cx = (max(p.x for p in pc) + min(p.x for p in pc)) / 2; cy = (max(p.y for p in pc) + min(p.y for p in pc)) / 2
    cam.location = cam.matrix_world @ Vector((cx, cy, 0))
    asp = res[0] / res[1]; cd.type = 'ORTHO'; cd.ortho_scale = max(w, h * asp) * pad; cd.clip_end = size * 10 + 50
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.filepath = path; bpy.ops.render.render(write_still=True); print('saved', path, flush=True)


VIEWS = dict(truoc=(0, -1, 0), ngang=(1, 0, 0), sau=(0, 1, 0), q34=(1, -1.25, .85))


def render_item(iid):
    _, fn, grp, name, states, budget = do_pho.BY_ID[iid]
    for st in [None] + states:
        night = st == 'dem'
        sc, cam, cd = reset(night); ground(night)
        fn(st)
        objs = item_objs(); lo, hi, pts = bbox(objs)
        tall = hi.z - lo.z
        bpos = (hi.x + .45, (lo.y + hi.y) / 2 - .1, max(0, lo.z) if lo.z > -.1 else 0)
        if st is None:
            # trước có Bơ đứng cạnh; ngang và sau không có
            b = bo(bpos, math.radians(90)); _, _, bp = bbox([o for o in _BO['c'].objects if o.type == 'MESH'])
            bpts = [Vector(p) + Vector(bpos) for p in bp]
            res = (900, 900) if tall < 4 else (700, 1000)
            shoot(cam, cd, f'{OUT}/{iid}_q34.png', VIEWS['q34'], pts + bpts, res=(1000, 820))
            san = bpy.data.objects.get('San'); san.hide_render = True
            shoot(cam, cd, f'{OUT}/{iid}_truoc.png', VIEWS['truoc'], pts + bpts, res=res)
            bpy.data.objects.remove(b)
            san = bpy.data.objects.get('San'); san.hide_render = True
            shoot(cam, cd, f'{OUT}/{iid}_ngang.png', VIEWS['ngang'], pts, res=res)
            shoot(cam, cd, f'{OUT}/{iid}_sau.png', VIEWS['sau'], pts, res=res)
            if grp == 'mat_duong':
                san.hide_render = False
                shoot(cam, cd, f'{OUT}/{iid}_tren.png', (0.001, -.001, 1), pts, res=(900, 900))
        else:
            if night: bo(bpos, math.radians(90))
            shoot(cam, cd, f'{OUT}/{iid}_{st}.png', VIEWS['q34'], pts, res=(1000, 820))


# ---------------------------------------------------------------- bản game
_k = dict(cyl=kit.cyl, torus=kit.torus, ball=kit.ball, box=kit.box, curve=kit.curve, corr=kit.corrugated)

def low_on():
    def cyl(r, h, loc, mat, rot=(0, 0, 0), n=24, r2=None, bv=.01, name='tru', smooth=True):
        return _k['cyl'](r, h, loc, mat, rot, n=max(4, min(n, 8 if r > .05 else 6)), r2=r2, bv=0, name=name, smooth=smooth)
    def torus(R, r, loc, mat, rot=(0, 0, 0), n=32, m=12, name='vong'):
        return _k['torus'](R, r, loc, mat, rot, n=max(6, min(n, 10)), m=3, name=name)
    def ball(r, loc, mat, scale=(1, 1, 1), sub=2, name='cau'):
        return _k['ball'](r, loc, mat, scale, sub=1, name=name)
    def box(size, loc, mat, bv=.015, rot=(0, 0, 0), name='hop'):
        if min(size) < .004: return _k['box'](size, loc, mat, 0, rot, name)   # gân mỏng vẫn giữ, giảm lưới tự gộp
        return _k['box'](size, loc, mat, 0, rot, name)
    def curve(points, r, mat, name='day'):
        pts = list(points)
        if len(pts) > 6: pts = pts[::max(1, len(pts) // 5)] + ([pts[-1]] if (len(pts) - 1) % max(1, len(pts) // 5) else [])
        o = _k['curve'](pts, max(r, .006), mat, name); o.data.bevel_resolution = 0; o.data.bevel_depth = max(r, .006)
        try: o.data.fill_mode = 'FULL'
        except Exception: pass
        return o
    def corrugated(w, l, mat, loc, rot=(0, 0, 0), period=.076, amp=.012, thick=.006, name='ton'):
        o = _k['corr'](w, l, mat, loc, rot, period=period * 2.2, amp=amp * 1.3, thick=thick, name=name)
        for md in list(o.modifiers): o.modifiers.remove(md)
        return o
    for mod in (kit, do_pho):
        mod.cyl, mod.torus, mod.ball, mod.box, mod.curve, mod.corrugated = cyl, torus, ball, box, curve, corrugated


def low_off():
    for mod in (kit, do_pho):
        mod.cyl, mod.torus, mod.ball, mod.box, mod.curve, mod.corrugated = _k['cyl'], _k['torus'], _k['ball'], _k['box'], _k['curve'], _k['corr']


def flat_color(m):
    if m is None: return (.8, .8, .8)
    try:
        bs = m.node_tree.nodes['Principled BSDF']; return tuple(bs.inputs['Base Color'].default_value[:3])
    except Exception: return (.8, .8, .8)


def export_game(iid, st, budget):
    _, fn, grp, name, states, _b = do_pho.BY_ID[iid]
    reset(); fn(st)
    dg = bpy.context.evaluated_depsgraph_get(); sc = bpy.context.scene; parts = []
    for o in list(sc.objects):
        if o.type not in ('MESH', 'CURVE', 'FONT') or o.get('ngu_canh') or o.get('chu'): continue
        me = bpy.data.meshes.new_from_object(o.evaluated_get(dg)); me.transform(o.matrix_world)
        if not len(me.polygons): continue
        c = flat_color(o.active_material) + (1.0,)
        ca = me.color_attributes.new('Col', 'FLOAT_COLOR', 'POINT'); ca.data.foreach_set('color', list(c) * len(me.vertices))
        me.materials.clear(); p = bpy.data.objects.new('p', me); sc.collection.objects.link(p); parts.append(p)
    for o in list(sc.objects):
        if o not in parts and o.type != 'CAMERA' and o.type != 'LIGHT': bpy.data.objects.remove(o)
    bpy.ops.object.select_all(action='DESELECT')
    for p in parts: p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    if len(parts) > 1: bpy.ops.object.join()
    g = bpy.context.active_object; g.name = iid if st is None else f'{iid}__{st}'; me = g.data
    bm = bmesh.new(); bm.from_mesh(me); bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4); bmesh.ops.triangulate(bm, faces=bm.faces); bm.to_mesh(me); bm.free()
    tris0 = len(me.polygons)
    for _ in range(6):
        tris = len(me.polygons)
        if tris <= budget: break
        md = g.modifiers.new('Dec', 'DECIMATE'); md.ratio = budget / tris * .96; md.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier='Dec')
    mat = bpy.data.materials.new('D_mausac'); mat.use_nodes = True; nt = mat.node_tree
    an = nt.nodes.new('ShaderNodeVertexColor'); an.layer_name = 'Col'; nt.links.new(an.outputs['Color'], nt.nodes['Principled BSDF'].inputs['Base Color'])
    nt.nodes['Principled BSDF'].inputs['Roughness'].default_value = .7
    me.materials.clear(); me.materials.append(mat); me.color_attributes.active_color = me.color_attributes['Col']
    co = np.empty(len(me.vertices) * 3, np.float32); me.vertices.foreach_get('co', co); co = co.reshape(-1, 3)
    lo, hi = co.min(0), co.max(0)
    off = np.array([(lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, max(lo[2], -.1) if grp == 'mat_duong' else lo[2]], np.float32)
    off_keep = off.copy()
    me.vertices.foreach_set('co', (co - off).ravel()); me.update()
    try: bpy.ops.object.shade_smooth_by_angle(angle=.6)
    except Exception: bpy.ops.object.shade_flat()
    tris = sum(len(pl.vertices) - 2 for pl in me.polygons)
    path = os.path.join(OUT, g.name + '.glb')
    bpy.ops.object.select_all(action='DESELECT'); g.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_apply=True, export_vertex_color='ACTIVE')
    print('game', g.name, tris0, '->', tris, flush=True)
    return dict(tris=int(tris), tris_truoc_giam=int(tris0), size_m=[round(float(x), 2) for x in (hi - lo)], goc_doi=[round(float(x), 3) for x in off_keep])


if __name__ == '__main__':
    for iid in IDS:
        info = dict(id=iid, ten=do_pho.BY_ID[iid][3], nhom=do_pho.BY_ID[iid][2], trang_thai=do_pho.BY_ID[iid][4], ngan_sach=do_pho.BY_ID[iid][5])
        if MODE in ('render', 'both'): render_item(iid)
        if MODE in ('game', 'both'):
            low_on()
            info['game'] = {'chinh': export_game(iid, None, info['ngan_sach'])}
            for st in info['trang_thai']:
                if st not in NO_GAME_STATE: info['game'][st] = export_game(iid, st, info['ngan_sach'])
            low_off()
            json.dump(info, open(f'{OUT}/manifest_{iid}.json', 'w'), ensure_ascii=False, indent=1)
