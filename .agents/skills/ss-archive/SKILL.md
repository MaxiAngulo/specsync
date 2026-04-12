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
- if `git` is available: create `proposals-archive/<name>/` with `proposal.json`, `proposal.md` (if present), and `changes.patch` (unified diff of each proposal file against its live counterpart in `specs/` or the configured source roots; new files diff against `/dev/null`; paths listed in `deletions.txt` diff from live to `/dev/null`); then delete the proposal folder
- if `git` is not available: move the folder into `proposals-archive` (current behavior)
- record `archive_format: "patch"` or `"folder"` in `proposal.json`
- clear any session bindings that point to the archived proposal

`deletions.txt` (optional file in proposal root): repo-relative paths of files to remove from live state during `ss-apply`. One path per line; blank lines and `#` comments ignored. Used by `ss-archive` to generate removal hunks in `changes.patch`.

Resolve the session id from `SPECSYNC_SESSION_ID` when available. The host runtime may also expose another session env var. Only require an explicit session id when no runtime session id is available.

