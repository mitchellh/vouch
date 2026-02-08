# Sync Vouch

Download remote `.td` vouch files via HTTP for web-of-trust inheritance.
Files are saved with numeric prefixes (`000-`, `001-`, ...) to preserve
the priority order of the source list. Failed downloads emit a warning
but do not fail the action.

Use the output `vouched-dir` with other vouch actions' `vouched-dir`
input to inherit trust decisions from other projects.

## Usage

```yaml
steps:
  - uses: mitchellh/vouch/action/sync-vouch@main
    id: sync
    with:
      sources: |
        https://raw.githubusercontent.com/org/project/main/.github/VOUCHED.td
        https://raw.githubusercontent.com/org/other/main/.github/VOUCHED.td

  - uses: mitchellh/vouch/action/check-pr@main
    with:
      pr-number: ${{ github.event.pull_request.number }}
      vouched-dir: ${{ steps.sync.outputs.vouched-dir }}
      auto-close: true
    env:
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Inputs

| Name          | Required | Default      | Description                                 |
| ------------- | -------- | ------------ | ------------------------------------------- |
| `sources`     | Yes      |              | Newline-separated list of URLs to .td files |
| `vouched-dir` | No       | `".vouch.d"` | Directory to save downloaded files          |

## Outputs

| Name          | Description                                       |
| ------------- | ------------------------------------------------- |
| `vouched-dir` | Path to the directory containing downloaded files |
