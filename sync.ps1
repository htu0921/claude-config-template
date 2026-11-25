# Pulls other machines' changes, builds the house rules into the repo and into
# ~/.claude and ~/.codex, then commits and pushes this machine's changes.
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$claude = Join-Path $env:USERPROFILE '.claude'
. (Join-Path $PSScriptRoot 'rules.ps1')

Save-RulesEdit $PSScriptRoot $claude
# A fetch, then a rebase onto the upstream branch - not git pull, which takes
# what to rebase onto from FETCH_HEAD. Another fetch at the same moment (another tool's
# update check, say) added its lines there, and the pull failed
# with "Cannot fast-forward to multiple branches".
git fetch --quiet
if ($LASTEXITCODE -ne 0) { throw 'pull failed; resolve it in this folder, then run again' }
git rebase --autostash '@{u}'
if ($LASTEXITCODE -ne 0) { throw 'pull failed; resolve it in this folder, then run again' }
# The pull may have brought a new rules.ps1: load it again, so this run already
# builds the rules the new way. Then build them before the commit, so the repo's
# built CLAUDE.md and codex/AGENTS.md go up with the sources they came from.
. (Join-Path $PSScriptRoot 'rules.ps1')
Install-Rules $PSScriptRoot $claude
git add -A
git diff --cached --quiet
if ($LASTEXITCODE -ne 0) {
    git commit -m "Sync from $env:COMPUTERNAME"
}
# Push whatever the upstream lacks, a commit made by hand included (rules.ps1).
Push-IfAhead $PSScriptRoot
