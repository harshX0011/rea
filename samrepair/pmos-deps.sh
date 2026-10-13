#!/usr/bin/env bash
# Host packages pmbootstrap needs to build/flash on a Debian/Ubuntu host.
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y kpartx multipath-tools qemu-user-binfmt binfmt-support \
  android-tools-adb android-tools-fastboot e2fsprogs dosfstools git
echo "installed. kpartx: $(command -v kpartx)  qemu-aarch64: $(command -v qemu-aarch64-static)"
