# Template helper module.

# Template engine based off of Nushell's "format pattern".
#
# Only designed to be used in vouch code - not designed to be used externally.
#
# To use, pass the record set representing the template arguments into the
# command, with the path:
#
#   { ... } | template render templates/example
#
# Example: 
#
#   # Render the GitHub PR unvouched template:
#   const $template_file = path self ./templates/github-pr-unvouched
#   {
#     author: $pr_author,
#     owner: $repo_parts.owner,
#     repo: $repo_parts.name,
#     default_branch: $default_branch,
#   } | template render $template_file
#
export def render [
  path: string, # The path of the template
]: record -> string {
  let input = open --raw $path
  let out = $in | format pattern $input
  $out
}
