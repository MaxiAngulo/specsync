# SpecSync Workflow

SpecSync keeps software documentation in `specs` and implementation in the configured source roots synchronized through proposal folders.

## Repository Folders

- `specs` holds the current approved specification set.
- `.specsync/templantes` holds the default template pack for initializing or extending that specification set.
- `.specsync/source-roots.txt` stores one or more configured source-code roots. The default is `src`.
- `.specsync/sessions` stores one session binding file per chat or agent session.
- `proposes` holds open proposal workspaces.
- `proposals-archive` holds archived proposals.

## Governance

Read `.specsync/skills/_shared/specsync-governance.md` for the cross-cutting rules that govern proposal work, document ownership, source-code routing, and consistency across managed artifacts. SpecSync should be usable after installation without a repository-root `AGENTS.md` file.

## Recommended Minimal Spec Set

The default template pack should prioritize a small set of authoritative artifacts:

- vision and scope
- stakeholders and roles
- product requirements document
- requirements traceability matrix
- system architecture
- architectural decision records
- technical design
- data model and schema
- UI UX design asset manifest
- test plan
- release plan
- runbook

Avoid maintaining parallel business, user, functional, non-functional, story, and case catalogs unless a project has a specific governance need that justifies the extra overhead.
