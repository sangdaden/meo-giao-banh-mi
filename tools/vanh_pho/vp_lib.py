"""Thư viện chung cho phác thảo vành phố (P1).
Toạ độ viết theo Godot: x đông, y lên, z nam. Khi tạo lưới Blender đổi (x, y, z) -> (x, -z, y).
Mọi khối gom vào 'Chunk' (một lưới, một vật liệu màu đỉnh RGBA; A = mặt kính sáng đèn ban đêm)."""
import math, random, os
import bpy
from mathutils import Vector


def hexc(h, a=0.0):
    h = h.lstrip('#')
    return [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)] + [a]


def lin(h):
    def f(c): return c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4
    r, g, b, _ = hexc(h)
    return (f(r), f(g), f(b), 1)


def shade(col, k):
    return [min(1, c * k) for c in col[:3]] + [col[3]]


def mix(a, b, t):
    return [a[i] * (1 - t) + b[i] * t for i in range(3)] + [a[3]]


class Chunk:
    def __init__(self, name):
        self.name = name; self.v = []; self.f = []; self.c = []

    @property
    def tris(self):
        return sum(len(f) - 2 for f in self.f)

    def poly(self, pts, col):
        i = len(self.v); self.v += [tuple(p) for p in pts]
        self.f.append(tuple(range(i, i + len(pts)))); self.c.append(list(col))

    def quad(self, a, b, c, d, col):
        self.poly([a, b, c, d], col)

    def box(self, c, s, col, rot=0.0, bottom=False, top=True, sides=(1, 1, 1, 1), tint=True):
        """Hộp tâm c (x, y-giữa, z), cỡ s. sides: (bắc -z, nam +z, tây -x, đông +x)."""
        x, y, z = c; hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2
        cr, sr = math.cos(rot), math.sin(rot)
        def P(dx, dy, dz):
            return (x + dx * cr + dz * sr, y + dy, z - dx * sr + dz * cr)
        p = [P(-hx, -hy, -hz), P(hx, -hy, -hz), P(hx, -hy, hz), P(-hx, -hy, hz),
             P(-hx, hy, -hz), P(hx, hy, -hz), P(hx, hy, hz), P(-hx, hy, hz)]
        k = (lambda t: shade(col, t)) if tint else (lambda t: col)
        if top: self.quad(p[4], p[7], p[6], p[5], k(1.0))
        if bottom: self.quad(p[0], p[1], p[2], p[3], k(.7))
        if sides[0]: self.quad(p[0], p[4], p[5], p[1], k(.92))
        if sides[1]: self.quad(p[3], p[2], p[6], p[7], k(.97))
        if sides[2]: self.quad(p[0], p[3], p[7], p[4], k(.88))
        if sides[3]: self.quad(p[1], p[5], p[6], p[2], k(.94))

    def cyl(self, base, r, h, col, n=8, top=True, r2=None):
        r2 = r if r2 is None else r2
        x, y, z = base
        lo = [(x + r * math.cos(a), y, z + r * math.sin(a)) for a in [i * 2 * math.pi / n for i in range(n)]]
        hi = [(x + r2 * math.cos(a), y + h, z + r2 * math.sin(a)) for a in [i * 2 * math.pi / n for i in range(n)]]
        for i in range(n):
            j = (i + 1) % n
            self.quad(lo[i], hi[i], hi[j], lo[j], shade(col, .85 + .15 * math.cos(i * 2 * math.pi / n)))
        if top: self.poly(hi[::-1], col)

    def blob(self, c, s, col, n=6, rings=3):
        """Khối tròn thấp (tán cây), n cạnh x rings tầng."""
        x, y, z = c
        pts = []
        for k in range(1, rings):
            t = math.pi * k / rings
            pts.append([(x + s[0] * math.sin(t) * math.cos(a), y + s[1] * math.cos(t), z + s[2] * math.sin(t) * math.sin(a))
                        for a in [(i + .5 * k) * 2 * math.pi / n for i in range(n)]])
        top = (x, y + s[1], z); bot = (x, y - s[1], z)
        for i in range(n):
            j = (i + 1) % n
            self.poly([top, pts[0][j], pts[0][i]], shade(col, 1.05))
            for k in range(rings - 2):
                self.quad(pts[k][i], pts[k][j], pts[k + 1][j], pts[k + 1][i], shade(col, .95 - .1 * k))
            self.poly([bot, pts[-1][i], pts[-1][j]], shade(col, .7))

    def strip(self, pts, w, y, col, start=0.0):
        """Dải phẳng theo polyline 2D (x, z), rộng w, cao y."""
        def nrm(a, b):
            dx, dz = b[0] - a[0], b[1] - a[1]; L = math.hypot(dx, dz)
            return (-dz / L, dx / L)
        n = len(pts); L = []; R = []
        for i in range(n):
            if i == 0: nx, nz = nrm(pts[0], pts[1])
            elif i == n - 1: nx, nz = nrm(pts[-2], pts[-1])
            else:
                a = nrm(pts[i - 1], pts[i]); b = nrm(pts[i], pts[i + 1])
                nx, nz = a[0] + b[0], a[1] + b[1]; l = math.hypot(nx, nz); nx, nz = nx / l, nz / l
                d = nx * a[0] + nz * a[1]; nx, nz = nx / d, nz / d
            L.append((pts[i][0] + nx * w / 2, y, pts[i][1] + nz * w / 2))
            R.append((pts[i][0] - nx * w / 2, y, pts[i][1] - nz * w / 2))
        for i in range(n - 1):
            self.quad(R[i], R[i + 1], L[i + 1], L[i], col)

    def build(self, mat, coll=None):
        me = bpy.data.meshes.new(self.name)
        vb = [(x, -z, y) for (x, y, z) in self.v]
        me.from_pydata(vb, [], self.f)
        me.update()
        at = me.color_attributes.new('Col', 'FLOAT_COLOR', 'CORNER')
        k = 0
        for fi, poly in enumerate(me.polygons):
            col = self.c[fi]
            for li in poly.loop_indices:
                at.data[li].color = (*[lin_c(c) for c in col[:3]], col[3])
        o = bpy.data.objects.new(self.name, me)
        (coll or bpy.context.scene.collection).objects.link(o)
        me.materials.append(mat)
        return o


def lin_c(c):
    return c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4


# ----------------------------------------------------------- vật liệu + sương (giống Godot: trộn theo khoảng cách)
FOG = {'k': None}


def _fog_wrap(nt, shader_out, out_node):
    """Trộn shader với màu sương theo 1 - exp(-d * mật độ). Mật độ, màu lấy từ node group 'Suong'."""
    n = nt.nodes; l = nt.links
    g = n.new('ShaderNodeGroup'); g.node_tree = fog_group()
    m = n.new('ShaderNodeMixShader')
    l.new(g.outputs['Fac'], m.inputs[0]); l.new(shader_out, m.inputs[1]); l.new(g.outputs['Shader'], m.inputs[2])
    l.new(m.outputs[0], out_node.inputs['Surface'])


def fog_group():
    if 'Suong' in bpy.data.node_groups: return bpy.data.node_groups['Suong']
    g = bpy.data.node_groups.new('Suong', 'ShaderNodeTree')
    g.interface.new_socket('Fac', in_out='OUTPUT', socket_type='NodeSocketFloat')
    g.interface.new_socket('Shader', in_out='OUTPUT', socket_type='NodeSocketShader')
    n = g.nodes; l = g.links
    out = n.new('NodeGroupOutput')
    cam = n.new('ShaderNodeCameraData')
    dens = n.new('ShaderNodeValue'); dens.name = 'density'; dens.outputs[0].default_value = .006
    mul = n.new('ShaderNodeMath'); mul.operation = 'MULTIPLY'
    l.new(cam.outputs['View Distance'], mul.inputs[0]); l.new(dens.outputs[0], mul.inputs[1])
    neg = n.new('ShaderNodeMath'); neg.operation = 'MULTIPLY'; neg.inputs[1].default_value = -1
    l.new(mul.outputs[0], neg.inputs[0])
    ex = n.new('ShaderNodeMath'); ex.operation = 'EXPONENT'; l.new(neg.outputs[0], ex.inputs[0])
    one = n.new('ShaderNodeMath'); one.operation = 'SUBTRACT'; one.inputs[0].default_value = 1
    l.new(ex.outputs[0], one.inputs[1])
    mx = n.new('ShaderNodeMath'); mx.operation = 'MULTIPLY'; mx.inputs[1].default_value = .92
    l.new(one.outputs[0], mx.inputs[0])
    l.new(mx.outputs[0], out.inputs['Fac'])
    col = n.new('ShaderNodeRGB'); col.name = 'color'; col.outputs[0].default_value = (.8, .8, .8, 1)
    em = n.new('ShaderNodeEmission'); l.new(col.outputs[0], em.inputs['Color'])
    st = n.new('ShaderNodeValue'); st.name = 'strength'; st.outputs[0].default_value = 1
    l.new(st.outputs[0], em.inputs['Strength'])
    l.new(em.outputs[0], out.inputs['Shader'])
    return g


def set_fog(color, density, strength=1.0):
    g = fog_group()
    g.nodes['color'].outputs[0].default_value = lin(color)
    g.nodes['density'].outputs[0].default_value = density
    g.nodes['strength'].outputs[0].default_value = strength


def glow_group():
    if 'Den' in bpy.data.node_groups: return bpy.data.node_groups['Den']
    g = bpy.data.node_groups.new('Den', 'ShaderNodeTree')
    g.interface.new_socket('k', in_out='OUTPUT', socket_type='NodeSocketFloat')
    v = g.nodes.new('ShaderNodeValue'); v.name = 'k'; v.outputs[0].default_value = 0
    o = g.nodes.new('NodeGroupOutput'); g.links.new(v.outputs[0], o.inputs['k'])
    return g


def set_glow(k):
    glow_group().nodes['k'].outputs[0].default_value = k


def mat_vc(name='VanhPho', rough=.85, wet=False):
    """Vật liệu màu đỉnh: Col.rgb = màu, Col.a = kính sáng đèn ban đêm."""
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; n = nt.nodes; l = nt.links
    for x in list(n): n.remove(x)
    out = n.new('ShaderNodeOutputMaterial')
    at = n.new('ShaderNodeAttribute'); at.attribute_name = 'Col'
    bs = n.new('ShaderNodeBsdfPrincipled'); bs.inputs['Roughness'].default_value = rough
    l.new(at.outputs['Color'], bs.inputs['Base Color'])
    gg = n.new('ShaderNodeGroup'); gg.node_tree = glow_group()
    mul = n.new('ShaderNodeMath'); mul.operation = 'MULTIPLY'
    l.new(at.outputs['Alpha'], mul.inputs[0]); l.new(gg.outputs['k'], mul.inputs[1])
    ec = n.new('ShaderNodeRGB'); ec.outputs[0].default_value = lin('#FFC27A')
    l.new(ec.outputs[0], bs.inputs['Emission Color']); l.new(mul.outputs[0], bs.inputs['Emission Strength'])
    if wet:
        bs.inputs['Roughness'].default_value = .25
    _fog_wrap(nt, bs.outputs[0], out)
    return m


def mat_flat(name, col, rough=.6, metal=0.0, alpha=1.0, emit=None, es=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; n = nt.nodes; l = nt.links
    for x in list(n): n.remove(x)
    out = n.new('ShaderNodeOutputMaterial')
    bs = n.new('ShaderNodeBsdfPrincipled')
    bs.inputs['Base Color'].default_value = lin(col); bs.inputs['Roughness'].default_value = rough
    bs.inputs['Metallic'].default_value = metal
    if emit:
        bs.inputs['Emission Color'].default_value = lin(emit); bs.inputs['Emission Strength'].default_value = es
    _fog_wrap(nt, bs.outputs[0], out)
    return m


# ----------------------------------------------------------- trời + đèn theo buổi (khớp scripts/anh_sang.gd)
BUOI = {
    'sang': dict(top='#5FA6CF', hor='#F6D3A4', fog='#F3D8B4', dens=.0045, sun='#FFD7A3', se=3.2, el=24, az=60,
                 fill='#A9D4E0', fe=.6, amb=.9, glow=0, lamp=0, wet=False),
    'chieu': dict(top='#6E8FB5', hor='#E3A985', fog='#E8B48F', dens=.005, sun='#FFB27A', se=2.8, el=12, az=-110,
                  fill='#8FA6D0', fe=.5, amb=.8, glow=.6, lamp=0, wet=False),
    'mua': dict(top='#6D7B86', hor='#9AA7AE', fog='#A9B3B8', dens=.012, sun='#D9E2E8', se=.7, el=55, az=30,
                fill='#B7C4CC', fe=.9, amb=1.3, glow=.9, lamp=0, wet=True),
    'toi': dict(top='#0E1530', hor='#1E2A48', fog='#1E2A48', dens=.008, sun='#9FB4E8', se=.45, el=40, az=150,
                fill='#4A5A8A', fe=.25, amb=.35, glow=6, lamp=1, wet=False),
}


def setup_world(sc, b):
    p = BUOI[b]
    w = sc.world or bpy.data.worlds.new('W'); sc.world = w; w.use_nodes = True
    nt = w.node_tree; n = nt.nodes; l = nt.links
    for x in list(n): n.remove(x)
    out = n.new('ShaderNodeOutputWorld'); bg = n.new('ShaderNodeBackground')
    tc = n.new('ShaderNodeTexCoord'); sp = n.new('ShaderNodeSeparateXYZ')
    l.new(tc.outputs['Generated'], sp.inputs[0])
    mr = n.new('ShaderNodeMapRange'); mr.inputs['From Min'].default_value = 0; mr.inputs['From Max'].default_value = .55
    l.new(sp.outputs['Z'], mr.inputs['Value'])
    cr = n.new('ShaderNodeValToRGB')
    cr.color_ramp.elements[0].color = lin(p['hor']); cr.color_ramp.elements[1].color = lin(p['top'])
    cr.color_ramp.elements[1].position = .8
    l.new(mr.outputs[0], cr.inputs[0]); l.new(cr.outputs[0], bg.inputs['Color'])
    bg.inputs['Strength'].default_value = p['amb']
    l.new(bg.outputs[0], out.inputs['Surface'])
    for o in [o for o in sc.objects if o.type == 'LIGHT' and o.name.startswith('B_')]:
        bpy.data.objects.remove(o)
    def sun(name, col, e, el, az, shadow=True, ang=.05):
        ld = bpy.data.lights.new(name, 'SUN'); ld.energy = e; ld.color = lin(col)[:3]; ld.angle = ang
        ld.use_shadow = shadow
        o = bpy.data.objects.new(name, ld); sc.collection.objects.link(o)
        # az: góc từ hướng đông (+x Godot) quay về bắc; mặt trời ở hướng đó chiếu ngược lại
        o.rotation_euler = (math.radians(90 - el), 0, math.radians(az + 90))
        return o
    sun('B_sun', p['sun'], p['se'], p['el'], p['az'], ang=.08 if b != 'mua' else .5)
    sun('B_fill', p['fill'], p['fe'], 35, p['az'] + 180, shadow=False)
    set_fog(p['fog'], p['dens'])
    set_glow(p['glow'])
    return p


def eevee(sc, samples=48):
    # Máy dựng không có GPU: Eevee chạy qua llvmpipe rất chậm, nên cảnh lớn render bằng Cycles CPU (cùng vật liệu)
    if os.environ.get('P1_EEVEE') != '1':
        sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = max(16, samples // 2)
        sc.cycles.use_denoising = True; sc.cycles.max_bounces = 4; sc.cycles.diffuse_bounces = 2
        sc.cycles.glossy_bounces = 2; sc.cycles.transparent_max_bounces = 8
        sc.view_settings.view_transform = 'Standard'; sc.view_settings.look = 'None'
        return
    sc.render.engine = 'BLENDER_EEVEE'
    try: sc.eevee.taa_render_samples = samples
    except Exception: pass
    for k, v in (('use_shadows', True), ('use_raytracing', False), ('use_gtao', True)):
        try: setattr(sc.eevee, k, v)
        except Exception: pass
    try: sc.eevee.shadow_resolution_scale = 1.0
    except Exception: pass
    sc.view_settings.view_transform = 'AgX'
    try: sc.view_settings.look = 'AgX - Base Contrast'
    except Exception: pass


def look(cam, loc, tgt, lens=30, ortho=None, gz=True):
    """loc, tgt theo Godot (x, y, z)."""
    if gz:
        loc = (loc[0], -loc[2], loc[1]); tgt = (tgt[0], -tgt[2], tgt[1])
    cam.location = Vector(loc)
    cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    cd = cam.data
    if ortho: cd.type = 'ORTHO'; cd.ortho_scale = ortho
    else: cd.type = 'PERSP'; cd.lens = lens
    cd.clip_start = .1; cd.clip_end = 3000


def render(path, w=1600, h=900):
    sc = bpy.context.scene; sc.render.resolution_x = w; sc.render.resolution_y = h
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = 'PNG'
    sc.render.filepath = path; bpy.ops.render.render(write_still=True); print('saved', path, flush=True)
