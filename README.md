# SpecSync

> Keep all software design artifacts and source code always in sync — using any AI coding tool.

SpecSync is a set of AI skills expressed entirely in markdown. Drop `.agents/skills/` and `.specsync/` into any project and your AI tool will automatically orchestrate a team of specialists that keep your specs and code coherent on every change request.

No runtime. No CLI. No dependencies. Just markdown files your AI tool reads.

---

## Design Principles

**Specs as code.** Every software artifact — vision, glossary, user stories, architecture, data model, API spec — lives in the repository as a well-known, structured file. Both humans and AI agents always have full, up-to-date project knowledge directly from the repo. No external wikis, no stale documents, no context lost between sessions.

**Results over process.** Agent output is designed to be concise. You see what changed and why — not the internal plans, subtask breakdowns, or intermediate reasoning of each specialist. This keeps the focus on the final result and reduces noise in your workflow.

**Git is yours.** SpecSync writes files and nothing else. It does not commit, branch, tag, or push. Your team owns the git strategy — feature branches, trunk-based development, pull request reviews — all unaffected and unrestricted.

**Built to extend.** The specialist roster is not fixed. Adding support for a new artifact type (e.g., infrastructure-as-code, ADRs, runbooks) takes one file: copy `_template/SKILL.md`, fill in the sections, and register it with the orchestrator. Existing specialists and their artifact definitions are plain markdown files — edit them directly to rename artifacts, change ownership rules, or adjust the behavior of any specialist. SpecSync grows and adapts with your project's needs.

---

## How it works

SpecSync defines a team of 8 specialist skills — one per design artifact domain — plus an orchestrator that coordinates them. When you make a change request, the orchestrator runs each specialist, collects proposals, resolves contradictions, and writes all accepted changes atomically.

```
You: /ss "add user authentication"
        │
        ▼
  /specsync  (orchestrator skill)
        │
        ├── specsync-vision-scope          →  specs/01-Vision-and-Scope/
        ├── specsync-glossary              →  specs/02-Glossary/
        ├── specsync-user-stories          →  specs/03-User-Stories/
        ├── specsync-functional-requirements  →  specs/04-Functional-Requirements/
        ├── specsync-non-functional-requirements  →  specs/05-Non-Functional-Requirements/
        ├── specsync-architecture          →  specs/06-Architecture/
        ├── specsync-data-model            →  specs/07-Data-Model/
        ├── specsync-api-spec              →  specs/08-API-Spec/
        ├── specsync-code                  →  src/**
        └── specsync-tests                 →  tests/**
              │
              ▼
        Coherence merger (orchestrator resolves conflicts)
              │
              ▼
        All accepted changes written atomically
```

---

## Repository Layout

```
.agents/
└── skills/                        ← Auto-discovered by Copilot CLI, Claude Code, etc.
    ├── specsync/SKILL.md              Orchestrator — invoke with /specsync or /ss
    ├── ss/SKILL.md                    Short alias — invoke with /ss
    ├── specsync-vision-scope/SKILL.md
    ├── specsync-glossary/SKILL.md
    ├── specsync-user-stories/SKILL.md
    ├── specsync-functional-requirements/SKILL.md
    ├── specsync-non-functional-requirements/SKILL.md
    ├── specsync-architecture/SKILL.md
    ├── specsync-data-model/SKILL.md
    ├── specsync-api-spec/SKILL.md
    ├── specsync-code/SKILL.md
    ├── specsync-tests/SKILL.md
    └── _template/SKILL.md             Template for adding custom specialists

.specsync/
└── adapters/                      ← Copy one of these to activate SpecSync in your tool
    ├── copilot.md                 →  .github/copilot-instructions.md
    ├── claude-code.md             →  CLAUDE.md
    ├── kiro.md                    →  .kiro/steering/specsync.md
    └── cursor.mdc                 →  .cursor/rules/specsync.mdc
```

**Skills live in `.agents/skills/`** — a built-in location supported by Copilot CLI,
Claude Code, and other tools. No configuration needed; skills are auto-discovered.

---

## Quick Start

### 1. Copy the skill and config directories into your project

```bash
cp -r .agents /your-project/
cp -r .specsync /your-project/
mkdir -p /your-project/src /your-project/tests
```

### 2. Activate SpecSync for your tool

**GitHub Copilot CLI** — skills are auto-discovered, no setup needed. Use the short alias:
```
/ss add user authentication
```
Or the full name:
```
/specsync add user authentication
```

**Other tools** — copy the adapter once, then trigger with `/ss`:

| Tool | Copy this file | To this location |
|------|---------------|-----------------|
| GitHub Copilot (chat/IDE) | `.specsync/adapters/copilot.md` | `.github/copilot-instructions.md` |
| Claude Code | `.specsync/adapters/claude-code.md` | `CLAUDE.md` |
| Kiro | `.specsync/adapters/kiro.md` | `.kiro/steering/specsync.md` |
| Cursor | `.specsync/adapters/cursor.mdc` | `.cursor/rules/specsync.mdc` |

Then trigger SpecSync explicitly in chat:
```
/ss add user authentication with email and password
```

SpecSync only activates when you write `/ss`. All other requests go to your tool's normal behaviour.

---

## Artifact Ownership

Each specialist owns specific files exclusively. No two specialists write the same file.

| Specialist | Owns |
|-----------|------|
| `specsync-vision-scope` | `specs/01-Vision-and-Scope/` |
| `specsync-glossary` | `specs/02-Glossary/` |
| `specsync-user-stories` | `specs/03-User-Stories/` |
| `specsync-functional-requirements` | `specs/04-Functional-Requirements/` |
| `specsync-non-functional-requirements` | `specs/05-Non-Functional-Requirements/` |
| `specsync-architecture` | `specs/06-Architecture/` |
| `specsync-data-model` | `specs/07-Data-Model/` |
| `specsync-api-spec` | `specs/08-API-Spec/` |
| `specsync-code` | `src/**` |
| `specsync-tests` | `tests/**` |

---

## Adding a Custom Specialist

1. Copy `.agents/skills/_template/SKILL.md` to `.agents/skills/specsync-<name>/SKILL.md`
2. Fill in every section of the template
3. Declare the artifact file(s) this specialist owns (must not overlap with existing specialists)
4. Add a row to the Artifact Map in `.agents/skills/specsync/SKILL.md`
