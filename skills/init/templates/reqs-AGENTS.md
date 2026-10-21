# reqs/

Every change starts as a request in this folder: a change to a project, and a change
to the files of this workspace. Request files are
written in the `reqs-language` from root `AGENTS.md`.

<!-- ss-workflow:managed id=reqs-files -->
## Files

- One Markdown file per request, directly in `reqs/`. No subfolder per request and
  no status index file.
- File name: `REQ-<4-digit id>-<yyyyMMdd>-<slug>.md`, for example
  `REQ-0012-20260907-gui-button.md`.
  - **id**: the highest id in use, plus 1. An id is in use when a file in `reqs/` or
    `reqs/done/` on `develop` has it, or when a local or remote branch name of the
    workspace contains it (`req/REQ-0012-…`, `feat/REQ-0012-…`).
  - **date**: the creation date.
  - **slug**: short, lowercase, kebab-case, in English.
- When a request is closed, `/ss-workflow:merge` moves its file to `reqs/done/` with
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
projects: [SSDisp]
priority: normal
branch:
created: 2026-09-07
---

# GUI buttonX modification

## Spec

<!-- The agreed specification: goal, scope, acceptance criteria, out of scope. -->

## Original

<!-- The developer's original request, verbatim. Never edit this section. -->

## Q&A

<!-- Every question to the developer and its answer, in the order asked. Append only. -->

## Notes

<!-- Assumptions, implementation summary, behavior changes, verify results, and review feedback, each with a date. -->
```

| Field | Values |
|-------|--------|
| `status` | `draft`, `ready`, `in-progress`, `review`, `done` |
| `type` | `feat`, `fix`, `docs`, `refactor`, `perf`, `test`, `chore`, `hotfix` |
| `projects` | The projects that the request changes, by their `name` in "Workflow settings", for example `[SSLib, SSDisp]`. `[]` for a request that changes only workspace files (docs, READMEs, agent files outside their managed blocks). A `hotfix` names exactly one. A request from before the workspace layout may lack the field: it belongs to `legacy-project` in "Workflow settings". |
| `priority` | `high`, `normal`, `low` |
| `branch` | Empty until claimed, then the workspace request branch, for example `feat/REQ-0012-gui-button`. The projects use the same name, except for a hotfix: `hotfix/SSDisp-v1.0.1` in the workspace, `hotfix/v1.0.1` in the project. |

The frontmatter is the only source of truth for a request's state.

Keep the headings `## Spec`, `## Original`, `## Q&A`, and `## Notes` in English and
in this order. The skills look them up.
<!-- /ss-workflow:managed -->

<!-- ss-workflow:managed id=reqs-qa -->
## Questions and answers

`## Q&A` records what was asked and what was decided, in the order it happened, so
that anyone can tell later why the request is the way it is.

```markdown
### Q3 (2026-09-08, spec)

Q: Should the button also appear in the toolbar? Options: toolbar and menu / menu only.
A: Menu only. The toolbar is full.
Decision: "Scope" lists the menu entry only. The toolbar is in "Out of scope".
```

- Record every question whose answer changes what the request delivers or how a
  result is judged: the scope, the behavior, the architecture, an acceptance
  criterion, or whether a failed or skipped check is accepted. Do not record
  procedural questions, such as which request to pick or whether to continue now.
- Number the entries in the order asked. The heading carries the date of the question
  and the stage: `spec`, `implementation`, or `review`.
- `Q:` is the question as it was asked, with the options that were offered. `A:` is
  the developer's answer in their own words. `Decision:` is what follows from it for
  the request.
- A question without an answer yet has `A: (pending)` and no `Decision:` line. Fill
  both in when the answer comes. If that is on a later day, start the answer with its
  date.
- Append only. Never change or delete an entry that has an answer. When a decision
  changes, add a new entry that names the one it replaces (`Replaces Q3.`).
- A default that the agent proposed and the developer accepted is recorded like any
  other answer, and also as an `Assumption` in `## Notes`, so that the Review checks
  it again.
- A request moves to `ready` only when no entry is pending. An older request may
  still have an "Open questions" part in its spec: that part must be empty too.
<!-- /ss-workflow:managed -->

<!-- ss-workflow:managed id=reqs-results -->
## Results and behavior changes

`## Notes` holds the dated results: the implementation summary, the Verify result,
the code review, and the Review.

- Every result lists each check with exactly one of these: `passed`, `failed` (with
  the reason), `did not run` (with the reason), or `not configured`. A check that did
  not run is never written as passed. A part of the spec that is not implemented is
  listed as not done.
- Changes to workspace files (docs, READMEs, agent files) are not built, tested, or
  code-reviewed. The developer reads each of them in the Review, and the Review
  result names them.
- A request that changes an agent behavior file (see "Working agreement" in the root
  `AGENTS.md`) has a `### Behavior changes` entry, with one item per file:

  ```markdown
  ### Behavior changes (2026-09-10)
  - `.claude/skills/deploy/SKILL.md`
    - Diff: <the changed lines, quoted. For a long change, the command that shows
      them: `git diff <base>...<branch> -- <path>`>
    - Before: <what an agent did, and in which situation>
    - After: <what an agent does now>
  ```

  Write "Before" and "After" in plain words, as behavior and not as a description of
  the edit. The implementation writes the entry. Verify cannot prove it, so the
  developer confirms every item in the Review.
<!-- /ss-workflow:managed -->

<!-- ss-workflow:managed id=reqs-lifecycle -->
## Lifecycle

| Status | Meaning | Where the work happens | The file with this status is on | Set by |
|--------|---------|------------------------|---------------------------------|--------|
| `draft` | The spec is under discussion | Root checkout, on a `req/REQ-…` branch | The `req/` branch | `/ss-workflow:new-req` |
| `ready` | The developer approved the spec; waiting to be claimed | (nothing) | `develop`, after the `req/` branch is merged | `/ss-workflow:new-req` |
| `in-progress` | Claimed; being implemented | A worktree of the workspace with a worktree of each project inside, on the request branches | The workspace request branch | `/ss-workflow:check-req` |
| `review` | Implemented; the worktrees are removed and the branches are kept; waiting for or under Verify and Review | Root checkout, on the request branches | The workspace request branch | `/ss-workflow:check-req` sets it; `/ss-workflow:review` works on it |
| `done` | Closed; the file is in `reqs/done/` | Root checkout | The workspace request branch, as its last commit before the merge | `/ss-workflow:merge` |

Terms:

- **Root checkout**: the workspace's primary working tree. Its home branch is
  `develop`. Spec discussions, Verify, Review, merges, and releases use it, one at a
  time.
- **Request branches**: the branch of the request in the workspace and the branch
  with the same name in each project of the request.
- **Verify**: running the build, the test projects, and the verification scripts.
- **Review**: the developer checks the result by hand.

Rules:

- A `draft` exists only on its `req/REQ-<id>-<slug>` branch. `develop` only holds
  requests that the developer approved.
- Only move a request to `ready` after the developer explicitly approves the spec,
  and only when `## Q&A` has no pending entry.
- **Creating the workspace request branch is the claim.** The branch
  `<type>/REQ-<id>-<slug>` is created from `develop`. If a workspace branch for this
  id already exists, locally or on the remote, the request is claimed. The first
  commit on the branch sets `status: in-progress` and `branch`.
- In one repository, git creates a branch name only once, so the claim needs no
  remote. Across machines, the branch and its first commit are pushed (see "Remote
  and pushing" in the root `AGENTS.md`): the machine whose first commit the remote
  accepts holds the claim, and the other one gives up its branch. A claim that is not
  pushed holds in this repository only.
- The branches in the projects are created only after the claim holds, from each
  project's latest `develop-branch` (not from the gitlink).
- `develop` keeps showing `ready` until the merge. The workspace request branch holds
  the current status (`in-progress`, `review`, or `done`), and that status is the
  effective one.
- Code is committed in the projects only. The workspace request branch holds the
  request file, the gitlinks of the request's projects, and the request's changes to
  workspace files (see "Workspace and projects" in the root `AGENTS.md`). A request
  with `projects: []` has a workspace branch only.
- In a worktree, the agent writes code and may try to compile it. It does not run
  tests, scripts, or executables there. Those belong to Verify, in the root checkout.
- When the implementation is finished, the worktrees are removed and the branches are
  kept. The request waits in `review` until the developer starts `/ss-workflow:review`.
- Small fixes found during Verify or Review are made in the root checkout, on the
  request branches. If the request needs larger rework, it goes back to `in-progress`
  and is implemented in a worktree again.
- A request is closed when the developer runs `/ss-workflow:merge`.
- A request that is `done` on its workspace branch while that branch is not merged
  yet is waiting for a merge on a remote ("merge pending").
- `type: hotfix` requests name one project. They use `hotfix/<name>-v<version>` in the
  workspace, created from its main branch, and `hotfix/v<version>` in the project,
  created from the project's main branch. The request file is not on the workspace
  main branch yet, so the claim commit copies it from `develop` onto the hotfix branch.
- The worktree of a request is `.claude/worktrees/<branch with "/" replaced by "-">`
  under the workspace root, with the projects at their paths inside it.
- Never edit the `## Original` section. Never delete the file of a request that
  reached `develop`. A request that is dropped gets `status: done` and a note in
  `## Notes` that explains why.
<!-- /ss-workflow:managed -->
