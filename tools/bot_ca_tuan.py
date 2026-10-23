#!/usr/bin/env python3
"""Bot tự chơi cả tuần (mã I1): chạy tests/bot_ca_tuan.gd cho 7 ngày, gộp báo cáo, đỏ khi có lỗi.

Hai lượt cho mỗi ngày:
  autotest  autotest sẵn có của ngày (Bơ dịch chuyển). Đỏ khi main/cảnh in AUTOTEST ... FAIL, không in dòng OK,
            có SCRIPT ERROR, hoặc Bơ rơi khỏi map.
  chạy bộ   Bơ chạy bộ thật theo lưới đường đi tới lò và tới khách (ngày có đơn). Đỏ khi không giao đủ đơn,
            Bơ rơi khỏi map, có SCRIPT ERROR, hoặc quá giờ. Dòng AUTOTEST của main ở lượt này chỉ để tham khảo
            (bot không làm nhiệm vụ phụ, không cố bị Chó Mực đớp). Chỗ bot phải dịch chuyển, đơn trễ: cảnh báo.

Chạy (từ gốc repo, đã --import):
  python3 tools/bot_ca_tuan.py --godot ~/godot/godot              # không màn hình, không ảnh
  xvfb-run -a python3 tools/bot_ca_tuan.py --godot ... --anh      # có ảnh mỗi đơn (renderer opengl3)
Tùy chọn: --ngay thu_hai,thu_ba  --luot autotest|chay_bo|ca_hai  -j 2  --out bot_ca_tuan
Kết quả: <out>/bao_cao.md, <out>/bao_cao.json, <out>/anh/, <out>/log/. Có GITHUB_STEP_SUMMARY thì ghi bảng vào đó.
"""
import argparse
import concurrent.futures as cf
import json
import os
import re
import subprocess
import sys
import time

DAYS = ["thu_hai", "thu_ba", "thu_tu", "thu_nam", "thu_sau", "thu_bay", "chu_nhat"]
DAY_NAMES = {"thu_hai": "Thứ Hai", "thu_ba": "Thứ Ba", "thu_tu": "Thứ Tư", "thu_nam": "Thứ Năm",
             "thu_sau": "Thứ Sáu", "thu_bay": "Thứ Bảy", "chu_nhat": "Chủ Nhật"}
# Ngày không có đơn giao (dạo phố): lượt chạy bộ không có gì để chạy
NO_ORDERS = {"thu_bay"}
# Cờ thêm cho autotest của từng ngày (giống bước CI trong desktop.yml)
EXTRA = {"thu_tu": ["--ngap"]}
NOISE = re.compile(r"mesh_storage|Parameter \"m\"")


def run_one(args, day, mode):
    out = args.out
    tag = f"{mode}_{day}"
    report_path = os.path.abspath(os.path.join(out, "json", tag + ".json"))
    log_path = os.path.join(out, "log", tag + ".log")
    cmd = [args.godot]
    if args.anh:
        cmd += ["--rendering-driver", "opengl3", "--resolution", "640x360"]
    else:
        cmd += ["--headless"]
    cmd += ["--path", ".", "-s", "tests/bot_ca_tuan.gd", "--", "--autotest", f"--ngay={day}",
            f"--bot-bao={report_path}"] + EXTRA.get(day, [])
    if mode == "chay_bo":
        cmd.append("--bot-di")
    if args.anh:
        cmd.append("--bot-anh=" + os.path.abspath(os.path.join(out, "anh", tag)))
    if os.path.exists(report_path):
        os.remove(report_path)
    # Mỗi lượt một thư mục user:// riêng (XDG_DATA_HOME) để các ngày chạy song song không ghi đè file lưu thử
    env = dict(os.environ, XDG_DATA_HOME=os.path.abspath(os.path.join(out, "user", tag)))
    t0 = time.time()
    timed_out = False
    try:
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=args.timeout, env=env)
        code, raw = p.returncode, p.stdout
    except subprocess.TimeoutExpired as e:
        code, raw, timed_out = -1, e.stdout or b"", True
    text = raw.decode("utf-8", "replace")
    with open(log_path, "w", encoding="utf-8") as f:
        f.write("\n".join(l for l in text.splitlines() if not NOISE.search(l)))
    rep = {}
    if os.path.exists(report_path):
        with open(report_path, encoding="utf-8") as f:
            rep = json.load(f)
    lines = text.splitlines()
    autotest_lines = [l.strip() for l in lines if l.startswith("AUTOTEST")]
    script_errors = [l.strip() for l in lines if "SCRIPT ERROR" in l]
    problems = []
    if timed_out:
        problems.append(f"quá {args.timeout} giây chưa xong")
    if not rep:
        problems.append("không có báo cáo (game thoát giữa chừng?)")
    if script_errors:
        problems.append(f"{len(script_errors)} SCRIPT ERROR: {script_errors[0][:160]}")
    falls = rep.get("falls", [])
    if falls:
        f0 = falls[0]
        more = f" (và {len(falls) - 1} lần nữa)" if len(falls) > 1 else ""
        problems.append(f"Bơ rơi khỏi map ở {f0['pos']} ({f0['scene']}, đơn {f0['order']}){more}")
    if mode == "autotest":
        ok_marker = "AUTOTEST OK" if day == "thu_hai" else f"AUTOTEST {day.upper()} OK"
        fails = [l for l in autotest_lines if "FAIL" in l]
        if fails:
            problems.append(fails[0])
        elif ok_marker not in autotest_lines:
            problems.append(f"không thấy dòng \"{ok_marker}\" (mã thoát {code})")
    else:
        got, want = len(rep.get("orders", [])), rep.get("expected", 0)
        if rep and got < want:
            problems.append(f"chỉ giao được {got}/{want} đơn")
    warnings = []
    for tp in rep.get("teleports", []):
        warnings.append(f"đơn {tp['order']}: {tp['why']}")
    for o in rep.get("orders", []):
        if o.get("late"):
            warnings.append(f"đơn {o['index']} {o['who']}: giao trễ")
    return {"day": day, "mode": mode, "ok": not problems, "problems": problems, "warnings": warnings,
            "autotest": autotest_lines, "seconds": round(time.time() - t0, 1), "report": rep,
            "log": os.path.relpath(log_path, out)}


def fmt_left(o):
    if o.get("untimed"):
        return "không tính giờ"
    if o.get("late"):
        return "**trễ**"
    s = f"{o['left']:.0f}/{o['limit']:.0f} s"
    if o.get("scene"):
        s += " (chung cư)"
    return s


def markdown(results, args):
    md = ["# Bot tự chơi cả tuần", ""]
    bad = [r for r in results if not r["ok"]]
    md.append("**Kết quả: " + ("ĐỎ, " + f"{len(bad)} lượt hỏng" if bad else "XANH, mọi lượt đều chơi hết") + "**")
    md.append("")
    md.append("| Ngày | Autotest (dịch chuyển) | Chạy bộ thật | Đơn giao | Bot dịch chuyển |")
    md.append("|---|---|---|---|---|")
    by = {(r["day"], r["mode"]): r for r in results}
    for d in [d for d in DAYS if any(r["day"] == d for r in results)]:
        a, w = by.get((d, "autotest")), by.get((d, "chay_bo"))
        cell = lambda r: "–" if r is None else ("✅" if r["ok"] else "❌ " + "; ".join(r["problems"])) + f" ({r['seconds']:.0f}s)"
        rep = (w or a or {}).get("report", {})
        orders = f"{len(rep.get('orders', []))}/{rep.get('expected', 0)}" if rep else "?"
        tps = str(len(w["report"].get("teleports", []))) if w and w.get("report") else "–"
        md.append(f"| {DAY_NAMES[d]} | {cell(a)} | {cell(w)} | {orders} | {tps} |")
    walks = [r for r in results if r["mode"] == "chay_bo" and r["report"].get("orders")]
    if walks:
        md += ["", "## Giờ còn dư mỗi đơn (Bơ chạy bộ thật, chạy nhanh hết cỡ theo đường ngắn nhất)", "",
               "Bot chạy giỏi hơn người mới chơi, nên số dư thật của người chơi sẽ ít hơn. "
               "Đơn có dấu * là bot đã phải dịch chuyển một đoạn (leo, nhảy, kẹt), số giờ đó lạc quan hơn thật.", "",
               "| Ngày | " + " | ".join(f"Đơn {i}" for i in range(1, 6)) + " |",
               "|---|" + "---|" * 5]
        for r in walks:
            cells = []
            for o in r["report"]["orders"][:5]:
                star = "*" if o.get("teleports") else ""
                cells.append(f"{o['who']}: {fmt_left(o)}{star} · {o['stars']}★")
            cells += [""] * (5 - len(cells))
            md.append(f"| {DAY_NAMES[r['day']]} | " + " | ".join(cells) + " |")
    warn = [(r, w) for r in results for w in r["warnings"]]
    if warn:
        md += ["", "## Cảnh báo (không làm đỏ)", ""]
        for r, w in warn:
            md.append(f"- {DAY_NAMES[r['day']]} ({'chạy bộ' if r['mode'] == 'chay_bo' else 'autotest'}): {w}")
    if args.anh:
        md += ["", "Ảnh mỗi đơn nằm trong artifact `bot-ca-tuan` (thư mục anh/)."]
    return "\n".join(md) + "\n"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    ap.add_argument("--ngay", default=",".join(DAYS))
    ap.add_argument("--luot", choices=["autotest", "chay_bo", "ca_hai"], default="ca_hai")
    ap.add_argument("--anh", action="store_true", help="chụp ảnh mỗi đơn (cần màn hình, ví dụ xvfb-run)")
    ap.add_argument("-j", type=int, default=2, help="số ngày chạy cùng lúc")
    ap.add_argument("--timeout", type=int, default=900, help="giây tối đa cho một lượt")
    ap.add_argument("--out", default="bot_ca_tuan")
    args = ap.parse_args()
    for sub in ("json", "log", "anh"):
        os.makedirs(os.path.join(args.out, sub), exist_ok=True)
    days = [d for d in args.ngay.split(",") if d]
    jobs = []
    for d in days:
        if args.luot in ("autotest", "ca_hai"):
            jobs.append((d, "autotest"))
        if args.luot in ("chay_bo", "ca_hai") and d not in NO_ORDERS:
            jobs.append((d, "chay_bo"))
    results = []
    with cf.ThreadPoolExecutor(max_workers=max(1, args.j)) as ex:
        futs = {ex.submit(run_one, args, d, m): (d, m) for d, m in jobs}
        for fut in cf.as_completed(futs):
            r = fut.result()
            results.append(r)
            mark = "OK " if r["ok"] else "LỖI"
            print(f"[{mark}] {DAY_NAMES[r['day']]:9} {r['mode']:8} {r['seconds']:6.0f}s  " + "; ".join(r["problems"]), flush=True)
    order = {(d, m): i for i, (d, m) in enumerate(jobs)}
    results.sort(key=lambda r: order[(r["day"], r["mode"])])
    md = markdown(results, args)
    with open(os.path.join(args.out, "bao_cao.md"), "w", encoding="utf-8") as f:
        f.write(md)
    with open(os.path.join(args.out, "bao_cao.json"), "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as f:
            f.write(md)
    print(md)
    bad = [r for r in results if not r["ok"]]
    if bad:
        print("BOT CA TUAN FAIL: " + ", ".join(f"{r['day']}/{r['mode']}" for r in bad))
        sys.exit(1)
    print("BOT CA TUAN OK")


if __name__ == "__main__":
    main()
