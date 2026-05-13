---
name: create-issue
description: Creates a single well-specified GitHub issue from a user's description of a bug, feature, enhancement, or refactor. Runs a /grill-me interview to develop deep understanding, drafts a structured issue body, gets user approval, then publishes to GitHub with the correct type and triage labels. Use when a user describes a new issue, bug, feature, enhancement, or refactor they want to track.
disable-model-invocation: true
---

# Create Issue

Turn a user's description into a fully-specified GitHub issue — grilled for clarity, structured for implementation, and ready for `/implement-issue` to pick up.

---

## Process

### 1. Understand the issue type

From the user's prompt, identify which type this is:

| Type | When to use |
|------|-------------|
| `bug` | Something isn't working as expected |
| `feature` | New capability that doesn't exist yet |
| `enhancement` | Improvement to something that already works |
| `refactor` | Code improvement with no user-visible behaviour change |
| `chore` | Maintenance, tooling, or process work |

If unclear, ask before grilling.

### 2. Run /grill-me

Interview the user relentlessly about the issue. The goal is to reach a shared understanding where every significant ambiguity is resolved.

Draw out:

- **For bugs**: exact reproduction steps, expected vs actual behaviour, affected scope
- **For features/enhancements**: who benefits and how, edge cases, what "done" looks like, what's explicitly out of scope
- **For refactors**: what problem the current code causes, what the improved structure looks like, risk areas
- **For chores**: what triggers this, what done looks like, any downstream effects

Ask one question at a time. Recommend an answer for each. If a question can be answered by exploring the codebase, explore instead of asking.

Don't proceed to step 3 until you have enough to write acceptance criteria with confidence.

### 3. Explore the codebase (if relevant)

If the issue touches existing code, read enough to:

- Understand the current behaviour or structure
- Use the project's domain vocabulary from `CONTEXT.md` (if present)
- Respect any relevant decisions in `docs/adr/`
- Identify obvious implementation risks to surface in the issue

Do not start designing the solution — that's `/implement-issue`'s job.

### 4. Draft the issue

Write the issue using the template below. Use the project's domain vocabulary throughout.

<issue-template>

## Summary

One or two sentences describing the issue from the user's perspective. For bugs, describe the broken behaviour. For features/enhancements, describe the outcome the user wants.

## Background

Why this matters. What triggers it. Any relevant context about the current state of the codebase or product. Omit if obvious from the summary.

## Acceptance Criteria

A checklist of conditions that must be true for this issue to be considered done.

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

Each criterion should be verifiable — something you can check or test, not a vague intent.

## Out of Scope

Explicitly list anything that came up during grilling but is NOT part of this issue. This prevents scope creep during `/implement-issue`.

## Notes

Any further context: reproduction steps (bugs), links, prior art in the codebase, known risks, or decisions made during grilling that should be preserved.

</issue-template>

Keep the issue **focused on one unit of work**. If grilling reveals the issue is actually two or more distinct concerns, split it into separate issues rather than writing one large one.

### 5. Present the draft and get approval

Show the user:
- The proposed issue **title**
- The full issue **body** (from the template above)
- The **type label** you intend to apply (`bug`, `feature`, `enhancement`, `refactor`, or `chore`)

Ask: *"Does this capture the issue correctly? Any changes before I publish?"*

Iterate until the user approves. Don't publish without explicit approval.

### 6. Publish to GitHub

Once approved, create the issue:

```sh
gh issue create \
  --title "<title>" \
  --body "<body>" \
  --label "<type-label>,ready-for-build"
```

Apply exactly two labels:
1. The issue type label (`bug`, `feature`, `enhancement`, `refactor`, or `chore`)
2. `ready-for-build` — signals the issue is fully specified and ready for `/implement-issue`

### 7. Confirm

Tell the user:
- The issue number and URL (from `gh` output)
- That it is labelled and ready for `/implement-issue`

Example:

```
Created issue #42: "Add dark mode toggle to settings page"
https://github.com/owner/repo/issues/42

Labelled: feature, ready-for-build
Ready for /implement-issue.
```
