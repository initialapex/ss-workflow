# Anomalies and repairs

Check every request against this table. Propose the repair, and apply it only after
the developer approves. "Status" means the effective status: the one in the request
file on the workspace request branch, or the one on `develop` when there is no
workspace request branch. "Request branch" without more means the workspace branch;
"project branch" means the branch that the request's `project-branch` names in a
project of the request (the name of the workspace branch when `project-branch` is
empty, for a request started before ss-workflow 0.8.0).

Other branches in a project are not anomalies. Other developers create branches
there from their own workspaces, and a project branch carries no request id, so a
branch that no request of this workspace names is someone else's work. Never report,
change, or delete it.

Normal states, for comparison:

| Status | Workspace request branch | Project branches | Worktrees |
|--------|--------------------------|------------------|-----------|
| Draft | Exists; the root checkout is on it during a discussion | None | None |
| `ready` | Exists | None | None |
| `in-progress` | Exists | One per project of the request (right after the start commit, possibly not yet); none for `projects: []` | The workspace worktree, with a project worktree at each `path` |
| `review` | Exists | Exist (none for `projects: []`) | None. During a review, the root checkout and its projects are on the branches. |
| `done`, not merged ("merge pending") | Exists | Exist, or already merged into their develop branches | None |
| `done`, merged | Deleted | Deleted | None |

## Two-layer problems

| Symptom | Likely cause | Repair |
|---------|--------------|--------|
| `in-progress`, the start commit exists, but a project of the request has no project branch | The session stopped between the start commit and Step 5.4 | Continue: create the project branch and its worktree as Step 5.4 of `SKILL.md` does. |
| `project-branch` names a branch that exists in a project, but the branch has commits that are not from this request (its history does not start at the start commit, or another person committed on it) | The name was taken by someone else between the check and the start, or a branch was created by hand | Do not commit on it. Show its commits (`git -C src/<name> log <project develop-ref>..<branch> --oneline`) and ask the developer whose they are. If they are not this request's, pick a new name as in Step 5.1 of `SKILL.md`, record it in `project-branch`, and create the project branch with that name. |
| A project worktree whose workspace worktree is gone (`git -C src/<name> worktree list` shows a path under a removed `.claude/worktrees/…`) | The workspace worktree was deleted by hand, or the removal stopped halfway | Check the project worktree for uncommitted changes and unpushed commits. Then `git -C src/<name> worktree prune` if its folder is gone, or `git -C src/<name> worktree remove <path>` if it still exists. |
| The workspace worktree cannot be removed: "working trees containing submodules cannot be moved or removed" | A project worktree is still inside it | Remove the project worktrees first, then restore the empty folders, as Step 4 of [implement.md](implement.md) describes. |
| The workspace worktree shows ` D <path>` | A project worktree was removed, but its empty folder was not put back | `git -C <worktree> restore <path>`. |
| `review`, and a project branch has commits after the gitlink on the workspace branch (`git -C src/<name> log <gitlink>..<branch> --oneline`) | Fixes were made in the project after the hand-over, or during a review that was interrupted before it recorded its result | Report it. During an open review this is normal; the next commit that records a result stages the gitlink. Otherwise, ask whether the commits belong to the review. |
| The root checkout's project is on a project branch while the root checkout itself is on `develop` | A review or a merge stopped halfway, or the branch was checked out by hand | Git cannot create a project worktree for that branch. If the project has no uncommitted changes, offer `git submodule update <path>` in the root checkout, which puts it back at the gitlink. |

## Branch and worktree problems

| Symptom | Likely cause | Repair |
|---------|--------------|--------|
| A worktree holds a request branch whose request file still says `ready` | The session stopped between creating the worktree and the start commit | Ask the developer to choose: (a) continue: make the start commit, create the project worktrees, and implement; or (b) give up the start: remove the worktree. The request stays `ready` on its branch. |
| The request file says `in-progress`, and the developer wants to put the request back to `ready` | The work should wait | Remove the worktrees (Step 4 of [implement.md](implement.md)), set `status: ready` on the request branch, and commit. Keep the project branches if they have commits; delete those without commits of their own and clear `project-branch`. |
| `in-progress`; the branches exist only on the remotes | The work was done on another machine, or the local clone was recreated | Ask first, because another machine may still be working on it. To take it over: recreate the worktrees as "Recreate the worktrees" in `SKILL.md` describes, from `origin/<branch>`. |
| `in-progress`; the local branches exist, but there is no worktree | The request was reopened by a review, or the worktree folders were deleted | Not a problem by itself: the request waits for a session to continue it. To continue: `git worktree prune` (and `git -C src/<name> worktree prune` for each project), then "Recreate the worktrees" in `SKILL.md`. |
| `review` or `done`, and a worktree still exists | The worktrees could not be removed after the implementation, usually because a folder was in use | Check that they have no uncommitted changes, and, when pushing is allowed, no unpushed commits. Then remove them in the order of Step 4 of [implement.md](implement.md). |
| `git worktree list` shows an entry as `prunable` | The worktree folder was removed by hand | Run `git worktree prune`. |
| The local branch has commits that are not on the remote, or the branch is not on the remote at all | A push was skipped or failed. With `push-policy: never`, or after the developer declined a push, this is the normal state and not an anomaly: show it as "waiting for the developer to push". | When pushing is allowed: run `git push` for that branch. If there is no upstream yet, `git push -u origin <branch>`. Otherwise, report it only. |
| A worktree has uncommitted changes | A session was interrupted in the middle of the work | Do not touch them. Report them. The developer resumes with this skill inside that worktree. |
| Two request branches contain the same `REQ-<id>` | Two machines took the same id before either pushed, or a branch was created by hand | Show both with their commits. Ask which one is the real one. Delete the other only with explicit approval if it has commits. |
| A branch named `<type>/REQ-xxxx-…` exists, but it has no request file of that id | The session stopped right after creating the branch, or the branch was created by hand | Report it. Ask whether to continue it as a draft with `/ss-workflow:new-req REQ-xxxx`, or to delete it. Never delete a branch that has unmerged commits without explicit approval. |
| The root checkout is on a request branch whose request file says `review` or `done`, and nobody is reviewing or merging | A review was paused or interrupted, or a merge stopped after it closed the request | Report it. `/ss-workflow:review` continues a review, and `/ss-workflow:merge` continues a merge. To free the root checkout, the developer switches it back to `develop` once it has no uncommitted changes. |
| The root checkout is on a request branch whose request file says `in-progress` or `ready` | A review sent the request back for rework, or a start was interrupted, and the root checkout was not switched back to `develop`. Or the branch was checked out by hand. | Git cannot create a worktree for a branch that the root checkout (or a project in it) is on, so apply this repair before any repair or step that creates the worktrees. Check that `git status --porcelain` shows no changes in the root checkout, and `git -C src/<name> status --porcelain` none in each project. If it does, report them, and do not switch. Otherwise, after the developer approves: `git checkout develop` and `git submodule update` in the root checkout, which puts every project back at its gitlink. The request is then an ordinary `in-progress` request without a worktree (or a `ready` one), and the rows above apply. |

## Draft problems

| Symptom | Likely cause | Repair |
|---------|--------------|--------|
| A draft branch that has not changed for a long time | The discussion was paused | Report it only. The developer decides whether to continue or to discard it. |
| The root checkout is on a draft branch with uncommitted changes to the request file, and no session discusses it | A discussion was interrupted before it paused or approved the draft | Report it. `/ss-workflow:new-req REQ-xxxx` continues it, with the changes as they are. |
| A `req/REQ-…` branch (from before ss-workflow 0.8.0) whose request is already on `develop` | The branch was merged, but not deleted | Delete the branch locally and on the remote. |
| A `req/REQ-…` branch whose request is not on `develop` | A draft from before 0.8.0 | Not a problem. `/ss-workflow:new-req REQ-xxxx` continues it and renames the branch. |
| A request file with `status: draft` on `develop` | A `req/` branch from before 0.8.0 was merged before the approval | Ask whether the spec is approved. If yes, start it from `develop` like any `ready` request from before 0.8.0, and set `ready` in its start commit first. If not, continue the discussion on a new request branch with the same id. |

## Status problems

| Symptom | Likely cause | Repair |
|---------|--------------|--------|
| The request branch is merged into `develop`, but the request is not `done`, or its file is not in `reqs/done/` | It was merged by hand, or on the remote before it was closed | Point to `/ss-workflow:merge`. It detects the finished merge and closes the request. |
| `done` on the request branch, and the branch is not merged | Not an anomaly: the merge is pending on the remote | Show it as "merge pending" with the merge request URL. No repair. |
| `status: done`, but the file is still in `reqs/` | The close step was interrupted | Point to `/ss-workflow:merge`, which finishes the close step. |
| A file in `reqs/done/` with a status other than `done` | The file was moved by hand | Ask which one is right, the location or the status. The fix is made on the request branch if it still exists, otherwise through `/ss-workflow:merge`. |
| `review`, and the branch has code commits after the commit that marked it for review | Fixes were made during a review. This is normal while a review is open. | Report it only. |

## File problems

Request files are changed on their request branch. A file in `reqs/` on `develop`
(from before ss-workflow 0.8.0) is changed on a new request branch with the same id.

| Symptom | Repair |
|---------|--------|
| The frontmatter is missing, is invalid YAML, or has an unknown `status` / `type` / `priority` value, or a `projects` entry that is not a project in "Workflow settings" | Show the problem. Fix it with the developer's answer. Commit `docs(reqs): fix REQ-xxxx frontmatter`. |
| Two files have the same id | Renumber the newer one (both the file name and `id`) to the next free id. If it has a request branch, keep the old branch name and record it in `branch`. |
| The file name does not match `REQ-<id>-<yyyyMMdd>-<slug>.md`, or its id differs from the frontmatter `id` | Run `git mv` to give it the correct name. The frontmatter `id` wins. |
| The `## Original` section is missing | Report it. Do not invent its content. Recover it from git history if possible (`git log -p -- <file>`). |
| The `## Q&A` section is missing | The request was written by an older ss-workflow version. Not a problem for a request that is `done`. For an open request, add the empty section between `## Original` and `## Notes` the next time its file is changed anyway. Do not make up entries for questions that were asked before. |
| A `ready` or later request has an entry with `A: (pending)` in `## Q&A` | Report it. A question came up after the approval, or the request was approved by hand. The session that works on the request asks the developer again before it builds on that point. |

## Stale worktrees

| Symptom | Repair |
|---------|--------|
| A worktree whose branch is merged | Remove it, the project worktrees first (Step 4 of [implement.md](implement.md)). `/ss-workflow:merge` deletes the branches. |
| A worktree on a branch that no request refers to | Report it. It may be the developer's own worktree, so leave it alone unless they ask. |
