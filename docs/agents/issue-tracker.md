# Issue tracker: GitHub

Issues and specs for this repository live in GitHub Issues. Use the `gh` CLI from this checkout; it resolves `techmigosglobal/schooldesk1` from the Git remote.

## Conventions

- Create an issue with `gh issue create --title "..." --body-file <path>`.
- Read an issue with `gh issue view <number> --comments`.
- List open issues with `gh issue list --state open --json number,title,body,labels,comments` and apply suitable state or label filters.
- Comment with `gh issue comment <number> --body "..."`.
- Add or remove labels with `gh issue edit <number> --add-label "..."` or `--remove-label "..."`.
- Close with `gh issue close <number> --comment "..."`.

## Write authorization

Issue reads are allowed when useful to the requested work. Creating, commenting on, editing, assigning, labeling, or closing GitHub issues requires explicit authorization in the current user request. If authorization is absent, prepare the proposed content locally and ask before sending it. This applies even when a skill describes an operation as publishing, claiming, or resolving a ticket.

## Pull requests as a triage surface

**PRs as a request surface: no.** Do not include external pull requests in the triage queue unless this policy is changed.

GitHub shares issue and pull request numbers. When resolving a reference such as `#42`, check whether it is a pull request or an issue before acting.

## Wayfinder conventions

- A map is one issue labeled `wayfinder:map`, containing Notes, Decisions-so-far, and Fog.
- Child tickets should be GitHub sub-issues when available. Otherwise, list them in the map and add `Part of #<map>` to each child.
- Child labels use `wayfinder:<type>` with `research`, `prototype`, `grilling`, or `task` as the type.
- Use native GitHub issue dependencies for blockers when available; otherwise, record `Blocked by: #<n>` in the child issue.
- Claiming, resolving, or changing any issue follows the write authorization rule above.
