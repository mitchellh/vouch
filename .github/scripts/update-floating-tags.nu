#!/usr/bin/env nu

# Update floating major-version tags to point to the latest matching semver release.
#
# For each semver tag (e.g. v1.2.3), determines the latest release per major
# version and creates or force-updates the corresponding floating tag (e.g. v1).
#
# Examples:
#
#   # Preview what would happen (default)
#   nu .github/scripts/floating-tags.nu
#
#   # Actually update the tags
#   nu .github/scripts/floating-tags.nu --dry-run=false

export def main [
  --dry-run = true, # Print what would happen without making changes
] {
  let tags = semver-tags
  if ($tags | is-empty) {
    print "No semver tags found"
    return
  }

  let grouped = $tags
    | each { |t| parse-semver $t }
    | group-by major
    | items { |major, entries|
      let latest = $entries | sort-by major minor patch | last
      { major: $"v($major)", tag: $latest.raw }
    }

  for entry in $grouped {
    let target = ^git rev-parse $entry.tag | str trim
    let existing = try {
      ^git rev-parse $entry.major err> /dev/null | str trim
    } catch {
      null
    }

    if $existing == $target {
      print $"($entry.major) -> ($entry.tag) (already up to date)"
      continue
    }

    if $dry_run {
      print $"(char lparen)dry-run(char rparen) git tag -fa ($entry.major) ($target) -m ($entry.tag)"
      print $"(char lparen)dry-run(char rparen) git push origin ($entry.major) --force"
      continue
    }

    ^git tag -fa $entry.major $target -m $entry.tag
    ^git push origin $entry.major --force
    print $"Updated ($entry.major) -> ($entry.tag)"
  }
}

# List all semver tags sorted by version descending.
def semver-tags [] {
  ^git tag --list --sort=-v:refname
    | lines
    | where { |t| $t =~ '^v\d+\.\d+\.\d+$' }
}

# Parse a semver tag string into a record.
def parse-semver [tag: string] {
  let parts = $tag | str replace "v" "" | split row "."
  {
    raw: $tag,
    major: ($parts | get 0 | into int),
    minor: ($parts | get 1 | into int),
    patch: ($parts | get 2 | into int),
  }
}
