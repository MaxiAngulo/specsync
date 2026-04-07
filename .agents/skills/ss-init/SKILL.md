---
name: ss-init
description: Initialize a SpecSync repository. Use when the user wants to bootstrap specs from templates, create the proposal folders, initialize `.specsync/sessions`, and create or maintain the configured source-root list in `.specsync/source-roots.txt`.
---

# Init Project

Use this skill to initialize the repository for the SpecSync workflow.

Run one of these scripts:

- `scripts/ss-init.ps1`
- `scripts/ss-init.sh`

The skill must:

- copy template documents from `.specsync/templantes` into `specs` when missing
- ensure `proposes` and `proposals-archive` exist
- ensure `.specsync/sessions` exists
- ensure `.specsync/source-roots.txt` exists with `src` as the default source root

