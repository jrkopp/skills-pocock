---
name: setup-existing-project
description: Configures an existing project repo for the team's LLM-assisted workflow. Creates GitHub labels, writes docs/agents/ reference files, and adds an Agent skills block to the repo's instructions file. Uses GitHub Issues, the Workflow.md label vocabulary, and single-context domain docs — no choices required. Run once before using /create-issue, /implement-issue, or /merge-issue.
disable-model-invocation: true
---

# Setup Existing Project

Configure this repo for the project's LLM-assisted workflow as defined in `skills/project/WORKFLOW.md`. This skill makes **no choices at runtime** — the issue tracker, labels, and doc layout are all pre-determined by the team's workflow standards. Your job is to explain what is happening and confirm the result with the user, and create any missing components such as labels in GitHub. 

---

## Workflow Context

Before doing anything, explain this to the user:

> **How this project's LLM workflow is structured:**
>
> Four skills drive the whole workflow:
>
> ```
> At project start             →  /setup-existing-project   (this skill, run once)
> For each new issue           →  /create-issue              (grills you for clarity, then opens a GitHub issue)
> When ready to build          →  /implement-issue           (worktree + branch → design → code → tdd tests)
> When implementation is done  →  /merge-issue               (PR → merge → auto-close → worktree cleanup)
> ```
>
> The agent and human work **jointly**. Each skill has human-in-the-loop checkpoints.

---

## Process

### 1. Explore

Read the repo's current state before writing anything.

- `git remote -v` — confirm a GitHub remote exists; note the `owner/repo` slug
- `CLAUDE.md`, `.github/copilot-instructions.md`, and `AGENTS.md` at the repo root — which file exists? Is there already an `## Agent skills` block?
- `docs/agents/` — does output from a prior run already exist?
- `CONTEXT.md` and `docs/adr/` at the repo root
- Run `gh auth status` — confirm the `gh` CLI is authenticated

### 2. Document the codebase

Check whether `docs/CODEBASE.md` already exists.

- **If it does not exist** — run `/review-codebase`. This produces `docs/CODEBASE.md`: a deep reference document covering the project's purpose, solution structure, architecture, every significant module and its public API, tests, configuration files, and key data flows. `/review-codebase` runs fully AFK; wait for it to complete before continuing.
- **If it already exists** — skip this step. Tell the user it was found and will be used as-is.

This document becomes the shared understanding between you and the agent for every subsequent skill invocation in this workflow.

### 3. Explain What Will Be Set Up

Before writing anything, give the user a plain-English summary of what is about to happen. Example:

> **What I'm about to set up:**
>
> 1. **Codebase documentation** — `docs/CODEBASE.md` documents the codebase structure, architecture, and key data flows for both engineers and LLM agents. (Written by `/review-codebase` in step 2, or found pre-existing.)
>
> 2. **Issue tracker** — GitHub Issues for `owner/repo`, using the `gh` CLI. Fixed by the project workflow.
>
> 3. **GitHub labels** — Two groups of labels will be created if they don't already exist:
>    - *Issue type* (what kind of work this is): `bug`, `feature`, `enhancement`, `refactor`, `chore`
>    - *Triage status* (where in the workflow it sits): `needs-info`, `ready-for-build`, `wontfix`
>
>    These come directly from `WORKFLOW.md` and match the vocabulary `/create-issue` and `/implement-issue` will use.
>
> 4. **Workflow reference docs** — Three short files under `docs/agents/` so that the project skills know how to interact with this repo's issues and domain documentation.
>
> 5. **Agent skills block** — An `## Agent skills` section added to your instructions file pointing at those docs.
>
> These choices come from the project's `WORKFLOW.md`. They are not configurable during setup. Edit `docs/agents/*.md` directly if you need to adjust them later.

Confirm with the user before proceeding.

### 4. Create GitHub Labels

Check which labels already exist:

```sh
gh label list --json name --jq '[.[].name]'
```

Create only the missing ones.

**Issue type labels** — apply exactly one per issue to describe the nature of the work:

| Label         | Description                            | Colour    |
|---------------|----------------------------------------|-----------|
| `bug`         | Something isn't working                | `#d73a4a` |
| `feature`     | New capability                         | `#0075ca` |
| `enhancement` | Improve existing capability            | `#a2eeef` |
| `refactor`    | Code improvements and simplifications  | `#e4e669` |
| `chore`       | Maintenance / process / internal work  | `#cfd3d7` |

**Triage labels** — reflect where the issue currently sits in the workflow:

| Label             | Description                                | Colour    |
|-------------------|--------------------------------------------|-----------|
| `needs-info`      | Needs further clarification and definition | `#fbca04` |
| `ready-for-build` | Ready for design and implementation        | `#0e8a16` |
| `wontfix`         | This will not be worked on                 | `#ffffff` |

Create command pattern:

```sh
gh label create "bug" --description "Something isn't working" --color "d73a4a"
```

Tell the user which labels already existed and which were newly created.

### 5. Write docs/agents/ Files

Create `docs/agents/` if it doesn't exist.

If a file already exists (from a prior run), update only the sections that differ — don't overwrite user edits.

---

**`docs/agents/issue-tracker.md`**

```markdown
# Issue Tracker: GitHub

Issues for this repo live in GitHub Issues. Use the `gh` CLI for all operations.

## Conventions

- **Create**: `gh issue create --title "..." --body "..."` (use a heredoc for multi-line bodies)
- **Read**: `gh issue view <number> --comments`
- **List**: `gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'`
- **Comment**: `gh issue comment <number> --body "..."`
- **Label**: `gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **Close**: `gh issue close <number> --comment "..."`

`gh` infers the repo from `git remote -v` when run inside the clone.

## When a skill says "publish to the issue tracker"

Create a GitHub issue.

## When a skill says "fetch the relevant ticket"

Run `gh issue view <number> --comments`.

```

## When a user asks to "open" or "create" an issue, bug, feature, enhancement, refactor

```text
  `\create-issue`
```

## When a user asks to "build" or "code" or "implement" an issue, bug, feature, enhancement, refactor

```text
\implement-issue`
```

## When a user asks to merge an issue

```text
Confirm branch
\merge-issue
```

---

**`docs/agents/triage-labels.md`**

```markdown
# Issue Labels

Labels fall into two groups: **issue type** and **triage status**.

## Issue Type Labels

Apply exactly one type label per issue.

| Label         | Meaning                                |
|---------------|----------------------------------------|
| `bug`         | Something isn't working                |
| `feature`     | New capability                         |
| `enhancement` | Improve existing capability            |
| `refactor`    | Code improvements and simplifications  |
| `chore`       | Maintenance / process / internal work  |

## Triage Labels

Apply the label that reflects where the issue currently sits in the workflow.

| Label             | Meaning                                    |
|-------------------|--------------------------------------------|
| `needs-info`      | Needs further clarification and definition |
| `ready-for-build` | Ready for design and implementation        |
| `wontfix`         | This will not be worked on                 |

## Issue Life Cycle

1. `/create-issue` opens the issue — assigns a type label; triage defaults to `needs-info`
2. `/grill-me` (within `/create-issue`) resolves ambiguity — label changes to `ready-for-build`
3. `/implement-issue` picks it up — creates worktree and branch, implements, tests
4. `/merge-issue` opens PR, merges PR → issue auto-closes, removes `ready-for-build` label
```

---

**`docs/agents/domain.md`**

```markdown
# Domain Docs

How skills should consume this repo's domain documentation before exploring or changing code.

## Before exploring, read these

- **`CONTEXT.md`** at the repo root — project glossary and domain model
- **`docs/adr/`** — read ADRs that touch the area you are about to work in

If either doesn't exist, proceed silently. Don't flag the absence; don't suggest creating them upfront.

## File structure (single-context)

```
/
├── CONTEXT.md
├── docs/adr/
│   └── 0001-...md
└── src/
```

## Use the glossary's vocabulary

When naming domain concepts in issue titles, refactor proposals, or test names, use the term as defined in `CONTEXT.md`. Don't drift to synonyms the glossary avoids.

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly rather than silently overriding:

> _Contradicts ADR-0007 — worth reopening because…_
```

---

### 6. Update the Instructions File

**Pick the file to edit** (in priority order):

1. `CLAUDE.md` — if it exists, edit it
2. `AGENTS.md` — if it exists, edit it
1. `.github/copilot-instructions.md` — if it exists, edit it
4. If none exists — create `.github/copilot-instructions.md`

Never create a second instructions file when one already exists.

If an `## Agent skills` block already exists, update it in-place. Otherwise append it.

```markdown
## Agent skills

### Issue tracker

Issues live in GitHub Issues for this repo. See `docs/agents/issue-tracker.md`.

### Labels

Issue type: `bug`, `feature`, `enhancement`, `refactor`, `chore`.
Triage status: `needs-info`, `ready-for-build`, `wontfix`.
See `docs/agents/triage-labels.md`.

### Workflow skills

- `/create-issue` — uses `/grill-me` to clarify a new issue, then opens it in GitHub
- `/implement-issue` — creates worktree and branch, designs, codes, and tests with `/tdd`
- `/merge-issue` — opens PR, merges, issue auto-closes, removes worktree
- `/grill-me` — stress-test any plan or design before building
- `/write-a-skill` — create or refine skills in `.agents/skills/`

### Domain docs

Single-context repo: `CONTEXT.md` + `docs/adr/` at repo root. See `docs/agents/domain.md`.
```

### 7. Done

Tell the user setup is complete. List what was written and what already existed. Then show the workflow they can use right away:

```
Setup complete. You're ready to use:

  /create-issue     →  describe a bug / feature / enhancement and open a GitHub issue
  /implement-issue  →  create worktree + branch, design, code, and test with /tdd
  /merge-issue      →  open PR, merge, auto-close issue, clean up worktree
  /grill-me         →  stress-test any plan before you build

To adjust labels or docs later, edit docs/agents/*.md directly.
Re-run this skill only if those files are deleted or corrupted.
```
