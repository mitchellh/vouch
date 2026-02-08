# Manage by Discussion

Manage contributor vouch status via discussion comments. When a collaborator
with write access comments `vouch` on a discussion, the discussion author is
added to the vouched contributors list. When they comment `denounce`, the user
is denounced. When they comment `unvouch`, the user is removed from the list
entirely. The trigger keywords are configurable.

Discussion data (comment body, commenter, discussion author) is fetched via
the GitHub GraphQL API since discussions are not available through the REST API.

## Usage

```yaml
on:
  discussion_comment:
    types: [created]

# Serialize updates to the VOUCHED file.
concurrency:
  group: vouch-manage
  cancel-in-progress: false

permissions:
  contents: write
  discussions: write

jobs:
  manage:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: mitchellh/vouch/action/manage-by-discussion@v1
        with:
          discussion-number: ${{ github.event.discussion.number }}
          comment-node-id: ${{ github.event.comment.node_id }}
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Inputs

| Name                | Required | Default   | Description                                                            |
| ------------------- | -------- | --------- | ---------------------------------------------------------------------- |
| `comment-node-id`   | Yes      |           | GraphQL node ID of the discussion comment                              |
| `discussion-number` | Yes      |           | Discussion number                                                      |
| `allow-denounce`    | No       | `"true"`  | Enable denounce handling                                               |
| `allow-unvouch`     | No       | `"true"`  | Enable unvouch handling                                                |
| `allow-vouch`       | No       | `"true"`  | Enable vouch handling                                                  |
| `denounce-keyword`  | No       | `""`      | Comma-separated keywords that trigger denouncing (default: `denounce`) |
| `dry-run`           | No       | `"false"` | Print what would happen without making changes                         |
| `repo`              | No       | `""`      | Repository in `owner/repo` format (default: current repository)        |
| `unvouch-keyword`   | No       | `""`      | Comma-separated keywords that trigger unvouching (default: `unvouch`)  |
| `vouch-keyword`     | No       | `""`      | Comma-separated keywords that trigger vouching (default: `vouch`)      |
| `vouched-file`      | No       | `""`      | Path to vouched contributors file (empty = auto-detect)                |

## Outputs

| Name     | Description                                                 |
| -------- | ----------------------------------------------------------- |
| `status` | Result: `vouched`, `denounced`, `unvouched`, or `unchanged` |

## Comment Syntax

Comments from collaborators with write access are matched:

- **`vouch`** — vouches for the discussion author (customizable via `vouch-keyword`)
- **`vouch @user`** — vouches for a specific user
- **`vouch <reason>`** — vouches for the discussion author with a reason
- **`vouch @user <reason>`** — vouches for a specific user with a reason
- **`denounce`** — denounces the discussion author (customizable via `denounce-keyword`)
- **`denounce @user`** — denounces a specific user
- **`denounce <reason>`** — denounces the discussion author with a reason
- **`denounce @user <reason>`** — denounces a specific user with a reason
- **`unvouch`** — removes the discussion author (customizable via `unvouch-keyword`)
- **`unvouch @user`** — removes a specific user

## Commit Behavior

When `dry-run` is `"false"`, the action commits and pushes any changes
to the VOUCHED file automatically. The caller must check out the
repository before using this action.
