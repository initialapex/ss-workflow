# Merging a request branch into `develop`

The request file travels with the branch. The request is closed (`status: done`, file
moved to `reqs/done/`) by the last commit on the request branch, right before the
merge. The merge then brings the code and the closed request to `develop` together.

## Prepare (both methods)

Work in the request's worktree.

1. **Status**: the request file on this branch must say `status: review`. If it says
   `in-progress`, stop and point to `/ss-workflow-check-req`. If it says `done`, the
   request was already closed by an earlier run: skip to step 5.
2. **Clean and pushed**: `git status --porcelain` must be empty. Push any unpushed
   commits.
3. **Up to date**: if `develop` has commits that the branch does not have
   (`git log HEAD..origin/develop --oneline`, or `HEAD..develop` without a remote),
   merge `develop` into the branch and resolve the conflicts here, on the branch.
4. **Verify**: if step 3 merged anything, or if the build and the tests were not run
   since the last commit, run `build-command` and `test-command`. Both must pass. If
   they fail, stop: the request goes back to `/ss-workflow-check-req`.
5. **Close the request on the branch**:
   - Set `status: done`.
   - Add a dated line to `## Notes`: `Merged into develop (yyyy-MM-dd)`.
   - Move the file: `git mv reqs/<file> reqs/done/<file>`.
   - Commit and push:

     ```
     chore(reqs): close REQ-0012

     Refs: REQ-0012
     ```

## Merge locally

Run these in the main checkout.

1. Check that the main checkout is on `develop` and has no uncommitted changes to
   tracked files. If it is on another branch, ask the developer before you switch it.
2. If a remote exists, run `git pull --ff-only`.
3. Merge:

   ```bash
   git merge --no-ff <branch> -m "Merge <branch> into develop" -m "<request title>" -m "Refs: REQ-0012"
   ```

   Because the branch already contains `develop`, this merge has no conflicts. If it
   does conflict, `develop` moved in the meantime: abort with `git merge --abort`, and
   repeat "Prepare" from step 3.
4. If a remote exists, push `develop`. If the push is rejected, run
   `git pull --no-rebase` (a merge commit must not be rebased), then push again.
5. Continue with "Finish".

## Merge request on the remote

1. Create the merge request from the branch into `develop`:
   - GitHub: `gh pr create --base develop --head <branch> --title "<title>" --body "<body>"`
   - GitLab: `glab mr create --source-branch <branch> --target-branch develop --title "<title>" --description "<body>"`

   Title: `<type>: <request title> (REQ-0012)`.
   Body: the goal and the acceptance criteria from `## Spec`, the review summary from
   `## Notes`, and `Refs: REQ-0012`.
2. Give the developer the URL. Tell them to choose a merge commit on the platform, not
   a squash merge, so that the request's commits stay in the history.
3. Stop here. Do not remove the worktree or the branch yet. The developer runs
   `/ss-workflow-merge REQ-0012` again after the merge request is merged, and the skill
   then continues with "Finish".

Until then, the branch shows `status: done` while it is not merged. This state means
"merge pending on the remote". If the remote review asks for changes, the developer
runs `/ss-workflow-check-req` in the worktree, which reopens the request.

## Finish

1. In the main checkout on `develop`: if a remote exists, run `git pull --ff-only`.
2. Confirm on `develop` that the request file is in `reqs/done/` with `status: done`.
   If it is not (the branch was merged before it was closed, or it was merged by
   hand), close it now on `develop` with the same changes as "Prepare" step 5. Commit
   `chore(reqs): close REQ-0012`, and push.
3. Run the shared clean-up (Step 5 of the skill): the worktree, the local branch, and
   the remote branch.
