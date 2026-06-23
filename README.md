# Windows Endpoint Health Check Toolkit

A PowerShell toolkit for collecting endpoint evidence and applying selected guarded Windows repairs.

## Diagnostic script

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Windows_Endpoint_Health_Check_Toolkit.ps1
```

The diagnostic script creates CSV, JSON, HTML, log and ticket-summary evidence covering operating system, storage, networking, services, Defender, firewall, BitLocker, startup items, applications and recent events.

## Repair script

Preview the standard repair:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Windows_Endpoint_Repair_Toolkit.ps1 -Repair -DryRun
```

Run the standard repair:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Windows_Endpoint_Repair_Toolkit.ps1 -Repair
```

Target individual actions:

```powershell
.\Windows_Endpoint_Repair_Toolkit.ps1 -RestartService wuauserv,bits
.\Windows_Endpoint_Repair_Toolkit.ps1 -RunDism -RunSfc
.\Windows_Endpoint_Repair_Toolkit.ps1 -FlushDns
.\Windows_Endpoint_Repair_Toolkit.ps1 -ClearTemp
```

## What the repair does

- Restarts selected core Windows services.
- Flushes the DNS resolver cache.
- Runs DISM RestoreHealth and System File Checker.
- Optionally removes stale files older than seven days from the current user’s temporary directory.
- Captures before-and-after JSON verification data.
- Supports `-DryRun`, confirmation prompts, action logs and clear exit codes.

## Safety

Administrator rights are required for real repairs. The script does not modify firewall rules, BitLocker configuration, user accounts or installed applications. Temporary-file cleanup is explicit and limited to old items in the current user’s temp directory.

## Maintainer

IAmLegionVaal
