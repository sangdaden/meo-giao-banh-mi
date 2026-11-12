"""U2 "Bơ phản ứng theo ngày": động tác đứng yên riêng mỗi ngày, trên rig chính thức 22 xương
(cùng cách viết với tools/dong_tac_bo/anims.py; chạy được trên Bơ lẫn 19 giống vì dùng chung tên xương).
Mỗi clip bắt đầu từ dáng đứng ({}), vì game phát khi Bơ đứng yên đủ lâu; kết thúc ở dáng ngồi hoặc đứng, game tự hoà về.
Tham khảo thật (ghi trên trang duyệt):
- Rửa mặt: liếm mặt trong chân trước cho ướt, miết vòng từ mũi lên qua mắt ra sau tai, liếm lại chân rồi miết tiếp; cùng một bên.
- Nằm bóng mát ("sploot"): bụng áp sàn, chân sau duỗi thẳng ra sau, để tăng chỗ chạm nền mát cho mau nguội.
- Giũ chân: mèo bước vào nước thì nhấc chân, vẩy nhanh vài cái rồi đặt xuống, chân khác làm sau.
- Hắt xì vì khói nhang: mũi mèo nhạy, đường thở hẹp; khói làm hắt xì, chảy nước mắt.
Khoá 'day' là ngày dùng; 'trigger' là điều kiện phát trong game; 'scene' là đồ tham chiếu đặt trong ảnh."""
import sys
import math
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from anims import merge, cyc, SIT, S, C, TAU   # noqa: E402
import anims as G2   # noqa: E402

ANIMS = {}


def A(name, **kw):
    kw['name'] = name
    ANIMS[name] = kw


EARS_FWD = dict(earL=(12,), earR=(12,))
EARS_SOFT = dict(earL=(-8, 0, -10), earR=(-8, 0, 10))
EARS_BACK = dict(earL=(-16, 0, -26), earR=(-16, 0, 26))
TAIL_WRAP = (-30, 20, -10, 35, 0, 35, 10, 30)


# ======================= THỨ HAI: rửa mặt buổi sáng =======================
LICK = merge(SIT, dict(head=(-22, 16, 10), chest=(-12, 4, -4), eye=(.3,), FR=(-.012, .18, .16, -85), **EARS_SOFT))
WIPE_A = merge(LICK, dict(head=(-30, 30, 34), FR=(.012, .25, .12, -55), eye=(.05,)))     # chân ở sau tai
WIPE_B = merge(LICK, dict(head=(-14, 10, 12), FR=(-.015, .17, .17, -85), eye=(.15,)))   # miết xuống tới mũi


def bob(d, k=6):
    h = d['head']
    return merge(d, dict(head=(h[0] - k, h[1], h[2])))


A('rua_mat', day='T2', title='Rửa mặt buổi sáng', dur=3.4, loop=False, modes=dict(FR='b'),
  trigger='Đứng yên 6 s ở bất cứ đâu ngoài phố Thứ Hai (sáng sớm, trời mát).',
  keys=[(0, {}), (.3, SIT), (.6, LICK), (.75, bob(LICK)), (.9, LICK), (1.05, bob(LICK)), (1.2, LICK),
        (1.45, WIPE_A), (1.75, WIPE_B), (1.95, WIPE_A), (2.25, WIPE_B),
        (2.45, LICK), (2.6, bob(LICK)), (2.75, LICK),
        (3.1, merge(SIT, dict(head=(2, 6, 4), eye=(1.0,), **EARS_FWD))), (3.4, merge(SIT, dict(head=(0, 0, 0), eye=(1.0,))))],
  shots=[.6, 1.45, 1.75, 3.1], main=1.45, views=('q34', 'front', 'side', 'q34f'), strip_view='q34', center=(0, -.05, .3), scale=.9,
  notes='Ngồi xuống (0,3 s), nhấc chân trước phải lên ngang miệng, cúi đầu liếm mặt trong bàn chân 3 nhát (đầu gật theo mỗi nhát, mắt lim dim). '
        'Rồi miết: đưa chân lên sau tai phải, đầu nghiêng 34° và quay về phía chân, kéo chân vòng xuống qua mắt tới mũi; làm 2 lượt. '
        'Liếm lại chân 2 nhát, đặt chân xuống, ngẩng lên tỉnh táo. Không có xương lưỡi nên "liếm" là nhịp gật đầu sát bàn chân.')


# ======================= THỨ BA: ngó chợ đông =======================
NGO = merge(SIT, dict(head=(4, 0, 0), eye=(1.0,), tail=TAIL_WRAP, **EARS_FWD))


def track(u):
    """Đầu dõi theo một chiếc xe chạy ngang trước mặt từ trái sang phải; tai quay theo, chóp đuôi búng."""
    y = -45 + 90 * u
    return merge(NGO, dict(head=(4, y, y * .12), chest=(-14, y * .15, 0),
                           earL=(10, y * .4, 0), earR=(10, y * .4, 0),
                           tail=(-30, 20, -10, 35, 0, 35, 10, 30 + 20 * S(u * TAU * 2))))


A('ngo_cho', day='T3', title='Ngó chợ đông', dur=3.6, loop=False,
  trigger='Đứng yên 6 s trong vùng chợ sáng (3 đơn đầu) hoặc ở góc cờ Thứ Ba.',
  keys=[(0, {}), (.3, SIT), (.55, track(0)), *[(.55 + 1.3 * i / 6, track(i / 6)) for i in range(1, 7)],
        (2.1, track(1.0)), (2.25, merge(track(1.0), dict(earL=(-6, -30, -20), earR=(-6, 30, 20), eye=(1.0,), root=(0, -.105, .02)))),
        (2.4, merge(NGO, dict(head=(10, -20, -6), earL=(16, -20, 0), earR=(16, -20, 0)))),
        (2.9, merge(NGO, dict(head=(10, -24, -10), eye=(.2,)))), (3.05, merge(NGO, dict(head=(10, -24, -10), eye=(1.0,)))),
        (3.6, merge(NGO, dict(head=(2, -8, -4))))],
  shots=[.55, 1.2, 2.25, 2.9], main=1.2, views=('q34', 'front', 'top', 'q34b'), strip_view='front', center=(0, 0, .28), scale=1.1,
  notes='Ngồi, đuôi quấn chân. Đầu dõi theo một chiếc xe chạy ngang trước mặt từ trái sang phải (1,3 s, quay ±45°, vai quay nhẹ theo), '
        'hai tai xoay cùng hướng, chóp đuôi búng hai lần. Có tiếng còi bên trái: tai giật bạt ra (2,25 s), người hơi rụt, '
        'quay phắt sang trái nhìn, chớp mắt chậm một cái (2,9 s) như "à, Chú Năm" rồi thôi.')


# ======================= THỨ TƯ: giũ chân ướt (giũ cả người dùng lại giu_nuoc G2) =======================
def flick_front(u):
    """Chân trước trái nhấc lên vẩy nhanh: cổ chân lắc trước sau, bàn chân gập búng."""
    a = S(u * TAU * 3)
    return dict(FL=(-.005, .12 + .015 * a, .06 + .03 * a, -55 + 35 * a), root=(.012, -.008, 0, 0, 0, 3),
                head=(-30, -14, -8), chest=(-6, -6, 0), eye=(.8,), earL=(-6, 0, -12), earR=(-6, 0, 12),
                tail=(10, 0, 0, 0, 0, 0, 10, 0))


def flick_back(u):
    a = S(u * TAU * 2.5)
    return dict(BR=(.01, .08 + .025 * a, -.08 - .04 * a, 50 + 30 * a), root=(-.01, -.006, .01, 0, 0, -3),
                head=(-6, 40, 6), chest=(-2, 18, 0), eye=(.7,), earL=(-4, 0, -8), earR=(-4, 0, 8),
                tail=(25, -20, 10, -20, 0, -15, 10, -10))


A('giu_chan', day='T4', title='Giũ chân ướt', dur=2.6, loop=False,
  trigger='Vừa lội vũng nước hay đi dưới mưa rồi đứng yên 3 s ở chỗ khô. Ra khỏi mưa thì phát giu_nuoc (G2) trước, đứng thêm thì giu_chan.',
  scene='vung',
  keys=[(0, {}), (.25, dict(FL=(-.005, .11, .05, -40), root=(.012, -.008, 0, 0, 0, 3), head=(-30, -14, -8), eye=(.9,))),
        *[(.3 + .45 * i / 12, flick_front(i / 12)) for i in range(13)],
        (.9, dict(root=(.006, -.004, 0), head=(-18, -8, -4), eye=(1.0,))), (1.05, {}),
        (1.25, dict(BR=(.01, .05, -.05, 40), root=(-.01, -.006, .01, 0, 0, -3), head=(-6, 36, 6), chest=(-2, 16, 0))),
        *[(1.3 + .4 * i / 10, flick_back(i / 10)) for i in range(11)],
        (1.85, dict(head=(-4, 10, 0))), (2.0, dict(head=(-2, 0, 18), eye=(.3,), **EARS_BACK)), (2.1, dict(head=(-2, 0, -18), eye=(.2,), **EARS_BACK)),
        (2.2, dict(head=(-2, 0, 14), eye=(.3,))), (2.3, dict(head=(-2, 0, -8), eye=(.6,))), (2.6, dict(eye=(1.0,)))],
  shots=[.25, .45, 1.45, 2.05], main=.45, views=('q34f', 'front', 'side', 'q34b'), strip_view='q34f', center=(0, 0, .25), scale=1.1,
  notes='Đứng, dồn người sang phải, nhấc chân trước trái lên 8 cm, cúi nhìn bàn chân rồi vẩy nhanh 3 cái trong 0,45 s (bàn chân búng gập, '
        'như rảy nước khỏi kẽ ngón), đặt xuống. Quay đầu ra sau nhìn chân sau phải, nhấc lên đá giật ra sau 2–3 cái. '
        'Cuối cùng lắc đầu nhanh 4 nhịp (tai bạt), mở mắt. Đi đôi với giu_nuoc G2 (giũ cả người, có sẵn trong game).')
A('giu_nuoc', day='T4', title='Giũ nước cả người (có sẵn, G2)', reuse=True,
  trigger='Đã có trong game từ G2: phát khi ra khỏi mưa hoặc vũng. U2 chỉ thêm điều kiện "đứng yên" và nối giu_chan sau.',
  **{k: v for k, v in G2.ANIMS['giu_nuoc'].items() if k in ('dur', 'loop', 'keys', 'base', 'notes')},
  shots=[.08, .22, .34, .5], main=.22, views=('front', 'q34'), strip_view='front', center=(0, 0, .27), scale=1.1)


# ======================= THỨ NĂM: nằm bóng mát buổi trưa =======================
SPLOOT = dict(root=(0, -.16, .03), hips=(-4,), chest=(-2,), head=(-16, 6, 4), eye=(.25,),
              FL=(-.01, .0, .1, 30), FR=(.01, .0, .12, 30), BL=(-.03, .0, -.24, 85), BR=(.03, .0, -.24, 85),
              tail=(-32, 6, -4, 8, 0, 10, 0, 6), earL=(-6, 0, -14), earR=(-6, 0, 14))
A('nam_bong_mat', day='T5', title='Nằm bẹp bóng mát', dur=3.2, loop=True,
  trigger='Trưa Thứ Năm, đứng yên 5 s dưới bóng râm (chân tường chung cư, gầm cầu thang). Ngoài nắng thì vẫn dùng phoi_nang/ngu_cuon như cũ.',
  scene='bong',
  keys=[(0, SPLOOT), (1.0, merge(SPLOOT, dict(chest=(1,), root=(0, -.157, .03)))), (1.8, SPLOOT),
        (2.2, merge(SPLOOT, dict(tail=(-32, 6, -4, 8, 0, 10, 25, 30)))), (2.35, merge(SPLOOT, dict(earL=(6, 0, -24)))),
        (2.6, SPLOOT), (3.2, SPLOOT)],
  shots=[0, 1.0, 2.2], main=1.0, views=('q34', 'side', 'top', 'q34b'), strip_view='q34', center=(0, -.05, .14), scale=1.2,
  notes='Nằm bẹp kiểu "ếch" trên nền gạch mát: bụng áp sàn, hai chân sau duỗi thẳng ra sau, lòng bàn chân ngửa lên, hai chân trước '
        'duỗi ra trước, cằm gần chạm sàn, mắt lim dim, tai xuôi. Lặp 3,2 s: lưng phồng xẹp chậm, chóp đuôi búng (2,2 s), tai trái giật (2,35 s). '
        'Khác phoi_nang (nằm nghiêng ngoài nắng): đây là dáng "nóng quá, áp bụng cho mát".')


# ======================= THỨ SÁU: hắt xì vì khói nhang =======================
STAND_SNIFF = dict(head=(14, 0, 0), eye=(.7,), **EARS_FWD)
A('hat_xi', day='T6', title='Hắt xì vì khói nhang', dur=2.4, loop=False,
  trigger='Đứng yên 3 s trong vòng 2 m quanh bàn thờ nhà Bà Sáu (đám giỗ Thứ Sáu). Mỗi lần vào vùng chỉ hắt xì một lần.',
  scene='nhang',
  keys=[(0, {}), (.3, STAND_SNIFF), (.42, merge(STAND_SNIFF, dict(head=(18, 0, 0)))), (.54, STAND_SNIFF), (.66, merge(STAND_SNIFF, dict(head=(18, 0, 0)))),
        (.95, dict(head=(26, 0, 0), chest=(6,), root=(0, .008, -.012), eye=(.12,), earL=(-12, 0, -16), earR=(-12, 0, 16))),
        (1.05, dict(head=(-30, 0, 0), chest=(-8,), root=(0, -.028, .022), eye=(0.,), **EARS_BACK)),
        (1.18, dict(head=(-12, 0, 0), chest=(-3,), root=(0, -.01, .008), eye=(.2,), **EARS_BACK)),
        *[(1.3 + .075 * i, dict(head=(-6, 8 * (-1) ** i, 26 * (-1) ** i * (1 - i / 8)), eye=(.15,), **EARS_BACK)) for i in range(7)],
        (1.9, dict(head=(-4, 0, 0), eye=(1.0,))), (2.02, dict(head=(-4, 0, 0), eye=(.1,))), (2.14, dict(head=(-2, 0, 0), eye=(1.0,), earL=(10, 0, -20))),
        (2.4, dict(eye=(1.0,)))],
  shots=[.3, .95, 1.05, 1.45], main=1.05, views=('side', 'q34', 'front', 'q34b'), strip_view='side', center=(0, -.2, .28), scale=1.35,
  notes='Đứng, ngẩng mũi hít hai nhịp về phía khói (0,3–0,66 s). Nín: đầu ngửa thêm, mắt nhíu, tai xuôi ra sau (0,95 s). '
        '"Hắt xì!" (1,05 s): đầu giật mạnh xuống 56°, ngực chúi, người nhích tới 2 cm, mắt nhắm tịt. Rồi lắc đầu nhanh 7 nhịp nhỏ dần, '
        'chớp mắt, tai trái giật một cái. Kèm tiếng "hắt xì" nhỏ (giọng ú ớ E1) và một làn khói nhẹ tan trước mũi.')


# ======================= THỨ BẢY: vờn bướm =======================
LOOKUP = merge(SIT, dict(head=(30, -10, -6), chest=(-16,), eye=(1.0,), tail=TAIL_WRAP, **EARS_FWD))
A('von_buom', day='T7', title='Vờn bướm', dur=3.2, loop=False, modes=dict(FR='b', FL='b'),
  trigger='Thứ Bảy, đứng yên 6 s gần chỗ có bướm (V4 bướm đã có trong game) hoặc bụi hoa; con bướm bay quanh đầu Bơ trong lúc phát.',
  scene='buom',
  keys=[(0, {}), (.3, SIT), (.6, LOOKUP), (1.0, merge(LOOKUP, dict(head=(36, 16, 8), tail=(-30, 20, -10, 35, 0, 35, 30, 50)))),
        (1.2, merge(LOOKUP, dict(head=(34, 10, 6), root=(0, -.11, .01)))),
        (1.4, merge(LOOKUP, dict(head=(38, 8, 4), chest=(-24,), FR=(.01, .33, .16, -30), eye=(1.0,)))),
        (1.6, merge(LOOKUP, dict(head=(34, -4, 0)))),
        (1.85, merge(LOOKUP, dict(head=(40, -14, -6), chest=(-24,), FL=(-.01, .34, .15, -30)))),
        (2.05, merge(LOOKUP, dict(head=(32, -20, -8)))),
        (2.5, merge(LOOKUP, dict(head=(22, 40, 12), earL=(14, 30, 0), earR=(14, 30, 0)))),
        (3.2, merge(SIT, dict(head=(10, 34, 10), eye=(.9,), tail=TAIL_WRAP)))],
  shots=[.6, 1.4, 1.85, 2.5], main=1.4, views=('q34', 'front', 'side', 'q34b'), strip_view='q34', center=(0, -.05, .32), scale=1.2,
  notes='Ngồi, ngẩng nhìn con bướm lượn trên đầu, mắt tròn, chóp đuôi giật giật. Bướm hạ thấp thì vươn người đập nhẹ chân trước phải lên (1,4 s), '
        'hụt, rồi chân trái (1,85 s), không vồ, không nhảy. Bướm bay đi, Bơ quay đầu nhìn theo rồi ngồi yên. Dáng hiền, vờn chứ không săn.')


# ======================= CHỦ NHẬT: chải lông đi hội =======================
FLANK = merge(SIT, dict(chest=(-10, 34, 4), head=(-34, 78, 24), eye=(.25,), **EARS_SOFT))
CHEST = merge(SIT, dict(chest=(-22, 6, 0), head=(-58, 8, 6), eye=(.2,), **EARS_SOFT))
A('chai_long', day='CN', title='Chải lông đi hội', dur=3.8, loop=False,
  trigger='Chủ Nhật, đứng yên 6 s ở sân Hội mèo trước các trò thi (mèo khác cũng chải chuốt, G10 dùng chung clip được).',
  keys=[(0, {}), (.3, SIT), (.65, FLANK), *[(.8 + .2 * i, bob(FLANK, 8) if i % 2 == 0 else FLANK) for i in range(6)],
        (2.0, CHEST), *[(2.15 + .18 * i, bob(CHEST, 8) if i % 2 == 0 else CHEST) for i in range(5)],
        (3.15, merge(SIT, dict(head=(-2, 0, 14), eye=(.5,)))), (3.4, merge(SIT, dict(head=(14, 0, 0), chest=(-8,), eye=(1.0,), tail=(-10, 0, 25, 0, 25, 0, 30, 10), **EARS_FWD))),
        (3.8, merge(SIT, dict(head=(12, 0, 0), chest=(-8,), eye=(1.0,), tail=(-10, 0, 25, 0, 25, 0, 30, -10), **EARS_FWD)))],
  shots=[.65, 1.0, 2.15, 3.4], main=1.0, views=('q34', 'q34b', 'front', 'side'), strip_view='q34', center=(0, 0, .28), scale=1.1,
  notes='Ngồi, quay đầu ra sau liếm vai và hông phải 3 nhát dài (đầu miết từ vai xuống), rồi cúi liếm ngực 3 nhát, lắc nhẹ đầu, '
        'ngồi thẳng ưỡn ngực, đuôi dựng vẫy chóp như sẵn sàng lên sân. Ngày hội thì phải đẹp.')
