"""Xe bánh mì đẩy hàng rong (phong cách D), dựng bằng kit.py của khu phố.
Dùng: python xe_banh_mi_day.py <outdir> [--glb] [--game]  (cần pip bpy 5.2, kit.py cùng thư mục)
Toạ độ Blender: x dọc thân xe (tay đẩy ở +x), -y mặt khách (bảng chữ), +y phía người bán, z lên. Gốc giữa đáy."""
import sys, os, math, json
import bpy
from mathutils import Vector
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE)); sys.path.insert(0, HERE)
from kit import *
import kit

OUT = sys.argv[1]; os.makedirs(OUT, exist_ok=True)
GLB = '--glb' in sys.argv
GAME = '--game' in sys.argv   # bản vào game: ít nan, ít mặt, xuất .glb thay vì render

L, D = 1.50, 0.68          # dài, sâu thân tủ
Z_TOP = 0.86               # mặt bàn inox
Z_GLASS = 1.36             # nóc tủ kính
X0, X1 = -L / 2, L / 2

PAL = dict(son='#C8412F', son2='#9E2F22', vang='#F2B33D', inox='#C9CED0', inox2='#9AA3A6', nhom='#D7DADB',
           kinh='#BFE3E6', go='#B07C46', go2='#8A5A30', lop='#232323', banh='#D98E2B', banh2='#C47A22',
           cha='#E9DCC4', la='#4E7A3A', pate='#9C5B3A', dochua='#E58A3A', ot='#C9372C', xidau='#4A2A1A', trang='#F1ECE2')

def mats():
    return dict(son=M(PAL['son'], .45, coat=.5), son2=M(PAL['son2'], .5), vang=M(PAL['vang'], .5),
                inox=M(PAL['inox'], .28, .9), inox2=M(PAL['inox2'], .35, .85), nhom=M(PAL['nhom'], .35, .8),
                kinh=M(PAL['kinh'], .05, alpha=.28), go=M(PAL['go'], .7), go2=M(PAL['go2'], .7), lop=M(PAL['lop'], .85),
                banh=M(PAL['banh'], .6, sheen=.2), banh2=M(PAL['banh2'], .6, sheen=.2), cha=M(PAL['cha'], .6), la=M(PAL['la'], .55),
                pate=M(PAL['pate'], .4, .6), dochua=M(PAL['dochua'], .3, alpha=.8), ot=M(PAL['ot'], .35), xidau=M(PAL['xidau'], .35),
                trang=M(PAL['trang'], .8), den=M('#FFE7A8', .4, emit=3.0), than=M('#3A2E2A', .9), lua=M('#FF7A2E', .5, emit=4.0))

def wheel(x, y, m, r=.30, side='L'):
    """Bánh xe đạp: lốp, vành, nan hoa, trục. Gốc nhóm ở tâm trục để game quay bánh."""
    nn = 6 if GAME else 12
    hub = group(f'banh_xe_{side}', (x, y, r + .028))
    with at(hub):
        torus(r, .028, (0, 0, 0), m['lop'], rot=(math.pi / 2, 0, 0), n=20 if GAME else 32, m=6 if GAME else 10, name='lop')
        torus(r - .03, .01, (0, 0, 0), m['inox'], rot=(math.pi / 2, 0, 0), n=20 if GAME else 32, m=4 if GAME else 6, name='vanh')
        cyl(.035, .06, (0, 0, 0), m['inox2'], rot=(math.pi / 2, 0, 0), n=8 if GAME else 12, name='truc')
        for i in range(nn):
            a = 2 * math.pi * i / nn
            cyl(.004 if not GAME else .007, r - .04, (math.cos(a) * (r - .04) / 2, 0, math.sin(a) * (r - .04) / 2), m['inox'],
                rot=(0, math.pi / 2 - a, 0), n=5 if not GAME else 4, bv=0, name='nan')

def tube(a, b, r, mat, name='ong'):
    curve([a, b], r, mat, name=name)

def build():
    m = mats(); parts = {}
    g = group('xe_banh_mi_day')
    with at(g):
        # 1 Khung sắt + chân chống + bánh xe
        for y in (-D / 2 + .03, D / 2 - .03):
            tube((X0 + .05, y, .32), (X1 - .05, y, .32), .016, m['inox2'], 'khung')
            for x in (X0 + .05, X1 - .05): tube((x, y, .06), (x, y, .34), .016, m['inox2'], 'chan')
            wheel(.32, y + (-.07 if y < 0 else .07), m, side='R' if y < 0 else 'L')
        tube((.32, -D / 2 - .07, .328), (.32, D / 2 + .07, .328), .014, m['inox2'], 'truc_ngang')
        for x in (X0 + .05, X1 - .05):
            for y in (-D / 2 + .03, D / 2 - .03): cyl(.03, .05, (x, y, .03), m['lop'], n=12, name='de_cao_su')
        # 2 Tủ dưới: thân sơn đỏ, viền vàng, cửa lùa inox phía người bán
        box((L, D, Z_TOP - .36), (0, 0, (Z_TOP + .36) / 2 - .01), m['son'], .02, name='than_tu')
        box((L + .01, .012, .05), (0, -D / 2 - .004, Z_TOP - .08), m['vang'], .004, name='vien_vang')
        box((L + .01, .012, .05), (0, -D / 2 - .004, .42), m['vang'], .004, name='vien_vang')
        box((.86, .01, .26), (-.3, -D / 2 - .006, .62), m['vang'], .01, name='bang_chu')
        text('BÁNH MÌ', .15, (-.3, -D / 2 - .014, .655), m['son2'], extrude=.006, name='chu_banh_mi')
        text('PATE · THỊT · CHẢ', .055, (-.3, -D / 2 - .014, .545), m['son2'], extrude=.003, name='chu_mon')
        for i, x in enumerate((-.36, .36)):
            box((.7, .012, .4), (x, D / 2 + .004, .62), m['inox'], .006, name='cua_lua')
            box((.08, .02, .025), (x + (.25 if i == 0 else -.25), D / 2 + .016, .66), m['inox2'], .004, name='tay_nam_cua')
            for k in range(6): box((.66, .004, .006), (x, D / 2 + .011, .46 + k * .06), m['inox2'], 0, name='gan_cua')
        # 3 Mặt bàn inox có gờ, thớt gỗ, dao, chai tương ớt, xì dầu, hộp pate, hũ đồ chua
        box((L + .08, D + .06, .03), (0, 0, Z_TOP), m['inox'], .008, name='mat_ban')
        box((L + .08, .015, .04), (0, D / 2 + .03, Z_TOP + .03), m['inox'], .004, name='go_mat_ban')
        box((.42, .26, .03), (.25, .2, Z_TOP + .03), m['go'], .008, name='thot')
        box((.18, .03, .004), (.28, .2, Z_TOP + .048), m['inox'], .001, name='dao')
        box((.09, .03, .02), (.15, .2, Z_TOP + .05), m['go2'], .005, name='can_dao')
        for i, (mat, x) in enumerate(((m['ot'], .58), (m['xidau'], .64))):
            cyl(.028, .16, (x, .22, Z_TOP + .095), mat, n=14, name='chai')
            cyl(.012, .04, (x, .22, Z_TOP + .195), m['trang'], n=10, name='nap_chai')
        cyl(.06, .07, (-.05, .22, Z_TOP + .05), m['pate'], n=20, name='hop_pate')
        cyl(.07, .14, (-.25, .22, Z_TOP + .085), m['dochua'], n=20, name='hu_do_chua')
        cyl(.072, .02, (-.25, .22, Z_TOP + .165), m['son'], n=20, name='nap_hu')
        # 4 Tủ kính: khung nhôm, kính, kệ inox, bánh mì xếp hàng, đòn chả treo
        zc = (Z_TOP + .015 + Z_GLASS) / 2; h = Z_GLASS - Z_TOP - .015
        x0g, x1g, y0g, y1g = X0 + .03, X1 - .45, -D / 2 + .03, D / 2 - .26
        for x in (x0g, x1g):
            for y in (y0g, y1g): box((.025, .025, h), (x, y, zc), m['nhom'], .004, name='khung_nhom')
        for z in (Z_TOP + .03, Z_GLASS):
            for y in (y0g, y1g): box((x1g - x0g, .025, .025), ((x0g + x1g) / 2, y, z), m['nhom'], .004, name='khung_nhom')
            for x in (x0g, x1g): box((.025, y1g - y0g, .025), (x, (y0g + y1g) / 2, z), m['nhom'], .004, name='khung_nhom')
        box((x1g - x0g, .006, h), ((x0g + x1g) / 2, y0g, zc), m['kinh'], 0, name='kinh_truoc')
        for x in (x0g, x1g): box((.006, y1g - y0g, h), (x, (y0g + y1g) / 2, zc), m['kinh'], 0, name='kinh_hong')
        box((x1g - x0g, y1g - y0g, .006), ((x0g + x1g) / 2, (y0g + y1g) / 2, Z_GLASS + .012), m['kinh'], 0, name='kinh_noc')
        box((x1g - x0g - .04, y1g - y0g - .04, .008), ((x0g + x1g) / 2, (y0g + y1g) / 2, Z_TOP + .2), m['inox'], .002, name='ke_giua')
        # bánh mì nằm dọc theo thân xe, xếp so le 3 lớp: 2 lớp dưới đáy tủ, 1 lớp trên kệ
        n = 4
        for row, (z, yy, off) in enumerate(((Z_TOP + .065, -.1, 0), (Z_TOP + .065, .0, .06), (Z_TOP + .12, -.05, .03), (Z_TOP + .245, -.06, 0))):
            for i in range(n):
                x = x0g + .16 + off + i * (x1g - x0g - .38) / (n - 1)
                ball(.045, (x, yy, z), m['banh'] if (i + row) % 3 else m['banh2'], scale=(2.6, .9, .75), name='o_banh')
                box((.15, .012, .006), (x, yy - .01, z + .031), m['banh2'], .002, name='vet_rach')
        tube((x0g + .05, y1g - .05, Z_GLASS - .03), (x1g - .05, y1g - .05, Z_GLASS - .03), .006, m['inox'], 'thanh_treo')
        for i, x in enumerate((x0g + .15, x0g + .32, x0g + .5)):
            # đòn chả lụa gói lá chuối, buộc dây ở giữa; đòn giữa đã cắt lộ ruột chả
            cyl(.05, .13, (x, y1g - .05, Z_GLASS - .13), m['la'], n=16, bv=.02, name='cha_lua')
            cyl(.052, .015, (x, y1g - .05, Z_GLASS - .13), m['trang'], n=16, bv=0, name='day_buoc')
            if i == 1: cyl(.047, .01, (x, y1g - .05, Z_GLASS - .2), m['cha'], n=16, bv=0, name='mat_cat_cha')
            cyl(.004, .04, (x, y1g - .05, Z_GLASS - .045), m['trang'], n=5, bv=0, name='day_treo')
        # 5 Lò than sưởi bánh ở đầu xe phía tay đẩy
        xb = X1 - .22
        box((.34, .3, .14), (xb, .05, Z_TOP + .085), m['inox2'], .01, name='lo_than')
        box((.3, .26, .02), (xb, .05, Z_TOP + .07), m['than'], .002, name='than')
        for k in range(3): ball(.025, (xb - .08 + k * .08, .05, Z_TOP + .085), m['lua'], scale=(1, 1, .5), name='lua_than')
        for k in range(7): box((.004, .28, .004), (xb - .15 + k * .05, .05, Z_TOP + .16), m['inox'], 0, name='vi_nuong')
        for k in range(2): ball(.04, (xb - .06 + k * .12, .05, Z_TOP + .195), m['banh2'], scale=(.85, 2.6, .75), name='banh_nuong')
        # 6 Bảng hiệu trên nóc + bóng đèn + dù che
        box((.9, .03, .2), ((x0g + x1g) / 2, y0g + .05, Z_GLASS + .14), m['son'], .01, name='bang_hieu')
        text('BÁNH MÌ NÓNG', .085, ((x0g + x1g) / 2, y0g + .03, Z_GLASS + .14), m['vang'], extrude=.004, name='chu_bang_hieu')
        for x in (x0g + .1, x1g - .1): tube((x, y0g + .05, Z_GLASS + .02), (x, y0g + .05, Z_GLASS + .04), .008, m['nhom'], 'chan_bang')
        tube((x1g - .03, y1g, Z_GLASS), (x1g - .03, y1g, Z_GLASS + .55), .01, m['nhom'], 'cot_den')
        tube((x1g - .03, y1g, Z_GLASS + .55), (x1g - .25, y1g, Z_GLASS + .55), .008, m['nhom'], 'canh_den')
        cyl(.004, .08, (x1g - .25, y1g, Z_GLASS + .5), m['lop'], n=5, bv=0, name='day_den')
        ball(.04, (x1g - .25, y1g, Z_GLASS + .44), m['den'], scale=(1, 1, 1.25), name='bong_den')
        # 7 Tay đẩy ống inox uốn + bọc cao su, móc túi ni lông
        xh = X1 + .22
        for y in (-D / 2 + .06, D / 2 - .06): tube((X1 - .02, y, .55), (xh, y, .82), .016, m['inox'], 'tay_day')
        tube((xh, -D / 2 + .06, .82), (xh, D / 2 - .06, .82), .016, m['inox'], 'tay_day')
        cyl(.024, .3, (xh, -.12, .82), m['lop'], rot=(math.pi / 2, 0, 0), n=12, name='boc_tay')
        cyl(.024, .3, (xh, .12, .82), m['lop'], rot=(math.pi / 2, 0, 0), n=12, name='boc_tay')
        box((.2, .006, .26), (X0 - .005, -.12, .68), m['trang'], .004, name='xap_tui')
        box((.004, .14, .03), (X0 - .004, -.12, .82), m['inox2'], .001, name='moc_tui')
        # 8 Hộp giấy gói + khay rau dưa dưới kính phía người bán
        box((.22, .14, .1), (-.55, .24, Z_TOP + .065), m['go2'], .008, name='hop_giay')
        box((.2, .12, .02), (-.55, .24, Z_TOP + .125), m['trang'], .004, name='giay_goi')
    return g

def stats(g):
    deps = bpy.context.evaluated_depsgraph_get(); tris = 0
    for o in g.children_recursive:
        if o.type in ('MESH', 'FONT', 'CURVE'):
            me = o.evaluated_get(deps).to_mesh(); me.calc_loop_triangles(); tris += len(me.loop_triangles); o.evaluated_get(deps).to_mesh_clear()
    return tris

def scene():
    bpy.ops.wm.read_factory_settings(use_empty=True); kit._MATS.clear(); kit.PARENT[0] = None
    sc = bpy.context.scene
    w = bpy.data.worlds.new('W'); sc.world = w
    if w.node_tree is None: w.use_nodes = True
    w.node_tree.nodes['Background'].inputs['Color'].default_value = lin('#B9D9D2'); w.node_tree.nodes['Background'].inputs['Strength'].default_value = .55
    l = bpy.data.lights.new('Sun', 'SUN'); l.energy = 2.8; l.angle = .12; l.color = (1, .95, .86)
    o = bpy.data.objects.new('Sun', l); sc.collection.objects.link(o); o.rotation_euler = (math.radians(50), 0, math.radians(-35))
    sc.render.engine = 'BLENDER_EEVEE'
    try: sc.eevee.taa_render_samples = 32
    except Exception: pass
    sc.view_settings.view_transform = 'Standard'; sc.view_settings.look = 'None'
    cd = bpy.data.cameras.new('Cam'); cam = bpy.data.objects.new('Cam', cd); sc.collection.objects.link(cam); sc.camera = cam
    bpy.ops.mesh.primitive_plane_add(size=40); gp = bpy.context.active_object; gp.data.materials.append(M('#C9C3B3', .95)); gp.location.z = -.005
    return sc, cam, cd

def look(cam, cd, loc, tgt, lens=40, ortho=None):
    cam.location = Vector(loc); cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    if ortho: cd.type = 'ORTHO'; cd.ortho_scale = ortho
    else: cd.type = 'PERSP'; cd.lens = lens

def render(path, w=1000, h=800):
    sc = bpy.context.scene; sc.render.resolution_x = w; sc.render.resolution_y = h
    sc.render.filepath = path; bpy.ops.render.render(write_still=True); print('saved', path)

def bo(loc, rot=0.0):
    f = os.path.join(os.path.dirname(HERE), 'chung2.glb')
    if not os.path.exists(f): f = '/mnt/project-files/meo-3d/bo-chung-chac/chung2.glb'
    before = set(bpy.data.objects); bpy.ops.import_scene.gltf(filepath=f)
    for o in set(bpy.data.objects) - before:
        if o.parent is None: o.location = loc; o.rotation_euler = (0, 0, rot)

def export_game(g, path, target=3200):
    """Gộp thành các mesh màu đỉnh: than (đục), kinh (trong), lua (phát sáng), banh_xe_L/R (gốc ở trục)."""
    import bmesh
    deps = bpy.context.evaluated_depsgraph_get()
    groups = {}
    def cat(o):
        p = o
        while p is not None:
            if p.name.startswith('banh_xe_'): return p.name.split('.')[0], p
            p = p.parent
        if o.name.startswith('lua_than'): return 'lua', None
        mt = o.active_material
        if mt and mt.node_tree and mt.node_tree.nodes['Principled BSDF'].inputs['Alpha'].default_value < 1 and 'kinh' in o.name: return 'kinh', None
        return 'than', None
    for o in g.children_recursive:
        if o.type not in ('MESH', 'FONT', 'CURVE'): continue
        key, root = cat(o)
        me = bpy.data.meshes.new_from_object(o.evaluated_get(deps))
        mw = o.matrix_world.copy()
        if root is not None: mw = root.matrix_world.inverted() @ mw
        me.transform(mw)
        col = me.color_attributes.new('Col', 'FLOAT_COLOR', 'CORNER')
        mats = [ms for ms in me.materials]
        for poly in me.polygons:
            mt = mats[poly.material_index] if mats and poly.material_index < len(mats) else None
            c = mt.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value if mt and mt.node_tree else (1, 1, 1, 1)
            for li in poly.loop_indices: col.data[li].color = (c[0], c[1], c[2], 1)
        bm = groups.setdefault(key, bmesh.new()); bm.from_mesh(me); bpy.data.meshes.remove(me)
    out = []
    names = dict(than='pho_mausac', kinh='kinh', lua='lua')
    for key, bm in groups.items():
        me = bpy.data.meshes.new(key); bm.to_mesh(me); bm.free()
        me.materials.clear()
        mt = bpy.data.materials.new(names.get(key, 'pho_mausac'))
        if mt.node_tree is None: mt.use_nodes = True
        vc = mt.node_tree.nodes.new('ShaderNodeVertexColor'); vc.layer_name = 'Col'
        mt.node_tree.links.new(vc.outputs['Color'], mt.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
        me.materials.append(mt)
        o = bpy.data.objects.new(key, me); bpy.context.scene.collection.objects.link(o)
        if key.startswith('banh_xe_'):
            src = bpy.data.objects[key]; o.location = src.matrix_world.translation
        me.calc_loop_triangles(); tris = len(me.loop_triangles)
        if key == 'than' and tris > target:
            md = o.modifiers.new('D', 'DECIMATE'); md.ratio = target / tris
            m2 = bpy.data.meshes.new_from_object(o.evaluated_get(bpy.context.evaluated_depsgraph_get()))
            o.modifiers.clear(); o.data = m2; m2.materials.clear(); m2.materials.append(mt)
        cm = o.data.color_attributes
        for ca in [c for c in cm if c.name != 'Col']: cm.remove(ca)
        cm.active_color = cm['Col']; cm.render_color_index = 0
        o.data.calc_loop_triangles(); print('GAME', key, len(o.data.loop_triangles), [c.name for c in cm])
        out.append(o)
    for ob in list(bpy.context.scene.objects):
        ob.select_set(ob in out)
    kw = dict(filepath=path, use_selection=True, export_format='GLB', export_apply=False)
    try: bpy.ops.export_scene.gltf(**kw, export_vertex_color='ACTIVE', export_all_vertex_colors=False)
    except TypeError: bpy.ops.export_scene.gltf(**kw)
    print('saved', path)

if GAME:
    scene(); g = build(); export_game(g, f'{OUT}/xe_banh_mi_day.glb'); sys.exit(0)

sc, cam, cd = scene()
g = build()
print('TRIS', stats(g))
bo((-1.15, -.55, 0), rot=-.4)
c = (0.1, 0, .75)
look(cam, cd, (2.4, -3.0, 1.9), c, 40); render(f'{OUT}/q34.png')
look(cam, cd, (0.1, -6, .8), c, ortho=2.6); render(f'{OUT}/truoc.png')
look(cam, cd, (0.1, 6, .8), c, ortho=2.6); render(f'{OUT}/sau.png')
look(cam, cd, (6, 0, .8), c, ortho=2.6); render(f'{OUT}/ngang.png')
look(cam, cd, (0.1, -0.001, 6), (0.1, 0, 0), ortho=2.6); render(f'{OUT}/tren.png')
look(cam, cd, (-.2, -1.25, 1.55), (-.2, 0, 1.0), 35); render(f'{OUT}/can_tu_kinh.png')
look(cam, cd, (1.6, .9, 1.6), (.5, .1, .9), 35); render(f'{OUT}/can_nguoi_ban.png')
if GLB:
    bpy.ops.wm.save_as_mainfile(filepath=f'{OUT}/xe_banh_mi_day.blend')
