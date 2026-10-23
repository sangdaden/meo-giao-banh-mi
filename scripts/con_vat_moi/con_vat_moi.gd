class_name ConVatMoi
extends Node3D
## Con vật mới V1–V6 ngoài phố (luồng 5 "Con vật mới vào game", kế hoạch tuong-tac-con-vat/KE-HOACH.md).
## Model Sang duyệt 23/10/2026 (trang https://claude.ai/artifact/HhyiCtnuF7vQRNnWeePBxv), nạp qua MoHinhConVat.
## Mọi con là thưởng: không tính vào đơn, không mất sao, không thua. Gọi Q (ConVat, nhóm "con_vat") thì đáp lại
## và ConVat.meet(id) lần đầu.
## Node nạp cho mọi ngày qua khóa "nodes" của scripts/ngay/thu_ba.gd; ngày không có trong LICH thì tự gỡ.
## Không có begin()/resume_day(): hai hàm đó dành cho node chính của ngày.
## Hai con ngoài cảnh phố: thạch sùng ở tường chung cư (scripts/con_vat_moi/thach_sung.gd, chung_cu.gd gắn),
## chuột Tí trong bếp Cô Ba (scripts/con_vat_moi/chuot_ti.gd, kitchen.gd gắn).

## Con vật từng ngày. Mỗi ngày chỉ 1–2 chỗ (ngân sách tam giác ngã tư).
const LICH := {
	"thu_hai": ["be_ca"],
	"thu_ba": ["ga", "thau_ca"],
	"thu_tu": ["vit", "be_ca"],
	"thu_sau": ["be_ca"],
	"thu_bay": ["buom", "be_ca"],
}
const SCRIPTS := {
	"ga": preload("res://scripts/con_vat_moi/ga_cho.gd"),
	"thau_ca": preload("res://scripts/con_vat_moi/thau_ca.gd"),
	"be_ca": preload("res://scripts/con_vat_moi/be_ca.gd"),
	"vit": preload("res://scripts/con_vat_moi/dan_vit.gd"),
	"buom": preload("res://scripts/con_vat_moi/buom_bay.gd"),
}

var main: Node
var player: CharacterBody3D
var hud: Node
var day_id := ""
## khóa LICH -> node con vật
var parts := {}


func _ready() -> void:
	name = "ConVatMoi"
	main = get_parent()
	var day: Dictionary = main.get("day") if main.get("day") is Dictionary else {}
	day_id = day.get("id", "")
	if not LICH.has(day_id):
		queue_free()
		return
	player = main.get("player")
	hud = main.get("hud")
	for k: String in LICH[day_id]:
		var n: Node3D = SCRIPTS[k].new()
		n.set("player", player)
		n.set("toast", _toast)
		add_child(n)
		parts[k] = n


func _toast(text: String, seconds := 2.6) -> void:
	if hud and hud.has_method("show_toast"):
		hud.show_toast(text, seconds)
