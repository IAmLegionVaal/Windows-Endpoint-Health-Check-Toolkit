# Interview Explanation

## Project name

Windows Endpoint Health Check Toolkit

## Short explanation

I built this toolkit to help IT Support technicians quickly collect Windows endpoint health evidence before escalating a ticket. It checks system health, disk space, network configuration, services, security posture, startup items, and recent event logs. It then exports the results into CSV, JSON, HTML, and a ticket-ready summary.

## Why I built it

In IT support, escalation quality matters. A senior engineer can troubleshoot faster when the first-line technician provides clean evidence. This toolkit standardizes that evidence collection and reduces the chance of missing important checks.

## What problem it solves

It helps with:

- Slow computer troubleshooting
- Windows Update problems
- Microsoft 365 connectivity problems
- Disk space issues
- Security baseline checks
- Service-related issues
- Event log triage
- Ticket escalation evidence

## Skills demonstrated

- PowerShell scripting
- Windows troubleshooting
- Endpoint support
- Evidence collection
- CSV/JSON/HTML reporting
- Event log analysis
- Service checks
- Network checks
- Defensive scripting
- Documentation

## How I would explain it to an interviewer

> I created a Windows Endpoint Health Check Toolkit in PowerShell to standardize endpoint troubleshooting. The script collects system, disk, network, service, security, startup, and event log evidence, then creates CSV, JSON, HTML, and ticket-ready reports. It is diagnostic-only, so it is safe to run in support environments. The goal is to help L1 and L2 technicians collect better evidence before escalating issues.

## Future improvements

- Add a GUI front-end
- Add remote computer support
- Add signed script support
- Add PowerShell 7 compatibility testing
- Add unit-style checks for report creation
- Add optional email/export integration
