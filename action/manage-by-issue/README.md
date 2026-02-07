# Manage by Issue

Manage contributor vouch status via issue comments. When a collaborator
with write access comments `vouch` on an issue, the issue author is added
to the vouched contributors list. When they comment `denounce`, the user
is denounced. The trigger keywords are configurable.

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

| Name               | Required | Default   | Description                                                            |
| ------------------ | -------- | --------- | ---------------------------------------------------------------------- |
| `comment-id`       | Yes      |           | GitHub comment ID                                                      |
| `issue-id`         | Yes      |           | GitHub issue number                                                    |
| `repo`             | Yes      |           | Repository in `owner/repo` format                                      |
| `allow-denounce`   | No       | `"true"`  | Enable denounce handling                                               |
| `allow-vouch`      | No       | `"true"`  | Enable vouch handling                                                  |
| `denounce-keyword` | No       | `""`      | Comma-separated keywords that trigger denouncing (default: `denounce`) |
| `dry-run`          | No       | `"false"` | Print what would happen without making changes                         |
| `vouch-keyword`    | No       | `""`      | Comma-separated keywords that trigger vouching (default: `vouch`)      |
| `vouched-file`     | No       | `""`      | Path to vouched contributors file (empty = auto-detect)                |

## Outputs

| Name     | Description                                    |
| -------- | ---------------------------------------------- |
| `status` | Result: `vouched`, `denounced`, or `unchanged` |

## Comment Syntax

Comments from collaborators with write access are matched:

- **`vouch`** — vouches for the issue author (customizable via `vouch-keyword`)
- **`vouch @user`** — vouches for a specific user
- **`vouch <reason>`** — vouches for the issue author with a reason
- **`vouch @user <reason>`** — vouches for a specific user with a reason
- **`denounce`** — denounces the issue author (customizable via `denounce-keyword`)
- **`denounce @user`** — denounces a specific user
- **`denounce <reason>`** — denounces the issue author with a reason
- **`denounce @user <reason>`** — denounces a specific user with a reason

## Commit Behavior

When `dry-run` is `"false"`, the action commits and pushes any changes
to the VOUCHED file automatically. The caller must check out the
repository before using this action.
