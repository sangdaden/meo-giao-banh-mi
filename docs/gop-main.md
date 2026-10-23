# Tự gộp main vào nhánh và thứ tự gộp PR

Nhiều luồng cùng sửa repo một lúc nên PR hay đụng nhau. Workflow
`.github/workflows/gop-main.yml` (script `tools/gop_main.sh`) giữ các nhánh PR luôn bám main.

## Workflow làm gì

| Khi nào | Làm gì |
|---|---|
| main vừa đổi (gộp PR) | Thử gộp main vào từng PR đang mở vào main. |
| … gộp sạch | Đẩy commit "Tự gộp main (sha) vào nhánh" lên nhánh PR, rồi gọi lại CI của PR (`desktop.yml`, `hieu-nang.yml`). |
| … đụng nhau | Gắn nhãn `dung-main`, ghi **một** bình luận trên PR liệt kê file đụng và lệnh sửa, đặt trạng thái đỏ **Gộp với main**. Lần sau chỉ sửa lại bình luận đó, không đăng chồng. |
| PR mở hoặc đẩy thêm | Kiểm riêng PR đó (check **Gộp được với main**), không đẩy gì. Hết đụng thì gỡ nhãn và bình luận đổi thành ✅. |
| Chạy tay | Tab Actions → **Tự gộp main vào PR** → Run workflow. Tick "Chỉ kiểm" nếu chỉ muốn xem PR nào đụng. |

Bảng tóm tắt từng lượt (PR nào sạch, PR nào đụng file nào) nằm ở trang tóm tắt của lượt chạy trong tab Actions.

Bỏ qua: PR từ fork, PR không nhắm vào main. PR có nhãn `khong-tu-gop` chỉ được kiểm và báo, không bị đẩy.

### Giới hạn của GITHUB_TOKEN

- Commit do `GITHUB_TOKEN` đẩy không tự kích hoạt CI, nên workflow gọi lại CI bằng `workflow_dispatch`.
  Các lượt đó vẫn hiện trên commit đầu nhánh của PR.
- `GITHUB_TOKEN` không được đẩy thay đổi file trong `.github/workflows/`. Khi main đổi file workflow,
  PR được gắn nhãn `gop-tay` và một bình luận chỉ lệnh gộp tay (chỉ cần `git merge origin/main` rồi đẩy,
  không phải sửa gì). Gộp xong thì nhãn tự gỡ.
- Muốn bỏ hai giới hạn trên: tạo token cá nhân (classic, quyền `repo` + `workflow`) và thêm vào
  Settings → Secrets and variables → Actions với tên `GOP_MAIN_TOKEN`. Không bắt buộc.

## Luồng làm việc (người và Claude)

- Nhánh PR có thể nhận commit gộp từ bot bất cứ lúc nào. **Trước khi sửa tiếp: `git pull`.**
  Nếu `git push` bị từ chối vì nhánh trên GitHub mới hơn: `git pull --no-rebase` rồi đẩy lại.
  Không `push --force` lên nhánh đã có commit gộp của bot (sẽ mất phần gộp).
- Thấy nhãn `dung-main` hoặc check đỏ **Gộp với main**: làm theo lệnh trong bình luận trên PR,
  giữ phần của cả hai bên, chạy lại test rồi đẩy.

## Thứ tự gộp PR

Sang gộp PR. Khi có nhiều PR cùng chờ, gộp theo thứ tự này để ít đụng nhất:

1. **PR sửa khung chung trước**: tách file (H1), `main.gd`, `hud.gd`, `days.gd`, `do_kho.gd`,
   `project.godot`, workflow CI. Các PR khác rẽ từ khung mới sẽ đỡ đụng.
2. **PR nhỏ và PR chỉ thêm file mới** (model, ảnh, script riêng một ngày).
3. **PR lớn sửa nhiều file dùng chung** (ánh sáng, phố, giao thông, người dân).
4. **PR đang đỏ** (`dung-main`, CI đỏ) để cuối, chờ luồng của nó sửa xong.

Cùng một nhóm thì PR mở trước gộp trước. Sau mỗi lần gộp, workflow tự cập nhật các PR còn lại,
nên chờ vài phút để check xanh lại rồi gộp PR kế tiếp.

## Chạy thử script ở máy

```bash
GITHUB_REPOSITORY=sangdaden/meo-giao-banh-mi THU=1 TU_GOP=0 bash tools/gop_main.sh
```

`THU=1` không đẩy và không ghi gì lên GitHub, chỉ in kết quả (cần `gh` đã đăng nhập để đọc danh sách PR).
