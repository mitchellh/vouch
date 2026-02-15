# Agent Development Guide

A file for [guiding coding agents](https://agents.md/).

## General

- See `VOUCHED.example` for an example vouch file.
- Clean up formatting with `prettier -w .` after every file change.
  - `prettier` is available via Nix if using Nix
- GraphQL should use queries with parameterization in dedicated `.gql` files
  in `vouch/gql`.

## Nu

- Try to limit line length to ~70 characters if an expression
  can be split in a readable way across multiple lines. Don't split
  strings in non-ergonomic ways just to fit within the line length limit.
- The order of definitions in Nu files should be:
  (1) Exported definitions (alphabetically sorted)
  (2) Helper commands (exported, alphabetically sorted)
  (3) Helper commands (non exported)
- Verify help output using `use <module> *; help <def>`. Everything
  must have human-friendly help output.
- All CLI commands must have a `--dry-run` option that is default on.
- CLI commands that do not modify external state don't need a `--dry-run` option.
- `mod.nu` should only use and export definitions, it should not
  contain any definitions itself.
- Run tests after every change with `nu tests/run.nu`.
- Tests can be filtered with the `--filter` option.

## GitHub Integration (github.nu)

- Prefer GraphQL to limit REST requests if possible.
- GraphQL bodies go into `vouch/gql/*.gql`.
- If `gh` is available, test `gh-*` functions by running them with dry-run
  against discovered content from the `mitchellh/vouch` repo.
- When a `gh-` function is modified, check if the actions in `action/`
  need to be updated.
