[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [switch]$Repair,
    [ValidateSet('wuauserv','bits','cryptsvc','spooler','winmgmt','Dnscache')]
    [string[]]$RestartService,
    [switch]$RunSfc,
    [switch]$RunDism,
    [switch]$FlushDns,
    [switch]$ClearTemp,
    [switch]$DryRun,
    [switch]$Yes,
    [string]$OutputPath = (Join-Path $env:ProgramData 'WindowsEndpointRepair')
)

$ErrorActionPreference = 'Stop'
$script:Failures = 0
$script:Actions = 0
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$runPath = Join-Path $OutputPath $stamp
New-Item -ItemType Directory -Path $runPath -Force | Out-Null
$log = Join-Path $runPath 'repair.log'
$before = Join-Path $runPath 'before.json'
$after = Join-Path $runPath 'after.json'

function Write-Log([string]$Message) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message" | Tee-Object -FilePath $log -Append
}
function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = [Security.Principal.WindowsPrincipal]::new($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Invoke-RepairAction([string]$Description, [scriptblock]$Action) {
    $script:Actions++
    Write-Log $Description
    if ($DryRun) { Write-Log "DRY-RUN: $Description"; return }
    try { & $Action; Write-Log "SUCCESS: $Description" }
    catch { $script:Failures++; Write-Log "FAILED: $Description - $($_.Exception.Message)" }
}
function Get-State {
    [pscustomobject]@{
        Collected = Get-Date
        ComputerName = $env:COMPUTERNAME
        OS = Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber,LastBootUpTime
        Volumes = Get-Volume | Select-Object DriveLetter,FileSystemLabel,FileSystem,HealthStatus,SizeRemaining,Size
        Services = Get-Service wuauserv,bits,cryptsvc,spooler,winmgmt,Dnscache -ErrorAction SilentlyContinue | Select-Object Name,Status,StartType
        PendingReboot = [bool](Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending')
        Defender = Get-MpComputerStatus -ErrorAction SilentlyContinue | Select-Object AntivirusEnabled,RealTimeProtectionEnabled,AntivirusSignatureLastUpdated
    }
}

Get-State | ConvertTo-Json -Depth 5 | Set-Content -Path $before -Encoding UTF8
if (-not ($Repair -or $RestartService -or $RunSfc -or $RunDism -or $FlushDns -or $ClearTemp)) {
    Write-Error 'Choose at least one repair action.'
    exit 2
}
if (-not $DryRun -and -not (Test-Admin)) { Write-Error 'Run this repair from an elevated PowerShell session.'; exit 4 }
if (-not $Yes -and -not $DryRun) {
    $answer = Read-Host 'Apply the selected Windows endpoint repairs? Type YES to continue'
    if ($answer -ne 'YES') { Write-Log 'Repair cancelled.'; exit 10 }
}
if ($Repair) { $RunSfc = $true; $RunDism = $true; $FlushDns = $true; $RestartService = @('wuauserv','bits','cryptsvc','winmgmt','Dnscache') }
foreach ($name in @($RestartService)) {
    Invoke-RepairAction "Restarting service $name" { Restart-Service -Name $name -Force -ErrorAction Stop }
}
if ($FlushDns) { Invoke-RepairAction 'Flushing DNS resolver cache' { Clear-DnsClientCache } }
if ($RunDism) { Invoke-RepairAction 'Running DISM RestoreHealth' { $p = Start-Process dism.exe -ArgumentList '/Online','/Cleanup-Image','/RestoreHealth' -Wait -PassThru -NoNewWindow; if ($p.ExitCode -ne 0) { throw "DISM exited with $($p.ExitCode)" } } }
if ($RunSfc) { Invoke-RepairAction 'Running System File Checker' { $p = Start-Process sfc.exe -ArgumentList '/scannow' -Wait -PassThru -NoNewWindow; if ($p.ExitCode -notin 0,1) { throw "SFC exited with $($p.ExitCode)" } } }
if ($ClearTemp) {
    Invoke-RepairAction 'Removing stale files from the current user temp directory' {
        Get-ChildItem -LiteralPath $env:TEMP -Force -ErrorAction SilentlyContinue | Where-Object LastWriteTime -lt (Get-Date).AddDays(-7) | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
}
Start-Sleep -Seconds 2
Get-State | ConvertTo-Json -Depth 5 | Set-Content -Path $after -Encoding UTF8
if ($script:Failures -gt 0) { Write-Log "Completed with $script:Failures failure(s)."; exit 20 }
Write-Log "Repair completed successfully. Actions performed: $script:Actions"
exit 0
