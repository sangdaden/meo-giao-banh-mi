# Phác thảo model bằng Blender chạy ngầm

Dựng bản phác Bơ bằng Blender thật (module `bpy`), không cần mở giao diện.

```bash
pip install bpy scikit-image          # bpy = Blender 5.2 dạng thư viện Python
mkdir -p out
python3 bo_sdf.py 0.003 out           # dựng dáng bằng SDF + hòa khối mềm -> out/bo_body.npz, out/bo_scarf.npz
python3 bo_blender.py out q34,side,front,back,face 64 1000 --glb
                                      # render Cycles + xuất out/bo_sdf.glb, out/bo_sdf.blend
```

- `bo_sdf.py`: các khối (ellipsoid, côn bo) hòa vào nhau, khoét hốc mắt, tô vằn lông theo vùng. Toạ độ theo three.js (mét, Y lên, mèo nhìn +Z), tỉ lệ khớp `bo-model.js`.
- `bo_blender.py`: nạp lưới vào Blender, thêm mắt, ria, vật liệu, đèn, camera; render và xuất.

Đây là bản phác để duyệt dáng. Model chơi game vẫn tự dựng tay trong Blender (lưới thưa + rig 22 xương).
