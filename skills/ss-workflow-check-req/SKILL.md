---
name: ss-workflow-check-req
description: Check the state of all open requests in an ss-workflow repository, repair inconsistent ones, claim a ready request into its own git worktree and implement it, or resume or review-check the request of the current worktree. Use when the developer asks what requests are pending, wants to start or continue work on a request, or asks whether a request is finished.
argument-hint: "[REQ-id]"
---

# ss-workflow-check-req

Where this skill runs decides what it does:

| Where | What it does |
|-------|--------------|
| `develop`, main checkout | Overview of open requests → repair anomalies → claim one `ready` request → implement it in a new worktree |
| A request worktree | Resume the implementation, or, if the request is in `review`, ask the developer about the review |

Input: `$ARGUMENTS` (optional `REQ-xxxx` to pick a specific request)

Supporting files:

- [references/anomalies.md](references/anomalies.md): inconsistent states and how to repair them
- [references/implement.md](references/implement.md): how to implement a request and hand it over for review

## Ground rules

- Read the root `AGENTS.md` ("Workflow settings", "Branching model", "Commit
  convention") and `reqs/AGENTS.md` first. They are the source of truth. If they differ
  from this skill, follow them.
- Talk to the developer in `discussion-language`.
- One invocation handles one request. Never implement two requests in one worktree.
- A request is implemented only inside its own worktree. Never change source files in
  the main checkout. The only edits made in the main checkout are request frontmatter
  changes on `develop`.
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
   - `git worktree list --porcelain`
   - `git status --porcelain`
3. Route:
   - Branch `develop` in the main checkout → **Step 2**.
   - The branch equals the `branch` field of a request (or matches
     `<type>/REQ-<id>-...` or `hotfix/...`) → **Step 6**.
   - Anything else: explain that this skill runs on `develop` or in a request
     worktree, list the worktrees, and stop.

## Step 2: Overview (on `develop`)

1. If a remote exists, run `git fetch --prune` and `git pull --ff-only`.
2. Read the frontmatter of every file in `reqs/` (not `reqs/done/`).
3. For each request with a `branch`, find its **effective status**. The request branch
   holds the newer copy of the file, so read it from there:
   `git show <branch>:reqs/<file>`, or from `origin/<branch>` when there is no local
   branch. `hotfix` requests are the exception: their status only lives on `develop`.
   A request that is `done` on its branch while the branch is not merged is shown as
   "merge pending".
4. For each request with a `branch`, also collect:
   - whether the local branch exists and whether the remote branch exists
   - the worktree path, from `git worktree list`
   - the unpushed commits: `git log origin/<branch>..<branch> --oneline`
   - whether the branch is already merged: `git branch --merged develop`
5. Show a table sorted by status, then priority, then id:

   | ID | Title | Type | Priority | Status | Branch / worktree | Notes |
   |----|-------|------|----------|--------|-------------------|-------|

   Put anomalies in the Notes column.

## Step 3: Repair anomalies

Compare what you collected with [references/anomalies.md](references/anomalies.md). If
there are anomalies, list them with the proposed repair for each, and ask the developer
which ones to apply. Apply the approved repairs before you claim anything. Each repair
is its own commit.

If the developer declines a repair, continue, but do not claim the request it affects.

## Step 4: Choose a request to claim

Candidates are the requests with effective status `ready`, sorted by `priority`
(`high` > `normal` > `low`), then by id.

- `$ARGUMENTS` names a request:
  - Status `ready`: use it.
  - Status `in-progress` or `review`: ask whether to resume it in its worktree (Step 6
    logic, using the worktree path).
  - Status `draft`: say that it needs approval through `/ss-workflow-new-req` first.
- No candidates: report this and mention the next useful action, such as `draft`
  requests to finish, requests in `review` waiting for `/ss-workflow-merge`, or
  `/ss-workflow-new-req`.
- One candidate: confirm it with the developer.
- Several candidates: ask with AskUserQuestion. Show the top three as options, with the
  recommended one first. The developer can name any other request through "Other".

Also mention the requests in `review`, because the developer may prefer to review and
merge those first.

## Step 5: Claim and create the worktree

Decide the names first:

| Item | Value |
|------|-------|
| Branch | `<type>/REQ-<id>-<slug>`, for example `feat/REQ-0012-gui-button`. For `type: hotfix`: `hotfix/v<version>`, with the version from the request's spec. |
| Base | `develop`. For `type: hotfix`: the main branch. |
| Worktree path | `<repo root>/.claude/worktrees/<branch with "/" replaced by "-">` |

Then:

1. **Claim (the lock).** On `develop`, set `status: in-progress` and `branch: <branch>`
   in the request file. Stage only that file and commit:

   ```
   chore(reqs): claim REQ-0012

   Refs: REQ-0012
   ```

2. **Push the claim** if a remote exists. If the push is rejected:
   - Run `git pull --ff-only`. If that is not possible, run `git pull --rebase`, which
     is allowed here because the claim commit is still unpublished.
   - Re-read the request. If someone else has claimed it in the meantime, drop your
     claim commit, tell the developer, and go back to Step 4.
   - Otherwise, push again.
3. **Create the branch and the worktree** only after the claim has landed:

   ```bash
   git worktree add -b <branch> <worktree path> <base>
   ```

4. **Publish the branch** if a remote exists:
   `git -C <worktree path> push -u origin <branch>`
5. If the repository has submodules, run
   `git -C <worktree path> submodule update --init --recursive`.
6. Tell the developer the worktree path and the branch. Mention that they can open a
   separate Claude session in that folder to work on several requests in parallel.

From here on, every file path and every command belongs to the worktree. Continue with
[references/implement.md](references/implement.md).

## Step 6: In a request worktree

1. Identify the request: the file in `reqs/` whose `branch` equals the current branch.
   For a `hotfix/*` branch, the request file is not on this branch. Read it from
   `develop` with `git show develop:reqs/<file>`, after a `git fetch`.
2. If a remote exists, run `git fetch`, then `git pull --ff-only` on this branch.
3. Act on the status:

| Status | Action |
|--------|--------|
| `in-progress` | Resume. Find where the work stopped (`git status`, `git log develop..HEAD --oneline`, the unchecked acceptance criteria, and `## Notes`). Summarize it for the developer. Continue with [references/implement.md](references/implement.md) from its Step 2. |
| `review` | Show the review summary from `## Notes` and the commits since `develop`. Then ask the question below. |
| `done`, and the branch is not merged into `develop` | `/ss-workflow-merge` closed the request on this branch, and the merge is pending, usually as an open merge request on the remote. Show its state (`gh pr view` / `glab mr view`). Ask whether the developer is still waiting, or whether the remote review asked for changes. For changes: move the file back with `git mv reqs/done/<file> reqs/<file>`, set `status: in-progress`, add the feedback to `## Notes`, commit `chore(reqs): reopen REQ-0012 after review`, push, and continue with [references/implement.md](references/implement.md) from its Step 2. |
| The branch is already merged into `develop` | Say that the request is finished and that this worktree is stale. `/ss-workflow-merge` cleans it up. |
| `draft` / `ready` on a branch | This is an anomaly. See [references/anomalies.md](references/anomalies.md). |

Question for a request in `review` (AskUserQuestion):

| Option | Action |
|--------|--------|
| Review passed, merge it | Tell the developer to run `/ss-workflow-merge` here, or run it if they ask you to. |
| Changes requested | Collect the feedback. Add it to `## Notes` with the date, set `status: in-progress`, commit `chore(reqs): reopen REQ-0012 after review`, and push. Then continue with [references/implement.md](references/implement.md) from its Step 2. If the feedback changes the spec, update `## Spec` too, and say so in the commit body. |
| Still reviewing | Change nothing. Repeat how to verify the work: the worktree path, `git diff develop...HEAD`, and the build and test commands. |
| Drop the request | Confirm once more. Then tell the developer that `/ss-workflow-merge` closes a request without merging it. Do not delete the branch here. |
