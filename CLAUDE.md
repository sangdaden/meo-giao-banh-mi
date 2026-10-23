# Sổ tay dự án Mèo Giao Bánh Mì

Đọc file này trước khi sửa repo. Dành cho người mới và cho mọi luồng Claude làm song song.
README.md là hướng dẫn cho người chơi; file này là luật làm việc.

## Ai làm gì

- **Sang** là chủ dự án: duyệt phác thảo, duyệt và **tự gộp (merge) mọi PR**. Không ai khác gộp PR.
- Viết cho Sang bằng **tiếng Việt**, gọi "Sang", xưng "mình". Tên file, biến, commit cũng dùng tiếng Việt không dấu như code đang có (`thu_hai`, `ban_do_nho`, `DoKho.v`).
- Nhiều luồng Claude chạy cùng lúc, mỗi luồng một nhánh `claude/...`, một PR. Không đẩy lên nhánh của luồng khác, không đẩy thẳng lên `main`.
- Không đăng gì ra ngoài (itch.io, mạng xã hội, email) khi Sang chưa đồng ý. Không xin khóa API trong chat; khóa đi vào GitHub secret do Sang tự thêm.

## Luật phác thảo trước

Mọi nhân vật, con vật, đồ vật hay bối cảnh **mới** phải có phác thảo Blender chi tiết trên một trang artifact để Sang duyệt **trước** khi vào game:

- hình trước / ngang / sau, tách từng bộ phận, kích thước tương đối, bảng màu, các trạng thái (nếu có);
- nhân vật: sơ đồ xương và danh sách animation;
- xoay được trên trang (viewer .glb), không dùng tranh 2D.

Phong cách đã duyệt (21/10/2026): hướng **D "Chững chạc"** của Bơ. Tỉ lệ con vật trưởng thành, đầu chỉ hơi to hơn thật, mắt hạnh nhân vui tươi, lông mờ, dựng và render bằng Blender (Eevee). Không chibi, không tròn kiểu thú bông, không quá thật, không dùng máy tạo 3D bằng AI (mọi model phải tự dựng trong Blender).

Chưa duyệt thì code dùng khối tạm (placeholder) và ghi rõ trong PR.

## Độ khó: chỉ chỉnh trong `scripts/do_kho.gd`

Sang (21/10): game phải **dễ và thân thiện**. Mặc định là chế độ "Thong thả"; Cài đặt > "Chế độ thử thách" giữ số cũ.

- Không sửa hằng số độ khó ngay trong file màn chơi. Thêm hoặc đổi một khóa trong `DoKho.EASY`, rồi đọc bằng `DoKho.v("khoa", so_cu)` (Thong thả trả số trong bảng, Thử thách trả `so_cu`).
- Hành vi khác hẳn giữa hai chế độ thì hỏi `DoKho.hard()`. Test ép chế độ bằng `DoKho.force`.
- Mỗi đơn chỉ có **một** việc bắt buộc là giao bánh. Việc phụ chỉ là thưởng, không bao giờ làm mất sao. Không có kiểu thua chặn người chơi.

## Chữ cho người chơi: thêm bản tiếng Anh

Game có hai ngôn ngữ (F3): tiếng Việt mặc định, English chọn ở Cài đặt > Ngôn ngữ hoặc nút góc trang chủ. Code vẫn viết chữ tiếng Việt như cũ; Label, Button, Label3D, tooltip tự dịch qua bảng `scripts/dich/en_*.gd` (khóa là câu Việt đúng như trong code, câu có `%s`/`%d` là mẫu).

- Thêm câu mới hiện cho người chơi thì thêm một dòng `"câu Việt": "English",` vào cuối nhóm file của mình trong bảng (`en_giao_dien`, `en_choi`, `en_bep`, `en_ngay`, `en_hoi_meo`). Câu ghép bằng `+` thì thêm mẫu cho cả câu đã ghép.
- Tên người, tên món kiểu Việt giữ nguyên (Cô Ba, Chú Tư, bánh mì, xe ôm); "Chó Mực" là "Mực the dog".
- Vẽ chữ bằng `draw_string` thì tự gọi `tr()`.
- `tests/test_ngon_ngu.gd` in các câu có dấu chưa có trong bảng; `-- --autotest --lang=en --dich-thieu` in câu còn tiếng Việt lúc chơi.

## Ngân sách (bản web là chuẩn)

Chi tiết và cách đo: `docs/ngan-sach-hieu-nang.md`. Workflow `hieu-nang.yml` chấm mỗi PR, vượt là đỏ.

| Mục | Ngân sách |
|---|---|
| Tam giác mỗi khung (cả bóng) | ≤ 400 000 (ngã tư đang ~394k, gần chạm trần) |
| Lệnh vẽ | ≤ 350 |
| Vật thể nhìn thấy | ≤ 450 |
| `index.pck` | ≤ 60 MB |

- **Thêm gì phải bớt bù.** PR thêm model ra phố phải ghi số tam giác trước/sau ở góc nặng nhất.
- Đồ đứng yên gộp qua `Blocks.merge_static`, dùng chung vật liệu (màu đỉnh). Đồ động đặt `visibility_range_end`. Mảng sát đất tắt bóng. Không thêm OmniLight/SpotLight ngoài phố.
- Ảnh chụp thử, ảnh render không để trong thư mục project (hoặc thêm `.gdignore`), kẻo bị đóng vào `index.pck`.

## Chạy game và test

Godot **4.3** (bản Standard). Máy đám mây chưa có sẵn Godot: tải `Godot_v4.3-stable_linux.x86_64.zip` từ GitHub releases của godotengine như trong `.github/workflows/desktop.yml`, rồi `godot --headless --path . --import` một lần.

```
# Tự chơi một ngày (in "AUTOTEST OK" khi xong)
godot --headless --path . -- --autotest                     # Thứ Hai
godot --headless --path . -- --autotest --ngay=thu_nam      # ngày khác: thu_ba, thu_tu, thu_nam, thu_sau, thu_bay, chu_nhat
godot --headless --path . -- --autotest --don=5             # vào thẳng một đơn

# Test riêng (mỗi file in "... TEST OK" hoặc tương tự)
godot --headless --path . -s tests/test_lien_ngay.gd
godot --headless --path . -s tests/test_<ten>.gd

# Đo hiệu năng giống bản web (cần màn hình ảo)
xvfb-run -a godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 \
  -s tools/do_hieu_nang.gd -- --chup=anh
```

Cờ hay dùng khi thử: `--buoi=pho_mua` (đổi buổi trong ngày), `--ngap` (nước ngập), `--thu-thach` (chế độ khó), `--lang=en` (tiếng Anh), `--giu-fps`, `--canh=pho|bep|menu` (đo một màn). Chụp ảnh soát: các script `tools/chup_*.gd` (chạy với `xvfb-run ... --rendering-driver opengl3 -s tools/chup_<ten>.gd -- <thu_muc_anh>`).

Model: Blender chạy headless qua `pip install bpy` (đang dùng bpy 5.2). Mỗi script xuất .glb trong `tools/` ghi cách chạy ở đầu file (`tools/bo_game.py`, `tools/nguoi_game.py`, `tools/xuat_skin_game.py`, `tools/nha_rap/`, `tools/khu_pho/`...).

## CI (GitHub Actions)

| Workflow | Chạy khi | Làm gì |
|---|---|---|
| `desktop.yml` | mỗi PR và mỗi lần `main` đổi | Xuất Windows (chạy thử `.exe` bằng wine) và macOS; job macOS chạy autotest mọi ngày và gần hết `tests/`. `main` thì thay zip ở bản phát hành `ban-moi-nhat`. |
| `hieu-nang.yml` | mỗi PR | Đo tam giác / lệnh vẽ / dung lượng `index.pck`, đỏ khi vượt ngân sách. Ảnh các góc ở mục Artifacts. |
| `pages.yml` | `main` đổi | Xuất bản web lên https://sangdaden.github.io/meo-giao-banh-mi/ |
| `gop-main.yml` | `main` đổi, PR mở hoặc đẩy thêm | Tự gộp `main` vào các PR đang mở, báo PR đụng (`docs/gop-main.md`). |
| `itch.yml` | chỉ khi bấm Run workflow (hoặc tag `v*` khi biến `ITCH_TU_DONG` = `co`), xem `docs/itch.md` | Đẩy bản web/Windows/Mac lên itch.io; chỉ chạy khi Sang đồng ý. |

- Thêm test mới thì thêm một dòng chạy nó vào job macOS trong `desktop.yml`, kèm `grep -q "<CHU OK>"`.
- Không bỏ qua, tắt hay cách ly test để CI xanh. Không push commit rỗng để chạy lại CI.
- CI vẽ bằng CPU: số tam giác và lệnh vẽ đúng, FPS thì không.

## Bản đồ file

Từ PR #133 (H1, 23/10) mỗi ngày có file riêng, HUD tách thành mảnh, bot tự chơi tách khỏi `main.gd`.

| Phần | File | Luồng phụ trách gần nhất |
|---|---|---|
| Vòng chơi chung, input | `scripts/main.gd`, `scripts/play_mode.gd` | chỉ sửa khi đổi vòng chơi chung; việc riêng của ngày không đặt ở đây |
| Dữ liệu từng ngày (đơn, lời Cô Ba, Cách chơi) | `scripts/ngay/<mã ngày>.gd` (`const DATA`) | luồng của ngày đó. **Không sửa `scripts/days.gd`** (chỉ còn thứ tự ngày và hàm đọc) |
| Ngày ngoài tuần (màn dạy chơi B1...) | file mới `scripts/ngay/<mã>.gd`, rồi `PlayMode.day = "<mã>"` | luồng làm ngày đó |
| Bot tự chơi và chấm kết quả | `scripts/tu_choi_pho.gd` | I1 mở rộng ở đây, không ở `main.gd` |
| HUD màn giao bánh | `scripts/hud.gd` (khung chung + `add_piece()`), mảnh: `ui/hud_ket_qua.gd` (kết quả), `ui/hud_tam_dung.gd` (menu Esc, `HELP_PHO`), `ui/hud_ban_do.gd` (bản đồ nhỏ), `ui/hud_trung.gd` (trứng), `ui/hud_hinh.gd` (icon) | "Chữ hướng dẫn và thẻ nhiệm vụ" (đợt 2) |
| Menu, Cài đặt, Chọn màn, tủ đồ, bản đồ nhỏ | `scripts/ui/` | "Giao diện menu và HUD", "Chọn màn chơi", "Bản đồ nhỏ góc màn hình" |
| Độ khó | `scripts/do_kho.gd` | "Thiết kế màn chơi" |
| Bơ: điều khiển, động tác, rig | `scripts/player.gd`, `scripts/bo_paw.gd`, `tools/bo_game.py`, `tools/dong_tac_bo/` | "Bơ 22 xương"; nút cứu kẹt A2 |
| Camera | `scripts/camera_rig.gd` | A1 "Camera không chui tường" |
| Giao đơn, cách giao, chấm sao | `scripts/deliveries.gd`, `scripts/scoring.gd`, `scripts/game_state.gd` | "Năm cách giao bánh", "Sao, tiền boa và lưu game" |
| Bếp Cô Ba | `scripts/kitchen*.gd`, `scripts/ui/kitchen_hud.gd` | "Thiết kế lại màn bếp" |
| Khu phố: vành phố, nhà, đồ phố | `scripts/vanh_pho.gd`, `scripts/nha_rap.gd`, `scripts/city*.gd`, `scripts/chi_tiet_pho.gd`, `scripts/pho_models.gd`, `scripts/blocks.gd` | "Thiết kế lại khu phố", "Bộ ráp nhà vào game", "Chi tiết phố vào game"; D2 giảm tam giác |
| Xe máy, xe buýt, người qua đường | `scripts/traffic.gd`, `scripts/xe_buyt.gd`, `scripts/nguoi_qua_duong.gd` | "Xe máy ở ngã tư", "Thiết kế lại khu phố" |
| Người dân có xương | `scripts/nguoi.gd`, `scripts/residents.gd`, `tools/nguoi_game.py` | "Người dân vào game" |
| Chó Mực | `scripts/dog.gd`, `scripts/muc_ban.gd` | "Chó Mực ở hẻm 42" |
| Ánh sáng, thời tiết, đèn tối | `scripts/anh_sang.gd`, `scripts/thoi_tiet.gd`, `scripts/den_toi.gd`, `scripts/giu_fps.gd` | "Hoàn thiện hình ảnh Thứ Hai"; D1 màu chiều tà |
| Âm thanh, giọng | `scripts/sound*.gd`, `scripts/bong_thoai.gd`, `tools/sound/`, `assets/audio/` (nguồn ghi ở `NGUON.md`) | "Âm thanh và nhạc"; E1 giọng ú ớ |
| Thứ Ba: chợ, góc cờ, tạp hóa | `scripts/market.gd`, `scripts/chess_corner.gd`, `scripts/shop_tap_hoa.gd` | "Chợ sáng", "Góc cờ tướng", "Tạp hóa và túi trứng" |
| Thứ Tư (mưa, bồ câu, sân thượng) | `scripts/thu_tu*.gd`, `scripts/bo_cau.gd`, `scripts/san_thuong.gd`, `scripts/thang_bang.gd` | "Thứ Tư trong game" |
| Thứ Năm (leo chung cư) | `scripts/thu_nam.gd`, `scripts/chung_cu.gd` | "Màn leo chung cư" |
| Thứ Sáu (đám giỗ, tiệm xe) | `scripts/thu_sau.gd` | "Thứ Sáu trong game" |
| Thứ Bảy (dạo phố, việc nhỏ, Sổ hàng xóm) | `scripts/thu_bay.gd`, `scripts/viec_nho/`, `scripts/so_hang_xom.gd`, `scripts/chup_anh.gd`, `scripts/anh_chung.gd`, `scripts/ui/thu_bay_hud.gd` | "Thứ Bảy dạo phố" |
| Chủ Nhật (Hội mèo) | `scripts/chu_nhat.gd`, `scripts/hoi_meo/`, `scripts/meo_npc.gd` | "Hội mèo" |
| Phim mở đầu, cảnh kết tuần, ảnh 7 ngày | `scripts/phim/` (`phim.gd` chạy chung, `mo_dau.gd`, `ket_tuan.gd`, `canh_phim.gd`, `anh_tuan.gd`), `scenes/phim.tscn`, `tools/phim/do_phim.py` | C1 "Phác thảo mở đầu và kết tuần" |
| Tiệm, mua đồ bằng tiền boa | `scripts/shop.gd`, `scripts/tiem.gd`, `scripts/ui/wardrobe_panel.gd`, `tools/xuat_skin_game.py` | "Skin mèo và phụ kiện", "Giao diện menu và HUD" |
| Test, đo, chụp | `tests/`, `tools/do_hieu_nang.gd`, `tools/chup_*.gd` | luồng nào thêm tính năng thì thêm test của mình; I1 bot tự chơi cả tuần |
| CI | `.github/workflows/` (`gop-main.yml` xem `docs/gop-main.md`, `itch.yml` xem `docs/itch.md`) | "Xuất bản Windows tự động"; H2 tự gộp main; J1 itch.io |
| Ngôn ngữ, bản tiếng Anh | `scripts/ngon_ngu.gd` (autoload `NgonNgu`), `scripts/dich/` | F3 "Bản tiếng Anh" |
| Con vật chung: phím Q, "Bạn bốn chân" | `scripts/con_vat.gd` (`ConVat`: con vật vào nhóm `"con_vat"` + `on_called(pos)`, `ConVat.meet(id)`), `scripts/ui/ban_bon_chan.gd` | "Cơ chế chung con vật" |
| Con vật mới V1–V6 (gà, cá, vịt, bướm, thạch sùng, chuột Tí) | `scripts/con_vat_moi/` (`ConVatMoi.LICH` theo ngày, `MoHinhConVat.put` nạp model), `assets/models/con_vat/` | "Con vật mới vào game" |

## Tránh đụng nhau giữa các PR

`main.gd`, `hud.gd`, `ui/level_select.gd` và `desktop.yml` là nơi hay đụng nhất.

1. **Việc mới đặt vào file mới của riêng mình**, chỉ nối vào file chung bằng vài dòng (gọi hàm, thêm node, thêm khóa). Một hàm `setup()` trong file mới tốt hơn 200 dòng chen vào `main.gd`.
2. Việc riêng của một ngày đi vào file ngày `scripts/ngay/<mã>.gd` qua các khóa ngày (khai báo trong đầu `scripts/days.gd`):
   - `nodes`: script node riêng của ngày, `main.gd` tự thêm vào cảnh phố (có thể có `begin()`, `resume_day() -> bool`);
   - `hud`: mảnh giao diện riêng (Control có biến `hud`), gắn qua `hud.add_piece()`, không sửa `hud.gd`;
   - `help`, `help_note`: bảng "Cách chơi" trong menu Esc của ngày;
   - khóa đơn `quick_assemble`: giao xong đơn thì sang bếp ráp nhanh rồi quay lại.
   Đang có luồng sửa lớn một file chung thì **chờ PR đó gộp** rồi rẽ nhánh từ `main` mới.
3. Trước khi mở PR và mỗi khi `main` đổi: `git fetch origin main && git merge origin/main`, chạy lại test liên quan, rồi đẩy. Gộp (merge), không rebase lại lịch sử đã đẩy.
4. Thêm vào file chung thì thêm **ở cuối nhóm** (cuối danh sách, cuối dict, cuối bước CI) và giữ một mục mỗi dòng, để hai PR cùng thêm ít đụng dòng.
5. PR nhỏ, một việc. Mô tả PR ghi: file chung nào bị sửa, ảnh trước/sau nếu đổi hình, số tam giác nếu thêm model.
6. Workflow `gop-main.yml` (H2) tự gộp `main` vào các PR đang mở; đụng thì gắn nhãn `dung-main` và bình luận cách sửa. Vì bot có thể đẩy commit gộp lên nhánh của mình: **`git pull --no-rebase` trước khi sửa tiếp**, không `push --force`. Luồng sở hữu PR tự sửa khi đụng hoặc CI đỏ. Thứ tự gộp PR cho Sang: `docs/gop-main.md`.

## Nơi để đồ ngoài repo

- Thư mục dùng chung của dự án `/mnt/project-files/`: phác thảo, bản giao (`BAN-GIAO.md`), kế hoạch (`thiet-ke-man/`, `cai-thien/KE-HOACH.md`). Đây không phải repo; file nặng (render, .blend) để ở đó, không đưa vào git.
- Trang duyệt (artifact) đã duyệt là nguồn đúng cho hình dáng, màu, số đo. Khi code khác trang duyệt, sửa code hoặc hỏi Sang, không tự đổi thiết kế.
