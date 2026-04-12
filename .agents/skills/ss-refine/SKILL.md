---
name: ss-refine
description: Refine the proposal bound to the current agent session. Use when the user wants to iterate on proposal-folder spec or source changes while keeping the proposal internally consistent.
---

# Refine Proposal

Use this skill to work inside the current session proposal.

Run one of these scripts:

- `scripts/ss-refine.ps1`
- `scripts/ss-refine.sh`

The skill must:

- resolve the proposal from `.specsync/sessions/<session-id>.json` when no proposal is passed
- load `.specsync/skills/_shared/specsync-governance.md`
- pass the current user request to `.specsync/agents/specsync-orchestrator/AGENT.md`
- update `orchestration.md` with the current routing rules
- keep work inside the bound proposal folder using mirrored `specs` and source-root paths
- route spec and source deltas by consulting the relevant support skills under `.specsync/skills`
- load `.specsync/agents/specsync-orchestrator/AGENT.md` as the orchestrator agent for proposal-folder work

Resolve the session id from `SPECSYNC_SESSION_ID` when available. The host runtime may also expose another session env var. Only require an explicit session id when no runtime session id is available.
