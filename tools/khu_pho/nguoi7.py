"""Người đám giỗ nhà Bà Sáu (gói G7, Sang duyệt 22/10): 4 khách giỗ, 2 con nít + 3 dáng mới của Bà Sáu.
Chép phần người và dáng từ g7nguoi.py của trang phác thảo (/mnt/project-files/thiet-ke-man/goi-phac-thao/g7-dam-gio/).
Đồ cầm tay (nhang, chén đũa, mâm cỗ, bình tưới) là đồ rời trong game nên không dựng ở đây.
Tay trong DANG cho bằng mét thế giới (x trái(+)/phải(-) của nhân vật, y lên, z trước), như nguoi3.py."""
import nguoi as N
import nguoi3 as N3
from nguoi3 import pose

N.CHARS.update({
 'thanh': dict(fem=False, name='Chú Thành', role='Con trai Bà Sáu, đứng ra lo giỗ', h=1.67, build=dict(bw=1.02, belly=1.08, hip=1.0, legr=.98, armr=.98),
   skin='#D49A74', hair=dict(style='short', col='#4A4440'), top=dict(kind='shirt', col='#F4F1EA', sleeve='long'), bottom=dict(kind='pants', col='#3D3F48'),
   shoe='#3A2A20', eye=('#8A5A2E', '#3A2214'), extras=['glasses'], pose={}),
 'loan': dict(name='Cô Loan', role='Con dâu Bà Sáu, lo mâm cỗ', h=1.56, build=dict(bw=1.0, belly=1.06, hip=1.1, legr=.98, armr=.98),
   skin='#E3AE88', hair=dict(style='bun', col='#2A1D18'), top=dict(kind='baba', col='#2F6E8A'), bottom=dict(kind='pants', col='#24242A'),
   shoe='#8A3A2A', eye=('#A06A34', '#4A2A14'), extras=['earring'], pose={}),
 'muoi': dict(fem=False, name='Ông Mười', role='Em trai Bà Sáu, khách lớn tuổi', h=1.6, old=True, build=dict(bw=.92, belly=.98, hip=.95, legr=.88, armr=.88),
   skin='#C99272', hair=dict(style='short', col='#DCD8D2'), top=dict(kind='shirt', col='#EDE6D6', sleeve='long', stripes='#8A6A4A'), bottom=dict(kind='pants', col='#5A4E44'),
   shoe='#5A3A2A', eye=('#8A5A36', '#3E2416'), extras=['glasses_round'], pose={}),
 'hanh': dict(name='Chị Hạnh', role='Cháu nội Bà Sáu, về từ thành phố', h=1.6, build=dict(bw=.92, belly=.92, hip=1.0, legr=.95, armr=.9),
   skin='#EDBB95', hair=dict(style='ponytail', col='#3A2620'), top=dict(kind='shirt', col='#F2D27A', sleeve='short'), bottom=dict(kind='pants', col='#4D6A8A'),
   shoe='#F1ECE2', eye=('#A06A34', '#4A2A14'), extras=['earring'], pose={}),
 'bin': dict(fem=False, name='Bé Bin', role='Chắt Bà Sáu, 6 tuổi, mê chạy theo Bơ', h=1.12, kid=True, build=dict(bw=.95, belly=1.0, hip=.95, legr=1.0, armr=1.0),
   skin='#E3AE88', hair=dict(style='short', col='#1E1714'), top=dict(kind='tee', col='#3F8FD0', sleeve='short'), bottom=dict(kind='shorts', col='#E9C46A'),
   shoe='#D2554A', eye=('#A87038', '#4A2A14'), extras=[], pose={}),
 'mit': dict(name='Bé Mít', role='Chắt gái Bà Sáu, 5 tuổi, thích vuốt mèo', h=1.04, kid=True, build=dict(bw=.95, belly=1.05, hip=.95, legr=1.0, armr=1.0),
   skin='#EDBB95', hair=dict(style='pigtails', col='#2C1E18', tie='#E86AAE'), top=dict(kind='dress', col='#F2A0B8', sleeve='short', dots='#FFF6F0'),
   bottom=dict(kind='skirt', col='#F2A0B8', dots='#FFF6F0'), shoe='#F2C14E', eye=('#A87038', '#4A2A14'), extras=[], pose={}),
})

_D3 = N3.DANG
def DANG(key):
    cid = key.split(':')[0]
    if cid not in ('thanh', 'loan', 'muoi', 'hanh', 'bin', 'mit', 'basau'):
        return _D3(key)
    h = N.CHARS[cid]['h']; f = h / 1.58
    walk = dict(L=((.43, .1), (.08, .2)), R=((.42, -.06), (.12, -.2)))
    D = {
     # ---- Chú Thành: chắp tay khấn (cầm 3 nén nhang) / đứng nói chuyện
     'thanh:dang': lambda: pose('thanh', bend=.08, nod=.32, yaw=0, mouth='smile', brow=.2,
                                aR=((-.2 * f, 1.0 * f, .12 * f), (-.015, 1.1 * f, .24 * f), (1, 0, 0)), aL=((.2 * f, 1.0 * f, .12 * f), (.015, 1.1 * f, .24 * f), (-1, 0, 0)), prop='nhang3'),
     'thanh:noichuyen': lambda: pose('thanh', bend=-.02, nod=0, yaw=.3, tilt=-.04, mouth='open', brow=-.3,
                                     aR=((-.27 * f, .98 * f, .06 * f), (-.22 * f, 1.1 * f, .28 * f), (0, 1, .2)), aL=((.25 * f, .95 * f, -.02), (.27 * f, .74 * f, .04), (-1, 0, 0))),
     # ---- Cô Loan: bưng mâm cỗ / chắp tay
     'loan:dang': lambda: pose('loan', bend=-.04, nod=.15, yaw=.15, mouth='smile', legs=walk,
                               aR=((-.29 * f, .9 * f, .1 * f), (-.27 * f, .99 * f, .29 * f), (0, 1, 0)), aL=((.29 * f, .9 * f, .1 * f), (.27 * f, .99 * f, .29 * f), (0, 1, 0)), prop='mam'),
     'loan:chaptay': lambda: pose('loan', bend=.1, nod=.3, mouth='smile',
                                  aR=((-.2 * f, 1.0 * f, .12 * f), (-.015, 1.1 * f, .24 * f), (1, 0, 0)), aL=((.2 * f, 1.0 * f, .12 * f), (.015, 1.1 * f, .24 * f), (-1, 0, 0))),
     # ---- Ông Mười: ngồi ăn trên ghế đẩu / đứng nói chuyện
     'muoi:dang': lambda: pose('muoi', sit=.3, bend=.22, nod=.28, yaw=-.05, mouth='smile',
                               aL=((.22, .58, .14), (.1, .66, .3), (0, 1, 0)), aR=((-.24, .62, .16), (-.08, .74, .32), (0, -1, 0)), prop='chen'),
     'muoi:noichuyen': lambda: pose('muoi', bend=.12, nod=.1, yaw=-.3, mouth='open', brow=-.4,
                                    aL=((.25 * f, .96 * f, .08), (.2 * f, 1.08 * f, .3 * f), (0, 1, .3)), aR=((-.25 * f, .95 * f, -.02), (-.27 * f, .74 * f, .04), (1, 0, 0))),
     # ---- Chị Hạnh: đứng nói chuyện / ngồi ăn
     'hanh:dang': lambda: pose('hanh', bend=.02, nod=.02, yaw=-.3, tilt=.07, mouth='open', brow=-.5,
                               aL=((.26 * f, .97 * f, .06), (.22 * f, 1.12 * f, .26 * f), (0, 1, .3)), aR=((-.24 * f, .96 * f, .04), (-.12 * f, .92 * f, .2 * f), (0, 1, 0))),
     'hanh:ngoian': lambda: pose('hanh', sit=.3, bend=.2, nod=.3, yaw=.1, mouth='smile',
                                 aL=((.22, .58, .14), (.1, .66, .3), (0, 1, 0)), aR=((-.24, .62, .16), (-.08, .74, .32), (0, -1, 0)), prop='chen'),
     # ---- Bé Bin: chạy theo Bơ / cười ôm bụng
     'bin:dang': lambda: pose('bin', bend=.18, nod=-.02, yaw=.05, mouth='open', brow=-.6,
                              legs=dict(L=((.47, .22), (.14, .3)), R=((.38, -.12), (.26, -.32))),
                              aR=((-.16, .58, .1), (-.12, .66, .24), (1, 0, .3)), aL=((.17, .56, -.1), (.16, .46, -.06), (-1, 0, 0))),
     'bin:cuoi': lambda: pose('bin', bend=-.06, nod=-.15, tilt=.1, mouth='open', brow=-.8,
                              aR=((-.17, .56, .08), (-.06, .5, .14), (0, 0, 1)), aL=((.17, .56, .08), (.06, .5, .14), (0, 0, 1))),
     # ---- Bé Mít: ngồi xổm vuốt Bơ / cười
     'mit:dang': lambda: pose('mit', sit=.27, noseat=True, knee=(.05, .22), ankle=(.04, -.1), kx=.1, bend=.3, nod=.4, yaw=.05, mouth='smile', brow=-.2,
                              aL=((.16, .5, .16), (.14, .42, .34), (0, -1, 0)), aR=((-.16, .5, .16), (-.12, .43, .33), (0, -1, 0))),
     'mit:cuoi': lambda: pose('mit', bend=0, nod=-.06, tilt=.16, yaw=.15, mouth='open', brow=-.7,
                              aR=((-.15, .54, .08), (-.03, .62, .14), (1, 0, 0)), aL=((.15, .54, .08), (.03, .62, .14), (-1, 0, 0))),
     # ---- Bà Sáu: tưới cây / ra cổng nhận túi / chào tiễn
     'basau:tuoi': lambda: pose('basau', bend=.16, nod=.3, yaw=.3, mouth='smile',
                                aR=((-.24, .95, .12), (-.25, .81, .3), (1, 0, 0)), aL=((.2, .92, .05), (.21, .7, .08), (-1, 0, 0)), prop='tuoi', grip=(-1,)),
     'basau:racong': lambda: pose('basau', bend=.36, nod=.3, yaw=0, mouth='open', brow=-.3, legs=walk,
                                  aR=((-.2, .82, .2), (-.08, .66, .38), (0, 1, 0)), aL=((.2, .82, .2), (.08, .66, .38), (0, 1, 0))),
     'basau:chao': lambda: pose('basau', bend=.08, nod=.05, yaw=.2, tilt=.08, mouth='open', brow=-.4,
                                aR=((-.3, 1.08, .06), (-.28, 1.3, .12), (0, 0, 1)), aL=((.22, .9, .08), (.12, .86, .22), (0, 1, 0))),
    }
    return D[key]() if key in D else _D3(key)
N3.DANG = DANG
