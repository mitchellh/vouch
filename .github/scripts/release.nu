#!/usr/bin/env nu

# Prepare a draft GitHub release for the next tag.
#
# Determines the next semantic version tag by bumping the latest existing
# tag (or starting at --initial-tag if none exist). Generates release notes from
# the git log since the previous tag and creates a draft release via `gh`.
#
# Examples:
#
#   # Preview what would happen (default)
#   nu .github/scripts/release.nu
#
#   # Bump minor version (default)
#   nu .github/scripts/release.nu --bump minor
#
#   # Bump major version
#   nu .github/scripts/release.nu --bump major
#
#   # Create the draft release
#   nu .github/scripts/release.nu --dry-run=false

export def main [
  --bump: string = "minor",          # Version component to bump: major, minor, or patch
  --initial-tag: string = "v0.1.0", # Tag to use when no existing tags are found
  --dry-run = true,                  # Print what would happen without making changes
] {
  if $bump not-in ["major" "minor" "patch"] {
    error make { msg: $"--bump must be major, minor, or patch (got ($bump))" }
  }

  let latest = latest-tag
  let next = if $latest == null {
    $initial_tag
  } else {
    bump-version $latest $bump
  }

  let notes = generate-notes $latest
  let repo = detect-repo

  print $"Latest tag: ($latest | default 'none')"
  print $"Next tag:   ($next)"
  print $"Repository: ($repo)"
  print ""
  print "Release notes:"
  print $notes

  if $dry_run {
    print ""
    print $"(char lparen)dry-run(char rparen) Would create draft release ($next) on ($repo)"
    return
  }

  let notes_file = mktemp -t "release-notes-XXXXXX"
  try {
    $notes | save -f $notes_file
    ^gh release create $next --repo $repo --title $next -F $notes_file --draft
    print ""
    print $"Draft release ($next) created"
  } catch { |e|
    rm -f $notes_file
    error make { msg: $e.msg }
  }
  rm -f $notes_file
}

# Find the latest semver tag, or null if none exist.
def latest-tag [] {
  let tags = git tag --list --sort=-v:refname
    | lines
    | where { |t| $t =~ '^v?\d+\.\d+\.\d+' }

  if ($tags | is-empty) {
    null
  } else {
    $tags | first
  }
}

# Bump a semver tag string (e.g. "v1.2.3") by the given component.
def bump-version [tag: string, component: string] {
  let stripped = $tag | str replace -r "^v" ""
  let parts = $stripped | split row "."
  let major = $parts | get 0 | into int
  let minor = $parts | get 1 | into int
  let patch = $parts | get 2 | into int

  match $component {
    "major" => $"v($major + 1).0.0",
    "minor" => $"v($major).($minor + 1).0",
    "patch" => $"v($major).($minor).($patch + 1)",
  }
}

# Generate release notes from the git log since the given tag.
def generate-notes [since?: string] {
  let commits = if $since == null {
    git log --oneline --no-decorate | lines
  } else {
    git log --oneline --no-decorate $"($since)..HEAD" | lines
  }

  if ($commits | is-empty) {
    "No changes since last release."
  } else {
    $commits
      | each { |c| $"- ($c)" }
      | str join "\n"
  }
}

# Detect the GitHub repository from the git remote.
def detect-repo [] {
  let url = git remote get-url origin | str trim
  $url
    | str replace -r '\.git$' ""
    | str replace -r '^https://github\.com/' ""
    | str replace -r '^git@github\.com:' ""
}
