# Write Permission

**The agent MUST NOT edit, write, create, or update any file without explicit user approval for each change.**

Before modifying any file:
1. Describe exactly what change you intend to make and why
2. Wait for the user to confirm
3. Only then apply the change

This applies to all file types: source files, headers, YAML, RC files, configuration, documentation, and any other file in the repository.

# Build Rules

**The agent MUST NOT perform builds.** All builds are performed by the user via Visual Studio.

- When a build is needed, ask the user to build in Visual Studio and report back results
- Do not invoke MSBuild, cl.exe, or any compiler/linker from the command line
- Do not delete, move, or modify build intermediate files (PDB, PCH, obj, tlog, etc.)

# Overview

- Find reusable skills under `agents/skills`
- This project uses C++20 with MSVC on Windows
- Uses Win32 API and yaml-cpp via vcpkg
- Follow existing code style and local warning suppression conventions
- Prefer consistency with existing architecture and naming patterns
- Minimize unrelated refactoring

# Visual Studio Project Safety Rules

This repository uses Visual Studio solution/project files that must remain stable.

Only the user performs Visual Studio structural operations inside the IDE.

## DO NOT

- create Visual Studio projects
- delete Visual Studio projects
- rename Visual Studio projects
- modify `.sln` files
- modify `.vcxproj` files
- modify `.vcxproj.filters` files
- modify solution configurations
- modify project configurations
- move source files
- rename source files
- delete source files
- create new source files unless explicitly requested
- reorganize directory structure
- change vcpkg configuration unless explicitly requested

## You MAY

- modify existing source files
- add implementation code
- update headers
- add tests
- refactor within existing files
- improve comments/documentation
- suggest new files that the user should create manually
- edit CMake or configuration files only when explicitly requested

# File Creation Workflow

If new files are needed:

1. Propose the file names and locations
2. Wait for the user to create them in Visual Studio
3. Then populate the contents

# Refactoring Rules

- Prefer small, localized changes
- Avoid broad repo-wide edits unless explicitly requested
- Preserve public APIs unless explicitly requested
- Avoid speculative cleanup/refactoring

# Build Safety

- **Do not perform builds** — see Build Rules above
- Do not change compiler flags or warning levels unless explicitly requested
- Preserve existing pragma warning suppressions
- Preserve existing include ordering conventions
- Prefer compatibility with current MSVC toolchain behavior

# Git Safety

- Prefer incremental changes
- Keep diffs focused and reviewable
- Do not amend or rewrite git history unless explicitly requested
