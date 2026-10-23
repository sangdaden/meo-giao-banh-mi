# Đưa bản chơi thử lên itch.io

Workflow `.github/workflows/itch.yml` đẩy ba bản lên trang itch.io bằng **butler** (công cụ chính thức của itch):

| Kênh itch | Lấy từ đâu |
|---|---|
| `web` | xuất lại bản web ngay trong workflow (giống `pages.yml`) |
| `windows` | `MeoGiaoBanhMi-windows.zip` ở GitHub Releases (`desktop.yml` đã build và chạy thử) |
| `mac` | `MeoGiaoBanhMi-macos.zip` ở GitHub Releases |

Workflow **không tự chạy khi main đổi**. Chỉ chạy khi:

- bấm **Run workflow** trong tab Actions, hoặc
- đẩy tag `v*` **và** biến repo `ITCH_TU_DONG` = `co` (mặc định không đặt, nên tag không đẩy gì lên itch).

Đẩy file lên itch không đổi chế độ hiển thị của trang. Trang để **Draft** hay **Restricted** thì người ngoài vẫn chưa thấy.

## 1. Tạo trang game trên itch (một lần)

1. Đăng nhập itch.io, bấm mũi tên cạnh tên tài khoản → **Upload new project**.
2. Điền theo `/mnt/project-files/itch/NOI-DUNG-TRANG.md` (tên, mô tả, ảnh bìa, tag, chế độ nhúng web 1280 × 720).
3. **Kind of project: HTML**. Không cần tải file gì lên tay. **Visibility: Draft**. Bấm **Save**.
4. Nhìn địa chỉ trang: `https://<tên-tài-khoản>.itch.io/<đường-dẫn-game>`. Ghi lại hai phần `<tên-tài-khoản>` và `<đường-dẫn-game>`.

## 2. Lấy khóa API cho butler (một lần)

1. Trên itch.io: **Settings** (menu tài khoản) → **API keys** (https://itch.io/user/settings/api-keys).
2. Bấm **Generate new API key**. Khóa hiện ra là một chuỗi dài, bấm **View** để xem và chép.
3. Khóa này cho phép đẩy file lên mọi game của tài khoản: không gửi qua chat, email hay commit vào repo. Lỡ lộ thì quay lại trang này bấm **Revoke** rồi tạo khóa mới.

## 3. Thêm khóa và tên trang vào GitHub (một lần)

Trong repo trên GitHub: **Settings → Secrets and variables → Actions**.

1. Tab **Secrets** → **New repository secret**
   - Name: `BUTLER_API_KEY`
   - Secret: dán khóa ở bước 2 → **Add secret**.
2. Tab **Variables** → **New repository variable**
   - Name: `ITCH_GAME`
   - Value: `<tên-tài-khoản>/<đường-dẫn-game>`, ví dụ `sangdaden/meo-giao-banh-mi` → **Add variable**.

Thiếu một trong hai thì workflow vẫn chạy được nhưng chỉ xuất bản web để thử rồi dừng, có cảnh báo vàng, không đẩy gì.

## 4. Đẩy một bản lên itch

1. Tab **Actions** → **Đẩy lên itch.io** → **Run workflow**.
2. `ban`: để `ban-moi-nhat` (bản mới nhất của main) hoặc gõ một tag như `v0.2.0`.
3. `kenh`: `tat-ca`, hoặc chỉ `web` / `windows` / `mac`.
4. Chạy xong (khoảng 5–10 phút), mở trang itch → **Edit game**. Lần đầu: ở file kênh `web`, tick **This file will be played in the browser**, bấm Save. Những lần sau itch tự giữ.

Số phiên bản hiện trên itch: tên tag, hoặc `năm.tháng.ngày-mãcommit` khi lấy `ban-moi-nhat`.

## Ghi chú

- Bản web không bật luồng (`variant/thread_support=false`), nên **không cần** tick "SharedArrayBuffer support" trên itch.
- Giới hạn của itch cho game HTML: tối đa 1000 file, mỗi file ≤ 200 MB. Workflow kiểm tra trước khi đẩy; `index.pck` hiện ≤ 60 MB theo ngân sách web.
- `web/update-check.js` vẫn chạy trên itch: khi có bản web mới đẩy lên, trang đang mở tự nhắc tải lại.
- butler chỉ gửi phần khác so với lần trước (vá), nên những lần đẩy sau nhanh hơn và người đã tải bản Windows/Mac qua app itch được cập nhật nhỏ.
