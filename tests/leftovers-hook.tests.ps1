# Checks Install-LeftoversHook (rules.ps1) on throwaway settings files in %TEMP%,
# never on ~/.claude. Exit 0 = all passed.
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\leftovers-hook.tests.ps1

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\rules.ps1')
$root = Join-Path $env:TEMP ('hook-test-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$failed = 0
function Check([bool]$ok, [string]$what) {
    if ($ok) { Write-Output "ok   $what" } else { Write-Output "FAIL $what"; $script:failed++ }
}

try {
    # No settings file yet: one is made with the hook.
    $empty = Join-Path $root 'empty'; New-Item -ItemType Directory -Force $empty | Out-Null
    Install-LeftoversHook $empty | Out-Null
    Check (Test-LeftoversHook $empty) 'a missing settings file gets the hook'

    # A settings file with keys and another SessionStart hook of its own.
    $own = Join-Path $root 'own'; New-Item -ItemType Directory -Force $own | Out-Null
    $before = '{"theme":"dark-ansi","autoMode":{"environment":["a ' + [char]0x2014 + ' b"]},"hooks":{"SessionStart":[{"matcher":"resume","hooks":[{"type":"command","command":"echo hi"}]}]}}'
    [IO.File]::WriteAllText((Join-Path $own 'settings.json'), $before, $script:Utf8)
    Check (-not (Test-LeftoversHook $own)) 'a file without the hook is seen as missing it'
    Install-LeftoversHook $own | Out-Null
    $s = Read-Settings $own
    Check (Test-LeftoversHook $own) 'the hook is added'
    Check ($s.theme -eq 'dark-ansi') 'other settings are kept'
    Check ($s.autoMode.environment[0] -eq ('a ' + [char]0x2014 + ' b')) 'non-ASCII text survives'
    Check (@($s.autoMode.environment).Count -eq 1 -and $s.autoMode.environment -is [array]) 'a one-item list stays a list'
    Check (@($s.hooks.SessionStart | Where-Object { $_.matcher -eq 'resume' }).Count -eq 1) 'its own SessionStart hook is kept'
    Check ([IO.File]::ReadAllText((Join-Path $own 'settings.json.pre-sync'), $script:Utf8) -eq $before) 'the file before the change is kept as settings.json.pre-sync'

    # A second run changes nothing.
    $after = [IO.File]::ReadAllText((Join-Path $own 'settings.json'), $script:Utf8)
    $said = Install-LeftoversHook $own
    Check ($said -like '*already set*' -and [IO.File]::ReadAllText((Join-Path $own 'settings.json'), $script:Utf8) -eq $after) 'a second run leaves the file as it is'
    Check (-not (Test-Path (Join-Path $own 'settings.json.pre-sync-2'))) 'a second run keeps no second copy'
}
finally {
    if ($root.StartsWith($env:TEMP) -and (Test-Path $root)) { Remove-Item -Recurse -Force $root }
}

if ($failed) { Write-Output "$failed check(s) failed"; exit 1 }
Write-Output 'all passed'
