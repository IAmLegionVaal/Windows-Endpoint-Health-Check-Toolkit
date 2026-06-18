# Windows Endpoint Health Check Toolkit

A read-only PowerShell toolkit for IT Support, L1/L2 technicians, and escalation teams.

This project helps a support technician quickly collect endpoint evidence before escalating a ticket. It standardizes checks, creates ticket-ready reports, and reduces manual troubleshooting time.

## What it checks

- System information
- Windows version and build
- Uptime
- Disk space
- Network adapter status
- IP and DNS configuration
- Microsoft 365 connectivity basics
- Pending reboot indicators
- Key Windows services
- Microsoft Defender status
- Firewall profile status
- BitLocker context where available
- Startup items
- Installed applications
- Recent System and Application event log warnings/errors

## Output

The toolkit creates a timestamped report folder with:

- CSV reports
- JSON reports
- HTML report
- Log file
- Ticket-ready summary

## How to run

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Windows_Endpoint_Health_Check_Toolkit.ps1
```

Run with a custom output folder:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Windows_Endpoint_Health_Check_Toolkit.ps1 -OutputPath C:\Temp\EndpointReports
```

Run without automatically opening File Explorer:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Windows_Endpoint_Health_Check_Toolkit.ps1 -NoExplorer
```

## Requirements

- Windows PowerShell 5.1+
- Windows 10/11 or Windows Server
- Administrator PowerShell recommended for complete results

## Safety

This script is diagnostic-only. It does not delete files, reset services, change registry values, change firewall settings, install software, or remove software.

## Portfolio explanation

This project demonstrates endpoint troubleshooting, PowerShell automation, evidence collection, reporting, and IT support documentation skills.
