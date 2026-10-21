class_name GameState
## Dữ liệu dùng chung giữa các màn (biến static giữ nguyên khi đổi scene).
## Màn bếp ghi điểm vào đây, màn giao bánh đọc ra.

## true khi vừa chơi xong màn bếp: màn giao bánh bỏ qua màn hình bắt đầu.
static var from_kitchen := false
## Số giây cộng thêm vào đồng hồ mỗi đơn giao (0–6), tính từ điểm màn bếp.
static var kitchen_bonus := 0.0
## Số sao màn bếp (0–3), mỗi sao 2 giây.
static var kitchen_stars := 0
## Số đơn giao mỗi ngày (bằng số phần tử của kitchen_stars_per_bread).
const ORDERS_PER_DAY := 5
## Sao bếp của từng ổ (0–3), phần tử i là ổ dùng cho đơn thứ i. Màn bếp ghi, chấm điểm giao bánh đọc.
static var kitchen_stars_per_bread: Array[int] = [0, 0, 0, 0, 0]
