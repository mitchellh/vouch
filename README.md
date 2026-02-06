# Vouch

A project trust management system. People must be **vouched for** before
interacting with certain parts of a project (the exact parts are
configurable to the project to enforce). People can also be explicitly
**denounced** to block them from interacting with the project.

The implementation is generic and can be used by any project on any code forge,
but we provide GitHub integration out of the box, including a GitHub action
provided by this repository.

The vouch list is maintained in a single flat file using a minimal format
that can be trivially parsed using standard POSIX tools and any programming
language without external libraries.

> [!WARNING]
>
> This is an experimental system in use by [Ghostty](https://github.com/ghostty-org/ghostty).
> We'll continue to improve the system based on experience and feedback.

## Why?

Open source has always worked on a system of _trust and verify_.

Historically, the effort required to understand a codebase, implement
a change, and submit that change for review was high enough that it
naturally filtered out many low quality contributions from unqualified people.
For over 20 years of my life, this was enough for my projects as well
as enough for most others.

Unfortunately, the landscape has changed particularly with the advent
of AI tools that allow people to trivially create plausible-looking but
extremely low-quality contributions with little to no true understanding.
Contributors can no longer be trusted based on the minimal barrier to entry
to simply submit a change.

But, open source still works on trust! And every project has a definite
group of trusted individuals (maintainers) and a larger group of probably
trusted individuals (active members of the community in any form). So,
let's move to an explicit trust model where trusted individuals can vouch
for others, and those vouched individuals can then contribute.

## Vouched File Format

The vouch list is stored in a `.td` file. See
[VOUCHED.example.td](VOUCHED.example.td) for an example. The file is
looked up at `VOUCHED.td` or `.github/VOUCHED.td` by default.

```
# Comments start with #
username
platform:username
-platform:denounced-user
-platform:denounced-user reason for denouncement
```

- One handle per line (without `@`), sorted alphabetically.
- Optionally specify a platform prefix: `platform:username` (e.g., `github:mitchellh`).
- Denounce a user by prefixing with `-`.
- Optionally add details after a space following the handle.

The `from td` and `to td` commands are exported by the module, so
Nushell's `open` command works natively with `.td` files to decode
into structured tables and encode back to the file format with
comments and whitespace preserved.

## CLI Usage

The CLI is implemented as a Nushell module and only requires
Nushell to run. There are no other external dependencies.

### Integrated Help

This is Nushell, so you can get help on any command:

```nu
use vouch *
help add
help check
help denounce
help gh-check-pr
help gh-manage-by-issue
```

### Local Commands

**Check a user's vouch status:**

```bash
vouch check <username>
```

Exit codes: 0 = vouched, 1 = denounced, 2 = unknown.

**Add a user to the vouched list:**

```bash
# Preview new file contents (default)
vouch add someuser

# Write the file in-place
vouch add someuser --write
```

**Denounce a user:**

```bash
# Preview new file contents (default)
vouch denounce badactor

# With a reason
vouch denounce badactor --reason "Submitted AI slop"

# Write the file in-place
vouch denounce badactor --write
```

### GitHub Integration

Requires the `GITHUB_TOKEN` environment variable. If not set and `gh`
is available, the token from `gh auth token` is used.

**Check if a PR author is vouched:**

```bash
# Check PR author status (dry run)
vouch gh-check-pr 123 --repo owner/repo

# Auto-close unvouched PRs (dry run)
vouch gh-check-pr 123 --repo owner/repo --auto-close

# Actually close unvouched PRs
vouch gh-check-pr 123 --repo owner/repo --auto-close --dry-run=false

# Allow unvouched users, only block denounced
vouch gh-check-pr 123 --repo owner/repo --require-vouch=false --auto-close
```

Outputs status: `skipped` (bot/collaborator), `vouched`, `allowed`, or `closed`.

**Manage contributor status via issue comments:**

```bash
# Dry run (default)
vouch gh-manage-by-issue 123 456789 --repo owner/repo

# Actually perform the action
vouch gh-manage-by-issue 123 456789 --repo owner/repo --dry-run=false
```

Responds to comments from collaborators with write access:

- `lgtm` — vouches for the issue author
- `denounce` — denounces the issue author
- `denounce username` — denounces a specific user
- `denounce username reason` — denounces with a reason

Outputs status: `vouched`, `denounced`, or `unchanged`.

## Library Usage

The module also exports a `lib` submodule for scripting:

```nu
use vouch/lib.nu *

let records = open VOUCHED.td
$records | check-user "mitchellh" --default-platform github  # "vouched", "denounced", or "unknown"
$records | add-user "newuser"                                # returns updated table
$records | denounce-user "badactor" "reason"                 # returns updated table
$records | remove-user "olduser"                             # returns updated table
```
