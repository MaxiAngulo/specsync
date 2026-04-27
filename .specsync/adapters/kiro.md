# SpecSync — Kiro Steering Document

> **Steering priority:** On-demand — only activate when the user explicitly writes `/ss`.

This project uses **SpecSync** to keep all software design artifacts and source code always
in sync using a team of specialized AI skills.

---

## Explicit trigger

Only activate SpecSync when the user's message **explicitly starts with `/ss`**.
All other requests are handled by Kiro's normal behaviour — do not intercept them.

---

## SpecSync orchestration procedure

Read `.agents/skills/specsync/SKILL.md` and follow the workflow defined there.

