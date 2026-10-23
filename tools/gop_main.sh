#!/usr/bin/env bash
# Thử gộp main vào từng PR đang mở (docs/gop-main.md).
# - Gộp sạch: đẩy commit gộp lên nhánh PR (trừ khi TU_GOP=0 hoặc PR có nhãn "khong-tu-gop").
# - Đụng nhau: gắn nhãn "dung-main", ghi một bình luận (sửa lại bình luận cũ, không đăng chồng)
#   liệt kê file đụng và cách sửa, đặt trạng thái đỏ "Gộp với main" lên commit đầu nhánh.
# - Hết đụng: gỡ nhãn, sửa bình luận thành "đã hết đụng".
#
# Cách gọi:  tools/gop_main.sh            -> mọi PR đang mở vào main
#            tools/gop_main.sh 12 15      -> chỉ các PR này
# Biến môi trường:
#   GITHUB_REPOSITORY  chủ/repo (bắt buộc), GH_TOKEN cho gh
#   TU_GOP=1           1 = đẩy commit gộp, 0 = chỉ kiểm và báo
#   CHAY_LAI_CI=1      sau khi đẩy bằng GITHUB_TOKEN, gọi lại các workflow PR trên nhánh
#                      (đẩy bằng GITHUB_TOKEN không tự kích hoạt CI)
#   KHO=0              1 = trả mã lỗi 1 nếu có PR đụng (dùng cho check trên PR)
#   THU=0              1 = chạy thử: không đẩy, không gọi API ghi
set -uo pipefail

BASE=${BASE:-main}
REPO=${GITHUB_REPOSITORY:?cần GITHUB_REPOSITORY}
TU_GOP=${TU_GOP:-1}
CHAY_LAI_CI=${CHAY_LAI_CI:-1}
KHO=${KHO:-0}
THU=${THU:-0}
NHAN_DUNG=dung-main
NHAN_TAT=khong-tu-gop
NHAN_TAY=gop-tay
DAU='<!-- gop-main -->'
TRANG_THAI="Gộp với main"
# Workflow chạy cho pull_request và có workflow_dispatch: gọi lại sau khi bot đẩy.
WORKFLOW_PR=${WORKFLOW_PR:-"desktop.yml hieu-nang.yml"}
TOM_TAT=${GITHUB_STEP_SUMMARY:-/dev/null}

ghi() { if [ "$THU" = 1 ]; then echo "  (chạy thử) $*"; else "$@"; fi; }

git config user.name >/dev/null || git config user.name "github-actions[bot]"
git config user.email >/dev/null || git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

git fetch -q origin "+refs/heads/$BASE:refs/remotes/origin/$BASE" || { echo "Không tải được $BASE"; exit 1; }
main_sha=$(git rev-parse --short "origin/$BASE")

if [ $# -gt 0 ]; then
  ds=$(for n in "$@"; do gh pr view "$n" --repo "$REPO" \
    --json number,title,headRefName,headRefOid,baseRefName,isCrossRepository,labels; done | jq -s '.')
else
  ds=$(gh pr list --repo "$REPO" --base "$BASE" --state open --limit 100 \
    --json number,title,headRefName,headRefOid,baseRefName,isCrossRepository,labels)
fi

if [ "$THU" != 1 ]; then
  gh label create "$NHAN_DUNG" --repo "$REPO" --color d73a4a \
    --description "Nhánh đụng main, cần gộp tay" >/dev/null 2>&1 || true
  gh label create "$NHAN_TAY" --repo "$REPO" --color fbca04 \
    --description "Gộp sạch nhưng main đổi file workflow, máy không đẩy được" >/dev/null 2>&1 || true
fi

binh_luan_cu() {  # id bình luận của workflow trên PR $1 (nếu có)
  gh api "repos/$REPO/issues/$1/comments" --paginate \
    --jq ".[] | select(.body | contains(\"$DAU\")) | .id" 2>/dev/null | head -1
}

dat_binh_luan() {  # $1 = PR, $2 = nội dung; sửa bình luận cũ nếu có, không thì đăng mới
  local id; id=$(binh_luan_cu "$1")
  if [ -n "$id" ]; then
    ghi gh api -X PATCH "repos/$REPO/issues/comments/$id" -f body="$2" >/dev/null
  else
    ghi gh api "repos/$REPO/issues/$1/comments" -f body="$2" >/dev/null
  fi
}

dat_trang_thai() {  # $1 = sha, $2 = success|failure, $3 = mô tả
  ghi gh api "repos/$REPO/statuses/$1" -f state="$2" -f context="$TRANG_THAI" \
    -f description="$3" >/dev/null || true
}

het_dung() {  # $1 = PR, $2 = sha đầu nhánh hiện tại
  local n=$1 sha=$2
  if [ "$co_nhan_dung" = 1 ] || [ "$co_nhan_tay" = 1 ]; then
    [ "$co_nhan_dung" = 1 ] && { ghi gh pr edit "$n" --repo "$REPO" --remove-label "$NHAN_DUNG" >/dev/null || true; }
    [ "$co_nhan_tay" = 1 ] && { ghi gh pr edit "$n" --repo "$REPO" --remove-label "$NHAN_TAY" >/dev/null || true; }
    local id; id=$(binh_luan_cu "$n")
    if [ -n "$id" ]; then
      ghi gh api -X PATCH "repos/$REPO/issues/comments/$id" \
        -f body="$DAU
✅ Nhánh này đã hết đụng với \`$BASE\` (kiểm ở $BASE $main_sha)." >/dev/null
    fi
  fi
  dat_trang_thai "$sha" success "Gộp sạch với $BASE $main_sha"
}

so_sach=0; so_moi=0; so_dung=0; so_bo=0
dung_ds=""
{
  echo "## Gộp \`$BASE\` ($main_sha) vào các PR đang mở"
  echo
  echo "| PR | Nhánh | Kết quả |"
  echo "|---|---|---|"
} >>"$TOM_TAT"

while read -r pr; do
  [ -z "$pr" ] && continue
  n=$(jq -r .number <<<"$pr")
  nhanh=$(jq -r .headRefName <<<"$pr")
  dau=$(jq -r .headRefOid <<<"$pr")
  goc=$(jq -r .baseRefName <<<"$pr")
  fork=$(jq -r .isCrossRepository <<<"$pr")
  nhan=$(jq -r '[.labels[].name] | join(",")' <<<"$pr")
  co_nhan_dung=0; [[ ",$nhan," == *",$NHAN_DUNG,"* ]] && co_nhan_dung=1
  co_nhan_tay=0; [[ ",$nhan," == *",$NHAN_TAY,"* ]] && co_nhan_tay=1
  tat=0; [[ ",$nhan," == *",$NHAN_TAT,"* ]] && tat=1
  echo "== PR #$n ($nhanh)"

  if [ "$goc" != "$BASE" ] || [ "$fork" = true ]; then
    kq="bỏ qua (gốc $goc, fork=$fork)"; so_bo=$((so_bo+1))
    echo "  $kq"; echo "| #$n | \`$nhanh\` | $kq |" >>"$TOM_TAT"; continue
  fi

  if ! git fetch -q origin "+refs/heads/$nhanh:refs/remotes/origin/$nhanh"; then
    kq="bỏ qua (không tải được nhánh)"; so_bo=$((so_bo+1))
    echo "  $kq"; echo "| #$n | \`$nhanh\` | $kq |" >>"$TOM_TAT"; continue
  fi
  git checkout -q --detach "origin/$nhanh"
  dau=$(git rev-parse HEAD)

  if git merge-base --is-ancestor "origin/$BASE" HEAD; then
    kq="đã có main mới nhất"; so_moi=$((so_moi+1))
    het_dung "$n" "$dau"
    echo "  $kq"; echo "| #$n | \`$nhanh\` | ✅ $kq |" >>"$TOM_TAT"; continue
  fi

  if git merge -q --no-ff --no-edit -m "Tự gộp $BASE ($main_sha) vào $nhanh" "origin/$BASE" >/dev/null 2>&1; then
    so_sach=$((so_sach+1))
    workflow_doi=$(git diff --name-only "$dau" HEAD -- .github/workflows)
    if [ "$TU_GOP" != 1 ] || [ "$tat" = 1 ]; then
      kq="gộp sạch, chưa đẩy"
      [ "$tat" = 1 ] && kq="$kq (nhãn $NHAN_TAT)"
      het_dung "$n" "$dau"
    elif [ -n "$workflow_doi" ] && [ -z "${CO_PAT:-}" ]; then
      # GITHUB_TOKEN không được phép đẩy thay đổi file workflow.
      kq="gộp sạch nhưng main đổi file workflow, cần gộp tay"
      dat_trang_thai "$dau" success "Gộp sạch với $BASE $main_sha (cần gộp tay)"
      if [ "$co_nhan_tay" != 1 ]; then
        ghi gh pr edit "$n" --repo "$REPO" --add-label "$NHAN_TAY" >/dev/null || true
        ds_wf=$(sed 's/^/- `/; s/$/`/' <<<"$workflow_doi")
        dat_binh_luan "$n" "$DAU
ℹ️ Nhánh \`$nhanh\` gộp sạch với \`$BASE\` ($main_sha), nhưng main có đổi file workflow nên máy không được phép tự đẩy:

$ds_wf

Gộp tay một lần (không phải sửa gì):
\`\`\`bash
git pull
git fetch origin $BASE
git merge origin/$BASE
git push
\`\`\`
Sau đó máy tự gộp tiếp được. Xem \`docs/gop-main.md\`."
      fi
    elif ghi git push -q origin "HEAD:refs/heads/$nhanh"; then
      kq="đã gộp và đẩy"
      moi=$(git rev-parse HEAD)
      het_dung "$n" "$moi"
      if [ "$CHAY_LAI_CI" = 1 ] && [ -z "${CO_PAT:-}" ]; then
        for wf in $WORKFLOW_PR; do
          ghi gh workflow run "$wf" --repo "$REPO" --ref "$nhanh" >/dev/null 2>&1 || true
        done
      fi
    else
      kq="gộp sạch nhưng đẩy không được (nhánh vừa đổi?), lần sau thử lại"
    fi
    echo "  $kq"; echo "| #$n | \`$nhanh\` | ✅ $kq |" >>"$TOM_TAT"
    git merge --abort >/dev/null 2>&1 || true
    continue
  fi

  # Đụng nhau: lấy danh sách file rồi hủy lượt gộp.
  files=$(git diff --name-only --diff-filter=U)
  git merge --abort >/dev/null 2>&1 || git reset -q --hard
  so_dung=$((so_dung+1))
  dem=$(grep -c . <<<"$files")
  dung_ds="$dung_ds #$n"
  echo "  ĐỤNG $dem file:"; sed 's/^/    /' <<<"$files"
  echo "| #$n | \`$nhanh\` | ❌ đụng $dem file: $(tr '\n' ' ' <<<"$files" | sed 's/ $//; s/ /, /g') |" >>"$TOM_TAT"

  ds_file=$(sed 's/^/- `/; s/$/`/' <<<"$files")
  body="$DAU
⚠️ **Nhánh \`$nhanh\` đụng \`$BASE\`** (kiểm ở $BASE $main_sha). Máy không tự gộp được, cần sửa tay ở $dem file:

$ds_file

Cách sửa (chạy trên nhánh này):
\`\`\`bash
git fetch origin $BASE
git merge origin/$BASE
# sửa các file trên (giữ phần của cả hai bên), rồi:
git add <file đã sửa>
git commit --no-edit
git push
\`\`\`
Đẩy xong, kiểm tra \"$TRANG_THAI\" sẽ xanh lại và bình luận này tự đổi. Thứ tự gộp PR: xem \`docs/gop-main.md\`."
  if [ "$co_nhan_dung" != 1 ]; then
    ghi gh pr edit "$n" --repo "$REPO" --add-label "$NHAN_DUNG" >/dev/null || true
  fi
  dat_binh_luan "$n" "$body"
  dat_trang_thai "$dau" failure "Đụng $BASE ở $dem file, cần gộp tay"
done < <(jq -c '.[]' <<<"$ds")

{
  echo
  echo "Gộp sạch: $so_sach · đã mới: $so_moi · đụng: $so_dung · bỏ qua: $so_bo"
} >>"$TOM_TAT"
echo "Gộp sạch: $so_sach, đã mới: $so_moi, đụng: $so_dung, bỏ qua: $so_bo"

if [ "$KHO" = 1 ] && [ "$so_dung" -gt 0 ]; then
  echo "::error::PR$dung_ds đụng $BASE, cần gộp tay (xem bình luận trên PR)."
  exit 1
fi
exit 0
