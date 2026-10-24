"""Q1 "Gói nhẹ bản web": tách index.pck của bản web thành gói chung + gói riêng từng ngày.

Đồ chỉ một ngày dùng (danh sách ở tools/goi_web/goi.json, làm bằng tools/goi_web/lap_goi.py) được rút
khỏi index.pck và ghi ra goi/<tên gói>.pck. index.pck nhận thêm res://goi_web.json (tên file, cỡ, md5
của từng gói) để scripts/goi_web.gd biết tải gì khi vào ngày đó. Bản desktop không qua bước này.

Dùng (sau khi xuất bản web):
  python3 tools/goi_web/tach_goi.py build/web/index.pck [tools/goi_web/goi.json]
"""
import hashlib, json, os, re, struct, sys

ALIGN = 16  # Godot 4.3 đặt dữ liệu mỗi file cách nhau bội 16 byte


def read_pck(fn):
    d = open(fn, 'rb').read()
    assert d[:4] == b'GDPC', 'không phải file pck'
    head = d[4:20]  # phiên bản pck + phiên bản Godot (4.3.0)
    flags, base = struct.unpack('<IQ', d[20:32])
    assert flags == 0, 'pck mã hóa hay kiểu lạ, chưa hỗ trợ'
    off = 32 + 64
    n = struct.unpack('<I', d[off:off + 4])[0]
    off += 4
    files = []
    for _ in range(n):
        L = struct.unpack('<I', d[off:off + 4])[0]
        off += 4
        p = d[off:off + L].rstrip(b'\0').decode()
        off += L
        o, s = struct.unpack('<QQ', d[off:off + 16])
        off += 16 + 16 + 4
        files.append((p, d[base + o:base + o + s]))
    return head, files


def write_pck(fn, head, files):
    dir_size = 32 + 64 + 4
    for p, _ in files:
        dir_size += 4 + _pad(len(p.encode()) + 1, 4) + 16 + 16 + 4
    base = _pad(dir_size, ALIGN)
    out = bytearray(b'GDPC' + head + struct.pack('<IQ', 0, base) + b'\0' * 64 + struct.pack('<I', len(files)))
    data = bytearray()
    for p, b in files:
        pb = p.encode()
        L = _pad(len(pb) + 1, 4)
        out += struct.pack('<I', L) + pb + b'\0' * (L - len(pb))
        out += struct.pack('<QQ', len(data), len(b)) + hashlib.md5(b).digest() + struct.pack('<I', 0)
        data += b + b'\0' * (_pad(len(b), ALIGN) - len(b))
    out += b'\0' * (base - len(out))
    with open(fn, 'wb') as f:
        f.write(out)
        f.write(data)


def _pad(n, a):
    return (n + a - 1) // a * a


def members(src, by_path):
    """Các mục trong pck thuộc về một file nguồn: chính nó, .import/.remap và file đã nhập mà chúng trỏ tới."""
    out = []
    for p in ['res://' + src, 'res://' + src + '.import', 'res://' + src + '.remap']:
        if p in by_path:
            out.append(p)
            if p.endswith(('.import', '.remap')):
                for t in re.findall(r'^path[^=]*="(res://[^"]+)"', by_path[p].decode(errors='ignore'), re.M):
                    if t in by_path:
                        out.append(t)
    return out


def main():
    pck = sys.argv[1]
    plan = json.load(open(sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(__file__), 'goi.json')))
    head, files = read_pck(pck)
    by_path = dict(files)
    out_dir = os.path.join(os.path.dirname(pck), 'goi')
    os.makedirs(out_dir, exist_ok=True)
    taken = set()
    manifest = {}
    for name, info in plan['goi'].items():
        mine = []
        for src in info['files']:
            for p in members(src, by_path):
                if p not in taken:
                    taken.add(p)
                    mine.append(p)
        if not mine:
            continue
        fn = os.path.join(out_dir, name + '.pck')
        write_pck(fn, head, [(p, by_path[p]) for p in sorted(mine)])
        blob = open(fn, 'rb').read()
        manifest[name] = {'file': 'goi/%s.pck' % name, 'size': len(blob), 'md5': hashlib.md5(blob).hexdigest()}
    rest = [(p, b) for p, b in files if p not in taken]
    rest.append(('res://goi_web.json', json.dumps(manifest, indent=1, sort_keys=True).encode()))
    before = os.path.getsize(pck)
    write_pck(pck, head, rest)
    # index.html ghi sẵn cỡ index.pck cho thanh tải lúc mở trang: sửa theo cỡ mới
    html = os.path.join(os.path.dirname(pck), 'index.html')
    if os.path.exists(html):
        t = open(html, encoding='utf-8').read()
        t = re.sub(r'("index\.pck":)\d+', lambda m: m.group(1) + str(os.path.getsize(pck)), t)
        open(html, 'w', encoding='utf-8').write(t)
    mb = lambda n: n / 1048576
    print('index.pck: %.1f MiB -> %.1f MiB' % (mb(before), mb(os.path.getsize(pck))))
    for name, m in manifest.items():
        print('  goi/%s.pck  %.1f MiB' % (name, mb(m['size'])))


if __name__ == '__main__':
    main()
