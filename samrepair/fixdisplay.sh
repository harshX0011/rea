#!/bin/sh
# fixdisplay.sh
# postmarketOS / Nura display bring-up + diagnostics for Samsung Exynos 7
# devices (samsung-exynos7, e.g. J7 Prime / on7xelte).
#
# Purpose: when the phone has booted pmOS (SSH works) but the panel stays
# black, this turns the backlight on at full brightness, re-enables every
# Wayland output, and prints the DRM / backlight / compositor state so the
# remaining cause (if any) is obvious.
#
# Run as root on the phone:   sudo sh /tmp/fixdisplay.sh
# (Writes to /sys/class/backlight and switching to the compositor user both
#  need root, so running without sudo will only print, not fix.)

echo "===================== fixdisplay.sh ====================="
if [ "$(id -u)" != "0" ]; then
	echo "WARNING: not running as root - privileged writes will fail."
	echo "         re-run as: sudo sh $0"
fi

echo
echo "===== 1. BACKLIGHT ====="
found_bl=0
for bl in /sys/class/backlight/*; do
	[ -e "$bl" ] || continue
	found_bl=1
	max=$(cat "$bl/max_brightness" 2>/dev/null)
	echo "[$bl]"
	echo "  before: brightness=$(cat "$bl/brightness" 2>/dev/null) bl_power=$(cat "$bl/bl_power" 2>/dev/null) max=$max"
	# bl_power 0 = FB_BLANK_UNBLANK (on); set brightness to max
	[ -w "$bl/bl_power" ] && echo 0 > "$bl/bl_power" 2>/dev/null
	[ -n "$max" ] && [ -w "$bl/brightness" ] && echo "$max" > "$bl/brightness" 2>/dev/null
	echo "  after:  brightness=$(cat "$bl/brightness" 2>/dev/null) bl_power=$(cat "$bl/bl_power" 2>/dev/null)"
done
[ "$found_bl" = 0 ] && echo "  (no backlight device found)"

echo
echo "===== 2. DRM OUTPUTS (kernel view) ====="
ls -la /dev/dri/ 2>/dev/null
for s in /sys/class/drm/*/status; do
	[ -e "$s" ] || continue
	d=$(dirname "$s")
	echo "  $(basename "$d"): status=$(cat "$s" 2>/dev/null) enabled=$(cat "$d/enabled" 2>/dev/null) dpms=$(cat "$d/dpms" 2>/dev/null)"
done

echo
echo "===== 3. WAYLAND / COMPOSITOR ====="
PID=$(pgrep -x phoc | head -1)
[ -z "$PID" ] && PID=$(pgrep -x phrog | head -1)
if [ -n "$PID" ]; then
	RT=$(tr '\0' '\n' < "/proc/$PID/environ" 2>/dev/null | grep -m1 '^XDG_RUNTIME_DIR=' | cut -d= -f2)
	WL=$(tr '\0' '\n' < "/proc/$PID/environ" 2>/dev/null | grep -m1 '^WAYLAND_DISPLAY=' | cut -d= -f2)
	SU=$(stat -c %U "/proc/$PID" 2>/dev/null)
	echo "  compositor pid=$PID user=$SU XDG_RUNTIME_DIR=$RT WAYLAND_DISPLAY=$WL"
	if command -v wlr-randr >/dev/null 2>&1; then
		echo "  -- wlr-randr (current state):"
		su "$SU" -s /bin/sh -c "XDG_RUNTIME_DIR='$RT' WAYLAND_DISPLAY='$WL' wlr-randr" 2>&1 | sed 's/^/    /'
		for out in $(su "$SU" -s /bin/sh -c "XDG_RUNTIME_DIR='$RT' WAYLAND_DISPLAY='$WL' wlr-randr" 2>/dev/null | grep -E '^[A-Za-z]' | awk '{print $1}'); do
			echo "  -- turning output ON: $out"
			su "$SU" -s /bin/sh -c "XDG_RUNTIME_DIR='$RT' WAYLAND_DISPLAY='$WL' wlr-randr --output '$out' --on" 2>&1 | sed 's/^/    /'
		done
	else
		echo "  wlr-randr NOT installed."
		echo "  To install (phone needs internet first): sudo apk add wlr-randr"
	fi
else
	echo "  phoc/phrog NOT running - the graphical session is not up."
fi

echo
echo "===================== DONE ====================="
echo "Ab phone ki screen dekho aur ungli se tap/swipe karo (idle pe blank hoti hai)."
