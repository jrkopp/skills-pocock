#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Links active skills into an agent's skills directory for CLI discovery.

.DESCRIPTION
    Accepts an agent name (copilot or claude) and creates relative symbolic
    links in the agent's skills directory, giving the agent CLI a flat
    one-level skills view without changing the bucketed layout under skills/.

    Also creates the agent's instructions symlink:
      copilot: .github/copilot-instructions.md -> ../AGENTS.md
      claude:  CLAUDE.md -> AGENTS.md

    NOTE: Creating symbolic links on Windows requires either Administrator
    privileges or Developer Mode enabled (Settings > System > For developers).

.PARAMETER Agent
    The agent to link skills for. Must be 'copilot' or 'claude'.

.EXAMPLE
    .\link-copilot-skills.ps1 -Agent copilot
    .\link-copilot-skills.ps1 -Agent claude
#>

param(
    [Parameter(Mandatory)]
    [ValidateSet('copilot', 'claude')]
    [string]$Agent
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot      = Split-Path -Parent $PSScriptRoot
$SkillsRoot    = Join-Path $RepoRoot 'skills'
$ActiveBuckets = 'engineering', 'productivity', 'project', 'misc'

# --- Agent-specific paths ---
switch ($Agent) {
    'copilot' {
        $AgentSkillsDir     = Join-Path $RepoRoot '.github\skills'
        $InstructionsLink   = Join-Path $RepoRoot '.github\copilot-instructions.md'
        $InstructionsTarget = '..\AGENTS.md'
    }
    'claude' {
        $AgentSkillsDir     = Join-Path $RepoRoot '.claude\skills'
        $InstructionsLink   = Join-Path $RepoRoot 'CLAUDE.md'
        $InstructionsTarget = 'AGENTS.md'
    }
}

$AgentSkillsDirRel = [System.IO.Path]::GetRelativePath($RepoRoot, $AgentSkillsDir)

# --- Ensure agent skills directory exists ---
if (-not (Test-Path $AgentSkillsDir -PathType Container)) {
    New-Item -ItemType Directory -Path $AgentSkillsDir -Force | Out-Null
    Write-Host "Created: $AgentSkillsDirRel"
} elseif ((Get-Item $AgentSkillsDir -Force).LinkType -eq 'SymbolicLink') {
    throw "$AgentSkillsDirRel is a symbolic link. Remove it first then re-run."
}

# --- Link each skill directory ---
$linked  = 0
$skipped = 0

foreach ($bucket in $ActiveBuckets) {
    $bucketPath = Join-Path $SkillsRoot $bucket

    if (-not (Test-Path $bucketPath -PathType Container)) {
        Write-Warning "Bucket not found, skipping: skills/$bucket"
        continue
    }

    foreach ($dir in Get-ChildItem $bucketPath -Directory) {
        if (-not (Test-Path (Join-Path $dir.FullName 'SKILL.md'))) {
            continue
        }

        $linkPath  = Join-Path $AgentSkillsDir $dir.Name
        # Relative from <agent-dir>/skills/<name>: up two levels to repo root, then into skills/<bucket>/<name>
        $relTarget = "..\..\skills\$bucket\$($dir.Name)"

        if (Test-Path $linkPath -PathType Any) {
            Write-Warning "$($dir.Name) skill already exists, skipping"
            $skipped++
            continue
        }

        New-Item -ItemType SymbolicLink -Path $linkPath -Target $relTarget | Out-Null
        Write-Host "  linked: $AgentSkillsDirRel\$($dir.Name) -> $relTarget"
        $linked++
    }
}

Write-Host ""
Write-Host "Skills: $linked linked, $skipped skipped"
Write-Host ""

# --- Instructions symlink ---
$InstructionsLinkRel = [System.IO.Path]::GetRelativePath($RepoRoot, $InstructionsLink)

if (Test-Path $InstructionsLink -PathType Any) {
    Write-Warning "$InstructionsLinkRel exists, no symbolic link made"
} else {
    New-Item -ItemType SymbolicLink -Path $InstructionsLink -Target $InstructionsTarget | Out-Null
    Write-Host "  linked: $InstructionsLinkRel -> $InstructionsTarget"
}
