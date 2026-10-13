#!/usr/bin/env bash
# Install pmbootstrap (from git; it's no longer on PyPI) in WSL for building
# postmarketOS for samsung-on7xelte. Build only -- flashing happens on bare metal.
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq git python3 python3-venv >/dev/null 2>&1 || apt-get install -y git python3

USER_NAME="$(getent passwd 1000 | cut -d: -f1)"
[ -z "$USER_NAME" ] && { echo "NO_UID1000_USER"; exit 0; }
echo "pmbootstrap user: $USER_NAME"

sudo -u "$USER_NAME" bash -lc '
  set -e
  mkdir -p ~/.local/bin ~/.local/share
  if [ ! -d ~/.local/share/pmbootstrap ]; then
    git clone --depth=1 https://gitlab.postmarketos.org/postmarketOS/pmbootstrap.git ~/.local/share/pmbootstrap
  fi
  ln -sf ~/.local/share/pmbootstrap/pmbootstrap.py ~/.local/bin/pmbootstrap
  export PATH="$HOME/.local/bin:$PATH"
  grep -q ".local/bin" ~/.bashrc || echo "export PATH=\$HOME/.local/bin:\$PATH" >> ~/.bashrc
  echo "version:"; pmbootstrap --version
'
