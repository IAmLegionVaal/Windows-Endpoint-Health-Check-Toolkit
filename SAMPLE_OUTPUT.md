# Sample Output

The toolkit creates a timestamped report folder, for example:

```text
EndpointHealth-LAPTOP01-20260618_153000
```

Inside the folder, you will see files such as:

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
defender_summary.csv
firewall_profiles.csv
startup_items.csv
recent_system_events.csv
recent_application_events.csv
```

## Example ticket summary

```text
Endpoint Health Check Summary
=============================
Computer: LAPTOP01
User: CONTOSO\jsmith
Generated: 2026-06-18 15:30
Report Folder: C:\Users\jsmith\Desktop\Endpoint_Health_Reports\EndpointHealth-LAPTOP01-20260618_153000

Suggested Ticket Note:
The Windows Endpoint Health Check Toolkit was run to collect system, disk, network, security, services, startup, and event log evidence. Reports were exported as CSV, JSON, and HTML for escalation review.
```

## Example health findings

| Category | Check | Status | Value | Recommendation |
|---|---|---|---|---|
| Disk | Free space C: | Warning | 6.2 GB free | Low disk space can cause updates, apps, profiles, and performance issues. |
| System | Pending reboot | Warning | Pending reboot detected | Restart the endpoint before continuing with updates or app troubleshooting. |
| Network | TCP 443 to login.microsoftonline.com | OK | Reachable | Internet/M365 path is reachable on TCP 443. |
| Security | Defender real-time protection | OK | Enabled | Microsoft Defender real-time protection is enabled. |
