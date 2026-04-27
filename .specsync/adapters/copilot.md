# SpecSync — GitHub Copilot Instructions

This project uses **SpecSync** to keep all software design artifacts and source code always
in sync using a team of specialized AI skills.

---

## When to activate SpecSync

Only activate SpecSync when the user's message **explicitly starts with `/ss`** (or `/specsync`).
Do not activate for general feature requests, code questions, or any other message.

---

## How to run SpecSync

### Option A — Copilot CLI (recommended)

```
/specsync <user request>
```

### Option B — Manual orchestration (any Copilot context)

Load `.agents/skills/specsync/SKILL.md` and follow the workflow defined there.

