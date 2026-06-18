#requires -Version 5.1
<#
.SYNOPSIS
    Windows Endpoint Health Check Toolkit.

.DESCRIPTION
    Menu-driven PowerShell toolkit for L1/L2 IT support endpoint checks.
    Creates ticket-ready reports for system, disk, network, security, services,
    pending reboot, event logs, startup items, and installed applications.

.NOTES
    Author: Dewald Pretorius / Dtech IT Solutions
    Version: 1.0.1
    This script is diagnostic-only and does not make destructive changes.
#>

[CmdletBinding()]
param(
    [switch]$RunAll,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$ScriptVersion = '1.0.1'
$RunStamp = Get-Date -Format 'yyyyMMdd_HHmmss'

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Initialize-ReportFolder {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) {
        $desktop = [Environment]::GetFolderPath('Desktop')
        $Path = Join-Path $desktop 'Endpoint_Health_Check_Reports'
    }
    New-Item -Path $Path -ItemType Directory -Force | Out-Null
    return $Path
}

$ReportRoot = Initialize-ReportFolder -Path $OutputPath
$LogFile = Join-Path $ReportRoot "EndpointHealthCheck_$RunStamp.log"

function Write-Log {
    param(
        [Parameter(Mandatory)] [string]$Message,
        [ValidateSet('INFO','WARN','ERROR','SUCCESS')] [string]$Level = 'INFO'
    )
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
    switch ($Level) {
        'WARN'    { Write-Host $Message -ForegroundColor Yellow }
        'ERROR'   { Write-Host $Message -ForegroundColor Red }
        'SUCCESS' { Write-Host $Message -ForegroundColor Green }
        default   { Write-Host $Message }
    }
}

function Pause-Menu {
    Write-Host
    [void](Read-Host 'Press Enter to return to the menu')
}

function Show-Header {
    Clear-Host
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host '   WINDOWS ENDPOINT HEALTH CHECK TOOLKIT' -ForegroundColor Cyan
    Write-Host "   Version $ScriptVersion" -ForegroundColor DarkCyan
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ("   Computer : {0}" -f $env:COMPUTERNAME)
    Write-Host ("   User     : {0}\{1}" -f $env:USERDOMAIN, $env:USERNAME)
    Write-Host ("   Admin    : {0}" -f (Test-IsAdministrator))
    Write-Host ("   Reports  : {0}" -f $ReportRoot)
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host
}

function New-Check {
    param(
        [Parameter(Mandatory)] [string]$Category,
        [Parameter(Mandatory)] [string]$Name,
        [ValidateSet('OK','Warning','Critical','Info')] [string]$Status = 'Info',
        [string]$Value = '',
        [string]$Recommendation = ''
    )
    [PSCustomObject]@{
        Category       = $Category
        Name           = $Name
        Status         = $Status
        Value          = $Value
        Recommendation = $Recommendation
    }
}

function Export-HealthReport {
    param(
        [Parameter(Mandatory)] [object[]]$Checks,
        [Parameter(Mandatory)] [string]$Name
    )
    $safeName = $Name -replace '[^\w\-]', '_'
    $csv = Join-Path $ReportRoot "$safeName`_$RunStamp.csv"
    $json = Join-Path $ReportRoot "$safeName`_$RunStamp.json"
    $html = Join-Path $ReportRoot "$safeName`_$RunStamp.html"

    $Checks | Export-Csv -Path $csv -NoTypeInformation -Encoding UTF8
    $Checks | ConvertTo-Json -Depth 5 | Set-Content -Path $json -Encoding UTF8

    $pre = @"
<h1>$Name</h1>
<p><b>Computer:</b> $env:COMPUTERNAME<br><b>User:</b> $env:USERDOMAIN\$env:USERNAME<br><b>Generated:</b> $(Get-Date)<br><b>Admin:</b> $(Test-IsAdministrator)</p>
<style>body{font-family:Segoe UI,Arial;margin:24px}table{border-collapse:collapse;width:100%}th,td{border:1px solid #ccc;padding:7px;vertical-align:top}th{background:#eee}.OK{color:green;font-weight:bold}.Warning{color:#b8860b;font-weight:bold}.Critical{color:red;font-weight:bold}.Info{color:#555;font-weight:bold}</style>
"@
    $body = $Checks | ConvertTo-Html -Fragment -Property Category,Name,Status,Value,Recommendation
    $body = $body -replace '<td>OK</td>','<td class="OK">OK</td>'
    $body = $body -replace '<td>Warning</td>','<td class="Warning">Warning</td>'
    $body = $body -replace '<td>Critical</td>','<td class="Critical">Critical</td>'
    $body = $body -replace '<td>Info</td>','<td class="Info">Info</td>'
    ConvertTo-Html -Title $Name -Body ($pre + $body) | Set-Content -Path $html -Encoding UTF8

    Write-Log "Created HTML report: $html" 'SUCCESS'
    Write-Log "Created CSV report: $csv" 'SUCCESS'
    Write-Log "Created JSON report: $json" 'SUCCESS'
    return [PSCustomObject]@{ Html = $html; Csv = $csv; Json = $json }
}

function Get-SystemChecks {
    $checks = @()
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $cs = Get-CimInstance Win32_ComputerSystem
        $bios = Get-CimInstance Win32_BIOS
        $uptime = (Get-Date) - $os.LastBootUpTime
        $ramGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
        $checks += New-Check 'System' 'Operating system' 'Info' "$($os.Caption) $($os.Version) Build $($os.BuildNumber)" 'Record OS/build in ticket notes.'
        $checks += New-Check 'System' 'Manufacturer / model' 'Info' "$($cs.Manufacturer) $($cs.Model)" 'Useful for warranty and driver checks.'
        $checks += New-Check 'System' 'BIOS version' 'Info' $bios.SMBIOSBIOSVersion 'Useful when firmware issues are suspected.'
        $checks += New-Check 'System' 'Domain / workgroup' 'Info' $cs.Domain 'Confirm join state.'
        $checks += New-Check 'System' 'Uptime' ($(if ($uptime.TotalDays -gt 14) { 'Warning' } else { 'OK' })) ("{0:N1} days" -f $uptime.TotalDays) 'Restart if uptime is high and symptoms match.'
        $checks += New-Check 'System' 'Installed RAM' ($(if ($ramGB -lt 8) { 'Warning' } else { 'OK' })) "$ramGB GB" '8 GB or more is recommended for modern Windows/M365 workloads.'
        $checks += New-Check 'System' 'Running as Administrator' ($(if (Test-IsAdministrator) { 'OK' } else { 'Warning' })) "$(Test-IsAdministrator)" 'Run elevated for complete results.'
    }
    catch {
        $checks += New-Check 'System' 'System query' 'Critical' $_.Exception.Message 'Run PowerShell as Administrator and retry.'
    }
    return $checks
}

function Get-DiskChecks {
    $checks = @()
    try {
        Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
            $size = [math]::Round($_.Size / 1GB, 2)
            $free = [math]::Round($_.FreeSpace / 1GB, 2)
            $pct = if ($_.Size -gt 0) { [math]::Round(($_.FreeSpace / $_.Size) * 100, 1) } else { 0 }
            $status = if ($pct -lt 10 -or $free -lt 5) { 'Critical' } elseif ($pct -lt 20 -or $free -lt 15) { 'Warning' } else { 'OK' }
            $rec = if ($status -eq 'OK') { 'Disk space looks healthy.' } else { 'Free up space. Check temp files, Downloads, profiles, and update cache.' }
            $checks += New-Check 'Disk' "Drive $($_.DeviceID)" $status "$free GB free of $size GB ($pct%)" $rec
        }
        Get-PhysicalDisk -ErrorAction SilentlyContinue | ForEach-Object {
            $status = if ($_.HealthStatus -eq 'Healthy') { 'OK' } else { 'Warning' }
            $checks += New-Check 'Disk' "Physical disk $($_.FriendlyName)" $status "Health: $($_.HealthStatus); Operational: $($_.OperationalStatus)" 'Investigate non-healthy disks with vendor diagnostics.'
        }
    }
    catch {
        $checks += New-Check 'Disk' 'Disk query' 'Critical' $_.Exception.Message 'Run as Administrator and retry.'
    }
    return $checks
}

function Get-NetworkChecks {
    $checks = @()
    try {
        $upAdapters = Get-NetAdapter -ErrorAction Stop | Where-Object Status -eq 'Up'
        if (-not $upAdapters) { $checks += New-Check 'Network' 'Active adapters' 'Critical' 'None found' 'Check cable, Wi-Fi, docking station, drivers, or disabled adapters.' }
        foreach ($adapter in $upAdapters) { $checks += New-Check 'Network' "Adapter $($adapter.Name)" 'OK' "$($adapter.InterfaceDescription); $($adapter.LinkSpeed)" 'Adapter is up.' }
        Get-NetIPConfiguration | Where-Object { $_.IPv4Address -or $_.IPv6Address } | ForEach-Object {
            $ipv4 = ($_.IPv4Address | Select-Object -First 1).IPAddress
            $gw = ($_.IPv4DefaultGateway | Select-Object -First 1).NextHop
            $dns = ($_.DNSServer.ServerAddresses -join ', ')
            $checks += New-Check 'Network' "IP config $($_.InterfaceAlias)" 'Info' "IPv4: $ipv4; Gateway: $gw; DNS: $dns" 'Use this in ticket notes.'
            if ($gw) { $ok = Test-Connection -ComputerName $gw -Count 1 -Quiet -ErrorAction SilentlyContinue; $checks += New-Check 'Network' "Gateway ping $gw" ($(if ($ok) { 'OK' } else { 'Warning' })) "$ok" 'If this fails, check local network/VLAN/Wi-Fi/router.' }
        }
        foreach ($target in @('1.1.1.1','8.8.8.8')) { $ok = Test-Connection -ComputerName $target -Count 1 -Quiet -ErrorAction SilentlyContinue; $checks += New-Check 'Network' "Internet ping $target" ($(if ($ok) { 'OK' } else { 'Warning' })) "$ok" 'If this fails, check internet path, firewall, or ISP.' }
        foreach ($name in @('www.microsoft.com','login.microsoftonline.com')) { try { [void][System.Net.Dns]::GetHostAddresses($name); $checks += New-Check 'Network' "DNS lookup $name" 'OK' 'Resolved' 'DNS works for this host.' } catch { $checks += New-Check 'Network' "DNS lookup $name" 'Warning' $_.Exception.Message 'Check DNS, VPN, proxy, or filtering.' } }
        $proxy = (& netsh.exe winhttp show proxy 2>&1) -join ' '
        $checks += New-Check 'Network' 'WinHTTP proxy' 'Info' $proxy 'Unexpected proxies can break updates and Microsoft 365 sign-in.'
    }
    catch {
        $checks += New-Check 'Network' 'Network query' 'Critical' $_.Exception.Message 'Run as Administrator and retry.'
    }
    return $checks
}

function Get-SecurityChecks {
    $checks = @()
    try { Get-NetFirewallProfile | ForEach-Object { $checks += New-Check 'Security' "Firewall $($_.Name)" ($(if ($_.Enabled) { 'OK' } else { 'Warning' })) "Enabled: $($_.Enabled)" 'Firewall should normally be enabled unless centrally managed.' } } catch { $checks += New-Check 'Security' 'Firewall check' 'Warning' $_.Exception.Message 'Could not query firewall.' }
    try { $mp = Get-MpComputerStatus; $checks += New-Check 'Security' 'Defender real-time protection' ($(if ($mp.RealTimeProtectionEnabled) { 'OK' } else { 'Critical' })) "$($mp.RealTimeProtectionEnabled)" 'Real-time protection should be enabled unless another AV is used.'; $age = (Get-Date) - $mp.AntivirusSignatureLastUpdated; $checks += New-Check 'Security' 'Defender signature age' ($(if ($age.TotalDays -gt 7) { 'Warning' } else { 'OK' })) ("{0:N1} days old" -f $age.TotalDays) 'Update signatures if old.' } catch { $checks += New-Check 'Security' 'Defender check' 'Info' $_.Exception.Message 'May be third-party AV or restricted cmdlets.' }
    try { Get-BitLockerVolume | ForEach-Object { $checks += New-Check 'Security' "BitLocker $($_.MountPoint)" ($(if ($_.ProtectionStatus -eq 'On') { 'OK' } else { 'Warning' })) "Protection: $($_.ProtectionStatus); Volume: $($_.VolumeStatus)" 'Review against company encryption policy.' } } catch { $checks += New-Check 'Security' 'BitLocker check' 'Info' $_.Exception.Message 'May require admin rights or supported Windows edition.' }
    try { $admins = (Get-LocalGroupMember -Group 'Administrators' | Select-Object -ExpandProperty Name) -join '; '; $checks += New-Check 'Security' 'Local administrators' 'Info' $admins 'Review local admin membership against company policy.' } catch { $checks += New-Check 'Security' 'Local administrators' 'Warning' $_.Exception.Message 'Run as Administrator.' }
    return $checks
}

function Get-ServiceChecks {
    $checks = @()
    $serviceList = @('wuauserv','BITS','Winmgmt','EventLog','Dhcp','Dnscache','Spooler','ClickToRunSvc')
    foreach ($name in $serviceList) {
        $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
        if (-not $svc) { $checks += New-Check 'Services' $name 'Warning' 'Not found' 'Service may not exist on this endpoint.'; continue }
        $mustRun = $name -in @('Winmgmt','EventLog','Dhcp','Dnscache')
        $status = if ($mustRun -and $svc.Status -ne 'Running') { 'Warning' } else { 'OK' }
        $checks += New-Check 'Services' $svc.DisplayName $status "Status: $($svc.Status)" 'Investigate if the service state does not match the reported issue.'
    }
    return $checks
}

function Get-PendingRebootChecks {
    $checks = @(); $reasons = @()
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') { $reasons += 'Component Based Servicing reboot pending' }
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') { $reasons += 'Windows Update reboot required' }
    try { $ops = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue).PendingFileRenameOperations; if ($ops) { $reasons += 'Pending file rename operations' } } catch { }
    if ($reasons.Count -gt 0) { $checks += New-Check 'Reboot' 'Pending reboot' 'Warning' ($reasons -join '; ') 'Restart before installs, updates, or deep troubleshooting.' } else { $checks += New-Check 'Reboot' 'Pending reboot' 'OK' 'No common pending reboot indicators found' 'No reboot required based on common checks.' }
    return $checks
}

function Get-EventLogChecks {
    param([int]$Hours = 24)
    $checks = @(); $start = (Get-Date).AddHours(-1 * $Hours)
    foreach ($log in @('System','Application')) {
        try {
            $events = Get-WinEvent -FilterHashtable @{ LogName = $log; Level = 1,2; StartTime = $start } -ErrorAction Stop
            $count = @($events).Count
            $status = if ($count -gt 50) { 'Warning' } elseif ($count -gt 0) { 'Info' } else { 'OK' }
            $checks += New-Check 'Event Logs' "$log critical/errors in last $Hours hours" $status "$count event(s)" 'Review top providers if symptoms match.'
            $events | Group-Object ProviderName | Sort-Object Count -Descending | Select-Object -First 5 | ForEach-Object { $checks += New-Check 'Event Logs' "Top provider: $($_.Name)" 'Info' "$($_.Count) event(s)" 'Use Event Viewer for deeper analysis.' }
        }
        catch { $checks += New-Check 'Event Logs' "$log query" 'Warning' $_.Exception.Message 'Run as Administrator or check log access.' }
    }
    return $checks
}

function Get-StartupAndAppChecks {
    $checks = @()
    try { $startup = Get-CimInstance Win32_StartupCommand; $checks += New-Check 'Startup' 'Startup item count' ($(if (@($startup).Count -gt 30) { 'Warning' } else { 'Info' })) "$(@($startup).Count) startup item(s)" 'Too many startup items can slow sign-in.'; $startup | Select-Object -First 10 | ForEach-Object { $checks += New-Check 'Startup' $_.Name 'Info' $_.Command 'Review if startup impact is suspected.' } } catch { $checks += New-Check 'Startup' 'Startup query' 'Warning' $_.Exception.Message 'Could not query startup items.' }
    try { $paths = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*','HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'); $apps = Get-ItemProperty $paths -ErrorAction SilentlyContinue | Where-Object DisplayName | Select-Object DisplayName,DisplayVersion,Publisher,InstallDate; $appCsv = Join-Path $ReportRoot "InstalledApps_$RunStamp.csv"; $apps | Sort-Object DisplayName | Export-Csv -Path $appCsv -NoTypeInformation -Encoding UTF8; $checks += New-Check 'Applications' 'Installed application count' 'Info' "$(@($apps).Count) app(s)" 'Exported app inventory.'; $checks += New-Check 'Applications' 'Installed app inventory exported' 'OK' $appCsv 'Attach this CSV to tickets if useful.' } catch { $checks += New-Check 'Applications' 'Installed apps query' 'Warning' $_.Exception.Message 'Could not query installed apps.' }
    return $checks
}

function Show-ChecksAndExport {
    param([object[]]$Checks, [string]$ReportName, [switch]$OpenReport)
    $Checks | Sort-Object Category, Status, Name | Format-Table Category, Name, Status, Value -AutoSize -Wrap
    $files = Export-HealthReport -Checks $Checks -Name $ReportName
    if ($OpenReport) { try { Start-Process $files.Html } catch { Write-Log "Could not open HTML report: $($_.Exception.Message)" 'WARN' } }
}

function Invoke-QuickSummary { Show-Header; $checks = @(); $checks += Get-SystemChecks; $checks += Get-DiskChecks; $checks += Get-PendingRebootChecks; $checks += Get-ServiceChecks; Show-ChecksAndExport $checks 'Quick_Endpoint_Health_Summary'; Pause-Menu }
function Invoke-FullReport { Show-Header; Write-Host 'Collecting endpoint data...' -ForegroundColor Yellow; $checks = @(); $checks += Get-SystemChecks; $checks += Get-DiskChecks; $checks += Get-NetworkChecks; $checks += Get-SecurityChecks; $checks += Get-ServiceChecks; $checks += Get-PendingRebootChecks; $checks += Get-StartupAndAppChecks; $checks += Get-EventLogChecks -Hours 24; Show-ChecksAndExport $checks 'Full_Endpoint_Health_Report' -OpenReport; Pause-Menu }
function Invoke-CheckByName { param([string]$Name); Show-Header; $checks = switch ($Name) { 'System' { Get-SystemChecks } 'Disk' { Get-DiskChecks } 'Network' { Get-NetworkChecks } 'Security' { Get-SecurityChecks } 'Services' { Get-ServiceChecks } 'Reboot' { Get-PendingRebootChecks } 'StartupApps' { Get-StartupAndAppChecks } }; Show-ChecksAndExport $checks "$Name`_Check"; Pause-Menu }
function Invoke-EventLogMenu { Show-Header; $inputHours = Read-Host 'How many hours back should I check? Default is 24'; $hours = 24; if (-not [string]::IsNullOrWhiteSpace($inputHours)) { [void][int]::TryParse($inputHours, [ref]$hours); if ($hours -lt 1) { $hours = 24 } }; $checks = Get-EventLogChecks -Hours $hours; Show-ChecksAndExport $checks "Event_Log_Check_Last_$hours`_Hours"; Pause-Menu }
function Open-ReportFolder { Show-Header; try { Start-Process explorer.exe -ArgumentList "`"$ReportRoot`""; Write-Log "Opened report folder: $ReportRoot" 'SUCCESS' } catch { Write-Log "Could not open report folder: $($_.Exception.Message)" 'ERROR' }; Pause-Menu }

Write-Log "Windows Endpoint Health Check Toolkit v$ScriptVersion started."
Write-Log "Administrator: $(Test-IsAdministrator)"
Write-Log "Report folder: $ReportRoot"

if ($RunAll) { Invoke-FullReport; return }

do {
    Show-Header
    Write-Host '  1. Quick endpoint health summary'
    Write-Host '  2. Full endpoint health report'
    Write-Host '  3. System information check'
    Write-Host '  4. Disk and storage check'
    Write-Host '  5. Network health check'
    Write-Host '  6. Security baseline check'
    Write-Host '  7. Critical services check'
    Write-Host '  8. Pending reboot check'
    Write-Host '  9. Event log analyzer'
    Write-Host ' 10. Startup and installed apps inventory'
    Write-Host ' 11. Open report folder'
    Write-Host
    Write-Host '  0. Exit'
    Write-Host
    $choice = Read-Host 'Select an option'
    switch ($choice) {
        '1'  { Invoke-QuickSummary }
        '2'  { Invoke-FullReport }
        '3'  { Invoke-CheckByName -Name 'System' }
        '4'  { Invoke-CheckByName -Name 'Disk' }
        '5'  { Invoke-CheckByName -Name 'Network' }
        '6'  { Invoke-CheckByName -Name 'Security' }
        '7'  { Invoke-CheckByName -Name 'Services' }
        '8'  { Invoke-CheckByName -Name 'Reboot' }
        '9'  { Invoke-EventLogMenu }
        '10' { Invoke-CheckByName -Name 'StartupApps' }
        '11' { Open-ReportFolder }
        '0'  { Write-Log 'Toolkit closed by the user.'; Write-Host 'Goodbye.' -ForegroundColor Green }
        default { Write-Host 'Invalid selection.' -ForegroundColor Yellow; Start-Sleep -Seconds 1 }
    }
}
while ($choice -ne '0')
