# House rules (all Claude Code work)

Personal rules, for every project. A repository's own rules are in its `AGENTS.md`
files, which Codex reads too; a `CLAUDE.md` beside each imports it. These personal
rules are built by claude-config's `sync.ps1`: what every AI tool follows comes from
`RULES.md`, the Claude Code part from `tools/claude.md`. A change goes into one of
those, never into two places.

{{RULES}}

## Claude Code: effort and model

A session cannot change its own effort: `set_session_effort` refuses the session that calls it. So state the effort, and when it differs from the session's current one, ask the user to set it in the app's effort picker before the work starts.

**Model: Sonnet for small, only while it costs the user nothing.** Good results and their time come before the token saving.

- Small work Claude hands off goes to Sonnet: a subagent (`model: "sonnet"`) or a session Claude starts for a small task. Medium and Large stay on Opus.
- Never ask the user to switch a session to Sonnet: that costs their time. A small task in an Opus session is done there.
- A Medium or Large task in a Sonnet session: say so in the sizing line and ask the user to pick Opus before starting.
- Sonnet work that fails its checks, or that the user has to correct, moves to Opus at once (say so in one line); no second try on Sonnet.

## Claude Code: tokens

- **Wide reads go to a subagent.** A branch's whole diff, long logs, many files: an Explore subagent (`model: "sonnet"`) returns the summary, so the raw text never sits in this context.
- **Edit what was Read.** A file to be changed with Edit is read with Read (a line range will do), not `cat` or `sed`; after a compaction, Read it again first. A failed Edit is a wasted round trip.
- **Scripts are written with Write**, then run.

## Claude Code: mockups

The mockup that "Mock up a screen before building it" asks for is drawn inline with the visualize `show_widget` tool.

## Paid usage

Claude cannot choose which pool pays: plan limits are spent first, extra usage only once one is full. So check early, keep work local, ask before the paid part.

1. **Usage line on every reply.** Call `get_usage` (ccd_session_mgmt) at the start of every reply, in the same message as its first other tool call, and make the first line `Usage: 5-hour 46% (resets in 2h 33m) · weekly 16% · extra USD 0.00 / 50.00`. The sizing line comes after it.
2. **Plan limits first.** No cloud work (a session moved to the cloud, `isolation: "remote"` agents, cloud routines, `/code-review ultra`) while local limits have room, unless the user asks.
3. **Stop and wait for a yes** when the 5-hour or the weekly limit is at 98% or more: before starting, and mid-task as soon as a usage check shows it. The same before any work that would run in the cloud. Give the percentages, the reset time and extra usage spent against its limit.
4. **Flag extra usage at 90% or more** of its monthly limit at the top of the reply (spent, limit). A heads-up, not a stop.
