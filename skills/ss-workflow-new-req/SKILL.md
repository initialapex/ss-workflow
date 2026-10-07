---
name: ss-workflow-new-req
description: Create a new request (feature, fix, docs change, hotfix) in an ss-workflow repository. Opens a req/ branch in the root checkout, writes the request file, discusses its spec with the developer, and merges it into develop as ready once the developer approves. Use when the developer asks to add a request, requirement, feature, or bug fix to the workflow, hands over a requirement .md file, or wants to continue a draft request.
argument-hint: "[requirement.md | REQ-id | short description]"
---

# ss-workflow-new-req

Discuss one request on its own `req/REQ-<id>-<slug>` branch in the root checkout. When
the developer approves the spec, merge the branch into `develop`, where the request
waits as `ready` for a session to claim it. This skill only writes the request. It
never implements it.

Input: `$ARGUMENTS`

## Ground rules

- Read the root `AGENTS.md` ("Workflow settings", "Working agreement") and
  `reqs/AGENTS.md` first. `reqs/AGENTS.md` is the source of truth for the file name,
  the frontmatter, and the lifecycle. If it differs from this skill, follow it.
- Talk to the developer in `discussion-language`. Write the request in `reqs-language`.
  Keep the headings `## Spec`, `## Original`, and `## Notes` in English, because other
  skills look them up.
- This skill runs in the root checkout, not in a worktree.
- A `req/` branch changes only its own request file.
- One request per `req/` branch.
- Never edit the `## Original` section after it is written.
- A request moves to `ready` only after the developer explicitly approves the spec.
- Commit messages are English and follow the root `AGENTS.md` section
  "Commit convention".

## Step 1: Preconditions

1. If the root `AGENTS.md` has no `ss-workflow-version:`, stop and tell the developer to
   run `/ss-workflow-init` first.
2. If this is a linked worktree (`git rev-parse --git-dir` and `--git-common-dir`
   give different paths), stop. Explain that spec discussions run in the root
   checkout.
3. If a remote exists, run `git fetch --prune`.
4. Check the current branch with `git branch --show-current`:

| Current branch | Action |
|----------------|--------|
| `develop` | Check that `git status --porcelain` shows no changes to tracked files. If it does, stop and report them. With a remote, run `git pull --ff-only`. Continue with Step 2. |
| A `req/REQ-…` branch | A spec discussion is open here. If `$ARGUMENTS` is empty or names this request, resume it at Step 5. Otherwise, ask whether to pause this draft first (commit it, push it, and switch to `develop`). |
| Any other branch | The root checkout is busy: a request branch means a review, and a `release/*` branch means a release. Say which one, and stop. |

## Step 2: Decide what to do with the input

| `$ARGUMENTS` | Action |
|--------------|--------|
| A `REQ-xxxx` id | Find its `req/REQ-xxxx-…` branch, locally or on the remote. Check it out, pull it, and resume at Step 5. If the request is already on `develop` (`ready` or later), say so, and ask what the developer wants to change. A change to a `ready` request that nobody has claimed is made on a new `req/` branch with the same id. |
| A path to a `.md` / text file | Read it. Its full content becomes `## Original`, verbatim. |
| Free text | That text becomes `## Original`, verbatim. |
| Empty | List the open drafts: the `req/*` branches, local and remote, each with the title from its request file. Ask whether to continue one of them or to create a new one. For a new one, ask the developer to describe what they need. Their answer becomes `## Original`. |

Then check the following:

- **Several requests in one input**: if the input describes changes that can be
  implemented and reviewed independently, propose splitting it, and ask. Handle the
  resulting requests one after another: finish this skill for the first one, then
  start again for the next one with its part of the original text.
- **Duplicates**: compare with the titles and specs of the requests in `reqs/` on
  `develop`, the open drafts on `req/*` branches, and the titles in `reqs/done/`. If
  one overlaps, show it and ask whether to extend that request (only if it is still a
  draft, or `ready` and unclaimed), create a follow-up, or continue.

## Step 3: Open the `req/` branch

1. **id**: the highest id in use, plus 1. Use `REQ-0001` when none is in use. An id is
   in use when:
   - a file in `reqs/` or `reqs/done/` on `develop` has it, or
   - a branch name contains it: `git branch -a --list "*REQ-*"`.
2. **type**: infer it from the content (`feat`, `fix`, `docs`, `refactor`, `perf`,
   `test`, `chore`). Use `hotfix` only when the problem affects a released version and
   cannot wait for the next release. Confirm `hotfix` with the developer.
3. **title**: a short imperative phrase. **slug**: lowercase English kebab-case, at
   most five words.
4. **priority**: `normal`, unless the developer says otherwise. Use `high` for
   `hotfix`.
5. Create and publish the branch. Publishing it reserves the id for other sessions and
   machines:

   ```bash
   git checkout -b req/REQ-<id>-<slug> develop
   git push -u origin req/REQ-<id>-<slug>      # with a remote
   ```

   If the remote now has another branch with the same id (fetch and list again),
   another session took the id at the same time. Rename your branch to the next free
   id (`git branch -m`, delete the wrong remote branch, and push again).

## Step 4: Create the draft file

1. Write `reqs/REQ-<id>-<yyyyMMdd>-<slug>.md` in the format from `reqs/AGENTS.md`,
   with `status: draft`, an empty `branch:`, and today's date in `created`. The
   `branch` field is for the implementation branch, not for this `req/` branch.
2. Put the original input into `## Original`, byte for byte. If the input came from a
   file, add one line above it: `Source: <original path>`.
3. If the source file is inside the repository (for example, the developer dropped it
   into `reqs/`), ask whether to delete it on this branch now that its content is
   preserved in `## Original`. Leave files outside the repository alone.
4. Commit and push, so that the draft is not lost:

   ```
   docs(reqs): add draft REQ-0012 gui button modification

   Refs: REQ-0012
   ```

## Step 5: Understand the context

Before you ask the developer anything, read what the request touches:

- `docs/*-spec.md` and the `README.md` of each affected project in `src/`
- The relevant source files, enough to know what exists today
- Related requests in `reqs/` and `reqs/done/`

Do not ask the developer questions that the repository already answers.

## Step 6: Discuss and write the spec

### What the spec settles

The spec settles the following before any code is written:

- Everything that the developer or a user sees or uses: the UI, commands and their
  options, file formats, and the public API. These go into "Scope".
- The software architecture. It goes into "Architecture".

Everything below that level is left to the implementation, for example the names of
private functions and the layout of a single file. Settle such a detail in the spec
only if the developer wants to.

`## Spec` has these parts, with the subheadings in `reqs-language`:

| Part | Content |
|------|---------|
| Goal | The problem to solve or the outcome wanted, in one or two sentences |
| Scope | The concrete changes: behavior, UI, commands, file formats, API, data, and the projects affected |
| Architecture | How the change is built into the software: the modules, classes, or components that are added or changed, what each one is responsible for, how they call each other, how data flows between them, the important data structures and stored state, and new dependencies. Say where the change fits into the existing structure. If the change needs no architectural decision, say so in one sentence and name the place it goes into. Do not leave this part out. |
| Acceptance criteria | A checklist (`- [ ]`) of conditions that can each be checked, so that Verify and Review can tell whether the request is done |
| How to verify | The tests, scripts, or manual steps that show the criteria are met. Say for each criterion whether it is checked automatically (Verify) or by hand (Review). |
| Out of scope | What this request deliberately does not cover |
| Open questions | Anything not decided yet. This part must be empty before `ready`. |

For `type: hotfix`, also state the affected released version and the hotfix version
(the next patch version after the latest tag on the main branch).

### How to start

Look at `## Original`:

- It says what to build: draft the spec, and go to "Rounds".
- It only describes a need or a problem, without a way to solve it: explore first.
  1. Ask about the problem itself, and only what the repository does not answer: who
     needs this, what they do today, what is wrong with that, and which limits apply
     (compatibility, performance, hardware, time).
  2. Propose two or three ways to solve it, from what you read in the code. For each
     one, say how it works for the user, its architecture in a few lines, what it
     affects, and its cost and risks. Recommend one, and say why. Ask with
     AskUserQuestion, with the recommended one first.
  3. Draft the spec from the way that the developer chose or changed.

### Architecture

Propose the architecture yourself, from the existing code. Do not ask the developer to
design it. If more than one structure is reasonable, show the alternatives with their
trade-offs, and recommend one. The developer confirms the architecture, like the rest
of the spec.

### When the developer does not know

If the developer cannot answer a question, do not leave it in "Open questions", and do
not decide it silently. Propose a default, and say why. If the developer accepts it,
write it into the spec, and record it in `## Notes` as
`Assumption (yyyy-MM-dd): <what>, because <why>`, so that it is checked again in the
Review.

### Rounds

Go through these rounds with the developer:

1. Show the draft spec, and ask only the questions whose answers change what gets
   built. Use AskUserQuestion when the answer is a choice between options. Ask in plain
   text when the answer is free-form.
2. Update the file after each round, and move resolved items out of "Open questions".
   Commit and push after each round (`docs(reqs): update REQ-0012 <what changed>`).
3. Flag what the developer may not have considered: breaking changes, effects on other
   projects or samples, missing tests, and documentation that would need updating.
4. If the request turns out to be too large for one branch, propose splitting it
   (Step 2).

Record the decisions that explain *why* in `## Notes`, with the date.

## Step 7: Approval

When "Open questions" is empty and "Architecture" is filled in, show the final spec
and ask with AskUserQuestion:

| Option | Action |
|--------|--------|
| Approve (Recommended) | Continue with Step 8. |
| Keep as draft | Commit and push what is there. Switch the root checkout back to `develop`. The `req/` branch stays, and the developer continues later with `/ss-workflow-new-req REQ-0012`. Then go to Step 9. |
| Keep discussing | Go back to Step 6. |
| Discard | Confirm once more, because the draft and its original text are deleted. Then switch to `develop`, delete the branch (`git branch -D`, and `git push origin --delete` with a remote), and go to Step 9. Nothing reaches `develop`. |

## Step 8: Merge into `develop`

1. On the `req/` branch: set `status: ready`. Commit and push:

   ```
   docs(reqs): mark REQ-0012 ready

   <one or two sentences that summarize the goal>

   Refs: REQ-0012
   ```

2. Read `merge-method` from "Workflow settings". If it is `remote`, open a merge
   request from the `req/` branch into `develop` (title
   `docs(reqs): add REQ-0012 <title>`), give the developer the URL, switch the root
   checkout back to `develop`, and go to Step 9. The request becomes `ready` when the
   merge request is merged. Otherwise, continue.
3. Merge locally:

   ```bash
   git checkout develop
   git pull --ff-only                          # with a remote
   git merge --no-ff req/REQ-<id>-<slug> -m "Merge req/REQ-<id>-<slug> into develop" -m "<request title>" -m "Refs: REQ-<id>"
   git push                                    # with a remote
   ```

   If the push is rejected, run `git pull --no-rebase`, then push again. If the remote
   refuses direct pushes to `develop`, undo the local merge
   (`git reset --hard HEAD^` while `HEAD` is that merge commit, which only removes the
   unpublished merge commit), and open a merge request as in step 2.
4. Delete the `req/` branch: `git branch -d`, and with a remote
   `git push origin --delete`.

## Step 9: Report

Tell the developer, in `discussion-language`:

- The request id, title, type, priority, and status
- Where it is: on `develop` (`ready`), on its `req/` branch (draft), in an open merge
  request, or discarded
- That the root checkout is back on `develop`
- The next step for a `ready` request: any session can run `/ss-workflow-check-req`
  to claim it and implement it in a worktree
