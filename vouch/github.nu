# GitHub API utilities and CLI commands for Nu scripts

use file.nu [default-path, "from td", init-file, open-file, "to td"]
use git.nu [commit-and-push]
use lib.nu [add-user, check-user, denounce-user, parse-comment, remove-user]

# Check if a PR author is a vouched contributor.
#
# This checks if the PR author is:
#   1. A bot (ends with [bot])
#   2. A collaborator with write access
#   3. In the vouched contributors list
#   4. Denounced
#
# When --require-vouch is true (default), unvouched users are blocked.
# When --require-vouch is false, only denounced users are blocked.
#
# When --auto-close is true and user is unvouched/denounced, the PR is closed.
#
# Outputs status: "skipped" (bot), "vouched", "allowed", or "closed".
#
# Examples:
#
#   # Check PR author status (dry run)
#   ./vouch.nu gh-check-pr 123
#
#   # Auto-close unvouched PRs
#   ./vouch.nu gh-check-pr 123 --auto-close --dry-run=false
#
#   # Allow unvouched users, only block denounced
#   ./vouch.nu gh-check-pr 123 --require-vouch=false --auto-close
#
export def gh-check-pr [
  pr_number: int,              # GitHub PR number
  --repo (-R): string,         # Repository in "owner/repo" format (required)
  --vouched-repo: string,      # Repository for the vouched file (defaults to --repo)
  --vouched-file: string = ".github/VOUCHED.td", # Path to vouched contributors file in the repo
  --require-vouch = true,      # Require users to be vouched (false = only block denounced)
  --auto-close = false,        # Automatically close PRs from unvouched/denounced users
  --dry-run = true,            # Print what would happen without making changes
] {
  if ($repo | is-empty) {
    error make { msg: "--repo is required" }
  }

  let repo_parts = ($repo | split row "/" | {owner: $in.0, name: $in.1})

  let pr_data = api "get" $"/repos/($repo_parts.owner)/($repo_parts.name)/pulls/($pr_number)"
  let pr_author = $pr_data.user.login
  let default_branch = $pr_data.base.repo.default_branch

  let result = (gh-check-user $pr_author
    -R $repo
    --vouched-repo $vouched_repo
    --vouched-file $vouched_file
    --default-branch $default_branch)

  if $result.status == "bot" {
    print $"($pr_author) is a bot, skipping"
    return "skipped"
  }

  if $result.status == "collaborator" {
    print $"($pr_author) is a collaborator with ($result.permission) access"
    return "vouched"
  }

  if $result.status == "vouched" {
    print $"($pr_author) is in the vouched contributors list"
    return "vouched"
  }

  if $result.status == "denounced" {
    print $"($pr_author) is denounced"

    if not $auto_close {
      return "closed"
    }

    print "Closing PR"

    let message = "This PR has been automatically closed because the author is explicitly blocked in the vouch list."

    if $dry_run {
      print "(dry-run) Would post comment and close PR"
      return "closed"
    }

    api "post" $"/repos/($repo_parts.owner)/($repo_parts.name)/issues/($pr_number)/comments" {
      body: $message
    }

    api "patch" $"/repos/($repo_parts.owner)/($repo_parts.name)/pulls/($pr_number)" {
      state: "closed"
    }

    return "closed"
  }

  print $"($pr_author) is not vouched"

  if not $require_vouch {
    print $"($pr_author) is allowed (char lparen)vouch not required(char rparen)"
    return "allowed"
  }

  if not $auto_close {
    return "closed"
  }

  print "Closing PR"

  let message = $"Hi @($pr_author), thanks for your interest in contributing!

  This project requires that pull request authors are vouched, and you are not in the list of vouched users. 

This PR will be closed automatically. See https://github.com/($repo_parts.owner)/($repo_parts.name)/blob/($default_branch)/CONTRIBUTING.md for more details."

  if $dry_run {
    print "(dry-run) Would post comment and close PR"
    return "closed"
  }

  api "post" $"/repos/($repo_parts.owner)/($repo_parts.name)/issues/($pr_number)/comments" {
    body: $message
  }

  api "patch" $"/repos/($repo_parts.owner)/($repo_parts.name)/pulls/($pr_number)" {
    state: "closed"
  }

  return "closed"
}

# Check if an issue reporter is a vouched contributor.
#
# This checks if the issue author is:
#   1. A bot (ends with [bot])
#   2. A collaborator with write access
#   3. In the vouched contributors list
#   4. Denounced
#
# When --require-vouch is true (default), unvouched users are blocked.
# When --require-vouch is false, only denounced users are blocked.
#
# When --auto-close is true and user is unvouched/denounced, the issue is closed.
#
# Outputs status: "skipped" (bot), "vouched", "allowed", or "closed".
#
# Examples:
#
#   # Check issue author status (dry run)
#   ./vouch.nu gh-check-issue 123
#
#   # Auto-close unvouched issues
#   ./vouch.nu gh-check-issue 123 --auto-close --dry-run=false
#
#   # Allow unvouched users, only block denounced
#   ./vouch.nu gh-check-issue 123 --require-vouch=false --auto-close
#
export def gh-check-issue [
  issue_number: int,             # GitHub issue number
  --repo (-R): string,           # Repository in "owner/repo" format (required)
  --vouched-repo: string,        # Repository for the vouched file (defaults to --repo)
  --vouched-file: string = ".github/VOUCHED.td", # Path to vouched contributors file in the repo
  --require-vouch = true,        # Require users to be vouched (false = only block denounced)
  --auto-close = false,          # Automatically close issues from unvouched/denounced users
  --dry-run = true,              # Print what would happen without making changes
] {
  if ($repo | is-empty) {
    error make { msg: "--repo is required" }
  }

  let owner = ($repo | split row "/" | first)
  let repo_name = ($repo | split row "/" | last)

  let issue_data = api "get" $"/repos/($owner)/($repo_name)/issues/($issue_number)"
  let issue_author = $issue_data.user.login
  let default_branch = try { $issue_data.repository.default_branch } catch {
    let repo_data = api "get" $"/repos/($owner)/($repo_name)"
    $repo_data.default_branch
  }

  let result = (gh-check-user $issue_author
    -R $repo
    --vouched-repo $vouched_repo
    --vouched-file $vouched_file
    --default-branch $default_branch)

  if $result.status == "bot" {
    print $"($issue_author) is a bot, skipping"
    return "skipped"
  }

  if $result.status == "collaborator" {
    print $"($issue_author) is a collaborator with ($result.permission) access"
    return "vouched"
  }

  if $result.status == "vouched" {
    print $"($issue_author) is in the vouched contributors list"
    return "vouched"
  }

  if $result.status == "denounced" {
    print $"($issue_author) is denounced"

    if not $auto_close {
      return "closed"
    }

    print "Closing issue"

    let message = "This issue has been automatically closed because the author is explicitly blocked in the vouch list."

    if $dry_run {
      print "(dry-run) Would post comment and close issue"
      return "closed"
    }

    api "post" $"/repos/($owner)/($repo_name)/issues/($issue_number)/comments" {
      body: $message
    }

    api "patch" $"/repos/($owner)/($repo_name)/issues/($issue_number)" {
      state: "closed"
    }

    return "closed"
  }

  print $"($issue_author) is not vouched"

  if not $require_vouch {
    print $"($issue_author) is allowed (char lparen)vouch not required(char rparen)"
    return "allowed"
  }

  if not $auto_close {
    return "closed"
  }

  print "Closing issue"

  let message = $"Hi @($issue_author), thanks for your interest!

  This project requires that issue reporters are vouched, and you are not in the list of vouched users. 

This issue will be closed automatically. See https://github.com/($owner)/($repo_name)/blob/($default_branch)/CONTRIBUTING.md for more details."

  if $dry_run {
    print "(dry-run) Would post comment and close issue"
    return "closed"
  }

  api "post" $"/repos/($owner)/($repo_name)/issues/($issue_number)/comments" {
    body: $message
  }

  api "patch" $"/repos/($owner)/($repo_name)/issues/($issue_number)" {
    state: "closed"
  }

  return "closed"
}

# Manage contributor status via issue comments.
#
# This checks if a comment matches a vouch keyword (default: "vouch"),
# denounce keyword (default: "denounce"), or unvouch keyword (default:
# "unvouch"), verifies the commenter has sufficient permissions, and
# updates the vouched list accordingly.
#
# Permission is checked using role_name from the collaborator API.
# When --roles is empty (default), the legacy permission field is
# also accepted if it is "admin" or "write".
#
# For vouch, the comment can be:
#   - "vouch" - vouches the issue author
#   - "vouch @user" - vouches the specified user
#   - "vouch <reason>" - vouches the issue author with a reason
#   - "vouch @user <reason>" - vouches the specified user with a reason
#
# For denounce, the comment can be:
#   - "denounce" - denounces the issue author
#   - "denounce @user" - denounces the specified user
#   - "denounce <reason>" - denounces the issue author with a reason
#   - "denounce @user <reason>" - denounces the specified user with a reason
#
# For unvouch, the comment can be:
#   - "unvouch" - removes the issue author
#   - "unvouch @user" - removes the specified user
#
# Use --vouch-keyword, --denounce-keyword, and --unvouch-keyword to
# customize the trigger words. Multiple keywords can be specified as a list.
#
# Outputs a status to stdout: "vouched", "denounced", "unvouched", or "unchanged"
#
# Examples:
#
#   # Dry run (default) - see what would happen
#   ./vouch.nu gh-manage-by-issue 123 456789
#
#   # Actually perform the action
#   ./vouch.nu gh-manage-by-issue 123 456789 --dry-run=false
#
#   # Custom vouch keywords
#   ./vouch.nu gh-manage-by-issue 123 456789 --vouch-keyword [lgtm approve]
#
export def gh-manage-by-issue [
  issue_id: int,           # GitHub issue number
  comment_id: int,         # GitHub comment ID
  --repo (-R): string,     # Repository in "owner/repo" format (required)
  --vouched-file: string = "",  # Path to vouched contributors file (default: VOUCHED.td or .github/VOUCHED.td)
  --vouch-keyword: list<string> = [], # Keywords that trigger vouching (default: ["vouch"])
  --denounce-keyword: list<string> = [], # Keywords that trigger denouncing (default: ["denounce"])
  --unvouch-keyword: list<string> = [], # Keywords that trigger unvouching (default: ["unvouch"])
  --allow-vouch = true,   # Enable vouch handling
  --allow-denounce = true, # Enable denounce handling
  --allow-unvouch = true,  # Enable unvouch handling
  --roles: list<string> = [], # Allowed role names (default: [admin maintain write triage])
  --vouched-managers: record, # Optional managers file config
  --commit = true,         # Commit and push changes
  --commit-message: string = "", # Git commit message
  --dry-run = true,        # Print what would happen without making changes
] {
  if ($repo | is-empty) {
    error make { msg: "--repo is required" }
  }

  let file = resolve-vouched-file $vouched_file

  let owner = ($repo | split row "/" | first)
  let repo_name = ($repo | split row "/" | last)
  let issue_data = (
    api "get"
      $"/repos/($owner)/($repo_name)/issues/($issue_id)"
  )
  let comment_data = (
    api "get"
      $"/repos/($owner)/($repo_name)/issues/comments/($comment_id)"
  )

  let issue_author = $issue_data.user.login
  let commenter = $comment_data.user.login
  let comment_body = (
    $comment_data.body | default "" | str trim
  )

  let vouch_keywords = if ($vouch_keyword | is-empty) {
    ["vouch"]
  } else {
    $vouch_keyword
  }
  let denounce_keywords = if ($denounce_keyword | is-empty) {
    ["denounce"]
  } else {
    $denounce_keyword
  }
  let unvouch_keywords = if ($unvouch_keyword | is-empty) {
    ["unvouch"]
  } else {
    $unvouch_keyword
  }

  let parsed = (parse-comment $comment_body
    --vouch-keyword $vouch_keywords
    --denounce-keyword $denounce_keywords
    --unvouch-keyword $unvouch_keywords
    --allow-vouch=$allow_vouch
    --allow-denounce=$allow_denounce
    --allow-unvouch=$allow_unvouch)

  if $parsed.action == null {
    print "Comment does not match any enabled action"
    return "unchanged"
  }

  if not (
    can-manage $commenter $owner $repo_name
      --roles $roles
      --vouched-managers $vouched_managers
  ) {
    print $"($commenter) does not have sufficient access"
    return "unchanged"
  }

  let target_user = $parsed.user | default $issue_author
  let prior = open -r $file
  let result = (gh-apply-action
    $parsed.action $target_user $parsed.reason $file
    --dry-run=$dry_run)

  if $result.acted and $commit {
    (commit-and-push $file
      --message $commit_message
      --retry 3
      --retry-action {
        $prior | save -f $file
        gh-apply-action $parsed.action $target_user $parsed.reason $file
      })
    try { react $owner $repo_name $comment_id "+1" }
  }

  $result.status
}

# Manage contributor status via discussion comments.
#
# This checks if a comment matches a vouch keyword (default: "vouch"),
# denounce keyword (default: "denounce"), or unvouch keyword (default:
# "unvouch"), verifies the commenter has sufficient permissions, and
# updates the vouched list accordingly.
#
# Discussion data is fetched via the GitHub GraphQL API since discussions
# are not available through the REST API.
#
# Permission is checked using role_name from the collaborator API.
# When --roles is empty (default), the legacy permission field is
# also accepted if it is "admin" or "write".
#
# For vouch, the comment can be:
#   - "vouch" - vouches the discussion author
#   - "vouch @user" - vouches the specified user
#   - "vouch <reason>" - vouches the discussion author with a reason
#   - "vouch @user <reason>" - vouches the specified user with a reason
#
# For denounce, the comment can be:
#   - "denounce" - denounces the discussion author
#   - "denounce @user" - denounces the specified user
#   - "denounce <reason>" - denounces the discussion author with a reason
#   - "denounce @user <reason>" - denounces the specified user with a reason
#
# For unvouch, the comment can be:
#   - "unvouch" - removes the discussion author
#   - "unvouch @user" - removes the specified user
#
# Use --vouch-keyword, --denounce-keyword, and --unvouch-keyword to
# customize the trigger words. Multiple keywords can be specified as a list.
#
# Outputs a status to stdout: "vouched", "denounced", "unvouched", or "unchanged"
#
# Examples:
#
#   # Dry run (default) - see what would happen
#   ./vouch.nu gh-manage-by-discussion 42 DC_kwDOExample
#
#   # Actually perform the action
#   ./vouch.nu gh-manage-by-discussion 42 DC_kwDOExample --dry-run=false
#
#   # Custom vouch keywords
#   ./vouch.nu gh-manage-by-discussion 42 DC_kwDOExample --vouch-keyword [lgtm approve]
#
export def gh-manage-by-discussion [
  discussion_number: int,  # GitHub discussion number
  comment_node_id: string, # GraphQL node ID of the comment (e.g. DC_kwDO...)
  --repo (-R): string,     # Repository in "owner/repo" format (required)
  --vouched-file: string = "",  # Path to vouched contributors file (default: VOUCHED.td or .github/VOUCHED.td)
  --vouch-keyword: list<string> = [], # Keywords that trigger vouching (default: ["vouch"])
  --denounce-keyword: list<string> = [], # Keywords that trigger denouncing (default: ["denounce"])
  --unvouch-keyword: list<string> = [], # Keywords that trigger unvouching (default: ["unvouch"])
  --allow-vouch = true,   # Enable vouch handling
  --allow-denounce = true, # Enable denounce handling
  --allow-unvouch = true,  # Enable unvouch handling
  --roles: list<string> = [], # Allowed role names (default: [admin maintain write triage])
  --vouched-managers: record, # Optional managers file config
  --commit = true,         # Commit and push changes
  --commit-message: string = "", # Git commit message
  --dry-run = true,        # Print what would happen without making changes
] {
  if ($repo | is-empty) {
    error make { msg: "--repo is required" }
  }

  let file = resolve-vouched-file $vouched_file

  let owner = ($repo | split row "/" | first)
  let repo_name = ($repo | split row "/" | last)

  const gql_dir = (
    path self | path dirname | path join "gql"
  )
  let query = open -r (
    [$gql_dir "gh-discussion-comment.gql"] | path join
  )
  let result = graphql $query --variables {
    owner: $owner,
    repo_name: $repo_name,
    discussion_number: $discussion_number,
    comment_node_id: $comment_node_id,
  }
  let discussion_author = (
    $result.data.repository.discussion.author.login
  )
  let commenter = $result.data.node.author.login
  let body = (
    $result.data.node.body | default "" | str trim
  )

  let vouch_keywords = if ($vouch_keyword | is-empty) {
    ["vouch"]
  } else {
    $vouch_keyword
  }
  let denounce_keywords = if ($denounce_keyword | is-empty) {
    ["denounce"]
  } else {
    $denounce_keyword
  }
  let unvouch_keywords = if ($unvouch_keyword | is-empty) {
    ["unvouch"]
  } else {
    $unvouch_keyword
  }

  let parsed = (parse-comment $body
    --vouch-keyword $vouch_keywords
    --denounce-keyword $denounce_keywords
    --unvouch-keyword $unvouch_keywords
    --allow-vouch=$allow_vouch
    --allow-denounce=$allow_denounce
    --allow-unvouch=$allow_unvouch)

  if $parsed.action == null {
    print "Comment does not match any enabled action"
    return "unchanged"
  }

  if not (
    can-manage $commenter $owner $repo_name
      --roles $roles
      --vouched-managers $vouched_managers
  ) {
    print $"($commenter) does not have sufficient access"
    return "unchanged"
  }

  let target_user = $parsed.user | default $discussion_author
  let prior = open -r $file
  let result = (gh-apply-action
    $parsed.action $target_user $parsed.reason $file
    --dry-run=$dry_run)

  if $result.acted and $commit {
    (commit-and-push $file
      --message $commit_message
      --retry 3
      --retry-action {
        $prior | save -f $file
        gh-apply-action $parsed.action $target_user $parsed.reason $file
      })
    try { react-graphql $comment_node_id "+1" }
  }

  $result.status
}

# Resolve the vouched file path, falling back to default-path or .github/VOUCHED.td.
def resolve-vouched-file [vouched_file: string] {
  if ($vouched_file | is-not-empty) {
    return $vouched_file
  }

  let default = default-path
  if ($default | is-empty) {
    ".github/VOUCHED.td"
  } else {
    $default
  }
}

# Apply a vouch, denounce, or unvouch action to the vouched file.
#
# Returns a record with:
#   - status: "vouched", "denounced", "unvouched", or "unchanged"
#   - acted: true if a real change was made (not dry-run, not already in desired state)
def gh-apply-action [
  action: string,          # "vouch", "denounce", or "unvouch"
  target_user: string,     # GitHub username to act on
  reason: string,          # Reason for the action (may be empty)
  file: string,            # Path to the vouched file
  --dry-run = false,       # Whether this is a dry run
] {
  if not ($file | path exists) {
    init-file $file
  }

  let records = open-file $file

  if $action == "vouch" {
    let status = $records | check-user $target_user --default-platform github
    if $status == "vouched" {
      print $"($target_user) is already vouched"
      return { status: "unchanged", acted: false }
    }

    if $dry_run {
      print $"(dry-run) Would add ($target_user) to ($file)"
      return { status: "vouched", acted: false }
    }

    let new_records = $records | add-user $target_user --default-platform github --details $reason
    $new_records | to td | save -f $file

    print $"Added ($target_user) to vouched contributors"
    return { status: "vouched", acted: true }
  }

  if $action == "denounce" {
    let status = $records | check-user $target_user --default-platform github
    if $status == "denounced" {
      print $"($target_user) is already denounced"
      return { status: "unchanged", acted: false }
    }

    if $dry_run {
      let entry = if ($reason | is-empty) { $"-($target_user)" } else { $"-($target_user) ($reason)" }
      print $"(dry-run) Would add ($entry) to ($file)"
      return { status: "denounced", acted: false }
    }

    let new_records = $records | denounce-user $target_user $reason --default-platform github
    $new_records | to td | save -f $file

    print $"Denounced ($target_user)"
    return { status: "denounced", acted: true }
  }

  if $action == "unvouch" {
    let status = $records | check-user $target_user --default-platform github
    if $status == "unknown" {
      print $"($target_user) is not in the vouched contributors list"
      return { status: "unchanged", acted: false }
    }

    if $dry_run {
      print $"(dry-run) Would remove ($target_user) from ($file)"
      return { status: "unvouched", acted: false }
    }

    let new_records = $records | remove-user $target_user --default-platform github
    $new_records | to td | save -f $file

    print $"Removed ($target_user) from vouched contributors"
    return { status: "unvouched", acted: true }
  }

  { status: "unchanged", acted: false }
}

# Check if a GitHub user is vouched in the vouch file in the given 
# repository.
#
# Returns a record with:
#   - status: "bot", "collaborator", "vouched", "denounced", or "unknown"
#   - permission: collaborator permission level (only set for "collaborator" status)
#
# By default, collaborator permissions can short-circuit the check. Use
# `--allow-collaborator=false` when you only want file-based status.
export def gh-check-user [
  user: string,            # GitHub username to check
  --repo (-R): string,     # Repository in "owner/repo" format
  --vouched-repo: string,  # Repository for the vouched file (defaults to --repo)
  --vouched-file: string,  # Path to vouched contributors file in the repo
  --vouched-ref: string,   # Git ref for the vouched file (defaults to repo default branch)
  --default-branch: string, # Default branch of the repo (fetched if not set)
  --allow-collaborator = true, # Allow collaborator permissions to short-circuit
] {
  let repo_parts = ($repo | split row "/" | {owner: $in.0, name: $in.1})
  let vr = if ($vouched_repo | default "" | is-empty) { $repo } else { $vouched_repo }
  let vouch_parts = ($vr | split row "/" | {owner: $in.0, name: $in.1})

  # All usernames that end with [bot] are bots and we allow it. The `[]`
  # characters aren't valid at the time of writing this for user accounts.
  if ($user | str ends-with "[bot]") {
    return { status: "bot" }
  }

  # See if this user has special permissions for the target repo.
  if $allow_collaborator {
    let permission = try {
      (api "get"
        $"/repos/($repo_parts.owner)/($repo_parts.name)/collaborators/($user)/permission"
        | get permission)
    } catch {
      null
    }
    if $permission in ["admin", "write"] {
      return { status: "collaborator", permission: $permission }
    }
  }

  let branch = if ($vouched_ref | default "" | is-not-empty) {
    $vouched_ref
  } else if ($default_branch | default "" | is-not-empty) {
    $default_branch
  } else {
    (api "get"
      $"/repos/($vouch_parts.owner)/($vouch_parts.name)"
      | get default_branch)
  }

  # Grab the vouched file contents
  let records = try {
    let file_data = (api "get"
      $"/repos/($vouch_parts.owner)/($vouch_parts.name)/contents/($vouched_file)?ref=($branch)")
    ($file_data.content
      | str replace -a "\n" ""
      | decode base64
      | decode utf-8
      | from td)
  } catch {
    []
  }

  # Check the status using standard lib functions
  let vouch_status = $records | check-user $user --default-platform github
  { status: $vouch_status }
}

# Add a reaction emoji to a GitHub issue comment using the Reactions API.
def react [owner: string, repo: string, comment_id: int, reaction: string] {
  api "post" $"/repos/($owner)/($repo)/issues/comments/($comment_id)/reactions" {
    content: $reaction
  }
}

# Add a reaction emoji to a GitHub node (e.g. discussion comment) using GraphQL.
def react-graphql [node_id: string, reaction: string] {
  let content = match $reaction {
    "+1" => "THUMBS_UP",
    "-1" => "THUMBS_DOWN",
    "laugh" => "LAUGH",
    "confused" => "CONFUSED",
    "heart" => "HEART",
    "hooray" => "HOORAY",
    "rocket" => "ROCKET",
    "eyes" => "EYES",
    _ => ($reaction | str upcase),
  }

  const gql_dir = (path self | path dirname | path join "gql")
  let query = open -r ([$gql_dir "gh-add-reaction.gql"] | path join)
  graphql $query --variables {
    subject_id: $node_id,
    content: $content,
  }
}

# Make a GitHub API request with proper headers
def api [
  method: string,  # HTTP method (get, post, patch, etc.)
  endpoint: string # API endpoint (e.g., /repos/owner/repo/issues/1/comments)
  body?: record    # Optional request body
] {
  let url = $"https://api.github.com($endpoint)"
  let headers = [
    Authorization $"Bearer (get-token)"
    Accept "application/vnd.github+json"
    X-GitHub-Api-Version "2022-11-28"
  ]

  match $method {
    "get" => { http get $url --headers $headers },
    "post" => { http post $url --headers $headers --content-type application/json $body },
    "patch" => { http patch $url --headers $headers --content-type application/json $body },
    _ => { error make { msg: $"Unsupported HTTP method: ($method)" } }
  }
}

# Make a GitHub GraphQL API request.
def graphql [
  query: string          # GraphQL query or mutation string
  --variables: record    # Optional GraphQL variables
] {
  let url = "https://api.github.com/graphql"
  let headers = [
    Authorization $"Bearer (get-token)"
    Accept "application/vnd.github+json"
  ]
  let payload = if ($variables | is-empty) {
    { query: $query }
  } else {
    { query: $query, variables: $variables }
  } | to json

  let response = http post $url --headers $headers --content-type application/json $payload
  if ($response | get -o errors | default null) != null {
    error make { msg: ($response.errors | to json) }
  }
  $response
}

# Get GitHub token from environment or gh CLI (cached in env)
def get-token [] {
  if ($env.GITHUB_TOKEN? | is-not-empty) {
    return $env.GITHUB_TOKEN
  }

  $env.GITHUB_TOKEN = (gh auth token | str trim)
  $env.GITHUB_TOKEN
}

# Check if a given GitHub user can manage vouch status for a vouch
# file in the given target repository.
#
# If `--roles` is specified, only allow users with those specific
# roles to manage vouch status. If `--roles` is NOT explicitly
# specified to a non-empty list, this will default to 
# [admin, maintain, write, triage]. Additionally, the legacy
# permissions [admin, write] are always allowed. If roles is explicitly
# specified, legacy permissions are ignored unless they are explicitly 
# specified.
#
# If `--legacy-permissions` is specified, also check the legacy
# `permission` field of the permission GitHub REST API. If this is not
# specified, the default value is [admin, write] only if `--roles` is
# not set.
#
# If `--vouched-managers` is set, the managers file is also checked.
# Anyone listed as "vouched" in that file can manage vouches.
# The record fields are:
#   - repo: owner/repo for the managers file (empty = target repo)
#   - file: path to the managers VOUCHED file (required)
#   - ref: git ref to read from (empty = default branch)
export def can-manage [
  username: string, # Username of the GitHub user to check
  repo_owner: string, # Repository owner (e.g., "mitchellh") for vouch file
  repo_name: string, # Repository name (e.g., "vouch") for vouch file
  --roles: list<string>, # Roles to allow
  --legacy-permissions: list<string>, # Legacy permissions to allow
  --vouched-managers: record, # Optional managers file config
] {
  let real_roles = $roles | default --empty [
    admin
    maintain
    write
    triage
  ]

  # For legacy perms, we always take the flag value if its non-empty.
  # If it is empty, we set a default only if roles is empty.
  let real_legacy_perms = if (not ($legacy_permissions | is-empty)) {
    $legacy_permissions
  } else if (
    $roles |
    default --empty [] |
    is-empty
  ) {
    [admin, write]
  } else {
    []
  }

  let api_perm = try {
    api "get" $"/repos/($repo_owner)/($repo_name)/collaborators/($username)/permission"
  } catch {
    null
  }

  if $api_perm != null {
    let role_allowed = (($api_perm.role_name in $real_roles)
      or ($api_perm.permission in $real_legacy_perms))
    if $role_allowed {
      return true
    }
  }

  # No managers file configured, so the user isn't eligible.
  if ($vouched_managers | default null) == null {
    return false
  }

  # Managers file is required to evaluate eligibility.
  let file = $vouched_managers.file | default ""
  if ($file | is-empty) {
    return false
  }

  # Check only the managers file; collaborator status shouldn't bypass it.
  let repo = if ($vouched_managers.repo | default "" | is-empty) {
    $"($repo_owner)/($repo_name)"
  } else {
    $vouched_managers.repo
  }
  let result = (gh-check-user $username
    --repo $"($repo_owner)/($repo_name)"
    --vouched-repo $repo
    --vouched-file $file
    --vouched-ref ($vouched_managers.ref | default "")
    --allow-collaborator=false)
  $result.status == "vouched"
}
