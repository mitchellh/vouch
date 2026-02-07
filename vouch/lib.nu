# Library functions for vouch contributor management.

use file.nu [parse-handle]

# Add a user to the VOUCHED table, removing any existing entry first.
#
# Supports platform:username format (e.g., github:mitchellh).
# Returns the updated table with the user added and sorted.
export def add-user [
  username: string,            # Username to add (supports platform:user format)
  --default-platform: string = "", # Assumed platform for entries without explicit platform
  --details: string = "",      # Optional details/reason for vouching
]: table -> table {
  let handle = parse-handle $username
  let d = if ($details | is-empty) { null } else { $details }
  $in | 
    remove-user $username --default-platform $default_platform |
    append ({
      type: "vouch"
      platform: $handle.platform
      username: $handle.username
      details: $d
    }) | 
    sort-table
}

# Denounce a user in the VOUCHED table, removing any existing entry first.
#
# Supports platform:username format (e.g., github:mitchellh).
# Returns the updated table with the user added as denounced and sorted.
export def denounce-user [
  username: string,            # Username to denounce (supports platform:user format)
  reason: string = "",         # Reason for denouncement (can be empty)
  --default-platform: string = "", # Assumed platform for entries without explicit platform
]: table -> table {
  let handle = parse-handle $username
  $in |
    remove-user $username --default-platform $default_platform |
    append ({
      type: "denounce"
      platform: $handle.platform
      username: $handle.username
      details: (if ($reason | is-empty) { null } else { $reason })
    }) |
    sort-table
}

# Check a user's status in a VOUCHED table.
#
# Takes a table as returned by file.nu's `from td`.
# Supports platform:username format (e.g., github:mitchellh).
# Returns "vouched", "denounced", or "unknown".
export def check-user [
  username: string,            # Username to check (supports platform:user format)
  --default-platform: string = "", # Assumed platform for entries without explicit platform
]: table -> string {
  let records = $in
  let handle = parse-handle $username
  let default_platform_lower = if ($default_platform | is-empty) { null } else { $default_platform | str downcase }

  let contributors = $records | where { |r| $r.type == "vouch" or $r.type == "denounce" }

  for entry in $contributors {
    let entry_platform = if ($entry.platform == null) { $default_platform_lower } else { $entry.platform | str downcase }
    let entry_user = $entry.username | str downcase

    let check_platform = if ($handle.platform == null) { $default_platform_lower } else { $handle.platform }

    let platform_matches = ($check_platform == null) or ($entry_platform == null) or ($entry_platform == $check_platform)

    if ($entry_user == $handle.username) and $platform_matches {
      if $entry.type == "denounce" {
        return "denounced"
      } else {
        return "vouched"
      }
    }
  }

  "unknown"
}

# Remove a user from the VOUCHED table (whether vouched or denounced).
#
# Comments and blank lines are preserved.
# Supports platform:username format (e.g., github:mitchellh).
# Returns the filtered table after removal.
export def remove-user [
  username: string,            # Username to remove (supports platform:user format)
  --default-platform: string = "", # Assumed platform for entries without explicit platform
]: table -> table {
  let records = $in
  let handle = parse-handle $username
  let default_platform_lower = if ($default_platform | is-empty) { null } else { $default_platform | str downcase }

  $records | where { |r|
    # Keep non-contributor entries (comments, blanks) unchanged
    if $r.type != "vouch" and $r.type != "denounce" {
      return true
    }

    # Normalize platforms: use default if not specified
    let entry_platform = if ($r.platform == null) { $default_platform_lower } else { $r.platform | str downcase }
    let entry_user = $r.username | str downcase
    let check_platform = if ($handle.platform == null) { $default_platform_lower } else { $handle.platform }

    # Platforms match if either is unspecified (null) or they're equal
    let platform_matches = (($check_platform == null) or 
      ($entry_platform == null) or 
      ($entry_platform == $check_platform))

    # Keep entries that don't match (remove those that do)
    not (($entry_user == $handle.username) and $platform_matches)
  }
}

# Helper: Sort table preserving comments/blanks at top, then entries alphabetically.
def sort-table []: table -> table {
  let records = $in
  let header = $records | where { |r| $r.type != "vouch" and $r.type != "denounce" }
  let entries = $records | where { |r| $r.type == "vouch" or $r.type == "denounce" }
  $header | append ($entries | sort-by -i username)
}
