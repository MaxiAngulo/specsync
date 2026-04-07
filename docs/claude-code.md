# Claude Code Setup

Claude Code supports project slash commands and project Skills, but it does not use the `.agents` folder as the primary project command surface.

Based on Anthropic's documentation:

- project slash commands live in `.claude/commands/`
- project Skills live in `.claude/skills/`

That means SpecSync should be adapted for Claude Code like this.

## Install Layout

Copy into the target repository:

- `.specsync`
- `.claude/commands`
- optionally `.claude/skills`

Keep `.specsync` as the authoritative SpecSync package. It contains:

- templates
- governance
- orchestrator instructions
- support-skill ownership for managed documents

## Recommended Mapping

Map the lifecycle workflow into Claude Code slash commands:

- `/ss-init` -> `.claude/commands/ss-init.md`
- `/ss-proposal` -> `.claude/commands/ss-proposal.md`
- `/ss-session` -> `.claude/commands/ss-session.md`
- `/ss-refine` -> `.claude/commands/ss-refine.md`
- `/ss-pull` -> `.claude/commands/ss-pull.md`
- `/ss-apply` -> `.claude/commands/ss-apply.md`
- `/ss-archive` -> `.claude/commands/ss-archive.md`

Each command file should instruct Claude to follow the corresponding workflow implemented by SpecSync and to read the relevant files under `.specsync`.

## Command Responsibility Split

Use this split in Claude Code:

- `.claude/commands/*` for explicit user-invoked lifecycle commands
- `.specsync/agents/specsync-orchestrator/AGENT.md` for proposal orchestration
- `.specsync/skills/*` for managed-document and source-code ownership
- `.claude/skills/*` only when you want Claude Code-native automatic Skill discovery in addition to the SpecSync rules

## Example Command Shape

Example `.claude/commands/ss-init.md`:

```md
---
description: Initialize a repository for the SpecSync workflow.
---

Initialize this repository for SpecSync.

Follow the workflow defined by:

- `.specsync/README.md`
- `.specsync/skills/_shared/specsync-governance.md`
- `.agents/skills/ss-init/SKILL.md` if this repository keeps the reference implementation

Create or ensure:

- `specs/`
- `proposes/`
- `proposals-archive/`
- `.specsync/sessions/`
- `.specsync/source-roots.txt`

Copy missing spec files from `.specsync/templantes` into `specs`.
```

## Practical Recommendation

For this repository, keep the `.agents` folder as the reference implementation of the lifecycle workflow, but document Claude Code installation separately:

- `.agents` is the reference source for the lifecycle command definitions in this repo
- `.claude/commands` is the installation target for Claude Code consumers
- `.specsync` stays portable across both models

This keeps SpecSync agent-agnostic while still making Claude Code installation straightforward.
