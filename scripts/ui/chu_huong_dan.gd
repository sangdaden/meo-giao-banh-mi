class_name ChuHuongDan
extends RefCounted
## Chữ hướng dẫn dùng chung: bảng "Cách chơi" trong menu Esc, dãy phím góc phải, chữ phụ của thẻ nhiệm vụ.
## Gom về một chỗ để chữ đúng theo từng ngày và để luồng bản tiếng Anh dịch một lần.
##
## Bảng "Cách chơi" của một ngày = phím di chuyển chung (PHIM_CHUNG) + dòng riêng của ngày (khóa "help" trong
## scripts/ngay/<ngày>.gd) + PHIM_CUU_KET. Ghi chú dưới bảng là khóa "help_note" của ngày (thiếu thì GHI_CHU_CHUNG) cộng dòng TAY_CAM.
## Ngày mới chỉ cần thêm "help" (vài dòng [phím, việc]) và "help_note" vào file ngày của mình, không sửa file này.

## Phím di chuyển, có ở mọi ngày ngoài phố. Mỗi dòng là [phím, việc].
const PHIM_CHUNG := [
	["W A S D", "chạy"],
	["Shift", "chạy nhanh"],
	["Space", "nhảy"],
	["C", "chui"],
	["Z", "rón rén"],
	["Chuột", "xoay camera · V đổi góc nhìn"],
	["B", "bản đồ lớn"],
]
## Phím Q gọi con vật (scripts/con_vat.gd), có ở mọi ngày; ngày tự khai dòng Q thì dùng dòng của ngày.
const PHIM_GOI := [["Q", "kêu meo · con vật gần đó đáp lại"]]
## Nút cứu kẹt (scripts/cuu_ket.gd), luôn ở cuối bảng.
const PHIM_CUU_KET := [["Giữ R", "về chỗ an toàn khi bị kẹt"]]
## Tùy chọn hỗ trợ "Tự đi theo mũi tên" (scripts/tu_di_pho.gd), chỉ hiện khi đã bật ở Cài đặt > Hỗ trợ.
const PHIM_TU_DI := [["Giữ F", "Bơ tự đi theo mũi tên"]]
## Dòng riêng mặc định khi ngày không khai "help": ngày giao bánh thường.
const PHIM_GIAO := [["E", "giao bánh"]]
const GHI_CHU_CHUNG := "Mũi tên đỏ trên đầu Bơ luôn chỉ về phía khách."
## Dòng tay cầm, luôn ở cuối ghi chú.
const TAY_CAM := "Tay cầm: cần trái chạy, A nhảy, giữ nút xuống để về chỗ an toàn, Start mở menu."

## Bảng và ghi chú chung cho màn không khai bảng riêng (HudTamDung.HELP_PHO, HELP_NOTE_PHO).
const BANG_GIAO := PHIM_CHUNG + PHIM_GIAO + PHIM_CUU_KET
const GHI_CHU_GIAO := GHI_CHU_CHUNG + "\n" + TAY_CAM

## Dãy phím nhỏ góc phải dưới lúc giao bánh (tắt bằng F1 hoặc Cài đặt > Gợi ý phím).
const DAY_PHIM := [
	[["W A S D", "chạy"], ["Shift", "nhanh"], ["Space", "nhảy"]],
	[["Giữ R", "về chỗ an toàn"], ["Esc", "menu"], ["F1", "ẩn gợi ý"]],
]

## Phím mở thẻ nhiệm vụ đầy đủ (thẻ góc trái chỉ hiện một dòng).
const PHIM_THE := "Tab"
## Thẻ nhiệm vụ tự mở đủ chừng này giây khi sang việc mới, rồi gọn lại một dòng.
const THE_MO_GIAY := 5.0


## Bảng "Cách chơi" của một ngày (day: kết quả Days.get_day).
static func bang(day: Dictionary) -> Array:
	var rieng: Array = day.get("help", [])
	if rieng.is_empty():
		rieng = PHIM_GIAO
	var goi: Array = [] if rieng.any(func(r): return r[0] == "Q") else PHIM_GOI
	var tu_di: Array = PHIM_TU_DI if DoKho.ho_tro("ho_tro_tu_di") else []
	return PHIM_CHUNG + rieng + goi + tu_di + PHIM_CUU_KET


## Ghi chú dưới bảng "Cách chơi" của một ngày, kèm dòng tay cầm.
static func ghi_chu(day: Dictionary) -> String:
	var note := str(day.get("help_note", ""))
	return (note if note != "" else GHI_CHU_CHUNG) + "\n" + TAY_CAM
