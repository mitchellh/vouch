<h1 align="center">Vouch</h1>

<p align="center">
  A community trust management system.
</p>

<p align="center">
  <a href="FAQ.md">FAQ</a> · <a href="COOKBOOK.md">Cookbook</a> · <a href="CONTRIBUTING.md">Contributing</a>
</p>

---

People must be **vouched for** before
interacting with certain parts of a project (the exact parts are
configurable to the project to enforce). People can also be explicitly
**denounced** to block them from interacting with the project.

The implementation is generic and can be used by any project on any code forge,
but we provide **GitHub integration** out of the box via GitHub actions
and the CLI.

The vouch list is maintained in a single flat file using a minimal format
that can be trivially parsed using standard POSIX tools and any programming
language without external libraries.

**Vouch lists can also form a web of trust.** You can configure Vouch to
read other project's lists of vouched or denounced users. This way,
projects with shared values can share their trust decisions with each other
and create a larger, more comprehensive web of trust across the ecosystem.
Users already proven to be trustworthy in one project can automatically
be assumed trustworthy in another project, and so on.

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

## Who is Vouched?

**Who** and **how** someone is vouched or denounced is left entirely up to the
project integrating the system. Additionally, **what** consequences
a vouched or denounced person has is also fully up to the project.
Implement a policy that works for your project and community.

## Usage

### GitHub

Integrating vouch into a GitHub project is easy with the
[provided GitHub Actions](https://github.com/mitchellh/vouch/tree/main/action).
By choosing which actions to use, you can fully control how
users are vouched and what they can or can't do.

For an example, look at this repository! It fully integrates vouch.

Below is a list of the actions and a brief description of their function.
See the linked README in the action directory for full usage details.

| Action                                                        | Trigger               | Description                                                                                                                                                                                |
| ------------------------------------------------------------- | --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [check-issue](action/check-issue/README.md)                   | `issues`              | Check if an issue author is vouched on open or reopen. Bots and collaborators with write access are automatically allowed. Optionally auto-close issues from unvouched or denounced users. |
| [check-pr](action/check-pr/README.md)                         | `pull_request_target` | Check if a PR author is vouched on open or reopen. Bots and collaborators with write access are automatically allowed. Optionally auto-close PRs from unvouched or denounced users.        |
| [check-user](action/check-user/README.md)                     | Any                   | Check if a GitHub user is vouched. Outputs the user's status and fails the step by default if the user is not vouched. Set `allow-fail` to only report via output.                         |
| [manage-by-discussion](action/manage-by-discussion/README.md) | `discussion_comment`  | Let collaborators vouch, denounce, or unvouch users via discussion comments. Updates the vouched file and commits the change.                                                              |
| [manage-by-issue](action/manage-by-issue/README.md)           | `issue_comment`       | Let collaborators vouch or denounce users via issue comments. Updates the vouched file and commits the change.                                                                             |
| [sync-codeowners](action/sync-codeowners/README.md)           | Any                   | Sync CODEOWNERS owners into the vouch list by vouching missing users.                                                                                                                      |
| [setup-vouch](action/setup-vouch/README.md)                   | Any                   | Install the `vouch` CLI on `PATH`. Nushell is installed automatically if not already available.                                                                                            |

### CLI

The CLI is implemented as a Nushell module and only requires
Nushell to run. There are no other external dependencies.

#### Installation

*Using `nu`:*

You can use the CLI via `nu` directly as long as `vouch` is on your library path:

```nu
use vouch *
```

*Using `pixi`:*

`vouch` is available on [conda-forge](https://prefix.dev/conda-forge/vouch).

```bash
pixi global install vouch
# run vouch without installing it
pixi exec vouch
```

#### Integrated Help

This is Nushell, so you can get help on any command:

```nu
use vouch *
help add
help check
help denounce
help gh-check-issue
help gh-check-pr
help gh-manage-by-issue
```

#### Local Commands

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

#### GitHub Integration

Requires the `GITHUB_TOKEN` environment variable. If not set and `gh`
is available, the token from `gh auth token` is used.

**Check if an issue author is vouched:**

```bash
# Check issue author status (dry run)
vouch gh-check-issue 123 --repo owner/repo

# Auto-close unvouched issues (dry run)
vouch gh-check-issue 123 --repo owner/repo --auto-close

# Actually close unvouched issues
vouch gh-check-issue 123 --repo owner/repo --auto-close --dry-run=false

# Allow unvouched users, only block denounced
vouch gh-check-issue 123 --repo owner/repo --require-vouch=false --auto-close
```

Outputs status: `skipped` (bot/collaborator), `vouched`, `allowed`, or `closed`.

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

Responds to comments from collaborators with sufficient role
(admin, maintain, write, or triage by default):

- `vouch` — vouches for the issue author
- `vouch @user` — vouches for a specific user
- `vouch <reason>` — vouches for the issue author with a reason
- `vouch @user <reason>` — vouches for a specific user with a reason
- `denounce` — denounces the issue author
- `denounce @user` — denounces a specific user
- `denounce <reason>` — denounces the issue author with a reason
- `denounce @user <reason>` — denounces a specific user with a reason

Keywords are customizable via `--vouch-keyword` and `--denounce-keyword`.
You can also allow specific managers listed in a separate VOUCHED file
via `--vouched-managers`.

Outputs status: `vouched`, `denounced`, or `unchanged`.

### Library

The module also exports a `lib` submodule for scripting:

```nu
use vouch/lib.nu *

let records = open VOUCHED.td
$records | check-user "mitchellh" --default-platform github  # "vouched", "denounced", or "unknown"
$records | add-user "newuser"                                # returns updated table
$records | denounce-user "badactor" "reason"                 # returns updated table
$records | remove-user "olduser"                             # returns updated table
```

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

> [!NOTE]
>
> **What is `.td`?** This stands for "Trustdown," a play on the
> word "Markdown." I intend to formalize a specification for trust
> lists (with no opinion on how they're created or used) so that software
> systems like this Vouch project and others can coordinate with each
> other. I'm not ready to publish a specification until vouch itself
> stabilizes usage more.
