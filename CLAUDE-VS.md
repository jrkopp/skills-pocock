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

- Do not change compiler flags or warning levels unless explicitly requested
- Preserve existing pragma warning suppressions
- Preserve existing include ordering conventions
- Prefer compatibility with current MSVC toolchain behavior

# Git Safety

- Prefer incremental changes
- Keep diffs focused and reviewable
- Do not amend or rewrite git history unless explicitly requested
