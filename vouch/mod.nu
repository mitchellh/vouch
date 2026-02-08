#!/usr/bin/env nu

export use main.nu [main]

# The main CLI commands, this lets the user do `use vouch; vouch add` etc.
export use cli.nu [
  add
  check
  denounce
  remove
]

# The GitHub integration commands.
export use github.nu [
  gh-check-pr
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
