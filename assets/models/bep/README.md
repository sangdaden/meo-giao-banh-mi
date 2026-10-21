# Đồ bếp phong cách D, bản vào game (Sang duyệt 21/10/2026)
59 file .glb, mỗi món hoặc trạng thái một file. Danh sách, số tam giác và kích thước (m, x·y·z Blender) ở manifest.json; ảnh tổng preview.png.

Quy ước chung
- Kích thước thật, đơn vị mét. Trục glTF: Y lên, mặt trước của món nhìn về +Z (ví dụ cửa lò, chữ trên xe bánh mì).
- Gốc toạ độ ở giữa đáy, nên đặt thẳng lên mặt sàn hoặc mặt bàn.
- Một mesh, một vật liệu `D_mausac`, màu nằm trong màu đỉnh COLOR_0 (thuộc tính 'Col', theo điểm). Không có texture.
  Trên renderer Compatibility (web), màu đỉnh cần đổi linear → sRGB như cách player.gd làm cho Bơ.
- 180–1500 tam giác mỗi món (lo_gach, xe_banh_mi 1500; còn lại ≤ 1000).

Trạng thái
- Bánh: banh_song, banh_vang, banh_chay, banh_bo (bổ đôi có nhân, nắp mở).
- Bột: bot_dong (đống bột), bot_khoi_nhao, bot_u_to (tô ủ có khăn), bot_phoi.
- Lò: lo_gach (thân, miệng tối), lo_cua (cửa sắt; gốc ở mép dưới = bản lề, xoay quanh trục X để mở xuống), lo_khay (khay kéo), lo_lua (lửa, nên gán vật liệu phát sáng trong Godot), lo_cui.
- Rau: dua_leo, dua_leo_lat (4 lát), ngo_bo, do_chua_chen. Chả: cha_cay (gói lá), cha_boc, cha_khoanh. Thịt: thit_nguoi, thit_lat, pate_hop.
- Nguyên liệu thêm: ca_rot, cu_cai, hanh_la, ot, ot_lat, trung, trung_vo, to_bo_trung.
- Trạm và đồ lớn: ban_nhao, cay_can, thot, dao, ro_tre, khay_inox, bao_bot, xe_banh_mi, ban_rap, thung_rac, gach_bong (1 viên 40 cm để lát), den_treo, bon_rua, thau, ban_bao, hu_do_chua, to_phoi.
- Cảnh cận: ca_nuoc, hu_men, binh_xit, dao_lam, khan_u, gang_lo, chai_xi_dau, trai_ot, giay_goi, tay_tran, tay_gang (tay chưa có rig).

Giới hạn bản này
- Kính (xe bánh mì, ca nước, hũ đồ chua) đang đục; gán vật liệu trong suốt trong Godot nếu cần.
- Gạch lò, vân gỗ, đan tre là màu trơn (bản phác dùng texture thủ tục không xuất được); sẽ bổ sung atlas 1024 sau.
- Dựng lại: `python props.py <thẻ,...> <thư_mục> --export` (pk.py + props.py ở thư mục cha).
