# Check PR

Check if a PR author is a vouched contributor. Bots and collaborators
with write access are automatically allowed. Denounced users are always
blocked. When `require-vouch` is true (default), unvouched users are
also blocked. Use `auto-close` to close PRs from blocked users.

## Usage

```yaml
on:
  pull_request_target:
    types: [opened, reopened]

permissions:
  contents: read
  pull-requests: write

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: mitchellh/vouch/action/check-pr@main
        with:
          pr-number: ${{ github.event.pull_request.number }}
          auto-close: true
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Inputs

| Name            | Required | Default                | Description                                                |
| --------------- | -------- | ---------------------- | ---------------------------------------------------------- |
| `pr-number`     | Yes      |                        | GitHub PR number                                           |
| `auto-close`    | No       | `"false"`              | Automatically close PRs from unvouched or denounced users  |
| `dry-run`       | No       | `"false"`              | Print what would happen without making changes             |
| `repo`          | No       | Current repository     | Repository in `owner/repo` format                          |
| `require-vouch` | No       | `"true"`               | Require users to be vouched (false = only block denounced) |
| `vouched-dir`   | No       | `""`                   | Directory of inherited .td files for web-of-trust          |
| `vouched-file`  | No       | `".github/VOUCHED.td"` | Path to the vouched contributors file in the repo          |

## Outputs

| Name     | Description                                                |
| -------- | ---------------------------------------------------------- |
| `status` | Result: `skipped` (bot), `vouched`, `allowed`, or `closed` |
