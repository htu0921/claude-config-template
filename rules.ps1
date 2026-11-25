# The house rules have one source: RULES.md holds what every AI tool follows,
# and tools/<tool>.md holds one tool's own part around a {{RULES}} line, where
# RULES.md goes. Each tool's rules file is built from the two, never edited
# twice by hand (2026-11-16: two hand-kept copies had to be changed together).
#
# The built file is copied into each tool's home (~/.claude/CLAUDE.md,
# ~/.codex/AGENTS.md), not linked or imported. Claude Code skips a symlinked
# ~/.claude/CLAUDE.md, and an @import of a file outside the session's folder,
# in some sessions (Cowork on the desktop); Codex has no import; symlinks need
# admin on Windows. A plain file loads in every session.
#
# The built file is also kept in the repo, at the path the hand-kept copy had
# (CLAUDE.md, codex/AGENTS.md): a machine still running the sync.ps1 from
# before the build copies that path into its home after it pulls, so it gets
# the built rules too, with no failed sync.
#
# Every built file starts with one HTML comment naming its sources, and wraps
# RULES.md's text in two marker comments, so an edit made to any built file is
# carried back to the source it belongs in. Claude Code strips block comments
# before the rules reach the model. Used by setup.ps1 and sync.ps1.

$script:Utf8 = New-Object System.Text.UTF8Encoding($false)
$script:SharedSource = 'RULES.md'
$script:Slot = '{{RULES}}'
$script:SharedStart = '<!-- What every AI tool follows, from RULES.md: -->'
$script:SharedEnd = '<!-- End of RULES.md. -->'
# A built file's first line starts with the first; the second is the header
# of the copies made before the build, which a machine on the old sync.ps1
# puts above the built file's own header.
$script:HeaderPrefixes = @('<!-- Built from claude-config', '<!-- Copied from ')

# Each AI tool's part, where its built file is kept in the repo, and where it
# is installed. A new tool is one more line here and its tools/<tool>.md.
# Codex's home is CODEX_HOME when set, else .codex beside .claude.
function Get-RuleCopies($repo, $claude) {
    $codex = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path (Split-Path $claude) '.codex' }
    @(
        [pscustomobject]@{ Template = 'tools/claude.md'; Output = 'CLAUDE.md';       Installed = Join-Path $claude 'CLAUDE.md' }
        [pscustomobject]@{ Template = 'tools/codex.md';  Output = 'codex/AGENTS.md'; Installed = Join-Path $codex 'AGENTS.md' }
    )
}

# Both built files of a tool: the one in its home, then the one in the repo.
function Get-BuiltPaths($repo, $r) { @($r.Installed, (Join-Path $repo $r.Output)) }

function Get-RulesHeader($r) {
    "<!-- Built from claude-config's RULES.md and $($r.Template) by sync.ps1. Edit those, or this file: sync.ps1 carries an edit here back. -->"
}

function Test-OurHeader($text) {
    foreach ($p in $script:HeaderPrefixes) { if ($text.StartsWith($p)) { return $true } }
    $false
}

function Read-RepoText($repo, $source) {
    $path = Join-Path $repo $source
    if (-not (Test-Path $path)) { return $null }
    [IO.File]::ReadAllText($path, $script:Utf8)
}

# The rules a tool gets: its tools/<tool>.md with RULES.md, between the two
# markers, in place of the {{RULES}} line.
function Build-Rules($repo, $r) {
    $template = Read-RepoText $repo $r.Template
    if ($null -eq $template) { throw "house rules: $($r.Template) is missing" }
    $slots = [regex]::Matches($template, '(?m)^' + [regex]::Escape($script:Slot) + '\r?$')
    if ($slots.Count -ne 1) { throw "house rules: $($r.Template) must hold $script:Slot once, on a line of its own" }
    $shared = Read-RepoText $repo $script:SharedSource
    if ($null -eq $shared) { throw "house rules: $script:SharedSource is missing" }
    if (-not $shared.EndsWith("`n")) { $shared += "`n" }
    $at = $slots[0].Index
    $template.Substring(0, $at) + $script:SharedStart + "`n" + $shared + $script:SharedEnd +
        $template.Substring($at + $script:Slot.Length)
}

# A built file's text taken apart into its two sources: Shared (RULES.md) and
# Template (tools/<tool>.md). $null when its markers are missing or doubled.
function Split-Rules($text) {
    $start = $script:SharedStart + "`n"
    $i = $text.IndexOf($start)
    if ($i -lt 0 -or $text.IndexOf($start, $i + 1) -ge 0) { return $null }
    $from = $i + $start.Length
    $j = $text.IndexOf($script:SharedEnd, $from)
    if ($j -lt 0 -or $text.IndexOf($script:SharedEnd, $j + 1) -ge 0) { return $null }
    [pscustomobject]@{
        Shared   = $text.Substring($from, $j - $from)
        Template = $text.Substring(0, $i) + $script:Slot + $text.Substring($j + $script:SharedEnd.Length)
    }
}

# A built file's text without its header lines; $null when there is none.
function Read-RulesCopy($path) {
    if (-not (Test-Path $path)) { return $null }
    $text = [IO.File]::ReadAllText($path, $script:Utf8)
    while (Test-OurHeader $text) {
        $end = $text.IndexOf("`n")
        $text = if ($end -lt 0) { '' } else { $text.Substring($end + 1) }
    }
    $text
}

# A name beside $path that is not taken yet: x.pre-sync, x.pre-sync-2, ...
function Get-FreeName($path, $suffix = 'pre-sync') {
    $name = "$path.$suffix"; $n = 2
    while (Test-Path $name) { $name = "$path.$suffix-$n"; $n++ }
    $name
}

# Builds each tool's rules into the repo and into the tool's home. A file in
# the home that is neither one of ours nor the old one-line import is someone's
# own rules: it is kept beside it, never overwritten.
function Install-Rules($repo, $claude) {
    foreach ($r in Get-RuleCopies $repo $claude) {
        $text = (Get-RulesHeader $r) + "`n" + (Build-Rules $repo $r)
        $output = Join-Path $repo $r.Output
        New-Item -ItemType Directory -Force (Split-Path $output) | Out-Null
        if ((Read-RepoText $repo $r.Output) -ne $text) {
            [IO.File]::WriteAllText($output, $text, $script:Utf8)
            "house rules: built $($r.Output)"
        }
        $copy = $r.Installed
        New-Item -ItemType Directory -Force (Split-Path $copy) | Out-Null
        if (Test-Path $copy) {
            $old = [IO.File]::ReadAllText($copy, $script:Utf8)
            $ours = (Test-OurHeader $old) -or $old.Trim() -match '^@\S*claude-config/CLAUDE\.md$'
            if (-not $ours) {
                $kept = Get-FreeName $copy
                Move-Item $copy $kept
                "house rules: this machine's own $(Split-Path $copy -Leaf) kept as $(Split-Path $kept -Leaf)"
            }
        }
        [IO.File]::WriteAllText($copy, $text, $script:Utf8)
        "house rules: copied to $copy"
    }
}

# Whether $text is a version of $source the repo has committed. Compared by
# blob id, so no file text passes through the console's encoding.
function Test-CommittedText($repo, $source, $text) {
    $tmp = [IO.Path]::GetTempFileName()
    try {
        [IO.File]::WriteAllText($tmp, $text, $script:Utf8)
        $id = git -C $repo hash-object --no-filters -- $tmp
    } finally { Remove-Item $tmp }
    $ids = git -C $repo log --raw --no-abbrev --format= -- $source |
        Where-Object { $_.StartsWith(':') } | ForEach-Object { ($_ -split '\s+')[3] }
    @($ids) -contains $id
}

# Before a pull: an edit made to a built file, in a tool's home or in the repo,
# goes back into the source it belongs in (RULES.md or tools/<tool>.md), so the
# pull and the build that follows do not throw it away. A part whose text the
# repo has committed before is not an edit: it is out of date, because the
# rules were changed in the repo since it was built, and carrying it back would
# undo that change; Install-Rules rebuilds it. When the source has uncommitted
# changes too, neither wins: the built file is saved beside it. A file without
# our header is left for Install-Rules to keep aside.
function Save-RulesEdit($repo, $claude) {
    foreach ($r in Get-RuleCopies $repo $claude) {
        $built = Build-Rules $repo $r
        foreach ($path in Get-BuiltPaths $repo $r) {
            if (-not (Test-Path $path) -or -not (Test-OurHeader ([IO.File]::ReadAllText($path, $script:Utf8)))) { continue }
            $text = Read-RulesCopy $path
            if ($text -eq $built) { continue }
            $parts = Split-Rules $text
            if ($null -eq $parts) {
                # A copy from before the build, which the repo committed as
                # its CLAUDE.md or codex/AGENTS.md: out of date, not an edit.
                if (Test-CommittedText $repo $r.Output $text) { continue }
                $kept = Get-FreeName $path 'unsynced'
                Copy-Item $path $kept
                "house rules: $path was edited but its RULES.md markers are gone, so the edit cannot be carried back; it is kept as $(Split-Path $kept -Leaf) - merge it by hand"
                continue
            }
            $edits = @(
                [pscustomobject]@{ Source = $script:SharedSource; Text = $parts.Shared }
                [pscustomobject]@{ Source = $r.Template;          Text = $parts.Template }
            ) | Where-Object {
                $_.Text -ne (Read-RepoText $repo $_.Source) -and -not (Test-CommittedText $repo $_.Source $_.Text)
            }
            if (-not $edits) { continue }
            $clash = $edits | Where-Object { git -C $repo diff --quiet -- $_.Source; $LASTEXITCODE -ne 0 }
            if ($clash) {
                $kept = Get-FreeName $path 'unsynced'
                Copy-Item $path $kept
                "house rules: both $path and the repo's $(@($clash.Source) -join ' and ') were edited; the file is kept as $(Split-Path $kept -Leaf) - merge it by hand"
                continue
            }
            foreach ($e in $edits) {
                [IO.File]::WriteAllText((Join-Path $repo $e.Source), $e.Text, $script:Utf8)
                "house rules: the edit made in $path goes into $($e.Source)"
            }
            $built = Build-Rules $repo $r
        }
    }
}

# Whether this machine is set up: each built file matches its sources, and
# every memory folder is a junction into the repo. Returns the problems, none
# when it is.
function Test-Setup($repo, $claude) {
    $problems = @()
    foreach ($r in Get-RuleCopies $repo $claude) {
        $built = Build-Rules $repo $r
        foreach ($path in Get-BuiltPaths $repo $r) {
            if ((Read-RulesCopy $path) -ne $built) {
                $problems += "$path is missing or is not built from RULES.md and $($r.Template)"
            }
        }
    }
    if (-not (Test-LeftoversHook $claude)) {
        $problems += "$(Join-Path $claude 'settings.json') has no SessionStart hook for leftover branches"
    }
    if (-not (Test-CompactWindow $claude)) {
        $problems += "$(Join-Path $claude 'settings.json') lets a session grow past $script:CompactWindowCap tokens before compacting"
    }
    foreach ($dir in Get-ChildItem (Join-Path $repo 'memory') -Directory) {
        $link = Get-Item (Join-Path $claude "projects\$($dir.Name)\memory") -ErrorAction SilentlyContinue
        if (-not $link -or $link.LinkType -ne 'Junction' -or -not ($link.Target -contains $dir.FullName)) {
            $problems += "memory for $($dir.Name) is not linked to the repo"
        } elseif (-not (Test-Path (Join-Path $link.FullName 'MEMORY.md'))) {
            $problems += "memory for $($dir.Name) is linked but its MEMORY.md cannot be read through the link"
        }
    }
    $problems
}

# A SessionStart hook in ~/.claude/settings.json: in any repository with a
# scripts/leftovers.ps1, it lists branches and worktrees that hold nothing
# main lacks, so Claude names them to the user. It sits in the user settings
# because Claude Code reads a repo's .claude/settings.json only from the folder
# a session starts in, and a session may start in any of a repo's subfolders.
# Everything else in the file is kept; the file
# before the change is kept beside it as settings.json.pre-sync.
$script:LeftoversHook = '$t = git rev-parse --show-toplevel 2>$null; if ($t -and (Test-Path "$t/scripts/leftovers.ps1")) { powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$t/scripts/leftovers.ps1" -Repo $t }; exit 0'

function Read-Settings($claude) {
    $path = Join-Path $claude 'settings.json'
    if (-not (Test-Path $path)) { return $null }
    [IO.File]::ReadAllText($path, $script:Utf8) | ConvertFrom-Json
}

function Test-LeftoversHook($claude) {
    $s = Read-Settings $claude
    if (-not $s -or -not $s.hooks -or -not $s.hooks.SessionStart) { return $false }
    foreach ($group in @($s.hooks.SessionStart)) {
        foreach ($h in @($group.hooks)) { if ("$($h.command)" -like '*scripts/leftovers.ps1*') { return $true } }
    }
    $false
}

function Install-LeftoversHook($claude) {
    if (Test-LeftoversHook $claude) { "hook: leftover branches already set"; return }
    $path = Join-Path $claude 'settings.json'
    $s = Read-Settings $claude
    if ($s) { Copy-Item $path (Get-FreeName $path) } else { $s = [pscustomobject]@{} }
    if (-not $s.hooks) { $s | Add-Member -NotePropertyName hooks -NotePropertyValue ([pscustomobject]@{}) -Force }
    $group = [pscustomobject]@{
        matcher = 'startup'
        hooks   = @([pscustomobject]@{ type = 'command'; shell = 'powershell'; command = $script:LeftoversHook })
    }
    $groups = @(@($s.hooks.SessionStart) | Where-Object { $_ }) + $group
    $s.hooks | Add-Member -NotePropertyName SessionStart -NotePropertyValue $groups -Force
    [IO.File]::WriteAllText($path, ($s | ConvertTo-Json -Depth 32), $script:Utf8)
    "hook: leftover branches added to $path"
}

# Pushes when the branch holds commits its upstream lacks: sync.ps1's own
# "Sync from" commit, or one made by hand in the repo since the last sync
# (2026-11-14: a hand-made rules commit stayed local, because the push ran
# only after sync.ps1 had committed something itself).
function Push-IfAhead($repo) {
    $ahead = [int](git -C $repo rev-list --count '@{u}..HEAD')
    if ($LASTEXITCODE -ne 0) { throw 'could not compare with the upstream branch' }
    if ($ahead -eq 0) { return "push: nothing to push" }
    git -C $repo push --quiet
    if ($LASTEXITCODE -ne 0) { throw 'push failed; run sync.ps1 again once the network is back' }
    "push: $ahead commit(s) pushed"
}

# How large a session grows before Claude Code compacts it. Every turn re-reads
# the whole conversation, so a session left to grow to 400k tokens costs more and
# answers more slowly on every turn (2026-11-14: a model's autoCompactWindow had
# been set to 400000). A model whose window is above the cap is lowered to it;
# a smaller one is left as it is.
$script:CompactWindowCap = 200000

function Get-OversizedCompactWindows($claude) {
    $s = Read-Settings $claude
    if (-not $s -or -not $s.modelSettings) { return @() }
    @($s.modelSettings.PSObject.Properties | Where-Object {
        $_.Value -and $_.Value.PSObject.Properties['autoCompactWindow'] -and [long]$_.Value.autoCompactWindow -gt $script:CompactWindowCap
    } | ForEach-Object { $_.Name })
}

function Test-CompactWindow($claude) { (Get-OversizedCompactWindows $claude).Count -eq 0 }

function Install-CompactWindow($claude) {
    $models = Get-OversizedCompactWindows $claude
    if (-not $models.Count) { "compact window: at most $script:CompactWindowCap already"; return }
    $path = Join-Path $claude 'settings.json'
    $s = Read-Settings $claude
    Copy-Item $path (Get-FreeName $path)
    foreach ($m in $models) { $s.modelSettings.$m.autoCompactWindow = $script:CompactWindowCap }
    [IO.File]::WriteAllText($path, ($s | ConvertTo-Json -Depth 32), $script:Utf8)
    "compact window: lowered to $script:CompactWindowCap for $($models -join ', ')"
}
