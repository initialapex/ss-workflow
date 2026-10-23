# Merging a request

All of this runs in the root checkout of the workspace. The request's worktrees were
removed when its implementation was finished, and only the branches are left: the
workspace request branch (`<branch>`), and the project branch (`<project branch>`,
the request's `project-branch`) in each project of the request.

The order is fixed: **each project first, the workspace last.**

1. Each project branch is merged into the project's `develop-branch`, in the project
   repository.
2. The request is closed (`status: done`, file moved to `reqs/done/`) by the last
   commit on the workspace request branch. That commit also sets the gitlink of each
   project to the merge commit of step 1.
3. The workspace request branch is merged into `develop`, which brings the closed
   request and the new gitlinks to `develop` together.

A run that stops after step 1 (a merge request that waits, a protected develop
branch) is continued by the next run: Step 2 of the skill finds which project
branches are merged already.

A request with `projects: []` changes workspace files only. It has no project
branches: skip every project step below, and go from "Prepare" to "Merge the
workspace".

## Prepare (both methods)

1. **Workspace branch**: `git checkout <branch>` in the root checkout. If the branch
   exists only on the remote, this creates it from `origin/<branch>`. With a remote,
   run `git pull --ff-only`. Then `git submodule update`.

   If a leftover worktree still holds a branch of the request, git refuses the
   checkout. Remove the worktrees first (Step 5.2 of the skill).
2. **Status**: the request file on this branch must say `status: review`. If it says
   `in-progress`, switch back to `develop` (`git submodule update`), stop, and point
   to `/ss-workflow:check-req`. If it says `done`, the request was already closed by
   an earlier run: skip to "Merge the workspace" or "Finish".
3. **Project branches**: for each project of the request that is not merged yet,
   `git -C <path> checkout <project branch>`, and with a remote `git -C <path> pull
   --ff-only`.
4. **Up to date**, in each project that is not merged yet: if its `develop-branch` has
   commits that the project branch does not have (`git -C <path> log
   HEAD..origin/<develop-branch> --oneline`, or the local branch without a remote),
   merge it into the project branch, and resolve the conflicts there. Do the same for
   the workspace branch with `develop`. A gitlink conflict in the workspace is
   resolved with the project branch's tip (`git update-index --cacheinfo
   160000,<sha>,<path>`). A conflict in a workspace file (two requests changed the
   same spec in `docs/`, or the same section of an agent file) is resolved like a
   conflict in code: show both sides, and ask the developer unless it is trivial.
5. **Verify again, if the code changed**: if step 4 merged anything into a project
   branch, run that project's `build-command` and `test-command`, plus
   `verify-command` if it is set, in its folder, and also those of a project of the
   request that depends on it. They must pass. If they fail, stop: tell the developer,
   and point to `/ss-workflow:review`. The root checkout stays on the request branches
   for that. Record the run in `## Notes` as `### Verify before merge (yyyy-MM-dd)`,
   one block per project, one line per command, with `passed`, `failed (<reason>)`, or
   `not configured`. If step 4 merged nothing into the projects, do not run them, and
   do not record a result that you did not produce.
6. Push the updated project branches, then the workspace branch.

## Merge the projects

For each project of the request whose branch is not merged into its develop branch
yet, by that project's merge method (Step 3 of the skill):

### Locally

1. In the project:

   ```bash
   git -C <path> checkout <develop-branch>
   git -C <path> pull --ff-only                      # with a remote
   git -C <path> merge --no-ff <project branch> -m "Merge <project branch> into <develop-branch>" -m "<one line that describes the change>"
   ```

   Because the branch already contains the develop branch, this merge has no
   conflicts. If it does conflict, the develop branch moved in the meantime: abort with
   `git -C <path> merge --abort`, and repeat "Prepare" from step 4 for this project.
2. Push the develop branch of the project. If the push is rejected because the remote
   has new commits, run `git -C <path> pull --no-rebase` (a merge commit must not be
   rebased), then push again.

   If the remote refuses direct pushes to the develop branch (a protected branch), do
   not work around it. Undo the local merge (`git -C <path> reset --hard HEAD^` while
   `HEAD` is that merge commit, which only removes the unpublished merge commit), and
   put the project back on the request branch. Then:
   - With a remote platform: continue with "With a merge request" for this project.
   - Without one: stop. Tell the developer that `<project branch>` of `<name>` has to be
     merged into `<develop-branch>` on the remote by someone who is allowed to, with a
     merge commit. The request is "merge pending" until then, and running this skill
     again finds the finished merge and continues.

   If the develop branch is not pushed (no remote, `push-policy: never`, or the
   developer declined), the merge is complete in this repository. Continue.

### With a merge request

1. Create the merge request from the branch into the develop branch, in the project
   folder:
   - GitHub: `gh pr create --base <develop-branch> --head <project branch> --title "<title>" --body "<body>"`
   - GitLab: `glab mr create --source-branch <project branch> --target-branch <develop-branch> --title "<title>" --description "<body>"`

   Title: `<type>: <what the change does>`, in English, like a commit subject of the
   project.
   Body, written for the project's reviewers: the goal and the acceptance criteria
   from `## Spec`, the Verify and Review results of this project from `## Notes` as
   they are recorded (also what failed, what did not run, and what the developer
   accepted anyway), and the `### Behavior changes` items of this project if there
   are any. The merge request belongs to the project's history, so it carries no
   request id, no workspace name, no `Refs:` line, and no link to a workspace file
   (see "Workspace and projects" in the root `AGENTS.md`).
2. Give the developer the URL. Tell them to choose a merge commit on the platform, not
   a squash merge, so that the request's commits stay in the history.
3. Continue with the other projects. When every project is merged or has an open merge
   request, and at least one is open, switch the root checkout back to `develop`
   (`git submodule update`), and stop. Do not close the request yet. The developer runs
   `/ss-workflow:merge REQ-0012` again after the merge requests are merged.

## Merge the workspace

Only when every project branch of the request is merged into its develop branch
(`git -C <path> merge-base --is-ancestor <project branch> <develop-ref of the project>`).

1. **Close the request on the workspace branch**:
   - Set `status: done`.
   - Add a dated line to `## Notes`: `Merged into develop (yyyy-MM-dd)`, with the
     project merge commits (`<name> <short sha>`).
   - Move the file: `git mv reqs/<file> reqs/done/<file>`.
   - Set the gitlink of each project of the request to the commit of its develop
     branch that contains the merge: `git -C <path> checkout --detach <develop-ref of
     the project>`, then `git add <path>`.
   - Commit and push:

     ```
     chore(reqs): close REQ-0012

     Refs: REQ-0012
     ```

   If the workspace branch is already `done` (an earlier run closed it before a merge
   request), check that its gitlinks point to the develop branches' merge commits. If
   not, add a commit `chore(reqs): point REQ-0012 to the merged projects` that sets
   them.
2. By the workspace's merge method:
   - **Locally**:

     ```bash
     git checkout develop
     git pull --ff-only                      # with a remote
     git merge --no-ff <branch> -m "Merge <branch> into develop" -m "<request title>" -m "Refs: REQ-0012"
     git submodule update
     ```

     A gitlink conflict means that `develop` recorded a newer project commit in the
     meantime (another request, or a gitlink update). Resolve it with the newer of
     the two commits, which is the one that contains the other (`git -C <path>
     merge-base --is-ancestor`). If neither contains the other, stop and ask.

     Push `develop`. If the push is rejected because the remote has new commits, run
     `git pull --no-rebase`, then push again. If the remote refuses direct pushes to
     `develop`, undo the local merge (`git reset --hard HEAD^` while `HEAD` is that
     merge commit), and continue with the merge request below, or, without a remote
     platform, stop and tell the developer which branch has to be merged on the
     remote. If `develop` is not pushed, the merge is complete in this repository.
   - **With a merge request**: create it from the branch into `develop`, as for a
     project above, with the title `<type>: <request title> (REQ-0012)`, the same body
     with `Refs: REQ-0012`, the project merge commits, and the workspace files that
     the request changes. Give the developer the URL,
     switch back to `develop`, and stop. The developer runs this skill again after the
     merge.
3. Continue with "Finish".

Until the workspace branch is merged, it shows `status: done` while it is not merged:
"merge pending on the remote". If a remote review asks for changes, the developer
runs `/ss-workflow:review REQ-0012` again. That skill reopens the request on the
branch and continues the review.

## Finish

1. In the root checkout on `develop`: if a remote exists, run `git pull --ff-only`,
   then `git submodule update`.
2. Confirm on `develop` that the request file is in `reqs/done/` with `status: done`.
   If it is not (the workspace branch was merged before it was closed, or it was
   merged by hand), close it through a short-lived branch, as in "Closing a dropped
   request" in the skill, with the note `Merged into develop (yyyy-MM-dd)` and the
   commit `chore(reqs): close REQ-0012`.
3. Confirm that the gitlinks on `develop` contain the merges: for each project of the
   request, `git -C <path> merge-base --is-ancestor <project branch> $(git rev-parse
   develop:<path>)`. If not, offer the gitlink update of "Workspace and projects" in
   the root `AGENTS.md`.
4. Run the shared clean-up (Step 5 of the skill): the local and the remote branches,
   in the workspace and in each project. Confirm each merge on the ref that holds it:
   `origin/<develop branch>` when it was pushed or merged on the remote, the local
   branch otherwise.
