"""Vẽ chữ bảng hiệu vòng 3 lên một ảnh atlas 2048 x 2048 cho game (bảng bản game không có lưới chữ).
Đọc chu.json do `bang_hieu_v3/run_v3.py game` ghi: mỗi dòng chữ có 4 góc mặt trước (toạ độ Godot, gốc mảnh trệt,
thứ tự dưới-trái, dưới-phải, trên-phải, trên-trái nhìn từ phía chữ). Mỗi dòng vẽ một lần, cỡ điểm ảnh theo chiều cao
thật của chữ (chữ tên to thì nét to), xếp kệ vào ảnh, rồi ghi bảng tra cho scripts/nha_rap.gd:
  { "bang_<tên>_<ngang>": [ {"uv": [u0, v0, u1, v1], "p": [[x, y, z] x 4]}, ... ] }
Dùng: python3 atlas_chu_v3.py <chu.json> <ra.png> <ra.json>"""
import sys, os, json
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bang_hieu as BH

SRC, OUT_PNG, OUT_JSON = sys.argv[1:4]
SIZE = 2048
PX_PER_M = 210        # chữ cao 0,5 m -> 105 px
H_MIN, H_MAX = 20, 132
PAD = 6
SS = 3                # vẽ to gấp 3 rồi thu nhỏ cho mượt
LIFT = .004           # chữ nổi trước mặt bảng 4 mm


def render(text, font, color, h):
    f = ImageFont.truetype(BH.FONTS[font], h * SS * 2)
    l, t, r, b = f.getbbox(text)
    # nền cùng màu chữ, alpha 0: lọc mipmap không ăn viền đen quanh chữ
    rgb = tuple(int(color[i:i + 2], 16) for i in (1, 3, 5))
    img = Image.new('RGBA', (r - l + 8, b - t + 8), rgb + (0,))
    ImageDraw.Draw(img).text((4 - l, 4 - t), text, font=f, fill=color)
    img = img.crop(img.getchannel("A").getbbox())   # khít mực, như khung chữ Blender
    w = max(1, round(img.width * h / img.height))
    return img.resize((w, h), Image.LANCZOS)


def height(p): return max(q[1] for q in p) - min(q[1] for q in p)


chu = json.load(open(SRC))
want = {}
for key, lst in chu.items():
    for c in lst:
        k = (c['chu'], c['font'], c['mau'])
        want[k] = max(want.get(k, 0), min(H_MAX, max(H_MIN, round(height(c['p']) * PX_PER_M))))
imgs = {k: render(k[0], k[1], k[2], h) for k, h in want.items()}
atlas = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
x = y = shelf = 0
uv = {}
for k in sorted(imgs, key=lambda k: (-imgs[k].height, -imgs[k].width)):
    im = imgs[k]
    if x + im.width + PAD > SIZE:
        x, y, shelf = 0, y + shelf + PAD, 0
    if y + im.height > SIZE:
        sys.exit('atlas đầy: giảm PX_PER_M')
    atlas.paste(im, (x, y))
    uv[k] = [round(x / SIZE, 5), round(y / SIZE, 5), round((x + im.width) / SIZE, 5), round((y + im.height) / SIZE, 5)]
    x += im.width + PAD
    shelf = max(shelf, im.height)
atlas.save(OUT_PNG, optimize=True)


def lifted(p):
    """Đẩy 4 góc ra trước theo pháp tuyến mặt chữ."""
    a, b, d = p[0], p[1], p[3]
    u = [b[i] - a[i] for i in range(3)]; v = [d[i] - a[i] for i in range(3)]
    n = [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]]
    ln = sum(c * c for c in n) ** .5 or 1
    return [[round(q[i] + n[i] / ln * LIFT, 3) for i in range(3)] for q in p]


out = {key: [dict(uv=uv[(c['chu'], c['font'], c['mau'])], p=lifted(c['p'])) for c in lst] for key, lst in chu.items()}
json.dump(out, open(OUT_JSON, 'w'), ensure_ascii=False, separators=(',', ':'))
print('atlas', len(imgs), 'dòng, cao tới', y + shelf, 'px')
