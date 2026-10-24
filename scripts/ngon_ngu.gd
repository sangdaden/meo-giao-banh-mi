extends Node
## Ngôn ngữ của game (autoload tên "NgonNgu", khai báo trong project.godot).
## Mặc định tiếng Việt; Cài đặt > Ngôn ngữ đổi sang English (lưu khóa "ngon_ngu" trong GameSettings).
## Thử nhanh: godot --path . -- --lang=en
## Bảng dịch: scripts/dich/ban_dich.gd và scripts/dich/en_*.gd.

const BanDich := preload("res://scripts/dich/ban_dich.gd")
const LANGS := [["Tiếng Việt", "vi"], ["English", "en"]]

signal doi_ngon_ngu(ma: String)

var ban_dich: BanDich
var ma := "vi"


func _ready() -> void:
	var chon := str(GameSettings.get_value("ngon_ngu"))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--lang="):
			chon = arg.trim_prefix("--lang=")
	dat(chon, false)
	if "--dich-thieu" in OS.get_cmdline_user_args() and ban_dich:
		ban_dich.ghi_thieu = true


## Đổi ngôn ngữ đang chạy. luu = true thì nhớ cho lần sau.
func dat(moi: String, luu := true) -> void:
	moi = "en" if moi == "en" else "vi"
	if luu:
		GameSettings.set_value("ngon_ngu", moi)
	if moi == "en":
		if ban_dich == null:
			ban_dich = BanDich.new()
		if TranslationServer.get_translation_object("en") != ban_dich:
			TranslationServer.add_translation(ban_dich)
	elif ban_dich:
		# Gỡ hẳn bảng: để nguyên thì TranslationServer vẫn dùng "en" làm ngôn ngữ dự phòng.
		TranslationServer.remove_translation(ban_dich)
	TranslationServer.set_locale(moi)
	var doi := moi != ma
	ma = moi
	if doi:
		doi_ngon_ngu.emit(ma)
		TrangWeb.bao_ngon_ngu(ma)


## Thử: godot --headless --path . -- --autotest --lang=en --dich-thieu → in các câu tiếng Việt chưa dịch lúc thoát.
func in_thieu() -> void:
	if ban_dich == null or not ban_dich.ghi_thieu:
		return
	for s in ban_dich.thieu:
		print("THIEU DICH: ", s.c_escape(), "  =>  ", str(ban_dich.thieu[s]).c_escape())
	print("THIEU DICH: %d câu" % ban_dich.thieu.size())


func _exit_tree() -> void:
	in_thieu()
	if ban_dich:
		TranslationServer.remove_translation(ban_dich)
