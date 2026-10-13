#!/usr/bin/env bash
# Probe pmbootstrap init prompt order by feeding blank answers from HOME (ext4).
cd "$HOME"
export PATH="$HOME/.local/bin:$PATH"
# 30 blank lines -> takes defaults; stops/loops at first prompt without a default.
printf '\n%.0s' {1..30} | timeout 180 pmbootstrap init 2>&1 | tail -60
