#!/usr/bin/env python3
"""PH3: ghép 8 khung Bơ chạy (tools/chup_bo_tai.gd) thành một dải webp nền trong, nhúng vào web/vo_trang.html.

    python3 tools/web/lam_bo_tai.py <thư_mục_khung>

Thay dòng giữa hai dấu BO_TAI trong web/vo_trang.html bằng ảnh data: (vỏ trang không cần file ảnh riêng,
itch.yml và xuat_web.sh không phải chép thêm gì).
"""
import base64
import io
import re
import sys
from pathlib import Path

from PIL import Image

KHUNG = 8
CAO = 144  # px mỗi khung (hiện ở 72 px CSS: sắc nét trên màn hình hai lần mật độ)


def main() -> None:
    thu_muc = Path(sys.argv[1])
    anh = [Image.open(thu_muc / f"bo_chay_{i}.png").convert("RGBA") for i in range(KHUNG)]
    # Khung chung bao hết mọi khung, để Bơ không nhảy chỗ giữa các khung
    hop = [a.getbbox() for a in anh]
    x0 = min(h[0] for h in hop) - 2
    y0 = min(h[1] for h in hop) - 2
    x1 = max(h[2] for h in hop) + 2
    y1 = max(h[3] for h in hop) + 2
    rong = round((x1 - x0) * CAO / (y1 - y0))
    dai = Image.new("RGBA", (rong * KHUNG, CAO), (0, 0, 0, 0))
    for i, a in enumerate(anh):
        dai.paste(a.crop((x0, y0, x1, y1)).resize((rong, CAO), Image.LANCZOS), (i * rong, 0))
    buf = io.BytesIO()
    dai.save(buf, "WEBP", quality=82, method=6)
    data = base64.b64encode(buf.getvalue()).decode()
    trang = Path(__file__).resolve().parents[2] / "web" / "vo_trang.html"
    s = trang.read_text(encoding="utf-8")
    moi = f"/*BO_TAI*/--bo-anh: url(data:image/webp;base64,{data}); --bo-rong: {rong / 2:g}px;/*BO_TAI*/"
    s, n = re.subn(r"/\*BO_TAI\*/.*?/\*BO_TAI\*/", lambda _m: moi, s, flags=re.S)
    assert n == 1, "web/vo_trang.html thiếu chỗ /*BO_TAI*/ ... /*BO_TAI*/"
    trang.write_text(s, encoding="utf-8")
    print(f"dải {dai.size[0]}x{CAO}, {len(buf.getvalue()) // 1024} KB, mỗi khung {rong / 2:g}x{CAO // 2} px CSS")


if __name__ == "__main__":
    main()
