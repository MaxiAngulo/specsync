---
name: ss-session
description: Set or inspect the SpecSync proposal bound to the current agent session. Use when the user wants to switch proposal context for this session or confirm which proposal the session is using.
---

# Set Session Proposal

Use this skill to manage `.specsync/sessions/<session-id>.json`.

Run one of these scripts:

- `scripts/ss-session.ps1`
- `scripts/ss-session.sh`

The skill must:

- resolve a proposal by name or path
- bind it to the current agent session
- return the resolved proposal path
- when no proposal is passed, return the proposal currently bound to the current agent session

Resolve the session id from `SPECSYNC_SESSION_ID` when available. The host runtime may also expose another session env var. Only require an explicit session id when no runtime session id is available.

