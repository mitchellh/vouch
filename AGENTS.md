# Agent Development Guide

A file for [guiding coding agents](https://agents.md/).

## General

- See `VOUCHED.example` for an example vouch file.
- Check formatting with `prettier` after every file change.
  - `prettier` is available via Nix if using Nix
- GraphQL should use queries with parameterization in dedicated `.gql` files
  in `vouch/gql`.

## Nu

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
