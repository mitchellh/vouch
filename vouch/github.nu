# GitHub API utilities and CLI commands for Nu scripts

use file.nu [default-path, "from td", init-file, open-file, "to td"]
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
  pr_number: int,                                 # GitHub PR number
  --repo (-R): string,                            # Repository in "owner/repo" format (optional in Actions; required otherwise)
  --vouched-file: string = ".github/VOUCHED.td",  # Path to vouched contributors file in the repo
  --require-vouch = true,                         # Require users to be vouched (false = only block denounced)
  --auto-close = false,                           # Automatically close PRs from unvouched/denounced users
  --dry-run = true,                               # Print what would happen without making changes
] {
  let repo_to_use = if ($repo | is-empty) {
    $env.GITHUB_REPOSITORY? | default ""
  } else {
    $repo
  }

  if ($repo_to_use | is-empty) {
    error make { msg: "--repo is required" }
  }

  let owner = ($repo_to_use | split row "/" | first)
  let repo_name = ($repo_to_use | split row "/" | last)

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

    api "post" $"/repos/($owner)/($repo_name)/issues/($pr_number)/comments" { body: $message }
    api "patch" $"/repos/($owner)/($repo_name)/pulls/($pr_number)" { state: "closed" }

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

  api "post" $"/repos/($owner)/($repo_name)/issues/($pr_number)/comments" { body: $message }
  api "patch" $"/repos/($owner)/($repo_name)/pulls/($pr_number)" { state: "closed" }

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
  issue_id: int,                          # GitHub issue number
  comment_id: int,                        # GitHub comment ID
  --repo (-R): string,                    # Repository in "owner/repo" format (optional in Actions; required otherwise)
  --vouched-file: string = "",            # Path to vouched contributors file (default: VOUCHED.td or .github/VOUCHED.td)
  --vouch-keyword: list<string> = [],     # Keywords that trigger vouching (default: ["vouch"])
  --denounce-keyword: list<string> = [],  # Keywords that trigger denouncing (default: ["denounce"])
  --unvouch-keyword: list<string> = [],   # Keywords that trigger unvouching (default: ["unvouch"])
  --allow-vouch = true,                   # Enable vouch handling
  --allow-denounce = true,                # Enable denounce handling
  --allow-unvouch = true,                 # Enable unvouch handling
  --dry-run = true,                       # Print what would happen without making changes
] {
  let repo_to_use = if ($repo | is-empty) {
    $env.GITHUB_REPOSITORY? | default ""
  } else {
    $repo
  }

  if ($repo_to_use | is-empty) {
    error make { msg: "--repo is required" }
  }

  let file = if ($vouched_file | is-empty) {
    let d = default-path
    if ($d | is-empty) { ".github/VOUCHED.td" } else { $d }
  } else {
    $vouched_file
  }

  let owner = ($repo_to_use | split row "/" | first)
  let repo_name = ($repo_to_use | split row "/" | last)
  let issue_data = api "get" $"/repos/($owner)/($repo_name)/issues/($issue_id)"
  let comment_data = api "get" $"/repos/($owner)/($repo_name)/issues/comments/($comment_id)"

  let issue_author = $issue_data.user.login
  let commenter = $comment_data.user.login
  let comment_body = ($comment_data.body | default "" | str trim)

  let vouch_keywords = if ($vouch_keyword | is-empty) { ["vouch"] } else { $vouch_keyword }
  let denounce_keywords = if ($denounce_keyword | is-empty) { ["denounce"] } else { $denounce_keyword }
  let unvouch_keywords = if ($unvouch_keyword | is-empty) { ["unvouch"] } else { $unvouch_keyword }

  let parsed = (parse-comment $comment_body
    --vouch-keyword $vouch_keywords
    --denounce-keyword $denounce_keywords
    --unvouch-keyword $unvouch_keywords
    --allow-vouch=$allow_vouch
    --allow-denounce=$allow_denounce
    --allow-unvouch=$allow_unvouch
  )

  if $parsed.action == null {
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
  let target_user = $parsed.user | default $issue_author
  let reason = $parsed.reason

  if $parsed.action == "vouch" {
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

    try { react $owner $repo_name $comment_id "+1" }

    print $"Added ($target_user) to vouched contributors"
    return "vouched"
  }

  if $parsed.action == "denounce" {
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

    try { react $owner $repo_name $comment_id "+1" }

    print $"Denounced ($target_user)"
    return "denounced"
  }

  if $parsed.action == "unvouch" {
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

    try { react $owner $repo_name $comment_id "+1" }

    print $"Removed ($target_user) from vouched contributors"
    return "unvouched"
  }
}

# Manage contributor status via discussion comments (GraphQL).
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
  discussion_number: int,                 # GitHub discussion number
  comment_node_id: string,                # GraphQL node ID of the comment (e.g. DC_kwDO...)
  --repo (-R): string,                    # Repository in "owner/repo" format (optional in Actions; required otherwise)
  --vouched-file: string = "",            # Path to vouched contributors file (default: VOUCHED.td or .github/VOUCHED.td)
  --vouch-keyword: list<string> = [],     # Keywords that trigger vouching (default: ["vouch"])
  --denounce-keyword: list<string> = [],  # Keywords that trigger denouncing (default: ["denounce"])
  --unvouch-keyword: list<string> = [],   # Keywords that trigger unvouching (default: ["unvouch"])
  --allow-vouch = true,                   # Enable vouch handling
  --allow-denounce = true,                # Enable denounce handling
  --allow-unvouch = true,                 # Enable unvouch handling
  --dry-run = true,                       # Print what would happen without making changes
] {
  let repo_to_use = if ($repo | is-empty) {
    $env.GITHUB_REPOSITORY? | default ""
  } else {
    $repo
  }

  if ($repo_to_use | is-empty) {
    error make { msg: "--repo is required" }
  }

  let file = if ($vouched_file | is-empty) {
    let d = default-path
    if ($d | is-empty) { ".github/VOUCHED.td" } else { $d }
  } else {
    $vouched_file
  }

  let owner = ($repo_to_use | split row "/" | first)
  let repo_name = ($repo_to_use | split row "/" | last)

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

  # FIX: wrap multi-line call in parentheses so Nu parses it
  let parsed = (parse-comment $body
    --vouch-keyword $vouch_keywords
    --denounce-keyword $denounce_keywords
    --unvouch-keyword $unvouch_keywords
    --allow-vouch=$allow_vouch
    --allow-denounce=$allow_denounce
    --allow-unvouch=$allow_unvouch
  )

  if $parsed.action == null {
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
  let target_user = $parsed.user | default $discussion_author
  let reason = $parsed.reason

  if $parsed.action == "vouch" {
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

  if $parsed.action == "denounce" {
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

  if $parsed.action == "unvouch" {
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

# Orchestrate the full management cycle (manage + commit + push) with retries.
export def gh-manage-and-push [
  --type: string,                 # "issue" or "discussion"
  --id: int,                      # issue or discussion number
  --comment-id: string,           # comment ID or node ID
  --repo: string,                 # optional in Actions; required otherwise
  --vouched-file: string,
  --vouch-keyword: list<string>,
  --denounce-keyword: list<string>,
  --unvouch-keyword: list<string>,
  --allow-vouch = true,
  --allow-denounce = true,
  --allow-unvouch = true,
  --dry-run = true,
] {
  let repo_to_use = if ($repo | is-empty) {
    $env.GITHUB_REPOSITORY? | default ""
  } else {
    $repo
  }

  if ($repo_to_use | is-empty) {
    error make { msg: "--repo is required" }
  }

  let file = if ($vouched_file | is-empty) {
    default-path | default ".github/VOUCHED.td"
  } else {
    $vouched_file
  }

  if not $dry_run {
    git config user.name "github-actions[bot]"
    git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
  }

  mut last_status = "unchanged"

  for attempt in 1..5 {
    if $attempt > 1 {
      print $"Push failed, retrying (attempt ($attempt)/5)..."
      git fetch origin main
      git reset --hard origin/main
    }

    # FIX: wrap call in parentheses, and use spaced flags (avoid --repo=$var)
    let status = if $type == "issue" {
      (gh-manage-by-issue ($id | into int) ($comment_id | into int)
        --repo $repo_to_use
        --vouched-file $file
        --vouch-keyword $vouch_keyword
        --denounce-keyword $denounce_keyword
        --unvouch-keyword $unvouch_keyword
        --allow-vouch $allow_vouch
        --allow-denounce $allow_denounce
        --allow-unvouch $allow_unvouch
        --dry-run $dry_run
      )
    } else {
      (gh-manage-by-discussion ($id | into int) $comment_id
        --repo $repo_to_use
        --vouched-file $file
        --vouch-keyword $vouch_keyword
        --denounce-keyword $denounce_keyword
        --unvouch-keyword $unvouch_keyword
        --allow-vouch $allow_vouch
        --allow-denounce $allow_denounce
        --allow-unvouch $allow_unvouch
        --dry-run $dry_run
      )
    }

    $last_status = $status

    if $dry_run or $status == "unchanged" {
      break
    }

    let is_new = (git ls-files $file | str trim | is-empty)
    if $is_new {
      git add $file
    }

    let diff = git diff --quiet $file | complete
    if $diff.exit_code == 0 and not $is_new {
      print "No changes to commit"
      break
    }

    let server_url = ($env.GITHUB_SERVER_URL? | default "https://github.com")
    let url = if $type == "issue" {
      $"($server_url)/($repo_to_use)/issues/($id)#issuecomment-($comment_id)"
    } else {
      $"($server_url)/($repo_to_use)/discussions/($id)#discussioncomment-($comment_id)"
    }

    git add $file
    git commit -m $"Update VOUCHED list\n\n($url)"

    let push_res = git push | complete
    if $push_res.exit_code == 0 {
      break
    }

    if $attempt == 5 {
      print $push_res.stderr
      error make { msg: "Failed to push after 5 attempts" }
    }

    # Jittered backoff: 0.5s to 1.5s
    sleep (1sec * (0.5 + (random float 0.0..1.0)))
  }

  return $last_status
}

# Add a reaction emoji to a GitHub issue comment using the Reactions API.
def react [owner: string, repo: string, comment_id: int, reaction: string] {
  api "post" $"/repos/($owner)/($repo)/issues/comments/($comment_id)/reactions" { content: $reaction }
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
