# Sync Codeowners

Sync CODEOWNERS entries into the VOUCHED list. The action expands any
team owners to their members and adds missing users to the vouch file.

## Usage

```yaml
on:
  schedule:
    - cron: "0 0 * * 1"
  workflow_dispatch:

permissions:
  contents: write
  pull-requests: write

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: mitchellh/vouch/action/sync-codeowners@v1
        with:
          repo: ${{ github.repository }}
```

## Inputs

| Name                | Required | Default   | Description                                                    |
| ------------------- | -------- | --------- | -------------------------------------------------------------- |
| `repo`              | No       | `""`      | Repository in `owner/repo` format (empty = current repository) |
| `codeowners-file`   | No       | `""`      | Path to CODEOWNERS file (empty = auto-detect)                  |
| `commit-message`    | No       | `""`      | Commit message override                                        |
| `merge-immediately` | No       | `"false"` | Merge the pull request immediately after creation              |
| `pull-request`      | No       | `"false"` | Create a pull request instead of pushing directly              |
| `vouched-file`      | No       | `""`      | Path to VOUCHED file (empty = auto-detect)                     |

## Outputs

| Name     | Description                      |
| -------- | -------------------------------- |
| `status` | Result: `updated` or `unchanged` |

## Notes

When `pull-request` is `"true"`, the action creates a branch and opens a
pull request instead of pushing directly. This requires `pull-requests:
write` permission and a token that can create pull requests. The default
`GITHUB_TOKEN` **cannot** create pull requests unless you enable it in
the repository settings.
