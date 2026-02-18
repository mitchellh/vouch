# CODEOWNERS parsing utilities.

# Parse CODEOWNERS content into a table of owner -> files.
#
# Each row maps an owner (user or team handle) to the list
# of file patterns they own. Owners are sorted alphabetically.
#
# Owners have the leading "@" stripped.
#
# Example:
#   open -r CODEOWNERS | parse-codeowners
#   ╭───┬────────────┬──────────────────╮
#   │ # │   owner    │      files       │
#   ├───┼────────────┼──────────────────┤
#   │ 0 │ acme/core  │ [/src/]          │
#   │ 1 │ bob        │ [/src/, /docs/]  │
#   ╰───┴────────────┴──────────────────╯
export def parse-codeowners []: string -> table<owner: string, files: list<string>> {
  $in
    | lines
    | where {|line|
      not ($line | str starts-with "#")
    }
    | where {|line| ($line | str trim) != ""}
    | where {|line| $line | str contains "@"}
    | each {|line|
      let parts = (
        $line
          | split row "#"
          | first
          | str trim
          | split row " "
          | where {|p| $p != ""}
      )
      let pattern = ($parts | first)
      let owners = ($parts | skip 1)
      $owners | each {|o| { owner: $o, pattern: $pattern }}
    }
    | flatten
    | group-by owner
    | transpose owner files
    | update files {|r| $r.files | get pattern}
    | update owner {|r|
      $r.owner | str trim --left -c "@"
    }
}
