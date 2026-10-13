<#
  windows-usb.ps1 - Windows side of samrepair (buttonless entry + USB passthrough to WSL).

  The phone is flashed by Heimdall running inside WSL. These helpers do the parts
  that must happen on Windows: put the phone into download mode over USB with no
  buttons, then forward that USB device into WSL with usbipd.

  Usage (run in PowerShell; attach/detach need an *admin* PowerShell):
    .\windows-usb.ps1 detect       # show adb device + USB list
    .\windows-usb.ps1 download     # adb reboot download  (no buttons)
    .\windows-usb.ps1 attach       # bind+attach the Samsung USB to WSL   (admin)
    .\windows-usb.ps1 detach       # give the USB back to Windows         (admin)

  Then flash from WSL:
    wsl python3 ./samrepair.py pit
    wsl python3 ./samrepair.py flash <firmware-dir> --go
#>
param([Parameter(Mandatory)][ValidateSet('detect','download','attach','detach')]$action)

$ErrorActionPreference = 'Stop'
$adb = @(
  'D:\reverse\android-system-repair\Android System Repair\adb\adb.exe',
  (Get-Command adb -ErrorAction SilentlyContinue).Source
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

function Get-SamsungBusId {
  # Samsung USB vendor id is 04e8 (Android, download mode, Gadget Serial).
  $line = (usbipd list) -split "`n" | Where-Object { $_ -match '04e8:' } | Select-Object -First 1
  if (-not $line) { return $null }
  ($line.Trim() -split '\s+')[0]
}

switch ($action) {
  'detect' {
    if ($adb) { Write-Host "ADB:"; & $adb devices -l } else { Write-Host "adb not found" }
    Write-Host "`nUSB devices (look for 04e8 = Samsung):"
    if (Get-Command usbipd -ErrorAction SilentlyContinue) { usbipd list } else { Write-Host "usbipd not installed" }
  }
  'download' {
    if (-not $adb) { throw "adb not found" }
    Write-Host "Rebooting into download mode over USB (no buttons)..."
    & $adb reboot download
    Write-Host "If the phone is unreachable (dead + broken buttons), use a 300K USB jig cable."
  }
  'attach' {
    $id = Get-SamsungBusId
    if (-not $id) { throw "No Samsung (04e8) USB device found. Is it in download mode? Run 'download' first." }
    Write-Host "Attaching bus $id to WSL..."
    usbipd bind --busid $id
    usbipd attach --wsl --busid $id
    Write-Host "Attached. Now flash from WSL."
  }
  'detach' {
    $id = Get-SamsungBusId
    if ($id) { usbipd detach --busid $id; Write-Host "Detached $id." } else { Write-Host "Nothing to detach." }
  }
}
