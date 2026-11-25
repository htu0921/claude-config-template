# Checks the house rules build (rules.ps1): RULES.md and tools/<tool>.md go into
# each tool's built file, and an edit made to a built file goes back to the
# source it belongs in. Runs on a throwaway repo and homes in %TEMP%, never on
# this repo or ~/.claude, except the last check, which only reads this repo.
# Exit 0 = all passed.
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\rules-build.tests.ps1

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\rules.ps1')
$root = Join-Path $env:TEMP ('rules-test-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$failed = 0
$savedCodexHome = $env:CODEX_HOME
function Check([bool]$ok, [string]$what) {
    if ($ok) { Write-Output "ok   $what" } else { Write-Output "FAIL $what"; $script:failed++ }
}
# Git's notes on stderr would stop the script under 'Stop' in Windows PowerShell.
function Invoke-TestGit {
    $ErrorActionPreference = 'Continue'
    git -c user.name=test -c user.email=test@example.invalid -c core.autocrlf=false @args 2>$null | Out-Null
}
function Put($path, $text) {
    New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
    [IO.File]::WriteAllText($path, $text, $script:Utf8)
}
function Get($path) { [IO.File]::ReadAllText($path, $script:Utf8) }
function Get-RulesProblems { @(Test-Setup $repo $claude | Where-Object { $_ -like '*built from*' }) }

try {
    $repo = Join-Path $root 'repo'; $claude = Join-Path $root 'home\.claude'
    $env:CODEX_HOME = Join-Path $root 'home\.codex'
    $shared = "## Shared`n`nEvery tool does this.`n"
    $claudeTpl = "# Claude`n`n{{RULES}}`n`n## Claude only`n`nUse get_usage.`n"
    $codexTpl = "# Codex`n`n{{RULES}}`n`n## Codex only`n`nUse the usage tool.`n"
    $legacy = "# House rules (all Claude Code work)`n`nThe hand-kept copy.`n"
    Put "$repo\RULES.md" $shared
    Put "$repo\tools\claude.md" $claudeTpl
    Put "$repo\tools\codex.md" $codexTpl
    Put "$repo\CLAUDE.md" $legacy
    Put "$repo\.gitattributes" "* text=auto eol=lf`n"
    New-Item -ItemType Directory -Force "$repo\memory" | Out-Null
    Invoke-TestGit init --quiet $repo
    Invoke-TestGit -C $repo add -A; Invoke-TestGit -C $repo commit --quiet -m one
    $rc, $rx = Get-RuleCopies $repo $claude

    # Build and take apart.
    $built = Build-Rules $repo $rc
    $parts = Split-Rules $built
    Check ($built.Contains("$script:SharedStart`n$shared$script:SharedEnd")) 'RULES.md goes between the markers'
    Check ($built.StartsWith("# Claude`n") -and $built.EndsWith("Use get_usage.`n")) "the tool's own part is around it"
    Check ($parts.Shared -eq $shared -and $parts.Template -eq $claudeTpl) 'a built file takes apart into its two sources'
    Check ($null -eq (Split-Rules ($built.Replace($script:SharedEnd, '')))) 'a built file without its end marker does not take apart'

    Put "$repo\tools\bad.md" "# Bad`n`nno slot`n"
    $said = ''
    try { Build-Rules $repo ([pscustomobject]@{ Template = 'tools/bad.md' }) | Out-Null } catch { $said = "$_" }
    Check ($said -like '*tools/bad.md*{{RULES}}*') 'a tool part without {{RULES}} is refused, by name'
    Remove-Item "$repo\tools\bad.md"

    # A copy from before the build, committed as CLAUDE.md: out of date, not an edit.
    Put $rc.Installed ("<!-- Copied from C:\x\CLAUDE.md by claude-config. -->`n" + $legacy)
    $said = @(Save-RulesEdit $repo $claude) -join "`n"
    Check ($said -eq '' -and -not (Test-Path "$($rc.Installed).unsynced")) 'a copy from before the build is left for the build'

    # Install: built into the repo and into each home.
    Install-Rules $repo $claude | Out-Null
    Check ((Read-RulesCopy $rc.Installed) -eq $built) "Claude's home gets the built file"
    Check ((Read-RulesCopy "$repo\codex\AGENTS.md") -eq (Build-Rules $repo $rx)) 'the repo keeps the built Codex file'
    Check ((Get-RulesProblems).Count -eq 0) 'the check finds every built file in place'
    Invoke-TestGit -C $repo add -A; Invoke-TestGit -C $repo commit --quiet -m built

    # A machine on the old sync.ps1 copies the repo's built file under its own header.
    $kept = Get $rc.Installed
    Put $rc.Installed ("<!-- Copied from C:\x\CLAUDE.md by claude-config. -->`n" + (Get "$repo\CLAUDE.md"))
    Check ((Read-RulesCopy $rc.Installed) -eq $built -and (Get-RulesProblems).Count -eq 0) 'a copy made by the old sync.ps1 reads as the built file'
    Put $rc.Installed $kept

    # An edit to the shared part, in Claude's home, goes into RULES.md and so to Codex.
    Put $rc.Installed ($kept.Replace('Every tool does this.', 'Every tool does this, and that.'))
    Save-RulesEdit $repo $claude | Out-Null
    Check ((Get "$repo\RULES.md") -eq "## Shared`n`nEvery tool does this, and that.`n") 'an edit to the shared part goes into RULES.md'
    Check ((Get "$repo\tools\claude.md") -eq $claudeTpl) "and leaves Claude's own part alone"
    Install-Rules $repo $claude | Out-Null
    Check ((Get $rx.Installed).Contains('this, and that.')) "Codex's home gets it at the next build"
    Invoke-TestGit -C $repo add -A; Invoke-TestGit -C $repo commit --quiet -m shared

    # An edit to a tool's own part, in the repo's built file, goes into its tools/<tool>.md.
    Put "$repo\codex\AGENTS.md" ((Get "$repo\codex\AGENTS.md").Replace('Use the usage tool.', 'Use the usage tool first.'))
    Save-RulesEdit $repo $claude | Out-Null
    Check ((Get "$repo\tools\codex.md") -eq $codexTpl.Replace('tool.', 'tool first.')) "an edit to Codex's own part goes into tools/codex.md"
    Install-Rules $repo $claude | Out-Null
    Invoke-TestGit -C $repo add -A; Invoke-TestGit -C $repo commit --quiet -m codex

    # Rules changed in the repo since a home was built: out of date, not an edit.
    $before = Get $rc.Installed
    Put "$repo\RULES.md" "## Shared`n`nChanged in the repo.`n"
    Invoke-TestGit -C $repo commit --quiet -am repo
    Save-RulesEdit $repo $claude | Out-Null
    Check ((Get "$repo\RULES.md") -eq "## Shared`n`nChanged in the repo.`n") 'an out-of-date home does not undo a rules change'
    Install-Rules $repo $claude | Out-Null
    Check ((Get $rc.Installed) -ne $before -and (Get-RulesProblems).Count -eq 0) 'the next build brings the home up to date'

    # Both edited: neither wins, the home's file is kept beside it.
    Put "$repo\RULES.md" "## Shared`n`nEdited in the repo, not committed.`n"
    Put $rc.Installed ((Get $rc.Installed).Replace('Changed in the repo.', 'Edited in the home.'))
    $said = @(Save-RulesEdit $repo $claude) -join "`n"
    Check ((Test-Path "$($rc.Installed).unsynced") -and $said -like '*RULES.md*merge it by hand*') 'both edited: the home file is kept as .unsynced'
    Check ((Get "$repo\RULES.md") -eq "## Shared`n`nEdited in the repo, not committed.`n") "and the repo's edit stays"
    Remove-Item "$($rc.Installed).unsynced"
    Invoke-TestGit -C $repo checkout --quiet -- RULES.md
    Install-Rules $repo $claude | Out-Null

    # Markers gone: the edit cannot be split, so it is kept, never guessed at.
    Put $rc.Installed ((Get $rc.Installed).Replace($script:SharedStart, '').Replace('Changed in', 'Edited in'))
    $said = @(Save-RulesEdit $repo $claude) -join "`n"
    Check ((Test-Path "$($rc.Installed).unsynced") -and $said -like '*markers are gone*') 'an edit with its markers gone is kept as .unsynced'
    Check ((Get "$repo\RULES.md") -eq "## Shared`n`nChanged in the repo.`n") 'and RULES.md is untouched'

    # This repo: its built files are up to date with their sources.
    $real = Split-Path $PSScriptRoot
    foreach ($r in Get-RuleCopies $real $claude) {
        Check ((Read-RulesCopy (Join-Path $real $r.Output)) -eq (Build-Rules $real $r)) "this repo's $($r.Output) is built from RULES.md and $($r.Template) (run sync.ps1 if not)"
    }
}
finally {
    $env:CODEX_HOME = $savedCodexHome
    if ($root.StartsWith($env:TEMP) -and (Test-Path $root)) { Remove-Item -Recurse -Force $root }
}

if ($failed) { Write-Output "$failed check(s) failed"; exit 1 }
Write-Output 'all passed'
