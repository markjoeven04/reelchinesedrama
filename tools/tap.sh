#!/bin/sh
# usage: tools/tap.sh "<accessibility label prefix>" [index]  - taps the Nth (default 1st) element whose content-desc starts with the label
A=~/Library/Android/sdk/platform-tools/adb
$A shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
B=$($A shell cat /sdcard/ui.xml | tr '>' '\n' | grep -F "content-desc=\"$1" | sed -n "${2:-1}p" | grep -oE 'bounds="\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]"' | grep -oE '[0-9]+' | tr '\n' ' ')
[ -z "$B" ] && { echo "not found: $1"; exit 1; }
set -- $B; $A shell input tap $(( ($1+$3)/2 )) $(( ($2+$4)/2 ))
