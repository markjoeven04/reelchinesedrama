#!/bin/sh
# usage: tools/shot.sh <name>  -> screenshots/<name>.png (downscaled to 540px wide)
D="$(dirname "$0")/../screenshots"; mkdir -p "$D"
~/Library/Android/sdk/platform-tools/adb exec-out screencap -p > "$D/$1.png" && sips -Z 1000 "$D/$1.png" >/dev/null && echo "$D/$1.png"
