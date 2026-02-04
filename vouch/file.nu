# Parse Trustdown format into structured data.
export def "from td" []: string -> list<record> {
  lines | each { parse-line }
}

# Convert structured data to Trustdown format.
export def "to td" []: list<record> -> string {
  each { format-line } | to text
}

# Open a VOUCHED file and return all the lines. The rest of the commands
# take these lines as input. This will preserve comments and ordering and
# whitespace.
#
# If no path is provided or the path doesn't exist, falls back to default-path
# when --default is true (the default).
export def open-file [
  path?: path  # Path to the VOUCHED file
  --default = true  # Fall back to default-path if path is missing or doesn't exist
] {
  let resolved = if $path == null {
    if $default {
      default-path
    } else {
      null
    }
  } else {
    $path
  }

  if ($resolved == null) or (not ($resolved | path exists)) {
    error make { msg: "VOUCHED file not found" }
  }

  open --raw $resolved | from td
}

# Find the default VOUCHED file by checking common locations.
#
# Checks for VOUCHED.td in the current directory first, then .github/VOUCHED.td.
# Returns null if neither exists.
export def default-path [] {
  if ("VOUCHED.td" | path exists) {
    "VOUCHED.td"
  } else if (".github/VOUCHED.td" | path exists) {
    ".github/VOUCHED.td"
  } else {
    null
  }
}

# Parse a single line of TD format.
def parse-line []: string -> record {
  let line = $in

  if ($line | str trim | is-empty) {
    return { type: "blank", platform: null, username: null, details: null }
  }

  if ($line | str trim | str starts-with "#") {
    return { type: "comment", platform: null, username: null, details: $line }
  }

  let trimmed = $line | str trim

  # Check for denounce prefix
  let is_denounce = $trimmed | str starts-with "-"
  let rest = if $is_denounce { $trimmed | str substring 1.. } else { $trimmed }

  # Split handle from details (first space separates them)
  let parts = $rest | split row " " --number 2
  let handle = $parts | first
  let details = if ($parts | length) > 1 { $parts | get 1 } else { null }

  # Parse platform:username or just username
  let handle_parts = $handle | split row ":" --number 2
  let platform = if ($handle_parts | length) > 1 { $handle_parts | get 0 } else { null }
  let username = if ($handle_parts | length) > 1 { $handle_parts | get 1 } else { $handle }

  {
    type: (if $is_denounce { "denounce" } else { "vouch" })
    platform: $platform
    username: $username
    details: $details
  }
}

# Format a single record back to TD format.
def format-line []: record -> string {
  let rec = $in

  match $rec.type {
    "blank" => "",
    "comment" => $rec.details,
    _ => {
      let prefix = if $rec.type == "denounce" { "-" } else { "" }
      let handle = if $rec.platform != null {
        $"($rec.platform):($rec.username)"
      } else {
        $rec.username
      }
      let suffix = if $rec.details != null { $" ($rec.details)" } else { "" }
      $"($prefix)($handle)($suffix)"
    }
  }
}
