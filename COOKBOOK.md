# Cookbook

Common tasks and step-by-step guides for setting up and using Vouch.
The [README](README.md) covers the basics; this document walks through
real-world scenarios in more detail.

## Integrating with Branch Protection and Rulesets

**This is only required if you have branch protection or ruleset merge
requirements.** If you do not, you do not need to setup a GitHub app.

The default `GITHUB_TOKEN` provided by GitHub Actions cannot be added
to a branch protection or ruleset bypass list. This means workflows
that push commits or merge PRs (like the `manage-by-issue` and
`manage-by-discussion` actions) will fail if your default branch has
merge requirements such as required reviews or status checks.

A **private GitHub App** gives you a named identity that can be added
to the bypass list and works across repositories.

Use a GitHub App when you need any of the following:

- Bypassing branch protection or ruleset merge requirements for
  automated VOUCHED file commits.
- The `manage-by-issue` or `manage-by-discussion` actions with
  `pull-request: true`, especially with `merge-immediately: true`.
- Cross-repo lookups via `vouched-managers-repo`.

### 1. Create the GitHub App

1. Go to **Settings → Developer settings → GitHub Apps → New GitHub App**
   (for an org, go to **Organization Settings → Developer settings →
   GitHub Apps**).
2. Fill in the basics:
   - **Name**: something like `myorg-vouch` (must be globally unique).
   - **Homepage URL**: your repo URL or `https://github.com/mitchellh/vouch`.
   - **Webhook**: uncheck **Active** (you don't need webhook delivery;
     GitHub Actions triggers the workflows).
3. Set **permissions** (Repository permissions only):
   - **Contents**: Read & write (commit VOUCHED file changes).
   - **Issues**: Read & write (close issues, post comments).
   - **Pull requests**: Read & write (create/close PRs, post comments).
   - **Discussions**: Read & write (only if using `manage-by-discussion`).
   - **Metadata**: Read-only (always required).
4. Under **Where can this GitHub App be installed?**, choose
   **Only on this account**.
5. Click **Create GitHub App**.

### 2. Generate a Private Key

1. On the app's settings page, scroll to **Private keys**.
2. Click **Generate a private key**. A `.pem` file downloads.
3. Keep this file safe — you'll store it as a repository secret.

### 3. Install the App

1. From the app's settings page, click **Install App** in the sidebar.
2. Choose your account or organization.
3. Select **Only select repositories** and pick the repo(s) where you
   use Vouch.
4. Click **Install**.

### 4. Store Secrets

In each repository that uses the app:

1. Go to **Settings → Secrets and variables → Actions**.
2. Add two repository secrets:
   - `VOUCH_ID` — the App ID shown on the app's **General** page.
   - `VOUCH_PRIVATE_KEY` — the full contents of the `.pem` file.

### 5. Use the App Token in Workflows

Use a well-known action to mint a short-lived installation token at the
start of each job, then pass it as `GITHUB_TOKEN`:

```yaml
name: Manage by Issue

on:
  issue_comment:
    types: [created]

concurrency:
  group: vouch-manage
  cancel-in-progress: false

permissions: {}

jobs:
  manage:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/create-github-app-token@v2
        id: app-token
        with:
          app-id: ${{ secrets.VOUCH_ID }}
          private-key: ${{ secrets.VOUCH_PRIVATE_KEY }}

      - uses: actions/checkout@v4
        with:
          token: ${{ steps.app-token.outputs.token }}

      - uses: mitchellh/vouch/action/manage-by-issue@v1
        with:
          issue-id: ${{ github.event.issue.number }}
          comment-id: ${{ github.event.comment.id }}
          pull-request: true
        env:
          GITHUB_TOKEN: ${{ steps.app-token.outputs.token }}
```

Key points:

- **`permissions: {}`** — the workflow itself needs no permissions
  since the app token carries its own.
- **Pass the token to `actions/checkout`** so that pushes and PR
  creation use the app identity instead of the default token.
- The same pattern works for `check-pr`, `check-issue`, and
  `manage-by-discussion` — just swap the action and inputs.
