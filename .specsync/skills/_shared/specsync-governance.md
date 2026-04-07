# SpecSync Governance

Use this file as the repository-local source of truth for SpecSync workflow governance. A project that installs SpecSync should not require a root `AGENTS.md` file to operate correctly.

## Core Rules

1. Run proposal lifecycle work through `.specsync/agents/specsync-orchestrator/AGENT.md` together with the lifecycle skills under `.agents/skills`.
2. Use the lifecycle skills under `.agents/skills` instead of inventing a parallel command metadata layer.
3. Do not edit `specs` or configured source roots directly while a proposal is being created or refined. Save proposed changes under the proposal folder bound to the current session instead.
4. When a user request may affect requirements, specifications, design, QA, release, or operations content, inspect the managed documents that match the request.
5. Resolve managed document ownership from the support skills under `.specsync/skills`.
6. When a user request may affect implementation under configured source roots, load `.specsync/skills/specsync-source-code/SKILL.md` before creating or editing source files.
7. Update only the managed documents whose facts, decisions, scope, interfaces, tests, rollout steps, or operators change because of the request.
8. If a request does not change the managed facts of a document, leave that document unchanged and say so briefly.
9. Keep related documents aligned when a change crosses document boundaries.

## Proposal-Time Routing

- The orchestrator owns proposal routing and proposal-folder document maintenance.
- Support skills own individual managed documents and must report whether the proposal affects their owned files.
- The source-code skill owns changes under configured source roots and should be consulted whenever implementation behavior changes.
- During proposal creation and refinement, all spec and code deltas stay inside the bound proposal folder until apply.
