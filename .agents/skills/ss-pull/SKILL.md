---
name: ss-pull
description: Capture the current live specs and configured source-root state into the active SpecSync proposal. Use when managed spec files or source files changed outside the proposal and those live changes must be merged into the proposal workspace before refinement or apply.
---

# Pull Source State

Use this skill to merge the current live `specs` tree into a proposal, copy the configured source roots into the proposal mirror, and record the live source snapshot used by `ss-apply`.

Run one of these scripts:

- `scripts/ss-pull.ps1`
- `scripts/ss-pull.sh`

The skill must:

- resolve the target proposal, defaulting to `.specsync/sessions/<session-id>.json`
- merge each live `specs/<matching-path>` document into the mirrored proposal `specs/<matching-path>` file while preserving proposal-only edits when the merge is clean
- copy each configured source root from `.specsync/source-roots.txt` into the mirrored proposal-folder source path
- refuse to overwrite proposal-folder source edits that no longer match the last captured live source snapshot
- write `source-state.txt` inside the proposal folder with the current live source snapshot

Resolve the session id from `SPECSYNC_SESSION_ID` when available. The host runtime may also expose another session env var. Only require an explicit session id when no runtime session id is available.
