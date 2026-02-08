#!/usr/bin/env nu

# Vouch - contributor trust management.
export def main [] {
  print "Usage: vouch <command>"
  print ""
  print "Local Commands:"
  print "  add               Add a user to the vouched contributors list"
  print "  check             Check a user's vouch status"
  print "  denounce          Denounce a user by adding them to the vouched file"
  print "  remove            Remove a user from the vouched contributors list"
  print ""
  print "GitHub integration:"
  print "  gh-check-pr         Check if a PR author is a vouched contributor"
  print "  gh-manage-by-discussion Manage contributor status via discussion comment"
  print "  gh-manage-by-issue  Manage contributor status via issue comment"
}

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
  gh-manage-and-push
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

