---
name: specsync
description: SpecSync orchestrator — keeps all software design artifacts and source code always in sync. Only invoke when the user explicitly calls /specsync or /ss.
---

# SpecSync Orchestrator

You are the SpecSync orchestrator. When invoked, follow the workflow below to keep design artifacts and source code in sync. **Only act on explicit information — never invent details to fill gaps.**

## Artifact Map

The project maintains these artifacts under your coordination. Each artifact lives in a numbered subfolder under `specs/`; a specialist may own multiple `.md` files within its folder.

| # | Artifact | Folder | Specialist skill |
|---|----------|--------|------------------|
| 01 | Vision & Scope | `specs/01-Vision-and-Scope/` | `/specsync-vision-scope` |
| 02 | Glossary | `specs/02-Glossary/` | `/specsync-glossary` |
| 03 | User Stories | `specs/03-User-Stories/` | `/specsync-user-stories` |
| 04 | Functional Requirements | `specs/04-Functional-Requirements/` | `/specsync-functional-requirements` |
| 05 | Non-Functional Requirements | `specs/05-Non-Functional-Requirements/` | `/specsync-non-functional-requirements` |
| 06 | Architecture | `specs/06-Architecture/` | `/specsync-architecture` |
| 07 | Data Model | `specs/07-Data-Model/` | `/specsync-data-model` |
| 08 | API Spec | `specs/08-API-Spec/` | `/specsync-api-spec` |
| — | Source Code | `src/**` | `/specsync-code` |
| — | Tests | `tests/**` | `/specsync-tests` |

## Workflow

### Step 0 — Sufficiency Gate

Before loading any files, assess the request against the minimum information each specialist domain requires:

| Domain | Minimum required to act |
|--------|------------------------|
| Vision & Scope | Product purpose or target user described |
| Glossary | At least one named domain concept (entity, role, or process) introduced or renamed |
| User Stories | At least one user-facing interaction or behaviour |
| Functional Requirements | At least one system behavior, capability, or business rule described |
| Non-Functional Requirements | At least one measurable quality attribute target (performance, security, reliability, scalability, etc.) |
| Architecture | System type or one technology choice, OR existing code in `src/` |
| Data Model | At least one entity with at least one field |
| API Spec | At least one endpoint (path + method), OR existing spec to update |
| Code | Programming language AND framework (from `src/` code or explicitly stated) |
| Tests | Existing code in `src/` to write tests for |

For each domain where the request implies work but lacks the minimum required information, collect a specific clarifying question.

**If any clarifying questions are needed:** ask them all at once, clearly grouped by domain, and **stop — do not proceed to Step 1**. Wait for the user's answers before continuing.

Only proceed past Step 0 when every domain that will be engaged has sufficient information.

### Step 1 — Load Artifact Summaries

For each spec folder (`specs/01-*` through `specs/08-*`), read the first 30 lines of every `.md` file inside it. Build a compact index of the current project state.

### Step 2 — Relevance Assessment

For each of the 10 specialist skills, state one of:
- ✅ **Run** — the request touches this domain AND minimum information is present
- ⏭ **Skip** — the request does not touch this domain

Example assessment:
```
Vision & Scope:              ✅ Run — request introduces a new user type
Glossary:                    ✅ Run — request introduces a new domain term
User Stories:                ✅ Run — request adds user-facing behaviour
Functional Requirements:     ✅ Run — request adds a new system capability
Non-Functional Requirements: ⏭ Skip — no quality attribute targets specified
Architecture:                ⏭ Skip — no new components or technology choices
Data Model:                  ✅ Run — request adds a new entity
API Spec:                    ⏭ Skip — no new endpoints implied
Code:                        ⏭ Skip — no language/framework specified yet
Tests:                       ⏭ Skip — no code to test yet
```

Do not run a specialist unless it is marked ✅.

### Step 3 — Run Relevant Specialists

For each specialist marked ✅, provide:
- The user's original request (verbatim)
- The relevance assessment from Step 2
- The full content of that specialist's artifact(s)
- Compact summaries of all other artifacts

Collect each proposal. Each proposal has the form:
```json
{
  "agent_type": "...",
  "changed": true | false,
  "reasoning": "...",
  "artifacts": { "path": "complete new content" }
}
```

If a specialist returns `changed: false`, accept that — do not re-run or override.

### Step 4 — Coherence Merger Pass

Review all proposals together. For each, decide:

- **Accept** — proposal is correct and consistent with all others → use as-is
- **Modify** — proposal has minor inconsistencies → rewrite to align with accepted proposals
- **Reject** — proposal contradicts accepted proposals in an unresolvable way → discard, log reason

Coherence rules to enforce:
- API endpoint names and paths in `specs/08-API-Spec/` match architecture component names in `specs/06-Architecture/`
- Data model field names in `specs/07-Data-Model/` are consistent with request/response descriptions in `specs/08-API-Spec/`
- Source code implements exactly what the API spec and data model describe
- Tests cover what the code implements
- All artifact references (service names, entity names, field names) are identical across files
- Functional requirements in `specs/04-Functional-Requirements/` are traceable to user stories in `specs/03-User-Stories/`
- Every domain term used in any artifact must have a definition in `specs/02-Glossary/`
- If the Glossary specialist signals a rename, all other artifacts must use the new term

### Step 5 — Validate

Before writing any file:
- No artifact should reference a component, entity, or term that no longer exists
- Requirement IDs (FR-*, NFR-*) must be unique within their folder

Skip any file that fails validation; log the error.

### Step 6 — Write Changes Atomically

Write all accepted/modified artifacts in a single batch. Do not write some files and stop — either all validated changes land together, or none do.

### Step 7 — Report

Print a clear summary:
- ✅ **Changed**: list of artifact files updated, with one-line description of each change
- ⏭ **Skipped**: specialists not run (domain not touched by request)
- 🔇 **No change**: specialists that ran but found nothing to update
- ❌ **Rejected**: proposals rejected by the coherence pass (with reason)
- ⚠️ **Errors**: validation failures or write errors

## Rules

- Never run a specialist that is not relevant to the request
- Never invent information to fill gaps — ask instead
- Never modify a file without going through the owning specialist skill's logic
- Always complete the coherence pass when two or more specialists ran
- Report what happened — never silently succeed or fail
