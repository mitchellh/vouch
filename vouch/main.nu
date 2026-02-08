#!/usr/bin/env nu

# Print CLI usage.
#
# This is primarily useful if you `use vouch *` and want a quick reminder
# of the available commands.
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

