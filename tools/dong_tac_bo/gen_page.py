"""Dựng trang phác thảo G2 (page/index.html + page/r/*.webp + page/bo_g2.glb) từ anims.py, renders/ và tui3/.
Chạy: python3 gen_page.py"""
import json
import os
import shutil
import html
from PIL import Image
import anims

HERE = os.path.dirname(os.path.abspath(__file__))
PAGE = f'{HERE}/page'
os.makedirs(f'{PAGE}/r', exist_ok=True)


def webp(src, name, w=None, q=80):
    im = Image.open(src).convert('RGB')
    if w and im.width > w:
        im = im.resize((w, round(im.height * w / im.width)), Image.LANCZOS)
    im.save(f'{PAGE}/r/{name}.webp', 'WEBP', quality=q, method=6)
    return f'r/{name}.webp'


DAYS = [('T4', 'Thứ Tư', 'Mưa chiều, sân thượng'), ('T5', 'Thứ Năm', 'Lên tầng năm'), ('T6', 'Thứ Sáu', 'Chiều thứ Sáu'),
        ('T7', 'Thứ Bảy', 'Dạo phố'), ('CN', 'Chủ Nhật', 'Hội mèo')]
VIEWN = {'q34': 'Góc 3/4', 'q34r': 'Sau, chéo phải', 'q34l': 'Sau, chéo trái', 'q34f': 'Trước, chéo trái', 'side': 'Ngang (chiếu thẳng)',
         'front': 'Trước (chiếu thẳng)', 'back': 'Sau (chiếu thẳng)', 'top': 'Trên xuống'}


def vn(x, d=2):
    s = f'{x:.{d}f}'.rstrip('0').rstrip('.') if '.' in f'{x:.{d}f}' else f'{x}'
    return s.replace('.', ',')


meta = []
for name, a in anims.ANIMS.items():
    shots = [{'t': t, 'img': webp(f'{HERE}/renders/{name}_k{i}.png', f'{name}_k{i}', 480)} for i, t in enumerate(a['shots'])]
    vs = a.get('views', ('q34r', 'side', 'back', 'q34l') if a.get('ctx') in ('ledge', 'pipe') else ('q34', 'side', 'front', 'back'))
    views = [{'v': VIEWN[v], 'img': webp(f'{HERE}/renders/{name}_{v}.png', f'{name}_{v}', 640)} for v in vs]
    meta.append(dict(name=name, day=a['day'], title=a['title'], dur=a['dur'], loop=a['loop'], ctx=a.get('ctx'),
                     bag=bool(a.get('bag')), bag3=bool(a.get('bag3')), medal=name == 'nhan_huy_chuong',
                     frames=int(round(a['dur'] * 30)) + 1, main=a['main'], notes=a['notes'], game=a['game'],
                     shots=shots, views=views, partner=bool(a.get('partner'))))

t3 = json.load(open(f'{HERE}/tui3/tui3.json'))
t3img = {v: webp(f'{HERE}/tui3/tui3_{v}.png', f'tui3_{v}', 640) for v in ('q34', 'front', 'side', 'back', 'top')}
pass

E = html.escape


def card(m):
    loop = 'lặp' if m['loop'] else 'một lần'
    strip = ''.join(f'<figure class="key"><img src="{s["img"]}" alt="{E(m["title"])} lúc {vn(s["t"])} s" loading="lazy" width="480" height="400">'
                    f'<figcaption><span class="t">{vn(s["t"])} s</span><span class="f">khung {int(round(s["t"] * 30))}</span></figcaption></figure>'
                    for s in m['shots'])
    views = ''.join(f'<figure class="view"><img src="{v["img"]}" alt="{E(m["title"])}, {E(v["v"])}" loading="lazy" width="640" height="540">'
                    f'<figcaption>{E(v["v"])}</figcaption></figure>' for v in m['views'])
    extra = []
    if m['bag']: extra.append('đeo túi chéo')
    if m['bag3']: extra.append('ngậm túi 3 ổ')
    if m['partner']: extra.append('mèo bạn: Xiêm')
    if m['ctx']: extra.append({'ledge': 'mép tường 0,5 m', 'pipe': 'ống nước Ø10 cm', 'walls': 'khe 1,2 m', 'plank': 'ván 0,25 m'}[m['ctx']])
    chips = ''.join(f'<span class="chip">{E(x)}</span>' for x in extra)
    return f'''<article class="anim" id="{m["name"]}">
  <header class="ah">
    <div class="ah-t"><h3>{E(m["title"])}</h3><code class="id">{m["name"]}</code></div>
    <div class="timing"><span class="dur">{vn(m["dur"])} s</span><span>{loop}</span><span>{m["frames"]} khung · 30/s</span></div>
  </header>
  <div class="chips">{chips}<button class="play" type="button" data-anim="{m["name"]}">Xem chuyển động 3D</button></div>
  <div class="strip">{strip}</div>
  <div class="cols">
    <div class="txt"><p><b>Dáng và nhịp.</b> {E(m["notes"])}</p><p><b>Vào game.</b> {E(m["game"])}</p></div>
    <div class="views">{views}</div>
  </div>
</article>'''


sections = ''
for d, dn, sub in DAYS:
    ms = [m for m in meta if m['day'] == d]
    sections += f'<section class="day" id="{d.lower()}"><div class="dh"><h2>{dn}</h2><p>{sub} · {len(ms)} động tác</p></div>' + ''.join(card(m) for m in ms) + '</section>'

NAMES = {'Than': 'Thân túi', 'Vien': 'Viền miệng', 'Quai': 'Quai', 'Banh': '3 ổ bánh', 'Khia': '9 vết khía', 'Mieng': 'Miếng vá', 'Dem': '4 đệm chân'}
parts_rows = ''
for (pn, desc, col, matn) in t3['parts']:
    parts_rows += (f'<tr><td>{E(pn)}</td><td>{E(desc)}</td><td><span class="sw" style="--c:{col}"></span><code>{col}</code></td>'
                   f'<td>{E(matn)}</td></tr>')
tri_rows = ''.join(f'<tr><td>{NAMES[k]}</td><td class="n">{v[2]}</td><td class="n">{v[0]:,}</td><td class="n">{v[1]}</td></tr>'.replace(',', '.')
                   for k, v in t3['tris'].items())
dims = t3['dims']

index = ''.join(f'<li><a href="#{m["name"]}">{E(m["title"])}</a><span>{vn(m["dur"])} s</span></li>' for m in meta)
nav_days = ''.join(f'<button type="button" class="dbtn" data-day="{d}">{dn}</button>' for d, dn, _ in DAYS)

page = open(f'{HERE}/page_tpl.html').read()
page = (page.replace('%%SECTIONS%%', sections).replace('%%META%%', json.dumps(
            [{k: m[k] for k in ('name', 'day', 'title', 'dur', 'loop', 'ctx', 'bag', 'bag3', 'medal')} for m in meta], ensure_ascii=False))
        .replace('%%PARTS%%', parts_rows).replace('%%TRIS%%', tri_rows).replace('%%TOTAL%%', str(t3['total']))
        .replace('%%DIMS%%', f'{vn(dims[0] * 100, 1)} × {vn(dims[1] * 100, 1)} × {vn(dims[2] * 100, 1)} cm')
        .replace('%%INDEX%%', index).replace('%%NAVDAYS%%', nav_days))
for v, p in t3img.items():
    page = page.replace(f'%%T3_{v}%%', p)
open(f'{PAGE}/index.html', 'w').write(page)
print('ok', len(page), 'bytes;', len(os.listdir(f"{PAGE}/r")), 'ảnh')
