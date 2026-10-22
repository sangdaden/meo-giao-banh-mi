"""Nạp bản game của một mèo hội (thân + rig 22 xương + phụ kiện game theo điểm gắn trong skin.json) vào cảnh Blender."""
import sys, os, json
import numpy as np
import bpy
from mathutils import Vector, Matrix
sys.path.insert(0, '/home/user/meo-giao-banh-mi/tools/dong_tac_bo'); sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import props, hoi
SKIN = None; META = None
Cb = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))   # three.js (Y lên, nhìn +Z) -> Blender (Z lên, nhìn -Y)


def init(skin):
    global SKIN, META
    SKIN = skin; META = json.load(open(f'{skin}/skin.json'))


def render_look(meshes):
    """Chỉ cho ảnh phác thảo: chất liệu như hướng dẫn D (glTF nhập vào mặc định bóng hơn), mặt mịn, chia lưới 1 bậc sau xương."""
    for o in meshes:
        for m in o.data.materials:
            if not m or not m.node_tree:
                continue
            bs = m.node_tree.nodes.get('Principled BSDF')
            if not bs:
                continue
            nm = m.name.lower()
            if nm.startswith('long') or nm.startswith('than'):
                vals = dict(Roughness=.78, **{'Sheen Weight': .45, 'Specular IOR Level': .3})
            elif 'iris' in nm or 'trong' in nm or 'kinh' in nm:
                vals = {'Roughness': .05, 'Coat Weight': 1}
            elif bs.inputs['Metallic'].default_value > .5:
                vals = {'Roughness': .38}
            else:
                vals = dict(Roughness=.9, **{'Sheen Weight': 1, 'Specular IOR Level': .3})
            for k_, v_ in vals.items():
                bs.inputs[k_].default_value = v_
        if 'sharp_face' in o.data.attributes:
            o.data.attributes.remove(o.data.attributes['sharp_face'])
        if o.name.startswith('Meo'):
            md = o.modifiers.new('Min', 'SUBSURF'); md.levels = 1; md.render_levels = 1


def load_cat(cid):
    name, bid, g, accs, *_ = hoi.CATS[cid]
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=f'{SKIN}/giong/{bid}_{g}.glb')
    new = [o for o in bpy.data.objects if o not in before]
    arm = next(o for o in new if o.type == 'ARMATURE')
    render_look([o for o in new if o.type == 'MESH'])
    gi = META['giong'][f'{bid}_{g}']; k = gi['size']
    HR = np.array(gi['basis']).reshape(3, 3).T
    piv = np.array(gi['pivot']) / k; hc = np.array(gi['hc']) / k
    hw = HR @ (hc - piv) + piv
    for aid in accs:
        b4 = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=f'{SKIN}/phu_kien/{aid}.glb')
        objs = [o for o in bpy.data.objects if o not in b4 and o.type == 'MESH']
        for o in objs:
            o.parent = None
            sock = META['phu_kien'][aid]['objects'].get(o.name.split('.')[0], {}).get('sock', 'neck')
            if sock == 'head':
                R = Cb @ Matrix(HR.tolist()) @ Cb.transposed()
                t = Cb @ Vector((hw * k).tolist())
                o.matrix_world = Matrix.Translation(t) @ R.to_4x4() @ Matrix.Scale(k, 4)
                bone = 'head'
            else:
                t = Cb @ Vector(gi['sockets'][sock])
                o.matrix_world = Matrix.Translation(t) @ Matrix.Scale(k, 4)
                bone = {'neck': 'chest', 'back': 'chest', 'shoulder': 'chest'}.get(sock, 'tail_2' if sock == 'tail_mid' else 'tail_4' if sock == 'tail_tip' else 'chest')
            props.parent_bone(o, arm, bone)
            new.append(o)
    return arm, new


