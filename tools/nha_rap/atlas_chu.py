"""Vẽ chữ 21 bảng hiệu P2 lên một ảnh atlas cho game (bảng hiệu bản game không có lưới chữ).
Đọc chu.json do `run.py bang_game` ghi (khung chữ từng tấm, toạ độ Blender), vẽ mỗi dòng chữ một lần bằng đúng
phông của bảng, xếp kệ vào ảnh 1024 x 1024, rồi ghi bảng tra cho Godot (scripts/nha_rap.gd đọc):
  { "bang_<tên>_<ngang>": [ {"uv": [u0, v0, u1, v1], "x": [x0, x1], "y": [y0, y1], "z": z, "sang": bool}, ... ] }
toạ độ Godot trong gốc mảnh trệt (x sang phải, y lên, z = mặt trước chữ, dương là ra đường).
Dùng: python3 atlas_chu.py <chu.json> <ra.png> <ra.json>"""
import sys, json
from PIL import Image, ImageDraw, ImageFont
import bang_hieu as BH

SRC, OUT_PNG, OUT_JSON = sys.argv[1:4]
SIZE = 1024
LINE_H = {True: 58, False: 30}   # chiều cao chữ (px): tên tiệm, dòng phụ
PAD = 6
SS = 3                            # vẽ to gấp 3 rồi thu nhỏ cho mượt


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


chu = json.load(open(SRC))
lines = {}
for key, lst in chu.items():
    for c in lst:
        t = c['chu']   # tên tiệm viết hoa: dòng to; dòng phụ chữ thường
        lines[(t, c['font'], c['mau'])] = any(ch.isalpha() for ch in t) and t == t.upper()
imgs = {k: render(k[0], k[1], k[2], LINE_H[big]) for k, big in lines.items()}
atlas = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
x = y = shelf = 0
uv = {}
for k in sorted(imgs, key=lambda k: (-imgs[k].height, -imgs[k].width)):
    im = imgs[k]
    if x + im.width + PAD > SIZE:
        x, y, shelf = 0, y + shelf + PAD, 0
    if y + im.height > SIZE:
        sys.exit('atlas đầy: giảm LINE_H')
    atlas.paste(im, (x, y))
    uv[k] = [x / SIZE, y / SIZE, (x + im.width) / SIZE, (y + im.height) / SIZE]
    x += im.width + PAD
    shelf = max(shelf, im.height)
atlas.save(OUT_PNG)
out = {}
for key, lst in chu.items():
    out[key] = [dict(uv=uv[(c['chu'], c['font'], c['mau'])], x=[round(c['x'][0], 3), round(c['x'][1], 3)],
                     y=[round(c['z'][0], 3), round(c['z'][1], 3)], z=round(-c['y'] + .003, 3), sang=c['sang']) for c in lst]
json.dump(out, open(OUT_JSON, 'w'), ensure_ascii=False, separators=(',', ':'))
print('atlas', len(imgs), 'dòng, cao tới', y + shelf, 'px')
