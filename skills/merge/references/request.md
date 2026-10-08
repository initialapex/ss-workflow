# Merging a request branch into `develop`

All of this runs in the root checkout. The request's worktree was removed when its
implementation was finished, and only the branch is left.

The request file travels with the branch. The request is closed (`status: done`, file
moved to `reqs/done/`) by the last commit on the request branch, right before the
merge. The merge then brings the code and the closed request to `develop` together.

## Prepare (both methods)

1. Check out the request branch in the root checkout: `git checkout <branch>`. If the
   branch exists only on the remote, this creates it from `origin/<branch>`. With a
   remote, run `git pull --ff-only`.

   If a leftover worktree still holds the branch, git refuses the checkout. Remove
   that worktree first (Step 5.2 of the skill).
2. **Status**: the request file on this branch must say `status: review`. If it says
   `in-progress`, switch back to `develop`, stop, and point to
   `/ss-workflow:check-req`. If it says `done`, the request was already closed by an
   earlier run: skip to "Merge locally" or "Finish".
3. **Up to date**: if `develop` has commits that the branch does not have
   (`git log HEAD..origin/develop --oneline`, or `HEAD..develop` without a remote),
   merge `develop` into the branch, and resolve the conflicts here, on the branch.
4. **Verify again, if the code changed**: if step 3 merged anything, run
   `build-command` and `test-command`, plus `verify-command` if it is set. They must
   pass. If they fail, stop: tell the developer, and point to `/ss-workflow:review`.
   The root checkout stays on the request branch for that. Record the run in
   `## Notes` as `### Verify before merge (yyyy-MM-dd)`, one line per command, with
   `passed`, `failed (<reason>)`, or `not configured`. If step 3 merged nothing, do
   not run them, and do not record a result that you did not produce.
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

1. `git checkout develop`. With a remote, run `git pull --ff-only`.
2. Merge:

   ```bash
   git merge --no-ff <branch> -m "Merge <branch> into develop" -m "<request title>" -m "Refs: REQ-0012"
   ```

   Because the branch already contains `develop`, this merge has no conflicts. If it
   does conflict, `develop` moved in the meantime: abort with `git merge --abort`, and
   repeat "Prepare" from step 3.
3. Push `develop`. If the push is rejected because the remote has new commits, run
   `git pull --no-rebase` (a merge commit must not be rebased), then push again.

   If the remote refuses direct pushes to `develop` (a protected branch), do not work
   around it. Undo the local merge (`git reset --hard HEAD^` while `HEAD` is that
   merge commit, which only removes the unpublished merge commit). Then:
   - With a remote platform: continue with "Merge request on the remote".
   - Without one: switch back to `develop`, and stop. Tell the developer that
     `<branch>` has to be merged into `develop` on the remote by someone who is
     allowed to, with a merge commit. The request is "merge pending" until then, and
     running this skill again finds the finished merge and continues with "Finish".

   If `develop` is not pushed (no remote, `push-policy: never`, or the developer
   declined), the merge is complete in this repository. Continue.
4. Continue with "Finish".

## Merge request on the remote

1. Create the merge request from the branch into `develop`:
   - GitHub: `gh pr create --base develop --head <branch> --title "<title>" --body "<body>"`
   - GitLab: `glab mr create --source-branch <branch> --target-branch develop --title "<title>" --description "<body>"`

   Title: `<type>: <request title> (REQ-0012)`.
   Body: the goal and the acceptance criteria from `## Spec`, the Verify and Review
   results from `## Notes` as they are recorded (also what failed, what did not run,
   and what the developer accepted anyway), the `### Behavior changes` entry if there
   is one, and `Refs: REQ-0012`.
2. Give the developer the URL. Tell them to choose a merge commit on the platform, not
   a squash merge, so that the request's commits stay in the history.
3. Switch the root checkout back to `develop`, and stop. Do not delete the branch yet.
   The developer runs `/ss-workflow:merge REQ-0012` again after the merge request is
   merged, and the skill then continues with "Finish".

Until then, the branch shows `status: done` while it is not merged. This state means
"merge pending on the remote". It is the same state when the branch waits for a merge
that someone else has to do on a remote without a platform. If the remote review asks for changes, the developer
runs `/ss-workflow:review REQ-0012` again. That skill reopens the request on the
branch and continues the review.

## Finish

1. In the root checkout on `develop`: if a remote exists, run `git pull --ff-only`.
2. Confirm on `develop` that the request file is in `reqs/done/` with `status: done`.
   If it is not (the branch was merged before it was closed, or it was merged by
   hand), close it through a short-lived branch, as in "Closing a dropped request" in
   the skill, with the note `Merged into develop (yyyy-MM-dd)` and the commit
   `chore(reqs): close REQ-0012`.
3. Run the shared clean-up (Step 5 of the skill): the local branch and the remote
   branch. Confirm the merge on the ref that holds it: `origin/develop` when `develop`
   was pushed or merged on the remote, the local `develop` otherwise.
