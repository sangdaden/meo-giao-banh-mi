#!/usr/bin/env python3
"""Dựng clip dọc 9:16 cho devlog (PH4) từ các file .avi do quay_clip_doc.gd ghi.

    python3 tools/clip_doc/dung_clip.py <thư_mục_avi> <thư_mục_ra> [tên_clip ...]

Mỗi clip: bỏ 0,5 s đầu (cảnh đang ổn định), phóng lên 1080x1920, chữ trên đầu (tiếng Việt, dòng nhỏ tiếng Anh),
dải tên game dưới chân, tiếng game trộn với nhạc nền của game, chuẩn độ to -16 LUFS. Ra <tên>.mp4 và trang xem index.html.
Không đăng gì: Sang chọn clip rồi tự đăng (Metricool).
"""
import html
import os
import subprocess
import sys

GOC = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(GOC, "..", ".."))
F_TITLE = os.path.join(REPO, "assets/fonts/Baloo2-ExtraBold.ttf")
F_TEXT = os.path.join(REPO, "assets/fonts/BeVietnamPro-Bold.ttf")
CAM = "0xFFB347"
KEM = "0xF6EBDD"

# tên clip: (chữ to tiếng Việt, dòng nhỏ tiếng Anh, nhạc nền)
CLIPS = {
    "leo": ("Leo chung cư giao bánh", "Climbing up to deliver bánh mì", "music_delivery.ogg"),
    "giao": ("Bánh mì còn nóng nè Chú Tư!", "Still warm, delivered!", "music_delivery.ogg"),
    "mua_mai": ("Mưa ngập? Chạy trên mái!", "Flooded street? Take the awnings", "music_delivery.ogg"),
    "muc": ("Rón rén qua hẻm Chó Mực", "Sneaking past Mực the dog", "music_chase.ogg"),
    "chay": ("Giao bánh khắp phố", "Morning bánh mì run", "music_delivery.ogg"),
}
BO_DAU = 0.5  # giây đầu bỏ đi


def esc(s: str) -> str:
    return s.replace("\\", "\\\\").replace(":", "\\:").replace("'", "’").replace("%", "\\%")


def co_chu(text: str, font: str, co: int, rong: int = 960) -> int:
    """Cỡ chữ lớn nhất (không quá co) để dòng chữ vừa bề ngang rong điểm ảnh."""
    try:
        from PIL import ImageFont
    except ImportError:
        return int(co * min(1.0, 22.0 / max(len(text), 1)))
    while co > 30 and ImageFont.truetype(font, co).getlength(text) > rong:
        co -= 2
    return co


def dung(avi: str, ra: str, ten: str) -> None:
    to, nho, nhac = CLIPS.get(ten, (ten, "", "music_delivery.ogg"))
    c_to, c_nho = co_chu(to, F_TITLE, 84), co_chu(nho, F_TEXT, 40)
    vf = (
        "scale=1080:1920:flags=lanczos,"
        # chữ trên đầu (dưới vùng tên kênh của TikTok/Reels), nền tối mờ cho dễ đọc trên trời sáng
        "drawbox=x=0:y=110:w=iw:h=250:color=black@0.35:t=fill,"
        f"drawtext=fontfile={F_TITLE}:text='{esc(to)}':fontsize={c_to}:fontcolor={KEM}:x=(w-tw)/2:y=150:"
        "borderw=3:bordercolor=black@0.6,"
        f"drawtext=fontfile={F_TEXT}:text='{esc(nho)}':fontsize={c_nho}:fontcolor=white:x=(w-tw)/2:y=270,"
        # dải tên game dưới chân (tránh vùng nút của TikTok/Reels: chữ đặt cao hơn mép dưới ~ 300 px)
        "drawbox=x=0:y=1560:w=iw:h=150:color=black@0.35:t=fill,"
        f"drawtext=fontfile={F_TITLE}:text='Mèo Giao Bánh Mì':fontsize=64:fontcolor={CAM}:x=(w-tw)/2:y=1575,"
        f"drawtext=fontfile={F_TEXT}:text='{esc('Chơi miễn phí trên trình duyệt')}':fontsize=34:fontcolor=white:x=(w-tw)/2:y=1655,"
        "fade=t=in:st=0:d=0.25"
    )
    nhac_file = os.path.join(REPO, "assets/audio", nhac)
    af = ("[0:a]volume=1.0[g];[1:a]volume=0.45,afade=t=in:d=0.4[m];"
          "[g][m]amix=inputs=2:duration=first:normalize=0,loudnorm=I=-16:TP=-1.5:LRA=11[a]")
    cmd = ["ffmpeg", "-loglevel", "error", "-y", "-ss", str(BO_DAU), "-i", avi,
           "-stream_loop", "-1", "-i", nhac_file,
           "-filter_complex", f"[0:v]{vf}[v];{af}", "-map", "[v]", "-map", "[a]",
           "-shortest", "-c:v", "libx264", "-preset", "medium", "-crf", "21", "-pix_fmt", "yuv420p",
           "-ar", "48000", "-c:a", "aac", "-b:a", "160k", "-movflags", "+faststart", ra]
    subprocess.run(cmd, check=True)
    # tắt dần tiếng ở 0,3 s cuối cho khỏi cụt
    dur = float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", ra],
                               capture_output=True, text=True, check=True).stdout.strip())
    tmp = ra + ".tmp.mp4"
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", ra, "-c:v", "copy",
                    "-af", f"afade=t=out:st={max(dur - 0.3, 0):.2f}:d=0.3", "-c:a", "aac", "-b:a", "160k",
                    "-movflags", "+faststart", tmp], check=True)
    os.replace(tmp, ra)
    # ảnh bìa cho trang xem
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-ss", f"{min(1.5, dur / 2):.2f}", "-i", ra,
                    "-frames:v", "1", "-vf", "scale=360:-1", "-q:v", "4", ra[:-4] + ".jpg"], check=True)


def trang(ra_dir: str, xong: list) -> None:
    the = []
    for ten in xong:
        to, nho, _ = CLIPS.get(ten, (ten, "", ""))
        the.append(f'<figure><video controls preload="none" poster="{ten}.jpg" src="{ten}.mp4"></video>'
                   f'<figcaption><b>{html.escape(to)}</b><br>{html.escape(nho)}<br><code>{ten}.mp4</code></figcaption></figure>')
    with open(os.path.join(ra_dir, "index.html"), "w", encoding="utf-8") as f:
        f.write("<!doctype html><meta charset='utf-8'><meta name='viewport' content='width=device-width'>"
                "<title>Clip dọc devlog</title><style>body{font:15px system-ui;background:#2B2320;color:#F6EBDD;margin:16px}"
                "main{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:16px}"
                "video{width:100%;aspect-ratio:9/16;border-radius:10px;background:#000}"
                "h1{color:#FFB347}</style><h1>Clip dọc 9:16 cho devlog</h1>"
                "<p>Dựng tự động từ game thật. Chọn clip rồi tự đăng qua Metricool; không có gì được đăng tự động.</p>"
                f"<main>{''.join(the)}</main>")


def main() -> None:
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    vao, ra_dir = sys.argv[1], sys.argv[2]
    ten_clip = sys.argv[3:] or list(CLIPS)
    os.makedirs(ra_dir, exist_ok=True)
    xong = []
    for ten in ten_clip:
        avi = os.path.join(vao, ten + ".avi")
        if not os.path.exists(avi) or os.path.getsize(avi) < 10000:
            print(f"thiếu {avi}, bỏ qua")
            continue
        dung(avi, os.path.join(ra_dir, ten + ".mp4"), ten)
        xong.append(ten)
        print(f"xong {ten}.mp4")
    trang(ra_dir, xong)
    print(f"CLIP DOC OK {len(xong)}/{len(ten_clip)}")


if __name__ == "__main__":
    main()
