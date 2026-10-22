"""Dáng người Thứ Năm ngoài phố (gói G1 bản 2): Chú Tư ngủ gật ở sạp báo, Anh Hùng nằm võng trong tiệm xe.
Dùng: python3 nguoi6.py chutu:ngugat <outdir> --glb ; python3 nguoi6.py hung:namvong <outdir> --glb
Tay cho bằng mét thế giới (x trái(+)/phải(-) của nhân vật, y lên, z trước), như nguoi3.py. sleep=True: mắt nhắm."""
import sys
import nguoi as N
import nguoi3 as N3
from nguoi3 import pose

_D3 = N3.DANG
def DANG(key):
    D = {
     # ngủ gật trên ghế đẩu ở sạp báo: đầu gục, nghiêng, miệng hé, hai tay buông trên đùi
     'chutu:ngugat': lambda: pose('chutu', sit=.45, bend=.06, nod=.62, yaw=.05, tilt=.22, mouth='o', sleep=True,
                                  aR=((-.24, .66, .06), (-.13, .56, .26), (0, -1, .2)), aL=((.24, .66, .06), (.13, .56, .26), (0, -1, .2))),
     # nằm võng: ngả lưng ra sau, hai tay gối sau đầu, mắt nhắm (đặt vào võng ngả thêm trong cảnh)
     'hung:namvong': lambda: pose('hung', sit=.30, bend=-.4, nod=-.1, yaw=0, tilt=.05, mouth='smile', sleep=True,
                                  aR=((-.34, .98, -.02), (-.08, .92, -.3), (0, 0, -1)), aL=((.34, .98, -.02), (.08, .92, -.3), (0, 0, -1))),
     # Chị Mây ngồi ghế đẩu trên gác, cúi ra mép gác, hai tay thả dây giỏ xuống quầy
     'may:thagio': lambda: pose('may', sit=.32, bend=.2, nod=.45, yaw=0, mouth='open', brow=-.3,
                                aR=((-.22, .66, .16), (-.13, .62, .4), (1, 0, 0)), aL=((.22, .7, .16), (.13, .7, .4), (-1, 0, 0))),
    }
    return D[key]() if key in D else _D3(key)
N3.DANG = DANG

if __name__ == '__main__':
    arg = sys.argv[1]; out = sys.argv[2]; glb = '--glb' in sys.argv
    cid, dk = arg.split(':')
    P = DANG(arg); N.CHARS[cid]['pose'] = P; N3.CUR['P'] = P
    N.POSE_ONLY[0] = True; N.SUF[0] = '_' + dk
    N.run(cid, out, glb)
