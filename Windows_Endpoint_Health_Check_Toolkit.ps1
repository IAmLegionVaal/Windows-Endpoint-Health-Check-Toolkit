#requires -Version 5.1
<#
.SYNOPSIS
    Windows Endpoint Health Check Toolkit.
.DESCRIPTION
    Read-only endpoint health reporter for IT support and ticket escalation.
.NOTES
    Author: Dewald Pretorius
    Safety: Diagnostic-only. Does not modify system settings.
#>
[CmdletBinding()]
param(
    [string]$OutputPath,
    [int]$EventHours = 24,
    [switch]$NoExplorer
)

$RunStamp = Get-Date -Format 'yyyyMMdd_HHmmss'
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Endpoint_Health_Reports'
}
$ReportRoot = Join-Path $OutputPath "EndpointHealth_$env:COMPUTERNAME`_$RunStamp"
New-Item -Path $ReportRoot -ItemType Directory -Force | Out-Null
$LogFile = Join-Path $ReportRoot 'toolkit.log'

function Write-Log {
    param([string]$Message,[string]$Level='INFO')
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$Level,$Message
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
    Write-Host $Message
}

function New-HealthCheck {
    param([string]$Category,[string]$Check,[string]$Status,[string]$Value,[string]$Recommendation)
    [PSCustomObject]@{ComputerName=$env:COMPUTERNAME;Category=$Category;Check=$Check;Status=$Status;Value=$Value;Recommendation=$Recommendation;CheckedAt=Get-Date}
}

function Export-Data {
    param([string]$Name,[object]$Data)
    $Data | Export-Csv (Join-Path $ReportRoot "$Name.csv") -NoTypeInformation -Encoding UTF8
    $Data | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $ReportRoot "$Name.json") -Encoding UTF8
}

Write-Log 'Starting Windows Endpoint Health Check Toolkit.'
$checks = @()

try {
    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    $bios = Get-CimInstance Win32_BIOS
    $summary = [PSCustomObject]@{
        ComputerName=$env:COMPUTERNAME;CurrentUser="$env:USERDOMAIN\$env:USERNAME";Manufacturer=$cs.Manufacturer;Model=$cs.Model;Domain=$cs.Domain;PartOfDomain=$cs.PartOfDomain;OS=$os.Caption;Version=$os.Version;Build=$os.BuildNumber;Architecture=$os.OSArchitecture;LastBootUpTime=$os.LastBootUpTime;UptimeHours=[math]::Round(((Get-Date)-$os.LastBootUpTime).TotalHours,2);TotalMemoryGB=[math]::Round($cs.TotalPhysicalMemory/1GB,2);BIOSVersion=$bios.SMBIOSBIOSVersion;SerialNumber=$bios.SerialNumber;GeneratedAt=Get-Date
    }
    Export-Data 'system_summary' @($summary)
    if ($summary.UptimeHours -gt 168) { $checks += New-HealthCheck 'System' 'Uptime' 'Warning' "$($summary.UptimeHours) hours" 'Restart may be useful before deeper troubleshooting.' }
    else { $checks += New-HealthCheck 'System' 'Uptime' 'OK' "$($summary.UptimeHours) hours" 'Uptime is within a normal support range.' }
} catch { $checks += New-HealthCheck 'System' 'System summary' 'Failed' $_.Exception.Message 'Run PowerShell with sufficient permissions.' }

try {
    $disks = Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object { [PSCustomObject]@{Drive=$_.DeviceID;VolumeName=$_.VolumeName;FileSystem=$_.FileSystem;SizeGB=[math]::Round($_.Size/1GB,2);FreeGB=[math]::Round($_.FreeSpace/1GB,2);FreePercent=[math]::Round(($_.FreeSpace/$_.Size)*100,2)} }
    Export-Data 'disk_summary' $disks
    foreach ($disk in $disks) {
        if ($disk.FreeGB -lt 10 -or $disk.FreePercent -lt 10) { $checks += New-HealthCheck 'Disk' "Free space $($disk.Drive)" 'Warning' "$($disk.FreeGB) GB free ($($disk.FreePercent)%)" 'Low disk space can cause updates, app, profile, and performance issues.' }
        else { $checks += New-HealthCheck 'Disk' "Free space $($disk.Drive)" 'OK' "$($disk.FreeGB) GB free ($($disk.FreePercent)%)" 'Disk free space looks acceptable.' }
    }
} catch { $checks += New-HealthCheck 'Disk' 'Disk summary' 'Failed' $_.Exception.Message 'Review WMI/CIM health.' }

try {
    $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Select-Object Name,Status,LinkSpeed,MacAddress,InterfaceDescription
    $ipConfig = Get-NetIPConfiguration -ErrorAction SilentlyContinue | Select-Object InterfaceAlias,InterfaceDescription,IPv4Address,IPv4DefaultGateway,DNSServer
    Export-Data 'network_adapters' $adapters
    Export-Data 'ip_configuration' $ipConfig
    $upAdapters = @($adapters | Where-Object Status -eq 'Up').Count
    if ($upAdapters -lt 1) { $checks += New-HealthCheck 'Network' 'Active adapters' 'Warning' '0 active adapters' 'Check physical link, Wi-Fi, driver, VLAN, or adapter status.' }
    else { $checks += New-HealthCheck 'Network' 'Active adapters' 'OK' "$upAdapters active adapter(s)" 'Network adapter status looks available.' }
    foreach ($target in @('www.microsoft.com','login.microsoftonline.com')) {
        $tcp = Test-NetConnection -ComputerName $target -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
        if ($tcp) { $checks += New-HealthCheck 'Network' "TCP 443 to $target" 'OK' 'Reachable' 'Internet/M365 path is reachable on TCP 443.' }
        else { $checks += New-HealthCheck 'Network' "TCP 443 to $target" 'Warning' 'Not reachable' 'Review DNS, firewall, proxy, ISP, or captive portal.' }
    }
} catch { $checks += New-HealthCheck 'Network' 'Network summary' 'Failed' $_.Exception.Message 'Network cmdlets may be unavailable.' }

try {
    $pending = (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')
    if ($pending) { $checks += New-HealthCheck 'System' 'Pending reboot' 'Warning' 'Pending reboot detected' 'Restart the endpoint before continuing with updates or app troubleshooting.' }
    else { $checks += New-HealthCheck 'System' 'Pending reboot' 'OK' 'No common pending reboot indicators found' 'No reboot indicator found in common locations.' }
} catch { $checks += New-HealthCheck 'System' 'Pending reboot' 'Info' $_.Exception.Message 'Could not query all pending reboot indicators.' }

try {
    $keyServices = @('Winmgmt','EventLog','wuauserv','BITS','MpsSvc','Dhcp','Dnscache','Spooler','LanmanWorkstation','LanmanServer')
    $services = foreach ($name in $keyServices) { Get-Service -Name $name -ErrorAction SilentlyContinue | Select-Object Name,DisplayName,Status,StartType }
    Export-Data 'key_services' $services
    foreach ($svc in $services) {
        if ($svc.Status -eq 'Running') { $checks += New-HealthCheck 'Services' $svc.Name 'OK' 'Running' "$($svc.DisplayName) is running." }
        else { $checks += New-HealthCheck 'Services' $svc.Name 'Warning' "$($svc.Status)" 'Review this service if related to the reported issue.' }
    }
} catch { $checks += New-HealthCheck 'Services' 'Service summary' 'Failed' $_.Exception.Message 'Could not query services.' }

try {
    $mp = Get-MpComputerStatus -ErrorAction Stop
    $defender = [PSCustomObject]@{AntivirusEnabled=$mp.AntivirusEnabled;RealTimeProtectionEnabled=$mp.RealTimeProtectionEnabled;SignatureLastUpdated=$mp.AntivirusSignatureLastUpdated;AMServiceEnabled=$mp.AMServiceEnabled}
    Export-Data 'defender_summary' @($defender)
    if ($mp.RealTimeProtectionEnabled) { $checks += New-HealthCheck 'Security' 'Defender real-time protection' 'OK' 'Enabled' 'Microsoft Defender real-time protection is enabled.' }
    else { $checks += New-HealthCheck 'Security' 'Defender real-time protection' 'Warning' 'Disabled or unavailable' 'Confirm whether another managed AV solution is installed.' }
} catch { $checks += New-HealthCheck 'Security' 'Defender status' 'Info' $_.Exception.Message 'Defender cmdlets may be unavailable or managed by another product.' }

try {
    $firewall = Get-NetFirewallProfile -ErrorAction Stop | Select-Object Name,Enabled,DefaultInboundAction,DefaultOutboundAction
    Export-Data 'firewall_profiles' $firewall
    foreach ($profile in $firewall) {
        if ($profile.Enabled) { $checks += New-HealthCheck 'Security' "Firewall $($profile.Name)" 'OK' 'Enabled' 'Firewall profile is enabled.' }
        else { $checks += New-HealthCheck 'Security' "Firewall $($profile.Name)" 'Warning' 'Disabled' 'Confirm this is approved by policy.' }
    }
} catch { $checks += New-HealthCheck 'Security' 'Firewall profiles' 'Info' $_.Exception.Message 'Could not query firewall profiles.' }

try {
    $startup = Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue | Select-Object Name,Command,Location,User
    Export-Data 'startup_items' $startup
    $checks += New-HealthCheck 'Startup' 'Startup item count' 'Info' (@($startup).Count) 'Review startup items if user reports slow logon.'
} catch { $checks += New-HealthCheck 'Startup' 'Startup items' 'Info' $_.Exception.Message 'Could not collect startup items.' }

try {
    $startTime = (Get-Date).AddHours(-1*$EventHours)
    $systemEvents = Get-WinEvent -FilterHashtable @{LogName='System';Level=1,2,3;StartTime=$startTime} -ErrorAction SilentlyContinue | Select-Object -First 150 TimeCreated,Id,ProviderName,LevelDisplayName,Message
    $appEvents = Get-WinEvent -FilterHashtable @{LogName='Application';Level=1,2,3;StartTime=$startTime} -ErrorAction SilentlyContinue | Select-Object -First 150 TimeCreated,Id,ProviderName,LevelDisplayName,Message
    Export-Data 'recent_system_events' $systemEvents
    Export-Data 'recent_application_events' $appEvents
    $eventCount = @($systemEvents).Count + @($appEvents).Count
    $checks += New-HealthCheck 'Event Logs' 'Recent warning/error count' 'Info' "$eventCount events in last $EventHours hours" 'Event count exported for review.'
} catch { $checks += New-HealthCheck 'Event Logs' 'Event log collection' 'Info' $_.Exception.Message 'Could not collect event logs.' }

Export-Data 'endpoint_health_checks' $checks
$summaryCounts = $checks | Group-Object Status | Select-Object Name,Count
$summaryCounts | Export-Csv (Join-Path $ReportRoot 'health_status_summary.csv') -NoTypeInformation -Encoding UTF8

$ticketSummary = @"
Endpoint Health Check Summary
=============================
Computer: $env:COMPUTERNAME
User: $env:USERDOMAIN\$env:USERNAME
Generated: $(Get-Date)
Report Folder: $ReportRoot

Suggested Ticket Note:
The Windows Endpoint Health Check Toolkit was run to collect system, disk, network, security, services, startup, and event log evidence. Reports were exported as CSV, JSON, and HTML for escalation review.
"@
$ticketSummary | Set-Content (Join-Path $ReportRoot 'ticket_summary.txt') -Encoding UTF8

$htmlReport = "<h1>Windows Endpoint Health Check - $env:COMPUTERNAME</h1><p><strong>Generated:</strong> $(Get-Date)</p><h2>Status Summary</h2>$($summaryCounts|ConvertTo-Html -Fragment)<h2>Health Checks</h2>$($checks|ConvertTo-Html -Fragment)"
$htmlReport | ConvertTo-Html -Title 'Windows Endpoint Health Check' | Set-Content (Join-Path $ReportRoot 'endpoint_health_report.html') -Encoding UTF8

Write-Log "Completed. Reports saved to: $ReportRoot" 'OK'
if (-not $NoExplorer) { Start-Process explorer.exe -ArgumentList "`"$ReportRoot`"" -ErrorAction SilentlyContinue }
