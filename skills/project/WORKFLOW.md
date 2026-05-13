# LLM Workflow

## Overview

This is a simple workflow to drive existing software projects to completion.

The workflow:

- LLM agent(s) will be working jointly with a human.
- The agent will used defined skills during this workflow.
- Project management uses a Kanban board approach.
- Uses Github as an issue tracker.
- All skills performed by the agent have a human in the loop component (HITL).
- Issues have three dimensions: type, priority, status

Example:

| Type | Priority | Status |
| ---- | -------- | ------ |
| Bug  | High     | Open   |
| Enhancement | Low | In Progress |
| Feature | Med | Closed |

## Definitions

### Issue Types

| Category    | Meaning                               |
| ----------- | ------------------------------------- |
| bug         | Something isn't working               |
| feature     | New capability                        |
| enhancement | Improve existing capability           |
| refactor    | code improvements and simplifications |
| chore       | Maintenance/process/internal work     |

*Implemented as tags*

### Triage Types

| Category        | Meaning                                    |
| --------------- | ------------------------------------------ |
| needs-info      | Needs further clarification and definition |
| ready-for-build | ready for design and implementation        |
| wontfix         | This will not be worked on                 |
*Implemented as tags*
## setup-existing-project

Establish and document issue tracking and issue life cycle at project start. Done once per project.

- Check for `docs/CODEBASE.md`; if absent, run `/review-codebase` to document the codebase
- Explore project set up and documentation
- Explain what will be configured and why
- Confirm with user
- Create GitHub labels and write `docs/agents/` reference files

Simplified Workflow:

```text
At project start
\setup-existing-project

As each bug/feature/enhancement/refactor is discovered
\create-issue

When build is scheduled
\implement-issue

When implementation is reviewed and approved
\merge-issue
```

## create-issue

- Human prompts AI with description of issue
- AI uses /grill-me skill to clarify and flesh out issue
- AI opens issue in GitHub with type label and `needs-info` triage label
- AI updates triage label to `ready-for-build` once clarified

## implement-issue

- Create new git worktree with branch
- AI generates design/solution and presents to human
- Human reviews and approves design
- AI implements code using /tdd skill (red → green → refactor)
- Human reviews implementation

## merge-issue

Runs AFK unless merge conflicts or CI failures require human intervention.

- AI pushes branch and opens a pull request with `Closes #<number>` in the body
- AI waits for CI / GitHub Actions checks if present; stops and reports if any fail
- AI squash merges PR into default branch
- Issue auto-closes on merge
- AI deletes remote branch and removes local worktree

