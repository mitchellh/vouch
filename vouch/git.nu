# Non-forge-specific git operations

# Commit and push changes to a vouched file.
#
# Configures git authorship as github-actions[bot], stages the file,
# and pushes. If there are no changes to commit, this is a no-op.
#
# When `--branch` is set, a new branch is created from HEAD
# before committing. The generated branch name is returned so
# the caller can open a pull request.
#
# When `--retry` is set, push failures are retried after a
# rebase. If `--retry-action` is also provided, the closure is
# invoked after each rebase to re-apply file changes.
export def commit-and-push [
  file: string,              # Path to the vouched file
  --message: string = "",    # Commit message (default: "Update VOUCHED list")
  --branch: string = "",     # Create a new branch with this prefix (e.g. "vouch/")
  --retry: int = 0,          # Max retry attempts on push failure (0 = no retry)
  --retry-action: closure,   # Closure to re-apply changes after rebase
] {
  # Create the branch once so retries push the same name.
  let branch_name = if ($branch | is-not-empty) {
    let name = $branch + (random uuid | str substring 0..8)
    git checkout -b $name

    # Set it up so that `git push` just works.
    git config $"branch.($name).remote" origin
    git config $"branch.($name).merge" $"refs/heads/($name)"
    $name
  } 

  if $retry < 1 {
    push $file --message $message
    return $branch_name
  }

  mut last_err = null
  for attempt in 1..($retry) {
    let push_err = try {
      push $file --message $message
      null
    } catch { |e| $e }

    if $push_err == null {
      return $branch_name
    }

    $last_err = $push_err
    print (
      $"Push failed "
      + $"(char lparen)attempt ($attempt)/($retry)(char rparen)"
      + $", retrying..."
    )
    git pull --rebase
    if ($retry_action | is-not-empty) {
      do $retry_action
    }
  }

  error make {
    msg: (
      $"Failed to push after ($retry) attempts: ($last_err)"
    )
  }
}

# Stage, commit, and push a single file.
def push [
  file: string,
  --message: string = "",
] {
  # New files aren't tracked yet, so `git diff` won't
  # see them. Stage first so the diff check below covers
  # both new and modified files.
  let is_new = (
    git ls-files $file | str trim | is-empty
  )
  if $is_new {
    git add $file
  }

  # Exit early when the file hasn't actually changed to
  # avoid creating empty commits.
  let diff = git diff --quiet $file | complete
  if $diff.exit_code == 0 and not $is_new {
    return
  }

  # Configure authorship for the commit. We use the GitHub
  # Actions bot identity so the commit is attributed to the
  # automation rather than a human.
  git config user.name "github-actions[bot]"
  git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
  git add $file
  git commit -m (
    $message | default -e "Update VOUCHED list"
  )

  git push
}
