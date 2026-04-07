---
name: specsync-source-code
description: Maintain source code under the configured source roots for this repository. Use when a user request creates, changes, refactors, fixes, or removes implementation code, tests colocated in a configured source root, module structure, interfaces, validation logic, or code behavior inside those roots.
---

# Source Code

Use this skill for implementation work inside the configured source roots from `.specsync/source-roots.txt`.

When a proposal is bound to the current agent session, prefer editing mirrored source paths directly inside that proposal folder. Use `<source-root>/<matching-path>` for relative configured roots and `<root-key>/<matching-path>` for absolute or external roots. Resolve the proposal folder from `.specsync/sessions/<session-id>.json`, using `SPECSYNC_SESSION_ID` as the default session id when available. Only the apply step should write back into the configured source roots.

Also load `.specsync/skills/_shared/specsync-governance.md` when implementation changes may affect managed documentation or proposal routing.

## Scope

Review and own files and folders under every configured source root.

When the orchestrator agent asks for input:

- say whether the proposal affects any configured source root
- list the source roots and files you reviewed
- if affected, describe the exact proposal-folder code deltas required

Apply this skill when a request changes:

- application behavior implemented in a configured source root
- module or folder structure inside a configured source root
- interfaces, function signatures, or internal contracts in a configured source root
- validation, transformation, parsing, or business logic in a configured source root
- source-level tests or fixtures stored in a configured source root

Do not use this skill for managed specification documents under `.specsync/templantes`, `specs`, or `proposes` unless the request explicitly changes both code and documentation.

## Decide Whether To Change Code

1. Read the request and identify the expected runtime or build-time behavior.
2. Inspect the relevant configured source roots.
3. Change code only if the current implementation does not satisfy the request, is missing, or is inconsistent with the requested behavior.
4. If the request only affects documentation, planning, or release process, do not edit the configured source roots.

## How To Change Code

1. Keep changes local to the smallest coherent area.
2. Preserve public contracts unless the request requires a breaking change.
3. Prefer clear names and simple control flow over clever abstractions.
4. Update related code paths when a change affects shared behavior.
5. Add or update tests when the repository has a test pattern for the changed area.

## Quality Bar

- Keep code consistent with the surrounding style.
- Avoid dead code, placeholder implementations, and silent behavior changes.
- Make failure cases explicit when the request introduces new validation or edge cases.
- If code changes imply document changes, consult the relevant managed document skills and keep the proposal consistent across docs and code.
