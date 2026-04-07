---
name: specsync-system-architecture
description: Maintain the System Architecture document for a software project. Use when a request creates or changes system context, containers, components, data flow, integrations, architectural drivers, or architecture-level risks in a markdown document tagged with this skill.
---

# System Architecture

Follow the shared workflow in [../_shared/document-maintenance.md](../_shared/document-maintenance.md).

Review and own:

- `specs/03_Architecture-and-Design/System-Architecture.md`

When the orchestrator agent asks for input:

- say whether the proposal affects this file
- list the file you reviewed
- if affected, describe the exact system-architecture delta to stage

Update this document when the request changes:

- system boundaries, actors, or external integrations
- C4 context, container, or component views
- architecture-level data flow and quality attributes
- links to relevant ADRs
- major architectural risks or constraints

Do not use this document for ticket-level implementation steps that belong in technical design.

