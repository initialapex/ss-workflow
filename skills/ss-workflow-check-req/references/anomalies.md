# Anomalies and repairs

Check every open request against this table. Propose the repair, and apply it only
after the developer approves. "Status" means the status on `develop` unless the row
says "effective".

## Claim and branch problems

| Symptom | Likely cause | Repair |
|---------|--------------|--------|
| `in-progress`, but the branch exists neither locally nor on the remote | The session stopped between the claim and the branch creation | Ask the developer to choose: (a) create the branch and the worktree now and continue (Step 5.3 of the skill), or (b) release the claim: set `status: ready`, clear `branch`, and commit `chore(reqs): release claim REQ-xxxx`. |
| `in-progress`; the branch exists only on the remote | The work was done on another machine, or the local clone was recreated | Recover it: `git worktree add <worktree path> <branch>`, which tracks `origin/<branch>`. Ask first, because another machine may still be working on it. |
| `in-progress`; the local branch exists, but there is no worktree | The worktree folder was deleted | Run `git worktree prune`, then `git worktree add <worktree path> <branch>`. |
| `git worktree list` shows an entry as `prunable` | The worktree folder was removed by hand | Run `git worktree prune`. |
| The local branch has commits that are not on the remote | A push was skipped or failed | Run `git -C <worktree> push`. If there is no upstream yet, run `git push -u origin <branch>`. |
| The worktree has uncommitted changes | A session was interrupted in the middle of the work | Do not touch them. Report them. The developer resumes with this skill inside that worktree. |
| `ready` or `draft` with a non-empty `branch` | A claim was edited by hand, or a released claim was left incomplete | If the branch exists and has commits, ask whether the request is in fact in progress, and set `in-progress` if so. Otherwise, clear `branch`. |
| A branch named `<type>/REQ-xxxx-...` exists, but no request refers to it | The request file was renumbered or removed, or the branch was created by hand | Report it. Ask whether to link it to a request or to delete the branch. Never delete a branch that has unmerged commits without explicit approval. |

## Status problems

| Symptom | Likely cause | Repair |
|---------|--------------|--------|
| The branch is already merged into `develop`, but the request is not `done` or not in `reqs/done/` | It was merged by hand or on the remote | Point to `/ss-workflow-merge`. It detects the finished merge and closes the request (status, `git mv`, and cleanup). |
| Effective status `done` on the request branch, and the branch is not merged | Not an anomaly: the merge is pending on the remote | Show it as "merge pending" with the merge request URL. No repair. |
| `status: done`, but the file is still in `reqs/` | The close step was interrupted | Run `git mv` to move the file to `reqs/done/`. Commit `chore(reqs): archive REQ-xxxx`. |
| A file in `reqs/done/` with a status other than `done` | The file was moved by hand | Ask which one is right, the location or the status. Then fix the other one. |
| Effective status `review`, with commits after the review commit | Work continued without reopening the request | Report it. Ask whether the request is still in review or was reopened. |
| Effective status `in-progress`, all acceptance criteria checked, and no commits for a long time | The hand-over for review was missed | Report it. The developer can resume in the worktree to finish the hand-over. |

## File problems

| Symptom | Repair |
|---------|--------|
| The frontmatter is missing, is invalid YAML, or has an unknown `status` / `type` / `priority` value | Show the problem. Fix it with the developer's answer. Commit `docs(reqs): fix REQ-xxxx frontmatter`. |
| Two files have the same id | Renumber the newer one (both the file name and `id`) to the next free id. If it has a branch, rename the branch only with the developer's approval. Otherwise, keep the old branch name and record it in `branch`. |
| The file name does not match `REQ-<id>-<yyyyMMdd>-<slug>.md`, or its id differs from the frontmatter `id` | Run `git mv` to give it the correct name. The frontmatter `id` wins. |
| The `## Original` section is missing | Report it. Do not invent its content. Recover it from git history if possible (`git log -p -- <file>`). |

## Stale worktrees

| Symptom | Repair |
|---------|--------|
| A worktree whose branch is merged, and whose request is `done` | Remove it: `git worktree remove <path>`, then delete the local branch with `git branch -d`. Delete the remote branch only with approval. |
| A worktree on a branch that no request refers to | Report it. It may be the developer's own worktree, so leave it alone unless they ask. |
