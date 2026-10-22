"""Render ảnh động tác G10 trên bản game của từng mèo (rig 22 xương + phụ kiện game gắn theo điểm gắn trong skin.json).
Cảnh và đèn dùng lại tools/dong_tac_bo/scene.py (sàn, tường lưới 10 cm / 50 cm).
Chạy: python3 make_hoi.py <skin_dir> <out> [tên,tên|all] [--draft]"""
import sys, os, math, json
import numpy as np
import bpy
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
G2 = '/home/user/meo-giao-banh-mi/tools/dong_tac_bo'
sys.path.insert(0, G2); sys.path.insert(0, HERE)
SKIN, OUT = sys.argv[1], sys.argv[2]
WANT = sys.argv[3] if len(sys.argv) > 3 and not sys.argv[3].startswith('--') else 'all'
DRAFT = '--draft' in sys.argv
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
import scene, rig, props   # noqa: E402
import anims_hoi as AH    # noqa: E402
import hoi                # noqa: E402  (chỉ lấy bảng CATS, không dựng SDF)
import nap                # noqa: E402
nap.init(SKIN)
load_cat = nap.load_cat

cam, floor, wall = scene.setup(res=(480, 400), samples=8 if DRAFT else 24)


def show(objs, on):
    for o in objs:
        o.hide_render = not on


CATS = {}
names = list(AH.ANIMS) if WANT == 'all' else WANT.split(',')
need = sorted({AH.ANIMS[n]['who'] for n in names})
for cid in need:
    arm, objs = load_cat(cid)
    CATS[cid] = (arm, rig.Rig(arm, prefix=cid + '_'), objs)
    show(objs, False)

gm = scene.mat('Tam', '#B9B4AA', rough=.9)
crate = props.rbox('ThungTam', (.5, .42, .4), (0, -.02, .2), scene.mat('GoTam', '#A9805A', rough=.85), .01, 2)
board = props.rbox('BangTam', (.2, .012, .14), (0, 0, 0), gm, .006, 2)
medal = props.huy_chuong()
for o in (crate, board, *medal):
    o.hide_render = True


def place_board(arm):
    pb = arm.pose.bones['paw_FR']
    m = arm.matrix_world @ pb.matrix
    tip = arm.matrix_world @ pb.tail
    board.matrix_world = Matrix.Translation(tip + Vector((0, -.01, .09))) @ Matrix.Rotation(math.radians(-8), 4, 'X')


def place_medal(arm):
    a = arm.matrix_world @ arm.pose.bones['paw_FL'].tail
    b = arm.matrix_world @ arm.pose.bones['paw_FR'].tail
    mid = (a + b) / 2
    ring, disc = medal
    ring.matrix_world = Matrix.Translation(mid + Vector((0, 0, -.095 * .8))) @ Matrix.Rotation(math.radians(-90), 4, 'X') @ Matrix.Diagonal((.75, .75, .75, 1))
    disc.matrix_world = Matrix.Translation(mid + Vector((0, 0, -.19))) @ Matrix.Rotation(math.radians(90), 4, 'X')


def pose_at(an, t, arm, R):
    keys = [(k, rig.full(dict(an.get('base', {}), **d))) for k, d in an['keys']]
    p = rig.sample(keys, t)
    R.modes = {k: an.get('modes', {}).get(k, 'w') for k in rig.LEGS}
    R.apply(p)
    bpy.context.view_layer.update()
    if 'bang' in an.get('props', ()):
        place_board(arm)
    if 'medal' in an.get('props', ()):
        on = p.get('medal', (0,))[0] > .5
        show(medal, on)
        if on:
            place_medal(arm)
    return p


for name in names:
    an = AH.ANIMS[name]
    arm, R, objs = CATS[an['who']]
    for c, (a2, R2, o2) in CATS.items():
        show(o2, c == an['who'])
    up = .4 if an.get('ctx') == 'thung' else 0
    arm.location.z = up
    crate.hide_render = not up
    board.hide_render = 'bang' not in an.get('props', ())
    show(medal, False)
    cen = (0, 0, .27 + up * .5)
    sc = 1.0 + up * .9
    cen = an.get('center', cen); sc = an.get('scale', sc)
    for i, t in enumerate(an['shots']):
        pose_at(an, t, arm, R)
        scene.shoot(cam, wall, an.get('strip_view', 'q34'), f'{OUT}/{name}_k{i}.png', cen, sc, res=(480, 400))
    pose_at(an, an['main'], arm, R)
    for vw in an.get('views', ('q34', 'side', 'front', 'back')):
        scene.shoot(cam, wall, vw, f'{OUT}/{name}_{vw}.png', cen, sc, res=(640, 540))
    print('xong', name, flush=True)
