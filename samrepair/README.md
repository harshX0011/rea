# samrepair

Fully-local, open-source Samsung **system repair** over USB — reflash stock firmware
in download mode, the same job Odin / ReiBoot do, with **no license, no server, no
account**. Built on open-source [Heimdall](https://gitlab.com/BenjaminDobell/Heimdall)
(the open Odin) + adb. Firmware is yours (the stock `BL/AP/CP/CSC` `.tar.md5` set).

> **Not a crack.** This is an independent tool. It does not contain, unlock, or
> bypass any other product. You supply your own stock firmware.

## Buttonless by design

Your phone's buttons don't need to work:

- **Enter download mode:** `adb reboot download` from the PC — no key combo. Needs the
  phone to still boot to Android (or recovery) with **USB debugging on**.
- **Auto-boot after flashing:** Heimdall reboots the phone into the system itself
  (like Odin's "Auto Reboot"). No button press to finish.
- **Dead phone + dead buttons + no adb?** No PC software can force download mode then.
  Use a **300K USB jig cable** — plug it in and the phone boots straight to download
  mode. (Hardware, a few dollars. After that, flashing is all USB from the PC.)

## Why WSL on Windows

No maintained open-source USB flasher ships a working Windows binary (Thor's Windows
USB is unimplemented; Heimdall no longer ships Windows binaries). So on Windows we run
Heimdall inside **WSL (Linux)** and forward the phone's USB in with **usbipd-win**.
This is the reliable, fully-FOSS path and needs no Zadig driver juggling.

## One-time setup (Windows, admin PowerShell)

```powershell
wsl --install -d Ubuntu          # enable WSL + Ubuntu; REBOOT when it asks
choco install usbipd -y          # USB passthrough into WSL
```

After the reboot, inside Ubuntu (WSL):

```bash
sudo apt update
sudo apt install -y heimdall-flash android-tools-adb python3 python3-lz4
# copy this folder in, e.g.:  cp -r /mnt/d/reverse/samrepair ~/samrepair
```

## Repair flow

Phone booted to Android, USB debugging on, plugged into the PC.

```powershell
# 1. Windows: confirm the phone is seen
.\windows-usb.ps1 detect

# 2. Windows: enter download mode over USB (no buttons)
.\windows-usb.ps1 download

# 3. Windows (ADMIN): forward the download-mode USB into WSL
.\windows-usb.ps1 attach
```

```bash
# 4. WSL: read the partition table, then flash + auto-reboot
python3 samrepair.py pit
python3 samrepair.py flash /mnt/d/firmware/<model>   # dry run: prints the plan
python3 samrepair.py flash /mnt/d/firmware/<model> --go
```

`flash` extracts the `.tar.md5` set, decompresses `.lz4` images, matches each image to
its partition via the PIT, and flashes. It **skips the bootloader** unless you pass
`--allow-bootloader`, and auto-reboots unless you pass `--no-reboot`.

## Getting stock firmware

Download the exact firmware for your model/CSC from a stock-firmware source (e.g.
samfw.com, sammobile) — the `BL_ AP_ CP_ CSC_` `.tar.md5` set. Put them in one folder
and point `flash` at it. Flash `HOME_CSC` (not `CSC`) to keep user data; `CSC` wipes.

## Commands

| Where | Command | Does |
|---|---|---|
| Win | `windows-usb.ps1 detect` | show adb device + USB list |
| Win | `windows-usb.ps1 download` | `adb reboot download` (buttonless) |
| Win (admin) | `windows-usb.ps1 attach` / `detach` | usbipd passthrough to WSL |
| WSL | `samrepair.py detect` | device / download-mode status |
| WSL | `samrepair.py pit` | print partition table |
| WSL | `samrepair.py flash DIR [--go] [--no-reboot] [--allow-bootloader]` | the repair |
| any | `samrepair.py selftest` | internal checks, no device |

## Safety

- Dry run by default; real flash needs `--go` and typing `YES`.
- Bootloader/PIT skipped unless explicitly allowed — wrong bootloader can hard-brick.
- Flash only firmware that matches your exact model. You are responsible for the files.

## License

MIT — see [LICENSE](LICENSE). Uses Heimdall (MIT), adb (Apache-2.0), usbipd-win
(GPL-3.0/GPL-2.0), python-lz4 (BSD) — each under its own license.
