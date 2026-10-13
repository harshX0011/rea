#!/usr/bin/env python3
"""samrepair - fully-local, open-source Samsung system repair over USB.

Repair == reflash stock firmware in download mode, the same thing Odin/ReiBoot do,
but with no license, no server, no account. Built on Heimdall (open-source Odin)
and adb. Firmware comes from you (the stock .tar.md5 set: BL/AP/CP/CSC).

Buttonless by design: if the phone still boots to Android (or recovery) with USB
debugging on, `download` puts it in download mode over USB with no key combo, and
flashing auto-reboots it back into the system. If the phone is dead AND adb can't
reach it AND the buttons are broken, no PC software can force download mode -- you
need a 300K USB jig cable (plug it in, it boots straight to download mode). See
README.
"""
from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
from dataclasses import dataclass

BUNDLED_ADB = r"D:\reverse\android-system-repair\Android System Repair\adb\adb.exe"
# Images Heimdall must never touch without an explicit, separate decision.
DANGEROUS = {"PIT", "BOOTLOADER", "BOTA0", "BOTA1"}


def which(name: str, override: str | None, *fallbacks: str) -> str | None:
    if override:
        return override if os.path.isfile(override) else None
    found = shutil.which(name)
    if found:
        return found
    return next((p for p in fallbacks if os.path.isfile(p)), None)


def run(cmd: list[str], capture: bool = False) -> subprocess.CompletedProcess:
    print(f"  $ {' '.join(cmd)}")
    return subprocess.run(cmd, text=True, capture_output=capture)


# ---- PIT: maps partition names <-> the firmware filenames that flash to them ----
@dataclass
class PitEntry:
    partition: str
    filename: str


def parse_pit(text: str) -> list[PitEntry]:
    """Parse `heimdall print-pit` text into (partition name, flash filename) pairs."""
    entries, name = [], None
    for line in text.splitlines():
        m = re.search(r"Partition Name:\s*(\S+)", line)
        if m:
            name = m.group(1)
            continue
        m = re.search(r"Flash Filename:\s*(\S+)", line)
        if m and name is not None:
            if m.group(1):  # blank filename = not flashable
                entries.append(PitEntry(name, m.group(1)))
            name = None
    return entries


def heimdall_pit_text(heimdall: str) -> str:
    cp = run([heimdall, "print-pit", "--no-reboot"], capture=True)
    if cp.returncode != 0:
        sys.exit(f"heimdall print-pit failed:\n{cp.stderr or cp.stdout}")
    return cp.stdout


# ---- firmware: unpack the stock .tar.md5 set into raw images ----
def extract_firmware(src: str, workdir: str) -> dict[str, str]:
    """Extract every image from the firmware tar(.md5) files in `src`.

    Returns {original_entry_name: path_to_raw_image}. .lz4 entries are
    decompressed; .tar.md5 is a plain tar with an md5 line appended, which
    tarfile reads fine.
    """
    tars = []
    if os.path.isfile(src):
        tars = [src]
    else:
        for f in sorted(os.listdir(src)):
            if f.lower().endswith((".tar.md5", ".tar")) and (
                f.upper().startswith(("BL_", "AP_", "CP_", "CSC_", "HOME_CSC_", "USERDATA_"))
                or f.lower().endswith(".tar")
            ):
                tars.append(os.path.join(src, f))
    if not tars:
        sys.exit(f"No firmware .tar/.tar.md5 files found in {src}")

    images: dict[str, str] = {}
    for tar in tars:
        print(f"unpacking {os.path.basename(tar)}")
        with tarfile.open(tar, "r:*") as tf:
            for member in tf.getmembers():
                if not member.isfile():
                    continue
                raw = tf.extractfile(member)
                if raw is None:
                    continue
                entry = os.path.basename(member.name)
                if entry.endswith(".lz4"):
                    out_name, out_path = entry[:-4], os.path.join(workdir, entry[:-4])
                    _lz4_to_file(raw, out_path)
                else:
                    out_name, out_path = entry, os.path.join(workdir, entry)
                    with open(out_path, "wb") as w:
                        shutil.copyfileobj(raw, w)
                images[out_name] = out_path
    return images


def _lz4_to_file(stream, out_path: str) -> None:
    try:
        import lz4.frame
    except ImportError:
        sys.exit("Need python 'lz4' for .lz4 images. Install: pip install lz4")
    with lz4.frame.open(stream, "rb") as src, open(out_path, "wb") as dst:
        shutil.copyfileobj(src, dst)


def build_flash_map(images: dict[str, str], pit: list[PitEntry]) -> list[tuple[str, str]]:
    """Match each extracted image to its PIT partition by flash filename."""
    by_file = {e.filename: e.partition for e in pit}
    # PIT filenames may or may not carry the .lz4 suffix; try both.
    plan = []
    for entry, path in images.items():
        part = by_file.get(entry) or by_file.get(entry + ".lz4")
        if part:
            plan.append((part, path))
        else:
            print(f"  skip (no PIT match): {entry}")
    return plan


# ---- commands ----
def cmd_detect(a) -> None:
    adb = which("adb", a.adb, BUNDLED_ADB)
    heimdall = which("heimdall", a.heimdall)
    if adb:
        print("ADB devices:")
        cp = run([adb, "devices", "-l"], capture=True)
        print(cp.stdout.strip() or "  (none)")
        cp = run([adb, "shell", "getprop", "ro.product.model"], capture=True)
        if cp.returncode == 0 and cp.stdout.strip():
            print(f"  model: {cp.stdout.strip()}")
    else:
        print("adb: not found")
    print("Download mode (Heimdall):")
    if heimdall:
        run([heimdall, "detect"])
    else:
        print("  heimdall: not found -- install it to flash (see README)")


def cmd_download(a) -> None:
    adb = which("adb", a.adb, BUNDLED_ADB) or sys.exit("adb not found")
    print("Rebooting phone into download mode over USB (no buttons)...")
    cp = run([adb, "reboot", "download"])
    if cp.returncode != 0:
        print(
            "\nadb could not reach the phone. If the buttons are dead and the phone\n"
            "won't boot, use a 300K USB jig cable to force download mode (see README)."
        )
        sys.exit(1)
    print("Done. Phone should now show the download/Odin screen.")


def cmd_pit(a) -> None:
    heimdall = which("heimdall", a.heimdall) or sys.exit("heimdall not found")
    print(heimdall_pit_text(heimdall))


def cmd_flash(a) -> None:
    heimdall = which("heimdall", a.heimdall) or sys.exit("heimdall not found")
    pit = parse_pit(heimdall_pit_text(heimdall))
    if not pit:
        sys.exit("Could not read PIT -- is the phone in download mode? Run `download` first.")

    workdir = tempfile.mkdtemp(prefix="samrepair_")
    try:
        images = extract_firmware(a.firmware, workdir)
        plan = build_flash_map(images, pit)
        plan = [(p, f) for (p, f) in plan if p.upper() not in DANGEROUS or a.allow_bootloader]
        if not plan:
            sys.exit("Nothing to flash.")

        cmd = [heimdall, "flash"]
        for part, path in plan:
            cmd += [f"--{part}", path]
        if a.no_reboot:
            cmd.append("--no-reboot")  # otherwise Heimdall auto-reboots into system

        print("\nFlash plan:")
        for part, path in plan:
            print(f"  {part:16} <- {os.path.basename(path)}")
        print(f"  auto-reboot after flash: {'NO' if a.no_reboot else 'YES'}")

        if not a.go:
            print("\nDry run. Add --go to actually flash.")
            print("  " + " ".join(cmd))
            return
        if input("\nType YES to flash: ").strip() != "YES":
            sys.exit("Aborted.")
        sys.exit(run(cmd).returncode)
    finally:
        shutil.rmtree(workdir, ignore_errors=True)


def cmd_selftest(_a) -> None:
    sample = """
--- Entry #1 ---
Partition Name: BOOT
Flash Filename: boot.img.lz4
--- Entry #2 ---
Partition Name: RECOVERY
Flash Filename: recovery.img.lz4
--- Entry #3 ---
Partition Name: PIT
Flash Filename:
"""
    pit = parse_pit(sample)
    assert [(e.partition, e.filename) for e in pit] == [
        ("BOOT", "boot.img.lz4"),
        ("RECOVERY", "recovery.img.lz4"),
    ], pit  # blank filename dropped
    plan = build_flash_map({"boot.img": "/x/boot.img", "stray.img": "/x/stray.img"}, pit)
    assert plan == [("BOOT", "/x/boot.img")], plan  # matched via +.lz4; stray skipped
    try:
        import lz4.frame

        data = b"samrepair" * 5000
        assert lz4.frame.decompress(lz4.frame.compress(data)) == data
        print("selftest: OK (incl. lz4)")
    except ImportError:
        print("selftest: OK (lz4 not installed, roundtrip skipped)")


def main() -> None:
    p = argparse.ArgumentParser(prog="samrepair", description=__doc__.splitlines()[0])
    p.add_argument("--adb", help="path to adb.exe")
    p.add_argument("--heimdall", help="path to heimdall")
    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser("detect", help="show device / download-mode status")
    sub.add_parser("download", help="reboot phone into download mode over USB (no buttons)")
    sub.add_parser("pit", help="print the partition table (PIT)")
    sub.add_parser("selftest", help="run internal checks, no device needed")

    f = sub.add_parser("flash", help="flash stock firmware (the repair)")
    f.add_argument("firmware", help="folder with BL/AP/CP/CSC .tar.md5 (or a single tar)")
    f.add_argument("--go", action="store_true", help="actually flash (default is dry run)")
    f.add_argument("--no-reboot", action="store_true", help="do not auto-reboot after flash")
    f.add_argument("--allow-bootloader", action="store_true", help="also flash BL/bootloader (risky)")

    a = p.parse_args()
    {"detect": cmd_detect, "download": cmd_download, "pit": cmd_pit,
     "flash": cmd_flash, "selftest": cmd_selftest}[a.cmd](a)


if __name__ == "__main__":
    main()
