"""Dựng trailer từ các cảnh đã quay (tools/trailer/quay.sh) + nhạc (nhac_trailer.py) bằng ffmpeg.

Chạy:  python3 tools/trailer/dung_trailer.py <thư_mục_cảnh> <nhạc.wav> <ra.mp4> [rộng cao]
Mốc thời gian khớp nhịp nhạc 100 BPM (1 ô nhịp = 2,4 giây), xem tools/trailer/README.md.
Mỗi dòng CUTS: (tên file cảnh, giây bắt đầu trong file, độ dài, chữ trên hình hoặc None).
Mặc định chỉ có nhạc trailer (Sang muốn không có giọng nói); thêm --tieng-game để trộn tiếng game dưới nhạc.
"""
import os
import subprocess
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
FONT_TITLE = os.path.join(ROOT, "assets", "fonts", "Baloo2-ExtraBold.ttf")
FONT_TEXT = os.path.join(ROOT, "assets", "fonts", "BeVietnamPro-Bold.ttf")
WARM = 0.5  # nửa giây đầu mỗi file cảnh là lúc cảnh ổn định, bỏ đi

# (file, bắt đầu, dài, thẻ ngày)  — tổng các đoạn khớp mốc nhạc: mo 0, bep 4.8, pho 14.4, muc 26.4, tuan 32.4, tu_do 54, ket 61.2
CUTS = [
    ("mo_dau", 0.0, 4.8, None),
    # bếp: chỉ lấy những đoạn bot làm liền tay (đo YDIF không có quá 1 khung đứng yên liền nhau), tránh chỗ bot dừng chờ
    ("bep", 12.5, 2.4, None),
    ("bep", 14.9, 2.4, None),
    ("bep", 59.9, 2.4, None),
    ("bep", 62.5, 2.4, None),
    ("chay_ra_pho", 0.0, 3.0, None),
    ("nga_tu", 0.0, 2.4, None),
    ("giao_chu_tu", 0.45, 2.2, None),
    ("giao_anh_hung", 0.6, 2.2, None),
    ("tren_cao", 0.0, 2.2, None),
    ("muc", 0.0, 6.0, None),
    ("giao_chi_may", 0.6, 3.0, "THỨ HAI · Mẻ bánh đầu tiên"),
    ("thu_ba", 0.0, 3.0, "THỨ BA · Chợ đông chen hẻm"),
    ("thu_tu", 0.0, 3.0, "THỨ TƯ · Mưa ngập, chạy trên cao"),
    ("thu_nam", 0.0, 3.0, "THỨ NĂM · Leo chung cư"),
    ("thu_sau", 0.0, 3.0, "THỨ SÁU · Tiệm xe chiều tà"),
    ("thu_bay", 0.0, 3.0, "THỨ BẢY · Dạo phố hoàng hôn"),
    ("chu_nhat", 0.0, 3.6, "CHỦ NHẬT · Hội mèo"),
    ("tu_do", 0.0, 7.2, None),
    ("ket", 0.0, 8.0, None),
]
# chữ giữa màn hình phía dưới: (từ giây, tới giây, chữ)
CAPTIONS = [
    (0.8, 4.4, "Sáu giờ sáng, khu phố bắt đầu đói bụng…"),
    (5.4, 13.8, "Phụ Cô Ba làm bánh mì"),
    (15.0, 20.5, "…rồi giao tận tay cả xóm"),
    (28.6, 32.2, "Đừng đánh thức Chó Mực"),
    (54.6, 60.9, "19 giống mèo · 45 món phụ kiện"),
]
TITLE_AT = 64.0   # hiện tên game
LINK_AT = 66.0    # hiện dòng chơi thử
END = 76.0


def esc(t):
    return t.replace("\\", "\\\\").replace(":", "\\:").replace("'", "’").replace(",", "\\,")


def fade_alpha(a, b, f=0.35):
    return f"if(lt(t,{a}),0,if(lt(t,{a + f}),(t-{a})/{f},if(lt(t,{b - f}),1,if(lt(t,{b}),({b}-t)/{f},0))))"


def build(src, music, out, w=1920, h=1080, game_gain=0.0):
    inputs, parts, auds = [], [], []
    t = 0.0
    day_cards = []
    for k, (name, start, dur, card) in enumerate(CUTS):
        path = os.path.join(src, name + ".avi")
        inputs += ["-ss", "%.3f" % (start + WARM), "-t", "%.3f" % dur, "-i", path]
        parts.append(f"[{k}:v]scale={w}:{h}:force_original_aspect_ratio=increase,crop={w}:{h},setsar=1,fps=30,"
                     f"format=yuv420p,trim=duration={dur},setpts=PTS-STARTPTS[v{k}]")
        auds.append(f"[{k}:a]aresample=48000,aformat=channel_layouts=stereo,atrim=duration={dur},asetpts=PTS-STARTPTS,"
                    f"apad=whole_dur={dur}[a{k}]")
        if card:
            day_cards.append((t + 0.15, t + dur - 0.1, card))
        t += dur
    n = len(CUTS)
    inputs += ["-i", music]
    fs_cap = int(h * 0.046)
    fs_card = int(h * 0.04)
    chain = "".join(f"[v{k}]" for k in range(n)) + f"concat=n={n}:v=1:a=0[cat]"
    draws = []
    for a, b, text in CAPTIONS:
        draws.append(f"drawtext=fontfile='{FONT_TEXT}':text='{esc(text)}':fontsize={fs_cap}:fontcolor=0xFFF8EA:"
                     f"box=1:boxcolor=0x2B2420@0.82:boxborderw={int(fs_cap * 0.45)}:x=(w-text_w)/2:y=h*0.84:"
                     f"alpha='{fade_alpha(a, b)}'")
    for a, b, text in day_cards:
        draws.append(f"drawtext=fontfile='{FONT_TITLE}':text='{esc(text)}':fontsize={fs_card}:fontcolor=0x2B2420:"
                     f"box=1:boxcolor=0xFFF8EA@0.94:boxborderw={int(fs_card * 0.5)}:x=w*0.045:y=h*0.07:"
                     f"alpha='{fade_alpha(a, b, 0.2)}'")
    # Kết: tên game và dòng chơi thử trên nền tối dần
    draws.append(f"drawbox=x=0:y=0:w=iw:h=ih:color=0x1D1916@0.55:t=fill:enable='gte(t,{TITLE_AT})'")
    draws.append(f"drawtext=fontfile='{FONT_TITLE}':text='Mèo Giao Bánh Mì':fontsize={int(h * 0.13)}:fontcolor=0xF2B45A:"
                 f"borderw={int(h * 0.006)}:bordercolor=0x2B2420:x=(w-text_w)/2:y=h*0.30:alpha='{fade_alpha(TITLE_AT, END + 5, 0.6)}'")
    draws.append(f"drawtext=fontfile='{FONT_TEXT}':text='Chơi miễn phí trên web':fontsize={int(h * 0.045)}:fontcolor=0xFFF8EA:"
                 f"x=(w-text_w)/2:y=h*0.55:alpha='{fade_alpha(LINK_AT, END + 5, 0.5)}'")
    draws.append(f"drawtext=fontfile='{FONT_TEXT}':text='sangdaden.github.io/meo-giao-banh-mi':fontsize={int(h * 0.038)}:"
                 f"fontcolor=0x2B2420:box=1:boxcolor=0xF2B45A:boxborderw={int(h * 0.016)}:x=(w-text_w)/2:y=h*0.64:"
                 f"alpha='{fade_alpha(LINK_AT + 0.4, END + 5, 0.5)}'")
    hold = max(0.0, END - t)  # giữ khung cuối của cảnh kết dưới tên game tới hết nhạc
    vf = f"[cat]tpad=stop_mode=clone:stop_duration={hold:.2f},{','.join(draws)},fade=t=in:st=0:d=0.8,fade=t=out:st={END - 1.5}:d=1.5[vout]"
    achain = "".join(f"[a{k}]" for k in range(n)) + f"concat=n={n}:v=0:a=1,volume={game_gain}[game]"
    mix = f"[game][{n}:a]amix=inputs=2:duration=longest:normalize=0,alimiter=limit=0.9,atrim=duration={END},afade=t=out:st={END - 2}:d=2[aout]"
    fc = ";".join(parts + auds + [chain, vf, achain, mix])
    cmd = ["ffmpeg", "-y", "-loglevel", "error"] + inputs + [
        "-filter_complex", fc, "-map", "[vout]", "-map", "[aout]", "-t", str(END),
        "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p", "-r", "30",
        "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", out]
    subprocess.run(cmd, check=True)
    print("tổng các đoạn %.1f giây -> %s" % (t, out))


if __name__ == "__main__":
    a = sys.argv
    # Sang (22/10/2026): trailer chỉ để nhạc, không giọng nói. --tieng-game trộn lại tiếng game (có lời thoại) dưới nhạc.
    game = 0.55 if "--tieng-game" in a else 0.0
    a = [x for x in a if not x.startswith("--")]
    size = (int(a[4]), int(a[5])) if len(a) > 5 else (1920, 1080)
    build(a[1], a[2], a[3], *size, game_gain=game)
