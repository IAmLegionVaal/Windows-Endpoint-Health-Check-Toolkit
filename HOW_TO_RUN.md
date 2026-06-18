# How to Run

## 1. Download the repo

Download the repository as a ZIP or clone it with Git.

```powershell
git clone https://github.com/IAmLegionVaal/Windows-Endpoint-Health-Check-Toolkit.git
```

## 2. Open PowerShell as Administrator

Administrator mode is recommended because some checks need elevated permissions.

## 3. Go to the project folder

```powershell
cd .\Windows-Endpoint-Health-Check-Toolkit
```

## 4. Run the toolkit

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Windows_Endpoint_Health_Check_Toolkit.ps1
```

## 5. Review the output

A report folder is created on the Desktop by default.

Typical files include:

```text
endpoint_health_report.html
endpoint_health_checks.csv
endpoint_health_checks.json
health_status_summary.csv
ticket_summary.txt
toolkit.log
system_summary.csv
disk_summary.csv
network_adapters.csv
ip_configuration.csv
key_services.csv
recent_system_events.csv
recent_application_events.csv
```

## Common parameters

Custom output folder:

```powershell
.\Windows_Endpoint_Health_Check_Toolkit.ps1 -OutputPath C:\Temp\EndpointReports
```

Change event log lookback window:

```powershell
.\Windows_Endpoint_Health_Check_Toolkit.ps1 -EventHours 72
```

Do not open File Explorer after completion:

```powershell
.\Windows_Endpoint_Health_Check_Toolkit.ps1 -NoExplorer
```
