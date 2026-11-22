#!/usr/bin/env bash
# Chuyển giọng ElevenLabs (.mp3 tải về) thành file dùng trong game: cắt khoảng lặng đầu/cuối,
# cân độ to -16 LUFS (đỉnh -1,5 dBTP), mono 22 050 Hz, ogg vorbis q4.
# Chạy: tools/giong_that/chuyen_ogg.sh thu_muc_mp3   (ra assets/audio/giong/<tên>.ogg)
# Câu mới thì thêm dòng vào GiongThat.CAU (scripts/giong_that.gd) và bảng trong assets/audio/NGUON.md.
set -euo pipefail
src="${1:?thu muc chua .mp3}"
out="$(dirname "$0")/../../assets/audio/giong"
mkdir -p "$out"
for f in "$src"/*.mp3; do
  id="$(basename "$f" .mp3)"
  ffmpeg -loglevel error -y -i "$f" \
    -af "silenceremove=start_periods=1:start_threshold=-50dB,areverse,silenceremove=start_periods=1:start_threshold=-50dB,areverse,loudnorm=I=-16:TP=-1.5:LRA=11,apad=pad_dur=0.05" \
    -ar 22050 -ac 1 -c:a libvorbis -q:a 4 "$out/$id.ogg"
  echo "$out/$id.ogg"
done
