"""In các file nặng nhất trong index.pck (Godot 4.3, pck bản 2) và tổng theo loại, để biết cái gì làm bản web nặng.
Dùng: python3 tools/pck_lon_nhat.py build/web/index.pck [số dòng]"""
import struct, sys, collections

d = open(sys.argv[1], 'rb').read()
top = int(sys.argv[2]) if len(sys.argv) > 2 else 15
assert d[:4] == b'GDPC', 'không phải file pck'
off = 4 + 16 + 12 + 64  # magic, phiên bản, cờ + vị trí gốc, 16 số dự phòng
n = struct.unpack('<I', d[off:off + 4])[0]; off += 4
ent = []
for _ in range(n):
    L = struct.unpack('<I', d[off:off + 4])[0]; off += 4
    p = d[off:off + L].rstrip(b'\0').decode(); off += L
    _, size = struct.unpack('<QQ', d[off:off + 16]); off += 16 + 16 + 4  # vị trí, cỡ, md5, cờ
    ent.append((size, p))
kind = collections.Counter()
for s, p in ent:
    kind[p.rsplit('.', 1)[-1]] += s
print('Theo loại (MiB):', ', '.join('%s %.2f' % (k, v / 1048576) for k, v in kind.most_common(8)))
for s, p in sorted(ent, reverse=True)[:top]:
    print('%6.2f MiB  %s' % (s / 1048576, p.replace('res://.godot/imported/', '')))
