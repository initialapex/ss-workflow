# reqs/

Every change to this repository starts as a request in this folder. Request files are
written in the `reqs-language` from root `AGENTS.md`.

<!-- ss-workflow:managed id=reqs-files -->
## Files

- One Markdown file per request, directly in `reqs/`. No subfolder per request and
  no status index file.
- File name: `REQ-<4-digit id>-<yyyyMMdd>-<slug>.md`, for example
  `REQ-0012-20260907-gui-button.md`.
  - **id**: the highest id in use, plus 1. An id is in use when a file in `reqs/` or
    `reqs/done/` on `develop` has it, or when a local or remote branch name contains
    it (`req/REQ-0012-…`, `feat/REQ-0012-…`).
  - **date**: the creation date.
  - **slug**: short, lowercase, kebab-case, in English.
- When a request is closed, `/ss-workflow-merge` moves its file to `reqs/done/` with
  `git mv`. The file name does not change.
<!-- /ss-workflow:managed -->

<!-- ss-workflow:managed id=reqs-format -->
## Request file format

```markdown
---
id: REQ-0012
title: GUI buttonX modification
status: draft
type: feat
priority: normal
branch:
created: 2026-09-07
---

# GUI buttonX modification

## Spec

<!-- The agreed specification: goal, scope, acceptance criteria, out of scope. -->

## Original

<!-- The developer's original request, verbatim. Never edit this section. -->

## Notes

<!-- Decisions, implementation summary, verify results, and review feedback, each with a date. -->
```

| Field | Values |
|-------|--------|
| `status` | `draft`, `ready`, `in-progress`, `review`, `done` |
| `type` | `feat`, `fix`, `docs`, `refactor`, `perf`, `test`, `chore`, `hotfix` |
| `priority` | `high`, `normal`, `low` |
| `branch` | Empty until claimed, then the request branch, for example `feat/REQ-0012-gui-button` |

The frontmatter is the only source of truth for a request's state.
<!-- /ss-workflow:managed -->

<!-- ss-workflow:managed id=reqs-lifecycle -->
## Lifecycle

| Status | Meaning | Where the work happens | The file with this status is on | Set by |
|--------|---------|------------------------|---------------------------------|--------|
| `draft` | The spec is under discussion | Root checkout, on a `req/REQ-…` branch | The `req/` branch | `/ss-workflow-new-req` |
| `ready` | The developer approved the spec; waiting to be claimed | (nothing) | `develop`, after the `req/` branch is merged | `/ss-workflow-new-req` |
| `in-progress` | Claimed; being implemented | A worktree, on the request branch | The request branch | `/ss-workflow-check-req` |
| `review` | Implemented; the worktree is removed and the branch is kept; waiting for or under Verify and Review | Root checkout, on the request branch | The request branch | `/ss-workflow-check-req` sets it; `/ss-workflow-review` works on it |
| `done` | Closed; the file is in `reqs/done/` | Root checkout | The request branch, as its last commit before the merge | `/ss-workflow-merge` |

Terms:

- **Root checkout**: the repository's primary working tree. Its home branch is
  `develop`. Spec discussions, Verify, Review, merges, and releases use it, one at a
  time.
- **Verify**: running the build, the test projects, and the verification scripts.
- **Review**: the developer checks the result by hand.

Rules:

- A `draft` exists only on its `req/REQ-<id>-<slug>` branch. `develop` only holds
  requests that the developer approved.
- Only move a request to `ready` after the developer explicitly approves the spec.
- **Creating the request branch is the claim.** The branch
  `<type>/REQ-<id>-<slug>` is created from `develop` and pushed. If a branch for this
  id already exists, locally or on the remote, the request is claimed. The first
  commit on the branch sets `status: in-progress` and `branch`. When two machines
  claim at the same time, the one whose first commit the remote accepts holds the
  claim, and the other one gives up its branch.
- `develop` keeps showing `ready` until the merge. The request branch holds the
  current status (`in-progress`, `review`, or `done`), and that status is the
  effective one.
- In a worktree, the agent writes code and may try to compile it. It does not run
  tests, scripts, or executables there. Those belong to Verify, in the root checkout.
- When the implementation is finished, the worktree is removed and the branch is kept.
  The request waits in `review` until the developer starts `/ss-workflow-review`.
- Small fixes found during Verify or Review are made in the root checkout, on the
  request branch. If the request needs larger rework, it goes back to `in-progress`
  and is implemented in a worktree again.
- A request is closed when the developer runs `/ss-workflow-merge`.
- A request that is `done` on its branch while the branch is not merged yet is
  waiting for its merge request on the remote ("merge pending").
- `type: hotfix` requests use the branch `hotfix/v<version>`, created from the main
  branch instead of `develop`. The request file is not on the main branch, so the
  claim commit copies it from `develop` onto the hotfix branch.
- The worktree of a request is `.claude/worktrees/<branch with "/" replaced by "-">`
  under the repository root.
- Never edit the `## Original` section. Never delete the file of a request that
  reached `develop`. A request that is dropped gets `status: done` and a note in
  `## Notes` that explains why.
<!-- /ss-workflow:managed -->
