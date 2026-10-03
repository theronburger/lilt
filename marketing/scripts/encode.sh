#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
source_video="${1:?Usage: marketing/scripts/encode.sh path/to/lilt-demo.h264}"
output="$root/marketing/output"
mkdir -p "$output"
duration="$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$root/marketing/assets/soundtrack.wav")"
ffmpeg -hide_banner -loglevel warning -y -fflags +genpts -r 30 -i "$source_video" -i "$root/marketing/assets/soundtrack.wav" \
  -map 0:v:0 -map 1:a:0 -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -c:a aac -b:a 160k -ar 48000 -t "$duration" -movflags +faststart "$output/lilt-demo.mp4"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT
ffmpeg -hide_banner -loglevel warning -y -ss 17.25 -i "$output/lilt-demo.mp4" -frames:v 1 -update 1 "$temporary/poster.png"
cwebp -quiet -q 92 "$temporary/poster.png" -o "$output/lilt-demo-poster.webp"
ffmpeg -hide_banner -loglevel warning -y -ss 11.3 -t 7.7 -i "$output/lilt-demo.mp4" \
  -filter_complex '[0:v]fps=12,scale=800:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=96[p];[b][p]paletteuse=dither=bayer:bayer_scale=3' \
  -loop 0 "$output/lilt-demo.gif"
ffprobe -v error -show_entries format=duration,size -show_entries stream=codec_name,width,height,r_frame_rate -of json "$output/lilt-demo.mp4"
