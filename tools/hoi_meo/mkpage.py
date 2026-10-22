"""Gom ảnh, số đo và model thành trang phác thảo G10 (page/index.html + img/*.webp + m/*.json).
Chạy: python3 mkpage.py <scratch> <page_dir>
  scratch có: r/ (ảnh + meta + .glb phác thảo), an/ (ảnh động tác), canh/ (so cỡ, cảnh), luoi_6_dang_*.png, hoi_bamuop.glb"""
import sys, os, json, struct, base64, html
from PIL import Image, ImageDraw, ImageFilter, ImageChops

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import anims_hoi as AH
import hoi

SP, OUT = sys.argv[1], sys.argv[2]
REPO = '/home/user/meo-giao-banh-mi'
G2R = '/mnt/project-files/thiet-ke-man/goi-phac-thao/g2-bo/page/r'
os.makedirs(f'{OUT}/img', exist_ok=True); os.makedirs(f'{OUT}/m', exist_ok=True)
SKIN = json.load(open(f'{REPO}/assets/models/skin/skin.json'))
STAGE = (156, 203, 193)


def webp(im, name, q=80, w=None):
    im = im.convert('RGB')
    if w and im.width > w:
        im = im.resize((w, round(im.height * w / im.width)), Image.LANCZOS)
    im.save(f'{OUT}/img/{name}.webp', quality=q, method=6)
    return f'img/{name}.webp'


def glb2json(src, dst):
    b = open(src, 'rb').read(); n = struct.unpack('<I', b[12:16])[0]; js = json.loads(b[20:20 + n])
    o = 20 + n; bl = struct.unpack('<I', b[o:o + 4])[0]; binc = b[o + 8:o + 8 + bl]
    js['buffers'][0]['uri'] = 'data:application/octet-stream;base64,' + base64.b64encode(binc).decode()
    json.dump(js, open(dst, 'w'), separators=(',', ':'))


# ---------- ảnh chiếu thẳng: nền sân khấu, lưới 10 cm / 50 cm, bóng Bơ nét đứt ----------
S_PX = 720 / .98; GY = 288 + .3 * S_PX; CX = 360


def ortho(cid, view):
    im = Image.open(f'{SP}/r/{cid}_{view}.png').convert('RGBA')
    bg = Image.new('RGBA', im.size, STAGE + (255,)); d = ImageDraw.Draw(bg)
    for i in range(-6, 7):
        x = CX + i * .1 * S_PX
        d.line([(x, 0), (x, im.height)], fill=(80, 133, 120, 255) if i % 5 == 0 else (128, 176, 166, 255), width=2 if i % 5 == 0 else 1)
    for j in range(0, 9):
        y = GY - j * .1 * S_PX
        d.line([(0, y), (im.width, y)], fill=(80, 133, 120, 255) if j % 5 == 0 else (128, 176, 166, 255), width=2 if j % 5 == 0 else 1)
        if j:
            d.text((6, y - 14), f'{j * 10} cm', fill=(40, 80, 72, 255))
    bo = f'{SP}/r/bo_{view}.png'
    if os.path.exists(bo):
        a = Image.open(bo).convert('RGBA').split()[3].point(lambda v: 255 if v > 128 else 0)
        edge = ImageChops.subtract(a.filter(ImageFilter.MaxFilter(5)), a)
        ghost = Image.new('RGBA', im.size, (184, 58, 43, 0)); ghost.putalpha(edge.point(lambda v: 150 if v else 0))
        bg.alpha_composite(ghost)
    bg.alpha_composite(im)
    return bg


CATS = []
for cid in hoi.ORDER:
    name, bid, g, accs, tinh, vai = hoi.CATS[cid]
    m = json.load(open(f'{SP}/r/meta_{cid}.json'))
    views = {}
    for v in ('q34', 'front', 'side', 'back', 'mat', 'q34b'):
        p = f'{SP}/r/{cid}_{v}.png'
        if not os.path.exists(p):
            continue
        if v in ('front', 'side', 'back'):
            views[v] = webp(ortho(cid, v), f'{cid}_{v}', w=640)
        else:
            im = Image.open(p).convert('RGBA'); bg = Image.new('RGBA', im.size, STAGE + (255,)); bg.alpha_composite(im)
            views[v] = webp(bg, f'{cid}_{v}', w=640)
    glb2json(f'{SP}/r/{cid}.glb', f'{OUT}/m/{cid}.json')
    key = f'{bid}_{g}'
    game = SKIN['giong'][key]['tris']; nhe = SKIN.get('giong_nhe', {}).get(key, {}).get('tris')
    acc_g = sum(SKIN['phu_kien'][a]['tris'] for a in accs); acc_n = sum(SKIN.get('phu_kien_nhe', {}).get(a, {}).get('tris', 0) for a in accs)
    CATS.append(dict(id=cid, name=name, breed=bid, sex=g, accs=accs, tinh=tinh, vai=vai, m=m, views=views,
                     sketch=sum(p['tris'] for p in m['parts']), game=game, nhe=nhe, acc_g=acc_g, acc_n=acc_n))

BREEDN = {'bamuop': 'Mèo mướp già (mới)', 'xiem': 'Xiêm', 'khoaimon': 'Khoai Môn · Anh lông ngắn', 'mun': 'Mun · mèo ta đen thon',
          'tuyet': 'Tuyết · Ba Tư', 'vobanh': 'Vỏ Bánh Giòn · Munchkin', 'que': 'Quế · Abyssinian', 'suadac': 'Sữa Đặc · Ragdoll'}
ACCN = {'kinhlao': 'kính lão (mới)', 'daykinh': 'dây kính (mới)', 'khanchoang': 'khăn choàng len (mới)', 'kinhphicong': 'kính phi công',
        'khanran': 'khăn rằn', 'chuong': 'vòng cổ chuông', 'vuongmien': 'vương miện', 'nonsinhnhat': 'mũ sinh nhật', 'bangdo': 'băng đô',
        'hoadambut': 'hoa dâm bụt'}

# ---------- động tác ----------
ANIMS = []
for nm, an in AH.ANIMS.items():
    keys = []
    for i, t in enumerate(an['shots']):
        p = f'{SP}/an/{nm}_k{i}.png'
        if os.path.exists(p):
            keys.append((t, webp(Image.open(p), f'a_{nm}_k{i}', w=480)))
    vs = []
    for v in ('q34', 'side', 'front', 'back'):
        p = f'{SP}/an/{nm}_{v}.png'
        if os.path.exists(p):
            vs.append((v, webp(Image.open(p), f'a_{nm}_{v}', w=640)))
    ANIMS.append(dict(name=nm, title=an['title'], who=an['who'], dur=an['dur'], loop=an['loop'], shots=an['shots'], keys=keys, views=vs,
                      notes=an['notes'], game=an['game']))
glb2json(f'{SP}/hoi_bamuop.glb', f'{OUT}/m/hoi_bamuop.json')

REUSE = [('dua_tui', 'Chuyền túi: đưa'), ('nhan_tui', 'Chuyền túi: nhận'), ('nhan_huy_chuong', 'Nhận huy chương'),
         ('chup_vay', 'Tạo dáng: vẫy chào'), ('chup_nam', 'Tạo dáng: ổ bánh mì'), ('chup_dung', 'Tạo dáng: ta-da')]
reuse_imgs = []
for nm, t in REUSE:
    src = next((f'{G2R}/{nm}_{v}.webp' for v in ('main', 'q34', 'side', 'q34r') if os.path.exists(f'{G2R}/{nm}_{v}.webp')), None)
    if src:
        reuse_imgs.append((nm, t, webp(Image.open(src), f'g2_{nm}', w=480)))

# ---------- ảnh khác ----------
EXTRA = {}
for k, p in (('hang_truoc', f'{SP}/canh/hang_truoc.png'), ('hang_q34', f'{SP}/canh/hang_q34.png'), ('canh', f'{SP}/canh/canh_hoi.png'),
             ('dang_pc', f'{SP}/luoi_6_dang_pc.png'), ('dang_web', f'{SP}/luoi_6_dang_web.png')):
    if os.path.exists(p):
        EXTRA[k] = webp(Image.open(p), k, q=82, w=1800)

# ---------- sơ đồ xương (từ glb game) ----------
b = open(f'{REPO}/assets/models/skin/giong/bamuop_cai.glb', 'rb').read(); n = struct.unpack('<I', b[12:16])[0]; J = json.loads(b[20:20 + n])
joints = J['skins'][0]['joints']; jn = {i: J['nodes'][i]['name'] for i in joints}
children = {i: [c for c in J['nodes'][i].get('children', []) if c in jn] for i in joints}
rootj = [i for i in joints if not any(i in children[p] for p in joints)][0]
rows = []
def walk(i, d):
    rows.append((jn[i], d))
    for c in children[i]:
        walk(c, d + 1)
walk(rootj, 0)
BONE_ROLE = {'root': 'gốc, dời cả con', 'hips': 'hông', 'chest': 'ngực, giữ khăn và vòng cổ', 'head': 'đầu, giữ kính, mũ, vương miện',
             'scarf': 'đuôi khăn (Bơ), mèo hội để trống', 'eye_L': 'chớp mắt (co giãn)', 'eye_R': 'chớp mắt (co giãn)',
             'tail_1': 'đuôi gốc', 'tail_4': 'đuôi chóp, nối lò xo', 'paw_FR': 'bàn chân trước phải, giữ bảng chấm điểm'}
svg = ['<svg viewBox="0 0 560 %d" role="img" aria-label="Sơ đồ 25 xương">' % (len(rows) * 22 + 12)]
for i, (nm, d) in enumerate(rows):
    x = 14 + d * 34; y = 16 + i * 22
    if d:
        svg.append(f'<path d="M{x - 26} {y - 14} V{y} H{x - 6}" class="bl"/>')
    svg.append(f'<circle cx="{x}" cy="{y}" r="4.5" class="bd"/><text x="{x + 10}" y="{y + 4}" class="bt">{nm}</text>')
    if nm in BONE_ROLE:
        svg.append(f'<text x="{x + 10 + len(nm) * 7.6 + 8}" y="{y + 4}" class="br">{BONE_ROLE[nm]}</text>')
svg.append('</svg>')
SVG = ''.join(svg)

DATA = dict(cats=[dict(id=c['id'], name=c['name'], breed=BREEDN[c['breed']], sex=c['sex'], accs=[ACCN.get(a, a) for a in c['accs']],
                       h=c['m']['h'], hb=c['m']['hb'], tail=c['m']['tail'], ratio=c['m']['ratio'], tris=c['sketch']) for c in CATS],
            anims=[dict(name=a['name'], title=a['title'], dur=a['dur'], loop=a['loop']) for a in ANIMS])
json.dump(dict(cats=CATS, anims=ANIMS, reuse=reuse_imgs, extra=EXTRA, svg=SVG, data=DATA), open(f'{OUT}/build.json', 'w'), ensure_ascii=False)
print('xong dữ liệu', len(CATS), len(ANIMS), list(EXTRA))
