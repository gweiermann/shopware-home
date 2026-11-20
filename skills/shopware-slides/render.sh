#!/bin/sh
# render.sh <pptx> <outdir>: preview PNGs via Keynote (PowerPoint's AppleScript PNG export writes nothing from here)
in="$1"; out="$2"; rm -rf "$out"; mkdir -p "$out"
osascript <<OSA
with timeout of 900 seconds
tell application "Keynote"
  set d to open POSIX file "$in"
  delay 2
  export d to POSIX file "$out" as slide images with properties {image format:PNG, skipped slides:false}
  close d saving no
end tell
end timeout
OSA
ls "$out" | wc -l
