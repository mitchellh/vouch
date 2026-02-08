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

# Parse a handle into platform and username components.
#
# Handles format: "platform:username" or just "username"
# Returns a record with {platform: string | null, username: string}
export def parse-handle [handle: string] {
  let parts = $handle | str downcase | split row ":" --number 2
  if ($parts | length) > 1 {
    {platform: ($parts | first), username: ($parts | get 1)}
  } else {
    {platform: null, username: ($parts | first)}
  }
}

# Initialize a new VOUCHED file at the given path with starter content.
#
# Creates parent directories if needed. The file includes an explanatory
# header pointing to github.com/mitchellh/vouch for details.
export def init-file [
  path: path  # Path where the VOUCHED file should be created
] {
  let parent = ($path | path dirname)
  if not ($parent | path exists) {
    mkdir $parent
  }

  "# Vouched contributors for this project.
#
# See https://github.com/mitchellh/vouch for details.
#
# Syntax:
#   - One handle per line (without @), sorted alphabetically.
#   - Optional platform prefix: platform:username (e.g., github:user).
#   - Denounce with minus prefix: -username or -platform:username.
#   - Optional details after a space following the handle.
" | save $path
}

# Open all .td files in a directory and return a flat list of records.
#
# Files are loaded in filesystem sort order. Returns an empty list if the
# directory does not exist.
export def open-dir [
  dir: path  # Path to directory containing .td files
] {
  if not ($dir | path exists) {
    return []
  }

  glob ($dir | path join "*.td") | sort | each { |f|
    open --raw $f | from td
  } | flatten
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

  let parsed = parse-handle $handle

  {
    type: (if $is_denounce { "denounce" } else { "vouch" })
    platform: $parsed.platform
    username: $parsed.username
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
