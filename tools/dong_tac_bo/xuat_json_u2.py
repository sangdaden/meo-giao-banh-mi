"""Rút 7 động tác U2 "Bơ phản ứng theo ngày" (anims_u2.py, Sang duyệt 24/10/2026) từ bo_u2.glb (export_u2.py)
rồi gộp vào assets/models/bo_dong_tac.json (giữ nguyên các động tác có sẵn; giu_nuoc của G2 không ghi đè).
Dùng nguyên xuat_json.py, chỉ thay bảng động tác bằng anims_u2.
Chạy: python3 tools/dong_tac_bo/xuat_json_u2.py <bo_u2.glb> assets/models/bo_dong_tac.json"""
import json
import os
import runpy
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import anims_u2  # noqa: E402

src, dst = sys.argv[1], sys.argv[2]
tmp = os.path.join(tempfile.mkdtemp(), 'u2.json')
sys.modules['anims'] = anims_u2
sys.argv = [sys.argv[0], src, tmp]
runpy.run_path(os.path.join(HERE, 'xuat_json.py'), run_name='__main__')
moi = json.load(open(tmp))['clips']
cu = json.load(open(dst))
for k, v in moi.items():
    if k in cu['clips'] and k == 'giu_nuoc':
        continue   # clip G2 dùng lại, đã có
    cu['clips'][k] = v
json.dump(cu, open(dst, 'w'), separators=(',', ':'))
print('gộp', [k for k in moi if k != 'giu_nuoc'], '->', dst, len(cu['clips']), 'động tác')
