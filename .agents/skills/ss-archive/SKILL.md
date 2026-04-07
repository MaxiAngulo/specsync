---
name: ss-archive
description: Archive a completed SpecSync proposal. Use when the user wants to move a proposal from `proposes` into `proposals-archive` and clear any session bindings that point to it.
---

# Archive Proposal

Use this skill to archive a proposal after apply or when closing it.

Run one of these scripts:

- `scripts/ss-archive.ps1`
- `scripts/ss-archive.sh`

The skill must:

- resolve the target proposal, defaulting to `.specsync/sessions/<session-id>.json`
- move the folder into `proposals-archive`
- clear any session bindings that point to the archived proposal

Resolve the session id from `SPECSYNC_SESSION_ID` when available. The host runtime may also expose another session env var. Only require an explicit session id when no runtime session id is available.

