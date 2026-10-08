---
name: merge
description: Close a reviewed request by merging its branch into develop, or merge a release or hotfix branch into the main branch and develop with a tag, following the gitflow rules of an ss-workflow repository. Also finishes a merge that already happened on the remote (closes the request, deletes the branches) and closes a dropped request. Use when the developer says a request is reviewed and should be merged or closed, asks to merge a release or hotfix, or asks to clean up after a merge request was merged.
argument-hint: "[REQ-id | branch]"
---

# merge

Merge one branch according to its kind, then clean up. For a request, running this
skill is the developer's sign-off: the request is closed.

Input: `$ARGUMENTS` (optional `REQ-xxxx` or a branch name)

| Branch kind | Merges into | Guide |
|-------------|-------------|-------|
| Request (`feat/…`, `fix/…`, `docs/…`, …) | `develop` | [references/request.md](references/request.md) |
| `release/v…` | main branch and `develop`, plus a tag | [references/release.md](references/release.md) |
| `hotfix/v…` | main branch and `develop`, plus a tag | [references/hotfix.md](references/hotfix.md) |

`req/*` branches are not merged here. `/ss-workflow:new-req` merges them when the
developer approves the spec.

## Ground rules

- Read the root `AGENTS.md` ("Workflow settings", "Working agreement", "Branching
  model", "Commit convention") and `reqs/AGENTS.md` first. They are the source of
  truth.
- Talk to the developer in `discussion-language`.
- This skill runs in the root checkout, not in a worktree. It switches the root
  checkout between the target branch, `develop`, and the main branch, and leaves it on
  `develop`.
- A request or a hotfix must have the effective status `review`, or must already be
  closed on its branch by an earlier run of this skill (merge pending). If it is
  `in-progress`, stop and point to `/ss-workflow:check-req`.
- If the request's `## Notes` has no passed Review, or no Verify result, say so. Say
  it too when the last Verify has a check that is `failed` or `did not run`, when a
  `### Behavior changes` item was not confirmed in the Review, or when `## Q&A` has a
  pending entry. Ask the developer whether to run `/ss-workflow:review` first, or to
  merge anyway. The developer may merge without a review, but must decide it
  knowingly: record the question and the answer in `## Q&A` (stage `review`), in the
  commit that closes the request.
- Always merge with `--no-ff`, so that every request, release, and hotfix stays visible
  as one merge commit. Never squash. Never rebase a pushed branch. Never force-push.
- **Pushing**: follow "Remote and pushing" in the root `AGENTS.md`. Where this skill
  says "push", push only when a remote exists and `push-policy` allows it: `auto`
  pushes, `ask` asks before the first push of this run, and `never` does not push. A
  missing `push-policy` means `auto`. Steps that fetch or pull apply only with a
  remote. When a push is skipped, go on, and list the unpushed branches in the report.
- Pushing the main branch or a tag publishes a version. Ask right before that push,
  every time, also with `push-policy: auto`. With `push-policy: never`, do not push:
  show the command, and the developer runs it.
- Merge commits use this message, and are exempt from the `<type>(<scope>)` rule:

  ```
  Merge <source branch> into <target branch>

  <request title, or "Release vX.Y.Z" / "Hotfix vX.Y.Z">

  Refs: REQ-0012
  ```

  Leave out the `Refs:` line for a release.
- `setup-command`, `build-command`, `test-command`, and `verify-command` come from
  "Workflow settings", and they depend on the project's toolchain. Where a guide says
  to run them, a command that is empty is skipped: say that it is not configured, and
  do not invent one.
- If a merge has conflicts that are not trivial, show them and ask the developer how to
  resolve them. Do not guess at the intent of other people's changes.

## Step 1: Preconditions and target

1. If the root `AGENTS.md` has no `ss-workflow-version:`, stop and point to
   `/ss-workflow:init`.
2. If this is a linked worktree, stop. Explain that merges run in the root checkout.
3. `git status --porcelain` must show no changes to tracked files. If it does, stop
   and report them.
4. If a remote exists, run `git fetch --prune --tags`.
5. Find the target branch:

| Situation | Target |
|-----------|--------|
| `$ARGUMENTS` is a `REQ-xxxx` id | The request branch of that request: the branch whose name contains `REQ-<id>-` and does not start with `req/`, or the `hotfix/*` branch that carries its file |
| `$ARGUMENTS` is a branch name | That branch |
| The root checkout is on a request, `release/*`, or `hotfix/*` branch | That branch |
| The root checkout is on `develop`, without arguments | List the candidates and ask: requests with the effective status `review` (say for each whether its Review passed), requests whose merge is pending on the remote, and open `release/*` and `hotfix/*` branches. If the developer asks to bring `develop` to the main branch without a release branch, see "Pre-1.0 sync" in [references/release.md](references/release.md). If there are no candidates, say so and stop. |
| The root checkout is on a `req/*` branch, or on the main branch | Explain what the root checkout is busy with, and stop. |

6. If the root checkout is on another branch than the target and than `develop`, it is
   busy with something else. Say what, and stop.
7. Tell the developer what you are about to merge, and into what, before you start.

## Step 2: Check the remote state

Skip this step if there is no remote.

First check git itself, for every branch that the target branch merges into: if
`git merge-base --is-ancestor <branch> origin/<target>` succeeds, the branch is
already merged on the remote, with or without a merge request. Skip the merge steps
of the guide, and go to its "Finish" section.

If `remote-platform` is not `none`, also look for a merge request of the target
branch with `remote-cli`:

- GitHub: `gh pr view <branch> --json state,url,baseRefName,mergeCommit`
- GitLab: `glab mr view <branch> --output json`

| Result | Action |
|--------|--------|
| Merged | The merge is already done on the remote. Skip the merge steps of the guide, and go to its "Finish" section. |
| Open | Show the URL. Ask whether to wait for the remote merge (stop here; the developer runs this skill again later), or to merge locally now (the push then closes the merge request). |
| Closed without merging | Show it. Ask whether to merge locally, to open a new merge request, or to stop. |
| None | Continue with Step 3. |

## Step 3: Choose the merge method

Read `merge-method` from "Workflow settings":

| Value | Action |
|-------|--------|
| `local` | Merge locally, then push. |
| `remote` | Open a merge request on the remote. If `remote-platform` is `none`, there is nothing to open it with: say so, and merge locally. |
| `ask`, or missing | If `remote-platform` is not `none`, ask the developer with AskUserQuestion: "Merge locally and push" or "Open a merge request on the remote". If there is no remote platform, merge locally. |

A merge request needs the branch on the remote, with all its commits. If the branch
is not pushed and you may not push it (`push-policy: never`, or the developer
declined), follow the "Prepare" section of the guide, then stop: say which branch the
developer has to push, and that running this skill again opens the merge request.

Without a remote, "Merge locally" is the whole merge: the steps that pull and push
are skipped, and the merge is confirmed on the local branches.

## Step 4: Follow the guide

Continue with the guide for the branch kind (the table at the top). Each guide has a
"Prepare" section, a "Merge locally" section, a "Merge request on the remote" section,
and a "Finish" section.

## Step 5: Clean up (shared by all guides)

Run this only after the merge is confirmed, either by
`git merge-base --is-ancestor <branch> <target>` for every target, or by a merge
request in the state "merged".

1. Switch the root checkout to `develop`.
2. **Leftover worktree**: the worktree of a request is normally removed when its
   implementation is finished. If `git worktree list` still shows one for this branch,
   check that it has no uncommitted changes, and remove it
   (`git worktree remove <worktree path>`). If the folder is in use, tell the developer
   to close the programs that hold it, and continue.
3. **Local branch**: `git branch -d <branch>`. If git refuses because the remote did a
   squash merge, and the merge request state is "merged", use `git branch -D <branch>`.

   `git branch -d` is not a safety check. It also deletes a branch that is pushed but
   not merged, with only a warning, and in this workflow most branches are pushed. The
   confirmation at the start of this step is what protects the work, so never skip it.
4. **Remote branch**: if it still exists and pushing is allowed,
   `git push origin --delete <branch>`. Otherwise, leave it, and name it in the report
   as a branch that the developer can delete on the remote.
5. Run `git worktree prune`, and with a remote `git fetch --prune`.

If the target was merged locally and not pushed, the merge exists in this repository
only. Keep that in the report: the remote still shows the request as it was.

## Step 6: Report

Tell the developer, in `discussion-language`:

- What was merged into what, the merge commits, and the tag if there is one
- That the request is closed, with its id and title
- What was pushed, and what is not on the remote yet: the branches and tags that the
  developer has to push, with the command
- What ran before the merge (build, tests, verify script) and its result, what did
  not run and why, and what the developer accepted although it failed or did not run
- What was cleaned up, and anything that could not be removed
- That the root checkout is on `develop`
- The next step: other requests waiting for `/ss-workflow:review`,
  `/ss-workflow:check-req` for the next request, or `/ss-workflow:release` when it is
  time to release

## Closing a dropped request

When the developer wants to close a request without merging its code:

1. Confirm it. Name the branch and the number of commits that will be abandoned
   (`git log develop..<branch> --oneline`).
2. Close the request file on `develop` through a short-lived branch, so that `develop`
   is only changed by a merge:
   - `git checkout -b req/REQ-<id>-drop develop`
   - Take the latest request file from the request branch, if there is one
     (`git show <branch>:reqs/<file> > reqs/<file>`), so that its notes are kept.
   - Set `status: done`, and add a dated line to `## Notes` that says the request was
     dropped and why.
   - Add the question and the developer's answer to `## Q&A` (stage `review`): that
     the request is dropped, and why.
   - `git mv reqs/<file> reqs/done/<file>`, then commit `chore(reqs): drop REQ-0012`.
   - Merge it into `develop` with `--no-ff`, push, and delete the `req/…-drop` branch.
3. Ask separately whether to delete the request branch, because its commits are not
   merged. Only after a clear yes: `git branch -D <branch>`, and delete the remote
   branch when pushing is allowed. Otherwise, keep the branch and say that it still
   exists.
