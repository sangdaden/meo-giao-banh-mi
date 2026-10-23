"""Dáng cảm ơn của 10 khách (gói A3 "Khoảnh khắc giao bánh", Sang duyệt 23/10 10:34 UTC).
Chép phần dáng từ a3nguoi.py của trang phác thảo (/mnt/project-files/thiet-ke-man/goi-phac-thao/a3-giao-banh/).
Mỗi dáng là khung chính của một clip một lần trong tools/nguoi_game.py (a3_clips). Đồ cầm tay (ly, xu, quạt)
không dựng vào người: quạt Ông Tám đã có, ly và xu chỉ có ở bản phác thảo.
Tay cho bằng mét thế giới (x trái(+)/phải(-) của nhân vật, y lên, z trước), như nguoi3.py.
Bàn tay đặt trên gối, đùi, hông đã nhấc cho chừa khe >= 1,5 cm (Sang góp ý "tay dính chân"), đo bằng kiemtay.py của trang."""
import nguoi as N  # noqa: F401
import nguoi3 as N3
from nguoi3 import pose
from nguoi9 import F, chest, wide

def thong(side, f):   # tay buông thả lỏng, chừa khe với vạt áo (thay cho chống nạnh bị lún vào hông)
    return ((side * .27 * f, .97 * f, -.03), (side * .32 * f, .76 * f, .05), (-side, 0, .2))

# Nhấc cổ tay/khuỷu (m, theo trục người) cho bàn tay không chạm thân, chân (đo bằng kiemtay.py, khe >= 1,5 cm)
ADJ = {'chutu:daykinh': {'armL': (0, .10, 0)}, 'hung:daptay': {'armL': (0, .13, 0), 'armR': (0, .04, 0)},
       'basau:xoadau': {'armR': (0, .08, 0)}, 'chunam:chao': {'armL': (0, .12, 0)},
       'ongbay:vuotrau': {'armL': (0, .10, 0)}, 'ongtam:quat': {'armR': (0, .11, 0)}}
def _adj(key, P):
    for arm, dv in ADJ.get(key, {}).items():
        a = P[arm]; dv = tuple(dv)
        a['w'] = tuple(x + d for x, d in zip(a['w'], dv)); a['e'] = tuple(x + .6 * d for x, d in zip(a['e'], dv))
    return P



def DANG(key):
    cid = key.split(':')[0]; f = F(cid)
    D = {
     # Cô Ba (đơn lấy đồ mang về lò, cuối ca): Bơ nhảy lên quầy, Cô Ba xoa đầu
     'coba:xoadau': lambda: pose('coba', bend=.14, nod=.3, tilt=.12, yaw=.05, mouth='smile', brow=-.6,
                                 aR=((-.2 * f, 1.16 * f, .24), (-.04, 1.28, .4), (0, -1, 0)), aL=thong(1, f)),
     # Chú Tư (ngồi sạp báo, ít nói): đẩy gọng kính, gật gù
     'chutu:daykinh': lambda: pose('chutu', sit=.42, bend=.06, nod=.22, yaw=.1, tilt=-.06, mouth='smile', brow=-.4,
                                   aR=((-.27, .84, .22), (-.09, .95, .28), (1, 0, .3)), aL=((.23, .66, .14), (.16, .6, .32), (0, -1, 0))),
     # Bé Na (ban công, giỏ thòng dây): ôm ổ bánh vào lòng, nghiêng đầu cười há
     'bena:ombanh': lambda: pose('bena', bend=-.04, nod=-.05, tilt=.28, yaw=.1, mouth='open', brow=-.8, legs=wide,
                                 aR=chest(-1, f, -.04), aL=chest(1, f, -.04), prop='loaf2'),
     # Chị Mây (quầy cà phê): đưa ly cà phê sữa đá ra "cụng" với Bơ
     'may:nangly': lambda: pose('may', bend=.06, nod=.12, tilt=.14, yaw=-.08, mouth='open', brow=-.6,
                                aR=((-.25 * f, 1.06 * f, .2), (-.12, 1.2, .44), (0, 0, 1)), aL=thong(1, f), prop='ly'),
     # Anh Hùng (ngồi ghế đẩu tiệm xe): khom người chìa nắm tay cho Bơ đập
     'hung:daptay': lambda: pose('hung', sit=.32, bend=.36, nod=.28, yaw=0, mouth='open', brow=-.6,
                                 aR=((-.22, .6, .3), (-.08, .42, .5), (1, 0, 0)), aL=((.24, .6, .14), (.16, .5, .32), (0, -1, 0))),
     # Bà Sáu (ngồi ghế trước nhà bông giấy): nghiêng người xoa đầu Bơ bên cạnh
     'basau:xoadau': lambda: pose('basau', sit=.42, bend=.3, nod=.3, yaw=.35, tilt=.08, mouth='smile', brow=-.6,
                                  aL=((.3, .66, .2), (.34, .44, .34), (0, -1, 0)), aR=((-.21, .66, .16), (-.13, .6, .32), (0, -1, 0))),
     # Chú Năm (ngồi xe ôm, vui tính): giơ tay chào kiểu "nghiêm" đùa
     'chunam:chao': lambda: pose('chunam', sit=.86, bend=-.06, nod=-.04, yaw=.25, tilt=-.1, mouth='open', brow=-.5, knee=(.6, .3), ankle=(.07, .26), kx=.1,
                                 aR=((-.36, 1.36, .12), (-.19, 1.49, .22), (0, 0, 1)), aL=((.26, .74, .08), (.16, .62, .3), (0, -1, 0)), bike=True),
     # Cô Hai (sau quầy tạp hóa, lanh lợi): cúi qua quầy thả đồng xu boa vào túi Bơ
     'cohai:thaxu': lambda: pose('cohai', bend=.16, nod=.32, yaw=-.05, tilt=.08, mouth='open', brow=-.5,
                                 aL=((.2 * f, 1.06 * f, .24), (.06, 1.0, .46), (0, -1, 0)), aR=thong(-1, f), prop='coin'),
     # Ông Bảy (ghế đá góc cờ): vuốt chòm râu, gật gù khen
     'ongbay:vuotrau': lambda: pose('ongbay', sit=.38, ghe=True, bend=-.04, nod=-.08, yaw=.25, mouth='smile', brow=-.5,
                                    aR=((-.24, .78, .22), (-.05, .9, .25), (1, 0, 0)), aL=((.23, .62, .14), (.16, .54, .32), (0, -1, .2))),
     # Ông Tám: quạt mo phe phẩy về phía Bơ cho mát
     'ongtam:quat': lambda: pose('ongtam', sit=.38, ghe=True, bend=.1, nod=.12, yaw=-.3, mouth='open', brow=-.4, prop='fan',
                                 aL=((.3, .82, .24), (.18, .9, .48), (0, 0, 1)), aR=((-.27, .66, .16), (-.18, .56, .32), (0, -1, 0))),
    }
    if key in D:
        return _adj(key, D[key]())
    return _D3(key)


_D3 = N3.DANG
N3.DANG = DANG
