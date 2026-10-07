---
name: ss-workflow-merge
description: Merge a reviewed request branch into develop, or a release or hotfix branch into the main branch and develop with a tag, following the gitflow rules of an ss-workflow repository. Also finishes a merge that already happened on the remote (closes the request, removes the worktree and branches) and closes a dropped request. Use when the developer says a request is reviewed and should be merged, asks to merge a release or hotfix, or asks to clean up after a merge request was merged.
argument-hint: "[REQ-id | branch]"
---

# ss-workflow-merge

Merge one branch according to its kind, then clean up.

Input: `$ARGUMENTS` (optional `REQ-xxxx` or a branch name)

| Branch kind | Merges into | Guide |
|-------------|-------------|-------|
| Request (`feat/…`, `fix/…`, `docs/…`, …) | `develop` | [references/request.md](references/request.md) |
| `release/v…` | main branch and `develop`, plus a tag | [references/release.md](references/release.md) |
| `hotfix/v…` | main branch and `develop`, plus a tag | [references/hotfix.md](references/hotfix.md) |

## Ground rules

- Read the root `AGENTS.md` ("Workflow settings", "Branching model", "Commit
  convention") and `reqs/AGENTS.md` first. They are the source of truth.
- Talk to the developer in `discussion-language`.
- Merge only what the developer has reviewed. A request must have the effective status
  `review`, or must already be closed on its branch by an earlier run of this skill
  (merge pending). Otherwise, stop and point to `/ss-workflow-check-req`.
- Always merge with `--no-ff`, so that every request, release, and hotfix stays visible
  as one merge commit. Never squash. Never rebase a pushed branch. Never force-push.
- Merge commits use this message, and are exempt from the `<type>(<scope>)` rule:

  ```
  Merge <source branch> into <target branch>

  <request title, or "Release vX.Y.Z" / "Hotfix vX.Y.Z">

  Refs: REQ-0012
  ```

  Leave out the `Refs:` line for a release.
- The "main checkout" is the repository's primary working tree (the first entry of
  `git worktree list`). Merges into `develop` and into the main branch run there.
  Before you use it, check that it has no uncommitted changes to tracked files. If it
  does, stop and report them.
- If a merge has conflicts that are not trivial, show them and ask the developer how to
  resolve them. Do not guess at the intent of other people's changes.

## Step 1: Preconditions and target

1. If the root `AGENTS.md` has no `ss-workflow-version:`, stop and point to
   `/ss-workflow-init`.
2. If a remote exists, run `git fetch --prune --tags`.
3. Find the target branch:

| Situation | Target |
|-----------|--------|
| `$ARGUMENTS` is a `REQ-xxxx` id | The `branch` of that request |
| `$ARGUMENTS` is a branch name | That branch |
| The current branch is a request, `release/*`, or `hotfix/*` branch | The current branch |
| On `develop` without arguments | List the candidates and ask: requests with the effective status `review`, requests whose merge is pending on the remote, and open `release/*` and `hotfix/*` branches. If the developer asks to bring `develop` to the main branch without a release branch, see "Pre-1.0 sync" in [references/release.md](references/release.md). If there are no candidates, say so and stop. |
| On the main branch, or anywhere else | Explain where this skill runs, and stop. |

4. Tell the developer what you are about to merge, and into what, before you start.

## Step 2: Check the remote state

Skip this step if `remote-platform` is `none`.

Look for a merge request of the target branch with `remote-cli`:

- GitHub: `gh pr view <branch> --json state,url,baseRefName,mergeCommit`
- GitLab: `glab mr view <branch> --output json`

| Result | Action |
|--------|--------|
| Merged | The merge is already done on the remote. Skip the merge steps of the guide, and go to its "Finish" section. |
| Open | Show the URL. Ask whether to wait for the remote merge (stop here; the developer runs this skill again later), or to merge locally now (the push then closes the merge request). |
| Closed without merging | Show it. Ask whether to merge locally, to open a new merge request, or to stop. |
| None | Continue with Step 3. |

Also check git itself: if `git merge-base --is-ancestor <branch> origin/<target>`
succeeds, the branch is already merged, even without a merge request.

## Step 3: Choose the merge method

Read `merge-method` from "Workflow settings":

| Value | Action |
|-------|--------|
| `local` | Merge locally, then push. |
| `remote` | Open a merge request on the remote. |
| `ask`, or missing | If `remote-platform` is not `none`, ask the developer with AskUserQuestion: "Merge locally and push" or "Open a merge request on the remote". If there is no remote platform, merge locally. |

## Step 4: Follow the guide

Continue with the guide for the branch kind (the table at the top). Each guide has a
"Merge locally" section, a "Merge request on the remote" section, and a "Finish"
section.

## Step 5: Clean up (shared by all guides)

Run this only after the merge is confirmed, either by
`git merge-base --is-ancestor <branch> <target>` for every target, or by a merge
request in the state "merged".

1. **Worktree** (request and hotfix branches). Run this from the main checkout, not
   from inside the worktree:

   ```bash
   git -C <main checkout> worktree remove <worktree path>
   ```

   - If git refuses because of modified or untracked files, show
     `git -C <worktree path> status --short` and ask before you use `--force`.
   - If the folder cannot be deleted because it is in use (a session, an editor, or
     Visual Studio has it open), tell the developer to close those programs and to run
     this skill again. Then continue with the other steps.
2. **Local branch**: `git branch -d <branch>`. If git refuses because the remote did a
   squash merge, and the merge request state is "merged", use `git branch -D <branch>`.
3. **Remote branch**: if it still exists, `git push origin --delete <branch>`.
4. Run `git worktree prune` and `git fetch --prune`.
5. Leave the main checkout on `develop`.

## Step 6: Report

Tell the developer, in `discussion-language`:

- What was merged into what, the merge commits, and the tag if there is one
- What was pushed
- What was cleaned up, and anything that could not be removed
- The next step: other requests waiting in `review`, `/ss-workflow-check-req` for the
  next request, or `/ss-workflow-release` when it is time to release

## Closing a dropped request

When the developer wants to close a request without merging it:

1. Confirm it. Name the branch and the number of commits that will be abandoned
   (`git log develop..<branch> --oneline`).
2. In the main checkout on `develop`: set `status: done`, add a dated line to
   `## Notes` that says the request was dropped and why, and move the file to
   `reqs/done/` with `git mv`. Commit `chore(reqs): drop REQ-0012`, and push.
3. Ask separately whether to delete the branch, because its commits are not merged.
   Only after a clear yes: remove the worktree, run `git branch -D <branch>`, and delete
   the remote branch. Otherwise, keep the branch and say that it still exists.
