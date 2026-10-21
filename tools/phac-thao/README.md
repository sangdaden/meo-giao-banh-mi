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

## Phong cách D · Chững chạc (bản Sang duyệt)

```bash
apt-get install -y libegl1 libegl-mesa0 libgl1-mesa-dri libgbm1   # để Eevee chạy ngầm
python3 mature.py chung2 out q34,side,front,face --glb
```

- `mature.py`: hai hướng chững chạc (`chung`, `thuc`) và bản duyệt `chung2` (mắt cười). Hướng dẫn phong cách: `docs/huong-dan-phong-cach.md`.
- `cute.py`: ba bản dễ thương đã thử và bị loại (chibi, thú bông, hoạt hình tròn), giữ lại để tham khảo.

## poly.py: Bơ bằng lưới đa giác (21/10/2026)
Dựng theo 7 bước của ảnh tham khảo "How to Model a Cat in Blender": khối hộp bo tròn làm thân, đùn chân, UV sphere làm đầu, đùn tai, ống trụ cong làm đuôi, Subdivision, tô màu đỉnh, 3 đèn, Eevee. Không dùng SDF.
Chạy: `python3 poly.py <outdir> q34,side,front,face --glb`. File kết quả và render: `/mnt/project-files/meo-3d/bo-poly/`.
