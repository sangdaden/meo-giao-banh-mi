"""Q1 "Gói nhẹ bản web" + PD-4 "index.pck ≤ 20 MB": chia đồ trong assets/ thành gói tải sau, ghi tools/goi_web/goi.json.

Dùng: python3 tools/goi_web/lap_goi.py <thư mục log của ghi_file_mo.sh>

Luật chia (mỗi file một chỗ):
- index.pck: file trang chủ mở được (log chung.menu, menu.*), và file bot không bao giờ mở (gọi theo tên ghép,
  đường hiếm: để lại cho chắc). Trang chủ hiện lên khi chỉ có index.pck.
- tu_do: mọi giống mèo bản đủ (assets/models/skin/giong/). Chỉ cần khi mở Tủ đồ, khi Bơ mặc giống khác
  hay là mèo cái, và ngày có nhiều mèo (Thứ Bảy, Chủ Nhật). Mèo hàng xóm trên web dùng bản nhẹ giong_nhe/.
- pho: đồ để chơi Thứ Hai: phố Thứ Hai, bếp (mọi ngày), màn dạy chơi, phim mở đầu. Trang chủ tải gói này
  ở nền ngay khi hiện; mọi ngày đều cần nó.
- <mã ngày> (thu_ba ... chu_nhat): file chỉ ngày đó mở, như Q1.
- sau: file từ hai ngày Thứ Ba–Chủ Nhật trở lên cùng mở (hay phim kết tuần), Thứ Hai không mở.
scripts/goi_web.gd tải gói cần trước khi vào cảnh (màn chờ có % và mẹo chơi), rồi tải nốt các gói khác ở nền.
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
    logs_set = {}
    for fn in glob.glob(os.path.join(logs, '*.txt')):
        logs_set[os.path.basename(fn)[:-4]] = opened(fn, root, imported)
    def union(pred):
        return set().union(*[v for k, v in logs_set.items() if pred(k)])
    menu = union(lambda k: k == 'chung.menu' or k.startswith('menu.'))
    first = union(lambda k: k.startswith('ngay.thu_hai') or k.startswith('chung.bep.') or k in ('chung.tap', 'chung.mo_dau'))
    later = {d: union(lambda k, d=d: k == 'ngay.' + d or k.startswith('ngay.' + d + '.')) for d in DAYS[1:]}
    shared = union(lambda k: k == 'chung.ket_tuan')
    assets = sorted(p for p in glob.glob('assets/**/*', recursive=True)
                    if os.path.isfile(p) and not p.endswith(('.import', '.md', '.txt')))
    goi = {k: [] for k in ['tu_do'] + DAYS[1:] + ['sau', 'pho']}
    for p in assets:
        if p.startswith(TU_DO):
            goi['tu_do'].append(p)
        elif p in menu:
            continue
        elif p in first:
            goi['pho'].append(p)
        else:
            days = [d for d in DAYS[1:] if p in later[d]]
            if len(days) == 1 and p not in shared:
                goi[days[0]].append(p)
            elif days or p in shared:
                goi['sau'].append(p)
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'goi.json')
    json.dump({'goi': {k: {'files': v} for k, v in goi.items()}}, open(out, 'w'), indent=1, ensure_ascii=False)
    for k, v in goi.items():
        mb = sum(os.path.getsize(p) for p in v) / 1048576
        print('%-9s %3d file, %.1f MB nguồn' % (k, len(v), mb))


if __name__ == '__main__':
    main()
