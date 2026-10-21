"""Chuyển model chuẩn Bơ kiểu D (chung2.glb) thành bản game có rig chính thức 22 xương.

Chạy:  python3 tools/bo_game.py <chung2.glb> assets/models/bo.glb
(Cần: pip install bpy)

Việc script làm:
1. Giảm số tam giác từ ~115k xuống ~15k cho nhẹ, giữ chi tiết quanh mắt (tròng mắt giữ đồng tử dọc).
2. Dồn màu lông, khăn, mắt vào một lớp màu đỉnh (COLOR_0) để Godot đọc được.
3. Gắn bộ xương chính thức Sang duyệt 21/10 (trang "Bơ đi giao Thứ Hai", mục Bộ xương), 22 xương:
   root, hips, chest, head, ear_L/R, tail_1..4, và mỗi chân 3 xương có khuỷu/gối:
   chân trước upperarm/forearm/paw, chân sau thigh/shin/paw.
   Thêm 3 xương phụ cho biểu cảm: eye_L/R (chớp mắt) và scarf (khăn đung đưa).
   Trọng số (weight) tính theo vị trí từng đỉnh, không cần vẽ tay.
4. Xuất .glb có xương (chưa có animation; game tự xoay xương bằng code trong scripts/player.gd).

Mọi xương nằm trong mặt phẳng dọc thân đều có trục X cục bộ trùng trục X của model,
nên trong Godot xoay quanh Vector3.RIGHT là gập trước/sau và các góc cộng dồn được dọc theo chân.
"""
import math
import sys
import bpy
from mathutils import Vector

src, dst = sys.argv[-2], sys.argv[-1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)

meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
for o in meshes:
    bpy.context.view_layer.objects.active = o
    for oo in meshes:
        oo.select_set(oo is o)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# Tâm hai mắt (cầu tròng mắt tên 'Mat...'): vùng quanh mắt được giữ nhiều tam giác hơn,
# nếu không mí mắt bị bào thành hình bát giác và tròng mất màu hổ phách (trông như đeo kính)
eye_centers = []
for o in meshes:
    if o.name.startswith('Mat'):
        vs = [v.co for v in o.data.vertices]
        eye_centers.append(sum(vs, Vector()) / len(vs))


def target_tris(name):
    if name.startswith('Bo_Than'):
        return 9000
    if name.startswith('Bo_Khan'):
        return 1200
    if name.startswith('Mat'):
        return 2400    # tròng mắt: đồng tử dọc nằm trong màu đỉnh, ít tam giác quá thì mắt thành màu nâu đục
    return 40          # đốm sáng trong mắt


for o in meshes:
    bpy.context.view_layer.objects.active = o
    for oo in meshes:
        oo.select_set(oo is o)
    tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    target = target_tris(o.name)
    if tris > target:
        md = o.modifiers.new('Dec', 'DECIMATE')
        md.ratio = target / tris
        if o.name.startswith('Bo_Than'):
            keep = o.vertex_groups.new(name='giu_mat')
            for v in o.data.vertices:
                d = min((v.co - c).length for c in eye_centers)
                if d < .08:
                    keep.add([v.index], 1.0 - d / .08, 'REPLACE')
            md.vertex_group = 'giu_mat'
            md.vertex_group_factor = 1.5
            md.invert_vertex_group = True  # trọng số 0 = giữ nguyên, nên đảo để vùng mắt được giữ
        bpy.ops.object.modifier_apply(modifier=md.name)

# Màu: lông và mắt đã có màu đỉnh tên 'Color'. Khăn và đốm sáng trong mắt chưa có,
# nên tô màu đỉnh bằng màu vật liệu để khi gộp mesh chỉ còn một lớp màu đỉnh duy nhất.
for o in meshes:
    if o.data.color_attributes.get('Color'):
        continue
    m = o.data.materials[0]
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    col = (1, 1, 1, 1) if m.name.startswith('Sang') else tuple(bsdf.inputs['Base Color'].default_value)
    attr = o.data.color_attributes.new('Color', 'BYTE_COLOR', 'CORNER')
    for d in attr.data:
        d.color = col

# Gộp thành một mesh (nhiều vật liệu): một lần vẽ cho mỗi vật liệu
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.join()
cat = bpy.context.active_object
cat.name = 'Bo'
cat.data.color_attributes.active_color = cat.data.color_attributes['Color']
print('tris', sum(len(p.vertices) - 2 for p in cat.data.polygons))


def ramp(v, a, b):
    """0 khi v ở a, 1 khi v ở b, mượt ở giữa."""
    t = max(0.0, min(1.0, (v - a) / (b - a)))
    return t * t * (3 - 2 * t)


def ik(a, e, l1, l2, hint):
    """Điểm khớp giữa (khuỷu/gối) của chân 2 đoạn dài l1, l2 nối a tới e, gập về phía hint."""
    d = e - a
    dist = d.length
    u = d / dist
    if dist >= l1 + l2 - 1e-4:
        return a + u * l1 * dist / (l1 + l2)
    k = (l1 * l1 - l2 * l2 + dist * dist) / (2 * dist)
    h = hint - u * hint.dot(u)
    h.normalize()
    return a + u * k + h * math.sqrt(max(l1 * l1 - k * k, 0.0))


# Toạ độ Blender: X phải, -Y là phía trước mặt mèo, Z lên trên.
BONES = {
    # tên: (đầu, đuôi, cha)
    'root':  ((0, 0, 0), (0, 0, .08), None),
    # hips mọc ở khớp háng sau, chĩa về giữa lưng: xoay hips là ngồi dậy/chúi người quanh hông
    'hips':  ((0, .15, .22), (0, .02, .26), 'root'),
    # chest nối tiếp tới gốc cổ: xoay chest là cong lưng, ngửa ngực
    'chest': ((0, .02, .26), (0, -.12, .31), 'hips'),
    'head':  ((0, -.1, .34), (0, -.17, .5), 'chest'),
    # Đuôi 4 đốt (~7,5 cm mỗi đốt, tổng ~0,30 m) theo đường cong của đuôi chuẩn:
    # mọc ở mông, rủ xuống ra sau, rồi cong lên ở chóp
    'tail_1': ((0, .2, .27), (0, .28, .25), 'hips'),
    'tail_2': ((0, .28, .25), (0, .35, .28), 'tail_1'),
    'tail_3': ((0, .35, .28), (.01, .38, .35), 'tail_2'),
    'tail_4': ((.01, .38, .35), (.02, .375, .42), 'tail_3'),
}
TAIL = ['tail_1', 'tail_2', 'tail_3', 'tail_4']

# Chân: số đo của Bơ chuẩn (poses.py, S['fl'], S['hl']). Vai/háng ở trong thân, cổ chân cao 4 cm,
# điểm cổ chân lấy theo tâm lát cắt lưới chân ở dáng đứng của chung2 (chân trước trái bước trước).
# Khuỷu trước gập ra sau, gối sau gập ra trước như mèo thật.
LEGS = {
    # tên: (vai/háng, cổ chân, (dài đoạn trên, dài đoạn dưới), hướng gập, cha, tên 3 xương)
    'FL': ((-.056, -.10, .27), (-.056, -.135, .04), (.12, .116), (0, 1, 0), 'chest', ('upperarm', 'forearm', 'paw')),
    'FR': ((.056, -.10, .27), (.056, -.10, .04), (.12, .116), (0, 1, 0), 'chest', ('upperarm', 'forearm', 'paw')),
    'BL': ((-.064, .15, .22), (-.064, .148, .04), (.096, .09), (0, -1, 0), 'hips', ('thigh', 'shin', 'paw')),
    'BR': ((.064, .15, .22), (.064, .12, .04), (.096, .09), (0, -1, 0), 'hips', ('thigh', 'shin', 'paw')),
}
LEG_SEGS = {}   # chân -> 3 đoạn (tên xương, đầu, đuôi)
for leg, (a, e, (l1, l2), hint, parent, names) in LEGS.items():
    a, e = Vector(a), Vector(e)
    j = ik(a, e, l1, l2, Vector(hint))
    toe = Vector((e.x, e.y - .045, .012))   # bàn chân nằm trên đất, chĩa về trước
    segs = [(f'{names[0]}_{leg}', a, j), (f'{names[1]}_{leg}', j, e), (f'{names[2]}_{leg}', e, toe)]
    LEG_SEGS[leg] = segs
    prev = parent
    for n, h, t in segs:
        BONES[n] = (tuple(h), tuple(t), prev)
        prev = n

# Vật liệu của từng đỉnh (sau khi gộp mesh), để tìm mắt, khăn
mat_of = {}
for poly in cat.data.polygons:
    name = cat.data.materials[poly.material_index].name
    for vi in poly.vertices:
        mat_of[vi] = name


def center(pts):
    return sum(pts, Vector()) / len(pts)


# Mắt: một xương cho mỗi mắt (tròng + đốm sáng), dựng đứng để co trục Y là chớp mắt
eye_pts = {'eye_L': [], 'eye_R': []}
for v in cat.data.vertices:
    m = mat_of.get(v.index, '')
    if m.startswith('Mat') or m.startswith('Sang'):
        eye_pts['eye_L' if v.co.x < .035 else 'eye_R'].append(v.co.copy())
for n, pts in eye_pts.items():
    c = center(pts)
    BONES[n] = (tuple(c), tuple(c + Vector((0, 0, .03))), 'head')

# Tai: hai chóp nhọn trên đỉnh đầu; xương mọc từ chân tai lên chóp tai
ear_pts = [v.co.copy() for v in cat.data.vertices if v.co.z > .53 and v.co.y < -.1]
mid_x = center(ear_pts).x
for n, side in (('ear_L', -1), ('ear_R', 1)):
    pts = [p for p in ear_pts if (p.x - mid_x) * side > 0]
    c = center(pts)
    tip = max(pts, key=lambda p: p.z)
    BONES[n] = ((c.x, c.y, .5), tuple(tip), 'head')

# Khăn: phần nút và hai mép rủ trước ngực đung đưa theo quán tính
knot = [v.co.copy() for v in cat.data.vertices if mat_of.get(v.index) == 'Khan' and v.co.z < .32]
kc = center(knot)
BONES['scarf'] = ((kc.x, kc.y, .32), (kc.x, kc.y - .01, min(p.z for p in knot)), 'chest')
print('eyes', [tuple(round(c, 3) for c in BONES[n][0]) for n in ('eye_L', 'eye_R')],
      'ears', [tuple(round(c, 3) for c in BONES[n][1]) for n in ('ear_L', 'ear_R')],
      'scarf', tuple(round(c, 3) for c in BONES['scarf'][0]))

arm_data = bpy.data.armatures.new('BoRig')
arm = bpy.data.objects.new('BoRig', arm_data)
bpy.context.scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='EDIT')
for name, (h, t, parent) in BONES.items():
    b = arm_data.edit_bones.new(name)
    b.head, b.tail = Vector(h), Vector(t)
    d = b.tail - b.head
    if abs(d.x) < 1e-3:
        # Xương nằm trong mặt phẳng dọc thân: đặt trục Z cục bộ vuông góc trong mặt phẳng đó
        # để trục X cục bộ đúng bằng +X của model (gập trước/sau = xoay quanh X, cộng dồn được)
        b.align_roll(Vector((0, -d.z, d.y)))
    else:
        b.roll = 0
    if parent:
        b.parent = arm_data.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')
bad = [b.name for b in arm_data.bones if abs(b.tail_local.x - b.head_local.x) < 1e-3
       and (b.matrix_local.to_3x3().col[0] - Vector((1, 0, 0))).length > 1e-3]
assert not bad, f'trục X của các xương này lệch khỏi +X: {bad}'
print('bones', len(arm_data.bones), [b.name for b in arm_data.bones])


def nearest_segments(p, segs):
    """Các đoạn xương sắp theo khoảng cách từ p: (khoảng cách, tên)."""
    d = []
    for n, h, t in segs:
        seg = t - h
        k = max(0.0, min(1.0, (p - h).dot(seg) / seg.length_squared))
        d.append(((p - (h + seg * k)).length, n))
    d.sort()
    return d


def split2(d, w, total):
    """Chia trọng số total cho đoạn gần nhất và đoạn kề nó để chỗ gập mềm."""
    inv = [1.0 / (dist + .004) ** 3 for dist, _ in d[:2]]
    for (dist, n), iv in zip(d[:2], inv):
        w[n] = w.get(n, 0) + total * iv / sum(inv)


groups = {n: cat.vertex_groups.new(name=n) for n in BONES if n != 'root'}
TAIL_SEGS = [(n, Vector(BONES[n][0]), Vector(BONES[n][1])) for n in TAIL]
for v in cat.data.vertices:
    x, y, z = v.co
    p = Vector((x, y, z))
    w = {}
    # Chân: cột dưới thân. Phần thấp theo hẳn chân, lên gần thân thì chuyển dần sang chest/hips.
    # Trong chân, mỗi đỉnh chia cho 2 đoạn gần nhất (vai-khuỷu, khuỷu-cổ chân, bàn chân).
    for leg, segs in LEG_SEGS.items():
        a, e = segs[0][1], segs[1][2]
        top = .2 if leg[0] == 'F' else .17
        ly = (a.y + e.y) / 2
        if abs(x - a.x) < .05 and abs(y - ly) < .085 and z < top + .04:
            # Chỉ lấy đỉnh nằm quanh ống chân (bán kính chân ~3–4 cm): ức và bụng sát chân vẫn theo thân,
            # nếu không khi chân co lên ngực, da ức bị kéo thành mảng
            d = nearest_segments(p, segs)
            r_in, r_out = (.042, .062) if leg[0] == 'F' else (.05, .075)
            split2(d, w, ramp(z, top + .04, top - .06) * ramp(d[0][0], r_out, r_in))
    # Đầu: phía trước và cao hơn cổ
    if y < -.05 and z > .3:
        w['head'] = ramp(z, .31, .37) * ramp(y, -.05, -.11)
    m = mat_of.get(v.index, '')
    # Mắt: theo trọn xương mắt
    if m.startswith('Mat') or m.startswith('Sang'):
        w = {'eye_L' if x < .035 else 'eye_R': 1.0}
    # Tai: phần trên chân tai theo xương tai
    elif z > .5 and y < -.1 and abs(x - mid_x) > .035:
        ear = 'ear_L' if x < mid_x else 'ear_R'
        k = ramp(z, .5, .545)
        w = {ear: k, 'head': 1.0 - k}
    # Khăn: phần dưới cổ (nút, mép rủ) theo xương khăn
    elif m == 'Khan' and z < .32:
        k = ramp(z, .32, .28)
        w = {n: val * (1 - k) for n, val in w.items()}
        w['scarf'] = k
    # Đuôi: mỗi đỉnh chia trọng số cho đốt gần nhất và đốt kề nó, để chỗ gập mềm
    if y > .17 and z > .18:
        d = nearest_segments(p, TAIL_SEGS)
        if d[0][0] < (.08 if d[0][1] in ('tail_1', 'tail_2') else .09):
            split2(d, w, ramp(y, .17, .21) if d[0][1] == 'tail_1' else 1.0)
    # Còn lại thuộc thân: nửa trước theo chest, nửa sau theo hips, chuyển mượt ở giữa lưng
    rest = max(0.0, 1.0 - sum(w.values()))
    if rest > 0:
        k = ramp(y, .08, -.04)
        w['chest'] = w.get('chest', 0) + rest * k
        w['hips'] = w.get('hips', 0) + rest * (1 - k)
    for n, val in w.items():
        if val > 0.001:
            groups[n].add([v.index], val, 'REPLACE')

# Kiểm tra theo quy trình duyệt mèo: đỉnh ở đuôi phải theo đuôi gần trọn (≥ 0,9),
# nếu không lông bị kéo thành mảng khi đuôi cử động
gi = {g.index: g.name for g in cat.vertex_groups}
weak = 0
for v in cat.data.vertices:
    if v.co.y > .24 and v.co.z > .2:   # khúc đuôi đã ra khỏi mông
        tw = sum(g.weight for g in v.groups if gi[g.group].startswith('tail'))
        weak += tw < .9
print('tail verts with tail weight < 0.9:', weak)
assert weak == 0

cat.parent = arm
md = cat.modifiers.new('Armature', 'ARMATURE')
md.object = arm

for o in bpy.context.scene.objects:
    o.select_set(o in (cat, arm))
bpy.ops.export_scene.gltf(filepath=dst, use_selection=True, export_vertex_color='ACTIVE',
                          export_skins=True, export_animations=False)
print('exported', dst)
