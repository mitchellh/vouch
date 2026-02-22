use std/assert

use ../vouch/template.nu

export def "test default github unvouched PR template" [] {
  let want = 'Hi @unvouched, thanks for your interest in contributing!

This project requires that pull request authors are vouched, and you are not in the list of vouched users. 

This PR will be closed automatically. See https://github.com/mitchellh/vouch/blob/main/CONTRIBUTING.md for more details.
'

  let pr_author = "unvouched"
  let repo_parts = {
    owner: "mitchellh",
    name: "vouch",
  }
  let default_branch = "main";

  const template_file = path self ../vouch/templates/github-pr-unvouched
  let got = {
    author: $pr_author,
    owner: $repo_parts.owner,
    repo: $repo_parts.name,
    default_branch: $default_branch,
  } | template render $template_file

  assert equal $want $got
}

export def "test default github unvouched issue template" [] {
  let want = 'Hi @unvouched, thanks for your interest!

This project requires that issue reporters are vouched, and you are not in the list of vouched users. 

This issue will be closed automatically. See https://github.com/mitchellh/vouch/blob/main/CONTRIBUTING.md for more details.
'

  let issue_author = "unvouched"
  let owner = "mitchellh"
  let repo_name = "vouch"
  let default_branch = "main";

  const template_file = path self ../vouch/templates/github-issue-unvouched
  let got = {
    author: $issue_author,
    owner: $owner,
    repo: $repo_name,
    default_branch: $default_branch,
  } | template render $template_file

  assert equal $want $got
}
