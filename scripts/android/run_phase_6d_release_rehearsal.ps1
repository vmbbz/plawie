param(
  [string]$DeviceId = "",
  [string]$PackageName = "com.nxg.openclawproot",
  [int]$Port = 8765,
  [switch]$SkipBuild,
  [switch]$SkipInstall,
  [switch]$SkipChatSmokes,
  [string]$OutputPath = ".tmp/phase-6d-a-release-rehearsal.json",
  [string]$Phase = "6D-A",
  [string]$Mode = "non-destructive release rehearsal",
  [string]$DataStateNote = "No app data was cleared.",
  [int]$MinimumInstalledNativeSkills = 60,
  [int]$ChatSmokeTimeoutSec = 60
)

$ErrorActionPreference = "Stop"

function Invoke-CheckedProcess {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [Parameter(Mandatory = $true)][string[]]$Arguments
  )

  Write-Host ">>> $FilePath $($Arguments -join ' ')"
  & $FilePath @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "$FilePath exited with code $LASTEXITCODE"
  }
}

function Resolve-DeviceId {
  param([string]$RequestedDeviceId)

  if ($RequestedDeviceId.Trim().Length -gt 0) {
    return $RequestedDeviceId.Trim()
  }

  $devices = adb devices |
    Select-Object -Skip 1 |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -match "\tdevice$" } |
    ForEach-Object { ($_ -split "\s+")[0] }

  if ($devices.Count -eq 0) {
    throw "No adb device is connected."
  }
  if ($devices.Count -gt 1) {
    throw "Multiple adb devices are connected. Pass -DeviceId explicitly."
  }
  return $devices[0]
}

function Invoke-JsonGet {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [int]$TimeoutSec = 30
  )

  return Invoke-RestMethod -Method Get -Uri "http://127.0.0.1:$Port$Path" `
    -TimeoutSec $TimeoutSec
}

function Invoke-JsonPost {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][hashtable]$Body,
    [int]$TimeoutSec = 30
  )

  $json = $Body | ConvertTo-Json -Depth 24 -Compress
  return Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:$Port$Path" `
    -ContentType "application/json" -Body $json -TimeoutSec $TimeoutSec
}

function Invoke-ToolSmoke {
  param(
    [Parameter(Mandatory = $true)][string]$Id,
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][hashtable]$ToolInput,
    [int]$TimeoutSec = 30,
    [switch]$Optional
  )

  $started = Get-Date
  try {
    $response = Invoke-JsonPost -Path "/api/tools/execute" -TimeoutSec $TimeoutSec -Body @{
      name = $Name
      input = $ToolInput
    }
    $ok = $true
    if ($response.PSObject.Properties.Name -contains "success" -and
        $response.success -eq $false) {
      $ok = $false
    }
    [pscustomobject]@{
      id = $Id
      name = $Name
      input = $ToolInput
      required = -not $Optional
      ok = $ok
      status = "ok"
      elapsedMs = [int]((Get-Date) - $started).TotalMilliseconds
      response = $response
    }
  } catch {
    [pscustomobject]@{
      id = $Id
      name = $Name
      input = $ToolInput
      required = -not $Optional
      ok = $false
      status = "error"
      elapsedMs = [int]((Get-Date) - $started).TotalMilliseconds
      error = $_.Exception.Message
    }
  }
}

function Invoke-ChatSmoke {
  param(
    [Parameter(Mandatory = $true)][string]$Prompt,
    [int]$TimeoutSec = 35
  )

  $started = Get-Date
  try {
    $response = Invoke-JsonPost -Path "/api/debug/app-native-chat-tool-smoke" `
      -TimeoutSec $TimeoutSec -Body @{ prompt = $Prompt }
    [pscustomobject]@{
      prompt = $Prompt
      ok = ($response.success -eq $true)
      elapsedMs = [int]((Get-Date) - $started).TotalMilliseconds
      response = $response
    }
  } catch {
    [pscustomobject]@{
      prompt = $Prompt
      ok = $false
      elapsedMs = [int]((Get-Date) - $started).TotalMilliseconds
      error = $_.Exception.Message
    }
  }
}

function Assert-True {
  param(
    [Parameter(Mandatory = $true)][bool]$Condition,
    [Parameter(Mandatory = $true)][string]$Message
  )

  if (-not $Condition) {
    throw $Message
  }
}

$resolvedDevice = Resolve-DeviceId -RequestedDeviceId $DeviceId
$startedAt = Get-Date

if (-not $SkipBuild) {
  Invoke-CheckedProcess -FilePath "flutter" -Arguments @("build", "apk", "--debug")
}

if (-not $SkipInstall) {
  Invoke-CheckedProcess -FilePath "flutter" -Arguments @("install", "-d", $resolvedDevice, "--debug")
}

Invoke-CheckedProcess -FilePath "adb" -Arguments @(
  "-s", $resolvedDevice,
  "shell", "monkey",
  "-p", $PackageName,
  "-c", "android.intent.category.LAUNCHER",
  "1"
)
Start-Sleep -Seconds 10
Invoke-CheckedProcess -FilePath "adb" -Arguments @(
  "-s", $resolvedDevice,
  "forward", "tcp:$Port", "tcp:$Port"
)

$health = $null
foreach ($attempt in 1..12) {
  try {
    $health = Invoke-JsonGet -Path "/device/health" -TimeoutSec 20
    break
  } catch {
    if ($attempt -eq 12) {
      throw "Device health did not respond after $attempt attempts: $($_.Exception.Message)"
    }
    Start-Sleep -Seconds 3
  }
}

$readiness = $health.androidDefaultReadiness
Assert-True -Condition ($null -ne $readiness) `
  -Message "Device health response did not include androidDefaultReadiness."
Assert-True -Condition ($readiness.releaseGatePass -eq $true) `
  -Message "Release gate did not pass."
Assert-True -Condition ($readiness.readyRequired.ready -eq 13 -and $readiness.readyRequired.total -eq 13) `
  -Message "Launch-required readiness was not 13/13."
Assert-True -Condition ($readiness.totalManifestSkills -eq 61) `
  -Message "Classified default manifest was not 61."
Assert-True -Condition ($readiness.installedNativeSkills -ge $MinimumInstalledNativeSkills) `
  -Message "Installed Native package/workspace skill count was below $MinimumInstalledNativeSkills."
Assert-True -Condition ($readiness.unexpectedMissingDependency -eq 0) `
  -Message "Unexpected missing dependency count was not zero."

$toolsCatalog = Invoke-JsonGet -Path "/api/tools" -TimeoutSec 20

$requiredSmokes = @(
  @{ id = "device-health"; name = "device-node"; input = @{ action = "device_health" } },
  @{ id = "device-status"; name = "device-node"; input = @{ action = "device_status" } },
  @{ id = "battery"; name = "device-node"; input = @{ action = "get_battery" } },
  @{ id = "sensors"; name = "device-node"; input = @{ action = "list_sensors" } },
  @{ id = "weather"; name = "device-node"; input = @{ action = "weather_current"; city = "Johannesburg" }; timeoutSec = 45 },
  @{ id = "clawhub"; name = "device-node"; input = @{ action = "clawhub_search"; query = "weather"; limit = 3 }; timeoutSec = 45 },
  @{ id = "meme-maker"; name = "device-node"; input = @{ action = "meme_maker_create"; topText = "OpenClaw"; bottomText = "GTM" } },
  @{ id = "vibrate"; name = "device-node"; input = @{ action = "vibrate"; durationMs = 60 } },
  @{ id = "avatar-status"; name = "avatar-control"; input = @{ action = "get_status" } }
)

$toolSmokes = foreach ($smoke in $requiredSmokes) {
  $timeout = if ($smoke.ContainsKey("timeoutSec")) {
    [int]$smoke["timeoutSec"]
  } else {
    30
  }
  Invoke-ToolSmoke `
    -Id $smoke["id"] `
    -Name $smoke["name"] `
    -ToolInput $smoke["input"] `
    -TimeoutSec $timeout
}

$failedRequired = @($toolSmokes | Where-Object { $_.required -and -not $_.ok })
if ($failedRequired.Count -gt 0) {
  $ids = ($failedRequired | ForEach-Object { $_.id }) -join ", "
  throw "Required tool smokes failed: $ids"
}

$chatSmokes = @()
if (-not $SkipChatSmokes) {
  $chatSmokes = @(
    Invoke-ChatSmoke `
      -Prompt "Check device health and summarize the Android release gate." `
      -TimeoutSec $ChatSmokeTimeoutSec
    Invoke-ChatSmoke `
      -Prompt "Vibrate once and tell me whether the haptic action succeeded." `
      -TimeoutSec $ChatSmokeTimeoutSec
  )
}

$result = [pscustomobject]@{
  phase = $Phase
  mode = $Mode
  startedAt = $startedAt.ToString("o")
  completedAt = (Get-Date).ToString("o")
  deviceId = $resolvedDevice
  packageName = $PackageName
  buildRan = -not $SkipBuild
  installRan = -not $SkipInstall
  releaseGatePass = $readiness.releaseGatePass
  readyRequired = "$($readiness.readyRequired.ready)/$($readiness.readyRequired.total)"
  totalManifestSkills = $readiness.totalManifestSkills
  installedNativeSkills = $readiness.installedNativeSkills
  unexpectedMissingDependency = $readiness.unexpectedMissingDependency
  countsByClass = $readiness.countsByClass
  toolCatalogShape = if ($toolsCatalog.tools) { "tools" } else { "raw" }
  toolCatalogCount = if ($toolsCatalog.tools) { @($toolsCatalog.tools).Count } else { 0 }
  requiredToolSmokes = $toolSmokes
  chatSmokes = $chatSmokes
  chatSmokeTimeoutSec = $ChatSmokeTimeoutSec
  strictPass = ($failedRequired.Count -eq 0)
  notes = @(
    $DataStateNote,
    "installedNativeSkills counts file-backed OpenClaw package/workspace skill roots; app-native manifest capabilities are not all file-backed directories.",
    "Instruction-only Class A skills and UI-stateful canvas remain interactive chat/UI pass items.",
    "Chat smoke results are recorded but not part of the strict local release gate."
  )
}

$outputItem = Get-Item -LiteralPath "." | Select-Object -First 1
$outputFullPath = [System.IO.Path]::GetFullPath((Join-Path $outputItem.FullName $OutputPath))
$outputDir = Split-Path -Parent $outputFullPath
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
$result | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $outputFullPath -Encoding UTF8

Write-Host ""
Write-Host "Phase $Phase release rehearsal strict pass: $($result.strictPass)"
Write-Host "Device: $resolvedDevice"
Write-Host "Release gate: $($result.releaseGatePass), ready_required: $($result.readyRequired)"
Write-Host "Manifest: $($result.totalManifestSkills), Native package/workspace: $($result.installedNativeSkills), unexpected: $($result.unexpectedMissingDependency)"
Write-Host "Required tool smokes: $(@($toolSmokes | Where-Object { $_.ok }).Count)/$(@($toolSmokes).Count)"
Write-Host "Artifact: $outputFullPath"
