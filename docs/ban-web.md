# Bản web: link ổn định, link mới nhất và dải "Có bản mới"

## Hai link (PH2)

| Link | Là bản nào | Đổi khi nào |
|---|---|---|
| **https://sangdaden.github.io/meo-giao-banh-mi/** | **Ổn định**, gửi cho người chơi thử | Chỉ khi Sang bấm nút (dưới đây) hoặc gắn tag `v*` |
| **https://sangdaden.github.io/meo-giao-banh-mi/moi-nhat/** | **Mới nhất** của nhánh `main`, có thể còn lỗi | Tự đổi mỗi lần `main` đổi (vài phút sau khi gộp PR) |

Hai bản **lưu game riêng**: chơi ở `/moi-nhat/` không đụng tiến độ ở link gốc (bản mới nhất có thể đổi file lưu mà bản ổn định chưa đọc được).

Chưa bấm nút lần nào thì link gốc vẫn là bản `main` như trước.

### Đưa bản mới nhất lên link ổn định

1. Mở tab **Actions** của repo → workflow **Bản web (GitHub Pages)** → **Run workflow**.
2. Tích ô **Đưa main hiện tại lên link ổn định**, bấm **Run workflow**.
3. Khoảng 10–15 phút sau, link gốc là bản `main` lúc bấm. Workflow gắn tag `on-dinh-<ngày-giờ>` vào đúng commit đó và cất bản web vào release **web-on-dinh** (`web-on-dinh.zip` là bản đang chạy, mỗi `web-<tag>.zip` là một bản cũ).

Gắn tag `v*` (bản phát hành) cũng đưa đúng commit của tag lên link ổn định.

### Trả link ổn định về bản cũ

Run workflow như trên nhưng không tích ô, mà gõ tên tag cũ (ví dụ `on-dinh-2026-10-25-0900`) vào ô **tra_lai**. Danh sách tag cũ: các file `web-<tag>.zip` trong release **web-on-dinh**.

## Dải "Có bản mới" (PH1)

`web/update-check.js` (chèn vào trang qua `export_presets.cfg` → `html/head_include`) hỏi `version.json` mỗi phút và mỗi khi quay lại tab. Thấy bản mới thì:

- **chỉ báo lúc an toàn**: ở màn hình chính hoặc bảng kết quả (hết ca, hết ngày dạo phố, kết tuần). Đang trong một ngày thì im lặng chờ;
- **không tự tải lại** và **không tải trước** file mới (index.pck ~30 MB) lúc đang chơi; chỉ tải khi người chơi bấm **Tải bản mới**;
- chữ theo ngôn ngữ đang chọn trong game (Tiếng Việt / English).

Game báo chỗ đang đứng cho trang bằng `scripts/trang_web.gd` (`TrangWeb.bao("menu" | "ket_ngay", node)`, ghi `window.meoGame`); node rời cây thì tự về `"choi"`. Màn mới cần báo "an toàn" thì gọi `TrangWeb.bao("ket_ngay", self)` lúc hiện bảng.

## Phím trên bản web (TC1)

Bản web không gán Ctrl (chui) và Alt (rón rén) vì Ctrl+W đóng tab, Alt mở menu trình duyệt: chui là **C**, rón rén là **Z**. Bản PC giữ cả Ctrl/Alt lẫn C/Z (`Main._setup_input`). Chữ nhắc phím trong game chỉ ghi C và Z.

## Người gác: không để đứng màn đen

Cũng trong `web/update-check.js`. Khi trình duyệt tắt phần đồ họa của game (WebGL context lost), khi game lỗi (wasm abort), hoặc khi game ngừng gửi nhịp quá 25 giây lúc tab đang mở, trang hiện bảng có nút **Tải lại trang** và một dòng mã lỗi (lý do, cảnh, thời gian chơi, màn hình, card đồ họa, trình duyệt) để người chơi chụp gửi lại. Mã lỗi cuối cùng cũng được giữ trong `localStorage` khóa `meo-loi-cuoi`.

Game gửi nhịp mỗi giây bằng `TrangWeb.bat_nhip()` (gọi ở trang chủ). Treo cứng cả trang (vòng lặp vô hạn) thì trang cũng không chạy được nên không hiện bảng; lúc đó trình duyệt tự hỏi "Trang không phản hồi".
