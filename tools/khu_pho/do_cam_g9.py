"""Đồ cầm tay mới của người dân Thứ Bảy (trang G9 "Người dân Thứ Bảy", Sang duyệt 22/10).
Cùng hình SDF với g9nguoi.build của trang phác thảo, nhưng dựng riêng từng món quanh gốc là chỗ bàn tay cầm,
để game gắn bằng Nguoi.attach / Nguoi.hold. Một mesh, một vật liệu, màu đỉnh COLOR_0 như đồ phố.

Dùng: pip install bpy==5.2.0 numpy scikit-image; python3 tools/khu_pho/do_cam_g9.py assets/models/nguoi [ten,ten]
Trục (như three/Godot): x trái của người cầm, y lên, z ra trước. Mét thật.
  ly_ca_phe   ly cà phê sữa đá có ống hút (Chị Mây, hand.R), gốc giữa thân ly
  banh_mieng  miếng bánh mì Cô Ba nếm (hand.R)       nua_o  nửa ổ bánh mì (Cô Ba, hand.L)
  con_oc      con ốc lục giác (Anh Hùng, hand.R)
  bong_giay   chùm bông giấy hồng 9 cụm (Bà Sáu, ôm hai tay, gắn hand.R), gốc giữa chùm
  mu_hong     mũ bảo hiểm nửa đầu màu hồng của Chị Thảo (hand.L), gốc giữa vành mũ
"""
import sys
import os
import json
import numpy as np
from skimage import measure
import bpy
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdflib import v, ellipsoid, sphere, roundcone, smax, hexc  # noqa: E402

COL = dict(ly='#B7D7E6', caphe='#5A3420', ong='#E58AA0', banh='#E2A452', ruot='#F3DDA8', oc='#A9B0B6',
           bong='#D23C8C', bong2='#E86AAE', la='#4E8A3A', mu='#E58AA0', kinh='#2E3640', quai='#3A3036')


def ly_ca_phe():
    """Ly đặc (game nhỏ, không cần thành ly mỏng): phần dưới màu cà phê sữa đá, phần trên màu ly, ống hút hồng."""
    a, b = v(0, -.05, 0), v(0, .08, 0)
    return [
        (lambda p: roundcone(p, a, b, .04, .048), 'ly'),
        (lambda p: smax(roundcone(p, a, b, .0415, .0495), p[..., 1] - .035, .002), 'caphe'),
        (lambda p: roundcone(p, v(.005, -.02, 0), v(.02, .14, -.01), .005, .005), 'ong'),
    ]


def banh_mieng():
    return [(lambda p: roundcone(p, v(-.03, 0, 0), v(.03, .005, 0), .022, .02), 'banh'),
            (lambda p: ellipsoid(p, v(.031, .004, 0), v(.004, .016, .016)), 'ruot')]


def nua_o():
    return [(lambda p: roundcone(p, v(-.1, 0, 0), v(.06, .01, 0), .034, .03), 'banh'),
            (lambda p: ellipsoid(p, v(.062, .01, 0), v(.005, .026, .026)), 'ruot')]


def con_oc():
    def oc(p):
        q = p
        r = np.maximum(np.abs(q[..., 0]) * .866 + np.abs(q[..., 2]) * .5, np.abs(q[..., 2])) - .018
        return smax(smax(r, np.abs(q[..., 1]) - .008, .002), -(np.linalg.norm(q[..., ::2], axis=-1) - .008), .002)
    return [(oc, 'oc')]


def bong_giay():
    rng = np.random.default_rng(6)
    c0 = v(0, 0, 0)
    out = [(lambda p: roundcone(p, c0 + v(.06, -.04, -.02), c0 + v(-.08, .05, .04), .007, .006), 'la')]
    for i in range(9):
        o = c0 + v(*(rng.uniform(-1, 1, 3) * (.08, .05, .05)))
        out.append(((lambda o, r: lambda p: sphere(p, o, r))(o, .028 + .01 * rng.random()), 'bong' if i % 3 else 'bong2'))
    for i in range(5):
        o = c0 + v(*(rng.uniform(-1, 1, 3) * (.1, .04, .06))) + v(0, -.02, 0)
        out.append(((lambda o: lambda p: ellipsoid(p, o, v(.03, .008, .018)))(o), 'la'))
    return out


def mu_hong():
    def mu(p):
        return smax(np.abs(ellipsoid(p, v(0, 0, 0), v(.11, .1, .13))) - .008, -p[..., 1], .006)

    def kinh(p):
        return smax(np.abs(ellipsoid(p, v(0, 0, .02), v(.118, .07, .14))) - .003, np.maximum(-p[..., 2] + .06, p[..., 1] - .06), .004)
    return [(mu, 'mu'), (kinh, 'kinh'),
            (lambda p: roundcone(p, v(.1, -.005, 0), v(.06, -.08, .02), .004, .004), 'quai'),
            (lambda p: roundcone(p, v(-.1, -.005, 0), v(-.06, -.08, .02), .004, .004), 'quai')]


# tên: (hàm, số tam giác sau giảm lưới, bước lưới marching cubes)
DO = dict(ly_ca_phe=(ly_ca_phe, 300, .004), banh_mieng=(banh_mieng, 120, .003), nua_o=(nua_o, 200, .004), con_oc=(con_oc, 160, .0015),
          bong_giay=(bong_giay, 700, .004), mu_hong=(mu_hong, 500, .004))


def lin(c):
    c = np.asarray(c, np.float32)
    return np.where(c <= .04045, c / 12.92, ((c + .055) / 1.055) ** 2.4)


def field(parts, lo, hi, H):
    axes = [np.arange(lo[i], hi[i] + H, H, dtype=np.float32) for i in range(3)]
    P = np.stack(np.meshgrid(*axes, indexing='ij'), -1)
    D = np.stack([fn(P) for fn, _ in parts], 0)
    return D.min(0), axes


def build(name):
    fn, target, H = DO[name]
    parts = fn()
    f, axes = field(parts, (-.16, -.12, -.16), (.16, .18, .18), H)
    V, F, _, _ = measure.marching_cubes(f, 0.0, spacing=(H, H, H), gradient_direction='descent')
    V = (V + np.array([a[0] for a in axes], np.float32)).astype(np.float32)
    # màu: phần gần nhất
    D = np.stack([pf(V) for pf, _ in parts], 1)
    cols = np.stack([lin(hexc(COL[m])) for _, m in parts])[D.argmin(1)]
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    me = bpy.data.meshes.new(name)
    # three (x trái, y lên, z trước) -> Blender (x, -z, y); xuất glTF với +Y lên sẽ trả lại như cũ
    me.from_pydata([(float(x), float(-z), float(y)) for x, y, z in V], [], [tuple(map(int, t)) for t in F])
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ca = me.color_attributes.new('Col', 'FLOAT_COLOR', 'POINT')
    ca.data.foreach_set('color', np.concatenate([cols, np.ones((len(cols), 1), np.float32)], 1).ravel().tolist())
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    if len(me.polygons) > target:
        mod = ob.modifiers.new('giam', 'DECIMATE')
        mod.ratio = target / len(me.polygons)
        bpy.ops.object.modifier_apply(modifier=mod.name)
    for p in me.polygons:
        p.use_smooth = True
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bs = m.node_tree.nodes['Principled BSDF']
    vc = m.node_tree.nodes.new('ShaderNodeVertexColor')
    vc.layer_name = 'Col'
    m.node_tree.links.new(vc.outputs['Color'], bs.inputs['Base Color'])
    bs.inputs['Roughness'].default_value = .35 if name in ('con_oc', 'ly_ca_phe', 'mu_hong') else .75
    bs.inputs['Metallic'].default_value = .8 if name == 'con_oc' else 0
    me.materials.append(m)
    return ob, len(me.polygons)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else 'assets/models/nguoi'
    names = sys.argv[2].split(',') if len(sys.argv) > 2 else list(DO)
    os.makedirs(out, exist_ok=True)
    rep = {}
    for n in names:
        ob, tris = build(n)
        path = os.path.join(out, n + '.glb')
        bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_yup=True, export_vertex_color='ACTIVE',
                                  export_normals=True, export_texcoords=False, export_materials='EXPORT', export_animations=False)
        rep[n] = dict(tris=tris, kb=os.path.getsize(path) // 1024)
    print(json.dumps(rep))


if __name__ == '__main__':
    main()
