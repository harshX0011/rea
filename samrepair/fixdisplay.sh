#!/bin/sh
# Auto-fix / diagnose a black phosh screen on postmarketOS (samsung-on7xelte).
# Run ON THE PHONE (over SSH): backlight on+max, force all wayland outputs on,
# print DRM + backlight + wlr-randr state. Paste the whole output back to Claude.
set -u
echo "===== 1. BACKLIGHT ====="
for b in /sys/class/backlight/*; do
  [ -e "$b" ] || continue
  max=$(cat "$b/max_brightness" 2>/dev/null)
  echo "$b  power=$(cat "$b/bl_power" 2>/dev/null) bright=$(cat "$b/brightness" 2>/dev/null)/$max"
  echo 0   | sudo tee "$b/bl_power"   >/dev/null 2>&1
  [ -n "$max" ] && echo "$max" | sudo tee "$b/brightness" >/dev/null 2>&1
  echo "   -> set power=0 bright=$max"
done

echo "===== 2. DRM CONNECTORS ====="
for c in /sys/class/drm/card*-*; do
  [ -e "$c" ] || continue
  echo "$(basename "$c"): status=$(cat "$c/status" 2>/dev/null) enabled=$(cat "$c/enabled" 2>/dev/null) dpms=$(cat "$c/dpms" 2>/dev/null)"
done

echo "===== 3. WAYLAND OUTPUTS (wlr-randr) ====="
sock=$(sudo find /run/user -maxdepth 2 -name 'wayland-*' ! -name '*.lock' 2>/dev/null | head -1)
if [ -z "$sock" ]; then
  echo "no wayland socket found (is phoc/greetd running?)"
else
  uid=$(echo "$sock" | cut -d/ -f4)
  wd=$(basename "$sock")
  owner=$(stat -c %U "$sock" 2>/dev/null)
  echo "socket=$sock uid=$uid display=$wd owner=$owner"
  R="sudo -u $owner env XDG_RUNTIME_DIR=/run/user/$uid WAYLAND_DISPLAY=$wd wlr-randr"
  echo "--- current ---"; $R 2>&1
  echo "--- forcing every output ON ---"
  for o in $($R 2>/dev/null | grep -oE '^[^ ]+'); do
    echo "  on: $o"; $R --output "$o" --on >/dev/null 2>&1
  done
  echo "--- after ---"; $R 2>&1
fi

echo "===== 4. SERVICES ====="
systemctl --failed --no-legend 2>/dev/null | head
echo "greetd: $(systemctl is-active greetd 2>/dev/null)"
echo "===== DONE - ab phone ki screen dekho (aur ungli se tap karo) ====="
