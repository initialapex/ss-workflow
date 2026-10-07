# Anomalies and repairs

Check every request against this table. Propose the repair, and apply it only after
the developer approves. "Status" means the effective status: the one in the request
file on the request branch, or the one on `develop` when there is no request branch.

Normal states, for comparison:

| Status | Request branch | Worktree |
|--------|----------------|----------|
| Draft | A `req/REQ-…` branch only | None |
| `ready` | None | None |
| `in-progress` | Exists | Exists |
| `review` | Exists | None. During a review, the root checkout is on the branch. |
| `done`, not merged ("merge pending") | Exists | None |
| `done`, merged | Deleted | None |

## Branch and worktree problems

| Symptom | Likely cause | Repair |
|---------|--------------|--------|
| A request branch exists, but the request file on it still says `ready`, or the branch has no commits of its own | The session stopped between creating the branch and the claim commit | Ask the developer to choose: (a) continue: recreate the worktree if needed, make the claim commit, and implement; or (b) release the claim: delete the branch locally and on the remote. The request is `ready` again. |
| `in-progress`; the branch exists only on the remote | The work was done on another machine, or the local clone was recreated | Ask first, because another machine may still be working on it. To take it over: `git worktree add <worktree path> <branch>`, which tracks `origin/<branch>`. |
| `in-progress`; the local branch exists, but there is no worktree | The request was reopened by a review, or the worktree folder was deleted | Not a problem by itself: the request waits for a session to continue it. To continue: `git worktree prune`, then `git worktree add <worktree path> <branch>`. |
| `review` or `done`, and a worktree still exists | The worktree could not be removed after the implementation, usually because the folder was in use | Check that it has no uncommitted changes and no unpushed commits. Then `git worktree remove <worktree path>`. |
| `git worktree list` shows an entry as `prunable` | The worktree folder was removed by hand | Run `git worktree prune`. |
| The local branch has commits that are not on the remote | A push was skipped or failed | Run `git push` for that branch. If there is no upstream yet, `git push -u origin <branch>`. |
| A worktree has uncommitted changes | A session was interrupted in the middle of the work | Do not touch them. Report them. The developer resumes with this skill inside that worktree. |
| Two request branches contain the same `REQ-<id>` | Two claims raced, or a branch was created by hand | Show both with their commits. Ask which one is the real one. Delete the other only with explicit approval if it has commits. |
| A branch named `<type>/REQ-xxxx-…` exists, but no request on `develop` has that id | The request was never approved, or the branch was created by hand | Report it. Ask whether to link it to a request or to delete it. Never delete a branch that has unmerged commits without explicit approval. |
| The root checkout is on a request branch, and nobody is reviewing | A review was paused or interrupted | Report it. `/ss-workflow-review` continues it. If the request file on that branch does not say `review`, that skill reports an undefined state, and asks whether to restart the review or to merge. To free the root checkout, the developer switches it back to `develop` once it has no uncommitted changes. |

## Draft problems

| Symptom | Likely cause | Repair |
|---------|--------------|--------|
| A `req/REQ-…` branch whose request is already on `develop` | The branch was merged, but not deleted | Delete the branch locally and on the remote. |
| A `req/` branch without commits of its own, or without a request file | The session stopped right after creating the branch | Ask whether to continue the draft with `/ss-workflow-new-req REQ-xxxx`, or to delete the branch. |
| A `req/` branch that has not changed for a long time | The discussion was paused | Report it only. The developer decides whether to continue or to discard it. |
| A request file with `status: draft` on `develop` | The `req/` branch was merged before the approval | Ask whether the spec is approved. If yes, set `ready` through a new `req/` branch. If not, the discussion continues the same way. |

## Status problems

| Symptom | Likely cause | Repair |
|---------|--------------|--------|
| The request branch is merged into `develop`, but the request is not `done`, or its file is not in `reqs/done/` | It was merged by hand, or on the remote before it was closed | Point to `/ss-workflow-merge`. It detects the finished merge and closes the request. |
| `done` on the request branch, and the branch is not merged | Not an anomaly: the merge is pending on the remote | Show it as "merge pending" with the merge request URL. No repair. |
| `status: done`, but the file is still in `reqs/` | The close step was interrupted | Point to `/ss-workflow-merge`, which finishes the close step. |
| A file in `reqs/done/` with a status other than `done` | The file was moved by hand | Ask which one is right, the location or the status. The fix is made on the request branch if it still exists, otherwise through `/ss-workflow-merge`. |
| `review`, and the branch has code commits after the commit that marked it for review | Fixes were made during a review. This is normal while a review is open. | Report it only. |

## File problems

Request files on `develop` are changed through a `req/` branch
(`/ss-workflow-new-req REQ-xxxx`). Files of claimed requests are changed on their
request branch.

| Symptom | Repair |
|---------|--------|
| The frontmatter is missing, is invalid YAML, or has an unknown `status` / `type` / `priority` value | Show the problem. Fix it with the developer's answer. Commit `docs(reqs): fix REQ-xxxx frontmatter`. |
| Two files have the same id | Renumber the newer one (both the file name and `id`) to the next free id. If it has a request branch, keep the old branch name and record it in `branch`. |
| The file name does not match `REQ-<id>-<yyyyMMdd>-<slug>.md`, or its id differs from the frontmatter `id` | Run `git mv` to give it the correct name. The frontmatter `id` wins. |
| The `## Original` section is missing | Report it. Do not invent its content. Recover it from git history if possible (`git log -p -- <file>`). |

## Stale worktrees

| Symptom | Repair |
|---------|--------|
| A worktree whose branch is merged | Remove it: `git worktree remove <path>`. `/ss-workflow-merge` deletes the branch. |
| A worktree on a branch that no request refers to | Report it. It may be the developer's own worktree, so leave it alone unless they ask. |
