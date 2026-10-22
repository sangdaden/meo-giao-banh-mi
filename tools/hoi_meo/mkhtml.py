"""Viết page/index.html từ page/build.json (mkpage.py)."""
import sys, json, html
OUT = sys.argv[1]
B = json.load(open(f'{OUT}/build.json'))
E = html.escape
fmt = lambda x, d=2: f'{x:.{d}f}'.replace('.', ',')
num = lambda n: f'{n:,}'.replace(',', '.')
SEX = {'duc': 'đực', 'cai': 'cái'}
VN = {'q34': '3/4 trước', 'front': 'trước', 'side': 'ngang', 'back': 'sau', 'mat': 'cận mặt', 'q34b': '3/4 sau'}
cats = B['cats']; bm = cats[0]
ACCN = {'kinhlao': 'Kính lão', 'daykinh': 'Dây kính', 'khanchoang': 'Khăn choàng len', 'kinhphicong': 'Kính phi công', 'khanran': 'Khăn rằn',
        'chuong': 'Vòng cổ chuông', 'vuongmien': 'Vương miện', 'nonsinhnhat': 'Mũ sinh nhật', 'bangdo': 'Băng đô', 'hoadambut': 'Hoa dâm bụt'}
WHO = {c['id']: c['name'] for c in cats}


def gal(c, order=('q34', 'mat', 'q34b', 'front', 'side', 'back')):
    out = []
    for v in order:
        if v in c['views']:
            out.append(f'<figure><img src="{c["views"][v]}" alt="{E(c["name"])}, nhìn {VN[v]}" loading="lazy"><figcaption>{VN[v]}{" · lưới 10 cm, viền đỏ là bóng Bơ" if v in ("front", "side", "back") else ""}</figcaption></figure>')
    return ''.join(out)


def meas(c):
    m = c['m']
    return (f'<dl class="ms"><div><dt>Cao tới chóp tai</dt><dd>{fmt(m["h"])} m</dd></div><div><dt>Đầu + thân</dt><dd>{fmt(m["hb"])} m</dd></div>'
            f'<div><dt>Đuôi dọc đường cong</dt><dd>{fmt(m["tail"])} m</dd></div><div><dt>Đuôi : đầu + thân</dt><dd>{fmt(m["ratio"])}</dd></div>'
            f'<div><dt>Đuôi gốc → chóp</dt><dd>{fmt(m["tr"][0], 1)} → {fmt(m["tr"][1], 1)} cm</dd></div><div><dt>Ngang thân</dt><dd>{fmt(m["w"])} m</dd></div></dl>')


BM_PARTS = [
    ('Thân', 'Một lớp da liền (SDF trộn mềm): đầu, má phính, ngực, thân mập ×1,15, bụng xệ, đùi sau, 4 chân thấp 5%, đuôi 4 đốt', '0,55 cao × 0,23 ngang × 0,47 dài', 'Than', 'màu đỉnh: lông #A8A49C, vằn #7A746C, bụng #EEEAE2, lông bạc mõm/mày #F4F1EA', 'toàn bộ 25 xương, đuôi 4 xương'),
    ('Mắt × 2', 'Hạnh nhân 6,1 × 5,0 cm (nhỏ hơn Bơ 8%), mí trên che 16%, mí dưới đẩy lên (cười hiền), đuôi mắt hếch', 'tròng 96 phân đoạn', None, 'tròng #DCD27E → #9C8C36, viền #5C5020, đồng tử khe', 'eye_L, eye_R'),
    ('Đốm sáng × 4', 'To trên-ngoài, nhỏ dưới', 'Ø 1,0 và 0,7 cm', None, 'trắng tự sáng', 'head'),
    ('Mi × 6', '3 sợi cong mỗi bên (mèo cái)', 'dài 1,4 cm', None, '#3E3632', 'head'),
    ('Kính lão: gọng', 'Hai mắt kính nửa vầng trăng 6,0 × 2,4 cm, cầu mũi cong, càng kính vòng ra sau tai; đeo trễ 2,1 cm dưới tâm mắt để bà nhìn qua mép kính', 'ngang 0,15 m', 'Gong_KinhLao', 'vàng đồng #C9A24A, kim loại', 'head'),
    ('Kính lão: tròng', 'Hai miếng kính nửa vầng trăng dày 2 mm', '6,0 × 2,4 cm', 'Trong_KinhLao', '#DDEBEE trong 30%', 'head'),
    ('Dây kính', 'Chuỗi hạt cườm Ø 6 mm nối hai càng kính, rủ qua hai bên má, vòng sau gáy', 'dài ~0,32 m', 'Day_Kinh', 'đồng #B8863A', 'chest (điểm gắn neck)'),
    ('Khăn choàng len', 'Khoác kín vai, rủ trước ngực 7–10 cm, viền kem gấu dưới, nơ nhỏ trước ngực; dệt gân dọc', 'vòng vai 0,34 m', 'Khan_Choang', 'mận #7E3550, viền kem #F1E6D2', 'chest (điểm gắn neck)'),
]
pt = {p['name']: p['tris'] for p in bm['m']['parts']}
bm_rows = ''.join(f'<tr><td><b>{E(a)}</b></td><td>{E(b_)}</td><td>{E(c_)}</td><td class="n">{num(pt[k]) if k in pt else "–"}</td><td>{E(d)}</td><td><code>{E(e)}</code></td></tr>'
                  for a, b_, c_, k, d, e in BM_PARTS)
PAL = [('Lông', '#A8A49C'), ('Vằn bạc màu', '#7A746C'), ('Bụng, ngực', '#EEEAE2'), ('Lông bạc mõm, mày', '#F4F1EA'), ('Trong tai', '#D7A6A0'),
       ('Mũi', '#B47A78'), ('Má hồng', '#E8A49A'), ('Nét', '#3E3632'), ('Tròng sáng', '#DCD27E'), ('Tròng tối', '#9C8C36'),
       ('Khăn mận (màu nhấn)', '#7E3550'), ('Viền khăn', '#F1E6D2'), ('Gọng kính', '#C9A24A'), ('Dây kính', '#B8863A')]
pal = ''.join(f'<li><span class="sw" style="--c:{c}"></span>{E(n)} <code>{c}</code></li>' for n, c in PAL)

cards = []
for c in cats[1:]:
    acc = ', '.join(ACCN.get(a, a) for a in c['accs'])
    cards.append(f'''<article class="cat" id="{c['id']}">
  <div class="ch"><h3>{E(c['name'])}</h3><span class="tag">{E(B['data']['cats'][cats.index(c)]['breed'])} · {SEX[c['sex']]}</span></div>
  <div class="gal4">{gal(c, ('q34', 'front', 'side', 'back'))}</div>
  <div class="cinfo"><p><b>Tính cách:</b> {E(c['tinh'])}. <b>Vai:</b> {E(c['vai'])}.</p>
  <p><b>Phụ kiện riêng:</b> {E(acc)} (đồ có sẵn trong tủ đồ, mỗi mèo một món khác nhau).</p>{meas(c)}
  <p class="sm">Tam giác: phác thảo {num(c['sketch'])} · game {num(c['game'])} + đồ {num(c['acc_g'])} · bản nhẹ web {num(c['nhe'])} + đồ {num(c['acc_n'])}</p></div>
</article>''')

mt = ''.join(f'<tr><td><b>{E(c["name"])}</b></td><td>{E(B["data"]["cats"][i]["breed"])}</td><td>{SEX[c["sex"]]}</td><td class="n">{fmt(c["m"]["h"])}</td><td class="n">{fmt(c["m"]["hb"])}</td>'
             f'<td class="n">{fmt(c["m"]["tail"])}</td><td class="n">{fmt(c["m"]["ratio"])}</td><td class="n">{num(c["game"] + c["acc_g"])}</td><td class="n">{num(c["nhe"] + c["acc_n"])}</td></tr>'
             for i, c in enumerate(cats))

an_cards = []
for a in B['anims']:
    strip = ''.join(f'<figure class="key"><img src="{s}" alt="{E(a["title"])} lúc {fmt(t)} s" loading="lazy"><figcaption><span class="t">{fmt(t)} s</span><span class="f">khung {round(t * 30)}</span></figcaption></figure>' for t, s in a['keys'])
    vws = ''.join(f'<figure class="view"><img src="{s}" alt="{E(a["title"])}, {VN.get(v, v)}" loading="lazy"><figcaption>{VN.get(v, v)}</figcaption></figure>' for v, s in a['views'])
    an_cards.append(f'''<article class="anim" id="a_{a['name']}">
  <div class="ah"><div class="ah-t"><h3>{E(a['title'])}</h3><code class="id">{a['name']}</code></div>
  <div class="timing"><span class="dur">{fmt(a['dur'])} s</span><span>{round(a['dur'] * 30)} khung</span><span>{'lặp' if a['loop'] else 'một lần'}</span><span>ảnh trên: {E(WHO[a['who']])}</span></div>
  <button type="button" class="play" data-anim="{a['name']}">Xem 3D</button></div>
  <div class="strip">{strip}</div>
  <div class="cols"><div class="txt"><p>{E(a['notes'])}</p><p class="gm"><b>Trong game:</b> {E(a['game'])}</p></div><div class="views">{vws}</div></div>
</article>''')
reuse = ''.join(f'<figure><img src="{s}" alt="{E(t)}" loading="lazy"><figcaption><b>{E(t)}</b> <code>{n}</code></figcaption></figure>' for n, t, s in B['reuse'])
X = B['extra']
img = lambda k, alt: f'<img src="{X[k]}" alt="{alt}" loading="lazy">' if k in X else '<p class="sm">(ảnh đang render)</p>'
catbtn = ''.join(f'<button type="button" class="ab" data-cat="{c["id"]}">{E(c["name"])}</button>' for c in cats)
anbtn = ''.join(f'<button type="button" class="ab" data-anim="{a["name"]}">{E(a["title"].replace("Bà Mướp ", ""))}</button>' for a in B['anims'])

page = open(f'{OUT}/../scripts/tpl.html').read()
for k, v in dict(BM_GAL=gal(bm), BM_MEAS=meas(bm), BM_ROWS=bm_rows, PAL=pal, CARDS=''.join(cards), MT=mt, ANIMS=''.join(an_cards), REUSE=reuse,
                 HANG1=img('hang_truoc', 'Tám mèo hội và Bơ đứng thành hàng, nhìn thẳng trên lưới mét'), HANG2=img('hang_q34', 'Tám mèo hội và Bơ, góc 3/4'),
                 CANH=img('canh', 'Tối Hội mèo: Bà Mướp ngồi thùng gỗ, mèo khán giả và Bơ quanh sân, đèn lồng'),
                 DPC=img('dang_pc', 'Bà Mướp 6 dáng chạy, bản PC'), DWEB=img('dang_web', 'Bà Mướp 6 dáng chạy, bản web'),
                 SVG=B['svg'], DATA=json.dumps(B['data'], ensure_ascii=False), CATBTN=catbtn, ANBTN=anbtn,
                 BM_SK=num(bm['sketch']), BM_GAME=num(bm['game'] + bm['acc_g']), BM_NHE=num(bm['nhe'] + bm['acc_n'])).items():
    page = page.replace('%%' + k + '%%', v)
open(f'{OUT}/index.html', 'w').write(page)
print('index.html', len(page))
