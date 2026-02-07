# GitHub API utilities and CLI commands for Nu scripts

use file.nu [default-path, "from td", init-file, open-file, "to td"]
use lib.nu [add-user, check-user, denounce-user, remove-user]

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
  --vouched-file: string = ".github/VOUCHED.td", # Path to vouched contributors file in the repo
  --require-vouch = true,      # Require users to be vouched (false = only block denounced)
  --auto-close = false,        # Automatically close PRs from unvouched/denounced users
  --dry-run = true,            # Print what would happen without making changes
] {
  if ($repo | is-empty) {
    error make { msg: "--repo is required" }
  }

  let owner = ($repo | split row "/" | first)
  let repo_name = ($repo | split row "/" | last)

  let pr_data = api "get" $"/repos/($owner)/($repo_name)/pulls/($pr_number)"
  let pr_author = $pr_data.user.login
  let default_branch = $pr_data.base.repo.default_branch

  if ($pr_author | str ends-with "[bot]") {
    print $"($pr_author) is a bot, skipping"
    return "skipped"
  }

  let permission = try {
    api "get" $"/repos/($owner)/($repo_name)/collaborators/($pr_author)/permission" | get permission
  } catch {
    null
  }

  if $permission in ["admin", "write"] {
    print $"($pr_author) is a collaborator with ($permission) access"
    return "vouched"
  }

  let records = try {
    let file_data = api "get" $"/repos/($owner)/($repo_name)/contents/($vouched_file)?ref=($default_branch)"
    $file_data.content | str replace -a "\n" "" | decode base64 | decode utf-8 | from td
  } catch {
    []
  }
  let status = $records | check-user $pr_author --default-platform github

  if $status == "vouched" {
    print $"($pr_author) is in the vouched contributors list"
    return "vouched"
  }

  if $status == "denounced" {
    print $"($pr_author) is denounced"

    if not $auto_close {
      return "closed"
    }

    print "Closing PR"

    let message = "This PR has been automatically closed because the author has been denounced."

    if $dry_run {
      print "(dry-run) Would post comment and close PR"
      return "closed"
    }

    api "post" $"/repos/($owner)/($repo_name)/issues/($pr_number)/comments" {
      body: $message
    }

    api "patch" $"/repos/($owner)/($repo_name)/pulls/($pr_number)" {
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

This PR will be closed automatically. See https://github.com/($owner)/($repo_name)/blob/($default_branch)/CONTRIBUTING.md for more details."

  if $dry_run {
    print "(dry-run) Would post comment and close PR"
    return "closed"
  }

  api "post" $"/repos/($owner)/($repo_name)/issues/($pr_number)/comments" {
    body: $message
  }

  api "patch" $"/repos/($owner)/($repo_name)/pulls/($pr_number)" {
    state: "closed"
  }

  return "closed"
}

# Manage contributor status via issue comments.
#
# This checks if a comment matches a vouch keyword (default: "vouch"),
# denounce keyword (default: "denounce"), or unvouch keyword (default:
# "unvouch"), verifies the commenter has write access, and updates the
# vouched list accordingly.
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
  --vouched-file: string,  # Path to vouched contributors file (default: VOUCHED.td or .github/VOUCHED.td)
  --vouch-keyword: list<string>, # Keywords that trigger vouching (default: ["vouch"])
  --denounce-keyword: list<string>, # Keywords that trigger denouncing (default: ["denounce"])
  --unvouch-keyword: list<string>, # Keywords that trigger unvouching (default: ["unvouch"])
  --allow-vouch = true,   # Enable vouch handling
  --allow-denounce = true, # Enable denounce handling
  --allow-unvouch = true,  # Enable unvouch handling
  --dry-run = true,        # Print what would happen without making changes
] {
  if ($repo | is-empty) {
    error make { msg: "--repo is required" }
  }

  let file = if ($vouched_file | is-empty) {
    let default = default-path
    if ($default | is-empty) {
      ".github/VOUCHED.td"
    } else {
      $default
    }
  } else {
    $vouched_file
  }

  let owner = ($repo | split row "/" | first)
  let repo_name = ($repo | split row "/" | last)
  let issue_data = api "get" $"/repos/($owner)/($repo_name)/issues/($issue_id)"
  let comment_data = api "get" $"/repos/($owner)/($repo_name)/issues/comments/($comment_id)"

  let issue_author = $issue_data.user.login
  let commenter = $comment_data.user.login
  let comment_body = ($comment_data.body | default "" | str trim)

  let vouch_keywords = if ($vouch_keyword | is-empty) { ["vouch"] } else { $vouch_keyword }
  let denounce_keywords = if ($denounce_keyword | is-empty) { ["denounce"] } else { $denounce_keyword }
  let unvouch_keywords = if ($unvouch_keyword | is-empty) { ["unvouch"] } else { $unvouch_keyword }

  let vouch_joined = ($vouch_keywords | str join '|')
  let vouch_pattern = '(?i)^\s*(' ++ $vouch_joined ++ ')(?:\s+@(\S+))?(?:\s+(.+))?$'
  let vouch_match = if $allow_vouch {
    $comment_body | parse -r $vouch_pattern
  } else {
    []
  }
  let is_lgtm = ($vouch_match | is-not-empty)

  let denounce_joined = ($denounce_keywords | str join '|')
  let denounce_pattern = '(?i)^\s*(' ++ $denounce_joined ++ ')(?:\s+@(\S+))?(?:\s+(.+))?$'
  let denounce_match = if $allow_denounce {
    $comment_body | parse -r $denounce_pattern
  } else {
    []
  }
  let is_denounce = ($denounce_match | is-not-empty)

  let unvouch_joined = ($unvouch_keywords | str join '|')
  let unvouch_pattern = '(?i)^\s*(' ++ $unvouch_joined ++ ')(?:\s+@(\S+))?\s*$'
  let unvouch_match = if $allow_unvouch {
    $comment_body | parse -r $unvouch_pattern
  } else {
    []
  }
  let is_unvouch = ($unvouch_match | is-not-empty)

  if not $is_lgtm and not $is_denounce and not $is_unvouch {
    print "Comment does not match any enabled action"
    return "unchanged"
  }

  let permission = try {
    api "get" $"/repos/($owner)/($repo_name)/collaborators/($commenter)/permission" | get permission
  } catch {
    print $"($commenter) does not have collaborator access"
    return "unchanged"
  }

  if not ($permission in ["admin", "write"]) {
    print $"($commenter) does not have write access"
    return "unchanged"
  }

  if not ($file | path exists) {
    init-file $file
  }

  let records = open-file $file

  if $is_lgtm {
    let match = $vouch_match | first
    let target_user = if ($match.capture1? | default "" | is-empty) {
      $issue_author
    } else {
      $match.capture1
    }
    let reason = $match.capture2? | default ""

    let status = $records | check-user $target_user --default-platform github
    if $status == "vouched" {
      print $"($target_user) is already vouched"
      return "unchanged"
    }

    if $dry_run {
      print $"(dry-run) Would add ($target_user) to ($file)"
      return "vouched"
    }

    let new_records = $records | add-user $target_user --default-platform github --details $reason
    $new_records | to td | save -f $file

    # React to the comment with a thumbs up to indicate success, ignoring errors.
    try { react $owner $repo_name $comment_id "+1" }

    print $"Added ($target_user) to vouched contributors"
    return "vouched"
  }

  if $is_denounce {
    let match = $denounce_match | first
    let target_user = if ($match.capture1? | default "" | is-empty) {
      $issue_author
    } else {
      $match.capture1
    }
    let reason = $match.capture2? | default ""

    let status = $records | check-user $target_user --default-platform github
    if $status == "denounced" {
      print $"($target_user) is already denounced"
      return "unchanged"
    }

    if $dry_run {
      let entry = if ($reason | is-empty) { $"-($target_user)" } else { $"-($target_user) ($reason)" }
      print $"(dry-run) Would add ($entry) to ($file)"
      return "denounced"
    }

    let new_records = $records | denounce-user $target_user $reason --default-platform github
    $new_records | to td | save -f $file

    # React to the comment with a thumbs up to indicate success, ignoring errors.
    try { react $owner $repo_name $comment_id "+1" }

    print $"Denounced ($target_user)"
    return "denounced"
  }

  if $is_unvouch {
    let match = $unvouch_match | first
    let target_user = if ($match.capture1? | default "" | is-empty) {
      $issue_author
    } else {
      $match.capture1
    }

    let status = $records | check-user $target_user --default-platform github
    if $status == "unknown" {
      print $"($target_user) is not in the vouched contributors list"
      return "unchanged"
    }

    if $dry_run {
      print $"(dry-run) Would remove ($target_user) from ($file)"
      return "unvouched"
    }

    let new_records = $records | remove-user $target_user --default-platform github
    $new_records | to td | save -f $file

    # React to the comment with a thumbs up to indicate success, ignoring errors.
    try { react $owner $repo_name $comment_id "+1" }

    print $"Removed ($target_user) from vouched contributors"
    return "unvouched"
  }
}

# Manage contributor status via discussion comments.
#
# This checks if a comment matches a vouch keyword (default: "vouch"),
# denounce keyword (default: "denounce"), or unvouch keyword (default:
# "unvouch"), verifies the commenter has write access, and updates the
# vouched list accordingly.
#
# Discussion data is fetched via the GitHub GraphQL API since discussions
# are not available through the REST API.
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
  --vouched-file: string,  # Path to vouched contributors file (default: VOUCHED.td or .github/VOUCHED.td)
  --vouch-keyword: list<string>, # Keywords that trigger vouching (default: ["vouch"])
  --denounce-keyword: list<string>, # Keywords that trigger denouncing (default: ["denounce"])
  --unvouch-keyword: list<string>, # Keywords that trigger unvouching (default: ["unvouch"])
  --allow-vouch = true,   # Enable vouch handling
  --allow-denounce = true, # Enable denounce handling
  --allow-unvouch = true,  # Enable unvouch handling
  --dry-run = true,        # Print what would happen without making changes
] {
  if ($repo | is-empty) {
    error make { msg: "--repo is required" }
  }

  let file = if ($vouched_file | is-empty) {
    let default = default-path
    if ($default | is-empty) {
      ".github/VOUCHED.td"
    } else {
      $default
    }
  } else {
    $vouched_file
  }

  let owner = ($repo | split row "/" | first)
  let repo_name = ($repo | split row "/" | last)

  const gql_dir = (path self | path dirname | path join "gql")
  let query = open -r ([$gql_dir "gh-discussion-comment.gql"] | path join)
  let result = graphql $query --variables {
    owner: $owner,
    repo_name: $repo_name,
    discussion_number: $discussion_number,
    comment_node_id: $comment_node_id,
  }
  let discussion_author = $result.data.repository.discussion.author.login
  let commenter = $result.data.node.author.login
  let body = ($result.data.node.body | default "" | str trim)

  let vouch_keywords = if ($vouch_keyword | is-empty) { ["vouch"] } else { $vouch_keyword }
  let denounce_keywords = if ($denounce_keyword | is-empty) { ["denounce"] } else { $denounce_keyword }
  let unvouch_keywords = if ($unvouch_keyword | is-empty) { ["unvouch"] } else { $unvouch_keyword }

  let vouch_joined = ($vouch_keywords | str join '|')
  let vouch_pattern = '(?i)^\s*(' ++ $vouch_joined ++ ')(?:\s+@(\S+))?(?:\s+(.+))?$'
  let vouch_match = if $allow_vouch {
    $body | parse -r $vouch_pattern
  } else {
    []
  }
  let is_lgtm = ($vouch_match | is-not-empty)

  let denounce_joined = ($denounce_keywords | str join '|')
  let denounce_pattern = '(?i)^\s*(' ++ $denounce_joined ++ ')(?:\s+@(\S+))?(?:\s+(.+))?$'
  let denounce_match = if $allow_denounce {
    $body | parse -r $denounce_pattern
  } else {
    []
  }
  let is_denounce = ($denounce_match | is-not-empty)

  let unvouch_joined = ($unvouch_keywords | str join '|')
  let unvouch_pattern = '(?i)^\s*(' ++ $unvouch_joined ++ ')(?:\s+@(\S+))?\s*$'
  let unvouch_match = if $allow_unvouch {
    $body | parse -r $unvouch_pattern
  } else {
    []
  }
  let is_unvouch = ($unvouch_match | is-not-empty)

  if not $is_lgtm and not $is_denounce and not $is_unvouch {
    print "Comment does not match any enabled action"
    return "unchanged"
  }

  let permission = try {
    api "get" $"/repos/($owner)/($repo_name)/collaborators/($commenter)/permission" | get permission
  } catch {
    print $"($commenter) does not have collaborator access"
    return "unchanged"
  }

  if not ($permission in ["admin", "write"]) {
    print $"($commenter) does not have write access"
    return "unchanged"
  }

  if not ($file | path exists) {
    init-file $file
  }

  let records = open-file $file

  if $is_lgtm {
    let match = $vouch_match | first
    let target_user = if ($match.capture1? | default "" | is-empty) {
      $discussion_author
    } else {
      $match.capture1
    }
    let reason = $match.capture2? | default ""

    let status = $records | check-user $target_user --default-platform github
    if $status == "vouched" {
      print $"($target_user) is already vouched"
      return "unchanged"
    }

    if $dry_run {
      print $"(dry-run) Would add ($target_user) to ($file)"
      return "vouched"
    }

    let new_records = $records | add-user $target_user --default-platform github --details $reason
    $new_records | to td | save -f $file

    try { react-graphql $comment_node_id "+1" }

    print $"Added ($target_user) to vouched contributors"
    return "vouched"
  }

  if $is_denounce {
    let match = $denounce_match | first
    let target_user = if ($match.capture1? | default "" | is-empty) {
      $discussion_author
    } else {
      $match.capture1
    }
    let reason = $match.capture2? | default ""

    let status = $records | check-user $target_user --default-platform github
    if $status == "denounced" {
      print $"($target_user) is already denounced"
      return "unchanged"
    }

    if $dry_run {
      let entry = if ($reason | is-empty) { $"-($target_user)" } else { $"-($target_user) ($reason)" }
      print $"(dry-run) Would add ($entry) to ($file)"
      return "denounced"
    }

    let new_records = $records | denounce-user $target_user $reason --default-platform github
    $new_records | to td | save -f $file

    try { react-graphql $comment_node_id "+1" }

    print $"Denounced ($target_user)"
    return "denounced"
  }

  if $is_unvouch {
    let match = $unvouch_match | first
    let target_user = if ($match.capture1? | default "" | is-empty) {
      $discussion_author
    } else {
      $match.capture1
    }

    let status = $records | check-user $target_user --default-platform github
    if $status == "unknown" {
      print $"($target_user) is not in the vouched contributors list"
      return "unchanged"
    }

    if $dry_run {
      print $"(dry-run) Would remove ($target_user) from ($file)"
      return "unvouched"
    }

    let new_records = $records | remove-user $target_user --default-platform github
    $new_records | to td | save -f $file

    try { react-graphql $comment_node_id "+1" }

    print $"Removed ($target_user) from vouched contributors"
    return "unvouched"
  }
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
