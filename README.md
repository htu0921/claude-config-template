# claude-config

House rules for every AI tool, written once, on every machine.

Your house rules for Claude Code, Codex and any other AI tool, and Claude's memory, shared
between machines. Keep your copy private: its memory is yours. A repository's own rules are not here: they are in its
`AGENTS.md` files, which both agents read.

## Start your own

1. On GitHub, **Use this template** › **Create a new repository**, and make it private.
2. Clone it anywhere, and run `.\setup.ps1` in it (Windows PowerShell). Your AI tools
   now load `RULES.md` in every project.
3. Make the rules yours: edit `RULES.md` for every AI tool, `tools/<tool>.md` for one.
   Run `.\sync.ps1` after an edit, and on each machine before starting and after finishing.

A part of a rules file between `<!-- personal -->` and `<!-- /personal -->` lines is
yours alone: it loads for you like any rule, and is left out when the rules are shared
as a template.

## What is here

- `RULES.md` — the house rules every AI tool follows, in every project. The one
  place to change a rule that is not one tool's own.
- `tools/<tool>.md` — one tool's own part (`claude.md`, `codex.md`): its title, its
  usage and model rules, and a `{{RULES}}` line where `RULES.md` goes. A new AI tool
  is one more file here and one line in `Get-RuleCopies` (`rules.ps1`).
- `CLAUDE.md`, `codex/AGENTS.md` — each tool's rules as built from those two, kept
  here so GitHub can show them, and so a machine still on an older
  `sync.ps1` gets them. Never edited by hand: an edit here is carried back to its
  source, as from a home copy. Copied to `~/.claude/CLAUDE.md` and
  `~/.codex/AGENTS.md` (`CODEX_HOME` when set) as real files: Claude Code skips a
  symlinked or imported one in some sessions, such as Cowork on the desktop, and
  Codex has no import. Each built file's first line names its sources.
- `memory/<project key>/` — Claude's memory for each repo, junctioned into
  `~/.claude/projects/<project key>/memory`. A rule a repository's `AGENTS.md`
  already states is not kept here too.
- `rules.ps1` — the build, the copies, carrying an edit made to one back, and the
  check. `tests/rules-build.tests.ps1` checks the build and the carrying back on a
  throwaway repo, and that this repo's built files are up to date.

- `~/.claude/settings.json` is not copied (Claude Code rewrites it in place), but
  `setup.ps1` adds one SessionStart hook to it and keeps the rest: in a repository
  with `scripts/leftovers.ps1`, it lists branches and worktrees that
  hold nothing `main` lacks. It also lowers any model's `autoCompactWindow` above
  200k tokens to 200k, so sessions compact before every turn gets slow and costly.
  `.credentials.json` is never synced.
- `tests/leftovers-hook.tests.ps1` and `tests/compact-window.tests.ps1` check those
  steps on throwaway settings files.

## New machine

1. Sign in to Claude Code.
2. Clone your copy of this repo, and your other repos to the same paths as on the
   first machine. A memory folder's project key comes from its repo's path, so a repo
   at `C:\dev\app` must be at `C:\dev\app` there too.
3. Run `.\setup.ps1`. It ends with `check: ...` when everything is in place, or
   `CHECK FAILED: ...` and exit code 1.

Then start a new Claude or Codex session: one already open keeps the rules it
started with.

## Day to day

Run `.\sync.ps1` on a machine before starting and after finishing. It carries an
edit made in any built file back into `RULES.md` or the tool's part (whichever the
edited lines came from), pulls, builds the rules into the repo and the homes, then
commits and pushes. A part whose text the
repo has committed before is only out of date, never carried back, so a rules change
committed in the repo survives a sync on a machine that has not refreshed yet. An
edit that cannot be carried back (its `RULES.md` markers deleted, or the source
edited too) is kept beside the file as `*.unsynced` to merge by hand. A `~/.codex/AGENTS.md` that
claude-config did not write is kept beside it as `AGENTS.md.pre-sync`, never
carried into the repo.

