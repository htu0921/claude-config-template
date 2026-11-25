# memory

Claude Code's memory for each repo, shared between machines. Each folder here is
named by a project key, the repo's checkout path with `:` and `\` as `-`
(`C:\dev\app` is `C--dev-app`), and `setup.ps1` junctions it into
`~/.claude/projects/<project key>/memory`, where Claude Code keeps that repo's memory.

To share a repo's memory: move `~/.claude/projects/<project key>/memory` here as
`memory/<project key>`, then run `.\setup.ps1`. The folder holds a `MEMORY.md`, its
index. On another machine the repo must sit at the same path.
