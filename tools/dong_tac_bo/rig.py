"""Điều khiển bộ xương chính thức 22 xương của Bơ trong Blender (dùng chung cho ảnh phác thảo và bản xuất glb).

Mọi góc tính trong hệ model (độ), xoay quanh khớp gốc của từng xương, cộng dồn theo xương cha:
  p = ngẩng lên (+) / cúi xuống (-), y = quay sang +X (+), r = nghiêng (lăn) quanh trục trước sau.
Toạ độ dịch: V(phải, lên, trước) theo mét. Toạ độ Blender: X phải, -Y trước, Z lên.
Chân dùng IK 2 đoạn của Blender: đặt điểm cổ chân (so với cổ chân lúc đứng) và độ nghiêng bàn chân.
  mode 'w': điểm cổ chân đứng yên theo thế giới (chân bám đất, bám mép); 'b': đi theo thân (chân co, đung đưa).
"""
import math
import bpy
from mathutils import Vector, Quaternion, Matrix

LEGS = {'FL': ('upperarm_FL', 'forearm_FL', 'paw_FL', 'chest'), 'FR': ('upperarm_FR', 'forearm_FR', 'paw_FR', 'chest'),
        'BL': ('thigh_BL', 'shin_BL', 'paw_BL', 'hips'), 'BR': ('thigh_BR', 'shin_BR', 'paw_BR', 'hips')}
TAIL = ['tail_1', 'tail_2', 'tail_3', 'tail_4']


def V(r=0., u=0., f=0.):
    return Vector((r, -f, u))


def Q(p=0., y=0., r=0.):
    return (Quaternion((0, 0, 1), math.radians(y)) @ Quaternion((1, 0, 0), -math.radians(p))
            @ Quaternion((0, -1, 0), math.radians(r)))


# Tư thế trung tính: mọi số 0, chân 'w', mắt mở
def neutral():
    p = {'root': (0, 0, 0, 0, 0, 0), 'hips': (0, 0, 0), 'chest': (0, 0, 0), 'head': (0, 0, 0),
         'earL': (0, 0, 0), 'earR': (0, 0, 0), 'tail': (0,) * 8, 'eye': (1.0,), 'scarf': (0, 0, 0)}
    for k in LEGS:
        p[k] = (0, 0, 0, 0)   # dịch cổ chân (phải, lên, trước), nghiêng bàn chân
    return p


class Rig:
    def __init__(self, arm, prefix=''):
        self.arm = arm
        self.B = arm.data.bones
        self.P = arm.pose.bones
        self.modes = {k: 'w' for k in LEGS}
        self.tgt = {}
        for k, (b1, b2, b3, par) in LEGS.items():
            e = bpy.data.objects.new(f'{prefix}T_{k}', None)
            bpy.context.scene.collection.objects.link(e)
            e.empty_display_size = .02
            self.tgt[k] = e
            c = self.P[b2].constraints.new('IK')
            c.target = e
            c.chain_count = 2
            c.use_tail = True
            c.use_stretch = False
            r = self.P[b3].constraints.new('COPY_ROTATION')
            r.target = e
            for n in (b1, b2, b3):
                self.P[n].rotation_mode = 'QUATERNION'
        for pb in self.P:
            pb.rotation_mode = 'QUATERNION'

    def rest_q(self, n):
        return self.B[n].matrix_local.to_quaternion()

    def set_rot(self, n, q):
        R = self.rest_q(n)
        self.P[n].rotation_quaternion = R.inverted() @ q @ R

    def apply(self, pose):
        P = self.P
        x, y, z, rp, ry, rr = pose['root']
        R = self.rest_q('root')
        P['root'].location = R.inverted() @ V(x, y, z)
        self.set_rot('root', Q(rp, ry, rr))
        for n in ('hips', 'chest', 'head', 'scarf'):
            self.set_rot(n, Q(*pose[n]))
        self.set_rot('ear_L', Q(*pose['earL']))
        self.set_rot('ear_R', Q(*pose['earR']))
        t = pose['tail']
        for i, n in enumerate(TAIL):
            self.set_rot(n, Q(-t[2 * i], t[2 * i + 1], 0))   # đuôi: số dương = nhấc lên
        o = max(pose['eye'][0], .08)
        for n in ('eye_L', 'eye_R'):
            P[n].scale = (1, o, 1)
        bpy.context.view_layer.update()
        mw = self.arm.matrix_world
        for k, (b1, b2, b3, par) in LEGS.items():
            dx, dy, dz, tilt = pose[k]
            ankle = self.B[b2].tail_local + V(dx, dy, dz)
            rot = Q(tilt) @ self.rest_q(b3)
            if self.modes[k] == 'b':
                rel = P[par].matrix @ self.B[par].matrix_local.inverted()
                ankle = rel @ ankle
                rot = rel.to_quaternion() @ rot
            self.tgt[k].matrix_world = mw @ (Matrix.Translation(ankle) @ rot.to_matrix().to_4x4())
        bpy.context.view_layer.update()


def lerp_pose(a, b, t):
    return {k: tuple(x + (y - x) * t for x, y in zip(a[k], b[k])) for k in a}


def full(d):
    p = neutral()
    for k, val in d.items():
        p[k] = tuple(val) + p[k][len(val):] if k in p else tuple(val)
    return p


def sample(keys, time, loop=False):
    """keys: [(giây, pose đầy đủ)], nội suy mượt (smoothstep) giữa hai khoá."""
    if time <= keys[0][0]:
        return keys[0][1]
    for (t0, a), (t1, b) in zip(keys, keys[1:]):
        if time <= t1:
            u = (time - t0) / max(t1 - t0, 1e-6)
            u = u * u * (3 - 2 * u)
            return lerp_pose(a, b, u)
    return keys[-1][1]
