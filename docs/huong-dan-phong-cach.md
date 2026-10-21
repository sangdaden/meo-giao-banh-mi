# Hướng dẫn phong cách D · Chững chạc (Sang duyệt 21/10/2026)

Bản đọc cho các thread. Bản cho Sang: https://claude.ai/artifact/NZk8t4BZ21jUdGXkWnX6NW
Trang so sánh, có Bơ chuẩn xoay 3D: https://claude.ai/artifact/1ogwurqo2d1s53J4vozLSL

## Bơ chuẩn
- Script: `meo-3d/bo-chung-chac/mature.py` + `sdflib.py`. Chạy: `python3 mature.py chung2 <outdir> q34,side,front,face --glb`.
- `STYLES['chung2']` ghi `None` trong dict, rồi được tạo ngay sau dict bằng `deepcopy(STYLES['chung'])` và ghi đè `eye`, `pose`, `blush`. Đó là bản Sang duyệt (mắt cười: lid .08, lidtilt -.1, smile .16, roll .16, pupilw .5).
- File: `chung2.blend`, `chung2.glb`, `chung2_*.png` cùng thư mục.
- Cần: `pip install bpy scikit-image`; Eevee chạy ngầm cần `apt-get install libegl1 libegl-mesa0 libgl1-mesa-dri libgbm1`.

## Tinh thần
Hoạt hình 3D chững chạc, thân thiện (Zootopia, Puss in Boots). Không chibi (đầu to bằng thân, mắt chấm, pastel, toon phẳng: Sang đã loại). Không cứng (khối rời, đứng thẳng đơ, bóng như nhựa: Sang đã chê).

## Tỉ lệ (toạ độ three.js: mét, Y lên, nhìn +Z; Blender = (x, -z, y))
- Bơ cao 0,6 m tới đỉnh tai. Đầu : thân ≈ 1 : 2,2; đầu to hơn thật 10–15%.
- Đầu c(0,.43,.17) bán kính (.12,.105,.11). Thân c(0,.24,-.03) r(.108,.112,.19). Ngực c(0,.29,.11) r(.092,.1,.09).
- Chân trước x ±.056, z .1, từ y .27, r .036→.029. Chân sau x ±.064, z -.15, từ y .22, r .04→.031; đùi sau c(±.064,.24,-.14) r(.058,.1,.09).
- Đuôi ngắn như mèo nhà thật (Sang chỉnh 21/10, trước đó 0,53 m là quá dài): dài ~0,30 m dọc đường cong ≈ 0,55 × (đầu + thân ~0,55 m); gốc dày 6 cm, chóp 4,4 cm; rủ xuống rồi cong nhẹ lên, chóp cao ~0,42 m. Điểm `tail` trong chung2: (0,.27,-.2) (0,.25,-.285) (0,.29,-.35) (.012,.36,-.385) (.02,.42,-.375), bán kính .03 → .022. Rig 4 xương đuôi, mỗi xương ~7,5 cm. Các giống mèo khác theo tỉ lệ 0,55 (trừ giống cụt đuôi, giống đuôi xù chỉ dày hơn chứ không dài hơn).
- Cổ rất ngắn, giấu dưới khăn (vòng khăn tâm (0,.335,.13), pháp tuyến (0,.9,.44)).
- Dáng duyệt: đầu quay .28 rad, nghiêng .05, ngẩng .04 quanh (0,.34,.12); chân trước trái bước +3,5 cm, chân sau phải +3 cm; đuôi chữ S. Không duyệt ở dáng đứng thẳng đơ.

## Hình khối
Một lớp da liền, chỗ nối bo 2–5 cm (smooth union). Tròn căng, không góc nhọn trừ chóp tai. Có mốc giải phẫu: đùi sau, khuỷu, cổ chân, má, hốc mắt. Chi tiết < 1 cm vẽ texture.

## Mắt (quan trọng nhất)
Hạnh nhân rộng hơn cao (Bơ 6,6 × 5,4 cm), đuôi mắt hếch ~9°. Mí trên mỏng, nằm ngang, che ~8%. Mí dưới hơi đẩy lên (cười). Con ngươi khe dọc rộng ~1/2 tròng. Tròng sáng 2 tông (Bơ #F7D35E → #CC8E2C, viền #8A5520). 2 đốm sáng: to trên-ngoài, nhỏ dưới. Miệng chữ w khóe cong lên. Má hồng ~30%.
Cấm: mí xệ đuôi mắt (buồn, Sang đã chê), xệ khóe trong (giận), che > 1/5 (buồn ngủ), khe mảnh như chỉ, đầu cúi mắt ngước.
Biểu cảm khác = shape key trên cùng thiết kế mắt.

## Màu
Ấm, bão hoà vừa, không pastel nhạt, không neon. Bơ: lông #E8913A, vằn #B9601C, kem #FBE6C8, trong tai #E59A8C, mũi #C45A5E, nét #3A2418, khăn #C8412F. Mỗi nhân vật 1 màu nhấn. Phố/đồ vật trầm hơn nhân vật 1 bậc.

## Chất liệu
Blender lông: Roughness .78, Sheen .45, Specular IOR Level .3, Coat 0. Mắt: Roughness .05, Coat 1. Vải: Roughness .9, Sheen 1. Kim loại: Metallic 1, Roughness .35–.5.
Godot: StandardMaterial3D lông Roughness .8, Rim .3; mắt Clearcoat 1; vải Roughness .9, Rim .4. Không cel shading.

## Độ chi tiết (model vào game, tự dựng tay)
Bơ/skin 4–6k tam giác, texture 1024, 22 xương. Chó Mực 4–5k, 1024. Người 2,5–4k, 512, ~18 xương. Phụ kiện 100–800 (atlas 512). Đồ bếp 100–1000 (atlas 1024). Mảnh phố 300–2000. Cạnh đồ vật bevel 1–2 cm.

## Áp dụng
- Skin 19 giống: cùng dáng/mắt Bơ, chỉ đổi tỉ lệ xương, shape key, màu lông, màu tròng.
- Chó Mực: to ~1,6 lần Bơ, đầu vuông bo, mõm dài hơn, đen mực bụng xám. Canh hẻm: mí trên hạ phẳng, nghiêm chứ không ác. Thua: tai cụp, mắt tròn, đuôi vẫy.
- Người: đầu : thân ~1 : 5,5, tay chân tròn, bàn tay 4 ngón bo, mắt cùng kiểu.
- Đồ bếp: kích thước thật, đồ cầm tay phóng ~10%.
- Phố, xe: kích thước thật, cạnh bo, chi tiết gọn, màu ấm Sài Gòn.

## Điểm gắn phụ kiện (dáng nghỉ, đầu chưa xoay, toạ độ three.js, mét)
| Socket | Vị trí | Gắn xương |
| --- | --- | --- |
| head_top | (0, .535, .15) | head |
| face (giữa hai mắt, kính) | (0, .44, .282) | head |
| neck (tâm vòng khăn) | (0, .335, .13), pháp tuyến (0, .9, .44) | neck |
| shoulder | (0, .36, .06) | spine.3 |
| back | (0, .352, -.03) | spine.2 |
| tail_mid | (0, .29, -.35) | tail.2 |
| tail_tip | (.02, .42, -.375) | tail.4 |
| paw.F.L / paw.F.R | (-.056, .022, .112) / (.056, .022, .112) | paw bones |
| paw.B.L / paw.B.R | (-.064, .022, -.138) / (.064, .022, -.138) | paw bones |

Trong dáng duyệt, đầu xoay quanh (0,.34,.12); socket thuộc đầu xoay theo (hàm `head_world` trong mature.py).

## Duyệt
Render Eevee, đèn: mặt trời ấm 1,7 trước-phải-trên, phụ xanh nhạt trái, viền sau, nền bạc hà #9CCBC1. Góc: 3/4, ngang, trước, cận mặt + khung xoay. Đặt cạnh Bơ chuẩn.
