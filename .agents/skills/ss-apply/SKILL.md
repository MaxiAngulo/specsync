---
name: ss-apply
description: Apply a SpecSync proposal into the repository state. Use when the user wants to promote proposal-folder spec and source deltas into `specs` and the configured source roots.
---

# Apply Proposal

Use this skill to apply a proposal.

Run one of these scripts:

- `scripts/ss-apply.ps1`
- `scripts/ss-apply.sh`

The skill must:

- resolve the target proposal, defaulting to `.specsync/sessions/<session-id>.json`
- overlay `specs/<matching-path>` deltas into `specs`
- refuse to apply proposal-folder source changes when the live configured source roots no longer match `source-state.txt`
- overlay each proposal-folder source delta into its configured source root from `.specsync/source-roots.txt`
- update `apply-summary.md`

Resolve the session id from `SPECSYNC_SESSION_ID` when available. The host runtime may also expose another session env var. Only require an explicit session id when no runtime session id is available.

