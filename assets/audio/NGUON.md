# Nguồn và giấy phép âm thanh

Mọi file trong thư mục này do `tools/sound/synth.py` tự tổng hợp bằng toán (numpy, scipy), **không lấy mẫu, không ghi âm, không tải từ thư viện nào**. Vì vậy chúng thuộc về dự án và được phát hành theo **CC0 1.0** (tự do dùng, sửa, bán, không cần ghi công). Code tạo ra chúng theo giấy phép MIT của repo.

Muốn sửa một tiếng: chỉnh hàm tương ứng trong `synth.py` rồi chạy `python3 tools/sound/synth.py ten_file`. Mỗi file có hạt ngẫu nhiên riêng nên làm lại bao nhiêu lần cũng ra y hệt.

Khi thêm tiếng lấy từ nơi khác, ghi thêm một dòng vào bảng cuối trang: tên file, link gốc, tác giả, giấy phép. Chỉ nhận CC0 hoặc giấy phép rõ ràng cho phép dùng thương mại (sau này có bán skin). Không dùng file không rõ nguồn.

## Nhạc nền (lặp liền, .ogg)

| File | Dùng ở | Mô tả | Nguồn |
|---|---|---|---|
| music_menu.ogg | màn bắt đầu | Sol trưởng, 88 BPM, giai điệu ngũ cung kiểu đàn tranh có luyến, nền pad nhẹ | tự tổng hợp, CC0 |
| music_delivery.ogg | lúc giao bánh | Rê trưởng, 126 BPM, vui, gảy dây + bass nảy + trống nhẹ | tự tổng hợp, CC0 |
| music_chase.ogg | đơn 5, Chó Mực thức | La thứ, 150 BPM, gấp, trống 4 phách | tự tổng hợp, CC0 |
| music_kitchen.ogg | màn bếp | Fa trưởng, 100 BPM, đàn gõ kiểu marimba, nhịp lắc lư | tự tổng hợp, CC0 |
| jingle_win.ogg | kết thúc, từ 10/15 sao | hợp âm rải đi lên + chuông | tự tổng hợp, CC0 |
| jingle_lose.ogg | kết thúc, dưới 10 sao | bốn nốt đi xuống, nhẹ nhàng | tự tổng hợp, CC0 |

## Tiếng nền (lặp liền, .ogg)

| File | Mô tả | Nguồn |
|---|---|---|
| amb_street.ogg | 40 giây phố: ù xa, rì rầm người, 6 xe máy chạy ngang (có Doppler, trái phải), còi "tin tin", chim sẻ, hai tiếng rao xa không lời | tự tổng hợp, CC0 |
| amb_kitchen.ogg | 20 giây bếp: tủ lạnh ù, đồng hồ treo tường, xe máy xa ngoài đường | tự tổng hợp, CC0 |

## Hiệu ứng (.wav, ngắn)

| File | Khi nào | Nguồn |
|---|---|---|
| step_1..4.wav | bước chân mèo, chọn ngẫu nhiên, nhanh dần theo tốc độ | tự tổng hợp, CC0 |
| jump.wav, land.wav | nhảy, chạm đất | tự tổng hợp, CC0 |
| meow.wav, meow_short.wav | được 3 sao, nhận bánh, bị đớp | tự tổng hợp, CC0 |
| pickup.wav | nhận bánh: túi giấy sột soạt + hai nốt | tự tổng hợp, CC0 |
| deliver.wav | giao xong: chuông "ting ting" | tự tổng hợp, CC0 |
| star_1..3.wav | mỗi sao một tiếng, cao dần | tự tổng hợp, CC0 |
| fail.wav | trễ đơn | tự tổng hợp, CC0 |
| tick.wav, tick_urgent.wav | 5 giây cuối, 3 giây cuối kêu gấp | tự tổng hợp, CC0 |
| bark.wav, bark_single.wav | Chó Mực sủa (gâu gâu / gâu), nhỏ dần theo khoảng cách. Tạo bằng mô hình nguồn-bộ lọc trong tools/sound/bark.py; đổi giọng bằng BARK_KIND=vua/tram/kho | tự tổng hợp, CC0 |
| growl.wav | Chó Mực thức dậy | tự tổng hợp, CC0 |
| bite.wav | bị đớp | tự tổng hợp, CC0 |
| ui_click.wav, ui_start.wav | bấm nút, bấm Bắt đầu | tự tổng hợp, CC0 |
| knead_1..3.wav | bếp: nhồi bột | tự tổng hợp, CC0 |
| chop_1..3.wav | bếp: dao chặt trên thớt | tự tổng hợp, CC0 |
| crunch.wav | bếp: cắt bánh mì giòn | tự tổng hợp, CC0 |
| sauce.wav | bếp: bóp chai sốt | tự tổng hợp, CC0 |
| oven_open.wav, oven_ding.wav | bếp: mở cửa lò, chuông lò xong | tự tổng hợp, CC0 |
| wrap.wav | bếp: gói bánh vào giấy | tự tổng hợp, CC0 |
| burn.wav | bếp: bánh cháy, xèo gắt rồi phì khói | tự tổng hợp, CC0 |
| water.wav | bếp: rửa rau, rót nước | tự tổng hợp, CC0 |
| spray.wav | bếp: phun hơi nước, bình xịt | tự tổng hợp, CC0 |
| sizzle.ogg, oven_fire.ogg | bếp: tiếng xèo chảo, lửa lò (lặp 4 giây) | tự tổng hợp, CC0 |
| snore.ogg | Thứ Hai: Chó Mực ngáy (lặp 3,2 giây) | tự tổng hợp, CC0 |
| sniff.wav | Thứ Hai: Chó Mực đánh hơi khi nghi ngờ | tự tổng hợp, CC0 |
| tag_jingle.wav | Thứ Hai: thẻ tên đồng trên vòng cổ khua leng keng | tự tổng hợp, CC0 |
| sneak_1..3.wav | Thứ Hai: bước rón rén, rất nhỏ | tự tổng hợp, CC0 |
| moto_pass_1..2.ogg | Thứ Hai: xe máy chạy ngang (3 giây, có Doppler) | tự tổng hợp, CC0 |
| moto_idle.ogg | Thứ Hai: xe máy nổ máy chờ đèn (lặp 2 giây) | tự tổng hợp, CC0 |
| horn.wav | Thứ Hai: còi xe máy "tin tin" | tự tổng hợp, CC0 |
| basket_lower.wav, basket_drop.wav | Thứ Hai: Bé Na thòng giỏ nhựa, thả bánh vào giỏ | tự tổng hợp, CC0 |
| glass_rattle.wav, glass_tip.wav | Thứ Hai: ly cà phê rung, ly đổ | tự tổng hợp, CC0 |
| oil_slip.wav | Thứ Hai: giẫm vũng dầu trượt | tự tổng hợp, CC0 |

## Tiếng lấy từ nguồn ngoài

Chưa có.

| File | Link gốc | Tác giả | Giấy phép |
|---|---|---|---|
