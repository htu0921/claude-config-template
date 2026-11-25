# Checks Push-IfAhead (rules.ps1) on a throwaway remote and clone in %TEMP%,
# never on this repo. Exit 0 = all passed.
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\push-if-ahead.tests.ps1

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\rules.ps1')
$root = Join-Path $env:TEMP ('push-test-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$failed = 0
function Check([bool]$ok, [string]$what) {
    if ($ok) { Write-Output "ok   $what" } else { Write-Output "FAIL $what"; $script:failed++ }
}
# Git's notes on stderr would stop the script under 'Stop' in Windows PowerShell.
function Invoke-TestGit {
    $ErrorActionPreference = 'Continue'
    git -c user.name=test -c user.email=test@example.invalid @args 2>$null | Out-Null
}

try {
    $remote = Join-Path $root 'remote.git'; $clone = Join-Path $root 'clone'
    Invoke-TestGit init --quiet --bare $remote
    Invoke-TestGit clone --quiet $remote $clone
    Set-Content (Join-Path $clone 'a.txt') 'one'
    Invoke-TestGit -C $clone add a.txt; Invoke-TestGit -C $clone commit --quiet -m one; Invoke-TestGit -C $clone push --quiet -u origin HEAD

    # Up to date: nothing is pushed.
    Check ((Push-IfAhead $clone) -like '*nothing*') 'an up-to-date branch pushes nothing'

    # A commit made by hand, not by sync.ps1: it is pushed.
    Set-Content (Join-Path $clone 'a.txt') 'two'
    Invoke-TestGit -C $clone commit --quiet -am 'by hand'
    $said = Push-IfAhead $clone
    $local = git -C $clone rev-parse HEAD
    $pushed = git -C $remote rev-parse HEAD
    Check ($said -like '*1 commit*') 'a hand-made commit is reported as pushed'
    Check ($local -eq $pushed) 'the remote now has the hand-made commit'
}
finally {
    if ($root.StartsWith($env:TEMP) -and (Test-Path $root)) { Remove-Item -Recurse -Force $root }
}

if ($failed) { Write-Output "$failed check(s) failed"; exit 1 }
Write-Output 'all passed'
