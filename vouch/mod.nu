#!/usr/bin/env nu

# The main CLI commands. This lets the user do `use vouch *; add ...` etc.
export use cli.nu [
  add
  check
  denounce
  main
  remove
  "vouch main"
]

# The GitHub integration commands.
export use github.nu [
  gh-check-issue
  gh-check-pr
  gh-check-user
  gh-manage-by-discussion
  gh-manage-by-issue
]

# This exposes the function so `open <file>.td` works.
export use file.nu [
  default-path
  "from td"
  init-file
  "to td"
]

# The API if people want to use this as a Nu library.
export module lib.nu

