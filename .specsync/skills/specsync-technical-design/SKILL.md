---
name: specsync-technical-design
description: Maintain the Technical Design document for a software project. Use when a request creates or changes implementation design, module responsibilities, contracts, sequencing, error handling, or operational design in a markdown document tagged with this skill.
---

# Technical Design

Follow the shared workflow in [../_shared/document-maintenance.md](../_shared/document-maintenance.md).

Review and own:

- `specs/03_Architecture-and-Design/Technical-Design.md`

When the orchestrator agent asks for input:

- say whether the proposal affects this file
- list the file you reviewed
- if affected, describe the exact technical-design delta to stage

Update this document when the request changes:

- implementation-level solution design
- modules, contracts, or sequencing behavior
- compatibility, failure handling, or rollback design
- operational considerations that are specific to the implementation approach

Do not duplicate data-model details here when they belong in the dedicated data-model-and-schema document.

