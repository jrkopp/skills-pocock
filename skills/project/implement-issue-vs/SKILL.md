---
name: implement-issue-vs
description: 'Visual Studio variant of /implement-issue. Identical except that new source files are never created autonomously — the skill pauses after design approval for the user to create files in Visual Studio, then populates them. Use this instead of /implement-issue for C++/C# repos managed in Visual Studio.'
disable-model-invocation: true
---

# Implement Issue (Visual Studio)

> **Maintenance note — this is a Visual Studio variant of `/implement-issue`.**
>
> The two skills are identical except for the sections marked `[VS VARIANT]` below:
> - **Step 4 (design):** adds a pre-coding file-creation checkpoint after design approval.
> - **Step 5 (TDD):** adds a guard that pauses before writing to any file that does not yet exist.
>
> When updating `/implement-issue`, apply the same change here **except** within those two sections.
> When updating either VS-specific section, do **not** back-port to `/implement-issue`.

Take a `ready-for-build` GitHub issue from specification to working, tested code — on its own branch and worktree, fully traceable back to the issue.

Usage: `/implement-issue-vs <issue-number>`

This skill runs in **two phases**, each in its own agent session:

- **Phase 1 (this session):** pre-flight, branch creation, worktree creation, handoff.
- **Phase 2 (new session, rooted in the worktree):** context reading, design, TDD, commits, final checks.

---

## Phase detection

Before doing anything, determine which phase this invocation is:

```sh
git branch --show-current
```

- If the current branch matches the pattern `{type}/{slug}-{issue-number}` (e.g. `bug/choose-button-inoperative-42`) — you are already inside the implementation worktree. **Skip directly to Phase 2 (Step 3: Read context).**
- Otherwise you are on `main`/`master` in the main repo. Proceed with Phase 1 (Step 1) below.

---

## Phase 1 — Setup

### 1. Pre-flight checks

**a. Confirm the issue number was provided.**
If no issue number was passed, stop:
> "Please provide an issue number. Example: `/implement-issue-vs 42`
> If the issue doesn't exist yet, run `/create-issue` first."

**b. Check the current branch.**
Run `git branch --show-current`. If the result is not `main` or `master`, stop:
> "You're on branch `<name>`, not `main`/`master`. Please switch to your default branch before starting an implementation."

**c. Fetch the issue.**
```sh
gh issue view <number> --comments
```
Read the full issue body and comments. Confirm it exists and is open. Note:
- Issue **title** (used to name the branch)
- Issue **type label** (`bug`, `feature`, `enhancement`, `refactor`, `chore`)
- **Acceptance criteria** from the issue body

### 2. Create the worktree and branch

**a. Generate the branch name.**

Format: `{type}/{slug}-{number}`

Slug rules:
- Take the issue title
- Lowercase
- Replace spaces and special characters with hyphens
- Remove consecutive hyphens
- Truncate slug to 40 characters

Examples:
- Issue #42 "Choose button inoperative" (bug) → `bug/choose-button-inoperative-42`
- Issue #17 "User feedback page" (feature) → `feature/user-feedback-page-17`

**b. Derive the worktree path.**
Replace the `/` in the branch name with `-` for the filesystem path:
`../worktrees/{type}-{slug}-{number}`

Example: branch `bug/choose-button-inoperative-42` → worktree `../worktrees/bug-choose-button-inoperative-42`

**c. Create the branch and worktree together.**
```sh
git worktree add ../worktrees/{type}-{slug}-{number} -b {type}/{slug}-{number}
```

Confirm success, then tell the user:
```
Worktree created: ../worktrees/bug-choose-button-inoperative-42
Branch: bug/choose-button-inoperative-42
Working directory: ready
```

All subsequent git operations (commits, etc.) are run from inside the worktree path.

### Handoff to Phase 2

Tell the user:

```
Phase 1 complete.

Worktree: ../worktrees/{type}-{slug}-{number}
Branch:   {type}/{slug}-{number}

Next step — start a NEW agent session with its initial directory set to:

    ../worktrees/{type}-{slug}-{number}

Then run /implement-issue-vs {number} in that session.
The new agent will detect it is already in the worktree and begin the
implementation phase (design → code → tests → commit) with a clean context window.

Do NOT continue in this session.
```

**Stop here.** Do not read context or write any code in this session.

---

## Phase 2 — Implementation

*(Runs in a fresh agent session rooted at the worktree directory.)*

> **[VS VARIANT] Write permission**
>
> Before modifying any file, describe the exact change and wait for explicit user approval.
> Apply the change only after the user confirms. This applies to every file without exception.

> **[VS VARIANT] No command-line builds**
>
> The agent MUST NOT invoke MSBuild, cl.exe, or any build tool from the command line.
> When a build is needed, ask the user to build via Visual Studio and report back results.
> Do not delete, move, or modify build intermediate files (PDB, PCH, obj, tlog, etc.).

### 3. Read context

Before designing anything:

- Read `CONTEXT.md` at the repo root (if present) — use its vocabulary throughout
- Read any ADRs in `docs/adr/` that touch the area being changed
- Explore the modules the issue is likely to affect — understand current behaviour and structure

Apply the **deletion test** from `/improve-codebase-architecture` to any module you're about to touch: would deleting it concentrate complexity into callers, or just move it? Look for opportunities to deepen shallow modules while you're in the area.

### 4. Lightweight design

Present a design proposal to the user **before writing any code or tests**. Cover:

**Modules affected**
List every module (file, class, package) that will be modified or deepened (interface change vs implementation change only).

For any module that must be **created** from scratch, list it separately under **New files required** (see below) — do not mark it as modified.

**Interface changes**
For any public interface that changes, describe the before and after in plain English. No code snippets unless a type shape or state machine encodes a decision more precisely than prose can.

**Architectural considerations**
Flag any deepening opportunities spotted during exploration (step 3). Note any ADR conflicts.

**Test plan**
List the specific **behaviours** to be tested (not implementation steps). Prioritise:
1. Acceptance criteria from the issue — each criterion should map to at least one test
2. Edge cases and error paths surfaced during grilling
3. Any regression risk from touching existing modules

You cannot test everything — confirm with the user which behaviours matter most.

Ask the user:
> "Does this design look right? Any changes before I start coding?"

Do not proceed until the user approves the design.

> **[VS VARIANT] File-creation checkpoint**
>
> After the user approves the design, check whether any **new files** are required.
>
> If there are none, proceed directly to Step 5.
>
> If new files are needed, list them and stop:
>
> ```
> Before I begin coding, these files need to be created inside Visual Studio
> (right-click the project → Add → New Item):
>
>   src/Foo.h
>   src/Foo.cpp
>
> Please create them now, then confirm when done.
> ```
>
> **Do not create these files yourself.** Wait for the user's confirmation before
> proceeding. Visual Studio must register the files in `.vcxproj` — creating them
> outside the IDE will leave them out of the build.

### 5. Implement with TDD

Follow the `/tdd` red-green-refactor loop — one vertical slice at a time. **Never write tests in bulk first.**

```
For each behaviour in the approved test plan (priority order):
  RED:   Write one failing test that describes the behaviour through the public interface
  GREEN: Write the minimal code to make it pass
  REPEAT
```

Rules (from `/tdd`):
- Tests verify behaviour through **public interfaces only** — not implementation details
- Only enough code to pass the current test — no speculative features
- A test that breaks on internal refactor (but not behaviour change) is a bad test

> **[VS VARIANT] Build and test via Visual Studio**
>
> After each GREEN step, do NOT run tests from the command line.
> Instead, ask the user to build the solution and run the test suite in Visual Studio,
> then report back results before proceeding to the next slice.

> **[VS VARIANT] Per-file guard**
>
> Before writing code to any file, verify the file already exists on disk:
>
> ```sh
> test -f <path>        # or: Get-Item <path>
> ```
>
> If the file does **not** exist, stop:
>
> ```
> <path> does not exist yet. Please create it in Visual Studio
> (right-click the project → Add → New Item), then confirm when done.
> ```
>
> Wait for confirmation before writing anything. Never use the `create` tool
> on source files — only use `edit` to populate files the user has already
> created in the IDE.

After all acceptance criteria tests pass:

**Refactor pass** (from `/tdd`):
- Extract duplication
- Deepen any shallow modules identified in step 3
- Run tests after each refactor step
- Never refactor while RED

### 6. Commit

Commit completed work from inside the worktree directory. Every commit message must:
- Summarise what changed (imperative mood, ≤72 chars subject line)
- Include `refs #<number>` in the footer — this links the commit to the issue in GitHub

```
git commit -m "Fix choose button click handler not triggering action

refs #42"
```

Commit at logical checkpoints — not necessarily once per test cycle, but at least once per meaningful unit of work. Do not squash everything into one commit.

### 7. Final checks

Before handing off to `/merge-issue`:

- [ ] All acceptance criteria from the issue are covered by passing tests
- [ ] Full test suite passes with no failures
- [ ] No debug code, commented-out blocks, or TODO stubs left in
- [ ] All commits on the branch include `refs #<number>`
- [ ] Domain vocabulary from `CONTEXT.md` is used consistently in code, test names, and comments

### 8. Hand off

Tell the user the implementation is ready:

```
Implementation complete for issue #42.

Branch:   bug/choose-button-inoperative-42
Worktree: ../worktrees/bug-choose-button-inoperative-42
Commits:  3 commits, all referencing #42

All acceptance criteria covered by passing tests.
Run /merge-issue 42 to open the PR, merge, and clean up the worktree.
```
