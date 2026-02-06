# Manage by Issue

Manage contributor vouch status via issue comments. When a collaborator
with write access comments `lgtm` on an issue, the issue author is added
to the vouched contributors list. When they comment `denounce`, the user
is denounced.

## Usage

```yaml
on:
  issue_comment:
    types: [created]

# Serialize updates to the VOUCHED file.
concurrency:
  group: vouch-manage
  cancel-in-progress: false

permissions:
  contents: write
  issues: write

jobs:
  manage:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: mitchellh/vouch/action/manage-by-issue@main
        with:
          repo: ${{ github.repository }}
          issue-id: ${{ github.event.issue.number }}
          comment-id: ${{ github.event.comment.id }}
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Inputs

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `comment-id` | Yes | | GitHub comment ID |
| `issue-id` | Yes | | GitHub issue number |
| `repo` | Yes | | Repository in `owner/repo` format |
| `allow-denounce` | No | `"true"` | Enable `denounce` handling |
| `allow-vouch` | No | `"true"` | Enable `lgtm` handling |
| `dry-run` | No | `"false"` | Print what would happen without making changes |
| `vouched-file` | No | `""` | Path to vouched contributors file (empty = auto-detect) |

## Outputs

| Name | Description |
|------|-------------|
| `status` | Result: `vouched`, `denounced`, or `unchanged` |

## Comment Syntax

Comments from collaborators with write access are matched:

- **`lgtm`** — vouches for the issue author
- **`denounce`** — denounces the issue author
- **`denounce username`** — denounces a specific user
- **`denounce username reason`** — denounces with a reason

## Commit Behavior

When `dry-run` is `"false"`, the action commits and pushes any changes
to the VOUCHED file automatically. The caller must check out the
repository before using this action.
