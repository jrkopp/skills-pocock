#!/usr/bin/env pwsh

$RepoRoot = Split-Path -Parent $PSScriptRoot

Get-ChildItem -Path $RepoRoot -Filter SKILL.md -Recurse |
    Where-Object { $_.FullName -notmatch '[\\/]node_modules[\\/]' } |
    ForEach-Object { [System.IO.Path]::GetRelativePath($RepoRoot, $_.FullName) } |
    Sort-Object
