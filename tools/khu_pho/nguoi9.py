"""Người dân Thứ Bảy (gói G9, Sang duyệt 22/10 07:23 UTC): dáng chụp ảnh chung với Bơ và dáng chính của từng việc nhờ.
Chép phần dáng từ g9nguoi.py của trang phác thảo (/mnt/project-files/thiet-ke-man/goi-phac-thao/g9-nguoi-thu-bay/).
Đồ cầm tay (ly cà phê, bánh, con ốc, chùm bông giấy, mũ hồng) là đồ rời trong game, dựng ở do_cam_g9.py.
Chị Thảo Thứ Bảy bỏ quên mũ bảo hiểm nên có thêm bản không mũ 'khachxeom_tb' (cùng khung xương, cùng động tác).
Tay trong DANG cho bằng mét thế giới (x trái(+)/phải(-) của nhân vật, y lên, z trước), như nguoi3.py."""
import copy
import nguoi as N
import nguoi3 as N3
from nguoi3 import pose

N.CHARS['khachxeom_tb'] = dict(copy.deepcopy(N.CHARS['khachxeom']), base='khachxeom', hair=dict(style='ponytail', col='#2C1E18'))

walk = dict(L=((.43, .1), (.08, .2)), R=((.42, -.06), (.12, -.2)))
wide = dict(L=((.45, .05), (.1, .02)), R=((.45, -.05), (.1, -.02)))

def F(cid): return N.CHARS[cid]['h'] / 1.58

def hips(cid, side, f):   # tay chống nạnh: khuỷu bung ra, cổ tay đặt trên hông
    return ((side * .33 * f, .98 * f, -.06 * f), (side * .17 * f, .86 * f, .0), (0, 0, side * 1.0))
def hang(side, f):        # tay buông tự nhiên
    return ((side * .25 * f, .95 * f, -.02), (side * .27 * f, .73 * f, .04), (-side, 0, 0))
def wave(side, f):        # vẫy chào ngang đầu
    return ((side * .36 * f, 1.03 * f, .06), (side * .37 * f, 1.23 * f, .12), (0, 0, 1))
def clap(side, f):        # vỗ tay trước ngực
    return ((side * .17 * f, .98 * f, .16 * f), (side * .03, 1.06 * f, .27 * f), (-side, 0, 0))
def chest(side, f, dz=0.):  # hai tay ôm vật trước ngực
    return ((side * .22 * f, .95 * f, .14 * f), (side * .1 * f, 1.0 * f, (.3 + dz) * f), (0, 1, 0))

_D3 = N3.DANG


def DANG(key):
    cid = key.split(':')[0]; f = F(cid)
    D = {
     # ================= Cô Ba · trang 1 · chọn nhân "bánh mì Bơ"
     'coba:chup': lambda: pose('coba', yaw=.12, tilt=.06, nod=0, mouth='smile', brow=-.2,
                               aR=((-.3 * f, 1.0 * f, .16), (-.26 * f, 1.12 * f, .32), (1, 0, 0)), aL=wave(1, f), prop='loaf'),
     'coba:nem': lambda: pose('coba', bend=.04, nod=.12, yaw=.05, mouth='o', brow=-.2,
                              aR=((-.24 * f, 1.04 * f, .2), (-.06 * f, 1.21 * f, .25), (1, 0, .2)), aL=chest(1, f), prop='banh'),
     'coba:khen': lambda: pose('coba', bend=.06, nod=.18, tilt=.12, yaw=.1, mouth='smile', brow=-.6,
                               aR=clap(-1, f), aL=clap(1, f)),
     # ================= Chú Tư · trang 2 · đuổi tờ báo bay
     'chutu:chup': lambda: pose('chutu', yaw=0, nod=.02, tilt=-.04, mouth='smile', brow=-.3,
                                aR=((-.26 * f, 1.03 * f, .14), (-.19 * f, 1.12 * f, .32), (1, 0, .2)), aL=((.26 * f, 1.03 * f, .14), (.19 * f, 1.12 * f, .32), (-1, 0, .2)), prop='newspaper'),
     'chutu:duoi': lambda: pose('chutu', bend=-.1, nod=-.45, yaw=.1, mouth='o', brow=1, legs=walk,
                                aR=((-.25 * f, 1.42 * f, .1), (-.2 * f, 1.66 * f, .26), (1, 0, .2)), aL=((.34 * f, 1.0 * f, -.12), (.42 * f, .84 * f, -.24), (-1, 0, 0))),
     'chutu:chi': lambda: pose('chutu', bend=-.04, nod=-.3, yaw=.35, mouth='open', brow=.6,
                               aL=((.3 * f, 1.32 * f, .2), (.36 * f, 1.52 * f, .44), (0, 0, 1)), aR=hips('chutu', -1, f)),
     'chutu:camon': lambda: pose('chutu', bend=.2, nod=.28, yaw=0, mouth='smile', brow=-.4,
                                 aR=chest(-1, f), aL=chest(1, f), prop='newspaper'),
     # ================= Bé Na · trang 3 · trốn tìm ở chung cư
     'bena:chup': lambda: pose('bena', yaw=.1, tilt=.12, nod=-.06, mouth='open', brow=-.7, legs=wide,
                               aR=((-.22, .84, .04), (-.27, 1.0, .1), (1, 0, .3)), aL=((.22, .84, .04), (.27, 1.0, .1), (-1, 0, .3))),
     'bena:tron': lambda: pose('bena', sit=.3, noseat=True, knee=(.06, .24), ankle=(.04, -.1), kx=.1, bend=.35, nod=.2, yaw=-.1, mouth='smile', brow=-.5,
                               aR=((-.14, .52, .18), (-.03, .58, .25), (1, 0, 0)), aL=((.14, .52, .18), (.03, .58, .25), (-1, 0, 0))),
     'bena:lo': lambda: pose('bena', bend=.12, tilt=.38, yaw=.25, nod=.05, mouth='smile', brow=-.3,
                             aL=((.24, .7, .14), (.3, .76, .3), (-1, 0, 0)), aR=((-.12, .62, .1), (-.03, .7, .2), (1, 0, 0))),
     'bena:cuoi': lambda: pose('bena', bend=-.06, nod=-.12, tilt=.16, yaw=.1, mouth='open', brow=-.8,
                               aR=((-.15, .6, .12), (-.03, .66, .2), (1, 0, 0)), aL=((.15, .6, .12), (.03, .66, .2), (-1, 0, 0))),
     # ================= Chị Mây · trang 4 · Bơ làm mèo mẫu
     'may:chup': lambda: pose('may', yaw=-.15, tilt=.1, nod=0, mouth='smile', brow=-.2,
                              aR=((-.32 * f, 1.02 * f, .12), (-.27 * f, 1.18 * f, .26), (0, 0, 1)), aL=hips('may', 1, f), prop='ly'),
     'may:chibang': lambda: pose('may', yaw=-.45, tilt=-.04, nod=.02, mouth='open', brow=-.2,
                                 aR=((-.43 * f, 1.24 * f, .1), (-.66 * f, 1.3 * f, .2), (0, 0, 1)), aL=hips('may', 1, f)),
     'may:votay': lambda: pose('may', bend=.04, nod=.05, tilt=.1, mouth='open', brow=-.6, aR=clap(-1, f), aL=clap(1, f)),
     # ================= Anh Hùng · trang 5 · tìm 4 con ốc
     'hung:chup': lambda: pose('hung', yaw=.1, tilt=-.06, nod=0, mouth='smile', brow=-.3, legs=wide,
                               aR=((-.32 * f, 1.04 * f, .12), (-.29 * f, 1.24 * f, .2), (1, 0, 0)), aL=hips('hung', 1, f), prop='wrench'),
     'hung:cui': lambda: pose('hung', bend=.62, nod=.45, yaw=0, mouth='o', brow=.2, legs=wide,
                              aR=((-.27 * f, .95 * f, .4), (-.15 * f, .72 * f, .32), (1, 0, 0)), aL=((.27 * f, .95 * f, .4), (.15 * f, .72 * f, .32), (-1, 0, 0))),
     'hung:nhan': lambda: pose('hung', bend=0, nod=-.05, yaw=-.1, tilt=.06, mouth='open', brow=-.6,
                               aR=((-.26 * f, 1.12 * f, .3), (-.08 * f, 1.3 * f, .42), (1, 0, .3)), aL=hips('hung', 1, f), prop='oc'),
     # ================= Bà Sáu · trang 6 · hái bông giấy
     'basau:chup': lambda: pose('basau', sit=.42, bend=.08, nod=.05, yaw=.15, tilt=.06, mouth='smile', brow=-.4,
                                aR=((-.21, .86, .16), (-.08, .78, .32), (0, 1, 0)), aL=((.21, .86, .16), (.08, .78, .32), (0, 1, 0)), prop='bonggiay'),
     'basau:chi': lambda: pose('basau', bend=.06, nod=-.32, yaw=.2, mouth='open', brow=-.2,
                               aR=((-.27, 1.18, .2), (-.3, 1.4, .4), (0, 0, 1)), aL=((.22, .86, -.12), (.06, .82, -.18), (0, 0, -1))),
     'basau:nhan': lambda: pose('basau', bend=.12, nod=.2, yaw=.05, tilt=.08, mouth='smile', brow=-.5,
                                aR=chest(-1, F('basau'), -.06), aL=chest(1, F('basau'), -.06), prop='bonggiay'),
     # ================= Ông Bảy, Ông Tám · trang 7 · trọng tài tìm quân cờ
     'ongbay:chup': lambda: pose('ongbay', sit=.38, ghe=True, bend=-.05, nod=-.08, yaw=.15, mouth='open', brow=-.5,
                                 aR=((-.3, .92, .1), (-.26, 1.14, .18), (0, 0, 1)), aL=((.22, .55, .12), (.15, .42, .3), (0, -1, .2)), prop='piece'),
     'ongbay:chi': lambda: pose('ongbay', sit=.38, ghe=True, bend=.36, nod=.45, yaw=-.2, mouth='open', brow=.3,
                                aR=((-.3, .64, .22), (-.42, .42, .38), (0, 0, 1)), aL=((.22, .6, .16), (.14, .46, .3), (0, -1, .2))),
     'ongtam:chup': lambda: pose('ongtam', sit=.38, ghe=True, bend=-.06, nod=-.06, yaw=-.15, mouth='open', brow=-.5, prop='fan',
                                 aL=((.34, .94, .06), (.31, 1.16, .14), (-1, 0, .3)), aR=((-.26, .6, .14), (-.18, .46, .3), (0, -1, 0))),
     'ongtam:chi': lambda: pose('ongtam', sit=.38, ghe=True, bend=.02, nod=.05, yaw=.45, tilt=.05, mouth='open', brow=.2, prop='fan',
                                aL=((.36, .84, .22), (.46, .9, .46), (0, 0, 1)), aR=((-.26, .6, .14), (-.18, .46, .3), (0, -1, 0))),
     # ================= Cô Hai · trang 8 · dựng lại tháp lon
     'cohai:chup': lambda: pose('cohai', yaw=.15, tilt=.1, nod=0, mouth='open', brow=-.5,
                                aR=((-.32 * f, 1.14 * f, .08), (-.3 * f, 1.36 * f, .14), (1, 0, .3)), aL=hips('cohai', 1, f)),
     'cohai:chongnanh': lambda: pose('cohai', bend=-.03, nod=.22, yaw=-.1, tilt=-.1, mouth='o', brow=.4, legs=wide,
                                     aR=hips('cohai', -1, f), aL=hips('cohai', 1, f)),
     'cohai:votay': lambda: pose('cohai', bend=.05, nod=.05, tilt=.08, mouth='open', brow=-.6, aR=clap(-1, f), aL=clap(1, f)),
     # ================= Chú Năm · trang 9 · mũ bảo hiểm khách quên
     'chunam:chup': lambda: pose('chunam', sit=.86, bend=-.04, nod=.0, yaw=.25, mouth='open', brow=-.4, knee=(.6, .3), ankle=(.07, .26), kx=.1,
                                 aR=((-.3, 1.02, .08), (-.27, 1.24, .14), (1, 0, .3)), aL=((.26, .74, .08), (.16, .62, .3), (0, -1, 0)), bike=True),
     'chunam:gaidau': lambda: pose('chunam', bend=.02, nod=.08, yaw=-.15, tilt=.14, mouth='o', brow=.5,
                                   aR=((-.33 * f, 1.3 * f, .1), (-.09 * f, 1.36 * f, -.08), (0, -1, 0)), aL=hips('chunam', 1, f)),
     'chunam:chimai': lambda: pose('chunam', bend=-.04, nod=-.28, yaw=.3, mouth='open', brow=-.1,
                                   aL=((.3 * f, 1.3 * f, .2), (.37 * f, 1.5 * f, .44), (0, 0, 1)), aR=hang(-1, f)),
     # ================= Chị Thu · trang 10 · ru em bé (dáng ru/suyt có sẵn ở G1)
     'chithu:chup': lambda: pose('chithu', bend=.06, nod=.08, yaw=.1, tilt=-.22, mouth='smile', brow=-.4,
                                 aR=((-.2 * f, 1.06 * f, .14), (-.035 * f, 1.23 * f, .2), (1, 0, 0)), aL=((.2 * f, 1.06 * f, .14), (.035 * f, 1.23 * f, .2), (-1, 0, 0))),
     # ================= Chị Thảo · khách xe ôm, chủ cái mũ (trang 9, chụp chung khi trả mũ)
     'khachxeom:chup': lambda: pose('khachxeom', yaw=-.1, tilt=.08, nod=0, mouth='open', brow=-.4,
                                    aL=((.27 * f, .96 * f, .08), (.2 * f, .88 * f, .26), (0, 1, 0)), aR=wave(-1, f), prop='mu'),
     'khachxeom:tim': lambda: pose('khachxeom', bend=.04, nod=-.1, yaw=.45, mouth='o', brow=.6,
                                   aR=((-.25 * f, 1.3 * f, .18), (-.06 * f, 1.42 * f, .16), (0, -1, 0)), aL=hips('khachxeom', 1, f)),
     'khachxeom:nhanmu': lambda: pose('khachxeom', bend=.22, nod=.3, yaw=0, mouth='smile', brow=-.5, aR=chest(-1, f), aL=chest(1, f), prop='mu2'),
    }
    return D[key]() if key in D else _D3(key)


N3.DANG = DANG

# Tất cả dáng G9 theo thứ tự trang phác thảo (nguoi_game.g9_clips đọc để biết ai có dáng Thứ Bảy)
ALL = ['coba:chup', 'coba:nem', 'coba:khen', 'chutu:chup', 'chutu:duoi', 'chutu:chi', 'chutu:camon', 'bena:chup', 'bena:tron', 'bena:lo', 'bena:cuoi',
       'may:chup', 'may:chibang', 'may:votay', 'hung:chup', 'hung:cui', 'hung:nhan', 'basau:chup', 'basau:chi', 'basau:nhan',
       'ongbay:chup', 'ongbay:chi', 'ongtam:chup', 'ongtam:chi', 'cohai:chup', 'cohai:chongnanh', 'cohai:votay',
       'chunam:chup', 'chunam:gaidau', 'chunam:chimai', 'chithu:chup', 'chithu:ru', 'chithu:suyt', 'khachxeom:chup', 'khachxeom:tim', 'khachxeom:nhanmu']
