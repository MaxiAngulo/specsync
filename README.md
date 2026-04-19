# SpecSync

SpecSync keeps project's software  documentation and code in sync so both development teams and AI agents can work against current project knowledge.

It is a repository-local workflow, not a hosted service and not a CLI product. You install it by copying the `.agents` and `.specsync` folders into another repository. After that, the repository contains:

- the lifecycle workflow used to create, refine, pull, apply, and archive changes
- the managed document templates that define the default `specs` structure
- the support skills that tell an agent which document owns which facts
- the governance rules that keep proposal work, documentation, and source-code changes aligned

## What It Solves

Software teams often let code and documentation drift apart because there is no shared unit of change that keeps both in step. SpecSync solves this by making the proposal folder that shared unit, so every change — whether it starts in code or in a document — travels with its counterpart until both sides are promoted together.

Specifically, SpecSync lets people and AI agents:

- **Keep code and documentation permanently in sync.** A code change propagates into the relevant specs. A documentation change propagates into the relevant source. Neither side can be promoted alone, so drift cannot accumulate silently.
- **Start from whichever artifact changed first.** If a developer lands a fix before the docs are updated, pull the live state into a proposal and refine the documentation to match. If a product owner updates the requirements first, refine the code delta inside the proposal and then apply both together.
- **Work at any scale.** A single requirement correction, a screen-copy update, or a one-line validation fix fits the same workflow as a new subsystem, a data-model migration, or a cross-cutting architectural change.
- **Focus on the resulting artifact, not on process overhead.** There are no mandatory planning documents, no status templates, and no ticket hierarchies. The proposal holds only the spec and source deltas that describe the desired end state.
- **Collaborate across roles inside a single proposal.** A UI designer, a software architect, a tester, and a product owner can each refine the documents they own — UX, architecture, test plan, requirements — within the same proposal before anything is promoted to the live tree.

The workflow is Git-independent. If a repository uses Git, SpecSync works inside it. If a team does not want to model the process around branches or pull requests, SpecSync still works because the unit of change is the proposal folder, not the Git branch. That said, using SpecSync alongside Git is recommended: applying a proposal on a dedicated branch and reviewing it as a pull request gives the team a natural checkpoint before the promoted changes reach the main line.

## Installation

Copy these folders into the target repository:

- `.agents`
- `.specsync`

No CLI installation is required.

After copying the folders, initialize the repository with the `/ss-init` skill so the project gets:

- `specs/`
- `proposes/`
- `proposals-archive/`
- `.specsync/sessions/`
- `.specsync/source-roots.txt`

Example:

```text
/ss-init
```

By default, `.specsync/source-roots.txt` starts with `src`.


## Claude Code Installation

Claude Code does not use the `.agents` folder for project slash commands. According to Anthropic's documentation, project slash commands live in `.claude/commands/`, and project Skills live in `.claude/skills/`.

For Claude Code, install SpecSync like this:

- copy `.specsync` into the target repository
- copy the lifecycle command definitions from this repository into `.claude/commands/`
- copy any reusable Claude Code Skills into `.claude/skills/` when you want Claude to discover them automatically

Recommended mapping for the lifecycle workflow:

- `/ss-init` -> `.claude/commands/ss-init.md`
- `/ss-proposal` -> `.claude/commands/ss-proposal.md`
- `/ss-session` -> `.claude/commands/ss-session.md`
- `/ss-refine` -> `.claude/commands/ss-refine.md`
- `/ss-pull` -> `.claude/commands/ss-pull.md`
- `/ss-apply` -> `.claude/commands/ss-apply.md`
- `/ss-archive` -> `.claude/commands/ss-archive.md`

In that setup:

- `.claude/commands` is the user-facing entrypoint for the lifecycle workflow
- `.specsync` remains the source of truth for orchestrator rules, templates, governance, and managed-document ownership
- `.claude/skills` is optional and can be used for Claude-native Skills if you want automatic discovery in Claude Code

See [Claude Code Setup](docs/claude-code.md) for the detailed mapping.
## Core Workflow

The normal flow is:

1. Initialize the repository with `/ss-init`.
2. Create a proposal with `/ss-proposal`.
3. Refine the proposal with `/ss-refine`.
4. Pull live changes into the proposal with `/ss-pull` when the repository changed outside the proposal. If the main line has been updated while the proposal was in progress — for example, another proposal was applied or a hotfix was merged — run `/ss-pull` to bring those changes into the proposal workspace before continuing refinement or applying.
5. Apply the proposal with `/ss-apply`.
6. Archive the proposal with `/ss-archive`.

The proposal folder is the working area for changes. During proposal creation and refinement, the live `specs` tree and configured source roots should not be edited directly.

## Example: Documentation-Led Change

Use this flow when you want to define the change in documentation first and then update the code to match it.

1. Create a proposal:

```text
/ss-proposal add-order-validation
```

2. Refine the proposal by updating the proposal-folder docs under:

- `proposes/<proposal>/specs/...`
- `proposes/<proposal>/<source-root>/...`

3. Add the matching source-code delta inside the proposal mirror.
4. Apply the proposal:

```text
/ss-apply
```

This is useful when the team wants the requirements, architecture, UX, or rollout plan agreed before code is promoted.

## Example: Code-Led Change

Use this flow when code changed first and the documentation must be synchronized afterward.

1. Create or bind a proposal.
2. Pull the current live state into the proposal:

```text
/ss-pull
```

3. Refine the proposal to document the real code behavior and any missing requirements, design, QA, or operations updates.
4. Apply the synchronized proposal back into `specs` and source roots.

This flow is useful when a small bug fix, emergency change, or implementation spike happened before the documents were updated.

## Small And Large Changes

SpecSync works for both:

- small changes, such as one requirement adjustment, one screen copy update, or one validation fix
- large changes, such as a new subsystem, a redesign, a data model migration, or a rollout that affects architecture, QA, and operations together

The support skills under `.specsync/skills` keep the change set focused by updating only the documents whose facts actually changed.

## Default Managed Documents

The default template set is intentionally minimal:

- Vision and Scope
- Stakeholders and Roles
- Product Requirements Document
- Requirements Traceability Matrix
- System Architecture
- Architectural Decision Record
- Technical Design
- Data Model and Schema
- UI UX Design
- Test Plan
- Release Plan
- Runbook

UX is handled as a manifest that can point to richer assets such as Figma, not as a markdown-only mockup format.

## Workflow Guides

See:

- [Workflow Guide](docs/workflow-guide.md)
- [Custom Document Types](docs/custom-document-types.md)

## How Agents Know What To Update

SpecSync separates responsibilities:

- `.agents/skills` owns lifecycle actions such as init, proposal creation, refine, pull, apply, and archive
- `.specsync/agents/specsync-orchestrator/AGENT.md` owns proposal-time orchestration
- `.specsync/skills/*/SKILL.md` owns individual document types and source-code routing

That structure is what lets the workflow travel with the repository. No root `AGENTS.md` file is required.

The scripts inside `.agents/skills/*/scripts` are implementation details of those skills. The intended interface for users and agents is the skill invocation itself, for example `/ss-init` or `/ss-apply`.

