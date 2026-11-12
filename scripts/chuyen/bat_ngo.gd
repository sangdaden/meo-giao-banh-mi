class_name BatNgo
extends RefCounted
## Buổi bất ngờ mừng lò bánh Cô Ba 30 năm (chuyện tuần R2), tối Chủ Nhật ở sân Hội mèo:
## sau khi Bà Mướp trao huy chương, trước bảng tổng kết và phim kết tuần (scripts/chu_nhat.gd gọi BatNgo.chay).
## Bản này kể bằng phụ đề (scripts/chuyen/chuyen.gd, nhịp "bat_ngo") với người dân có sẵn: Cô Ba quay ra sân khấu,
## Anh Hùng và Chị Mây đứng cạnh nhau ở hàng ghế. Đồ trang trí buổi mừng, Chị Lan và phim ngắn O5 (đã duyệt
## 24/10, https://claude.ai/artifact/2oxRYWdjepyueHYDRLdDwG) vào sau. Bấm E, Enter hay Space để qua nhanh từng câu.

## Hùng và Mây đứng cạnh nhau sau băng ghế khán giả (scripts/chu_nhat.gd AUDIENCE)
const CAP_DOI := [["hung", Vector3(-32.85, 0, 16.95), 0.15], ["may", Vector3(-32.3, 0, 16.95), -0.15]]


static func chay(cn: Node, xong: Callable) -> void:
	var tree := cn.get_tree()
	var c: Node = tree.get_first_node_in_group(Chuyen.GROUP)
	if c == null or not c.has_method("dien_nhip"):
		xong.call()
		return
	for a in CAP_DOI:
		var n: Nguoi = null
		for o: Node in tree.get_nodes_in_group(Nguoi.GROUP):
			if o.get("id") == a[0]:
				n = o
		if n == null:
			n = Nguoi.make(a[0], "vui")
			cn.add_child(n)
		n.set_physics_process(false)
		n.global_position = a[1]
		n.rotation.y = a[2]
		n.play("vui")
	for o: Node in tree.get_nodes_in_group(Nguoi.GROUP):
		if o.get("id") in ["coba", "bena", "chutu", "chunam", "basau"] and o.has_method("play_for"):
			o.play_for("vui", 12.0)
	c.dien_nhip("bat_ngo", xong)
