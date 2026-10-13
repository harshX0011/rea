#!/usr/bin/env bash
# =====================================================================
# flash-pmos.sh  (v2, NTFS-free) - Install postmarketOS (Nura) on
#   Samsung SM-G610F (samsung-on7xelte / Exynos 7870) from a Linux live USB.
#
# RUN INSIDE LUBUNTU (live USB), after downloading this file:
#     bash ~/Downloads/*flash-pmos.sh
#
# Needs: internet (wifi) in Lubuntu. Does NOT touch the Windows disk.
# Work area goes in your home (RAM overlay) - the laptop has ~23 GB RAM.
#
# GUIDED: nothing is written to the phone until you type YES.
# RESULT: phone runs postmarketOS/Phosh. Works: wifi/bt/touch/graphics.
#   Broken on this model: calls, SMS, mobile data, audio, camera, GPS.
#   Android is erased. Experimental ("testing") software.
# =====================================================================
set -u
say(){ printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
err(){ printf '\n\033[1;31mERROR: %s\033[0m\n' "$*"; }
ask(){ read -r -p "$1 " _r; [ "$_r" = "YES" ]; }

DEVICE="samsung-exynos7"; UI="phosh"; PASSWORD="147147"

if grep -qi microsoft /proc/version 2>/dev/null; then
  err "This is WSL, not the live USB. Boot Lubuntu and run it there."; exit 1; fi

say "1/5  Installing tools (needs internet)..."
sudo apt-get update -y || { err "apt update failed - connect wifi and re-run."; exit 1; }
sudo apt-get install -y git python3 python3-venv kpartx multipath-tools \
  android-tools-adb android-tools-fastboot heimdall-flash e2fsprogs || {
    err "apt install failed - check wifi, re-run."; exit 1; }

say "2/5  Installing pmbootstrap..."
export PATH="$HOME/.local/bin:$PATH"
if ! command -v pmbootstrap >/dev/null; then
  rm -rf "$HOME/pmbootstrap"
  git clone --depth=1 https://gitlab.postmarketos.org/postmarketOS/pmbootstrap.git "$HOME/pmbootstrap" || {
    err "git clone failed - check wifi."; exit 1; }
  mkdir -p "$HOME/.local/bin"; ln -sf "$HOME/pmbootstrap/pmbootstrap.py" "$HOME/.local/bin/pmbootstrap"
fi
pmbootstrap --version || { err "pmbootstrap not working"; exit 1; }

say "3/5  Configuring + initializing (downloads base, a few min)..."
rm -f "$HOME/.config/pmbootstrap"*.cfg
pmbootstrap config device "$DEVICE"
pmbootstrap config ui "$UI"
# All prompts take the pre-set defaults (just feed blank lines):
printf '\n%.0s' {1..40} | pmbootstrap init || { err "init failed - run: pmbootstrap log"; exit 1; }

say "4/5  Building postmarketOS for $DEVICE ($UI). ~30-45 min. Lots of text is normal."
pmbootstrap install --password "$PASSWORD" || { err "build failed - run: pmbootstrap log (read the end)"; exit 1; }

say "5/5  The phone. Plug it in via USB now."
if adb get-state 2>/dev/null | grep -q device; then
  say "Phone is in Android -> rebooting into download mode over USB (no buttons)..."
  adb reboot download
elif heimdall detect >/dev/null 2>&1; then
  say "Phone already in download mode."
else
  cat <<EOF
Phone not detected yet.
 - If it boots Android, it will appear and I'll retry.
 - Buttons dead + phone off/stuck: use a 300K USB jig cable, or charge it,
   let it boot Android, then re-run this script.
EOF
fi

say "Waiting for download mode (Ctrl-C to abort)..."
until heimdall detect >/dev/null 2>&1; do sleep 3; done
say "Download mode detected."

printf '\n\033[1;33m============ READY TO FLASH ============\033[0m\n'
printf 'This ERASES Android and installs postmarketOS on the phone.\n'
printf 'Device: %s   UI: %s\n' "$DEVICE" "$UI"
ask "Type YES to flash (anything else aborts):" || { err "Aborted. Nothing flashed."; exit 1; }

say "Flashing rootfs..."
pmbootstrap flasher flash_rootfs || { err "flash_rootfs failed. Phone is NOT bricked (still in download mode). Save the error and ask for help."; exit 1; }
say "Flashing kernel..."
pmbootstrap flasher flash_kernel || { err "flash_kernel failed. Re-enter download mode, run: pmbootstrap flasher flash_kernel"; exit 1; }

say "DONE! Phone should boot postmarketOS (first boot slow, several min)."
say "Login: user 'user', password '$PASSWORD'. Change it later with: passwd"
