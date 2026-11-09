#!/usr/bin/env bash
# vmcon.sh - drive a headless VirtualBox VM console: send keys/text, then save a screenshot.
#   vmcon.sh VM shot.png [ENTER|SPACE|TAB|LEFT|RIGHT|UP|DOWN|ESC|BKSP|WAIT:n|text:...]...
vb="/c/Program Files/Oracle/VirtualBox/VBoxManage.exe"
vm=$1; shot=$2; shift 2
for k in "$@"; do
  case "$k" in
    ENTER) "$vb" controlvm "$vm" keyboardputscancode 1c 9c ;;
    SPACE) "$vb" controlvm "$vm" keyboardputscancode 39 b9 ;;
    TAB)   "$vb" controlvm "$vm" keyboardputscancode 0f 8f ;;
    ESC)   "$vb" controlvm "$vm" keyboardputscancode 01 81 ;;
    BKSP)  "$vb" controlvm "$vm" keyboardputscancode 0e 8e ;;
    LEFT)  "$vb" controlvm "$vm" keyboardputscancode e0 4b e0 cb ;;
    RIGHT) "$vb" controlvm "$vm" keyboardputscancode e0 4d e0 cd ;;
    UP)    "$vb" controlvm "$vm" keyboardputscancode e0 48 e0 c8 ;;
    DOWN)  "$vb" controlvm "$vm" keyboardputscancode e0 50 e0 d0 ;;
    WAIT:*) sleep "${k#WAIT:}" ;;
    text:*) "$vb" controlvm "$vm" keyboardputstring "${k#text:}" ;;
    *) echo "unknown key $k" >&2 ;;
  esac
  sleep 0.6
done
[ -n "$shot" ] && "$vb" controlvm "$vm" screenshotpng "$shot"
