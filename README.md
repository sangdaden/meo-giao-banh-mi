# Mèo Giao Bánh Mì

Game 3D góc nhìn thứ ba làm bằng **Godot 4** (ráp game) và **Blender** (model, rig, animation). Mèo cam Bơ nhận bánh ở lò Cô Ba rồi chạy nhảy khắp khu phố để giao kịp giờ cho 5 khách.

Đây là **bản khối thô (block-out) của tuần 1**: mọi thứ đều là khối hộp tạm, chưa có model Blender. Mục tiêu là thử cảm giác chạy nhảy và vòng giao đơn trước khi làm đồ họa thật.

![Toàn cảnh khu phố](docs/toan-canh.png)

| Lò bánh Cô Ba | Đơn 5: Chó Mực canh hẻm |
|---|---|
| ![Lò bánh](docs/lo-banh.png) | ![Chó Mực](docs/cho-muc.png) |

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
  blocks.gd            hàm tiện ích dựng khối hộp tạm
docs/                  ảnh chụp cho README (Godot bỏ qua thư mục này)
```

Khu phố rộng 96 × 60 m, gốc tọa độ ở giữa ngã tư; trục X là đông, trục Z là nam, đúng với bản đồ 2D trong sổ phác thảo (1 điểm ảnh = 0,1 m). Mèo nằm ở layer va chạm 2, Chó Mực layer 4, thế giới layer 1.

Bản khối thô dựng mọi thứ bằng code để dễ đọc từ trên xuống. Khi model Blender xong (tuần 2 và 3), mèo, chó và các mảnh phố sẽ thành scene `.tscn` riêng, thay cho các khối hộp.

## Tự kiểm tra

Lệnh sau cho mèo tự "dịch chuyển" qua cả 5 đơn, ghé Chó Mực để thử bị đớp, rồi in `AUTOTEST OK` nếu mọi thứ chạy đúng:

```
godot --headless --path . -- --autotest
```

## Xuất bản chạy trên Windows

1. Trong Godot: **Editor → Manage Export Templates → Download and Install** (chỉ làm một lần).
2. **Project → Export**, chọn sẵn preset **Windows Desktop**, bấm **Export Project**. File `.exe` nằm trong thư mục `export/`, gửi cho người khác chạy thử được luôn.

## Bước tiếp theo

- Tuần 2: model, rig và animation mèo Bơ và Chó Mực trong Blender (theo model sheet đã duyệt), thay khối hộp bằng file `.glb`.
- Tuần 3: bộ mảnh phố modular.
- Lộ trình đầy đủ ở sổ phác thảo của dự án.

## Giấy phép

MIT, xem file [LICENSE](LICENSE).
