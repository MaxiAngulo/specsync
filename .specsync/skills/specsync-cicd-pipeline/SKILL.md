---
name: specsync-cicd-pipeline
description: Maintain the CI/CD Pipeline document for a software project. Use when a request creates or changes pipeline stages, environment configuration, quality gates, secrets management, branch strategy, notifications, or deployment/rollback procedures in a markdown document tagged with this skill.
---

# CI/CD Pipeline

Follow the shared workflow in [../_shared/document-maintenance.md](../_shared/document-maintenance.md).

Review and own:

- `specs/05_Operations-and-Delivery/CI-CD-Pipeline.md`

When the orchestrator agent asks for input:

- say whether the proposal affects this file
- list the file you reviewed
- if affected, describe the exact CI/CD pipeline delta to stage

Update this document when the request changes:

- pipeline stages, triggers, tools, or runner configuration
- target environments, deployment methods, or approval gates
- quality gates such as coverage thresholds, static analysis, or security scan policies
- secrets, credential stores, or rotation policies
- notification channels or observability integrations
- branch strategy, merge requirements, or protected-branch rules
- known pipeline limitations or risks

Do not edit this document for product requirements or internal implementation details unless the build, test, or deployment process changes.
