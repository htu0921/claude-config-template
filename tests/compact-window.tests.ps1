# Checks Install-CompactWindow (rules.ps1) on throwaway settings files in %TEMP%,
# never on ~/.claude. Exit 0 = all passed.
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\compact-window.tests.ps1

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\rules.ps1')
$root = Join-Path $env:TEMP ('compact-test-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$failed = 0
function Check([bool]$ok, [string]$what) {
    if ($ok) { Write-Output "ok   $what" } else { Write-Output "FAIL $what"; $script:failed++ }
}
function New-Settings($name, $json) {
    $dir = Join-Path $root $name; New-Item -ItemType Directory -Force $dir | Out-Null
    [IO.File]::WriteAllText((Join-Path $dir 'settings.json'), $json, $script:Utf8)
    $dir
}

try {
    # The setting found on 2026-11-14: one model at 400k.
    $before = '{"theme":"dark-ansi","modelSettings":{"claude-opus-5-5":{"autoCompactWindow":400000},"claude-sonnet-5-5":{"autoCompactWindow":150000}}}'
    $big = New-Settings 'big' $before
    Check (-not (Test-CompactWindow $big)) 'a 400k window is seen as too large'
    Check (@(Test-Setup (Split-Path $PSScriptRoot) $big | Where-Object { $_ -like '*compacting*' }).Count -eq 1) 'the setup check reports it'
    Install-CompactWindow $big | Out-Null
    $s = Read-Settings $big
    Check ($s.modelSettings.'claude-opus-5-5'.autoCompactWindow -eq 200000) 'it is lowered to 200k'
    Check ($s.modelSettings.'claude-sonnet-5-5'.autoCompactWindow -eq 150000) 'a smaller window is left as it is'
    Check ($s.theme -eq 'dark-ansi') 'other settings are kept'
    Check ([IO.File]::ReadAllText((Join-Path $big 'settings.json.pre-sync'), $script:Utf8) -eq $before) 'the file before the change is kept as settings.json.pre-sync'

    # A second run changes nothing.
    $after = [IO.File]::ReadAllText((Join-Path $big 'settings.json'), $script:Utf8)
    $said = Install-CompactWindow $big
    Check ($said -like '*already*' -and [IO.File]::ReadAllText((Join-Path $big 'settings.json'), $script:Utf8) -eq $after) 'a second run leaves the file as it is'
    Check (-not (Test-Path (Join-Path $big 'settings.json.pre-sync-2'))) 'a second run keeps no second copy'

    # No modelSettings at all, and no settings file: nothing to lower.
    $plain = New-Settings 'plain' '{"theme":"dark-ansi"}'
    Check (Test-CompactWindow $plain) 'no modelSettings is fine'
    $none = Join-Path $root 'none'; New-Item -ItemType Directory -Force $none | Out-Null
    Check (Test-CompactWindow $none) 'no settings file is fine'
}
finally {
    if ($root.StartsWith($env:TEMP) -and (Test-Path $root)) { Remove-Item -Recurse -Force $root }
}

if ($failed) { Write-Output "$failed check(s) failed"; exit 1 }
Write-Output 'all passed'
