"""Ghép bảng hiệu vòng 3 vào assets/models/nha_rap/nha_rap.json (mục "bang").
Đọc thư mục ra của `run_bang_v3.py game` (mỗi bảng một bang_*.json) và bảng tra chữ của atlas_chu_v3.py.
Dùng: python3 ghep_bang_v3.py <thư_mục_bang> <chu_uv.json> <nha_rap.json>"""
import sys, os, json, glob

SRC, UV, DST = sys.argv[1:4]
uv = json.load(open(UV))
meta = json.load(open(DST))
bang = {}
for f in sorted(glob.glob(os.path.join(SRC, 'bang_*.json'))):
    name = os.path.basename(f)[:-5]
    m = json.load(open(f))
    bang[name] = dict(tris=m['tris'], min=m['min'], max=m['max'], tiem=m['tiem'], ten=m['ten'], rong=m['rong'], chu=uv.get(name, []))
meta['bang'] = bang
json.dump(meta, open(DST, 'w'), ensure_ascii=False, separators=(',', ':'))
print('bang', len(bang), 'tam giác', sum(b['tris'] for b in bang.values()))
