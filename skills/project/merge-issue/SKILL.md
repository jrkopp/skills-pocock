---
name: merge-issue
description: 'Opens a PR for an implemented issue, waits for CI checks if present, squash merges into the default branch, auto-closes the issue, deletes the remote branch, and removes the local worktree. Runs AFK unless there are merge conflicts or CI failures. Use when a user wants to merge a completed implementation: "/merge-issue 42".'
disable-model-invocation: true
---

# Merge Issue

Take a completed, tested branch and merge it cleanly into the default branch — fully AFK unless something needs human attention.

Usage: `/merge-issue <issue-number>`

---

## Process

### 1. Pre-flight checks

**a. Confirm the issue number was provided.**
If not, stop:
> "Please provide an issue number. Example: `/merge-issue 42`"

**b. Resolve the branch and worktree names.**
Derive from the issue number — check existing worktrees:
```sh
git worktree list
```
Find the worktree whose path contains the issue number (e.g. ends in `-42`). Note:
- Worktree path: `../worktrees/{type}-{slug}-{number}`
- Branch name: `{type}/{slug}-{number}`

If no matching worktree is found, stop:
> "No worktree found for issue #42. Has `/implement-issue 42` been run?"

**c. Confirm the branch is ahead of the default branch.**
From inside the worktree path:
```sh
git fetch origin
git status
```
Confirm there are no uncommitted changes. If there are, stop:
> "There are uncommitted changes on `{branch}`. Please commit or stash them before merging."

**d. Check for merge conflicts.**
```sh
git merge-tree $(git merge-base HEAD origin/main) HEAD origin/main
```
Or attempt a dry-run merge:
```sh
git merge --no-commit --no-ff origin/main
git merge --abort
```
If conflicts are detected, **stop and involve the user**:
> "Merge conflicts detected between `{branch}` and `main`. Here are the conflicting files:
> - `{file1}`
> - `{file2}`
>
> Please resolve these conflicts, commit the resolution, then re-run `/merge-issue 42`."

Do not attempt to resolve conflicts automatically.

### 2. Open the pull request

Push the branch and open the PR:
```sh
git push origin {type}/{slug}-{number}
```

Create the PR with a description that:
- Summarises what was implemented (drawn from the issue body and commit messages)
- Links back to the issue using `Closes #<number>` — this triggers auto-close on merge

```sh
gh pr create \
  --title "{issue title}" \
  --body "## Summary

{brief summary of what was implemented}

## Changes

{list of key changes, drawn from commit messages}

Closes #{number}" \
  --base main \
  --head {type}/{slug}-{number}
```

Note the PR number from the output.

Tell the user:
```
PR opened: #{pr-number} — {title}
{pr-url}
```

### 3. Check for CI / GitHub Actions

```sh
gh pr checks {pr-number}
```

**If no checks exist:** proceed directly to step 4.

**If checks exist:** wait for them to complete:
```sh
gh pr checks {pr-number} --watch
```

- If all checks **pass**: proceed to step 4.
- If any check **fails**: stop and report to the user:
  > "CI checks failed on PR #{pr-number}. Please review the failures before merging:
  > - `{check-name}`: {status}
  > {check-url}
  >
  > Fix the failures on branch `{branch}`, commit with `refs #{number}`, push, then re-run `/merge-issue {number}`."

Do not merge with failing checks.

### 4. Squash merge

Once all checks pass (or no checks exist):

```sh
gh pr merge {pr-number} --squash --delete-branch \
  --subject "{issue title} (#{pr-number})" \
  --body "refs #{issue-number}"
```

Setting `--body "refs #{issue-number}"` makes the squash commit on `main` cross-reference the issue, so the commit appears in the issue timeline. GitHub also auto-appends `(#{pr-number})` in the commit title, giving the squash commit a clickable link back to the PR.

This single command:
- Squash merges all branch commits into one commit on `main`
- Deletes the remote branch automatically
- Auto-closes the issue via `Closes #<number>` in the PR description
- Links the squash commit back to the issue via `refs #<number>` in the commit body
- Links the squash commit back to the PR via `(#{pr-number})` in the commit title

Confirm the merge succeeded and capture the squash commit SHA:
```sh
gh pr view {pr-number} --json state,mergeCommit --jq '{state: .state, sha: .mergeCommit.oid}'
```

Note the squash commit SHA for step 6.

### 5. Clean up the local worktree

Switch to the default branch in the main repo and remove the worktree:
```sh
git worktree remove ../worktrees/{type}-{slug}-{number}
```

If the worktree has unexpected local changes that prevent removal:
```sh
git worktree remove --force ../worktrees/{type}-{slug}-{number}
```

Confirm the worktree is gone:
```sh
git worktree list
```

### 6. Add traceability comment to the issue

Post a closing comment on the issue with explicit links to the PR and squash commit. This makes the issue a complete navigable record — forward to the PR and the exact commit on `main`.

```sh
gh issue comment {number} --body "## Implemented

This issue was resolved and merged.

| | |
|---|---|
| **Pull Request** | #{pr-number} — {pr-url} |
| **Merge Commit** | \`{short-sha}\` — {commit-url} |
| **Branch** | \`{type}/{slug}-{number}\` (deleted after merge) |

All acceptance criteria were covered by passing tests."
```

Where:
- `{short-sha}` = first 7 characters of the squash commit SHA from step 4
- `{commit-url}` = `https://github.com/{owner}/{repo}/commit/{full-sha}`
- `{pr-url}` = the PR URL noted in step 2

### 7. Done

Report completion:

```
Merged and closed issue #42.

PR:            #{pr-number} — {title}  [merged, squash]
Merge commit:  {short-sha}  [refs #42, linked to PR]
Branch:        {type}/{slug}-{number}  [deleted]
Worktree:      ../worktrees/{type}-{slug}-{number}  [removed]
Issue:         #{number}  [auto-closed, comment added]

Traceability:
  Issue  → PR via Development sidebar
  Issue  → commit via closing comment + issue timeline
  PR     → issue via "Closes #42" in description
  PR     → commits via Commits tab + "Merged commit {sha}" on PR page
  Commit → PR via "(#{pr-number})" in commit title
  Commit → issue via "refs #{number}" in commit body

main is up to date.
```
