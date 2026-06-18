# Troubleshooting Guide

## Script does not run

Use:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Windows_Endpoint_Health_Check_Toolkit.ps1
```

## Some checks return Info or Failed

This is normal when:

- PowerShell is not running as Administrator
- A feature is not available on that Windows edition
- The device uses a third-party security product
- The device is offline
- A service or module is missing

## Defender check fails

Possible reasons:

- Third-party antivirus is installed
- Defender cmdlets are unavailable
- PowerShell is not elevated
- Defender is managed by policy

## BitLocker check fails

Possible reasons:

- BitLocker is not available on the edition
- PowerShell is not elevated
- The device does not support BitLocker

## Event log output is large

Use a smaller lookback window:

```powershell
.\Windows_Endpoint_Health_Check_Toolkit.ps1 -EventHours 6
```

## Reports are not created

Check that the user has write permissions to the output folder.

Use a custom folder:

```powershell
.\Windows_Endpoint_Health_Check_Toolkit.ps1 -OutputPath C:\Temp\EndpointReports
```
