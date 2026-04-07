# Shared Document Maintenance Workflow

## Decide Whether To Update

1. Read the user request and extract the new or changed facts.
2. Find documents whose ownership matches those facts.
3. Update a document only when the request changes content that belongs in that document.
4. Do not edit a managed document for implementation-only changes that do not affect its documented decisions or commitments.

## How To Update

1. Preserve the document title and ownership header.
2. Keep existing sections unless the structure is clearly no longer fit for purpose.
3. Replace placeholders with concrete content when the request provides enough detail.
4. Keep wording specific, testable, and internally consistent.
5. If related documents are impacted, note that and update them too.

## Quality Bar

- Avoid contradictory statements across requirements, design, QA, and operations documents.
- Keep IDs, tables, and acceptance criteria stable where possible.
- Prefer concise, concrete language over narrative filler.

## Response To Orchestrator

When the orchestrator agent asks whether a proposal affects this skill:

- reply `affected: yes` only when the proposal changes files owned by this skill
- reply `affected: no` when no owned file needs a delta
- always list the owned files you reviewed
- when affected, list the minimal file-level changes required in your area
- keep the response succinct and focused on actionable deltas

## Response To Orchestrator

When the orchestrator agent asks whether a proposal affects this skill:

- reply `affected: yes` only when the proposal changes files owned by this skill
- reply `affected: no` when no owned file needs a delta
- always list the owned files you reviewed
- when affected, list the minimal file-level changes required in your area
- keep the response succinct and focused on actionable deltas
