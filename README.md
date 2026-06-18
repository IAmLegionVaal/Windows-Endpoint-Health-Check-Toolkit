# Windows Endpoint Health Check Toolkit

A menu-driven PowerShell toolkit for L1/L2 IT support endpoint checks.

This project is designed for practical Windows troubleshooting and ticket escalation. It collects useful endpoint information and exports clean reports that can be attached to helpdesk tickets.

## Features

- Quick endpoint health summary
- Full endpoint health report
- System information check
- Disk and storage health check
- Network health check
- Security baseline check
- Critical Windows services check
- Pending reboot detection
- Event log analyzer
- Startup item and installed apps inventory
- HTML, CSV, and JSON report exports
- Timestamped logging

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1 or later
- Administrator rights recommended for complete results

## How to run

Open PowerShell as Administrator and run:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Windows_Endpoint_Health_Check_Toolkit.ps1
```

Run a full report directly without using the menu:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Windows_Endpoint_Health_Check_Toolkit.ps1 -RunAll
```

Send reports to a custom folder:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Windows_Endpoint_Health_Check_Toolkit.ps1 -RunAll -OutputPath C:\Temp\EndpointReports
```

## Output

By default, reports are saved on the desktop in:

```text
Endpoint_Health_Check_Reports
```

The toolkit creates:

```text
*.html
*.csv
*.json
*.log
```

## Menu options

| Option | Description |
|---|---|
| 1 | Quick endpoint health summary |
| 2 | Full endpoint health report |
| 3 | System information check |
| 4 | Disk and storage check |
| 5 | Network health check |
| 6 | Security baseline check |
| 7 | Critical services check |
| 8 | Pending reboot check |
| 9 | Event log analyzer |
| 10 | Startup and installed apps inventory |
| 11 | Open report folder |

## Safety

This script is diagnostic-focused. It does not delete data, reset services, modify registry settings, or make destructive system changes.

## Good use cases

- First-response helpdesk triage
- Before/after troubleshooting evidence
- Ticket escalation reports
- Endpoint health audits
- New device baseline checks

## Suggested repo topics

```text
powershell
windows
it-support
helpdesk
endpoint-management
troubleshooting
sysadmin
windows-11
```
