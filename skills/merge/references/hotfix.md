# Merging a hotfix branch

A `hotfix/v<version>` branch starts from the main branch. It merges into the main
branch, where the merge commit gets the tag `v<version>`, and into `develop`.

All of this runs in the root checkout. The hotfix worktree was removed when the
implementation was finished. The request file was copied onto the hotfix branch by the
claim commit, so the branch carries its own copy, and `develop` still holds the
original copy with `status: ready`.

## Prepare (both methods)

1. The tag name is the branch name without `hotfix/`, for example `v1.0.1`. The
   version is the tag name without the `v`.
2. Check out the hotfix branch in the root checkout: `git checkout hotfix/<tag>`. With
   a remote, run `git pull --ff-only`.
3. **Status**: the request file on this branch must say `status: review`. If it says
   `in-progress`, switch back to `develop`, stop, and point to
   `/ss-workflow:check-req`. If it says `done`, the request was already closed by an
   earlier run: skip to "Merge locally" or "Finish".
4. `version-source` on the hotfix branch contains exactly this version. If it does
   not, set it and commit `chore(release): bump version to <version>`. Skip this step
   if `version-source` is `none`.
5. The tag does not exist yet (`git tag -l <tag>`, and with a remote
   `git ls-remote --tags origin <tag>`).
6. If the main branch has commits that the hotfix branch does not have, merge the main
   branch into the hotfix branch and resolve the conflicts here.
7. If step 4 or step 6 changed anything, run `build-command` and `test-command`, plus
   `verify-command` if it is set. They must pass. If they fail, stop, and point to
   `/ss-workflow:review`.
8. **Close the request on the branch**:
   - Set `status: done`.
   - Add a dated line to `## Notes`: `Released as <tag> (yyyy-MM-dd)`.
   - `git mv reqs/<file> reqs/done/<file>`
   - Commit `chore(reqs): close REQ-0012`, with `Refs: REQ-0012`, and push.

## Merge locally

1. Main branch:

   ```bash
   git checkout <main branch>
   git pull --ff-only                      # with a remote
   git merge --no-ff hotfix/<tag> -m "Merge hotfix/<tag> into <main branch>" -m "Hotfix <tag>" -m "Refs: REQ-0012"
   git tag -a <tag> -m "Hotfix <tag>"
   ```

2. `develop`. Do not let git commit this merge by itself, because the old copy of the
   request file has to go in the same commit:

   ```bash
   git checkout develop
   git pull --ff-only                      # with a remote
   git merge --no-ff --no-commit hotfix/<tag>
   git rm reqs/<file>                      # the old copy that still says "ready"
   git commit -m "Merge hotfix/<tag> into develop" -m "Hotfix <tag>" -m "Refs: REQ-0012"
   ```

   After this commit, `develop` has the request only in `reqs/done/`, with
   `status: done`.

   If `develop` did not change the version since the last release, the version does
   not conflict, and `develop` takes the hotfix version. Other conflicts are possible,
   because `develop` has moved on:
   - `version-source`: keep the higher of the two versions. An open release branch
     normally has the higher one.
   - Code: keep the fix, and adapt it to the current code on `develop`. If the right
     resolution is not obvious, ask the developer.
   - After you resolve a conflict, run the build and the tests on `develop` before you
     commit the merge.
3. If a `release/*` branch is open, the release would ship without the fix. Ask the
   developer whether to merge the hotfix into that release branch as well
   (`git checkout release/<x>`, then the same merge as in step 2).
4. With a remote: pushing the main branch and the tag publishes the hotfix, so ask once
   more before you push. Then:

   ```bash
   git push --atomic origin <main branch> develop <tag>
   ```

   Also push the release branch if step 3 changed it.
5. Continue with "Finish".

## Merge request on the remote

1. Create the merge request from `hotfix/<tag>` into the main branch. Title:
   `Hotfix <tag>: <request title> (REQ-0012)`. Body: the goal, and the Verify and
   Review results from the request, and `Refs: REQ-0012`.
2. Give the developer the URL. Tell them to use a merge commit, not a squash merge.
   Switch the root checkout back to `develop`, and stop. The developer runs
   `/ss-workflow:merge` again after it is merged.
3. When it is merged on the remote:
   - `git checkout <main branch>`, then `git pull --ff-only`.
   - `git tag -a <tag> -m "Hotfix <tag>"`, then `git push origin <tag>`.
   - Continue with steps 2 and 3 of "Merge locally", then push `develop`. If the
     remote does not allow direct pushes to `develop`, do the merge of step 2 on a
     short-lived branch created from `develop`, and open a merge request from that
     branch into `develop`.

## Finish

1. Confirm all three:
   - `git merge-base --is-ancestor hotfix/<tag> <main branch>`
   - `git merge-base --is-ancestor hotfix/<tag> develop`
   - The tag exists, and points to a commit on the main branch.
2. Confirm on `develop` that the request file is in `reqs/done/` with `status: done`,
   and that no copy of it is left in `reqs/`.
3. Run the shared clean-up (Step 5 of the skill): the local branch and the remote
   branch.
4. Offer to create a release on the platform from the tag, as in the release guide.
