#!/usr/bin/env bash
# Preset the config to the active generic Exynos7 port, then run init taking
# those values as defaults (blank answers).
cd "$HOME"
export PATH="$HOME/.local/bin:$PATH"
pmbootstrap config device samsung-exynos7
pmbootstrap config ui console
echo "=== config before init ==="; pmbootstrap config device; pmbootstrap config ui
echo "=== init ==="
printf '\n%.0s' {1..40} | pmbootstrap init 2>&1 | tail -25
echo "=== config after init ==="; pmbootstrap config device; pmbootstrap config ui; pmbootstrap config kernel
