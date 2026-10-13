#!/usr/bin/env bash
export PATH="$HOME/.local/bin:$PATH"
echo "=== flasher subcommands ==="
pmbootstrap flasher --help 2>&1 | grep -iE 'flash_|lk2nd|boot|rootfs|list|sideload' | head -30
echo "=== export ==="
pmbootstrap export 2>&1 | tail -25
echo "=== exported files (resolved) ==="
for d in /tmp/postmarketOS-export ~/.local/var/pmbootstrap/*export* /tmp/pmbootstrap-export; do
  [ -d "$d" ] && { echo "DIR: $d"; ls -lL "$d" 2>/dev/null; }
done
