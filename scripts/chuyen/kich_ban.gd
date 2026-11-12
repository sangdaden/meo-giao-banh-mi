class_name KichBanTuan
extends RefCounted
## Kịch bản tuần "Bí mật cho Cô Ba" (R2 + L1 L2 L3 L5 + O1 O2 O3), Sang duyệt 24/10/2026:
## https://claude.ai/artifact/X4MBRy2JQzvUGsr72zvNkT (nguồn /mnt/project-files/cai-thien-2/kich-ban/kich_ban.py).
## Chỉ có dữ liệu; scripts/chuyen/chuyen.gd đọc và diễn. Bản tiếng Anh ở scripts/dich/en_chuyen.gd.
##
## Mỗi ngày: bao = [tít báo Chú Tư (O1), góc đếm ngược], buu = 2 dòng bưu thiếp cuối ngày (O2),
## buu_khac = dòng 2 khi không nhận thư (L3), ky = số chữ ký trên thiệp, nhip = các nhịp:
##   0..4      sau khi giao đơn đó (đơn lấy đồ mang về: lúc nhận đồ ở chỗ khách)
##   "cuoi"    sau đơn cuối ngày (Thứ Sáu: chuyến giỗ cuối, cả bản Thử thách nhiều chuyến hơn)
##   "sang"    đầu ngày, sau thẻ mở đầu · "ve_bep" về từ bếp ráp nhanh · "phim" sau "cuoi" (O5 tạm bằng phụ đề)
##   "viec_co_ba", "ky_viec", "muc": Thứ Bảy · "bat_ngo": buổi bất ngờ Chủ Nhật (scripts/chuyen/bat_ngo.gd)
## Một câu: k = loại (giao = câu cảm ơn khi giao, O3; bimat, thu, tranh, l1, l5, coba, toast = chữ kể, phim),
##   ai = người nói ("" là chữ kể), c = câu, co_san = câu có sẵn của khoảnh khắc giao (không đổi),
##   anh = tranh Bé Na hiện kèm (assets/chuyen/<anh>.jpg),
##   dk = điều kiện: "co:N" thư N đang trong túi, "da:N" thư N đã tới, "lan" có Chị Lan,
##   viec = việc khi câu hiện: "hoi:N" hỏi nhận thư N (E, tùy chọn), "toi:N" thư N tới tay (+2.000đ lần đầu).

const NGAY := {
	"thu_hai": {
		"bao": ["LÒ BÁNH CÔ BA CÓ PHỤ VIỆC MỚI?", "Còn 6 ngày ★"],
		"buu": ["Ngày đầu ở phố mới. Ai cũng cho Bơ ăn, ai cũng thì thầm.", "Trong túi Bơ có một bí mật. Bơ giữ kỹ lắm."],
		"ky": "3 chữ ký",
		"nhip": {
			0: [
				{"k": "giao", "ai": "Chú Tư", "c": "Mèo giao bánh hả? Mai tui đăng hình lên báo luôn."},
			],
			1: [
				{"k": "giao", "ai": "Bé Na", "c": "Mèo ơi cảm ơn! Con vẽ tặng mèo nè."},
				{"k": "tranh", "ai": "", "c": "Trong rổ có tờ giấy vẽ nguệch ngoạc: một con mèo cam đang chạy, chữ \"cảm ơn mèo\".", "anh": "tranh_1"},
			],
			2: [
				{"k": "giao", "ai": "Chị Mây", "c": "Cụng ly nè, nhân viên giỏi nhất phố!", "co_san": true},
				{"k": "bimat", "ai": "Chị Mây", "c": "Suỵt, Bơ. Chủ Nhật này lò bánh Cô Ba tròn 30 năm."},
				{"k": "bimat", "ai": "Chị Mây", "c": "Cả xóm tính làm bất ngờ. Cô Ba mà nghi là hỏng hết đó!"},
				{"k": "bimat", "ai": "Chị Mây", "c": "Con mèo thì ai mà nghi. Chuyền cái thiệp này cho mọi người ký nha."},
				{"k": "toast", "ai": "", "c": "Túi bánh có thêm: Thiệp mừng 30 năm (bí mật!). Giao bánh là thiệp tự chuyền, không cần làm gì thêm."},
			],
			3: [
				{"k": "giao", "ai": "Anh Hùng", "c": "Đập tay cái coi! Ngon lành!", "co_san": true},
				{"k": "bimat", "ai": "Anh Hùng", "c": "Ký rồi nè. Đèn với sân khấu buổi mừng để anh lo!"},
			],
			4: [
				{"k": "giao", "ai": "Bà Sáu", "c": "Con mèo ngoan của bà.", "co_san": true},
				{"k": "l1", "ai": "Bà Sáu", "c": "Ba chục năm rồi đó. Hồi lò mới mở, ông nhà bà đóng cái tủ kính đầu tiên cho Cô Ba."},
				{"k": "l1", "ai": "Bà Sáu", "c": "Thằng Mực gầm gừ vậy chứ hổng ác đâu. Nó vậy từ hồi ông nhà đi."},
				{"k": "toast", "ai": "", "c": "Bà Sáu ký vào thiệp, chữ run run mà đẹp."},
			],
		},
	},
	"thu_ba": {
		"bao": ["CHỢ SÁNG ĐÔNG KỶ LỤC", "Còn 5 ngày ★"],
		"buu": ["Chợ đông như kiến. Ôm túi trứng mà tim Bơ đập thình thịch.", "Túi Bơ giờ có thiệp, lồng đèn, và một lá thư run run."],
		"buu_khac": "Túi Bơ giờ có thiệp, lồng đèn, và câu đối của hai ông.",
		"ky": "7 chữ ký",
		"nhip": {
			"sang": [
				{"k": "coba", "ai": "Cô Ba", "c": "Hôm qua cô thấy Chị Mây với Anh Hùng to nhỏ gì ngoài sạp báo. Chắc chuyện người lớn ha."},
			],
			0: [
				{"k": "giao", "ai": "Chú Năm", "c": "Báo cáo: nhận đủ bánh!", "co_san": true},
				{"k": "l5", "ai": "Chú Năm", "c": "Chủ Nhật con gái chú ở Đà Lạt về đó Bơ! Hai năm rồi nó chưa về."},
				{"k": "toast", "ai": "", "c": "Chú Năm ký to đùng, vẽ thêm cái xe ôm bên cạnh."},
			],
			"ve_bep": [
				{"k": "coba", "ai": "Cô Ba", "c": "Ủa, túi trứng gì mà nặng vậy ta?"},
			],
			1: [
				{"k": "bimat", "ai": "Cô Hai", "c": "Cô giấu cuộn dây lồng đèn giấy dưới túi trứng rồi. Đi nhẹ thôi nghen!"},
			],
			2: [
				{"k": "giao", "ai": "Ông Bảy", "c": "Ổ bánh này… nước đi hay.", "co_san": true},
				{"k": "bimat", "ai": "Ông Bảy", "c": "Tụi tui viết câu đối mừng Cô Ba. Tui viết vế trên."},
				{"k": "bimat", "ai": "Ông Tám", "c": "Vế dưới của tui mới hay. Ký tên tui trước!"},
				{"k": "toast", "ai": "", "c": "Hai ông giành nhau ký, rốt cuộc ký chung một chữ."},
			],
			3: [
				{"k": "giao", "ai": "Bé Na", "c": "Bánh còn nóng nè! Cảm ơn Bơ!", "co_san": true},
				{"k": "tranh", "ai": "", "c": "Tranh thứ hai: Bơ ôm túi trứng, trứng to hơn đầu Bơ.", "anh": "tranh_2"},
				{"k": "tranh", "ai": "Bé Na", "c": "Con đang vẽ một bức thiệt bự tặng Cô Ba. Bí mật nha mèo!"},
			],
			4: [
				{"k": "giao", "ai": "Anh Hùng", "c": "Đập tay cái coi! Ngon lành!", "co_san": true},
				{"k": "thu", "ai": "Anh Hùng", "c": "Bơ… đưa giùm anh lá thư này cho Chị Mây được hông? Đừng nói ai nha.", "viec": "hoi:1"},
				{"k": "toast", "ai": "", "c": "Lá thư nằm trong túi bánh. Mai giao cho Chị Mây là thư tới.", "dk": "co:1"},
			],
		},
	},
	"thu_tu": {
		"bao": ["MƯA LỚN CHIỀU NAY, ĐƯỜNG NGẬP", "Còn 4 ngày ★"],
		"buu": ["Mưa ướt sũng mà bánh vẫn khô. Cô Hai lau lông cho Bơ.", "Mực ngồi dưới mái hiên nhìn ra cổng, như đang chờ ai."],
		"ky": "8 chữ ký",
		"nhip": {
			"sang": [
				{"k": "coba", "ai": "Cô Ba", "c": "Mưa vầy mà ai cũng hẹn gặp con. Con mèo này nổi tiếng quá ta!"},
			],
			0: [
				{"k": "giao", "ai": "Chị Mây", "c": "Mưa vầy mà vẫn tới! Lau chân cái đã."},
				{"k": "bimat", "ai": "Chị Mây", "c": "Lồng đèn với câu đối chị cất lên gác xép. Đó là kho bí mật của xóm mình."},
				{"k": "bimat", "ai": "Chị Mây", "c": "Chị đang tập làm bánh bông lan hình ổ bánh mì. Lần thứ ba rồi mà còn méo."},
				{"k": "thu", "ai": "Chị Mây", "c": "Thư… của Anh Hùng hả?", "dk": "co:1"},
				{"k": "thu", "ai": "Chị Mây", "c": "Ờ… chị gửi lại cái này. Đừng đọc lén nha Bơ.", "dk": "co:1", "viec": "toi:1"},
			],
			1: [
				{"k": "giao", "ai": "Cô Hai", "c": "Ướt hết rồi kìa, vô đây cô lau cho."},
			],
			2: [
				{"k": "giao", "ai": "Bé Na", "c": "Mèo hổng sợ mưa hả? Giỏi ghê!"},
				{"k": "tranh", "ai": "", "c": "Tranh thứ ba: Bơ trên sân thượng, mưa là cả trăm gạch xanh.", "anh": "tranh_3"},
			],
			3: [
				{"k": "giao", "ai": "Chú Năm", "c": "Báo cáo: nhận đủ bánh!", "co_san": true},
				{"k": "l5", "ai": "Chú Năm", "c": "Con gái chú gọi nè: Chủ Nhật xe đò về tới chiều. Nó còn đem hoa Đà Lạt về góp nữa!"},
			],
			4: [
				{"k": "giao", "ai": "Chú Tư", "c": "Ừm. Đúng giờ. Được lắm.", "co_san": true},
				{"k": "bimat", "ai": "Chú Tư", "c": "Tui đang in một số báo đặc biệt cho Chủ Nhật. Chưa ai được coi, kể cả Bơ."},
				{"k": "toast", "ai": "", "c": "Chú Tư ký bằng bút máy, nắn nót như viết tít báo."},
			],
		},
	},
	"thu_nam": {
		"bao": ["TRƯA NÓNG NHẤT TUẦN", "Còn 3 ngày ★"],
		"buu": ["Leo năm tầng giữa trưa. Bơ thở như cái ống bễ.", "Bé Na vẽ cả phố vô một tờ giấy. Có Bơ ở giữa."],
		"ky": "8 chữ ký",
		"nhip": {
			"sang": [
				{"k": "coba", "ai": "Cô Ba", "c": "Hôm qua cô thấy trong túi con có gì đỏ đỏ. Chắc giấy gói bánh ha?"},
			],
			0: [
				{"k": "giao", "ai": "Chú Tư", "c": "Lên tận nóc tủ! Mèo nhà Cô Ba giỏi thiệt."},
			],
			1: [
				{"k": "giao", "ai": "Anh Hùng", "c": "Đập tay cái coi! Ngon lành!", "co_san": true},
				{"k": "bimat", "ai": "Anh Hùng", "c": "Đèn buổi mừng anh đấu xong rồi. Sáu chục bóng!"},
				{"k": "toast", "ai": "", "c": "Anh Hùng đọc thư xong đỏ tới mang tai.", "dk": "co:2", "viec": "toi:2"},
				{"k": "thu", "ai": "Anh Hùng", "c": "Lần này anh hỏi thẳng luôn: Chủ Nhật ngồi xem hội với anh hông. Đưa giùm nha Bơ.", "viec": "hoi:3"},
			],
			2: [
				{"k": "giao", "ai": "Cô Hai", "c": "Đá còn nguyên cục, giỏi!"},
			],
			3: [
				{"k": "giao", "ai": "Chị Mây", "c": "Lên tới gác luôn! Ngồi nghỉ chút đi Bơ."},
				{"k": "bimat", "ai": "Chị Mây", "c": "Gác xép giờ chật cứng đồ bí mật rồi nè."},
				{"k": "thu", "ai": "Chị Mây", "c": "…Ừ. Nói với ảnh là ừ.", "dk": "co:3", "viec": "toi:3"},
				{"k": "toast", "ai": "", "c": "Chị Mây cười hoài không thôi.", "dk": "da:3"},
			],
			4: [
				{"k": "giao", "ai": "Bé Na", "c": "Con bị cảm nên mẹ hổng cho xuống. Mèo leo lên tận đây hả!"},
				{"k": "tranh", "ai": "Bé Na", "c": "Tranh lớn xong rồi! \"Bơ và cả phố\". Mèo đem tới Hội mèo giùm con nha.", "anh": "tranh_lon"},
				{"k": "toast", "ai": "", "c": "Bé Na cuộn tranh, cột dây thun, nhét vô túi bánh."},
			],
		},
	},
	"thu_sau": {
		"bao": ["CHIỀU NAY GIỖ ÔNG SÁU, HẺM 42", "Còn 2 ngày ★"],
		"buu": ["Đám giỗ ấm cúng. Có bánh mì thì không ai buồn lâu.", "Bà Sáu gửi Bơ một tấm bảng đồng. Nặng, mà đi đâu Bơ cũng mang."],
		"ky": "12 chữ ký",
		"nhip": {
			"sang": [
				{"k": "coba", "ai": "Cô Ba", "c": "Mấy bữa nay ai cũng hỏi cô Chủ Nhật rảnh hông. Lạ ghê!"},
			],
			0: [
				{"k": "giao", "ai": "Chị Mây", "c": "Nghe tiếng meo là biết Bơ tới!"},
				{"k": "thu", "ai": "Chị Mây", "c": "Lát chị qua phụ Bà Sáu dọn cỗ. Anh Hùng… cũng qua."},
			],
			1: [
				{"k": "giao", "ai": "Anh Hùng", "c": "Xong ca này anh qua bưng mâm giùm Bà Sáu."},
			],
			2: [
				{"k": "giao", "ai": "Cô Hai", "c": "Nhang đèn đủ rồi, cầm đi cẩn thận nha con."},
			],
			3: [
				{"k": "giao", "ai": "Bà Sáu", "c": "Bánh thơm quá. Ông nhà bà ưa chả cá nhất đó."},
			],
			"cuoi": [
				{"k": "thu", "ai": "Chị Mây", "c": "Anh Hùng, bưng giùm em mâm này."},
				{"k": "thu", "ai": "Anh Hùng", "c": "Dạ… ờ, để anh!"},
				{"k": "toast", "ai": "", "c": "Khách đám giỗ chuyền tay nhau ký thiệp."},
			],
			"phim": [
				{"k": "phim", "ai": "Bà Sáu", "c": "Bơ lại đây bà đưa cái này."},
				{"k": "phim", "ai": "Bà Sáu", "c": "Hồi lò mới mở, ông nhà bà khắc tấm bảng này tặng Cô Ba. Chưa kịp đưa thì ổng đi."},
				{"k": "phim", "ai": "Bà Sáu", "c": "Chủ Nhật Bơ đưa giùm ổng nha."},
				{"k": "l1", "ai": "Bà Sáu", "c": "Thẻ tên thằng Mực cũng tay ổng khắc. Mà mấy bữa nay nó làm rớt đâu mất rồi…"},
				{"k": "toast", "ai": "", "c": "Túi bánh có thêm: bảng đồng \"Lò bánh Cô Ba\"."},
			],
		},
	},
	"thu_bay": {
		"bao": ["THỨ BẢY NẮNG ĐẸP, PHỐ VUI", "Còn 1 ngày ★"],
		"buu": ["Mực đi theo Bơ suốt buổi chiều. Bạn mới to gấp rưỡi Bơ.", "Thiệp đủ chữ ký rồi. Mai là ngày đó!"],
		"ky": "đủ + dấu chân Mực",
		"nhip": {
			"viec_co_ba": [
				{"k": "coba", "ai": "Cô Ba", "c": "Ủa, cái gì trong túi con kêu sột soạt vậy?"},
				{"k": "coba", "ai": "Cô Ba", "c": "Thôi, chuyện của mèo, cô hổng hỏi."},
			],
			"ky_viec": [
				{"k": "toast", "ai": "", "c": "%s ký vào thiệp."},
			],
			"muc": [
				{"k": "l1", "ai": "Bà Sáu", "c": "Ông nhà bà khắc cái thẻ này hồi Mực mới về, còn nhỏ xíu."},
				{"k": "l1", "ai": "Bà Sáu", "c": "Từ hồi ổng đi, nó cứ nằm canh hẻm. Chắc chờ ổng về."},
				{"k": "l1", "ai": "Bà Sáu", "c": "Giờ có Bơ rồi. Đi chơi với bạn đi con."},
				{"k": "toast", "ai": "", "c": "Mực đóng một dấu chân lên thiệp. Đủ rồi!"},
			],
		},
	},
	"chu_nhat": {
		"bao": ["TỐI NAY HỘI MÈO KHU PHỐ", "Hôm nay ★"],
		"buu": ["Cô Ba vừa khóc vừa cười. Bơ đâu biết người ta làm được hai việc đó cùng lúc.", "Tuần đầu ở phố mới. Chắc Bơ ở lại đây luôn."],
		"ky": "bảng \"Tuần của Bơ\"",
		"nhip": {
			"sang": [
				{"k": "coba", "ai": "Cô Ba", "c": "Bà Mướp mời cô tối nay ra xem hội. Lạ ghê, mọi năm có mời đâu!"},
			],
			0: [
				{"k": "giao", "ai": "Bà Mướp", "c": "Meo meo. (Đồ trang trí giấu sau sân khấu hết rồi, yên tâm.)"},
			],
			"bat_ngo": [
				{"k": "phim", "ai": "Chú Tư", "c": "Bà con ơi, tới giờ rồi!"},
				{"k": "phim", "ai": "Cả xóm", "c": "Mừng lò bánh Cô Ba 30 năm!"},
				{"k": "phim", "ai": "Cô Ba", "c": "Trời đất ơi… cả xóm giấu cô hả?"},
				{"k": "bimat", "ai": "Chị Mây", "c": "Bơ chuyền thiệp cả tuần đó cô."},
				{"k": "l1", "ai": "Bà Sáu", "c": "Của ông nhà bà gửi đó. Trễ ba chục năm mà còn sáng."},
				{"k": "phim", "ai": "Cô Ba", "c": "Ba chục năm làm bánh, chưa bữa nào thơm như bữa nay."},
				{"k": "l5", "ai": "Chú Năm", "c": "Con gái chú nè! Lan ơi, đây là Bơ đó.", "dk": "lan"},
				{"k": "l5", "ai": "Chị Lan", "c": "Con đem hoa Đà Lạt về mừng cô Ba nè.", "dk": "lan"},
				{"k": "tranh", "ai": "Bé Na", "c": "Cô Ba coi nè, mèo ở giữa đó!"},
				{"k": "bimat", "ai": "Chú Tư", "c": "Số đặc biệt, tặng cô!"},
				{"k": "toast", "ai": "", "c": "LÒ BÁNH CÔ BA 30 NĂM: CẢ XÓM CẢM ƠN!"},
				{"k": "thu", "ai": "", "c": "Anh Hùng và Chị Mây ngồi cạnh nhau, chia nhau miếng bánh bông lan hình ổ bánh mì."},
				{"k": "l1", "ai": "", "c": "Mực nằm dưới chân Bà Sáu, đuôi đập đập xuống đất."},
			],
		},
	},
}
