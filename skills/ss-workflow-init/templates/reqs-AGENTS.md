# reqs/

Every change to this repository starts as a request in this folder. Request files are
written in the `reqs-language` from root `AGENTS.md`.

<!-- ss-workflow:managed id=reqs-files -->
## Files

- One Markdown file per request, directly in `reqs/`. No subfolder per request and
  no status index file.
- File name: `REQ-<4-digit id>-<yyyyMMdd>-<slug>.md`, for example
  `REQ-0012-20260907-gui-button.md`.
  - **id**: the highest existing id in `reqs/` and `reqs/done/`, plus 1.
  - **date**: the creation date.
  - **slug**: short, lowercase, kebab-case, in English.
- When a request reaches `done`, `/ss-workflow-merge` moves its file to `reqs/done/`
  with `git mv`. The file name does not change.
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

<!-- Implementation notes, decisions, and links added during the work. -->
```

| Field | Values |
|-------|--------|
| `status` | `draft`, `ready`, `in-progress`, `review`, `done` |
| `type` | `feat`, `fix`, `docs`, `refactor`, `perf`, `test`, `chore`, `hotfix` |
| `priority` | `high`, `normal`, `low` |
| `branch` | Empty until claimed, then the branch name, for example `feat/REQ-0012-gui-button` |

The frontmatter is the only source of truth for a request's state.
<!-- /ss-workflow:managed -->

<!-- ss-workflow:managed id=reqs-lifecycle -->
## Lifecycle

| Status | Meaning | Changed on | Changed by |
|--------|---------|------------|------------|
| `draft` | Created; the spec is under discussion | `develop` | `/ss-workflow-new-req` |
| `ready` | The developer approved the spec; waiting to be claimed | `develop` (commit) | `/ss-workflow-new-req` |
| `in-progress` | Claimed; being implemented in a worktree | `develop` (commit + push) | `/ss-workflow-check-req` |
| `review` | Implementation finished; waiting for developer review | Request branch | `/ss-workflow-check-req` |
| `done` | Merged into `develop`; the file is in `reqs/done/` | `develop` | `/ss-workflow-merge` |

Rules:

- Only move a request to `ready` after the developer explicitly approves the spec.
- **Claiming is the lock.** On `develop`:
  1. Set `status: in-progress` and fill in `branch`.
  2. Commit (`chore(reqs): claim REQ-0012`) and push.
  3. If the push is rejected, another session claimed a request first. Pull, then
     choose again.
  4. Only after the claim lands, create the branch and the worktree.
- After creating a request branch, push it right away (`git push -u`), and push after
  every commit, so that work is never only local.
- `type: hotfix` requests branch from the main branch instead of `develop`. See the
  root `AGENTS.md` section "Branching model".
- Never edit the `## Original` section. Never delete a request file. A request that is
  dropped gets `status: done` and a note in `## Notes` that explains why.
<!-- /ss-workflow:managed -->
