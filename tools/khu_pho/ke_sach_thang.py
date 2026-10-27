"""Kệ sách của tháng trên sạp báo Chú Tư (Vũ Trụ Mark C1). Phác thảo Sang duyệt 27/10/2026:
https://claude.ai/artifact/3v6iZDmt6tvSwJMsXjifAY (bản phác và ảnh render: /mnt/project-files/vu-tru-mark-dot-1/c1-sach-thang/).

Giá gỗ, sách dựng ngả 14°, thẻ "THÁNG 11", hai cuốn nằm chồng. Bìa lấy màu và dải bút chì của bìa thu nhỏ bên Vũ Trụ Khác
(Thinking, Fast and Slow), tự vẽ lại. xuat_game.py gắn món này lên quầy sạp báo (sap_bao_game) nên không có .glb riêng.
Đổi sách tháng sau: đổi MAU bìa và chữ thẻ ở đây, SACH trong scripts/ke_sach_thang.gd, rồi
python3 tools/khu_pho/xuat_game.py assets/models/pho sap_bao
"""
import math
from kit import *

MAU = dict(bia='#1A1A1A', bia2='#3A3320', vang='#F5C518', giay='#EFE6CF', go='#B07C46', go_dam='#8A5A30',
           do='#C8412F', hong='#E79A9A', chi='#4A4A4A', kem='#FFF8EA', xanh_sap='#2E7C80')

# Kích thước (mét thật) trước khi phóng TO: cả món phóng 1,3 lần (sách thành 23 x 34 cm, cỡ sách trưng bày)
# để nhận ra bìa từ camera game đứng xa ~4 m.
TO = 1.3
SW, ST, SH = .18, .03, .26      # rộng, dày, cao
NGHIENG = math.radians(14)       # sách tựa ngả ra sau


def sach_dung(tach=0.0):
    """Cuốn sách dựng trên giá. tach > 0: kéo các lớp bìa ra phía trước để xem từng bộ phận."""
    g = group('sach', (0, 0, 0))
    with at(g):
        # ruột sách (giấy kem) lùi vào trong bìa 4 mm ở ba cạnh
        box((SW - .008, ST - .006, SH - .008), (.002, 0, 0), M(MAU['giay'], .9), .002, name='ruot')
        # bìa trước, bìa sau, gáy (bên trái nhìn từ trước)
        box((SW, .004, SH), (0, -ST / 2 - tach * .5, 0), M(MAU['bia'], .55), .002, name='bia_truoc')
        box((SW, .004, SH), (0, ST / 2, 0), M(MAU['bia'], .55), .002, name='bia_sau')
        box((.006, ST + .004, SH), (-SW / 2, 0, 0), M(MAU['bia2'], .6), .002, name='gay')
        y = -ST / 2 - .003 - tach
        # dải vàng tên sách (thay chữ tựa) và vạch vàng mảnh dưới nó
        box((.13, .002, .045), (-.015, y, SH / 2 - .045), M(MAU['vang'], .5), 0, name='dai_ten')
        box((.13, .002, .006), (-.015, y, SH / 2 - .078), M(MAU['vang'], .5), 0, name='vach')
        # dải tên tác giả (kem) ở chân bìa
        box((.08, .002, .012), (-.035, y, -SH / 2 + .03), M(MAU['kem'], .7), 0, name='tac_gia')
        # bút chì nằm chéo giữa bìa: thân vàng, đầu gỗ, ngòi chì, tẩy hồng, khoen bạc
        b = group('but_chi', (0, y - .006, -.01), 0)
        b.rotation_euler = (0, math.radians(-35), 0)
        with at(b):
            cyl(.009, .12, (0, 0, 0), M(MAU['vang'], .5), rot=(0, math.pi / 2, 0), n=6, bv=0, name='than_chi')
            cyl(.009, .025, (.0725, 0, 0), M('#E8C98A', .7), rot=(0, math.pi / 2, 0), n=6, r2=.002, bv=0, name='dau_go')
            cyl(.0025, .008, (.089, 0, 0), M(MAU['chi'], .5), rot=(0, math.pi / 2, 0), n=6, r2=.0005, bv=0, name='ngoi')
            cyl(.0095, .01, (-.065, 0, 0), M('#AEB6B8', .35, .7), rot=(0, math.pi / 2, 0), n=6, bv=0, name='khoen')
            cyl(.009, .016, (-.078, 0, 0), M(MAU['hong'], .7), rot=(0, math.pi / 2, 0), n=6, bv=.002, name='tay')
    return g


def gia_go():
    """Giá gỗ nhỏ: đế, tấm tựa ngả sau, gờ chặn chân sách."""
    g = group('gia', (0, 0, 0))
    with at(g):
        box((.22, .13, .016), (0, .01, .008), M(MAU['go'], .6), .004, name='de')
        t = box((.16, .012, .2), (0, .055, .11), M(MAU['go_dam'], .65), .004, name='tua')
        t.rotation_euler = (NGHIENG, 0, 0)
        box((.22, .014, .024), (0, -.045, .028), M(MAU['go'], .6), .004, name='go_chan')
    return g


def the_thang():
    """Thẻ giấy "THÁNG 11" kẹp trước giá: nền kem viền đỏ, chữ đỏ."""
    g = group('the', (0, 0, 0))
    with at(g):
        box((.11, .004, .055), (0, 0, 0), M(MAU['do'], .7), .002, name='vien')
        box((.1, .005, .045), (0, -.001, 0), M(MAU['kem'], .8), .001, name='giay_the')
        text('THÁNG 11', .026, (0, -.004, -.001), M(MAU['do'], .6), extrude=.0015, name='chu_the')
    return g


def chong_sach():
    """Hai cuốn cùng loại nằm chồng cạnh giá (Chú Tư bán kèm)."""
    g = group('chong', (0, 0, 0))
    with at(g):
        for i, rz in enumerate((.12, -.05)):
            box((SW, SH, ST), (0, 0, ST / 2 + i * ST), M(MAU['bia'], .55), .002, rot=(0, 0, rz), name=f'nam{i}')
            box((.13, .045, .002), (-.015 + .0 * i, SH / 2 - .045, ST + i * ST + .001), M(MAU['vang'], .5), 0, rot=(0, 0, rz), name=f'nam_dai{i}')
    return g


def ke_sach(tach=0.0):
    """Cả món: giá gỗ + sách dựng + thẻ tháng + chồng sách bên phải. Gốc ở giữa đáy giá, mặt trước quay về -Y."""
    g = group('ke_sach_thang', (0, 0, 0))
    with at(g):
        gia_go()
        s = sach_dung(tach)
        s.location = (0, .012 + tach * .3, .016 + SH / 2 * math.cos(NGHIENG) + .004); s.rotation_euler = (NGHIENG, 0, 0)
        t = the_thang(); t.location = (-.02, -.062 - tach * 1.2, .05); t.rotation_euler = (math.radians(-8), 0, 0)
        c = chong_sach(); c.location = (.25 + tach * 1.5, .0, 0)
    g.scale = (TO, TO, TO)
    return g
