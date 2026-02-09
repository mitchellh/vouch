# Setup Vouch

Make the `vouch` CLI available on `PATH` for subsequent workflow
steps. Nushell is installed automatically if `nu` is not already
available.

## Usage

```yaml
jobs:
  example:
    runs-on: ubuntu-latest
    steps:
      - uses: mitchellh/vouch/action/setup-vouch@v1

      - run: vouch check someuser
```

### Capturing output

Use `$GITHUB_OUTPUT` to expose the result to later steps:

```yaml
- id: check
  run: echo "status=$(vouch check someuser)" >> "$GITHUB_OUTPUT"

- run: echo "${{ steps.check.outputs.status }}"
```

### Typed arguments

Some commands accept typed flags (e.g. `--vouch-keyword`). Pass them
using Nushell syntax:

```yaml
- run: |
    vouch gh-manage-by-issue 123 456789 \
      --repo owner/repo \
      --vouch-keyword [lgtm approve] \
      --dry-run=false
```
