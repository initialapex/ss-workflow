---
name: ss-workflow-check-req
description: Check the state of all requests in an ss-workflow repository, repair inconsistent ones, claim a ready request by creating its branch and git worktree, and implement it there. In a request worktree, resume the implementation. When the implementation is finished, it marks the request for review and removes the worktree. Use when the developer asks what requests are pending, or wants to start or continue the implementation of a request.
argument-hint: "[REQ-id]"
---

# ss-workflow-check-req

Where this skill runs decides what it does:

| Where | What it does |
|-------|--------------|
| The root checkout, on any branch | Overview of all requests → repair anomalies → claim one `ready` request → implement it in a new worktree |
| A request worktree | Resume the implementation of that request |

Input: `$ARGUMENTS` (optional `REQ-xxxx` to pick a specific request)

This skill covers the implementation only. Verify and Review happen later in the root
checkout, when the developer runs `/ss-workflow-review`.

Supporting files:

- [references/anomalies.md](references/anomalies.md): inconsistent states and how to repair them
- [references/implement.md](references/implement.md): how to implement a request and hand it over

## Ground rules

- Read the root `AGENTS.md` ("Workflow settings", "Working agreement", "Branching
  model", "Commit convention") and `reqs/AGENTS.md` first. They are the source of
  truth. If they differ from this skill, follow them.
- Talk to the developer in `discussion-language`.
- One invocation handles one request. Never implement two requests in one worktree.
- A request is implemented only inside its own worktree. This skill never changes
  files in the root checkout, and never switches the root checkout to another branch.
- In a worktree, write code and try to compile it. Do not run tests, scripts, or
  executables there.
- Never force-push, and never rebase a branch that has been pushed.
- Do not take over an `in-progress` request without asking: another session may be
  working on it.

## Step 1: Find out where you are

1. If the root `AGENTS.md` has no `ss-workflow-version:`, stop and point to
   `/ss-workflow-init`.
2. Collect the following:
   - `git branch --show-current`
   - `git rev-parse --git-dir --git-common-dir`. If the two differ, this is a linked
     worktree.
   - `git worktree list --porcelain`. The first entry is the root checkout.
3. If a remote exists, run `git fetch --prune`.
4. Choose the ref that stands for `develop` in this run, called `<develop-ref>` below:
   `origin/develop` with a remote, `develop` without one. If the local `develop` has
   commits that are not on `origin/develop`, tell the developer: other sessions cannot
   see those requests until they are pushed.
5. Route:
   - A linked worktree → **Step 6**.
   - The root checkout → **Step 2**. The root checkout may be on any branch: this
     skill reads `develop` through `<develop-ref>` and does not need it checked out.

## Step 2: Overview

Build the list of requests without checking anything out.

1. **Drafts**: each `req/REQ-…` branch, local or remote. Read the title from its
   request file (`git show <branch>:reqs/<file>`).
2. **Approved requests**: each file in `reqs/` on `<develop-ref>`
   (`git ls-tree --name-only <develop-ref> reqs/`, then `git show <develop-ref>:<path>`).
3. **The request branch** of each approved request:
   - A local or remote branch whose name contains `REQ-<id>-` and does not start with
     `req/`.
   - For `type: hotfix`: a `hotfix/*` branch that contains the request file in `reqs/`
     or `reqs/done/`.
4. **The effective status**:
   - No request branch: the status on `<develop-ref>`, normally `ready`.
   - With a request branch: the status in the request file on that branch
     (`in-progress`, `review`, or `done`). `done` on a branch that is not merged means
     "merge pending".
5. For each request branch, also collect:
   - whether it exists locally, on the remote, or both
   - its worktree path, from `git worktree list`
   - the unpushed commits: `git log origin/<branch>..<branch> --oneline`
   - whether it is merged: `git merge-base --is-ancestor <branch> <develop-ref>`
6. Show a table sorted by status, then priority, then id:

   | ID | Title | Type | Priority | Status | Branch / worktree | Notes |
   |----|-------|------|----------|--------|-------------------|-------|

   Put anomalies in the Notes column. For `review` requests, note that they wait for
   `/ss-workflow-review`.

## Step 3: Repair anomalies

Compare what you collected with [references/anomalies.md](references/anomalies.md). If
there are anomalies, list them with the proposed repair for each, and ask the developer
which ones to apply. Apply the approved repairs before you claim anything.

If the developer declines a repair, continue, but do not claim the request it affects.

## Step 4: Choose a request

Candidates are the requests with the effective status `ready`, sorted by `priority`
(`high` > `normal` > `low`), then by id.

- `$ARGUMENTS` names a request:
  - `ready`: use it.
  - `in-progress` with a worktree: ask whether to resume it there. If yes, continue
    with Step 6, using the worktree path.
  - `in-progress` without a worktree: the request was reopened by a review, or its
    worktree was lost. Ask whether to continue it. If yes, recreate the worktree
    (`git worktree add <worktree path> <branch>`), and continue with Step 6.
  - `review`: say that the implementation is finished, and point to
    `/ss-workflow-review`.
  - A draft: say that it needs approval through `/ss-workflow-new-req` first.
- No candidates: report this and mention the next useful action, such as drafts to
  finish, requests waiting for `/ss-workflow-review`, or `/ss-workflow-new-req`.
- One candidate: confirm it with the developer.
- Several candidates: ask with AskUserQuestion. Show the top three as options, with the
  recommended one first. The developer can name any other request through "Other".

## Step 5: Claim and create the worktree

Decide the names first:

| Item | Value |
|------|-------|
| Branch | `<type>/REQ-<id>-<slug>`, for example `feat/REQ-0012-gui-button`. For `type: hotfix`: `hotfix/v<version>`, with the version from the request's spec. |
| Base | `<develop-ref>`. For `type: hotfix`: the main branch (`origin/<main branch>` with a remote). |
| Worktree path | `<root checkout>/.claude/worktrees/<branch with "/" replaced by "-">` |

Creating the branch is the claim. Git creates a branch name only once, so two sessions
cannot both succeed.

1. **Check the remote first**, if one exists:
   `git ls-remote --heads origin "*REQ-<id>-*"` (for a hotfix: `hotfix/v<version>`).
   If it lists a branch other than a `req/` branch, the request is already claimed. Go
   back to Step 4.
2. **Create the branch and the worktree** in one command:

   ```bash
   git worktree add --no-track -b <branch> <worktree path> <base>
   ```

   If git says that the branch already exists, another session claimed the request.
   Tell the developer, and go back to Step 4.
3. **Publish the branch** if a remote exists:

   ```bash
   git -C <worktree path> push -u origin <branch>
   ```

   If the remote rejects this push, or the push of the claim commit in the next step,
   another machine claimed the request at the same time. Remove the worktree and the
   local branch (`git worktree remove <worktree path>`, `git branch -D <branch>`),
   tell the developer, and go back to Step 4.
4. **Record the claim** as the first commit on the branch, in the worktree:
   - For `type: hotfix`, the request file is not on this branch yet. Copy it first:
     `git show <develop-ref>:reqs/<file> > reqs/<file>`.
   - Set `status: in-progress` and `branch: <branch>` in the request file.
   - Commit and push:

     ```
     chore(reqs): claim REQ-0012

     Refs: REQ-0012
     ```

5. If the repository has submodules, run
   `git -C <worktree path> submodule update --init --recursive`.
6. Tell the developer the worktree path and the branch.

From here on, every file path and every command belongs to the worktree. Continue with
[references/implement.md](references/implement.md).

## Step 6: In a request worktree

1. Identify the request: the file in `reqs/` on this branch whose `branch` equals the
   current branch.
2. If a remote exists, run `git pull --ff-only` on this branch.
3. Act on the status:

| Status | Action |
|--------|--------|
| `in-progress` | Resume. Find where the work stopped: `git status`, `git log <develop-ref>..HEAD --oneline`, and `## Notes`, including review feedback if the request was reopened. Summarize it for the developer. Continue with [references/implement.md](references/implement.md) from its Step 2. |
| `review` or `done` | The implementation is finished, and this worktree should no longer exist. Check that it has no uncommitted changes and no unpushed commits, then remove it as in Step 4 of [references/implement.md](references/implement.md). Point to `/ss-workflow-review` (for `review`) or `/ss-workflow-merge` (for `done`). |
| No request file, or `draft` / `ready` | This is an anomaly. See [references/anomalies.md](references/anomalies.md). |
