#!/usr/bin/env nu

use file.nu [default-path, "from td", open-file, "to td"]
use lib.nu [add-user, check-user, denounce-user, remove-user]

# Add a user to the vouched contributors list.
#
# This adds the user to the vouched list, removing any existing entry
# (vouched or denounced) for that user first.
#
# Examples:
#
#   # Preview new file contents (default)
#   ./vouch.nu add someuser
#
#   # Write the file in-place
#   ./vouch.nu add someuser --write
#
#   # Add with platform prefix
#   ./vouch.nu add github:someuser --write
#
export def add [
  username: string,          # Username to vouch for (supports platform:user format)
  --default-platform: string = "", # Assumed platform for entries without explicit platform
  --vouched-file: string = "",    # Path to vouched contributors file (default: VOUCHED.td or .github/VOUCHED.td)
  --write (-w),              # Write the file in-place (default: output to stdout)
] {
  let file = if ($vouched_file | is-empty) {
    let default = default-path
    if ($default | is-empty) {
      error make { msg: "no VOUCHED file found" }
    }
    $default
  } else {
    $vouched_file
  }

  let records = open-file $file
  let new_records = $records | add-user $username --default-platform $default_platform

  if $write {
    $new_records | to td | save -f $file
    print $"Added ($username) to vouched contributors"
  } else {
    print -n ($new_records | to td)
  }
}

# Check a user's vouch status.
#
# This checks if a user is vouched, denounced, or unknown.
#
# Exit codes:
#   0 - vouched
#   1 - denounced
#   2 - unknown
#
# Examples:
#
#   ./vouch.nu check someuser
#   ./vouch.nu check github:someuser
#
export def check [
  username: string,          # Username to check (supports platform:user format)
  --default-platform: string = "", # Assumed platform for entries without explicit platform
  --vouched-file: string = "",    # Path to vouched contributors file (default: VOUCHED.td or .github/VOUCHED.td)
] {
  let file = if ($vouched_file | is-empty) {
    let default = default-path
    if ($default | is-empty) {
      error make { msg: "no VOUCHED file found" }
    }
    $default
  } else {
    $vouched_file
  }

  let records = open-file $file
  let status = $records | check-user $username --default-platform $default_platform

  match $status {
    "vouched" => {
      print $"($username) is vouched"
      exit 0
    }
    "denounced" => {
      print $"($username) is denounced"
      exit 1
    }
    _ => {
      print $"($username) is unknown"
      exit 2
    }
  }
}

# Denounce a user by adding them to the VOUCHED file with a minus prefix.
#
# This removes any existing entry for the user and adds them as denounced.
# An optional reason can be provided which will be added after the username.
#
# Examples:
#
#   # Preview new file contents (default)
#   ./vouch.nu denounce badactor
#
#   # Denounce with a reason
#   ./vouch.nu denounce badactor --reason "Submitted AI slop"
#
#   # Write the file in-place
#   ./vouch.nu denounce badactor --write
#
#   # Denounce with platform prefix
#   ./vouch.nu denounce github:badactor --write
#
export def denounce [
  username: string,          # Username to denounce (supports platform:user format)
  --default-platform: string = "", # Assumed platform for entries without explicit platform
  --reason: string,          # Optional reason for denouncement
  --vouched-file: string = "",    # Path to vouched contributors file (default: VOUCHED.td or .github/VOUCHED.td)
  --write (-w),              # Write the file in-place (default: output to stdout)
] {
  let file = if ($vouched_file | is-empty) {
    let default = default-path
    if ($default | is-empty) {
      error make { msg: "no VOUCHED file found" }
    }
    $default
  } else {
    $vouched_file
  }

  let records = open-file $file
  let new_records = $records | denounce-user $username ($reason | default "") --default-platform $default_platform

  if $write {
    $new_records | to td | save -f $file
    print $"Denounced ($username)"
  } else {
    print -n ($new_records | to td)
  }
}

# Remove a user from the VOUCHED file entirely.
#
# This removes any existing entry (vouched or denounced) for the user.
# The user will become unknown after this operation.
#
# Examples:
#
#   # Preview new file contents (default)
#   ./vouch.nu remove someuser
#
#   # Write the file in-place
#   ./vouch.nu remove someuser --write
#
#   # Remove with platform prefix
#   ./vouch.nu remove github:someuser --write
#
export def remove [
  username: string,          # Username to remove (supports platform:user format)
  --default-platform: string = "", # Assumed platform for entries without explicit platform
  --vouched-file: string = "",    # Path to vouched contributors file (default: VOUCHED.td or .github/VOUCHED.td)
  --write (-w),              # Write the file in-place (default: output to stdout)
] {
  let file = if ($vouched_file | is-empty) {
    let default = default-path
    if ($default | is-empty) {
      error make { msg: "no VOUCHED file found" }
    }
    $default
  } else {
    $vouched_file
  }

  let records = open-file $file
  let new_records = $records | remove-user $username --default-platform $default_platform

  if $write {
    $new_records | to td | save -f $file
    print $"Removed ($username) from vouched contributors"
  } else {
    print -n ($new_records | to td)
  }
}
