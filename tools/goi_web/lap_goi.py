"""Q1 "Gói nhẹ bản web": chia đồ trong assets/ thành gói tải sau, ghi tools/goi_web/goi.json.

Dùng: python3 tools/goi_web/lap_goi.py <thư mục log của ghi_file_mo.sh>

Luật chia:
- tu_do: mọi giống mèo bản đủ (assets/models/skin/giong/). Chỉ cần khi mở Tủ đồ, khi Bơ mặc giống khác
  hay là mèo cái, và ngày có nhiều mèo (Thứ Bảy, Chủ Nhật). Mèo hàng xóm trên web dùng bản nhẹ giong_nhe/.
- <mã ngày> (thu_ba ... chu_nhat): file chỉ được mở khi bot chơi đúng ngày đó, không mở ở ngày khác,
  không mở ở trang chủ, màn dạy chơi hay phim. Thứ Hai không có gói: người chơi mới vào thẳng Thứ Hai.
- Còn lại nằm trong index.pck.
scripts/goi_web.gd tải gói của ngày trước khi vào ngày (màn chờ), rồi tải nốt các gói khác ở nền.
"""
import glob, json, os, re, sys

DAYS = ['thu_hai', 'thu_ba', 'thu_tu', 'thu_nam', 'thu_sau', 'thu_bay', 'chu_nhat']
TU_DO = 'assets/models/skin/giong/'


def opened(fn, root, imported):
    s = set()
    for line in open(fn, errors='ignore'):
        m = re.search(r'openat\([^"]*"([^"]+)"', line)
        if not m or 'ENOENT' in line:
            continue
        p = m.group(1)
        if not p.startswith(root + '/'):
            continue
        p = p[len(root) + 1:]
        p = imported.get(p, p)
        if p.endswith('.import'):
            p = p[:-7]
        s.add(p)
    return s


def main():
    logs = sys.argv[1]
    root = os.getcwd()
    imported = {}  # .godot/imported/x.glb-<hash>.scn -> assets/.../x.glb
    for imp in glob.glob('assets/**/*.import', recursive=True):
        for line in open(imp, errors='ignore'):
            m = re.match(r'path[^=]*="res://(.*)"', line)
            if m:
                imported[m.group(1)] = imp[:-7]
    day_used = {d: set() for d in DAYS}
    common = set()
    for fn in glob.glob(os.path.join(logs, '*.txt')):
        name = os.path.basename(fn)[:-4]
        s = opened(fn, root, imported)
        if name.startswith('ngay.'):
            day_used[name.split('.')[1]] |= s
        else:
            common |= s
    assets = sorted(p for p in glob.glob('assets/**/*', recursive=True)
                    if os.path.isfile(p) and not p.endswith(('.import', '.md', '.txt')))
    goi = {'tu_do': [p for p in assets if p.startswith(TU_DO)]}
    for d in DAYS[1:]:
        others = common.union(*[day_used[o] for o in DAYS if o != d])
        goi[d] = [p for p in assets if p in day_used[d] and p not in others and not p.startswith(TU_DO)]
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'goi.json')
    json.dump({'goi': {k: {'files': v} for k, v in goi.items()}}, open(out, 'w'), indent=1, ensure_ascii=False)
    for k, v in goi.items():
        mb = sum(os.path.getsize(p) for p in v) / 1048576
        print('%-9s %3d file, %.1f MB nguồn' % (k, len(v), mb))


if __name__ == '__main__':
    main()
