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
    workspace contains it (`feat/REQ-0012-…`, or `req/REQ-0012-…` from before
    ss-workflow 0.8.0).
  - **date**: the creation date.
  - **slug**: short, lowercase, kebab-case, in English. It names the change, not the
    request, because the project branch takes it too (`feat/gui-button`).
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
project-branch:
created: 2026-09-07
---

# GUI buttonX modification

## Spec

<!-- The agreed specification: goal, scope, architecture, detailed design, acceptance criteria, how to verify, out of scope. See "Spec" below. -->

## Original

<!-- The developer's original request, verbatim. Never edit this section. -->

## Q&A

<!-- Every question to the developer and its answer, in the order asked. Append only. -->

## Notes

<!-- Assumptions, cold read, implementation summary, behavior changes, verify results, design check, and review feedback, each with a date. -->
```

| Field | Values |
|-------|--------|
| `status` | `draft`, `ready`, `in-progress`, `review`, `done` |
| `type` | `feat`, `fix`, `docs`, `refactor`, `perf`, `test`, `chore`, `hotfix` |
| `projects` | The projects that the request changes, by their `name` in "Workflow settings", for example `[SSLib, SSDisp]`. `[]` for a request that changes only workspace files (docs, READMEs, agent files outside their managed blocks). A `hotfix` names exactly one. A request from before the workspace layout may lack the field: it belongs to `legacy-project` in "Workflow settings". |
| `priority` | `high`, `normal`, `low` |
| `branch` | Empty until the request is started, then the workspace request branch, for example `feat/REQ-0012-gui-button`, or `hotfix/SSDisp-v1.0.1` for a hotfix. |
| `project-branch` | Empty until the request is started, then the branch of the request in each of its projects, named after the change with no request id, for example `feat/gui-button`, or `hotfix/v1.0.1` for a hotfix. Empty for `projects: []`. A request started before ss-workflow 0.8.0 lacks the field: its project branch has the name in `branch`. |

The frontmatter is the only source of truth for a request's state.

Keep the headings `## Spec`, `## Original`, `## Q&A`, and `## Notes` in English and
in this order. The skills look them up.
<!-- /ss-workflow:managed -->

<!-- ss-workflow:managed id=reqs-spec -->
## Spec

`## Spec` is what the implementation builds and what the review checks the result
against. Its subheadings are written in `reqs-language`.

**The standard.** A spec is complete when anyone who implements it from the spec and
the repository alone, each on their own, builds almost the same thing: a senior
engineer, a junior engineer, or another agent. They create and change the same files,
with the same types, names, and public members, the same data and stored state, the
same flows, the same handling of every error and edge case, and the same tests. Their
work may differ only where "Left to the implementation" allows it. A decision on
which two competent implementers could reasonably choose differently is settled in
the spec, not in the code. When in doubt, settle it.

**No code.** The spec contains no program code and no pseudo-code, not even a
signature in the project's language. Types, members, flows, and rules are described
in tables and plain sentences, and everything that the implementation creates is
named: file paths, types, members, parameters, and their types are written out as
names (`FrameBuffer`, `IReadOnlyList<Frame>`). Two kinds of examples may be shown in
code blocks: data formats (a JSON, XML, or INI file, the byte layout of a protocol
frame), and commands that a developer or a user types.

Names follow the conventions of the existing code, and the spec still writes each one
out. Where the spec decides something, it does not use words that leave the decision
open, such as "for example", "such as", "or similar", "etc.", "as appropriate", or
"if needed".

`## Spec` has these parts, in this order:

| Part | Content |
|------|---------|
| Goal | The problem to solve or the outcome wanted, in one or two sentences |
| Scope | The concrete changes that a developer or a user sees or uses: behavior, UI, commands and their options, file formats, the public API, and data. When the request changes more than one project, list the changes per project. List the changes to workspace files (docs, READMEs, agent files outside their managed blocks) under their own heading "Workspace", including the docs that have to follow the change, such as `docs/<name>/spec.md`. |
| Architecture | How the change is built into the software: the modules, classes, or components that are added or changed, what each one is responsible for, how they call each other, how data flows between them, the important data structures and stored state, and new dependencies. Say where the change fits into the existing structure. For several projects, write it per project, and say how they depend on each other (for example, SSDisp needs a new API of SSLib). If the change needs no architectural decision, say so in one sentence and name the place it goes into. Never left out. |
| Detailed design | The level below "Architecture" that makes the implementations converge, in the sections of the next table, in that order. For several projects, write it per project. A small change gets a short detailed design (for a one-line fix: the file, the member, and the behavior that changes), but never none. A section that has nothing for this request says "None" in one line. |
| Acceptance criteria | A checklist (`- [ ]`) of conditions that can each be checked, so that Verify and Review can tell whether the request is done |
| How to verify | The tests, scripts, or manual steps that show the criteria are met. Say for each criterion whether it is checked automatically (Verify), naming its tests from "Tests" in "Detailed design", or by hand (Review). |
| Out of scope | What this request deliberately does not cover |

"Detailed design" has these sections:

| Section | Content |
|---------|---------|
| File changes | A table with one row per file to add, change, delete, or rename: the project (or "Workspace"), the path from the project's root, the action, and what the file holds or what changes in it. List the files that the build has to know about too (project files, solution files, resource files), and the docs that follow the change. A file that is not listed is not changed. |
| Types and public members | One table per type that is added, changed, or removed: its name, kind (class, interface, struct, record, enum, module), namespace or location, the file that holds it, its base type and the interfaces it implements, and its responsibility in one sentence. Below it, one row per public member that is added, changed, or removed: name, kind (constructor, method, property, field, event, command, constant, enum value), the parameters in order with their names and types, the return type or the property type, and the behavior: what it does, its preconditions, and what it returns or raises on failure. Members that only the type itself uses are not listed. For a UI, also each view that is added or changed, and the members that each of its controls binds to. |
| Data and state | Every data item that is added or changed and that is stored, passed between components, or shown: its name, type, unit, default value, allowed range, and which component owns and changes it. The exact layout of every file, setting, message, or protocol frame that is read or written. |
| Flows | One numbered list per scenario (start-up, each user action, each external event): which component does what, in which order, which public member it calls, and on which thread or async context it runs. Say where the flow waits, what it locks, and what happens when it is cancelled. |
| Errors and edge cases | A table with one row per condition (invalid input, a missing file, a timeout, an empty list, a limit that is reached, a concurrent call): where it is detected, and exactly what happens: the exception type or the return value, the message text, what the UI shows, what is logged, and the state afterwards. |
| Configuration and dependencies | New or changed settings with their key, type, default value, and where they are stored. New or changed dependencies with the package name, the exact version, and how the project references them. |
| Tests | One row per automated test to add or change: the test project and file, the test class, the test name, what it sets up and what it asserts, and the acceptance criterion that it checks. Test names follow the project's existing tests. A project without automated tests says so; its checks are manual and belong in "How to verify". |
| Left to the implementation | What the implementation decides on its own: the members that only a type itself uses, local names, how a function body is written, and whatever else the developer agreed to leave open. Every other decision that the spec does not settle is a gap in the spec. |

For a request with `projects: []`, "File changes" lists the workspace files, and the
sections that describe code say "None".

The spec has no "Open questions" part. A question that is not decided yet is an entry
in `## Q&A` with `A: (pending)`.

A request approved before ss-workflow 0.11.0 may have no "Detailed design".
`/ss-workflow:check-req` writes it, and the developer confirms it, before the
implementation starts.
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

`## Notes` holds the dated results: the cold read of the spec, the implementation
summary, the Verify result, the design check, the code review, and the Review.

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
| `draft` | The spec is under discussion | Root checkout, on the request branch | The workspace request branch | `/ss-workflow:new-req` |
| `ready` | The developer approved the spec, and chose to start it later | (nothing) | The workspace request branch | `/ss-workflow:new-req` |
| `in-progress` | Started; being implemented | A worktree of the workspace with a worktree of each project inside, on the request branches | The workspace request branch | `/ss-workflow:check-req` |
| `review` | Implemented; the worktrees are removed and the branches are kept; waiting for or under Verify and Review | Root checkout, on the request branches | The workspace request branch | `/ss-workflow:check-req` sets it; `/ss-workflow:review` works on it |
| `done` | Closed; the file is in `reqs/done/` | Root checkout | The workspace request branch, as its last commit before the merge | `/ss-workflow:merge` |

Terms:

- **Root checkout**: the workspace's primary working tree. Its home branch is
  `develop`. Spec discussions, Verify, Review, merges, and releases use it, one at a
  time.
- **Request branches**: the branch of the request in the workspace (`branch`) and
  the branch `project-branch` in each project of the request.
- **Verify**: running the build, the test projects, and the verification scripts.
- **Review**: the developer checks the result by hand.

Rules:

- **One workspace branch from the first draft to the merge.** `/ss-workflow:new-req`
  creates the request branch `<type>/REQ-<id>-<slug>` from `develop` and writes the
  draft on it. The spec discussion, the approval, the implementation, Verify, and
  Review all happen on this branch. `develop` receives the request file only with the
  merge, already in `reqs/done/`. The request file on its branch holds the current
  status.
- Only approve a request after the developer explicitly approves the spec, and only
  when `## Q&A` has no pending entry. On approval, the developer chooses to start now
  (the request goes straight to `in-progress`) or later (`ready`, on its branch).
- **Starting a request** sets `status: in-progress`, `branch`, and `project-branch`
  on the request branch, creates the worktrees, and creates the project branches
  from each project's latest `develop-branch` (not from the gitlink). Their name has
  no request id and must be new in each of those projects (see "Branching model" in
  the root `AGENTS.md`). The request branch already exists since the draft, so
  starting needs no lock: a request whose worktree exists, or whose status is
  `in-progress`, is being worked on; do not take it over without asking.
- If the type changes during the discussion, rename the branch to the new type
  before the approval (`git branch -m`, then push the new name and delete the old one
  on the remote).
- Requests from before ss-workflow 0.8.0 may still use the old places: a draft on a
  `req/REQ-<id>-<slug>` branch, or a `ready` request in `reqs/` on `develop` without
  a branch. The skills handle both: `/ss-workflow:new-req` renames such a draft branch
  to `<type>/REQ-<id>-<slug>`, and starting a `ready` request from `develop` creates
  its branch from `develop` then.
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
- `type: hotfix` requests name one project. Their draft lives on
  `hotfix/REQ-<id>-<slug>`, from `develop`. Starting one creates
  `hotfix/<name>-v<version>` in the workspace from its main branch, copies the
  request file onto it in the first commit, and deletes the draft branch. The project
  gets `hotfix/v<version>`, from the project's main branch.
- The worktree of a request is `.claude/worktrees/<branch with "/" replaced by "-">`
  under the workspace root, with the projects at their paths inside it.
- Never edit the `## Original` section. A draft that the developer discards is
  deleted with its branch. A request that is dropped after its approval gets
  `status: done` and a note in `## Notes` that explains why, and reaches `develop` in
  `reqs/done/`, so that its record is kept.
<!-- /ss-workflow:managed -->
