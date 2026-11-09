# run_ae_script.ps1 — locate After Effects and execute a .jsx task script with JSON log feedback.
# Usage:
#   powershell -NoProfile -File run_ae_script.ps1 -FindAE
#   powershell -NoProfile -File run_ae_script.ps1 -ScriptPath task.jsx [-LogPath out.json] [-AePath <AfterFX.exe>] [-KeepOpen] [-NoUI] [-TimeoutMinutes 30]
# Exit codes: 0 = script ok | 1 = script error | 2 = AE not found / bad args | 3 = timeout
[CmdletBinding()]
param(
  [string]$ScriptPath,
  [string]$LogPath,
  [string]$AePath,
  [switch]$FindAE,
  [switch]$KeepOpen,
  [switch]$NoUI,
  [int]$TimeoutMinutes = 30
)

$ErrorActionPreference = 'Stop'

function Find-AfterFX {
  if ($AePath -and (Test-Path $AePath)) { return $AePath }
  $roots = @("$env:ProgramFiles\Adobe", "${env:ProgramFiles(x86)}\Adobe")
  $candidates = @()
  foreach ($root in $roots) {
    if (Test-Path $root) {
      $candidates += Get-ChildItem $root -Directory -Filter 'Adobe After Effects*' -ErrorAction SilentlyContinue |
        ForEach-Object { Join-Path $_.FullName 'Support Files\AfterFX.exe' } |
        Where-Object { Test-Path $_ }
    }
  }
  if ($candidates.Count -gt 0) {
    # Newest version first by folder name.
    return ($candidates | Sort-Object { [regex]::Match($_, 'After Effects[^\d]*([\d.]+)').Groups[1].Value } -Descending | Select-Object -First 1)
  }
  # Registry fallback.
  $regBase = 'HKLM:\SOFTWARE\Adobe\After Effects'
  if (Test-Path $regBase) {
    foreach ($ver in (Get-ChildItem $regBase | Sort-Object PSChildName -Descending)) {
      $p = (Get-ItemProperty $ver.PSPath -ErrorAction SilentlyContinue).InstallPath
      if ($p) {
        $exe = Join-Path $p 'Support Files\AfterFX.exe'
        if (Test-Path $exe) { return $exe }
        if (Test-Path (Join-Path $p 'AfterFX.exe')) { return (Join-Path $p 'AfterFX.exe') }
      }
    }
  }
  return $null
}

$ae = Find-AfterFX
$aerender = $null
if ($ae) {
  $candidate = Join-Path (Split-Path $ae) 'aerender.exe'
  if (Test-Path $candidate) { $aerender = $candidate }
}

if ($FindAE) {
  [pscustomobject]@{
    found    = [bool]$ae
    afterfx  = $ae
    aerender = $aerender
  } | ConvertTo-Json -Compress
  exit ([int](-not $ae) * 2)
}

if (-not $ae) {
  Write-Error 'AfterFX.exe not found. Install After Effects or pass -AePath.'
  exit 2
}
if (-not $ScriptPath -or -not (Test-Path $ScriptPath)) {
  Write-Error "ScriptPath missing or not found: $ScriptPath"
  exit 2
}
if (-not $LogPath) { $LogPath = "$ScriptPath.result.json" }
if (Test-Path $LogPath) { Remove-Item $LogPath -Force }

# Newer AE versions ship with scripting file/network access disabled, which
# silently kills any script that writes files (including our log writer).
# Flip the preference in the main prefs file before launching, if AE is closed.
function Ensure-ScriptingFileAccess {
  $prefRoot = Join-Path $env:APPDATA 'Adobe\After Effects'
  if (-not (Test-Path $prefRoot)) { return }
  foreach ($verDir in (Get-ChildItem $prefRoot -Directory -ErrorAction SilentlyContinue)) {
    Get-ChildItem $verDir.FullName -Filter 'Adobe After Effects *.txt' -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -notmatch '-indep|-paint|-text' } |
      ForEach-Object {
        $content = [System.IO.File]::ReadAllText($_.FullName)
        if ($content -match '"Pref_SCRIPTING_FILE_NETWORK_SECURITY"\s*=\s*"0"') {
          if (Get-Process AfterFX -ErrorAction SilentlyContinue) {
            Write-Warning "AE is running; enable 'Allow Scripts to Write Files and Access Network' manually in Preferences > Scripting & Expressions."
          } else {
            $fixed = $content -replace '"Pref_SCRIPTING_FILE_NETWORK_SECURITY"\s*=\s*"0"', '"Pref_SCRIPTING_FILE_NETWORK_SECURITY" = "1"'
            [System.IO.File]::WriteAllText($_.FullName, $fixed, (New-Object System.Text.UTF8Encoding($false)))
            Write-Host "Enabled scripting file/network access in '$($_.Name)'."
          }
        }
      }
  }
}
Ensure-ScriptingFileAccess

$running = Get-Process AfterFX -ErrorAction SilentlyContinue
if ($running) { Write-Warning 'An AfterFX.exe instance is already running; the script may attach to it or conflict.' }

$userCode = [System.IO.File]::ReadAllText((Resolve-Path $ScriptPath), [System.Text.Encoding]::UTF8)
$logPathJs = ($LogPath -replace '\\', '/')

$exitBlock = ''
if (-not $KeepOpen) {
  $exitBlock = @'
  try { app.project.close(CloseOptions.DO_NOT_SAVE_CHANGES); } catch (e1) {}
  try { app.exit(); } catch (e2) {}
'@
}

$wrapper = @"
(function () {
  var LOG_PATH = "$logPathJs";
  var __logs = [];
  function aeLog(m) { __logs.push(String(m)); }
  // This AE build has no native JSON object; serialize manually.
  function __q(s) { return '"' + String(s).replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\r/g, '\\r').replace(/\n/g, '\\n') + '"'; }
  function __ser(o) {
    if (o === null || o === undefined) return 'null';
    if (o instanceof Array) { var a = []; for (var i = 0; i < o.length; i++) a.push(__ser(o[i])); return '[' + a.join(',') + ']'; }
    if (typeof o === 'object') { var b = []; for (var k in o) { if (o.hasOwnProperty(k)) b.push(__q(k) + ':' + __ser(o[k])); } return '{' + b.join(',') + '}'; }
    if (typeof o === 'string') return __q(o);
    if (typeof o === 'number' || typeof o === 'boolean') return String(o);
    return __q(String(o));
  }
  function __writeLog(obj) {
    var f = new File(LOG_PATH);
    f.encoding = "UTF-8";
    f.open("w");
    f.write(__ser(obj));
    f.close();
  }
  var __status = "ok", __error = null, __line = null;
  try {
$userCode
  } catch (e) {
    __status = "error";
    __error = e.toString();
    try { __line = e.line; } catch (x) {}
  }
  __writeLog({ status: __status, error: __error, line: __line, log: __logs });
$exitBlock
})();
"@

$wrapperPath = Join-Path $env:TEMP ("ae_wrapper_" + [DateTime]::Now.ToString('yyyyMMdd_HHmmss') + '.jsx')
# BOM is required: ExtendScript decodes BOM-less .jsx as the system ANSI codepage,
# which mangles non-ASCII string literals (e.g. Chinese paths) inside the script.
[System.IO.File]::WriteAllText($wrapperPath, $wrapper, (New-Object System.Text.UTF8Encoding($true)))

# Use -s with $.evalFile instead of -r: some AE builds (incl. repackaged ones)
# silently exit on -r, while -s reliably executes and also forwards to a running instance.
$wrapperJs = $wrapperPath -replace '\\', '/'
$evalCmd = '$.evalFile("' + $wrapperJs + '")'
$argList = @()
if ($NoUI) { $argList += '-noui' }
$argList += @('-s', "`"$evalCmd`"")

$proc = Start-Process -FilePath $ae -ArgumentList $argList -PassThru

$deadline = (Get-Date).AddMinutes($TimeoutMinutes)
while (-not (Test-Path $LogPath)) {
  if ((Get-Date) -gt $deadline) {
    try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } catch {}
    Remove-Item $wrapperPath -Force -ErrorAction SilentlyContinue
    Write-Error "Timeout after $TimeoutMinutes min waiting for AE log: $LogPath"
    exit 3
  }
  Start-Sleep -Seconds 1
}

# Log appeared. If AE should close itself, give it a short grace period then force-kill.
if (-not $KeepOpen -and -not $proc.HasExited) {
  $grace = (Get-Date).AddSeconds(60)
  while (-not $proc.HasExited -and (Get-Date) -lt $grace) { Start-Sleep -Seconds 1 }
  if (-not $proc.HasExited) { try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } catch {} }
}

Remove-Item $wrapperPath -Force -ErrorAction SilentlyContinue

$result = Get-Content $LogPath -Raw -Encoding UTF8 | ConvertFrom-Json
$result | ConvertTo-Json -Depth 5
if ($result.status -eq 'ok') { exit 0 } else { exit 1 }
