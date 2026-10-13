#!/usr/bin/env bash
export PATH="$HOME/.local/bin:$PATH"
echo "=== host resolv ==="; cat /etc/resolv.conf
echo "=== host /etc/hosts tail ==="; tail -3 /etc/hosts
echo "=== native chroot /etc/hosts ==="
pmbootstrap chroot -- cat /etc/hosts 2>/dev/null | tail -5
echo "=== chroot connectivity ==="
pmbootstrap chroot -- sh -c '
  wget -T 12 -q -O /dev/null http://mirror.postmarketos.org/postmarketos/ && echo PMOS_OK || echo PMOS_FAIL
  wget -T 12 -q -O /dev/null http://dl-cdn.alpinelinux.org/alpine/ && echo ALPINE_OK || echo ALPINE_FAIL
' 2>&1 | tail -8
