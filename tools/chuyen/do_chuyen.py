"""Đồ chuyện "Bí mật cho Cô Ba" (R2) bản vào game: thiệp 30 năm, hai lá thư Hùng–Mây, bảng đồng "Lò bánh Cô Ba".
Hình, số đo và texture theo trang duyệt 24/10 (https://claude.ai/artifact/2oxRYWdjepyueHYDRLdDwG),
dựng lại từ /mnt/project-files/cai-thien-2/phac-thao-chuyen/scripts/do/do.py nhưng nhẹ cho game:
texture thu nhỏ còn cạnh dài 512 px (jpg), không bevel, bảng đồng bỏ bản đồ cao.

Chạy (cần `pip install bpy`):
  python3 tools/chuyen/do_chuyen.py [thu_muc_texture]
  (mặc định texture ở /mnt/project-files/cai-thien-2/phac-thao-chuyen/tex) -> assets/models/chuyen/*.glb

Toạ độ Blender: Z lên, mặt trước nhìn về -Y (glTF: +Y lên, mặt trước nhìn về +Z). Đơn vị mét.
Thiệp: một mesh, vật liệu mặt trong tên "Thiep_trong" để game đổi texture theo số chữ ký (assets/chuyen/thiep_trong_*.jpg)."""
import os, sys, math, tempfile
import bpy, bmesh
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..'))
SRC = sys.argv[1] if len(sys.argv) > 1 else '/mnt/project-files/cai-thien-2/phac-thao-chuyen/tex'
OUT = os.path.join(REPO, 'assets', 'models', 'chuyen')
TMP = tempfile.mkdtemp()
os.makedirs(OUT, exist_ok=True)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def small(name, edge=512):
    """Texture thu nhỏ (cạnh dài edge px) lưu jpg tạm để nhúng vào glb."""
    im = Image.open(os.path.join(SRC, name + '.png')).convert('RGB')
    k = edge / max(im.size)
    im = im.resize((max(1, round(im.size[0] * k)), max(1, round(im.size[1] * k))), Image.LANCZOS)
    p = os.path.join(TMP, name + '.jpg')
    im.save(p, quality=86)
    return p


def col(name, h, rough=.7, metal=0.):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bs = m.node_tree.nodes['Principled BSDF']
    c = tuple(int(h[i:i + 2], 16) / 255 for i in (1, 3, 5))
    bs.inputs['Base Color'].default_value = (*[x ** 2.2 for x in c], 1)
    bs.inputs['Roughness'].default_value = rough
    bs.inputs['Metallic'].default_value = metal
    return m


def tex(name, tname, rough=.8, metal=0., edge=512):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bs = nt.nodes['Principled BSDF']
    im = nt.nodes.new('ShaderNodeTexImage')
    im.image = bpy.data.images.load(small(tname, edge))
    nt.links.new(im.outputs['Color'], bs.inputs['Base Color'])
    bs.inputs['Roughness'].default_value = rough
    bs.inputs['Metallic'].default_value = metal
    return m


def panel(name, w, h, t, mats, uvf=(0, 0, 1, 1), uvb=(0, 0, 1, 1), origin='bottom'):
    """Tấm mỏng w (x) * t (y) * h (z). mats = (mặt trước -Y, mặt sau +Y, cạnh)."""
    bm = bmesh.new()
    x0, x1 = -w / 2, w / 2
    z0, z1 = (-h / 2, h / 2) if origin == 'center' else (0, h)
    if origin == 'left':
        x0, x1 = 0, w
    if origin == 'right':
        x0, x1 = -w, 0
    y0, y1 = -t / 2, t / 2
    V = [bm.verts.new(p) for p in ((x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1),
                                   (x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1))]
    faces = [((0, 1, 2, 3), 0), ((5, 4, 7, 6), 1), ((4, 0, 3, 7), 2), ((1, 5, 6, 2), 2), ((4, 5, 1, 0), 2), ((3, 2, 6, 7), 2)]
    uvl = bm.loops.layers.uv.new('UVMap')
    for idx, mi in faces:
        f = bm.faces.new([V[i] for i in idx])
        f.material_index = mi
        if mi == 0:
            u0, v0, u1, v1 = uvf
            uv = [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]
        elif mi == 1:
            u0, v0, u1, v1 = uvb
            uv = [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]
        else:
            uv = [(0, 0), (.01, 0), (.01, .01), (0, .01)]
        for l, c in zip(f.loops, uv):
            l[uvl].uv = c
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def join(objs, name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    for o in objs:
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = name
    return o


def export(name):
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + '.glb'), use_selection=True, export_apply=True,
                              export_image_format='JPEG')
    n = sum(len(p.vertices) - 2 for o in bpy.context.scene.objects if o.type == 'MESH' for p in o.data.polygons)
    print('glb', name, n, 'tam giác')


# ------------------------------------------------------------------ thiệp 30 năm (14 x 20 cm mỗi trang, mở 125°)
CW, CH = .14, .20


def thiep():
    reset()
    edge = col('Thiep_canh', '#F3E6C6', .9)
    bia, sau = tex('Thiep_bia', 'thiep_bia'), tex('Thiep_sau', 'thiep_sau')
    trong = tex('Thiep_trong', 'thiep_trong_0', .85, edge=1024)
    R = panel('Thiep_phai', CW, CH, .0016, (trong, bia, edge), uvf=(.5, 0, 1, 1), origin='left')
    L = panel('Thiep_trai', CW, CH, .0016, (trong, sau, edge), uvf=(0, 0, .5, 1), origin='right')
    a = math.radians((180 - 125) / 2)
    R.rotation_euler = (0, 0, a)
    L.rotation_euler = (0, 0, -a)
    join([R, L], 'Thiep')
    export('thiep_30')


# ------------------------------------------------------------------ lá thư (11 x 7 cm, uốn nhẹ như đang ngậm)
def la_thu(kind):
    reset()
    m = tex('Thu_' + kind, 'thu_' + kind, .85)
    o = panel('Thu_' + kind, .11, .07, .004, (m, m, col('Thu_canh', '#F4ECD8' if kind == 'may' else '#4A6E86', .9)),
              uvf=(0, .5, 1, 1), uvb=(0, 0, 1, .5), origin='center')
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.subdivide(number_cuts=4)
    bpy.ops.object.mode_set(mode='OBJECT')
    b = o.modifiers.new('Bend', 'SIMPLE_DEFORM')
    b.deform_method = 'BEND'
    b.angle = math.radians(18 if kind == 'hung' else 12)
    b.deform_axis = 'Z'
    export('la_thu_' + kind)


# ------------------------------------------------------------------ bảng đồng (40 x 14 cm, dày 6 mm, 2 vít)
def bang_dong():
    reset()
    PW, PH, PT = .40, .14, .006
    o = panel('Bang_dong', PW, PH, PT, (tex('Bang_mat', 'bang_dong', .45, .45), col('Bang_lung', '#7A5A2A', .5, .8),
                                        col('Bang_canh', '#A8823A', .35, .85)), origin='bottom')
    vit = col('Vit', '#B8963E', .3, .9)
    parts = [o]
    for sx in (-1, 1):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=4, radius=.006, location=(sx * (PW / 2 - .03), -PT / 2 - .001, PH / 2))
        s = bpy.context.active_object
        s.scale = (1, .5, 1)
        s.data.materials.append(vit)
        parts.append(s)
    join(parts, 'Bang_dong')
    export('bang_dong')


thiep()
la_thu('hung')
la_thu('may')
bang_dong()
print('XONG')
