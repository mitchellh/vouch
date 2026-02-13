# Check User

Check if a GitHub user is a vouched contributor. Bots and collaborators
with write access are automatically allowed. By default the step fails
if the user is denounced or unknown; set `allow-fail` to `true` to
always pass and rely on the `status` output instead.

## Usage

```yaml
on:
  workflow_dispatch:
    inputs:
      user:
        description: "GitHub username to check"
        required: true

permissions:
  contents: read

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - id: vouch
        uses: mitchellh/vouch/action/check-user@v1
        with:
          user: ${{ github.event.inputs.user }}
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      - run: echo "Status is ${{ steps.vouch.outputs.status }}"
```

## Inputs

| Name           | Required | Default                | Description                                            |
| -------------- | -------- | ---------------------- | ------------------------------------------------------ |
| `user`         | Yes      |                        | GitHub username to check                               |
| `allow-fail`   | No       | `"false"`              | Allow the step to pass even if the user is not vouched |
| `repo`         | No       | Current repository     | Repository in `owner/repo` format                      |
| `vouched-file` | No       | `".github/VOUCHED.td"` | Path to the vouched contributors file in the repo      |
| `vouched-repo` | No       | Same as `repo`         | Repository for the vouched file in `owner/repo` format |

## Outputs

| Name      | Description                                                         |
| --------- | ------------------------------------------------------------------- |
| `status`  | Result: `bot`, `collaborator`, `vouched`, `denounced`, or `unknown` |
| `vouched` | `true` if the user is vouched (includes bot and collaborator)       |
