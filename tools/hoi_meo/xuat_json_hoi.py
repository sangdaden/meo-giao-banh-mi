"""Rút 13 động tác G10 từ .glb (export_hoi.py, nướng trên Bơ) thành assets/models/meo_hoi_dong_tac.json, cùng định dạng bo_dong_tac.json
(dùng nguyên tools/dong_tac_bo/xuat_json.py, chỉ thay bảng động tác bằng anims_hoi).
Chạy: python3 xuat_json_hoi.py <hoi_bo.glb> <repo>/assets/models/meo_hoi_dong_tac.json"""
import sys, os, runpy
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import anims_hoi
sys.modules['anims'] = anims_hoi
runpy.run_path('/home/user/meo-giao-banh-mi/tools/dong_tac_bo/xuat_json.py', run_name='__main__')
