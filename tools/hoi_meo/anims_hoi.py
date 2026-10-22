"""Động tác chung của mèo trong Hội mèo (G10) trên rig chính thức 22 xương (cùng tên xương với Bơ và 19 giống).
Cùng cách viết với tools/dong_tac_bo/anims.py (gói G2): mỗi khoá (giây, {điều khiển}); điều khiển xem rig.py.
Dùng lại nguyên các clip G2 đã duyệt: dua_tui, nhan_tui (chuyền túi), nhan_huy_chuong, chup_vay, chup_nam, chup_dung (tạo dáng).
Mỗi clip có 'who': mèo dùng để chụp ảnh phác thảo."""
import sys
sys.path.insert(0, '/home/user/meo-giao-banh-mi/tools/dong_tac_bo')
from anims import gait, merge, cyc, SIT, S, C, TAU   # noqa: E402

ANIMS = {}


def A(name, **kw):
    kw['name'] = name
    ANIMS[name] = kw


def blink(u, at=.5, w=.05, lo=.1, hi=1.0):
    d = abs(u - at)
    return (lo if d < w else hi,)


# ============ khán giả ============
def watch(u):
    return merge(SIT, dict(head=(2 + 3 * S(u * TAU * 2), 22 * S(u * TAU), 4 * S(u * TAU)), eye=blink(u, .55),
                           earL=(4 + 6 * S(u * TAU + 1),), earR=(4 + 6 * S(u * TAU),),
                           chest=(-14 + 1.5 * S(u * TAU * 2),),
                           tail=(-30, 20, -10, 35, 0, 35, 10, 30 + 25 * S(u * TAU * 2))))
A('ngoi_xem', title='Ngồi xem', dur=3.0, loop=True, who='tuyet',
  keys=[(3.0 * i / 12, watch(i / 12)) for i in range(13)], shots=[0, .75, 1.65, 2.25], main=.75,
  notes='Ngồi ngay ngắn quanh sân khấu, đầu quay theo trò đang thi (±22°), tai xoay, chóp đuôi búng 2 lần mỗi vòng, chớp mắt một cái giữa vòng. '
        'Thở nhẹ (ngực ±1,5°). Vòng 3 s; mỗi mèo lệch pha ngẫu nhiên để đám đông không lắc cùng lúc.',
  game='Mặc định của mèo không thi; code cho đầu nhìn theo Bơ bằng look_at xương head (cộng thêm vào clip).')


def cheer(u):
    a = S(u * TAU)
    return merge(SIT, dict(root=(0, -.1 + .03 * max(a, 0), .02), chest=(-20 - 5 * max(a, 0),), head=(14, 0, 8 * a), eye=(1.0,),
                           FL=(-.02, .13 + .05 * max(a, 0), .08, -22), FR=(.02, .13 + .05 * max(-a, 0) + .02, .08, -22),
                           earL=(12,), earR=(12,),
                           tail=(45, 0, 10, 20 * a, 10, -25 * a, 15, 25 * a)))
A('reo', title='Reo, vẫy đuôi', dur=.8, loop=True, who='gung', modes=dict(FL='b', FR='b'),
  keys=cyc(8, .8, cheer), shots=[0, .2, .4, .6], main=.2,
  notes='Ngồi nhổm, hai chân trước giơ lên vẫy so le, người nảy nhẹ 3 cm, đầu lắc theo nhịp, tai dựng, đuôi dựng cao vẫy chữ S. '
        'Nhịp 0,8 s. Lạc dùng khi bất kỳ ai về đích hoặc khi chính nó về chót (vẫn reo to nhất); ảnh chụp trên Gừng.',
  game='Phát 2–3 vòng khi một trò kết thúc hoặc khi Bơ làm được việc khó; xong quay về ngoi_xem. Lạc chân ngắn (Munchkin, chân 62%): khi phát các dáng ngồi, nhân phần hạ gốc (root) với hệ số chân của giống để thân không lún xuống đất.')


def wag(u):
    a = S(u * TAU * 2)
    return dict(head=(6, 8 * S(u * TAU), 10 * S(u * TAU)), eye=(1.0,), earL=(8,), earR=(8,), chest=(0, 0, 3 * a),
                tail=(60, 18 * a, 8, 24 * S(u * TAU * 2 - .8), 6, 28 * S(u * TAU * 2 - 1.6), 10, 26 * S(u * TAU * 2 - 2.4)))
A('vay_duoi', title='Đứng vẫy đuôi', dur=1.0, loop=True, who='sua',
  keys=cyc(8, 1.0, wag), shots=[0, .125, .25, .375], main=.125,
  notes='Đứng bốn chân, đuôi dựng thẳng lên rồi vẫy sóng từ gốc ra chóp (2 lần/giây), đầu nghiêng qua lại. Chào Bơ khi gặp, '
        'đứng chờ ở vạch tiếp sức.',
  game='Mèo NPC đứng yên gần Bơ (dưới 2 m) hoặc chờ lượt.')


# ============ thi đấu ============
def run(u):
    ph = u * TAU
    d = dict(gait(ph, .12, .075))
    d.update(root=(0, .012 * abs(S(ph)), 0, -4 + 3 * S(ph * 2)), chest=(-6 * C(ph * 2),), head=(-6 + 3 * C(ph * 2),), eye=(1.0,),
             earL=(-22,), earR=(-22,), tail=(-6, 6 * S(ph), 4, 8 * S(ph - .8), 4, 10 * S(ph - 1.6), 6, 10 * S(ph - 2.4)))
    return d
A('chay_dua', title='Chạy đua', dur=.42, loop=True, who='mit',
  keys=cyc(8, .42, run), shots=[0, .105, .21, .315], main=.105,
  notes='Chạy nhanh tại chỗ (máy chạy bộ): bước dài 24 cm, nhấc chân 7,5 cm, nhịp 0,42 s ứng với khoảng 5 m/s. Tai cụp ra sau, '
        'đuôi duỗi thẳng ra sau giữ thăng bằng, chỉ lắc nhẹ. Mít và Bột dùng khi đua mái nhà; đội tiếp sức chạy cùng clip.',
  game='Tốc độ phát = vận tốc / 5 m/s; Thong thả đối thủ chạy 85% (race_rival_mult) nên clip chậm theo.')

GROUND = dict(FL=(0, 0, 0, 0), FR=(0, 0, 0, 0), BL=(0, 0, 0, 0), BR=(0, 0, 0, 0))
A('nhay', title='Nhảy lên thùng', dur=.9, loop=False, who='bot', center=(0, -.17, .45), scale=1.6, modes=dict(FL='b', FR='b', BL='b', BR='b'),
  keys=[(0, dict()),
        (.2, dict(root=(0, -.05, -.01, -6), head=(14,), chest=(6,), earL=(-10,), earR=(-10,),
                  FL=(0, .05, 0, 0), FR=(0, .05, 0, 0), BL=(0, .045, .01, 0), BR=(0, .045, .01, 0), tail=(-25, 0, -5, 0, 0, 0, 5, 0))),
        (.32, dict(root=(0, .1, .07, 28), head=(-8,), chest=(-10,), FL=(0, .07, .07, -30), FR=(0, .07, .05, -30),
                   BL=(0, -.07, -.09, -55), BR=(0, -.07, -.08, -55), tail=(-30, 0, -10, 0, -5, 0, 0, 0))),
        (.5, dict(root=(0, .4, .18, 0), head=(-4,), FL=(0, .09, .03, -20), FR=(0, .09, .02, -20),
                  BL=(0, .07, -.04, -20), BR=(0, .07, -.04, -20), tail=(10, 0, 10, 0, 5, 0, 5, 0))),
        (.7, dict(root=(0, .14, .3, -16), head=(10,), FL=(0, -.02, .06, 10), FR=(0, -.02, .05, 10),
                  BL=(0, .07, -.02, -10), BR=(0, .07, -.02, -10), tail=(25, 0, 10, 0, 5, 0, 0, 0))),
        (.8, dict(root=(0, -.035, .34, 0), chest=(4,), FL=(0, .035, 0, 0), FR=(0, .035, 0, 0), BL=(0, .035, 0, 0), BR=(0, .035, 0, 0),
                  tail=(5, 0, 5, 0, 0, 0, 0, 0))),
        (.9, dict(root=(0, 0, .34, 0)))],
  shots=[.2, .32, .5, .8], main=.5,
  notes='Nhún (0,2 s), bật hai chân sau (0,32 s), đỉnh cao 0,4 m bằng một tầng thùng (0,5 s), duỗi chân trước đón (0,7 s), đáp nhún '
        '(0,8 s), đứng dậy cách chỗ cũ 34 cm. Đáp không vững thì nối sang clip "chao" của Bơ (trượt chân G2) rồi rớt.',
  game='Thùng thi nhảy G11 cao 0,4 m mỗi tầng; code dời gốc theo đường nhảy, trừ phần dời của root trong clip.')


HIDE = dict(root=(0, -.095, 0), chest=(-3,), head=(-6,), eye=(.85,), earL=(-38, 0, -25), earR=(-38, 0, 25),
            FL=(-.006, 0, -.03, 20), FR=(.006, 0, -.03, 20), BL=(-.012, 0, .08, 0), BR=(.012, 0, .08, 0),
            tail=(-25, 45, -5, 40, 0, 35, 0, 25))
A('tron', title='Trốn (nằm rạp)', dur=2.0, loop=True, who='mun',
  keys=[(0, HIDE), (1.0, merge(HIDE, dict(chest=(-1.5,), tail=(-25, 45, -5, 40, 0, 35, 0, 45)))), (2.0, HIDE)],
  shots=[0, 1.0], main=0,
  notes='Nằm rạp sát đất sau thùng, hẻm, chậu cây; tai ép ra sau, đuôi quấn sát hông, mắt mở hé. Thở rất chậm, chóp đuôi giật một cái mỗi 2 s '
        '(chỗ người chơi để ý thấy). Chuông cổ của Mun leng keng nhỏ mỗi lần đuôi giật.',
  game='Trò trốn tìm: 5 mèo nằm ở 5 chỗ; Thong thả sau 30 s chuông kêu to hơn (hide_hint_after).')

A('lo_dau', title='Ló đầu nhìn', dur=1.6, loop=False, who='mun',
  keys=[(0, HIDE),
        (.35, merge(HIDE, dict(root=(0, -.06, 0), head=(18, 0, 0), chest=(-12,), earL=(10,), earR=(10,), eye=(1.0,)))),
        (.75, merge(HIDE, dict(root=(0, -.055, 0), head=(16, 38, 6), chest=(-12, 10, 0), earL=(14,), earR=(6,), eye=(1.0,)))),
        (1.15, merge(HIDE, dict(root=(0, -.055, 0), head=(16, -38, -6), chest=(-12, -10, 0), earL=(6,), earR=(14,), eye=(1.0,)))),
        (1.6, HIDE)],
  shots=[0, .35, .75, 1.15], main=.75,
  notes='Từ dáng trốn, nhổm ngực, ngẩng đầu ló khỏi chỗ nấp, nhìn trái rồi phải, rồi rụt xuống. Phát ngẫu nhiên 6–10 s một lần khi Bơ '
        'ở xa trên 4 m. Bơ chạy gần thì mèo chạy sang chỗ khác (Thử thách) bằng clip chay_dua.',
  game='Khi Bơ rón rén tới dưới 1,2 m thì bắt được: phát reo ngắn rồi đi về sân khấu.')


# ============ chấm điểm, thi trang phục ============
def board(u):
    up = min(u / .2, 1.0)
    sh = S(u * TAU * 3) * (u > .2)
    return merge(SIT, dict(chest=(-18 - 6 * up,), head=(6 + 4 * up, -8, 6 * sh), eye=(1.0,),
                           FR=(.035, .1 + .2 * up, .1 + .04 * up, -70 * up), earL=(8,), earR=(8,),
                           tail=(-30, 20, -10, 35, 0, 35, 10, 30 + 15 * sh)))
A('gio_bang', title='Giơ bảng chấm điểm', dur=1.5, loop=False, who='sua', modes=dict(FR='b'), props=('bang',),
  keys=[(1.5 * i / 10, board(i / 10)) for i in range(11)], shots=[0, .3, .75, 1.2], main=.75,
  notes='Ngồi, chân trước phải giơ cao bảng điểm 1–5 lên trên đầu (0,3 s), lắc bảng nhẹ 3 lần cho khán giả thấy, đầu nghiêng. '
        'Bảng trong ảnh là khối tạm màu xám; bảng thật (số 1–5) thuộc gói G11, gắn xương paw_FR.',
  game='Thi trang phục: 4 mèo chấm (Mít, Bột, Tuyết, Gừng) giơ bảng lần lượt cách nhau 0,4 s.')

POSE = merge(SIT, dict(head=(18, 26, 12), eye=(.62,), chest=(-16, 0, -3), earL=(6,), earR=(6,),
                       FL=(-.012, .06, .06, 35), tail=(-30, -55, -10, -50, 0, -40, 15, -30)))
A('tao_dang_kieu', title='Tạo dáng kiêu sa', dur=2.0, loop=True, who='tuyet', modes=dict(FL='b'),
  keys=[(0, POSE), (1.0, merge(POSE, dict(head=(20, 18, 16), FL=(-.012, .07, .07, 45)))), (2.0, POSE)],
  shots=[0, 1.0], main=0,
  notes='Ngồi nghiêng, cằm hếch, mắt lim dim kiêu sa, chân trước trái nhấc nhẹ như vẫy hoàng gia, đuôi vòng ôm quanh chân. '
        'Tuyết dùng trong thi trang phục; mèo khác lên sân khấu dùng 3 dáng chụp ảnh của Bơ (G2: vẫy chào, ổ bánh mì, ta-da).',
  game='Thi trang phục: mỗi mèo tạo 1 dáng 2 s trước 4 bảng chấm.')


# ============ Bà Mướp ============
def granny(u):
    return merge(SIT, dict(root=(0, -.1, .02), chest=(-12 + 1.5 * S(u * TAU),), head=(-4 + 2 * S(u * TAU), 10 * S(u * TAU / 1), 5),
                           eye=blink(u, .7, .06, .15, .85), earL=(0,), earR=(0,),
                           tail=(-30, 20, -10, 35, 0, 35, 10, 30 + 20 * S(u * TAU))))
A('ngoi_san_khau', title='Bà Mướp ngồi sân khấu', dur=3.0, loop=True, who='ba_muop', ctx='thung',
  keys=[(3.0 * i / 12, granny(i / 12)) for i in range(13)], shots=[0, .75, 2.1], main=.75,
  notes='Ngồi trên thùng gỗ sân khấu (thùng trong ảnh là khối tạm 0,4 m; thùng thật thuộc G11), lưng hơi gù, mắt hiền mở 85%, chớp chậm. '
        'Thở sâu chậm 3 s, đầu gật gù nhẹ nhìn đám đông, chóp đuôi buông qua mép thùng đung đưa.',
  game='Mặc định của Bà Mướp cả buổi hội; code quay đầu bà theo trò đang thi.')


def talk(u):
    a = S(u * TAU * 2)
    return merge(SIT, dict(chest=(-12,), head=(2 + 6 * a, 10 * S(u * TAU), 6 + 3 * S(u * TAU)), eye=(.9,), earL=(6 + 4 * a,), earR=(6 + 4 * a,),
                           FR=(.025, .07 + .035 * max(S(u * TAU), 0), .09, -30 - 20 * max(S(u * TAU), 0)),
                           tail=(-30, 20, -10, 35, 0, 35, 10, 30)))
A('noi', title='Bà Mướp nói', dur=1.2, loop=True, who='ba_muop', ctx='thung', modes=dict(FR='b'),
  keys=cyc(8, 1.2, talk), shots=[0, .3, .6, .9], main=.3,
  notes='Nói chuyện: đầu gật theo nhịp câu (2 lần/giây), tai rung, chân trước phải nhấc lên múa nhẹ như kể chuyện. Rig không có hàm: '
        'miệng không mở, lời thoại hiện bằng bóng chữ và giọng đọc.',
  game='Ra chủ đề thi trang phục, giới thiệu trò, nói đầu và cuối hội.')

MEDAL = dict(medal=(1,))
A('trao_huy_chuong', title='Bà Mướp trao huy chương', dur=2.0, loop=False, who='ba_muop', modes=dict(FL='b', FR='b'), props=('medal',),
  keys=[(0, merge(SIT, dict(medal=(1,), FR=(.02, .06, .06, -20), FL=(-.02, .06, .06, -20)))),
        (.4, merge(SIT, dict(medal=(1,), root=(0, -.08, .05), chest=(-34,), head=(-10,), eye=(.9,),
                             FL=(-.03, .2, .19, -60), FR=(.03, .2, .19, -60)))),
        (.85, merge(SIT, dict(medal=(1,), root=(0, -.08, .07), chest=(-38,), head=(-16,), eye=(.85,),
                              FL=(-.03, .16, .24, -70), FR=(.03, .16, .24, -70)))),
        (.95, merge(SIT, dict(medal=(0,), root=(0, -.08, .07), chest=(-38,), head=(-16,), eye=(.85,),
                              FL=(-.03, .16, .24, -70), FR=(.03, .16, .24, -70)))),
        (1.4, merge(SIT, dict(medal=(0,), chest=(-14,), head=(8, 0, 10), eye=(.15,), FL=(-.004, 0, -.02, 0), FR=(.03, .1, .12, -40)))),
        (2.0, merge(SIT, dict(medal=(0,), head=(4, 0, 6), eye=(.85,))))],
  shots=[0, .4, .85, 1.4], main=.85,
  notes='Hai chân trước nâng dây huy chương, nghiêng người tới trước (0,4 s), choàng qua đầu mèo được giải (0,85 s, khớp đúng lúc huy chương '
        'hiện trên Bơ trong clip nhan_huy_chuong G2), buông tay, ngồi lại, cười híp mắt và vỗ vai (1,4 s). Huy chương trong ảnh là bản tạm '
        'của G2; mẫu vàng/bạc/đồng/tham gia thuộc G11.',
  game='Lễ trao giải: Bà Mướp đứng cách mèo nhận 0,3 m; bắt đầu cùng lúc với nhan_huy_chuong.')


def laugh(u):
    a = S(u * TAU * 3)
    return merge(SIT, dict(root=(0, -.1 + .006 * a, .02), chest=(-10 + 4 * a,), head=(12 + 4 * a, 0, 10), eye=(.12,),
                           earL=(-4,), earR=(-4,), FL=(-.02, .17, .1, -60),
                           tail=(-30, 20, -10, 35, 0, 35, 25, 30 + 20 * S(u * TAU))))
A('cuoi', title='Bà Mướp cười', dur=1.0, loop=True, who='ba_muop', ctx='thung', modes=dict(FL='b'),
  keys=cyc(10, 1.0, laugh), shots=[0, .1, .2, .5], main=.1,
  notes='Cười hiền: mắt híp thành vầng trăng, ngửa đầu, vai rung 3 lần mỗi giây, chân trước trái che miệng như bà cụ cười. '
        'Không há miệng (không có xương hàm).',
  game='Khi Lạc về chót mà vẫn reo, khi Bơ mặc đồ vui, và ở màn tổng kết tuần.')
