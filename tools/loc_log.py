#!/usr/bin/env python3
"""Lọc log Godot trong CI (mã KT2): bỏ các lỗi đã biết là vô hại, lỗi mới thì làm đỏ.

Danh sách lỗi được phép: tools/loi_duoc_phep.txt (mỗi dòng một biểu thức chính quy, có ghi lý do).
Mọi dòng ERROR / SCRIPT ERROR / USER ERROR khác là lỗi mới.

Hai cách gọi:
  godot ... 2>&1 | python3 tools/loc_log.py | tee x.log    # lọc: bỏ lỗi được phép (kèm dòng "at:" ngay sau)
  python3 tools/loc_log.py --kiem *.log                     # kiểm: còn lỗi mới thì in ra và thoát mã 1

Thêm một lỗi vào danh sách được phép chỉ khi đã hiểu nó vô hại (lỗi của bộ vẽ giả lúc --headless,
rò rỉ lúc thoát...). Lỗi do code game gây ra thì sửa code, đừng thêm vào danh sách.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
LIST = os.path.join(HERE, "loi_duoc_phep.txt")
# Dòng báo lỗi của Godot: "ERROR: ...", "SCRIPT ERROR: ...", "USER ERROR: ...", "USER SCRIPT ERROR: ..."
ERR = re.compile(r"^\s*(USER )?(SCRIPT )?ERROR:")
# Dòng chỉ chỗ lỗi đi ngay sau dòng ERROR
AT = re.compile(r"^\s+at: ")


def load_allowed(path=LIST):
    pats = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            pats.append(re.compile(line))
    return pats


def allowed(line, pats):
    return any(p.search(line) for p in pats)


def new_errors(lines, pats):
    """Các dòng lỗi không nằm trong danh sách được phép."""
    return [l for l in lines if ERR.match(l) and not allowed(l, pats)]


def filter_stream(src, dst, pats):
    skip_at = False
    for line in src:
        if skip_at and AT.match(line):
            skip_at = False
            continue
        skip_at = False
        if ERR.match(line) and allowed(line, pats):
            skip_at = True
            continue
        dst.write(line)
        dst.flush()


def main(argv):
    pats = load_allowed()
    if argv and argv[0] == "--kiem":
        bad = 0
        for path in argv[1:]:
            with open(path, encoding="utf-8", errors="replace") as f:
                errs = new_errors(f.read().splitlines(), pats)
            for e in errs[:20]:
                print(f"::error file={path}::Lỗi mới trong log: {e.strip()[:300]}")
            if len(errs) > 20:
                print(f"::error file={path}::... và {len(errs) - 20} dòng lỗi nữa")
            bad += len(errs)
        if bad:
            print(f"Có {bad} dòng lỗi mới (không nằm trong tools/loi_duoc_phep.txt). "
                  "Sửa lỗi trong code; chỉ thêm vào danh sách khi chắc lỗi vô hại.")
            return 1
        print(f"LOG SACH: {len(argv) - 1} file log không có lỗi mới")
        return 0
    src = open(sys.stdin.fileno(), encoding="utf-8", errors="replace", closefd=False)
    filter_stream(src, sys.stdout, pats)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
