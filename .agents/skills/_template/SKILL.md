---
name: specsync-custom-specialist
description: Template for a custom SpecSync specialist skill. Replace this description with a trigger phrase that tells Copilot when to invoke this skill.
---

# SpecSync — Custom Specialist Template

> **Instructions:** Copy this directory to `.agents/skills/specsync-<your-name>/`. Edit `SKILL.md`:
> 1. Update the frontmatter `name` (lowercase, hyphenated, must start with `specsync-`)
> 2. Update the frontmatter `description` (the trigger phrase for Copilot)
> 3. Fill in each section below
> 4. Register the skill in `.github/skills/specsync/SKILL.md`'s Artifact Map table

---

## Your Artifacts

**Owns:** `specs/<your-artifact>.md` *(exact path — no other specialist may write this)*
**Reads:** Summaries of all other artifacts for context

## When to Propose Changes

Propose an updated artifact when the request:
- [ TODO: list the triggers for this specialist ]

Do **not** propose changes for:
- [ TODO: list exclusions — what this specialist should ignore ]

## How to Evaluate

1. Read the full content of your owned artifact
2. Read compact summaries of all other artifacts
3. Read the planning brief from the orchestrator
4. Ask: *Does this request require an update to my artifact?*
5. If yes → write the complete updated document
6. If no → return `changed: false`

## Document Format

```markdown
# <Artifact Title>

[ TODO: describe the expected structure and content of the artifact ]
```

## Output

```json
{
  "agent_type": "<your-agent-type>",
  "changed": true,
  "reasoning": "Explain what changed and why.",
  "artifacts": {
    "specs/<your-artifact>.md": "# Artifact Title\n\n..."
  }
}
```

If no change is needed:
```json
{
  "agent_type": "<your-agent-type>",
  "changed": false,
  "reasoning": "Explain why no change is needed.",
  "artifacts": {}
}
```

## Rules

- Only include your owned file(s) in `artifacts`
- Return **complete** file content, not a diff
- If `changed` is `false`, `artifacts` must be `{}`
- [ TODO: add any domain-specific consistency rules ]
