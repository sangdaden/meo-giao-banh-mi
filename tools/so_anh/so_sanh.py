#!/usr/bin/env python3
"""Ảnh so sánh mỗi PR (mã P2): so ảnh chụp cùng góc trên main và trên PR, đánh dấu vùng khác, làm trang xem nhanh.

Hai thư mục ảnh do tools/so_anh/chup.gd chụp (mỗi góc có <góc>.png và vài ảnh <góc>.sau1.png... chụp ngay sau đó).
Chỗ tự đổi giữa các ảnh của cùng một lần chạy (người đi, đuôi mèo, mưa) là chỗ động, không tính là khác.

Chạy:
  python3 tools/so_anh/so_sanh.py --goc anh_main --moi anh_pr --out trang_so_anh [--tieu-de "PR #12"]
Kết quả: <out>/index.html (mở bằng trình duyệt, ảnh nằm trong <out>/img/), <out>/tom_tat.md, <out>/ket_qua.json.
Luôn thoát mã 0: khác ảnh chỉ để báo, không làm đỏ CI. Cần Pillow và numpy.
"""
import argparse
import html
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

# Một điểm ảnh coi là đổi khi một kênh màu lệch hơn mức này (0-255)
PIXEL_T = 24
# Lưới ô vuông để gom điểm đổi thành vùng; ô có ít hơn CELL_MIN điểm đổi thì bỏ (răng cưa, nhiễu)
CELL = 12
CELL_MIN = 6
# Vùng nhỏ hơn MIN_PX điểm đổi thì không tính là khác
MIN_PX = 40
# Chỗ động nở thêm chừng này ô mỗi phía (đuôi mèo vẫy xa hơn hai ảnh đã chụp)
MOVE_GROW = 2

SECTIONS = [
    ("thu_hai", "Thứ Hai"), ("thu_ba", "Thứ Ba"), ("thu_tu", "Thứ Tư"), ("thu_nam", "Thứ Năm"),
    ("thu_sau", "Thứ Sáu"), ("thu_bay", "Thứ Bảy"), ("chu_nhat", "Chủ Nhật"),
]
SHOT_NAMES = {"tren_cao": "nhìn từ trên cao", "lo_banh": "lò bánh Cô Ba", "bep_toan_canh": "màn bếp",
              "menu_chinh": "màn hình chính"}


def nice_name(n):
    for key, day in SECTIONS:
        if n.startswith(key + "_"):
            rest = n[len(key) + 1:]
            if rest.startswith("don"):
                return f"{day} · đơn {rest[3:]}"
            return f"{day} · {SHOT_NAMES.get(rest, rest)}"
    return SHOT_NAMES.get(n, n)


def load(path, size=None):
    if not os.path.exists(path):
        return None
    im = Image.open(path).convert("RGB")
    if size and im.size != size:
        im = im.resize(size, Image.BILINEAR)
    return im


def changed(a, b):
    return np.abs(np.asarray(a, np.int16) - np.asarray(b, np.int16)).max(axis=2) > PIXEL_T


def cells(mask):
    h, w = mask.shape
    gh, gw = (h + CELL - 1) // CELL, (w + CELL - 1) // CELL
    pad = np.zeros((gh * CELL, gw * CELL), bool)
    pad[:h, :w] = mask
    return pad.reshape(gh, CELL, gw, CELL).sum(axis=(1, 3))


def grow(grid, n):
    out = grid.copy()
    for _ in range(n):
        g = out.copy()
        g[1:, :] |= out[:-1, :]
        g[:-1, :] |= out[1:, :]
        g[:, 1:] |= out[:, :-1]
        g[:, :-1] |= out[:, 1:]
        out = g
    return out


def regions(grid, counts):
    """Gom các ô đổi sát nhau (cách nhau tối đa một ô) thành vùng: [(x0, y0, x1, y1, số điểm đổi)] theo ô."""
    near = grow(grid, 1)
    seen = np.zeros_like(grid, bool)
    out = []
    gh, gw = grid.shape
    for y in range(gh):
        for x in range(gw):
            if not grid[y, x] or seen[y, x]:
                continue
            stack, box, px = [(y, x)], [x, y, x, y], 0
            seen[y, x] = True
            while stack:
                cy, cx = stack.pop()
                if grid[cy, cx]:
                    px += int(counts[cy, cx])
                    box = [min(box[0], cx), min(box[1], cy), max(box[2], cx), max(box[3], cy)]
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < gh and 0 <= nx < gw and near[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True
                            stack.append((ny, nx))
            out.append((*box, px))
    return out


def compare(name, args, img_dir):
    a = load(os.path.join(args.goc, name + ".png"))
    b = load(os.path.join(args.moi, name + ".png"), a.size if a else None)
    row = {"name": name, "title": nice_name(name), "status": "giong", "pct": 0.0, "regions": 0, "moving_pct": 0.0}
    if a is None or b is None:
        row["status"] = "moi" if a is None else "mat"
        only = b if a is None else a
        only.save(os.path.join(img_dir, name + (".moi" if a is None else ".goc") + ".jpg"), quality=85)
        return row
    moving = np.zeros((a.size[1], a.size[0]), bool)
    for d, first in ((args.goc, a), (args.moi, b)):
        for f in sorted(os.listdir(d)):
            if f.startswith(name + ".sau") and f.endswith(".png"):
                moving |= changed(first, load(os.path.join(d, f), a.size))
    move_grid = grow(cells(moving) > 0, MOVE_GROW)
    diff = changed(a, b)
    counts = cells(diff)
    grid = (counts >= CELL_MIN) & ~move_grid
    boxes = [r for r in regions(grid, counts) if r[4] >= MIN_PX]
    h, w = diff.shape
    real_px = sum(r[4] for r in boxes)
    row["pct"] = round(100.0 * real_px / (w * h), 2)
    row["moving_pct"] = round(100.0 * move_grid.mean(), 1)
    row["regions"] = len(boxes)
    if boxes:
        row["status"] = "khac"
    # Ảnh PR có khung đỏ quanh vùng khác
    marked = b.copy()
    d = ImageDraw.Draw(marked)
    px_boxes = []
    for x0, y0, x1, y1, _ in boxes:
        bx = (max(0, x0 * CELL - 4), max(0, y0 * CELL - 4), min(w - 1, (x1 + 1) * CELL + 3), min(h - 1, (y1 + 1) * CELL + 3))
        px_boxes.append(bx)
        d.rectangle(bx, outline=(230, 30, 40), width=3)
    row["boxes"] = px_boxes
    # Ảnh vùng khác: ảnh main xám mờ, điểm đổi màu đỏ, chỗ động phủ xanh
    grey = np.asarray(a.convert("L"), np.float32)[..., None].repeat(3, axis=2) * 0.45 + 120
    mv = np.kron(move_grid, np.ones((CELL, CELL), bool))[:h, :w]
    grey[mv] = grey[mv] * 0.6 + np.array([40, 110, 200]) * 0.4
    real = diff & ~mv
    grey[real] = [230, 30, 40]
    a.save(os.path.join(img_dir, name + ".goc.jpg"), quality=85)
    marked.save(os.path.join(img_dir, name + ".moi.jpg"), quality=85)
    Image.fromarray(grey.clip(0, 255).astype(np.uint8)).save(os.path.join(img_dir, name + ".khac.jpg"), quality=85)
    return row


STATUS = {"khac": ("Khác", "khac"), "moi": ("Góc mới", "moi"), "mat": ("Mất góc", "mat"), "giong": ("Giống", "giong")}


def page(rows, title, link):
    n_khac = sum(r["status"] != "giong" for r in rows)
    cards = []
    for r in rows:
        label, cls = STATUS[r["status"]]
        n = html.escape(r["name"])
        info = ""
        if r["status"] == "khac":
            info = f'{r["regions"]} vùng khác · {r["pct"]:.2f}% khung hình'
        elif r["status"] == "giong":
            info = "không thấy khác"
        if r.get("moving_pct"):
            info += f' · chỗ động bỏ qua {r["moving_pct"]:.0f}%'
        if r["status"] in ("moi", "mat"):
            src = f"img/{n}.{'moi' if r['status'] == 'moi' else 'goc'}.jpg"
            body = f'<img src="{src}" alt="" loading="lazy">'
            info = "chỉ có trên PR" if r["status"] == "moi" else "chỉ có trên main"
        else:
            body = f'''<div class="cmp" data-view="truot">
  <div class="truot"><img src="img/{n}.goc.jpg" alt="main" loading="lazy"><div class="top"><img src="img/{n}.moi.jpg" alt="PR" loading="lazy"></div>
  <input type="range" min="0" max="100" value="50" aria-label="Kéo để so"><span class="tag l">main</span><span class="tag r">PR</span></div>
  <div class="hai"><figure><img src="img/{n}.goc.jpg" alt="" loading="lazy"><figcaption>main</figcaption></figure><figure><img src="img/{n}.moi.jpg" alt="" loading="lazy"><figcaption>PR</figcaption></figure></div>
  <div class="vung"><img src="img/{n}.khac.jpg" alt="" loading="lazy"></div>
</div>
<div class="tabs"><button data-v="truot" class="on">Kéo so</button><button data-v="hai">Cạnh nhau</button><button data-v="vung">Vùng khác</button></div>'''
        cards.append(f'<section class="card {cls}" data-s="{cls}"><header><h2>{html.escape(r["title"])}</h2>'
                     f'<span class="badge {cls}">{label}</span></header><p class="info">{html.escape(info)}</p>{body}</section>')
    link_html = f' · <a href="{html.escape(link)}">PR trên GitHub</a>' if link else ""
    head = f"{n_khac} / {len(rows)} góc khác main" if n_khac else f"Cả {len(rows)} góc giống main"
    return f'''<!doctype html>
<html lang="vi"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Ảnh so sánh PR</title>
<style>
:root{{--bg:#f6f1e7;--card:#fff;--ink:#2b2420;--mute:#7a6e64;--line:#e4dccf;--khac:#d6453a;--moi:#2f7fb8;--giong:#5a8f4e}}
@media (prefers-color-scheme:dark){{:root{{--bg:#1d1916;--card:#29231f;--ink:#f1e9df;--mute:#a99c90;--line:#3c342e}}}}
*{{box-sizing:border-box}}body{{margin:0;background:var(--bg);color:var(--ink);font:15px/1.5 system-ui,-apple-system,"Segoe UI",sans-serif}}
main{{max-width:1040px;margin:0 auto;padding:20px 16px 60px}}h1{{font-size:22px;margin:0 0 4px}}
.sub{{color:var(--mute);margin:0 0 14px}}.filters{{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:16px}}
button{{font:inherit;border:1px solid var(--line);background:var(--card);color:var(--ink);border-radius:8px;padding:5px 12px;cursor:pointer}}
button.on{{background:var(--ink);color:var(--bg);border-color:var(--ink)}}
.card{{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:14px;margin-bottom:16px}}
.card header{{display:flex;justify-content:space-between;align-items:center;gap:8px}}h2{{font-size:17px;margin:0}}
.info{{color:var(--mute);margin:2px 0 10px;font-size:13px}}
.badge{{font-size:12px;font-weight:600;border-radius:99px;padding:2px 10px;color:#fff;background:var(--giong)}}
.badge.khac,.badge.mat{{background:var(--khac)}}.badge.moi{{background:var(--moi)}}
img{{display:block;width:100%;height:auto;border-radius:6px}}
.cmp>div{{display:none}}.cmp[data-view=truot] .truot,.cmp[data-view=vung] .vung{{display:block}}.cmp[data-view=hai] .hai{{display:grid}}
.truot{{position:relative;user-select:none}}.truot .top{{position:absolute;inset:0;clip-path:inset(0 0 0 50%)}}
.truot input{{position:absolute;inset:0;width:100%;height:100%;opacity:0;cursor:ew-resize;margin:0}}
.tag{{position:absolute;top:8px;font-size:12px;background:#0009;color:#fff;padding:1px 8px;border-radius:6px;pointer-events:none}}.tag.l{{left:8px}}.tag.r{{right:8px}}
.hai{{grid-template-columns:1fr 1fr;gap:8px}}figure{{margin:0}}figcaption{{font-size:12px;color:var(--mute)}}
.tabs{{display:flex;gap:6px;margin-top:8px;flex-wrap:wrap}}.tabs button{{font-size:13px;padding:3px 10px}}
.note{{color:var(--mute);font-size:13px}}
@media (max-width:600px){{.hai{{grid-template-columns:1fr}}}}
</style></head><body><main>
<h1>Ảnh so sánh: {html.escape(title)}</h1>
<p class="sub">{head}{link_html}</p>
<div class="filters"><button data-f="khac" class="on">Chỉ góc khác</button><button data-f="all">Tất cả</button></div>
{"".join(cards)}
<p class="note">Cùng một góc camera chụp trên main và trên PR. Khung đỏ là vùng khác. Ở "Vùng khác": đỏ là điểm đổi, xanh là chỗ tự động đậy (người đi, mưa, mèo thở) nên không tính. Khác ảnh chỉ để báo, không làm đỏ CI.</p>
</main><script>
for (const c of document.querySelectorAll('.card')) {{
  const cmp = c.querySelector('.cmp'); if (!cmp) continue;
  const top = c.querySelector('.top'), r = c.querySelector('input[type=range]');
  r.addEventListener('input', () => top.style.clipPath = `inset(0 0 0 ${{r.value}}%)`);
  for (const b of c.querySelectorAll('.tabs button')) b.onclick = () => {{
    cmp.dataset.view = b.dataset.v; for (const o of c.querySelectorAll('.tabs button')) o.classList.toggle('on', o === b); }};
}}
function filt(f) {{
  for (const c of document.querySelectorAll('.card')) c.style.display = (f === 'all' || c.dataset.s !== 'giong') ? '' : 'none';
  for (const b of document.querySelectorAll('.filters button')) b.classList.toggle('on', b.dataset.f === f);
}}
for (const b of document.querySelectorAll('.filters button')) b.onclick = () => filt(b.dataset.f);
filt(document.querySelectorAll('.card:not([data-s=giong])').length ? 'khac' : 'all');
</script></body></html>
'''


def summary_md(rows, page_link):
    bad = [r for r in rows if r["status"] != "giong"]
    md = ["### Ảnh so sánh với main", ""]
    if not bad:
        md.append(f"Cả {len(rows)} góc chụp giống main (đã bỏ qua chỗ tự động như người đi, mưa).")
    else:
        md += [f"**{len(bad)} / {len(rows)} góc khác main** (chỉ báo, không làm đỏ CI).", "",
               "| Góc | Kết quả |", "|---|---|"]
        for r in bad:
            txt = {"khac": f"{r['regions']} vùng khác, {r['pct']:.2f}% khung hình",
                   "moi": "góc mới, chỉ có trên PR", "mat": "mất góc, chỉ có trên main"}[r["status"]]
            md.append(f"| {r['title']} | {txt} |")
    if page_link:
        md += ["", f"Xem ảnh: [tải trang so sánh]({page_link}) (giải nén, mở `index.html`)."]
    return "\n".join(md) + "\n"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--goc", required=True, help="thư mục ảnh chụp trên main")
    ap.add_argument("--moi", required=True, help="thư mục ảnh chụp trên PR")
    ap.add_argument("--out", required=True)
    ap.add_argument("--tieu-de", default="PR")
    ap.add_argument("--link", default="", help="đường dẫn PR, ghi lên đầu trang")
    ap.add_argument("--link-trang", default="", help="đường dẫn tải trang so sánh, ghi vào tom_tat.md")
    args = ap.parse_args()
    img_dir = os.path.join(args.out, "img")
    os.makedirs(img_dir, exist_ok=True)

    def names(d):
        if not os.path.isdir(d):
            return set()
        return {f[:-4] for f in os.listdir(d) if f.endswith(".png") and ".sau" not in f}

    all_names = names(args.goc) | names(args.moi)
    order = {k: i for i, (k, _) in enumerate(SECTIONS)}

    def key(n):  # theo thứ tự ngày trong tuần, rồi bếp, màn hình chính
        day = next((k for k, _ in SECTIONS if n.startswith(k + "_")), "")
        return (order.get(day, 99), n)

    rows = []
    for n in sorted(all_names, key=key):
        try:
            rows.append(compare(n, args, img_dir))
        except Exception as e:  # một ảnh hỏng không làm hỏng cả trang
            print(f"[so anh] lỗi so {n}: {e}", file=sys.stderr)
    with open(os.path.join(args.out, "index.html"), "w", encoding="utf-8") as f:
        f.write(page(rows, args.tieu_de, args.link))
    with open(os.path.join(args.out, "ket_qua.json"), "w", encoding="utf-8") as f:
        json.dump(rows, f, ensure_ascii=False, indent=2)
    md = summary_md(rows, args.link_trang)
    with open(os.path.join(args.out, "tom_tat.md"), "w", encoding="utf-8") as f:
        f.write(md)
    print(md)
    for r in rows:
        print(f"[so anh] {r['status']:5} {r['name']}  {r['pct']:.2f}%  {r['regions']} vùng")


if __name__ == "__main__":
    main()
