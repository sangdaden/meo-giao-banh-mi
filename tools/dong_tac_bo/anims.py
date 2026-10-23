"""18 động tác mới của Bơ cho Thứ Tư đến Chủ Nhật (gói G2), trên rig chính thức 22 xương.

Mỗi khoá: (giây, {điều khiển}). Điều khiển (xem rig.py):
  root (phải, lên, trước, ngẩng, quay, lăn) · hips/chest/head/scarf (ngẩng, quay, lăn) · earL/earR (ngẩng, quay, lăn)
  tail (nhấc1, lệch1, ... nhấc4, lệch4) · eye (độ mở 0..1) · FL/FR/BL/BR (dịch cổ chân phải, lên, trước, nghiêng bàn chân)
  props: bag3 (đung đưa), medal (hiện 0..1), drops (giọt nước 0..1), bag_on (túi chéo hiện 0..1)
Toạ độ là của cảnh phác thảo: gốc ở giữa bụng trên mặt đất, mèo nhìn về phía trước (+trước).
"""
import math

LEG_PHASE = {'FL': 0.0, 'FR': math.pi, 'BL': math.pi, 'BR': 0.0}   # như player.gd: chéo nhau


def gait(ph, stride, lift, narrow=0.0, rlift=None):
    """Chân trong một bước đi tại chỗ (máy chạy bộ): ph là pha 0..2π."""
    out = {}
    for k, off in LEG_PHASE.items():
        a = ph + off
        side = -1 if k[1] == 'L' else 1
        out[k] = (-side * narrow, max(math.cos(a), 0) * lift, math.sin(a) * stride, -max(math.cos(a), 0) * 25)
    return out


def merge(*ds):
    o = {}
    for d in ds:
        o.update(d)
    return o


def cyc(n, dur, f):
    """n khoá đều trong một vòng lặp dài dur giây; f(u) trả về dict điều khiển (u = 0..1)."""
    return [(dur * i / n, f(i / n)) for i in range(n + 1)]


S = math.sin
C = math.cos
TAU = 2 * math.pi

# ---------- tư thế dùng chung ----------
SIT = dict(root=(0, -.1, .02), hips=(34,), chest=(-14,), head=(-8,),
           FL=(.004, 0, -.02, 0), FR=(-.004, 0, -.02, 0), BL=(-.01, 0, .13, 0), BR=(.01, 0, .13, 0),
           tail=(-30, 20, -10, 35, 0, 35, 10, 30))
# Treo trên mép: gốc 0,5 m dưới mặt mép, mặt tường cách 0,27 m về trước (như _try_grab)
HANG = dict(root=(0, .17, .36, 72), head=(-55,), chest=(-8,),
            FL=(.0, .47, .18, -70), FR=(.0, .47, .145, -70),
            BL=(0, .06, .1, 30), BR=(0, .02, .02, 30), tail=(-40, 0, -10, 0, 0, 0, 10, 0), earL=(10,), earR=(10,))

ANIMS = {}


def A(name, **kw):
    kw['name'] = name
    ANIMS[name] = kw


# ======================= THỨ NĂM: leo chung cư =======================
A('bam_mep', day='T5', title='Bám mép', dur=1.2, loop=True, ctx='ledge', bag=True,
  modes=dict(BL='b', BR='b'),
  keys=cyc(4, 1.2, lambda u: merge(HANG, dict(
      BL=(0, .06 + .04 * S(u * TAU), .1 + .05 * S(u * TAU), 30), BR=(0, .06 - .04 * S(u * TAU), .1 - .05 * S(u * TAU), 30),
      tail=(-40, 18 * S(u * TAU), -10, 22 * S(u * TAU - .8), 0, 25 * S(u * TAU - 1.6), 10, 20 * S(u * TAU - 2.4)),
      root=(0, .17 + .006 * S(u * TAU * 2), .36, 72)))),
  shots=[0, .3, .6, .9], main=.3,
  notes='Hai chân trước móc qua mép (móng bám, bàn chân gập 70°), đầu ló ngang mặt mép nhìn lên, bụng áp tường. '
        'Hai chân sau đạp so le vào tường, đuôi rủ đung đưa giữ thăng bằng. Vòng lặp 1,2 s, người nhún nhẹ 2 lần.',
  game='climb == "hang": gốc mèo đứng yên 0,5 m dưới mép như code hiện tại; clip này thay dáng bám cũ.')

A('keo_len', day='T5', title='Kéo người lên', dur=.6, loop=False, ctx='ledge', bag=True,
  keys=[(0, merge(HANG, dict(BL=(0, .12, .13, -60), BR=(0, .08, .13, -60)))),
        (.18, merge(HANG, dict(root=(0, .3, .42, 60), head=(-30,), chest=(-25,),
                               FL=(0, .47, .18, -40), FR=(0, .47, .145, -40),
                               BL=(0, .22, .13, -70), BR=(0, .22, .13, -70), eye=(.8,)))),
        (.36, dict(root=(0, .43, .5, 28), head=(-10,), chest=(-20,), hips=(0,),
                   FL=(0, .47, .2, 0), FR=(0, .47, .16, 0), BL=(0, .42, .13, -40), BR=(0, .42, .13, -40),
                   tail=(-10, 0, 0, 0, 0, 0, 0, 0))),
        (.6, dict(root=(0, .52, .59, 0), FL=(0, .52, .59, 0), FR=(0, .52, .59, 0), BL=(0, .52, .59, 0), BR=(0, .52, .59, 0)))],
  shots=[0, .18, .36, .6], main=.36,
  notes='0,6 s như pull_time. 0–0,18 s: chân trước kéo, chân sau đạp tường. 0,18–0,36 s: ngực lên khỏi mép, '
        'khuỷu chống, chân sau leo lên mặt tường. 0,36–0,6 s: hông lên, chân sau bước lên mặt mép, đứng thẳng (0,52 m cao, 0,32 m vào trong).',
  game='Code đang tự dời gốc mèo (lên trước, rồi vào trong); khi ráp, trừ quãng dời đó khỏi root của clip.')

PIPE = dict(root=(0, .45, .32, 80), head=(-60, 0, 0), chest=(-6,),
            FL=(.01, .71, .09, 0), FR=(-.01, .66, .09, 0), BL=(.014, .26, .36, 100), BR=(-.014, .26, .36, 100),
            tail=(-50, 0, -10, 0, 0, 0, 0, 0))
A('leo_ong', day='T5', title='Leo ống nước', dur=.8, loop=True, ctx='pipe', bag=True,
  keys=cyc(8, .8, lambda u: merge(PIPE, dict(
      root=(0, .45 + .03 * S(u * TAU), .32, 80 - 3 * S(u * TAU)),
      FL=(.01, .71 + .05 * S(u * TAU), .09, 0), FR=(-.01, .68 - .05 * S(u * TAU), .09, 0),
      BL=(.014, .26 + .04 * S(u * TAU + 2), .36, 100), BR=(-.014, .26 + .04 * S(u * TAU + 2), .36, 100),
      tail=(-50, 12 * S(u * TAU), -10, 15 * S(u * TAU - 1), 0, 15 * S(u * TAU - 2), 0, 10 * S(u * TAU - 3))))),
  shots=[0, .2, .4, .6], main=.2,
  notes='Ôm ống (đường kính 10 cm) bằng cả bốn chân, bụng sát ống, đầu ngẩng nhìn lên. Chân trước với lên so le, '
        'bốn chân tụm lại ôm ống như mèo thật leo cột (Sang 23/10): bàn chân trước hai bên ống, chân sau co dưới bụng, hai bàn chân sau cùng đạp trên mặt ống, mũi chân hướng lên; chân sau đẩy cùng lúc, lệch chân trước nửa nhịp. 0,8 s mỗi nhịp ứng với pipe_speed 1,4 m/s; leo xuống phát ngược nhanh 1,6 lần.',
  game='climb == "pipe": gốc mèo cách tâm ống 0,24 m như code; tốc độ phát clip theo vận tốc leo.')

KICK0 = dict(root=(0, .25, 0, 40), chest=(-20,), head=(-20, 0, 0), tail=(-25, 40, 0, 30, 0, 20, 10, 10),
             FL=(0, .3, .05, 0), FR=(0, .3, .05, 0), BL=(0, .22, -.3, -80), BR=(0, .22, -.3, -80),
             earL=(-20,), earR=(-20,))
A('dap_tuong', day='T5', title='Đạp tường', dur=.36, loop=False, ctx='walls', bag=True,
  modes=dict(FL='b', FR='b'),
  keys=[(0, merge(KICK0, dict(root=(0, .3, -.06, 50), BL=(0, .26, -.26, -70), BR=(0, .26, -.26, -70),
                              FL=(0, .08, .06, 20), FR=(0, .08, .06, 20)))),
        (.08, merge(KICK0, dict(root=(0, .24, -.1, 55), chest=(-28,), BL=(0, .3, -.33, -85), BR=(0, .3, -.33, -85),
                                FL=(0, .12, -.04, 30), FR=(0, .12, -.04, 30), head=(-35,)))),
        (.18, merge(KICK0, dict(root=(0, .36, .1, 30), chest=(0,), BL=(0, .3, -.38, -90), BR=(0, .3, -.38, -90),
                                FL=(0, .04, .12, 0), FR=(0, .04, .12, 0), head=(-5,), tail=(10, 0, 0, 0, 0, 0, 0, 0)))),
        (.36, dict(root=(0, .5, .4, 10), hips=(0,), FL=(0, .55, .55, 0), FR=(0, .55, .5, 0), BL=(0, .52, .25, 30), BR=(0, .52, .25, 30),
                   tail=(30, 0, 10, 0, 0, 0, 0, 0)))],
  shots=[0, .08, .18, .36], main=.08,
  notes='Khe giữa hai nhà 1,2 m. Bơ đã quay lưng vào tường (code quay mèo ngay lúc đạp). 0–0,08 s: chạm tường, hai chân sau '
        'gập sát, thân nén. 0,08–0,18 s: duỗi mạnh hai chân sau, chân trước vươn tới. 0,18–0,36 s: bay, chân sau thu dần.',
  game='Phát lúc wall_kicked; code giữ velocity và rotation; visual.scale bóp 0,8/1,25 như cũ cộng thêm clip.')


# ======================= THỨ TƯ: mưa, sân thượng =======================
def bal(u, extra=None):
    """Đi thăng bằng trên ván 0,25 m: chân đặt sát đường giữa, bước ngắn, thân lắc nhẹ, đuôi lệch ngược để giữ."""
    ph = u * TAU
    d = dict(gait(ph, .045, .03, narrow=.045))
    d.update(root=(0, -.025 + .004 * C(2 * ph), 0, 0, 0, 4 * S(ph)), head=(-16, 0, -3 * S(ph)), chest=(-4,),
             tail=(8, -28 * S(ph), 0, -18 * S(ph - .6), 0, -12 * S(ph - 1.2), 6, -8 * S(ph - 1.8)), earL=(6,), earR=(6,))
    if extra:
        d.update(extra)
    return d


A('thang_bang', day='T4', title='Đi thăng bằng trên ván', dur=1.0, loop=True, ctx='plank', bag=True,
  keys=cyc(8, 1.0, bal), shots=[0, .25, .5, .75], main=.25,
  notes='Ván rộng 0,25 m (bằng mặt bờ rào hẻm 42). Bơ tự đi kiểu này trên mặt hẹp dưới 0,3 m. Bước ngắn 9 cm, bốn bàn chân '
        'đặt sát đường giữa ván, đầu cúi nhìn ván, thân lắc ±4°, đuôi chìa ngang lắc ngược chiều thân. Nhịp 1 s mỗi chu kỳ (chậm hơn đi thường).',
  game='Thay chu kỳ đi khi dưới chân là mặt hẹp < 0,3 m; tốc độ tối đa giảm theo DoKho.')

SLIP = dict(root=(.02, -.04, 0, 0, 0, -14), head=(-28, -15, 6), chest=(-6,),
            FL=(-.03, 0, .02, 0), FR=(.02, 0, .03, 0), BL=(.035, 0, 0, 0), BR=(.13, -.1, -.03, 40),
            tail=(10, -45, 5, -35, 0, -25, 10, -20), earL=(-10, 0, -25), earR=(-10, 0, 25), eye=(1.0,))
A('truot_chan', day='T4', title='Trượt chân (Thong thả)', dur=.6, loop=False, ctx='plank', bag=True,
  keys=[(0, bal(0)), (.12, SLIP),
        (.3, merge(SLIP, dict(root=(.01, -.03, 0, 0, 0, -6), BR=(.06, .07, 0, 0), tail=(10, -25, 0, -15, 0, -10, 6, -6)))),
        (.6, bal(0))],
  shots=[0, .12, .3, .6], main=.12,
  notes='Mặt ván ướt. 0–0,12 s: chân sau phải trượt khỏi mép ván, thân chao 14° về phía hụt, hai chân trước bấu chặt, đuôi quất '
        'ngược để kéo lại, mắt mở to, tai bạt ngang. 0,12–0,3 s: rút chân lên. 0,3–0,6 s: đứng vững lại. Không rơi (Thong thả).',
  game='Phát khi chạy nhanh trên ván ướt ở Thong thả; khựng 0,6 s, không mất bánh.')

A('roi_van', day='T4', title='Rơi khỏi ván (Thử thách)', dur=.9, loop=False, ctx='plank', bag=True, center=(.15, 0, -.15), scale=1.5,
  modes=dict(FL='b', FR='b', BL='b', BR='b'),
  keys=[(0, dict(root=(0, -.025, 0))),
        (.15, dict(root=(.03, -.05, 0, 0, 0, -22), head=(-25, -15, 8), FL=(-.03, 0, .02, 0), FR=(.03, .02, .05, 0),
                   BR=(.07, .04, 0, 40), tail=(10, -45, 5, -35, 0, -25, 10, -20), earL=(-10, 0, -25), earR=(-10, 0, 25))),
        (.35, dict(root=(.16, -.22, 0, 10, 0, -50), head=(10, -30, 20), chest=(8,), FL=(-.06, .12, .1, -30), FR=(-.02, .16, .08, -30),
                   BL=(.03, .05, 0, 0), BR=(.06, .05, -.02, 0), tail=(40, -20, 20, -10, 10, 0, 10, 0),
                   earL=(-25, 0, -30), earR=(-25, 0, 30), eye=(1.0,))),
        (.65, dict(root=(.3, -.5, 0, 0, 0, -15), head=(-10, -10, 5), FL=(-.02, -.03, .04, 30), FR=(.02, -.03, .04, 30),
                   BL=(-.02, -.03, -.02, 30), BR=(.02, -.03, -.02, 30), tail=(45, 0, 20, 0, 10, 0, 0, 0),
                   earL=(-20, 0, -20), earR=(-20, 0, 20))),
        (.9, dict(root=(.32, -.6, 0), head=(-5,), tail=(20, 0, 10, 0, 0, 0, 0, 0)))],
  shots=[.15, .35, .65, .9], main=.35,
  notes='Chỉ có ở Chế độ thử thách khi chạy nhanh trên ván. 0–0,15 s trượt như trên nhưng chao mạnh 22°; 0,15–0,35 s hai chân trước '
        'với bấu mép ván nhưng hụt; 0,35–0,65 s rơi, chân duỗi xuống, đuôi dựng lái; 0,9 s chạm mái dưới (0,6 m) và đứng lại.',
  game='Số liệu trượt để trong DoKho (Thử thách); phần rơi do vật lý, clip chỉ cho dáng.')


def shake(u):
    env = S(math.pi * min(u / .85, 1.0))
    ph = u * TAU * 5
    return dict(root=(0, -.01, 0, 0, 0, 4 * env * S(ph - 1.6)),
                head=(-5, 22 * env * S(ph), 35 * env * S(ph)), chest=(0, 0, 18 * env * S(ph - .8)),
                hips=(0, 0, -10 * env * S(ph - 1.6)), tail=(15, 30 * env * S(ph - 2.4), 0, 30 * env * S(ph - 3), 0, 25 * env * S(ph - 3.6), 0, 20 * env * S(ph - 4.2)),
                FL=(-.02, 0, .01, 0), FR=(.02, 0, .01, 0), BL=(-.02, 0, -.01, 0), BR=(.02, 0, -.01, 0),
                eye=(1 - .85 * env,), earL=(-15 * env, 0, -35 * env), earR=(-15 * env, 0, 35 * env),
                drops=(1.0 if .1 < u < .75 else 0.0,))


A('giu_nuoc', day='T4', title='Giũ nước', dur=.8, loop=False, ctx=None, bag=True, base=dict(drops=(0,)),
  keys=[(i * .8 / 20, shake(i / 20)) for i in range(21)], shots=[.08, .22, .34, .5], main=.22,
  notes='Sau mưa hoặc lội vũng. Sóng lắc đi từ đầu (±35°) xuống ngực (±18°) rồi hông (±10°) và đuôi, 5 nhịp trong 0,8 s, '
        'mắt nhắm tịt, tai bạt ngang, giọt nước văng ra. Bánh không ướt (Cô Ba bọc túi ni-lông).',
  game='Phát khi ra khỏi vùng mưa hoặc vũng nước; chỉ là dáng, không khựng (người chơi bấm đi là ngắt).')


# ======================= THỨ SÁU: đám giỗ, tiệm xe =======================
SIT_MEO = merge(SIT, dict(head=(22, 0, -6), chest=(-10,), eye=(.7,), earL=(8,), earR=(8,),
                          tail=(-30, 20, -10, 35, 10, 40, 30, 30)))
A('ngoi_goi', day='T6', title='Ngồi gọi "meo"', dur=1.4, loop=False, ctx=None, bag=True,
  keys=[(0, {}), (.35, SIT), (.6, SIT_MEO), (.95, SIT_MEO), (1.15, merge(SIT, dict(head=(-2, 0, 8), eye=(.9,)))), (1.4, SIT)],
  shots=[0, .35, .7, 1.2], main=.7,
  notes='Phím Q (gọi). 0–0,35 s ngồi xuống; 0,35–0,6 s ngẩng cổ, mắt híp, tai hướng tới trước, chóp đuôi vẫy (cùng lúc phát tiếng "meo"); '
        '1,15 s nghiêng đầu chờ người ra. Bơ chưa có xương hàm nên miệng không mở; tiếng kêu đi kèm bong bóng "meo".',
  game='Phát khi bấm Q trước cổng; Bà Sáu, Anh Hùng nghe "meo" thì ra (lần 1, lần 2).')


def carry(u):
    ph = u * TAU
    d = dict(gait(ph, .07, .045))
    d.update(root=(0, .008 * C(2 * ph), 0, 0, 0, 0), head=(18, 0, 0), chest=(4,),
             tail=(25, 8 * S(ph), 10, 10 * S(ph - .7), 10, 10 * S(ph - 1.4), 15, 10 * S(ph - 2.1)),
             bag3=(9 * S(ph - .5), 1))
    return d


A('ngam_tui', day='T6', title='Ngậm túi 3 ổ', dur=.8, loop=True, ctx=None, bag=True, bag3=True, base=dict(bag3=(0, 1)),
  keys=cyc(8, .8, carry), shots=[0, .2, .4, .6], main=.2, views=('q34', 'side', 'front', 'back'),
  notes='Túi vải nhỏ 3 ổ (model mới bên dưới), Bơ ngậm đỉnh quai, túi đung đưa dưới cằm ±9° theo bước chân như túi trứng Thứ Ba. '
        'Cằm ngẩng 18° để túi treo trước ngực, đáy túi cách đất 17 cm. Vẫn đeo túi chéo. Nhịp đi 0,8 s như đi thường.',
  game='Đám giỗ Thong thả: 6 ổ, 2 chuyến; túi gắn xương head ở điểm miệng như ổ bánh giao Thứ Hai.')


# ======================= THỨ BẢY: dạo phố =======================
WAVE = lambda u: merge(SIT, dict(head=(4, 12, 12), eye=(1.0,), earL=(6,), earR=(6,),
                                 FR=(.02 + .035 * S(u * TAU * 2), .2, .14, -50 + 30 * S(u * TAU * 2)), chest=(-10, 0, -4),
                                 tail=(-30, 20, -10, 35, 0, 35, 25, 30 + 15 * S(u * TAU * 2))))
A('chup_vay', day='T7', title='Dáng chụp ảnh 1: vẫy chào', dur=1.0, loop=True, ctx=None, bag=False, modes=dict(FR='b'),
  keys=cyc(8, 1.0, WAVE), shots=[0, .125, .25, .375], main=.125,
  notes='Ngồi, chân trước phải giơ cao ngang má vẫy 2 lần mỗi giây, đầu nghiêng 12° về phía máy ảnh, mắt mở tròn vui. '
        'Thứ Bảy không đeo túi giao. Dùng khi chụp ảnh chung với người dân (G9) và dán vào Sổ hàng xóm.',
  game='Chế độ chụp ảnh Thứ Bảy: chọn 1 trong 3 dáng; giữ dáng lặp cho tới khi bấm chụp.')

LOAF = dict(root=(0, -.135, 0), chest=(-4,), head=(4, 22, 18), eye=(.75,),
            FL=(-.01, .015, -.07, 75), FR=(.01, .015, -.07, 75), BL=(-.025, 0, .1, 0), BR=(.025, 0, .1, 0),
            tail=(-25, 40, -5, 40, 0, 35, 5, 30), earL=(4,), earR=(4,))
A('chup_nam', day='T7', title='Dáng chụp ảnh 2: nằm ổ bánh mì', dur=1.6, loop=True, ctx=None, bag=False,
  keys=[(0, LOAF), (.8, merge(LOAF, dict(head=(4, 14, 8), tail=(-25, 40, -5, 40, 0, 35, 25, 40)))), (1.6, LOAF)],
  shots=[0, .8], main=0,
  notes='Nằm xếp chân kiểu "ổ bánh mì": hai chân trước gập giấu dưới ngực, hai chân sau xếp dưới bụng, đuôi ôm bên hông. '
        'Đầu nghiêng 18° quay về máy ảnh, mắt lim dim. Lặp chậm 1,6 s: đầu lắc nhẹ, chóp đuôi vẫy.',
  game='Như dáng 1.')

STAND = dict(root=(0, -.01, -.02), hips=(68,), chest=(-8,), head=(-48, 0, 8), eye=(1.0,),
             FL=(-.03, .1, .06, -40), FR=(.03, .1, .06, -40), BL=(-.01, 0, .02, 0), BR=(.01, 0, .02, 0),
             tail=(-55, 0, -10, 15, 10, 25, 30, 20), earL=(5,), earR=(5,))
A('chup_dung', day='T7', title='Dáng chụp ảnh 3: đứng hai chân "ta-da"', dur=1.2, loop=True, ctx=None, bag=False,
  modes=dict(FL='b', FR='b'),
  keys=[(0, STAND), (.6, merge(STAND, dict(FL=(-.06, .14, .04, -60), FR=(.06, .14, .04, -60), head=(-48, 0, -6), root=(0, .005, -.02)))), (1.2, STAND)],
  shots=[0, .6], main=.6,
  notes='Đứng thẳng trên hai chân sau, đuôi chống đất làm chân thứ ba, hai tay dang ra "ta-da" rồi khép lại (1,2 s), đầu nghiêng '
        'theo nhịp. Cao 0,72 m như dáng giao cao Thứ Hai.',
  game='Như dáng 1.')

LIE = dict(root=(.235, .12, 0, 0, 0, 88), head=(12, -8, 0), chest=(4,), eye=(.1,),
           FL=(-.03, -.02, .1, 30), FR=(-.01, .0, .13, 30), BL=(-.03, -.02, -.1, 20), BR=(-.01, 0, -.13, 20),
           tail=(0, -10, 0, -12, 0, -10, 0, -8), earL=(-5,), earR=(-5,))
A('phoi_nang', day='T7', title='Phơi nắng', dur=2.4, loop=True, ctx=None, bag=False,
  modes=dict(FL='b', FR='b', BL='b', BR='b'),
  keys=[(0, LIE), (1.2, merge(LIE, dict(chest=(7,), FL=(-.03, -.03, .14, 45), FR=(-.01, -.01, .17, 45),
                                       tail=(0, -10, 0, -12, 0, -10, 15, 10)))), (2.4, LIE)],
  shots=[0, 1.2], main=1.2, views=('q34', 'side', 'top', 'back'), strip_view='top',
  notes='Nằm nghiêng phơi bụng trên nền gạch nắng, chân duỗi, mắt nhắm. Lặp 2,4 s: thở (ngực phồng 3°), giữa chừng vươn hai '
        'chân trước ra rồi thu lại, chóp đuôi búng một cái.',
  game='Đứng yên lâu ở chỗ có nắng ngày Thứ Bảy (thay động tác chờ); chạm phím nào cũng dậy.')

CURL = dict(root=(0, -.14, 0), eye=(0.0,), chest=(-10, 18, 0), head=(-24, 32, 10),
            FL=(-.01, .015, -.07, 75), FR=(.01, .015, -.07, 75), BL=(-.025, 0, .1, 0), BR=(.025, 0, .1, 0),
            tail=(-25, -70, -5, -60, 0, -55, 0, -45), earL=(-8, 0, -10), earR=(-8, 0, 10))
A('ngu_cuon', day='T7', title='Ngủ cuộn tròn', dur=3.0, loop=True, ctx=None, bag=False,
  keys=[(0, CURL), (1.5, merge(CURL, dict(chest=(-7, 18, 0), root=(0, -.136, 0)))), (3.0, CURL)],
  shots=[0, 1.5], main=0, views=('q34', 'top', 'side', 'back'), strip_view='q34',
  notes='Nằm xếp chân, thân cong nhẹ sang một bên, đầu cúi gối lên hai chân trước, đuôi vòng ôm quanh người lên tới chân trước. Mắt nhắm. Thở chậm 3 s một nhịp (lưng phồng xẹp). Dùng ở cuối Thứ Bảy '
        '(Bơ ngủ ở tiệm sau một ngày dạo phố) và khi đứng yên rất lâu.',
  game='Cảnh cuối Thứ Bảy; động tác chờ lâu (> 30 s).')


# ======================= CHỦ NHẬT: Hội mèo =======================
MEDAL_BOW = merge(SIT, dict(head=(-38,), eye=(.8,), earL=(-8,), earR=(-8,)))
A('nhan_huy_chuong', day='CN', title='Nhận huy chương', dur=1.8, loop=False, ctx=None, bag=False, base=dict(medal=(0,)),
  keys=[(0, SIT), (.4, MEDAL_BOW), (.75, merge(MEDAL_BOW, dict(medal=(0,)))), (.85, merge(MEDAL_BOW, dict(medal=(1,)))),
        (1.25, merge(SIT, dict(head=(24, 0, 0), chest=(-4,), eye=(1.0,), medal=(1,), tail=(-10, 0, 25, 0, 25, 0, 30, 10)))),
        (1.8, merge(SIT, dict(head=(20, 0, 6), chest=(-4,), eye=(1.0,), medal=(1,), tail=(-10, 0, 25, 0, 25, 0, 30, -10))))],
  shots=[0, .5, 1.0, 1.5], main=1.5,
  notes='Ngồi thẳng, cúi đầu 38° để Bà Mướp đeo huy chương (0,4–0,85 s), rồi ngẩng cao, ưỡn ngực, đuôi dựng vẫy chóp. '
        'Huy chương ở đây là bản tạm để dựng dáng; mẫu 3 hạng chính thức nằm trong gói G11.',
  game='Lễ trao giải cuối Hội mèo; mèo trong hội (G10) dùng chung clip vì cùng rig.')


def hand(u, give=True):
    """Chuyền túi: mèo chạy chậm lại, ngẩng đầu, chạm mũi rồi nhả/ngậm quai."""
    ph = u * TAU * 1.5
    k = min(u / .55, 1.0)
    step = 1 - k
    d = dict(gait(ph, .07 * step, .045 * step))
    d.update(root=(0, 0, .04 * k, 0, 0, 0), head=(10 + 22 * k, 0, 0), chest=(4 * k,), eye=(1.0,),
             tail=(25, 0, 15, 0, 15, 0, 20, 0))
    hold = (u < .75) if give else (u > .7)
    d['bag3'] = (6 * S(ph) * step, 1.0 if hold else 0.0)
    return d


A('dua_tui', day='CN', strip_view='side', center=(0, -.37, .3), scale=1.5, views=('side', 'q34r', 'q34l', 'top'), title='Chuyền túi: đưa', dur=1.0, loop=False, ctx=None, bag=False, bag3=True, partner='nhan_tui',
  base=dict(bag3=(0, 1)), keys=[(i / 10, hand(i / 10, True)) for i in range(11)], shots=[0, .5, .7, .9], main=.7,
  notes='Đua tiếp sức: Bơ chạy chậm lại (0–0,55 s), ngẩng đầu đưa quai túi ra trước, mũi chạm mũi mèo nhận. Mèo kia ngậm được '
        'quai (0,7 s) thì Bơ mới nhả (0,75 s), không đặt xuống đất. Mèo nhận trong ảnh là Xiêm, cùng rig.',
  game='Trò chuyền túi Chủ Nhật; đồng bộ với clip "nhận" của mèo kia theo thời điểm chạm mũi.')

A('nhan_tui', day='CN', strip_view='side', center=(0, -.37, .3), scale=1.5, views=('side', 'q34r', 'q34l', 'top'), title='Chuyền túi: nhận', dur=1.0, loop=False, ctx=None, bag=False, bag3=True, partner='dua_tui',
  base=dict(bag3=(0, 0)), keys=[(i / 10, hand(i / 10, False)) for i in range(11)], shots=[0, .5, .7, .9], main=.7,
  notes='Bơ đứng chờ ở vạch, ngẩng đầu đón; chạm mũi thì ngậm quai (0,7 s), mèo đưa nhả ra, Bơ quay người chạy tiếp. '
        'Mèo đưa trong ảnh là Xiêm.',
  game='Như trên; sau 1 s chuyển sang chạy.')


# ======================= A3: KHOẢNH KHẮC GIAO BÁNH (mọi ngày giao) =======================
# Sau giao_xong Bơ đang đứng 4 chân; mọi clip A3 bắt đầu từ dáng đứng ({}), ngồi xuống trong 0,25 s.
TAIL_UP = (60, 0, 15, 0, 10, 0, 60, 0)            # đuôi dựng, chóp móc như dấu hỏi: "chào thân thiện"
KHEN = merge(SIT, dict(head=(12, 18, 14), chest=(-10, 6, 0), eye=(1.0,), earL=(8,), earR=(8,), tail=TAIL_UP))
A('cho_khen', day='A3', title='Ngồi chờ khen', dur=1.2, loop=False, ctx=None, bag=True,
  keys=[(0, {}), (.25, SIT), (.45, KHEN), (.7, merge(KHEN, dict(eye=(.15,)))), (.9, merge(KHEN, dict(eye=(1.0,), tail=(60, 0, 15, -12, 10, -10, 60, -10)))),
        (1.2, merge(KHEN, dict(tail=(60, 0, 15, 12, 10, 10, 60, 10))))],
  shots=[0, .45, .7, 1.1], main=.45,
  notes='Clip chung, chạy ở mọi lần giao. Ngồi xuống (0,25 s), đuôi dựng thẳng, chóp móc như dấu hỏi (kiểu mèo chào người quen), '
        'đầu nghiêng 14° về phía khách, rồi chớp mắt chậm một cái (0,6–0,8 s: kiểu mèo nói "thương"), chóp đuôi vẫy. Túi đeo hông vẫn đeo.',
  game='Phát ngay sau giao_xong; clip của khách chạy cùng lúc. Đồng xu boa rơi vào túi đeo hông ở 0,6 s.')

DUI = merge(SIT, dict(head=(30, 0, 0), chest=(-4,), eye=(0.0,), earL=(-12, 0, -10), earR=(-12, 0, 10), tail=TAIL_UP))
A('dui_dau', day='A3', title='Dụi đầu vào tay', dur=1.4, loop=False, ctx=None, bag=True,
  keys=[(0, {}), (.25, SIT), (.45, DUI), (.75, merge(DUI, dict(head=(34, 8, -12)))), (1.05, merge(DUI, dict(head=(34, -8, 12)))),
        (1.4, merge(DUI, dict(head=(26, 0, 0), eye=(.6,))))],
  shots=[.25, .45, .75, 1.05], main=.75,
  notes='Khi khách xoa đầu (Cô Ba, Bà Sáu): ngồi thẳng, ngửa đầu lên đón bàn tay, mắt nhắm, tai cụp nhẹ ra sau, '
        'đầu dụi qua lại hai nhịp theo tay. Đuôi dựng, chóp móc. Có tiếng rừ rừ nhỏ.',
  game='Thay cho_khen khi khách có clip xoa_dau; bàn tay khách chạm đầu Bơ ở 0,45 s.')

TAY = merge(SIT, dict(head=(10, 0, 0), chest=(-16, 0, -4), eye=(1.0,), earL=(10,), earR=(10,), tail=TAIL_UP,
                      FR=(.0, .2, .2, -70)))
A('dap_tay', day='A3', title='Đập tay', dur=1.0, loop=False, ctx=None, bag=True, modes=dict(FR='b'),
  keys=[(0, {}), (.25, SIT), (.45, merge(TAY, dict(FR=(.0, .16, .14, -50)))), (.55, TAY), (.65, merge(TAY, dict(FR=(.0, .19, .17, -60), eye=(.6,)))),
        (1.0, KHEN)],
  shots=[.25, .45, .55, 1.0], main=.55,
  notes='Với Anh Hùng, Chú Năm: ngồi, giơ chân trước phải ra trước cao 0,2 m chạm nắm tay khách ở 0,55 s (lùi lại một chút như bị đẩy), '
        'rồi thu chân về, nghiêng đầu như cho_khen.',
  game='Thay cho_khen khi khách có clip dap_tay; hai clip phải chạm đúng 0,55 s.')

LOI = merge(SIT, dict(head=(-22, 0, 8), chest=(-8,), eye=(.45,), earL=(-25, -30, -35), earR=(-25, 30, 35),
                      tail=(-30, 30, -10, 40, 0, 40, 10, 35)))
A('xin_loi', day='A3', title='Xin lỗi vì trễ', dur=1.0, loop=False, ctx=None, bag=True,
  keys=[(0, {}), (.25, SIT), (.5, LOI), (.8, merge(LOI, dict(head=(-14, 0, 12), eye=(.8,)))), (1.0, merge(LOI, dict(head=(-6, 0, 10), eye=(.9,))))],
  shots=[0, .25, .5, .9], main=.5,
  notes='Giao trễ: ngồi, cúi đầu, tai xoè ngang (tai "máy bay" nhẹ), mắt híp, đuôi quấn quanh chân. Không buồn bã quá: '
        'cuối clip ngẩng lên nhìn khách. Khách vẫn cười (giao trễ không bị mắng).',
  game='Thay cho_khen khi late = true.')

# ======================= PHIM MỞ ĐẦU VÀ KẾT TUẦN (C1, Sang duyệt 23/10) =======================
# Động tác lặp để cảnh phim giữ dáng bao lâu cũng được; vào/ra dáng do game hoà (player.gd play_clip).
SNIFF = dict(head=(14, 8, 0), chest=(12,), earL=(14,), earR=(14,), tail=(40, 0, 25, 0, 15, 0, -20, 0), eye=(.75,), FL=(0, 0, .03, 0))
A('ngui_mui', day='C1', title='Ngửi mùi bánh', dur=2.0, loop=True, ctx=None, bag=False,
  keys=cyc(12, 2.0, lambda u: merge(SNIFF, dict(head=(14 + 4 * max(S(u * TAU * 3), 0), 8 + 3 * S(u * TAU), 0),
                                                tail=(40, 0, 25, 0, 15, 4 * S(u * TAU), -20, 8 * S(u * TAU))))),
  shots=[0, .25], main=.25,
  notes='Đứng, ngẩng mũi hít ba nhịp mùi bánh từ cửa lò, tai dựng hướng trước, đuôi dựng cong móc câu.',
  game='Phim mở đầu M2.')

SIT_YEN = merge(SIT, dict(head=(-2,), eye=(1.0,), tail=(-30, 20, -10, 35, 0, 35, 10, 30)))
A('ngoi_yen', day='C1', title='Ngồi ngay ngắn', dur=3.0, loop=True, ctx=None, bag=False,
  keys=cyc(12, 3.0, lambda u: merge(SIT_YEN, dict(chest=(-14 + 1.5 * S(u * TAU),), head=(-2 + 2 * S(u * TAU - .6), 4 * S(u * TAU * .5 * 2), 0),
                                                  tail=(-30, 20, -10, 35, 0, 35, 10 + 12 * S(u * TAU * 2), 30)))),
  shots=[0, 1.5], main=0,
  notes='Ngồi thẳng chờ, thở chậm, chóp đuôi búng nhẹ. Dáng nền cho các cảnh phim.',
  game='Phim mở đầu M3, M6; kết tuần K1, K5, K7.')

NGUA = merge(SIT, dict(head=(2, 0, 0), chest=(-10,), eye=(.3,), earL=(-12,), earR=(-12,), tail=(-30, 20, -10, 35, 0, 35, 10, 30)))
A('ngua_co', day='C1', title='Ngẩng cổ chờ quàng khăn', dur=1.6, loop=True, ctx=None, bag=False,
  keys=cyc(8, 1.6, lambda u: merge(NGUA, dict(head=(2 + 2 * S(u * TAU), 0, 3 * S(u * TAU * 2)), chest=(-10 + 1.5 * S(u * TAU * 2),)))),
  shots=[0, .4], main=0,
  notes='Ngồi, ngẩng cằm cho Cô Ba quàng khăn, mắt híp cười, tai hơi xuôi vì thích, rừ rừ (ngực rung nhẹ).',
  game='Phim mở đầu M4.')

NGAM = merge(SIT, dict(head=(-30, 16, 10), chest=(-4,), eye=(.95,), earL=(6,), earR=(6,), tail=(50, 0, 30, 10, 20, 0, -35, 0)))
A('ngam_khan', day='C1', title='Ngắm khăn mới', dur=2.2, loop=True, ctx=None, bag=False,
  keys=cyc(11, 2.2, lambda u: merge(NGAM, dict(head=(-30 + 4 * S(u * TAU), 16 * C(u * TAU), 10 * C(u * TAU)),
                                               tail=(50, 0, 30, 10, 20, 0, -35, 15 * S(u * TAU * 2))))),
  shots=[0, 1.1], main=0,
  notes='Cúi nhìn khăn trên ngực, nghiêng đầu sang trái rồi sang phải, ưỡn ngực; đuôi dựng thẳng, chóp cong vẫy (vui).',
  game='Phim mở đầu M5.')

STRETCH = dict(root=(0, -.03, .02, -16, 0, 0), chest=(-6,), head=(24,), FL=(0, 0, .22, -10), FR=(0, 0, .22, -10),
               BL=(0, 0, -.03, 0), BR=(0, 0, -.03, 0), tail=(45, 0, 20, 0, 10, 0, 0, 0), eye=(0.,), earL=(-14,), earR=(-14,))
A('vuon_vai', day='C1', title='Vươn vai ngáp', dur=2.4, loop=False, ctx=None, bag=False,
  keys=[(0, {}), (.6, STRETCH), (1.5, merge(STRETCH, dict(head=(30,), FL=(0, 0, .24, -12), FR=(0, 0, .24, -12)))),
        (1.9, dict(head=(6, 0, 10), eye=(.6,))), (2.1, dict(head=(6, 0, -10), eye=(.8,))), (2.4, {})],
  shots=[0, .6, 1.5, 2.0], main=1.5,
  notes='Duỗi hai chân trước, hạ ngực, mông cao, ngẩng ngáp (mắt nhắm), rồi rùng mình đứng dậy.',
  game='Kết tuần K8: sáng Thứ Hai tuần mới.')
