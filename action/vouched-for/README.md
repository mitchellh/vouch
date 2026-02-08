# Vouched for

GitHub Action that wraps [vouch](https://github.com/mitchellh/vouch): it checks whether a GitHub user is in your vouch list and fails the job if the user is not vouched or is denounced.

## Usage in other repos

1. In your repo, add a **VOUCHED.td** (or `.github/VOUCHED.td`) with one GitHub username per line (see [vouch file format](https://github.com/mitchellh/vouch#vouched-file-format)).

2. In your workflow, call this action. Omit `user` and `ref` to default to the PR author and the PR base branch (or pusher and pushed ref on push).

```yaml
on:
  push:
    branches: [main, master]
  pull_request_target:
    types: [opened, reopened]

jobs:
  vouched-for:
    runs-on: ubuntu-latest
    steps:
      - name: Check user is vouched
        uses: mitchellh/vouch/action/vouched-for@main
```

Optionally pass `user` and/or `ref` to override the defaults.

## Inputs

| Name   | Required | Default   | Description                                                                 |
| ------ | -------- | --------- | --------------------------------------------------------------------------- |
| `user` | No       | PR author or `github.actor` | GitHub username to check (omit to use PR author or pusher)                    |
| `ref`  | No       | (unset)   | Ref to checkout (e.g. `github.event.pull_request.base.ref` or `github.ref`). When set, the action checks against this ref’s VOUCHED file. |

## Behaviour

- Checks out the repository at the given `ref` (if provided), then installs Nushell and clones [mitchellh/vouch](https://github.com/mitchellh/vouch) and runs vouch’s `check` command.
- Looks for **VOUCHED.td** or **.github/VOUCHED.td** in the repository root (the checkout).
- Exit codes: **0** = vouched (pass), **1** = denounced (fail), **2** = unknown (fail).

## Outputs

This action does not set outputs. It fails the step (exit code 1 or 2) when the user is not vouched or is denounced.

## This repo

The **vouched-for** workflow ([.github/workflows/vouched-for.yml](.github/workflows/vouched-for.yml)) in this repo calls the local action (`uses: ./`) with `ref` so the check runs against the target branch’s VOUCHED file on push and pull requests.
