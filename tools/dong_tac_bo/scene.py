"""Cảnh render phác thảo phong cách D: đèn như mature.py (Bơ chuẩn), sàn và tường sau có lưới mét (ô 10 cm, vạch đậm 50 cm)."""
import math
import numpy as np
import bpy
from mathutils import Vector


def lin(h, a=1.0):
    h = h.lstrip('#')
    c = np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)])
    c = np.where(c <= .04045, c / 12.92, ((c + .055) / 1.055) ** 2.4)
    return (*c, a)


def mat(name, color, rough=.7, sheen=0., metal=0., emit=0.):
    m = bpy.data.materials.new(name)
    if m.node_tree is None:
        m.use_nodes = True
    bs = m.node_tree.nodes['Principled BSDF']
    bs.inputs['Base Color'].default_value = lin(color)
    bs.inputs['Roughness'].default_value = rough
    bs.inputs['Metallic'].default_value = metal
    bs.inputs['Sheen Weight'].default_value = sheen
    if emit:
        bs.inputs['Emission Color'].default_value = lin(color)
        bs.inputs['Emission Strength'].default_value = emit
    return m


def grid_mat(name, base, line, major):
    """Lưới theo toạ độ object (mét): vạch mảnh mỗi 10 cm, vạch đậm mỗi 50 cm."""
    m = bpy.data.materials.new(name)
    if m.node_tree is None:
        m.use_nodes = True
    N, L = m.node_tree.nodes, m.node_tree.links
    bs = N['Principled BSDF']
    bs.inputs['Roughness'].default_value = 1
    tc = N.new('ShaderNodeTexCoord')
    sp = N.new('ShaderNodeSeparateXYZ')
    L.new(tc.outputs['Object'], sp.inputs[0])

    def lines(axis, step, width):
        a = N.new('ShaderNodeMath'); a.operation = 'DIVIDE'; a.inputs[1].default_value = step
        L.new(sp.outputs[axis], a.inputs[0])
        b = N.new('ShaderNodeMath'); b.operation = 'ADD'; b.inputs[1].default_value = .5; L.new(a.outputs[0], b.inputs[0])
        c = N.new('ShaderNodeMath'); c.operation = 'FRACT'; L.new(b.outputs[0], c.inputs[0])
        d = N.new('ShaderNodeMath'); d.operation = 'SUBTRACT'; d.inputs[1].default_value = .5; L.new(c.outputs[0], d.inputs[0])
        e = N.new('ShaderNodeMath'); e.operation = 'ABSOLUTE'; L.new(d.outputs[0], e.inputs[0])
        f = N.new('ShaderNodeMath'); f.operation = 'LESS_THAN'; f.inputs[1].default_value = width / step; L.new(e.outputs[0], f.inputs[0])
        return f.outputs[0]

    def mx(a, b):
        n = N.new('ShaderNodeMath'); n.operation = 'MAXIMUM'; L.new(a, n.inputs[0]); L.new(b, n.inputs[1]); return n.outputs[0]

    minor = mx(lines(0, .1, .0018), lines(1, .1, .0018))
    big = mx(lines(0, .5, .004), lines(1, .5, .004))
    m1 = N.new('ShaderNodeMix'); m1.data_type = 'RGBA'
    m1.inputs[6].default_value = lin(base); m1.inputs[7].default_value = lin(line)
    L.new(minor, m1.inputs['Factor'])
    m2 = N.new('ShaderNodeMix'); m2.data_type = 'RGBA'
    L.new(m1.outputs[2], m2.inputs[6]); m2.inputs[7].default_value = lin(major)
    L.new(big, m2.inputs['Factor'])
    L.new(m2.outputs[2], bs.inputs['Base Color'])
    return m


def setup(res=(900, 720), samples=32):
    sc = bpy.context.scene
    bpy.ops.mesh.primitive_plane_add(size=12)
    fl = bpy.context.active_object; fl.name = 'San'
    fl.data.materials.append(grid_mat('LuoiSan', '#8CBFB4', '#76A99E', '#4F8578'))
    bpy.ops.mesh.primitive_plane_add(size=12, location=(0, 3, 0), rotation=(math.pi / 2, 0, 0))
    wl = bpy.context.active_object; wl.name = 'Tuong'
    wl.data.materials.append(grid_mat('LuoiTuong', '#9CCBC1', '#88B7AD', '#5E9187'))
    w = bpy.data.worlds.new('W'); sc.world = w
    if w.node_tree is None:
        w.use_nodes = True
    w.node_tree.nodes['Background'].inputs['Color'].default_value = lin('#9CCBC1')
    w.node_tree.nodes['Background'].inputs['Strength'].default_value = .55

    def light(name, kind, loc, target, power, size=1.0, color=(1, 1, 1)):
        l = bpy.data.lights.new(name, kind); l.energy = power; l.color = color
        if kind == 'AREA': l.size = size
        if kind == 'SUN': l.angle = .25
        o = bpy.data.objects.new(name, l); sc.collection.objects.link(o); o.location = loc
        o.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    light('Key', 'SUN', (1.2, -1.2, 2.0), (0, 0, .25), 1.7, color=(1, .97, .92))
    light('Fill', 'AREA', (-1.5, -.8, .9), (0, 0, .3), 60, 2.0, (.9, .95, 1))
    light('Rim', 'AREA', (-.3, 1.6, 1.2), (0, 0, .3), 90, 1.0)
    sc.render.engine = 'BLENDER_EEVEE'
    try: sc.eevee.taa_render_samples = samples
    except Exception: pass
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.view_settings.view_transform = 'Standard'
    cd = bpy.data.cameras.new('Cam'); cam = bpy.data.objects.new('Cam', cd); sc.collection.objects.link(cam); sc.camera = cam
    return cam, fl, wl


# Góc nhìn: q34 (phối cảnh 3/4), side/front/back (chiếu thẳng, đo được trên lưới), top
VIEWS = {'q34': ((1.0, -1.2, .65), None, 50), 'side': ((2.0, 0, .3), 1.0, 0), 'front': ((0, -2.0, .3), 1.0, 0),
         'back': ((0, 2.0, .3), 1.0, 0), 'top': ((0, 0, 2.2), 1.0, 0), 'q34b': ((-1.0, 1.2, .65), None, 50),
         'q34r': ((1.25, .9, .8), None, 50), 'q34f': ((-1.0, -1.2, .65), None, 50), 'q34l': ((-1.25, .9, .8), None, 50)}


def shoot(cam, wall, view, path, center=(0, 0, .27), scale=1.0, res=None):
    sc = bpy.context.scene
    if res:
        sc.render.resolution_x, sc.render.resolution_y = res
    loc, ortho, lens = VIEWS[view]
    c = Vector(center)
    loc = c + (Vector(loc) - Vector((0, 0, .27))) * (scale if not ortho else 1)
    cam.location = loc
    up = 'Y'
    cam.rotation_euler = (c - loc).to_track_quat('-Z', up).to_euler()
    cd = cam.data
    if ortho:
        cd.type = 'ORTHO'; cd.ortho_scale = ortho * scale
    else:
        cd.type = 'PERSP'; cd.lens = lens
    # tường lưới luôn nằm sau mèo, vuông góc hướng nhìn (để đo chiều cao trên ảnh chiếu thẳng)
    d = Vector((loc.x - c.x, loc.y - c.y, 0))
    if view == 'top' or d.length < 1e-6:
        wall.hide_render = True
    else:
        wall.hide_render = False
        d.normalize()
        wall.location = Vector((c.x, c.y, 0)) - d * 1.2
        wall.rotation_euler = (math.pi / 2, 0, math.atan2(d.x, -d.y))
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
