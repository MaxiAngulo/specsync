---
name: specsync-test-plan
description: Maintain the Test Plan document for a software project. Use when a request creates or changes validation strategy, environments, requirement coverage, entry or exit criteria, or defect handling in a markdown document tagged with this skill.
---

# Test Plan

Follow the shared workflow in [../_shared/document-maintenance.md](../_shared/document-maintenance.md).

Review and own:

- `specs/04_Quality-Assurance/Test-Plan.md`

When the orchestrator agent asks for input:

- say whether the proposal affects this file
- list the file you reviewed
- if affected, describe the exact test-plan delta to stage

Update this document when the request changes:

- validation strategy by test layer
- environment or data setup
- requirement coverage and evidence expectations
- entry, exit, or defect triage rules

Do not maintain a separate default test-case catalog when traceability and validation strategy are enough to generate focused cases on demand.

