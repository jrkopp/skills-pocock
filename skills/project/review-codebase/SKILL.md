---
name: review-codebase
description: Produces a deep reference document (docs/CODEBASE.md) by exploring an existing codebase from first principles. Documents purpose, solution structure, architecture, every significant module and its public API, tests, configuration files, and key data flows. Fully automated — no user input required. Called by /setup-existing-project as an initial step, or run on its own to document a codebase for the first time or refresh an out-of-date document.
disable-model-invocation: true
---

# Review Codebase

Explore the project from first principles and produce `docs/CODEBASE.md` — a permanent, deep reference document for both engineers and LLM agents. The output follows a fixed template so that every skill in the project workflow can rely on it.

This skill runs **fully AFK**: the agent reads, explores, and writes. No questions are asked unless a critical ambiguity prevents the document from being accurate.

---

## Process

### 1. Pre-flight

Before exploring, check the current state:

```sh
git remote -v            # note repo name
ls docs/                 # does docs/CODEBASE.md already exist?
```

If `docs/CODEBASE.md` already exists, note that it will be **overwritten** — it is a generated document, not hand-maintained.

If `docs/` does not exist, create it:

```sh
mkdir -p docs
```

### 2. Establish project identity

Read the key orientation documents to understand what this application does and who uses it:

- `README.md` at the repo root
- Any top-level `ABOUT.md`, `OVERVIEW.md`, or equivalent
- Package/project manifests: `package.json`, `*.csproj`, `*.sln`, `Cargo.toml`, `pom.xml`, `CMakeLists.txt`, `pyproject.toml`, etc.

Determine:
- **What** the application does (from the user's perspective)
- **Who** uses it (end users, developers, other systems)
- **Platform / runtime** it targets (OS, browser, server, embedded, etc.)
- **Language and build toolchain**

This becomes the **Purpose** section.

### 3. Map solution structure

Enumerate all top-level directories and project/package files to understand how the codebase is divided:

- Source projects, libraries, packages, sub-applications
- Test projects
- Build/tooling directories (scripts, CI, Docker, etc.)

Identify the **role** of each component (entry point, shared library, test suite, tooling helper, etc.).

This becomes the **Solution Structure** table.

### 4. Build the architecture diagram

Identify the key runtime components and how they relate:

- Which component creates or owns which other component
- How data flows between the key components at a high level
- Any significant singletons, global state, or shared services

Draw an ASCII architecture diagram. Use boxes (```┌─┐```/```└─┘```) for components and arrows (```→```, ```↓```) or annotated lines (```│ owns```, ```│ creates```) for relationships. Include the entry-point component at the top.

This becomes the **High-Level Architecture** section.

### 5. Document every significant module

For each significant module, class, or file group:

1. Read the header and implementation files
2. Identify its responsibility (one sentence)
3. List every **public** method, function, field, or exported symbol with a one-line description
4. Note design patterns, invariants, or unusual decisions worth preserving
5. Group tightly related files together (e.g., base class + derived classes, header + implementation)

**Section heading format:** `### N. {Module Name} – \`{path/to/file}\``

Prefer a **table of members** for classes:

```markdown
| Method / Member | Description |
|---|---|
| `MethodName(...)` | What it does |
```

Prefer a **table of free functions** for utility files:

```markdown
| Function | Description |
|---|---|
| `FunctionName(...)` | What it does |
```

Number sections sequentially starting from 1. Work through the codebase top-down: entry point → core modules → supporting utilities → tests.

**Minimum coverage:** Every file that contains a class definition, every public API header, every file with more than one public function. Skip generated files, vendored/third-party code, and files with no public symbols.

### 6. Document tests

Treat the test suite as its own module section (the last numbered section in Module Reference).

Produce two tables:

**Test files:**

```markdown
| File | What it tests |
|---|---|
| `FooTests.cpp` | `Foo` construction, method X, edge case Y |
```

**Test infrastructure:**

```markdown
| File | Description |
|---|---|
| `StubFoo.h` | Full stub for `IFoo` — all methods return defaults; tests override via public fields |
| `MockLogger.h` | Captures log calls; asserted in tests that check logging behaviour |
| `TestHelpers.h` | Shared setup utilities |
```

Also note:
- Any compile-time flags that activate test-only code (e.g., `_UNITTEST`, `TESTING`)
- Any `friend` declarations or visibility changes enabled by those flags
- Global test fixtures or setup files

### 7. Document configuration files

Find all configuration files in the repo:

- YAML, JSON, TOML, INI, XML, `.env`, `.config` files that control runtime behaviour
- Distinguish: shipped defaults vs user-modified runtime config vs CI/build config

Produce a table:

```markdown
| File | Description |
|---|---|
| `config/defaults.yaml` | Default values shipped with the application |
| `config/app.yaml` | Live config written by the app (user should not edit directly) |
```

Add a note about where runtime config is stored (e.g., `%LOCALAPPDATA%`, `~/.config/`, beside the executable) if discoverable.

### 8. Trace key data flows

Identify the **2–4 most important runtime flows** through the system. Good candidates:

- The primary user action → response path (e.g., button click → state change → repaint)
- The application startup / initialisation sequence
- Any significant background or async process (e.g., polling loop, event handler)
- The config load and save cycle (if non-trivial)

For each flow, draw a top-down ASCII chain:

```
{Entry point / trigger}
  → {Module A: what it does}
    → {Module B: what it does}
      → {Module C: outcome}
```

Use annotations to clarify what is passed at each step. Keep each flow to one screen — ruthlessly abbreviate to show the critical path.

### 9. Assemble and write docs/CODEBASE.md

Assemble all sections using the template below. Write the file to `docs/CODEBASE.md`.

Do not add commentary, caveats, or "generated by" headers. The document should read as if a senior engineer who knows the codebase wrote it.

### 10. Done

Report completion:

```
docs/CODEBASE.md written.

Sections:
  ✓  Purpose
  ✓  Solution Structure          ({n} projects/packages)
  ✓  High-Level Architecture
  ✓  Module Reference            ({n} modules)
  ✓  Tests                       ({n} test files, {n} infrastructure files)
  ✓  Configuration Files         ({n} files)
  ✓  Key Data Flows              ({n} flows)
```

---

## Output Template

The generated `docs/CODEBASE.md` must follow this structure. Sections are always present; omit a subsection only if there is genuinely nothing to document (e.g., no config files at all).

````markdown
# {Project Name} – Codebase Understanding

## Purpose

{One or two paragraphs. What the application does from the user's perspective. Who uses it. What platform or runtime it targets. Any key non-obvious constraints.}

---

## Solution Structure

| Project | Type | Role |
|---|---|---|
| **{Name}** | {e.g., Win32 GUI application (.exe)} | {Role — entry point, core logic, tests, tooling} |

---

## High-Level Architecture

```
{ASCII diagram. Top-level component at the top. Use ┌─┐└─┘ for boxes, annotated arrows for relationships.}
```

{One or two sentences explaining any key global state or shared services not visible in the diagram.}

---

## Module Reference

### 1. {Module Name} – `{path/to/file.ext}`

{One-sentence description of the module's responsibility. Omit if the name is self-explanatory.}

| Method / Member | Description |
|---|---|
| `{name}` | {description} |

---

### 2. {Module Name} – `{path/to/file.ext}`

... (continue for all modules) ...

---

### N. Tests – `{test-directory/}`

{Brief description of the test suite — framework used, how tests are built.}

| Test File | What it tests |
|---|---|
| `{file}` | {description} |

**Test infrastructure:**

| File | Description |
|---|---|
| `{file}` | {description} |

{Any compile-time flags or visibility changes used by tests.}

---

## Configuration Files

| File | Description |
|---|---|
| `{file}` | {description} |

{Note about runtime config storage location if applicable.}

---

## Key Data Flows

### {Flow name — e.g., "Keyboard → Click (Grid Mode)"}

```
{ASCII chain: entry point → module A → module B → outcome}
```

### {Flow name}

```
{ASCII chain}
```
````
