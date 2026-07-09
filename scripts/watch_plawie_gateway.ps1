param(
  [string]$Package = "com.openclaw.plawie",
  [string]$OutDir = "test-watch",
  [string]$Adb = "adb",
  [switch]$NoFollow
)

$ErrorActionPreference = "Stop"

function New-SafeDirectory {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path | Out-Null
  }
}

function Invoke-AdbText {
  param([string[]]$Args)
  try {
    & $Adb @Args 2>&1
  } catch {
    "ADB command failed: $($Args -join ' ') :: $_"
  }
}

function Start-AdbCapture {
  param(
    [string]$Name,
    [string[]]$Args,
    [string]$Path
  )

  Write-Host "[watch] starting $Name -> $Path"
  $process = Start-Process -FilePath $Adb `
    -ArgumentList $Args `
    -NoNewWindow `
    -PassThru `
    -RedirectStandardOutput $Path `
    -RedirectStandardError "$Path.err"
  return $process
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$sessionDir = Join-Path $OutDir "live-gateway-$stamp"
New-SafeDirectory -Path $OutDir
New-SafeDirectory -Path $sessionDir

$manifestPath = Join-Path $sessionDir "manifest.txt"
"Plawie Gateway Watch Session" | Set-Content -Path $manifestPath
"Started: $(Get-Date -Format o)" | Add-Content -Path $manifestPath
"Package: $Package" | Add-Content -Path $manifestPath

Write-Host "[watch] output: $sessionDir"

Invoke-AdbText @("devices", "-l") | Tee-Object -FilePath (Join-Path $sessionDir "adb-devices.txt") | Out-Null
Invoke-AdbText @("shell", "date") | Tee-Object -FilePath (Join-Path $sessionDir "device-date.txt") | Out-Null
Invoke-AdbText @("shell", "pidof", $Package) | Tee-Object -FilePath (Join-Path $sessionDir "app-pid.txt") | Out-Null
Invoke-AdbText @("shell", "ps", "-A") |
  Select-String -Pattern "openclaw|node|npm|$Package" |
  Tee-Object -FilePath (Join-Path $sessionDir "processes-openclaw.txt") |
  Out-Null

$screenshot = Join-Path $sessionDir "screen.png"
try {
  & $Adb exec-out screencap -p > $screenshot
} catch {
  "screencap failed: $_" | Set-Content -Path "$screenshot.err"
}

try {
  Invoke-AdbText @("shell", "uiautomator", "dump", "/sdcard/plawie-watch.xml") |
    Out-File -FilePath (Join-Path $sessionDir "uiautomator-dump.txt")
  & $Adb pull /sdcard/plawie-watch.xml (Join-Path $sessionDir "uiautomator.xml") | Out-Null
} catch {
  "uiautomator dump failed: $_" | Set-Content -Path (Join-Path $sessionDir "uiautomator.err.txt")
}

if ($NoFollow) {
  Write-Host "[watch] snapshot complete (--NoFollow)."
  exit 0
}

$logcatPath = Join-Path $sessionDir "logcat-raw.txt"
$filteredPath = Join-Path $sessionDir "logcat-filtered.txt"
$gatewayPath = Join-Path $sessionDir "gateway-tail.txt"

$logcat = Start-AdbCapture -Name "logcat" `
  -Args @("logcat", "-v", "time") `
  -Path $logcatPath

$filterScript = @"
adb logcat -v time |
  Select-String -Pattern 'Plawie|OpenClaw|GATEWAY|Gateway|NODE|chat\.send|model-fetch|talk\.speak|talk provider|rate limit|stale|file lock|queued_work_without_active_run|node required|missing node|tools\.allow|WebSocket|handshake timeout|event_loop|liveness warning|flutter'
"@

Start-Job -Name "plawie-filtered-logcat-$stamp" -ScriptBlock {
  param($ScriptText, $OutputPath)
  powershell -NoProfile -ExecutionPolicy Bypass -Command $ScriptText |
    Tee-Object -FilePath $OutputPath
} -ArgumentList $filterScript, $filteredPath | Out-Null

$tailCommand = @"
run-as $Package sh -c '
  candidates="
  files/rootfs/root/.openclaw/gateway.log
  files/rootfs/ubuntu/root/.openclaw/gateway.log
  files/rootfs/root/.openclaw/logs/gateway.log
  files/rootfs/ubuntu/root/.openclaw/logs/gateway.log
  "
  for f in `$candidates; do
    if [ -f "`$f" ]; then
      echo "[watch] tailing `$f"
      exec tail -n 300 -F "`$f"
    fi
  done
  found=`$(find files -path "*openclaw*" -name "*.log" 2>/dev/null | head -n 1)
  if [ -n "`$found" ]; then
    echo "[watch] tailing `$found"
    exec tail -n 300 -F "`$found"
  fi
  echo "[watch] no app-private gateway log found via run-as"
'
"@

$gatewayTail = Start-AdbCapture -Name "gateway-tail" `
  -Args @("shell", $tailCommand) `
  -Path $gatewayPath

@"
[watch] live capture running.

Raw logcat:       $logcatPath
Filtered logcat:  $filteredPath
Gateway tail:     $gatewayPath

Press Ctrl+C in this terminal to stop. If child adb processes stay alive, run:
  Get-Process adb -ErrorAction SilentlyContinue | Stop-Process

Tip: use the in-app Chat diagnostics toggle to see the same filtered gateway
activity while testing prompts. This script is the forensic backup.
"@ | Tee-Object -FilePath (Join-Path $sessionDir "README.txt")

try {
  while ($true) {
    Start-Sleep -Seconds 2
    if ($logcat.HasExited) {
      Write-Host "[watch] logcat exited."
      break
    }
    if ($gatewayTail.HasExited) {
      Write-Host "[watch] gateway tail exited; logcat is still running."
    }
  }
} finally {
  foreach ($p in @($logcat, $gatewayTail)) {
    if ($p -and -not $p.HasExited) {
      $p.Kill()
    }
  }
  Get-Job -Name "plawie-filtered-logcat-$stamp" -ErrorAction SilentlyContinue |
    Stop-Job -PassThru |
    Remove-Job
  "Stopped: $(Get-Date -Format o)" | Add-Content -Path $manifestPath
}
