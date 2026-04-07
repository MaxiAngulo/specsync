# Document Templates

This proposal reduces the template pack to a minimal set of decision-bearing documents that are easier for humans and AI agents to keep consistent.

## Minimal Set

- `01_Project-Overview/Vision-and-Scope.md`
- `01_Project-Overview/Stakeholders-and-Roles.md`
- `02_Product-Specification/Product-Requirements-Document.md`
- `02_Product-Specification/Requirements-Traceability-Matrix.md`
- `03_Architecture-and-Design/System-Architecture.md`
- `03_Architecture-and-Design/Architectural-Decision-Record.md`
- `03_Architecture-and-Design/Technical-Design.md`
- `03_Architecture-and-Design/Data-Model-and-Schema.md`
- `03_Architecture-and-Design/UI-UX-Design.md`
- `04_Quality-Assurance/Test-Plan.md`
- `05_Operations-and-Delivery/Release-Plan.md`
- `05_Operations-and-Delivery/Runbook.md`

## Removed From The Default Set

The following artifacts are removed as separate managed documents because they overlap with the PRD, traceability matrix, or test plan:

- `02_Requirements/Business-Requirements.md`
- `02_Requirements/User-Requirements.md`
- `02_Requirements/Functional-Requirements.md`
- `02_Requirements/Non-Functional-Requirements.md`
- `02_Product-Specification/User-Stories.md`
- `04_Quality-Assurance/Test-Cases.md`

## Usage

1. Copy only the templates needed by the project into `specs` or the active proposal.
2. Keep one fact in one place. Use references and IDs instead of duplicating the same requirement across documents.
3. Use the owning support skill under `.specsync/skills` to decide whether a document should be created or updated.




