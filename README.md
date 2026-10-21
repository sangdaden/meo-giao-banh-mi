# Mèo Giao Bánh Mì

Game 3D góc nhìn thứ ba làm bằng **Godot 4** (ráp game) và **Blender** (model, rig, animation). Mèo cam Bơ nhận bánh ở lò Cô Ba rồi chạy nhảy khắp khu phố để giao kịp giờ cho 5 khách.

Đây là **bản chơi thử**: mèo Bơ đã dùng model kiểu D "Chững chạc" (bản tạm rút gọn từ model phác thảo), còn phố, khách và Chó Mực vẫn là khối hộp tạm. Mục tiêu là thử cảm giác chạy nhảy và vòng giao đơn trước khi làm đồ họa thật.

![Toàn cảnh khu phố](docs/toan-canh.png)

| Lò bánh Cô Ba | Đơn 5: Chó Mực canh hẻm |
|---|---|
| ![Lò bánh](docs/lo-banh.png) | ![Chó Mực](docs/cho-muc.png) |

## Chơi ngay trên trình duyệt

**https://sangdaden.github.io/meo-giao-banh-mi/**

Mở bằng Chrome, Edge hoặc Firefox trên máy tính. Lần đầu tải khoảng 35 MB. Bấm vào khung game để camera bắt chuột; Esc trả chuột lại.

Bản web tự cập nhật mỗi lần nhánh `main` thay đổi (GitHub Actions trong `.github/workflows/pages.yml` xuất bản web rồi đăng lên GitHub Pages). Bản web dùng renderer Compatibility (WebGL 2) nên ánh sáng hơi khác bản chạy trong Godot.

Khi có bản mới, trang đang mở tự biết (mỗi phút hỏi file `version.json` một lần, và mỗi khi quay lại tab). Trang tải sẵn file mới rồi hiện thông báo "Có bản mới!" và tự tải lại sau 10 giây; bấm **Để sau** nếu đang chơi dở. Mã nằm ở `web/update-check.js`; GitHub Actions ghi mã commit vào file này và vào `version.json` mỗi lần đăng.

## Tải bản Windows

**https://github.com/sangdaden/meo-giao-banh-mi/releases/download/ban-moi-nhat/MeoGiaoBanhMi-windows.zip**

Link này luôn trỏ tới bản mới nhất của nhánh `main`, gửi cho bạn bè chơi thử được ngay. Chạy trên Windows 10/11 64-bit, card đồ họa hỗ trợ Vulkan (hầu hết máy từ 2016 trở lại đây).

1. Tải file zip (khoảng 30 MB), **giải nén** ra một thư mục.
2. Bấm đúp **MeoGiaoBanhMi.exe**.
3. Nếu Windows hiện "Windows protected your PC", bấm **More info** rồi **Run anyway**. Game chưa ký số nên Windows cảnh báo vậy.

Các bản đã đánh số nằm ở trang [Releases](https://github.com/sangdaden/meo-giao-banh-mi/releases).

Cách bản Windows được làm ra (`.github/workflows/windows.yml`):

- Mỗi lần nhánh `main` thay đổi, GitHub Actions xuất `.exe` bằng Godot 4.3, gắn icon `icon.ico` (qua rcedit chạy bằng wine), cho `.exe` tự chơi hết 5 đơn bằng `--autotest` để chắc nó chạy được, rồi thay file trong bản phát hành **Bản mới nhất** (tag `ban-moi-nhat`).
- Muốn có một bản đánh số riêng: tạo tag `v` + số, ví dụ `git tag v0.1.0 && git push origin v0.1.0`. Actions tạo bản phát hành `v0.1.0`, số này cũng được ghi vào thông tin file `.exe`.
- Mỗi pull request cũng được xuất và chạy thử; file zip nằm ở mục **Artifacts** của lượt chạy.

Trong `export_presets.cfg` còn có sẵn preset **Android** (arm64, chưa ký) cho tuần làm bản điện thoại. Muốn xuất Android cần cài Android SDK và bật `rendering/textures/vram_compression/import_etc2_astc` trong Project Settings.

## Mở và chơi trong Godot 4

1. Tải **Godot 4.3** trở lên (bản Standard, không cần bản .NET) ở [godotengine.org/download](https://godotengine.org/download). Giải nén là chạy được, không cần cài.
2. Tải code về máy: bấm nút xanh **Code → Download ZIP** trên GitHub rồi giải nén, hoặc `git clone` repo này.
3. Mở Godot, ở Project Manager bấm **Import**, chọn file `project.godot` trong thư mục vừa giải nén, rồi bấm **Import & Edit**.
4. Lần đầu mở, Godot mất vài giây để nhập project. Xong thì bấm **F5** (hoặc nút ▶ góc trên bên phải) để chơi.

## Cách chơi

| Phím | Tay cầm | Việc |
|---|---|---|
| W A S D hoặc phím mũi tên | cần trái | chạy |
| Shift (giữ) | RB hoặc X | chạy nhanh |
| Space | A | nhảy (giữ lâu nhảy cao, bấm nhanh nhảy thấp) |
| Chuột | cần phải | xoay camera |
| Esc | Start | tạm dừng, trả chuột |
| Enter | | bắt đầu, chơi lại |
| F3 | | hiện hoặc ẩn bộ đếm FPS |

Vòng chơi:

1. Chạy tới vòng tròn cam trước **Lò bánh Cô Ba** để nhận bánh. Đồng hồ bắt đầu đếm ngược từ lúc nhận.
2. Theo **mũi tên đỏ** trên đầu mèo và **cột sáng vàng** ở chỗ khách. Thanh dưới màn hình cho biết còn bao nhiêu mét.
3. Bước vào vòng tròn đỏ dưới chân khách là giao xong. Còn nhiều giờ thì được nhiều sao (3 sao nếu còn từ một nửa thời gian).
4. Hết giờ thì đơn tính là trễ, quay về lò nhận đơn tiếp.
5. **Đơn 5** có **Chó Mực** thức dậy canh hẻm cạnh công viên. Lại gần là nó đuổi; bị đớp thì văng ra và mất 3 giây. Nhảy qua đầu nó thì an toàn.
6. Giao xong 5 đơn là hiện bảng tổng kết sao.

| Đơn | Khách | Món | Thời gian |
|---|---|---|---|
| 1 | Chú Tư · Sạp báo | 1 ổ pate | 18 giây |
| 2 | Bé Na · Chung cư | 2 ổ trứng | 24 giây |
| 3 | Chị Mây · Cà phê Mây | 2 ổ thịt nguội | 20 giây |
| 4 | Anh Hùng · Sửa xe | 3 ổ xíu mại | 30 giây |
| 5 | Bà Sáu · Nhà bông giấy | 1 ổ chả cá | 24 giây, có Chó Mực |

## Chỉnh cảm giác tay

Mọi con số chỉnh được đều nằm ở đầu file script, có chú thích tiếng Việt:

- `scripts/player.gd`: tốc độ chạy, tăng tốc, độ cao nhảy, trọng lực, coyote time (vẫn nhảy được ngay sau khi rời mép), jump buffer (bấm nhảy hơi sớm vẫn tính).
- `scripts/camera_rig.gd`: độ nhạy chuột, khoảng cách camera.
- `scripts/dog.gd`: tốc độ đuổi và tầm nhìn của Chó Mực.
- `scripts/main.gd`: danh sách 5 đơn (vị trí, thời gian), phạt khi bị đớp, `time_multiplier` để nới giờ cho mọi đơn.

## Cấu trúc project

```
project.godot          cấu hình project
scenes/main.tscn       scene duy nhất, gắn script main.gd
scripts/
  main.gd              vòng chơi: nhận bánh, giao đơn, đồng hồ, mũi tên, phím điều khiển
  player.gd            mèo Bơ: chạy, nhảy, animation tạm bằng code
  camera_rig.gd        camera sau lưng mèo (SpringArm3D tránh xuyên tường)
  dog.gd               Chó Mực: ngủ, thức dậy ở đơn 5, đuổi, đớp
  city.gd              dựng khu phố 6 khối theo bản đồ trong sổ phác thảo
  hud.gd               thẻ đơn, đồng hồ, 5 chấm tiến độ, màn bắt đầu, tạm dừng, kết thúc
  timer_ring.gd        đồng hồ vòng tròn
  blocks.gd            hàm tiện ích dựng khối hộp tạm, gộp mesh cho nhẹ
  sound.gd             autoload "Sound": bus Music/SFX/Ambience, phát tiếng, đổi nhạc, lưu âm lượng
  sound_panel.gd       nút loa góc phải dưới và bảng chỉnh âm lượng
  sound_director.gd    gắn tiếng vào màn giao bánh (bước chân, nhận/giao đơn, đồng hồ, Chó Mực)
assets/audio/          nhạc và tiếng động, nguồn và giấy phép ở assets/audio/NGUON.md
tools/sound/synth.py   tự tổng hợp toàn bộ file âm thanh (pip install numpy scipy, cần ffmpeg)
assets/models/bo.glb   mèo Bơ kiểu D: ~6,3k tam giác, 16 xương (bản tạm)
tools/bo_game.py       tạo bo.glb từ model phác thảo bằng Blender (pip install bpy)
web/update-check.js    bản web tự nhắc tải lại khi có bản mới
docs/                  ảnh chụp cho README (Godot bỏ qua thư mục này)
```

Khu phố rộng 96 × 60 m, gốc tọa độ ở giữa ngã tư; trục X là đông, trục Z là nam, đúng với bản đồ 2D trong sổ phác thảo (1 điểm ảnh = 0,1 m). Layer va chạm: 1 thế giới (đất, nhà), 2 mèo, 4 Chó Mực, 8 đồ vật (thùng, xe, cột, ghế, cây, người). Camera chỉ né layer 1 nên không giật khi mèo chạy qua đồ vật nhỏ.

Model Bơ hiện tại tạo bằng `python3 tools/bo_game.py chung2.glb assets/models/bo.glb`: giảm tam giác, dồn màu lông vào màu đỉnh, gắn 16 xương (đầu, 4 chân, 4 đốt đuôi, 2 tai, 2 mắt, khăn). Game tự xoay các xương này bằng code (hàm `_animate` trong player.gd): chân vung, thân nghiêng khi quẹo và chúi khi tăng tốc, đầu gật và ngó quanh, tai cụp khi chạy, mắt chớp, khăn đung đưa; đuôi (dài ~0,30 m, khoảng 0,55 lần đầu + thân như mèo thật) là chuỗi lò xo nên tự đổi dáng khi đứng, đi, chạy, nhảy, quẹo. Model chính thức 22 xương có animation làm trong Blender sẽ thay vào sau.

Bản khối thô dựng mọi thứ bằng code để dễ đọc từ trên xuống. Khi model Blender xong (tuần 2 và 3), mèo, chó và các mảnh phố sẽ thành scene `.tscn` riêng, thay cho các khối hộp.

## Âm thanh

Toàn bộ nhạc và tiếng động do `tools/sound/synth.py` tự tổng hợp, không dùng mẫu của ai nên không vướng giấy phép (CC0, chi tiết ở `assets/audio/NGUON.md`). Có 4 bài nhạc nền lặp (menu, giao bánh, bị Chó Mực đuổi, bếp), 2 nhạc kết, tiếng nền phố và bếp, cùng khoảng 35 hiệu ứng.

- Gọi từ code: `Sound.play("jump")`, `Sound.music("chase")`, `Sound.ambience("street")`, `Sound.loop("sizzle")` / `Sound.stop_loop("sizzle")`. Tên không có file thì bỏ qua.
- Âm lượng: nút loa góc phải dưới (hiện ở màn bắt đầu, tạm dừng, kết thúc), phím **M** tắt/bật tiếng bất cứ lúc nào. Lưu vào `user://am_thanh.cfg`.
- Cân to nhỏ giữa các tiếng: bảng `LEVEL` đầu file `scripts/sound.gd`. Nhịp bước chân, mấy giây cuối kêu tích tắc, tầm sủa của chó: hằng số đầu `scripts/sound_director.gd`.
- Bản web: trình duyệt chặn âm thanh cho tới cú bấm hoặc phím đầu tiên; Godot tự mở lại khi người chơi bấm, nên nhạc menu bắt đầu ngay khi chạm vào trang.
- In tên từng tiếng ra console khi chạy thử: thêm `--sound-log`, ví dụ `godot --path . -- --sound-log`.

## Tự kiểm tra

Lệnh sau cho mèo tự "dịch chuyển" qua cả 5 đơn, ghé Chó Mực để thử bị đớp, rồi in `AUTOTEST OK` nếu mọi thứ chạy đúng:

```
godot --headless --path . -- --autotest
```

## Xuất bản chạy trên Windows

1. Trong Godot: **Editor → Manage Export Templates → Download and Install** (chỉ làm một lần).
2. **Project → Export**, chọn sẵn preset **Windows Desktop**, bấm **Export Project**. File `.exe` nằm trong thư mục `export/`, gửi cho người khác chạy thử được luôn.

## Bước tiếp theo

- Tuần 2: model chính thức, rig 22 xương và animation của Bơ; Chó Mực kiểu D (theo model sheet đã duyệt).
- Tuần 3: bộ mảnh phố modular.
- Lộ trình đầy đủ ở sổ phác thảo của dự án.

## Giấy phép

MIT, xem file [LICENSE](LICENSE).
