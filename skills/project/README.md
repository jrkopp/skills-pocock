# Project

Skills for LLM-assisted project workflow on an existing codebase. Run these in order when onboarding a project, then use `create-issue → implement-issue → merge-issue` as the repeating development loop.

- **[setup-existing-project](./setup-existing-project/SKILL.md)** — Configure a repo for the LLM workflow: document the codebase, create GitHub labels, write `docs/agents/` reference files, and add an Agent skills block to the instructions file. Run once per project.
- **[review-codebase](./review-codebase/SKILL.md)** — Explore an existing codebase and produce `docs/CODEBASE.md`: purpose, solution structure, architecture diagram, deep module reference with public APIs, tests, configuration files, and key data flows. Fully automated. Called by `/setup-existing-project` if `docs/CODEBASE.md` is absent.
- **[create-issue](./create-issue/SKILL.md)** — Turn a user's description into a fully-specified GitHub issue. Grills for clarity, drafts a structured issue body, gets user approval, then publishes with type and `ready-for-build` labels.
- **[implement-issue](./implement-issue/SKILL.md)** — Pick up a `ready-for-build` issue and implement it: create a git worktree and branch, lightweight design review, TDD code, commit with full traceability back to the issue.
- **[implement-issue-vs](./implement-issue-vs/SKILL.md)** — Visual Studio variant of `/implement-issue`. Identical except new source files are never created autonomously — pauses after design approval for the user to create files in Visual Studio, then populates them.
- **[merge-issue](./merge-issue/SKILL.md)**— Open a PR, wait for CI checks, squash merge, delete the branch and worktree, and post a traceability comment on the issue. Runs AFK unless merge conflicts or CI failures require human review.
