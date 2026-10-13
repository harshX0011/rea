#!/usr/bin/env bash
# Build the postmarketOS rootfs + boot image for samsung-exynos7 (phosh).
cd "$HOME"
export PATH="$HOME/.local/bin:$PATH"
pmbootstrap config ui phosh
pmbootstrap shutdown 2>/dev/null || true
printf 'y\n' | pmbootstrap zap 2>/dev/null || true
echo "=== building (device=$(pmbootstrap config device) ui=$(pmbootstrap config ui)) ==="
# Non-interactive install; set a known first-login password (change later).
pmbootstrap install --password 147147 2>&1
echo "=== EXIT $? ==="
