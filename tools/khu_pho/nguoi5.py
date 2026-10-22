"""Người Thứ Năm (gói G1, bên trong chung cư): Chị Thu (mẹ em bé, mới) và dáng Bé Na mở cửa 5B-1.
Dựng bằng nguoi.py / nguoi3.py (phong cách D, cùng khung người). Dùng:
  python3 nguoi5.py chithu <outdir> [--glb]            xoay 3 mặt + dáng đứng + mặt
  python3 nguoi5.py chithu:suyt <outdir> [--glb]       dáng mới (suyt, ru, camon); bena:mocua
Tay cho bằng mét thế giới (x trái(+)/phải(-) của nhân vật, y lên, z trước), như nguoi3.py."""
import sys
import nguoi as N
import nguoi3 as N3
from nguoi3 import pose

N.CHARS.update({
 'chithu': dict(name='Chị Thu', role='Mẹ em bé, căn 3B-4 (Thứ Năm)', h=1.57, build=dict(bw=.95, belly=1.0, hip=1.05, legr=.95, armr=.92),
   skin='#E8B48E', hair=dict(style='bun', col='#2C1E18'), top=dict(kind='baba', col='#7FB7A4', floral='#F6F1E6'),
   bottom=dict(kind='pants', col='#7FB7A4', floral='#F6F1E6'), shoe='#C8412F', eye=('#A06A34', '#4A2A14'), extras=['earring'], pose={}),
})

_D3 = N3.DANG
def DANG(key):
    D = {
     # đứng yên ở cửa 3B-4, tay trái đặt lên bụng
     'chithu:dang': lambda: pose('chithu', bend=.02, nod=.05, yaw=.1, mouth='smile',
                                 aR=((-.25, .93, -.02), (-.27, .72, .04), (1, 0, 0)), aL=((.22, .95, .1), (.08, .92, .2), (0, 0, 1))),
     # suỵt: ngón trỏ lên môi, mắt nhìn Bơ dưới chân
     'chithu:suyt': lambda: pose('chithu', bend=.08, nod=.3, yaw=-.25, tilt=.06, mouth='o', brow=-.15,
                                 aR=((-.21, 1.0, .2), (-.045, 1.17, .29), (1, 0, .3)), aL=((.24, .93, -.02), (.27, .72, .04), (-1, 0, 0))),
     # ru võng: cúi người, tay phải nắm mép võng đưa nhẹ (mép võng cao ~0,75 m, trước người 0,4 m)
     'chithu:ru': lambda: pose('chithu', bend=.32, nod=.35, yaw=.05, mouth='smile',
                               aR=((-.2, .95, .22), (-.14, .78, .44), (0, -1, 0)), aL=((.22, .95, .08), (.12, .9, .22), (0, 0, 1))),
     # cảm ơn: hai tay chắp trước ngực, gật đầu cười
     'chithu:camon': lambda: pose('chithu', bend=.12, nod=.22, yaw=0, mouth='smile', brow=-.3,
                                  aR=((-.17, .98, .14), (-.03, 1.08, .25), (1, 0, 0)), aL=((.17, .98, .14), (.03, 1.08, .25), (-1, 0, 0))),
     # Bé Na mở cửa 5B-1: tay phải giữ nắm cửa, tay trái chìa ra nhận bánh
     'bena:mocua': lambda: pose('bena', bend=.04, nod=.12, yaw=.2, mouth='open', brow=-.4,
                                aR=((-.2, .6, .04), (-.3, .62, .16), (1, 0, 0)), aL=((.14, .66, .12), (.1, .7, .28), (0, 1, 0))),
    }
    return D[key]() if key in D else _D3(key)
N3.DANG = DANG

if __name__ == '__main__':
    arg = sys.argv[1]; out = sys.argv[2]; glb = '--glb' in sys.argv
    if ':' in arg:
        cid, dk = arg.split(':')
        P = DANG(arg); N.CHARS[cid]['pose'] = P; N3.CUR['P'] = P
        N.POSE_ONLY[0] = True; N.SUF[0] = '_' + dk
    else:
        P = DANG(arg + ':dang'); N.CHARS[arg]['pose'] = P; N3.CUR['P'] = P
    N.run(cid if ':' in arg else arg, out, glb)
