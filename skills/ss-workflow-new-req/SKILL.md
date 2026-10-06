---
name: ss-workflow-new-req
description: Create a new request (feature, fix, docs change, hotfix) in reqs/ of an ss-workflow repository, discuss its spec with the developer, and mark it ready once the developer approves. Use when the developer asks to add a request, requirement, feature, or bug fix to the workflow, hands over a requirement .md file, or wants to continue a draft request.
argument-hint: "[requirement.md | REQ-id | short description]"
---

# ss-workflow-new-req

Create one request file in `reqs/`, agree on its spec with the developer, and mark it
`ready`. This skill only writes the request. It never implements it.

Input: `$ARGUMENTS`

## Ground rules

- Read the root `AGENTS.md` section "Workflow settings" and `reqs/AGENTS.md` first.
  `reqs/AGENTS.md` is the source of truth for the file name, the frontmatter, and the
  lifecycle. If it differs from this skill, follow `reqs/AGENTS.md`.
- Talk to the developer in `discussion-language`. Write the request in `reqs-language`.
  Keep the headings `## Spec`, `## Original`, and `## Notes` in English, because other
  skills look them up.
- Requests are created on `develop`, including `type: hotfix` requests.
- Never edit the `## Original` section after it is written.
- A request moves to `ready` only after the developer explicitly approves the spec.
- Commit messages are English and follow the root `AGENTS.md` section
  "Commit convention".

## Step 1: Preconditions

1. If the root `AGENTS.md` has no `ss-workflow-version:`, stop and tell the developer to
   run `/ss-workflow-init` first.
2. Check the current branch with `git branch --show-current`:
   - On `develop`: continue.
   - On another branch with a clean working tree, and not inside a linked worktree
     (`git rev-parse --git-dir` and `--git-common-dir` give the same path): ask whether
     to switch to `develop`.
   - Inside a request worktree, or with uncommitted changes: stop. Explain that
     requests are created on `develop` in the main checkout, and that the developer can
     run this skill there.
3. If a remote exists, run `git fetch` and `git pull --ff-only`, so that the id
   numbering sees the latest requests. If the pull cannot fast-forward, report it and
   ask how to continue.

## Step 2: Decide what to do with the input

| `$ARGUMENTS` | Action |
|--------------|--------|
| A `REQ-xxxx` id, or the path of an existing request file | Resume that request at Step 5. If its status is not `draft`, say so and ask what the developer wants to change. |
| A path to another `.md` / text file | Read it. Its full content becomes `## Original`, verbatim. |
| Free text | That text becomes `## Original`, verbatim. |
| Empty | List the requests with `status: draft`, if any, and ask whether to continue one of them or create a new one. For a new one, ask the developer to describe what they need. Their answer becomes `## Original`. |

Then check the following:

- **Several requests in one input**: if the input describes changes that can be
  implemented and reviewed independently, propose splitting it into several requests
  and ask. Each request keeps the part of the original text that belongs to it.
- **Duplicates**: scan the frontmatter titles and specs of the open requests in
  `reqs/`, and the titles in `reqs/done/`. If one overlaps, show it and ask whether to
  extend that request (only if it is still `draft` or `ready`), create a follow-up, or
  continue.

## Step 3: Create the draft file

1. **id**: find the highest `REQ-<n>` among the file names in `reqs/` and `reqs/done/`,
   and add 1. Use `REQ-0001` when none exist.
2. **type**: infer it from the content (`feat`, `fix`, `docs`, `refactor`, `perf`,
   `test`, `chore`). Use `hotfix` only when the problem affects a released version and
   cannot wait for the next release. Confirm `hotfix` with the developer.
3. **title**: a short imperative phrase. **slug**: lowercase English kebab-case, at
   most five words.
4. **priority**: `normal`, unless the developer says otherwise. Use `high` for
   `hotfix`.
5. Write `reqs/REQ-<id>-<yyyyMMdd>-<slug>.md` in the format from `reqs/AGENTS.md`,
   with `status: draft`, an empty `branch:`, and today's date in `created`.
6. Put the original input into `## Original`, byte for byte. If the input came from a
   file, add one line above it: `Source: <original path>`.

If the source file is inside the repository (for example, the developer dropped it
into `reqs/`), ask whether to delete it now that its content is preserved in
`## Original`. Leave files outside the repository alone.

## Step 4: Understand the context

Before you ask the developer anything, read what the request touches:

- `docs/*-spec.md` and the `README.md` of each affected project in `src/`
- The relevant source files, enough to know what exists today
- Related requests in `reqs/` and `reqs/done/`

Do not ask the developer questions that the repository already answers.

## Step 5: Discuss and write the spec

Draft `## Spec` with these parts, with the subheadings in `reqs-language`:

| Part | Content |
|------|---------|
| Goal | The problem to solve or the outcome wanted, in one or two sentences |
| Scope | The concrete changes: behavior, UI, API, data, and the projects affected |
| Acceptance criteria | A checklist of conditions that can each be checked, so a reviewer can tell whether the request is done |
| Out of scope | What this request deliberately does not cover |
| Open questions | Anything not decided yet. This part must be empty before `ready`. |

For `type: hotfix`, also state the affected released version and the expected hotfix
version (the next patch version after the latest tag on the main branch).

Then go through these rounds with the developer:

1. Show the draft spec, and ask only the questions whose answers change what gets
   built. Use AskUserQuestion when the answer is a choice between options. Ask in plain
   text when the answer is free-form.
2. Update the file after each round, and move resolved items out of "Open questions".
3. Flag what the developer may not have considered: breaking changes, effects on other
   projects or samples, missing tests, and documentation that would need updating.
4. If the request turns out to be too large for one branch, propose splitting it
   (Step 2).

Record the decisions that explain *why* in `## Notes`, with the date.

## Step 6: Approval

When "Open questions" is empty, show the final spec and ask with AskUserQuestion:

| Option | Action |
|--------|--------|
| Approve (Recommended) | Set `status: ready`, then continue with Step 7. |
| Keep as draft | Leave `status: draft`, then commit it in Step 7, so that the draft is not lost. |
| Keep discussing | Go back to Step 5. |
| Discard | If the file was never committed, delete it. If it was committed, set `status: done`, add a note in `## Notes` that explains why it was dropped, and move it to `reqs/done/` with `git mv`. Commit as in Step 7. |

## Step 7: Commit

1. If a remote exists, run `git fetch` again. If `origin/develop` has new commits, run
   `git pull --ff-only` and re-check the id. If another request took the same id,
   renumber this one (the file name and the `id` field) before you commit.
2. Stage only the request file, plus the deleted source file if there is one.
3. Commit:

   ```
   docs(reqs): add REQ-0012 gui button modification

   <one or two sentences that summarize the goal>

   Refs: REQ-0012
   ```

   For a draft, use `docs(reqs): add draft REQ-0012 <title>`. For a later change to an
   existing request, use `docs(reqs): update REQ-0012 <what changed>`.
4. If a remote exists, push `develop`. If the push is rejected, pull with
   `--ff-only` if possible, or with `--rebase` if not, re-check the id, and push again.
   If the remote refuses direct pushes to `develop`, report it and leave the commit
   local.

## Step 8: Report

Tell the developer, in `discussion-language`:

- The request id, title, type, priority, status, and file path
- The commit, and whether it was pushed
- The next step: `/ss-workflow-check-req` on `develop` claims a `ready` request and
  starts the implementation in a worktree
