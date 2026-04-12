# Workflow Guide

This guide explains how to use SpecSync in day-to-day repository work without depending on a Git-specific process.

## Principles

- Work through a proposal folder instead of editing live managed files during proposal creation and refinement.
- Use the smallest coherent set of document and code changes.
- Keep documentation and code aligned before apply.
- Use `/ss-pull` when the live repository moved outside the proposal.

## Repository Layout After Init

After `/ss-init`, the repository contains:

- `specs/` for the approved documentation set
- `proposes/` for open proposal workspaces
- `proposals-archive/` for completed proposals
- `.specsync/source-roots.txt` for configured source roots
- `.specsync/sessions/` for session-to-proposal bindings

## Lifecycle Skills

### `/ss-init`

Bootstraps the repository from `.specsync/templantes`.

```text
/ss-init
```

### `/ss-proposal`

Creates a timestamped proposal and binds the current session.

```text
/ss-proposal improve-login-flow
```

### `/ss-session`

Shows or changes the proposal bound to the current session.

```text
/ss-session
```

### `/ss-refine`

Uses the orchestrator and support skills to refine the proposal content.

```text
/ss-refine improve-login-flow
```

### `/ss-pull`

Copies live `specs` and source-root state into the bound proposal so outside changes can be merged safely.

```text
/ss-pull
```

### `/ss-apply`

Promotes proposal-folder deltas into live `specs` and source roots.

```text
/ss-apply
```

### `/ss-archive`

Moves the completed proposal into `proposals-archive`.

```text
/ss-archive
```


## Claude Code Variant

If you use Claude Code, do not treat `.agents` as the command surface. Anthropic documents project slash commands under `.claude/commands/` and project Skills under `.claude/skills/`.

Use this mapping:

- keep `.specsync` in the repository
- expose the lifecycle workflow as Claude Code slash commands in `.claude/commands/`
- keep `.specsync` as the source of truth for templates, orchestrator behavior, and managed document ownership

Example command files:

- `.claude/commands/ss-init.md`
- `.claude/commands/ss-proposal.md`
- `.claude/commands/ss-refine.md`
- `.claude/commands/ss-pull.md`
- `.claude/commands/ss-apply.md`
- `.claude/commands/ss-archive.md`

Then users invoke `/ss-init`, `/ss-proposal`, and the rest from Claude Code in the normal way.
## Common Usage Patterns

### 1. Small Documentation Fix

Example: a test-plan correction or a missing architecture note.

1. Create a proposal.
2. Update only the affected proposal document.
3. Apply.
4. Archive.

You do not need to touch unrelated requirements, UX, or source-code files.

### 2. Small Code Fix With Documentation Sync

Example: a validation bug fix in `src`.

1. Create a proposal.
2. Update the mirrored code under the proposal source-root path.
3. Update only the documentation that changed because of that fix, such as PRD, technical design, or test plan.
4. Apply.

### 3. Large Cross-Cutting Change

Example: a new subsystem or a major redesign.

1. Create a proposal.
2. Update the relevant requirements, architecture, UX, QA, release, and operations documents in the proposal.
3. Update the mirrored code under the proposal source-root path.
4. Use traceability and ADRs where needed.
5. Apply after the proposal is coherent.

## Documentation-Led And Code-Led Work

SpecSync supports both directions.

### Documentation-led

Start by changing proposal docs, then add matching code deltas in the proposal mirror.

### Code-led

If code changed first, use `/ss-pull`, capture the live state into the proposal, then document the behavior and intent that correspond to the implementation.

## Git Independence

SpecSync does not require branches, commits, or pull requests as part of the workflow model.

If the repository uses Git, that is fine. If a team wants to review proposal folders through some other process, that is also fine. The proposal folder is the review unit.

## When To Use `/ss-pull`

Run `/ss-pull` when:

- live `specs` changed outside the proposal
- live source files changed outside the proposal
- you need the proposal to absorb current repository state before apply

This protects proposal work from blindly overwriting newer live changes.

## Scripts Versus Skills

Users and agents should invoke the skills directly, for example `/ss-init` or `/ss-proposal improve-login-flow`.

The files under `.agents/skills/*/scripts` exist to implement those skills. They are not the primary user-facing workflow.

