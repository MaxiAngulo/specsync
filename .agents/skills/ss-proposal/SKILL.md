---
name: ss-proposal
description: Create a new SpecSync proposal workspace. Use when the user starts a change, needs a new proposal folder, or wants to bind the current agent session to a newly created proposal.
---

# Create Proposal

Use this skill to create a proposal under `proposes`.

Run one of these scripts:

- `scripts/ss-proposal.ps1`
- `scripts/ss-proposal.sh`

The skill must:

- create a timestamped proposal folder
- write `proposal.json` inside the new proposal folder
- bind the current agent session to the new proposal in `.specsync/sessions/<session-id>.json`

Resolve the session id from `SPECSYNC_SESSION_ID` when available. The host runtime may also expose another session env var. Only require an explicit session id when no runtime session id is available.

After the proposal folder exists:

- load `.specsync/skills/_shared/specsync-governance.md`
- load `.specsync/agents/specsync-orchestrator/AGENT.md`
- use the orchestrator agent to create and maintain `proposal.md` plus the proposal-folder spec and source deltas for user review
