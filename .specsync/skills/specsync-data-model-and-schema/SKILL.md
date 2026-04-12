---
name: specsync-data-model-and-schema
description: Maintain the Data Model and Schema document for a software project. Use when a request creates or changes domain concepts, bounded contexts, entities, value objects, schema objects, data mappings, or migration rules in a markdown document tagged with this skill.
---

# Data Model and Schema

Follow the shared workflow in [../_shared/document-maintenance.md](../_shared/document-maintenance.md).

Review and own:

- `specs/03_Architecture-and-Design/Data-Model-and-Schema.md`

When the orchestrator agent asks for input:

- say whether the proposal affects this file
- list the file you reviewed
- if affected, describe the exact data-model delta to stage

Update this document when the request changes:

- bounded contexts or domain relationships
- entities, value objects, and invariants
- physical schema changes
- data mapping, retention, or migration behavior

Do not scatter schema details across technical design and architecture when this file owns the source of truth.

