# Custom Document Types

SpecSync is designed to be extended. If your project needs a different documentation set, add or change templates under `.specsync/templantes` and create or update the support skills under `.specsync/skills`.

## Mental Model

Each managed document type should have:

- a template file under `.specsync/templantes`
- a support skill under `.specsync/skills`

The template defines the document structure. The skill defines:

- when the document should be reviewed
- what facts it owns
- when it should change
- what it should not own

## Example

Assume you want to add a `Security-Review.md` document.

1. Add a template file, for example:

`.specsync/templantes/03_Architecture-and-Design/Security-Review.md`

2. Add a matching skill folder:

`.specsync/skills/specsync-security-review/SKILL.md`

3. In that skill, define:

- the owned file path under `specs/...`
- the types of requests that affect the document
- the changes that belong in this document
- the changes that do not belong in this document

## Skill Shape

A support skill typically includes:

- front matter with the skill name and description
- the owned file path
- rules for how to respond to the orchestrator
- rules for when to update the document
- rules for what not to update here

Example:

```md
---
name: specsync-security-review
description: Maintain the Security Review document for a software project.
---

# Security Review

Follow the shared workflow in [../_shared/document-maintenance.md](../_shared/document-maintenance.md).

Review and own:

- `specs/03_Architecture-and-Design/Security-Review.md`

When the orchestrator agent asks for input:

- say whether the proposal affects this file
- list the file you reviewed
- if affected, describe the exact security-review delta to stage

Update this document when the request changes:

- threat model decisions
- security controls
- trust boundaries
- secrets handling

Do not edit this document for generic product scope or release choreography unless the security posture changes.
```

## Template Design Guidance

Keep templates:

- minimal
- concrete
- decision-oriented
- non-overlapping with other managed documents

Avoid creating multiple documents that restate the same requirement in slightly different forms. If one document already owns the fact, link to it from another document instead of duplicating it.

## Updating The Default Spec Set

When you add or remove document types, update:

- `.specsync/templantes/README.md`
- `.specsync/README.md` when the recommended default set changes
- any support skills whose ownership paths or boundaries changed

## UX-Specific Note

For UX, the recommended pattern is:

- store the design source of truth in tools such as Figma
- keep `UI-UX-Design.md` as the manifest that links to those assets and records the implementation-relevant rules

That keeps the workflow AI-friendly without forcing UX professionals into markdown as their primary design tool.

