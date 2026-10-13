# rea

Work from a reverse-engineering + phone-Linux session.

## Contents
- **rea-main/** — source of the `rea-agents` reverse-engineering CLI/MCP server
  (upstream: https://github.com/morluto/rea, MIT). `node_modules/`, `dist/` and
  native binaries are gitignored; run `npm ci && npm run build:cached` to rebuild.
- **samrepair/** — original tools built this session:
  - `samrepair.py` — local, open-source Samsung firmware reflash over USB
    (Heimdall + adb), buttonless download-mode + auto-reboot.
  - `flash-pmos.sh` — install postmarketOS (Nura) on Samsung SM-G610F
    (samsung-exynos7 / Exynos 7870) from a Linux live USB, via pmbootstrap.
  - `FLASH-GUIDE.txt` — step-by-step for the above.
  - `pmos-*.sh`, `windows-usb.ps1`, `scripts/DecompileByName.java` — helpers.
- **extract_anydesk_payload.py** — static LZMA payload extractor (self-RE demo).

## Not in git (by design)
Proprietary extracted binaries (AnyDesk, Tenorshare), the Ubuntu/Lubuntu ISO,
third-party tool binaries (Thor, usbipd, Rufus, Heimdall) and `node_modules`.
Fetch those from their official sources.

## Phone project status
postmarketOS image for SM-G610F builds successfully. Flashing is done on a
bare-metal Linux live USB (USB passthrough is unreliable under WSL), guided by
`samrepair/flash-pmos.sh`. On this model wifi/bluetooth/touch/graphics work;
calls/SMS/mobile-data/audio/camera do not.
