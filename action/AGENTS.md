# GitHub Actions Guide

- Each action lives in its own subdirectory: `action/<name>/action.yml`.
- Don't prefix action names with "gh-" since actions are implicitly GitHub.
- Actions are composite actions using `shell: nu {0}`, not bash.
- Call Nu commands directly; don't use `nu -c` or build up argument lists.
- The vouch module is at `$GITHUB_ACTION_PATH/../../vouch` relative to
  an action subdirectory.
- Don't add a `github-token` input. Callers set `GITHUB_TOKEN` via env
  on their workflow step.
- Order inputs: required first (alphabetical), then optional (alphabetical).
- `--dry-run` defaults to false in actions (the action context implies
  intent to act).
- Each action should have a `README.md` with a usage example,
  inputs/outputs table, and any relevant notes.
- When an action is updated, also update the repo root `README.md` if
  necessary to keep the usage example and documentation in sync.
