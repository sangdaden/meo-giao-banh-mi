"""Rút 18 animation G2 (Sang duyệt 21/10) từ bo_g2.glb (export_glb.py) thành assets/models/bo_dong_tac.json cho player.gd.
Mỗi động tác: thời lượng, lặp hay không, và từng khung (30 khung/giây) của các xương có cử động:
xoay (quaternion x,y,z,w), vị trí (chỉ xương có dịch), tỉ lệ (chỉ xương mắt). Số liệu là biến đổi cục bộ của xương
y như glTF (3 số lẻ; kênh đứng yên chỉ ghi 1 khung), nên Godot đặt thẳng vào set_bone_pose_*. Thêm cờ "tui3" (túi 3 ổ đang ngậm hay không) theo từng khung.
Chạy: python3 tools/dong_tac_bo/xuat_json.py <bo_g2.glb> assets/models/bo_dong_tac.json
Thêm vài động tác vào file có sẵn (vd 4 clip A3 xuất riêng bằng ONLY=cho_khen,...): thêm cờ --gop."""
import json
import struct
import sys

sys.path.insert(0, __file__.rsplit('/', 1)[0])
import anims  # noqa: E402  (chỉ cần math, không cần bpy)

src, dst = sys.argv[1], sys.argv[2]
GOP = '--gop' in sys.argv
b = open(src, 'rb').read()
jl = struct.unpack('<I', b[12:16])[0]
J = json.loads(b[20:20 + jl])
off = 20 + jl
binc = b[off + 8:off + 8 + struct.unpack('<I', b[off:off + 4])[0]]
NCOMP = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4}


def acc(i):
    a = J['accessors'][i]
    bv = J['bufferViews'][a['bufferView']]
    n = NCOMP[a['type']]
    start = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
    vals = struct.unpack_from(f'<{a["count"] * n}f', binc, start)
    return [vals[k * n:(k + 1) * n] for k in range(a['count'])]


joints = {J['nodes'][i]['name'] for i in J['skins'][0]['joints']}
# Dáng nghỉ của Bơ: giống mèo khác (cùng tên xương, khác số đo) lấy phần chênh so với dáng nghỉ này
rest = {}
for i in J['skins'][0]['joints']:
    n = J['nodes'][i]
    rest[n['name']] = {'r': [round(x, 5) for x in n.get('rotation', [0, 0, 0, 1])],
                       'p': [round(x, 5) for x in n.get('translation', [0, 0, 0])]}
out = {'fps': 30, 'rest': rest, 'clips': {}}
for an in J['animations']:
    meta = anims.ANIMS[an['name']]
    clip = {'dur': meta['dur'], 'loop': meta['loop'], 'bones': {}}
    for ch in an['channels']:
        node = J['nodes'][ch['target']['node']]['name']
        path = ch['target']['path']
        s = an['samplers'][ch['sampler']]
        vals = acc(s['output'])
        if node == 'Tui3oPivot' and path == 'scale':
            clip['tui3'] = [1 if v[0] > .5 else 0 for v in vals]
            continue
        if node not in joints:
            continue
        key = {'rotation': 'r', 'translation': 'p', 'scale': 's'}[path]
        if key != 'r' and max(abs(v[k] - vals[0][k]) for v in vals for k in range(3)) < 1e-4 and node != 'root':
            continue     # vị trí, tỉ lệ không đổi: giữ dáng nghỉ
        if key == 's' and not node.startswith('eye'):
            continue
        if max(abs(v[k] - vals[0][k]) for v in vals for k in range(len(v))) < 2e-3:
            vals = vals[:1]  # đứng yên suốt động tác: chỉ giữ một khung
        clip['bones'].setdefault(node, {})[key] = [round(x, 3) for v in vals for x in v]
    out['clips'][an['name']] = clip
if GOP:
    cu = json.load(open(dst))
    cu['clips'].update(out['clips'])
    out = cu
json.dump(out, open(dst, 'w'), separators=(',', ':'))
print('xong', dst, len(out['clips']), 'động tác')
