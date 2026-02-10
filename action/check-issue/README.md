# Check Issue

Check if an issue author is a vouched contributor. Bots and
collaborators with write access are automatically allowed. Denounced
users are always blocked. When `require-vouch` is true (default),
unvouched users are also blocked. Use `auto-close` to close issues
from blocked users.

## Usage

```yaml
on:
  issues:
    types: [opened, reopened]

permissions:
  contents: read
  issues: write

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: mitchellh/vouch/action/check-issue@v1
        with:
          issue-number: ${{ github.event.issue.number }}
          auto-close: true
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Inputs

| Name            | Required | Default                | Description                                                  |
| --------------- | -------- | ---------------------- | ------------------------------------------------------------ |
| `issue-number`  | Yes      |                        | GitHub issue number                                          |
| `auto-close`    | No       | `"false"`              | Automatically close issues from unvouched or denounced users |
| `dry-run`       | No       | `"false"`              | Print what would happen without making changes               |
| `repo`          | No       | Current repository     | Repository in `owner/repo` format                            |
| `require-vouch` | No       | `"true"`               | Require users to be vouched (false = only block denounced)   |
| `vouched-file`  | No       | `".github/VOUCHED.td"` | Path to the vouched contributors file in the repo            |

## Outputs

| Name     | Description                                                |
| -------- | ---------------------------------------------------------- |
| `status` | Result: `skipped` (bot), `vouched`, `allowed`, or `closed` |
