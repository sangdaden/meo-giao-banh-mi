"""Người Thứ Ba: người đi chợ, người bán, hàng rong, người xem cờ + dáng mới của Ông Bảy, Ông Tám, Cô Hai, Chú Năm.
Dựng bằng nguoi.py (cùng phong cách D, cùng khung người). Dùng:
  python3 nguoi3.py <id> <outdir> [--glb]                 nhân vật mới: xoay 3 mặt, dáng, mặt
  python3 nguoi3.py <id>:<dáng> <outdir> [--glb]          dáng mới của người đã có (chỉ render dáng + mặt)
Tay chân trong DANG cho bằng mét thế giới (x trái(+)/phải(-) của nhân vật, y lên, z trước), hàm W() đổi sang toạ độ khung người."""
import sys, math, copy, numpy as np
import nguoi as N
from nguoi import v, ellipsoid, sphere, roundcone, smin, smax, chain, box, cyl, nrm

# ---------------------------------------------------------------- người mới
N.CHARS.update({
 'bancho': dict(name='Cô Tư bán rau', role='Bán rau ở chợ tạm (ngồi sạp)', h=1.52, build=dict(bw=1.0, belly=1.12, hip=1.12, legr=1.0, armr=1.0),
   skin='#D9A07A', hair=dict(style='bun', col='#2A1D18', nonla=True), top=dict(kind='baba', col='#9A6A44'), bottom=dict(kind='pants', col='#2A2A2E'),
   shoe='#4A3A2E', eye=('#9A6534', '#43271A'), extras=['earring'], pose={}),
 'hangrong': dict(fem=False, name='Chú Sáu bán bắp', role='Hàng rong đẩy xe (chặn hẻm khối 3)', h=1.63, build=dict(bw=1.0, belly=1.0, hip=.98, legr=.95, armr=1.0),
   skin='#C68A60', hair=dict(style='short', col='#2A1D18', nonla=True), top=dict(kind='shirt', col='#6E8FA8', sleeve='long'), bottom=dict(kind='pants', col='#3D3F40'),
   shoe='#2E2A28', eye=('#8A5A2E', '#3A2214'), extras=['towel'], pose={}),
 'ganhhang': dict(name='Cô Bảy gánh hàng', role='Hàng rong gánh (đi giữa chợ)', h=1.5, build=dict(bw=.95, belly=1.0, hip=1.05, legr=.95, armr=.95),
   skin='#D49A74', hair=dict(style='bun', col='#3A2620', nonla=True), top=dict(kind='baba', col='#3E8C8C'), bottom=dict(kind='pants', col='#2E2A30'),
   shoe='#6A4A3A', eye=('#9A6534', '#43271A'), extras=[], pose={}),
 'dicho1': dict(name='Bà Tư đi chợ', role='Người đi chợ', h=1.48, old=True, build=dict(bw=.95, belly=1.1, hip=1.08, legr=.9, armr=.92),
   skin='#DDA481', hair=dict(style='perm', col='#9C958E'), top=dict(kind='baba', col='#8C5A9A', floral='#F2C14E'), bottom=dict(kind='pants', col='#2E2A30'),
   shoe='#8A3A2A', eye=('#8A5A36', '#3E2416'), extras=['earring'], pose={}),
 'dicho2': dict(fem=False, name='Anh Tâm đi chợ', role='Người đi chợ', h=1.7, build=dict(bw=1.05, belly=.95, hip=.98, legr=1.0, armr=1.0),
   skin='#D9A07A', hair=dict(style='short', col='#1E1714', cap='#2E6FA8'), top=dict(kind='tee', col='#F2B33D', sleeve='short'), bottom=dict(kind='shorts', col='#4D6A8A'),
   shoe='#2E2A28', eye=('#9A6534', '#43271A'), extras=[], pose={}),
 'dicho3': dict(name='Chị Hồng đi chợ', role='Người đi chợ', h=1.58, build=dict(bw=.92, belly=.92, hip=1.0, legr=.92, armr=.9),
   skin='#EDBB95', hair=dict(style='ponytail', col='#2C1E18'), top=dict(kind='tee', col='#E58AA0', sleeve='long'), bottom=dict(kind='pants', col='#F1ECE2'),
   shoe='#E9E2D2', eye=('#A06A34', '#4A2A14'), extras=[], pose={}),
 'xemco': dict(fem=False, name='Ông Chín xem cờ', role='Người đứng xem cờ', h=1.62, old=True, build=dict(bw=.95, belly=1.15, hip=1.0, legr=.92, armr=.92),
   skin='#C99272', hair=dict(style='short', col='#BEB8B0'), top=dict(kind='shirt', col='#C9B48A', sleeve='short'), bottom=dict(kind='pants', col='#5A4E44'),
   shoe='#7A5A3A', eye=('#8A5A36', '#3E2416'), extras=['glasses_round'], pose={}),
})
N.EXTRA_PAL.update(piece='#EEDFB8', giocho='#D9475A', nilon='#7FB3D9', nilon2='#EF7F9A', rau='#4E9A3A', rau2='#E9C46A')
N.GROUP.update(piece='hard', giocho='hard', nilon='glass', nilon2='glass', nonla='hard')

# ---------------------------------------------------------------- đổi toạ độ thế giới -> khung người
def W(c, P, x, y, z):
    """Điểm thế giới (m) -> toạ độ tay trong khung người (đơn vị 'sc', trước khi nhân s), tính cả ngồi và cúi."""
    h = c['h']; kid = c.get('kid', False); hh = h / (3.9 if kid else 5.1); s = (h - hh) / 1.31
    T = -(0.79 * s - P['sit']) if P.get('sit') else 0.0
    Pu = np.array([0, .92 * s, 0]); Ru = N.rot(0, P.get('bend', 0), 0)
    p = np.array([x, y - T, z]) - Pu
    q = Ru.T @ p + Pu       # upw: Ru @ (j - Pu) + Pu + T  =>  j = Ru^T (w - T - Pu) + Pu
    out = q / s
    return (float(out[0]) / (c['build']['bw'] if abs(out[0]) > .2 else 1), float(out[1]), float(out[2]))

def arm(c, P, side, e, w, n):
    k = 'armL' if side > 0 else 'armR'
    P[k] = dict(e=W(c, P, *e), w=W(c, P, *w), n=n)

def pose(cid, **kw):
    """Tạo dict dáng: kw có thể có armL/armR = (elbow_world, wrist_world, normal)."""
    c = N.CHARS[cid]; P = {k: val for k, val in kw.items() if k not in ('aL', 'aR')}
    if 'aL' in kw: arm(c, P, 1, *kw['aL'])
    if 'aR' in kw: arm(c, P, -1, *kw['aR'])
    return P

# ---------------------------------------------------------------- dáng
def DANG(key):
    D = {
     # --- Ông Bảy (ngồi ghế đá 0,32 m, quay mặt vào bàn cờ ở +z 0,45 m) ---
     'ongbay:danh': lambda: pose('ongbay', sit=.38, ghe=True, bend=.15, nod=.38, yaw=.05, mouth='smile',
                                 aR=((-.22, .7, .14), (-.06, .64, .36), (0, -1, 0)), aL=((.22, .55, .12), (.15, .42, .3), (0, -1, .2)), prop='piece'),
     'ongbay:suyt': lambda: pose('ongbay', sit=.38, ghe=True, bend=.05, nod=.1, yaw=.35, tilt=.05, mouth='o', brow=.4,
                                 aR=((-.2, .66, .16), (-.0, .8, .21), (1, 0, .3)), aL=((.22, .55, .12), (.15, .42, .3), (0, -1, .2))),
     'ongbay:mang': lambda: pose('ongbay', sit=.38, ghe=True, bend=-.05, nod=-.05, yaw=.55, tilt=.08, mouth='shout', brow=1,
                                 aL=((.36, .86, .12), (.52, .9, .34), (0, 0, 1)), aR=((-.24, .62, -.02), (-.2, .55, .12), (1, 0, 0))),
     'ongbay:reo': lambda: pose('ongbay', sit=.38, ghe=True, bend=-.1, nod=-.18, yaw=.1, mouth='open', brow=-.5,
                                aR=((-.33, .93, .06), (-.3, 1.13, .14), (0, 0, 1)), aL=((.33, .93, .06), (.3, 1.13, .14), (0, 0, 1))),
     # --- Ông Tám (ngồi đối diện, tay trái cầm quạt) ---
     'ongtam:danh': lambda: pose('ongtam', sit=.38, ghe=True, bend=.18, nod=.35, yaw=-.05, mouth='smile', prop='fan',
                                 aR=((-.24, .62, .16), (-.05, .55, .38), (0, -1, 0)), aL=((.27, .7, .02), (.24, .9, .12), (-1, 0, .3))),
     'ongtam:suyt': lambda: pose('ongtam', sit=.38, ghe=True, bend=.05, nod=.1, yaw=.35, mouth='o', brow=.4, prop='fan',
                                 aR=((-.2, .66, .16), (-.0, .8, .22), (1, 0, .3)), aL=((.26, .6, .04), (.24, .5, .2), (-1, 0, .3))),
     'ongtam:mang': lambda: pose('ongtam', sit=.38, ghe=True, bend=-.05, nod=-.05, yaw=.55, tilt=.08, mouth='shout', brow=1, prop='fan',
                                 aR=((-.27, .62, .0), (-.22, .55, .14), (1, 0, 0)), aL=((.3, 1.0, .08), (.28, 1.25, .22), (-1, 0, .3))),
     'ongtam:reo': lambda: pose('ongtam', sit=.38, ghe=True, bend=-.1, nod=-.2, yaw=-.1, mouth='open', brow=-.5, prop='fan',
                                aR=((-.34, .93, .06), (-.31, 1.13, .14), (0, 0, 1)), aL=((.34, .93, .06), (.31, 1.13, .14), (-1, 0, .3))),
     # --- Cô Hai đưa túi trứng qua quầy (Bơ đứng trên quầy 0,92 m) ---
     'cohai:duatui': lambda: pose('cohai', bend=.18, nod=.3, yaw=0, mouth='open', aR=((-.22, 1.02, .2), (-.1, 1.12, .45), (1, 0, 0)),
                                  aL=((.24, .96, .02), (.2, .86, .14), (-1, 0, 0)), prop='eggbag'),
     # --- Chú Năm ngồi nghiêng trên yên xe chờ khách ---
     'chunam:choxe': lambda: pose('chunam', sit=.86, bend=-.04, nod=.05, yaw=.35, mouth='smile', knee=(.6, .3), ankle=(.07, .26), kx=.1,
                                  aR=((-.24, .72, .12), (-.12, .62, .3), (0, -1, 0)), aL=((.26, .74, .08), (.16, .62, .3), (0, -1, 0)), bike=True),
     # --- người mới ---
     'xemco:dang': lambda: pose('xemco', bend=.14, nod=.32, yaw=.1, mouth='smile', aR=((-.22, 1.0, -.1), (-.06, .86, -.16), (0, 0, -1)), aL=((.22, 1.0, -.1), (.06, .86, -.16), (0, 0, -1))),
     'xemco:reo': lambda: pose('xemco', bend=-.05, nod=-.1, yaw=.15, mouth='open', brow=-.6, aR=((-.32, 1.36, .08), (-.27, 1.6, .16), (0, 0, 1)), aL=((.24, 1.0, -.1), (.08, .86, -.16), (0, 0, -1))),
     'bancho:dang': lambda: pose('bancho', sit=.26, bend=.12, nod=.12, yaw=-.2, mouth='open', aR=((-.24, .62, .16), (-.14, .7, .34), (0, 1, 0)), aL=((.24, .58, .12), (.12, .66, .32), (0, 1, 0)), prop='rau'),
     'hangrong:dang': lambda: pose('hangrong', bend=.14, nod=.05, mouth='smile', legs=dict(L=((.43, .1), (.08, .2)), R=((.42, -.06), (.12, -.2))),
                                   aR=((-.26, 1.0, .2), (-.24, .92, .44), (1, 0, 0)), aL=((.26, 1.0, .2), (.24, .92, .44), (-1, 0, 0))),
     'ganhhang:dang': lambda: pose('ganhhang', bend=.06, nod=0, yaw=-.15, mouth='open', legs=dict(L=((.43, .1), (.08, .2)), R=((.42, -.06), (.12, -.2))),
                                   aR=((-.3, 1.04, .02), (-.18, 1.24, .12), (1, 0, 0)), aL=((.25, .95, -.06), (.25, .76, .02), (-1, 0, 0)), ganh=True),
     'dicho1:dang': lambda: pose('dicho1', bend=.1, nod=.1, yaw=.2, mouth='smile', aR=((-.24, .92, .02), (-.27, .7, .06), (1, 0, 0)), aL=((.24, .95, .1), (.12, .95, .25), (0, 1, 0)), prop='giocho'),
     'dicho2:dang': lambda: pose('dicho2', bend=0, nod=-.04, yaw=-.25, mouth='smile', aR=((-.27, 1.05, .0), (-.3, .8, .04), (1, 0, 0)), aL=((.27, 1.1, .1), (.13, 1.25, .2), (-1, 0, .3)), prop='tuinilon'),
     'dicho3:dang': lambda: pose('dicho3', bend=.04, nod=.08, yaw=.3, tilt=.06, mouth='smile', aR=((-.22, .96, .1), (-.1, .98, .26), (0, 1, 0)), aL=((.24, .96, -.02), (.27, .74, .02), (-1, 0, 0)), prop='rau'),
    }
    return D[key]()

# ---------------------------------------------------------------- đồ cầm tay (SDF, đi theo thân trên)
_orig_build = N.build
def build(c, posed):
    parts, G, FR, headw = _orig_build(c, posed)
    if not posed: return parts, G, FR, headw
    if c['pose'].get('ghe') or c['pose'].get('bike'): parts[:] = [p for p in parts if p['name'] != 'stool']
    P = c['pose']; s = G['s']; WR = {sd: G['arms'][sd][2] for sd in (1, -1)}; EL = {sd: G['arms'][sd][1] for sd in (1, -1)}
    def add(name, fn, mat, frame='up'): parts.append(dict(name=name, fn=fn, mat=mat, frame=frame, k=.002, sep=True))
    pr = P.get('prop')
    if pr == 'piece':
        w = WR[-1]; d = nrm(w - EL[-1])
        add('piece', lambda p: cyl(p, w + d * .055 * s + v(0, -.015 * s, 0), w + d * .055 * s + v(0, -.001 * s, 0), .019), 'piece')
    if pr == 'giocho':   # giỏ nhựa đi chợ treo dưới tay phải
        w = WR[-1]; bc = w + v(0, -.3, .0)
        def gio(p):
            q = p - bc; b = box(q, v(0, 0, 0), v(.17, .11, .1), .03)
            shell = smax(np.abs(b) - .005, q[..., 1] - .1, .004)
            handle = smax(np.abs(np.linalg.norm((q - v(0, .1, 0))[..., :2] * v(1, .75), axis=-1) - .14) - .007, np.maximum(np.abs(q[..., 2]) - .012, -(q[..., 1] - .1)), .003)
            return smin(shell, handle, .004)
        add('giocho', gio, 'giocho')
        for k in range(4): add('rau', (lambda k: lambda p: roundcone(p, bc + v(-.1 + k * .06, .02, 0), bc + v(-.12 + k * .07, .2, .02 * k), .025, .015))(k), 'rau')
    if pr == 'tuinilon':
        w = WR[-1]; bc = w + v(0, -.2, 0)
        def tui(p):
            q = p - bc; b = ellipsoid(q, v(0, -.02, 0), v(.13, .15, .07))
            shell = smax(np.abs(b) - .003, q[..., 1] - .1, .006)
            h1 = roundcone(p, bc + v(-.06, .08, 0), w + v(0, .01, 0), .008, .008); h2 = roundcone(p, bc + v(.06, .08, 0), w + v(0, .01, 0), .008, .008)
            return smin(shell, np.minimum(h1, h2), .01)
        add('nilon', tui, 'nilon')
        add('rau', lambda p: roundcone(p, bc + v(-.03, .0, 0), bc + v(-.06, .2, .02), .03, .02), 'rau')
    if pr == 'rau':     # bó rau muống ôm trên tay
        a, b = WR[-1] + v(0, .02, -.02), (WR[1] if c['pose'].get('aL') or True else WR[-1]) + v(0, .02, .0)
        mid = (WR[1] + WR[-1]) / 2 + v(0, .03, .03)
        add('rau', lambda p: roundcone(p, mid + v(-.18, .02, 0), mid + v(.18, .05, .02), .05, .07), 'rau')
        add('rau2', lambda p: roundcone(p, mid + v(-.03, .02, 0), mid + v(.0, .025, 0), .055, .055), 'rau2')
    return parts, G, FR, headw
N.build = build

# ---------------------------------------------------------------- vật gắn thêm bằng Blender (túi trứng, xe máy, gánh)
def hook(scn, coll, G, headw, B):
    P = CUR['P']
    if not (P.get('prop') == 'eggbag' or P.get('bike') or P.get('ganh') or P.get('ghe')): return
    import bpy, pk, dscene, do3, kit
    from mathutils import Vector
    pk.sc = scn; pk.item(None); pk._mats.clear()
    FRm, upw, hw = N.frames(G)
    before = set(bpy.data.objects)
    if P.get('prop') == 'eggbag':
        w = upw(G['arms'][-1][2]); d = nrm(G['arms'][-1][2] - G['arms'][-1][1]); w = w + d * .05 * G['s']
        bw = B(w); do3.egg_bag(6, loc=(bw.x, bw.y, bw.z - do3.KNOT_Z - .01))
    if P.get('ganh'):
        sh = upw(N.v(-.17 * G['s'], 1.2 * G['s'], 0)); bs = B(sh)
        do3.ganh((bs.x, bs.y, 0), yz=bs.z + .05, rz=math.pi / 2)
    if P.get('ghe'): do3.ghe_da((0, .02, 0))
    if P.get('bike'):
        kit.PARENT[0] = None; kit.xe_may((.3, -.02, 0), rot=0.0, col='#2E6FA8')
    new = [o for o in bpy.data.objects if o not in before]
    for o in new:
        if P.get('bike') or P.get('ghe'): continue        # xe máy, ghế đá chỉ để render, không xuất vào .glb người
        for cl in list(o.users_collection): cl.objects.unlink(o)
        coll.objects.link(o)
N.HOOKS.append(hook)
CUR = {}

if __name__ == '__main__':
    arg = sys.argv[1]; out = sys.argv[2]; glb = '--glb' in sys.argv
    if ':' in arg:
        cid, dk = arg.split(':')
        P = DANG(arg); N.CHARS[cid]['pose'] = P; CUR['P'] = P
        if dk != 'dang' or not N.CHARS[cid].get('pose_done'):
            pass
        if cid in ('ongbay', 'ongtam', 'cohai', 'chunam') or dk != 'dang':
            N.POSE_ONLY[0] = True; N.SUF[0] = '_' + dk
        N.run(cid, out, glb)
    else:
        P = DANG(arg + ':dang'); N.CHARS[arg]['pose'] = P; CUR['P'] = P
        N.run(arg, out, glb)
