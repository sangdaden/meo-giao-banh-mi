class_name DoThem
## Đồ thay khối tạm cuối cùng (gói G1, trang https://claude.ai/artifact/9xN5SEq7m2wA2c8ABYK29s, Sang duyệt 23/10).
## Model ở assets/models/do_them/ (nguồn: /mnt/project-files/cai-thien/g1-khoi-tam/scripts/do_khoi.py), một mesh màu đỉnh,
## gốc giữa đáy, mặt trước nhìn +Z. Va chạm vẫn là hộp cũ (Blocks.collider) nên đường leo, chỗ đặt bánh không đổi.

const DIR := "../do_them/"


## Hộp va chạm đúng như khối cũ + model đặt ở đáy hộp. model: tên trong do_them/ hoặc đường dẫn "../x/y" như PhoModels.
## scale_y: kéo cao model cho khớp hộp (tủ báo Thử thách, ghế đẩu theo mặt ngồi).
static func solid(parent: Node, model: String, size: Vector3, pos: Vector3, rot_y := 0.0, scale := Vector3.ONE,
		layer := Blocks.LAYER_PROP) -> StaticBody3D:
	var body := Blocks.collider(parent, size, pos, layer)
	var mi := PhoModels.put(body, _path(model), Vector3(0, -size.y / 2.0, 0), rot_y, scale)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if size.y < 0.3 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return body


## Chỉ để nhìn (không va chạm), gốc model ở pos.
static func put(parent: Node, model: String, pos: Vector3, rot_y := 0.0, scale := Vector3.ONE) -> MeshInstance3D:
	return PhoModels.put(parent, _path(model), pos, rot_y, scale)


## Ghế nhựa thấp P4 (mặt 0,26 m) kéo cho mặt ghế cao h, có va chạm.
static func stool(parent: Node, pos: Vector3, h: float, rot_y := 0.0) -> StaticBody3D:
	return solid(parent, "../pho/chi_tiet/ghe_nhua_thap", Vector3(0.3, h, 0.3), pos + Vector3(0, h / 2.0, 0), rot_y, Vector3(1, h / 0.26, 1))


static func _path(model: String) -> String:
	return model if model.begins_with("../") or model.begins_with("res://") else DIR + model
