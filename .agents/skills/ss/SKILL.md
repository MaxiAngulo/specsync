---
name: ss
description: Short alias for /specsync. Only invoke when the user explicitly types /ss <request>. Delegates entirely to the SpecSync orchestrator.
---

# /ss — SpecSync short alias

This skill is a short alias for `/specsync`. When invoked, run the full SpecSync orchestrator workflow exactly as if the user had typed `/specsync <request>`.

## What to do

1. Take the user's request (the text following `/ss`)
2. Read `.agents/skills/specsync/SKILL.md` — this is the orchestrator definition
3. Execute the full workflow described there, passing the user's request as the change request

## Important

- Only activate when the user **explicitly writes `/ss`** followed by their request
- Do not activate for any other message
- All orchestration logic is in `.agents/skills/specsync/SKILL.md` — do not duplicate it here
