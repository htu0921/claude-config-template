# Sets this machine's Claude Code and Codex up with the house rules, and Claude
# Code with the memory, in this repo, then checks that it worked. Safe to run again. Anything it replaces is
# kept beside it as *.pre-sync (then -2, -3, ...), never overwritten.
# Exit code 1: a check failed, and the last lines say which.
$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot
$claude = Join-Path $env:USERPROFILE '.claude'
New-Item -ItemType Directory -Force $claude | Out-Null
. (Join-Path $repo 'rules.ps1')

# House rules: built from RULES.md and each tool's part into the repo, and
# copied into Claude Code's and Codex's homes (rules.ps1 says why).
Install-Rules $repo $claude

# The SessionStart hook that lists leftover branches (rules.ps1 says why).
Install-LeftoversHook $claude

# Sessions compact by 200k tokens at most (rules.ps1 says why).
Install-CompactWindow $claude

# Memory: each memory\<project key> folder is junctioned into ~/.claude/projects.
# The key is the checkout path (C:\dev\app -> C--dev-app), so the
# repos must sit at the same paths on every machine.
foreach ($dir in Get-ChildItem (Join-Path $repo 'memory') -Directory) {
    $project = Join-Path $claude "projects\$($dir.Name)"
    $link = Join-Path $project 'memory'
    New-Item -ItemType Directory -Force $project | Out-Null
    $item = Get-Item $link -ErrorAction SilentlyContinue
    if ($item -and $item.LinkType -eq 'Junction' -and $item.Target -contains $dir.FullName) {
        "memory: $($dir.Name) already linked"
        continue
    }
    if ($item) {
        $kept = Get-FreeName $link
        Move-Item $link $kept
        "memory: $($dir.Name) this machine's own memory kept as $(Split-Path $kept -Leaf); compare it with the repo copy"
    }
    New-Item -ItemType Junction -Path $link -Target $dir.FullName | Out-Null
    "memory: $($dir.Name) linked"
}

$problems = @(Test-Setup $repo $claude)
if ($problems.Count) {
    foreach ($p in $problems) { "CHECK FAILED: $p" }
    exit 1
}
"check: house rules, memory and the leftovers hook are in place. Start a new Claude session to load them; sessions already open keep what they started with."
