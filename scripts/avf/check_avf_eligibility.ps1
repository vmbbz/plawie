param(
    [string]$DeviceId = "",
    [string]$VmHost = "192.168.0.2",
    [int]$GatewayPort = 18790,
    [switch]$SkipEndpointProbe
)

$ErrorActionPreference = "Stop"

function Invoke-Adb {
    param([Parameter(Position = 0, ValueFromRemainingArguments = $true)][string[]]$AdbArgs)

    $baseArgs = @()
    if ($DeviceId.Trim().Length -gt 0) {
        $baseArgs += @("-s", $DeviceId)
    }

    & adb @baseArgs @AdbArgs
}

if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    throw "adb is required and was not found on PATH."
}

$devices = @((& adb devices) | Where-Object { $_ -match "`tdevice$" })
if ($devices.Count -eq 0) {
    Write-Host "No ADB device is connected."
    exit 1
}

if ($DeviceId.Trim().Length -eq 0 -and $devices.Count -gt 1) {
    Write-Host "Multiple devices are connected. Pass -DeviceId <serial>."
    $devices | ForEach-Object { Write-Host "  $_" }
    exit 1
}

if ($DeviceId.Trim().Length -eq 0) {
    $DeviceId = ($devices[0] -split "`t")[0]
}

$props = [ordered]@{
    deviceId = $DeviceId
    manufacturer = (Invoke-Adb "shell" "getprop" "ro.product.manufacturer").Trim()
    model = (Invoke-Adb "shell" "getprop" "ro.product.model").Trim()
    androidRelease = (Invoke-Adb "shell" "getprop" "ro.build.version.release").Trim()
    sdk = (Invoke-Adb "shell" "getprop" "ro.build.version.sdk").Trim()
    protectedVmSupported = (Invoke-Adb "shell" "getprop" "ro.boot.hypervisor.protected_vm.supported").Trim()
    vmSupported = (Invoke-Adb "shell" "getprop" "ro.boot.hypervisor.vm.supported").Trim()
}

$packages = @(Invoke-Adb "shell" "pm" "list" "packages" "--user" "0" 2>$null)
$virtPackages = @($packages | Where-Object { $_ -match "virt|terminal|linux" })

Write-Host "AVF eligibility snapshot"
Write-Host "------------------------"
foreach ($key in $props.Keys) {
    Write-Host ("{0}: {1}" -f $key, $props[$key])
}

Write-Host ""
Write-Host "Virtualization-related packages:"
if ($virtPackages.Count -eq 0) {
    Write-Host "  none found"
} else {
    $virtPackages | ForEach-Object { Write-Host "  $_" }
}

Write-Host ""
Write-Host "Optional VM gateway reachability probe:"
if ($SkipEndpointProbe) {
    Write-Host "  skipped"
} else {
    $probe = Invoke-Adb `
        "shell" `
        "sh" `
        "-c" `
        "echo | toybox nc -w 2 $VmHost $GatewayPort >/dev/null 2>&1" 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "  reachable: ${VmHost}:${GatewayPort}"
    } else {
        Write-Host "  not reachable: ${VmHost}:${GatewayPort}"
        if ($probe) {
            Write-Host "  probe: $probe"
        }
    }
}

Write-Host ""
Write-Host "Interpretation:"
Write-Host "  This is an eligibility screen only. OEM Android builds expose AVF signals differently."
Write-Host "  PRoot remains the default runtime unless AVF is explicitly configured and tested."
