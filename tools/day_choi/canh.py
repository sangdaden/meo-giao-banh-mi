"""Ghép cả sân sau lò bánh (14 × 10 m) từ 6 món mới (san_sau.py, bản chi tiết) và model game đã duyệt, ánh sáng 5 giờ 40.
Toạ độ: X = x sơ đồ (đông), Y = -y sơ đồ (bắc lên trên), mét thật. Dùng: python3 canh.py <out>"""
import sys, os, math
import bpy
from mathutils import Vector
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import kit, san_sau, chay
from kit import M, group, at, boxab

REPO = '/home/user/meo-giao-banh-mi/assets/models/'
OUT = sys.argv[1]


def glb(path, loc, rot=0.0, s=1.0):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=REPO + path)
    new = set(bpy.data.objects) - before
    e = bpy.data.objects.new('g_' + os.path.basename(path), None); bpy.context.scene.collection.objects.link(e)
    for o in new:
        if o.parent is None: o.parent = e
    e.location = loc; e.rotation_euler = (0, 0, rot); e.scale = (s, s, s)
    return e


def put(fn, loc, rot=0.0, st=None):
    g = fn(st); g.location = loc; g.rotation_euler = (0, 0, rot); return g


def floor():
    me = bpy.data.meshes.new('nen'); me.from_pydata([(0, -10, 0), (14, -10, 0), (14, 0, 0), (0, 0, 0)], [], [(0, 1, 2, 3)])
    o = bpy.data.objects.new('nen', me); bpy.context.scene.collection.objects.link(o)
    m = bpy.data.materials.new('gach_tau'); m.use_nodes = True; nt = m.node_tree
    br = nt.nodes.new('ShaderNodeTexBrick'); br.offset = 0.0; br.offset_frequency = 1
    br.inputs['Scale'].default_value = 1.0; br.inputs['Brick Width'].default_value = .4; br.inputs['Row Height'].default_value = .4
    br.inputs['Mortar Size'].default_value = .012
    br.inputs['Color1'].default_value = kit.lin('#C46A48'); br.inputs['Color2'].default_value = kit.lin('#B25E40')
    br.inputs['Mortar'].default_value = kit.lin('#8E7A66')
    tc = nt.nodes.new('ShaderNodeTexCoord'); nt.links.new(tc.outputs['Object'], br.inputs['Vector'])
    bs = nt.nodes['Principled BSDF']; nt.links.new(br.outputs['Color'], bs.inputs['Base Color']); bs.inputs['Roughness'].default_value = .85
    me.materials.append(m)
    # hẻm ngoài cổng
    me2 = bpy.data.meshes.new('hem'); me2.from_pydata([(-4, -12, -.02), (0, -12, -.02), (0, 2, -.02), (-4, 2, -.02)], [], [(0, 1, 2, 3)])
    h = bpy.data.objects.new('hem', me2); bpy.context.scene.collection.objects.link(h); me2.materials.append(M('#9C978C', .95))


def dawn():
    sc = bpy.context.scene
    for o in list(sc.objects):
        if o.type == 'LIGHT': bpy.data.objects.remove(o)
    w = sc.world; bg = w.node_tree.nodes['Background']
    bg.inputs['Color'].default_value = kit.lin('#8FB0D4'); bg.inputs['Strength'].default_value = .7
    l = bpy.data.lights.new('Sun', 'SUN'); l.energy = 3.2; l.angle = .08; l.color = (1.0, .78, .55)
    o = bpy.data.objects.new('Sun', l); sc.collection.objects.link(o)
    o.rotation_euler = (math.radians(74), 0, math.radians(-100))      # thấp, từ phía đông chiếu qua
    f = bpy.data.lights.new('Fill', 'SUN'); f.energy = .6; f.color = (.7, .8, 1.0)
    of = bpy.data.objects.new('Fill', f); sc.collection.objects.link(of); of.rotation_euler = (math.radians(30), 0, math.radians(150))


def build():
    sc, cam, cd = chay.reset(); floor(); dawn()
    S = san_sau
    put(S.mat_sau_lo, (6.6, 0, 0), 0, 'toi')                      # cửa sau x 7,1 · cửa sổ x 4,0 · ống khói x 9,6
    for x in (1.3,): put(S.tuong_rao, (x, 0, 0), 0)
    boxab((0, 0, 0), (2.6, .2, 2.0), M(san_sau.PLASTER2, .92), .01)
    put(S.kho_cui, (12.75, -2.0, 0), 0)
    glb('bep/ro_tre.glb', (13.0, -1.5, 1.86), 0, 1.6)
    for x in (1, 3, 5, 7, 9, 11, 13): put(S.tuong_rao, (x, -10, 0), math.pi)
    for y in (-5, -7, -9): put(S.tuong_rao, (14, y, 0), -math.pi / 2)
    for y in (-1, -3, -5): put(S.tuong_rao, (0, y, 0), math.pi / 2)
    put(S.tuong_rao, (0, -9.6, 0), math.pi / 2)
    put(S.cong_sau, (0, -7.6, 0), math.pi / 2, 'mo')
    put(S.cay_khe, (7.0, -5.1, 0))
    glb('gio/lu_nuoc.glb', (5.7, -4.2, 0))
    for x in (4.0, 6.0, 8.0): put(S.bon_kieng, (x, -7.0, 0))
    # thùng gỗ bậc 0,45 / 0,9 / 1,35 (thung_go 0,8 m thu nhỏ còn 0,45)
    k = .45 / .8
    for (x, y), n in (((11.95, -5.25), 1), ((12.65, -4.65), 2), ((13.35, -4.35), 3)):
        for i in range(n): glb('pho/thung_go.glb', (x, y, i * .45), .1 * i, k)
    glb('pho/ba_gac.glb', (11.9, -7.0, 0), 0)
    for i, (x, y, z) in enumerate(((6.6, -9.5, 0), (7.25, -9.5, 0), (6.9, -9.45, .22), (7.6, -9.55, 0))):
        glb('pho/bao_gao.glb', (x, y, z), .2 * i)
    glb('skin/giong/khoaimon_duc.glb', (6.95, -9.5, .44), math.radians(80), 1.0)
    glb('nguoi/coba.glb', (5.6, -1.3, 0), math.radians(-20))       # đứng cạnh cửa sau lúc mở màn
    glb('nguoi/chutu.glb', (-.9, -7.6, 0), -math.pi / 2)
    chay.bo((7.1, -1.4, 0), math.radians(-90))
    return sc, cam, cd


def persp(cam, cd, loc, look, path, res=(1400, 880), lens=28):
    sc = bpy.context.scene; cd.type = 'PERSP'; cd.lens = lens; cd.clip_end = 200
    cam.location = loc; d = Vector(look) - Vector(loc); cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    sc.render.resolution_x, sc.render.resolution_y = res; sc.render.filepath = path
    bpy.ops.render.render(write_still=True); print('saved', path, flush=True)


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    sc, cam, cd = build()
    persp(cam, cd, (2.0, -19, 15), (7, -5.0, 0), f'{OUT}/canh_toan.png')
    cd.type = 'ORTHO'; cd.ortho_scale = 15.5; cam.location = (7, -5, 30); cam.rotation_euler = (0, 0, 0)
    sc.render.resolution_x, sc.render.resolution_y = 1400, 1050; sc.render.filepath = f'{OUT}/canh_tren.png'
    bpy.ops.render.render(write_still=True)
    persp(cam, cd, (8.2, -9.2, 2.6), (12.6, -3.5, 1.2), f'{OUT}/canh_tram2.png', lens=24)
    persp(cam, cd, (13.2, -3.8, 1.6), (8, -9, .3), f'{OUT}/canh_tram34.png', lens=22)
    persp(cam, cd, (6.0, -8.8, 1.8), (2.5, -3, 1.0), f'{OUT}/canh_tram5.png', lens=22)
