# Merging a hotfix branch

A `hotfix/v<version>` branch starts from the main branch. It merges into the main
branch, where the merge commit gets the tag `v<version>`, and into `develop`. The
hotfix is implemented in a worktree, and its request file lives only on `develop`.

## Prepare (both methods)

1. The tag name is the branch name without `hotfix/`, for example `v1.0.1`. The
   version is the tag name without the `v`.
2. The request: read it from `develop` (`git show develop:reqs/<file>`). Its status
   must be `review`. If it is `in-progress`, stop and point to
   `/ss-workflow-check-req`.
3. In the hotfix worktree: `git status --porcelain` is empty, and every commit is
   pushed.
4. `version-source` on the hotfix branch contains exactly this version. If it does
   not, set it and commit `chore(release): bump version to <version>`.
5. The tag does not exist yet (`git tag -l <tag>`, and with a remote
   `git ls-remote --tags origin <tag>`).
6. If the main branch has commits that the hotfix branch does not have, merge the main
   branch into the hotfix branch and resolve the conflicts there.
7. Run `build-command` and `test-command` in the worktree. Both must pass.
8. The main checkout has no uncommitted changes to tracked files. Note which branch it
   is on, normally `develop`. You return it to that branch at the end.

## Merge locally

Run these in the main checkout.

1. Main branch:

   ```bash
   git checkout <main branch>
   git pull --ff-only                      # with a remote
   git merge --no-ff hotfix/<tag> -m "Merge hotfix/<tag> into <main branch>" -m "Hotfix <tag>" -m "Refs: REQ-0012"
   git tag -a <tag> -m "Hotfix <tag>"
   ```

2. `develop`:

   ```bash
   git checkout develop
   git pull --ff-only                      # with a remote
   git merge --no-ff hotfix/<tag> -m "Merge hotfix/<tag> into develop" -m "Hotfix <tag>" -m "Refs: REQ-0012"
   ```

   Conflicts are likely here, because `develop` has moved on:
   - `version-source`: keep the higher of the two versions. This is normally the one
     on `develop`.
   - Code: keep the fix, and adapt it to the current code on `develop`. If the right
     resolution is not obvious, ask the developer.
   - After you resolve a conflict, run the build and the tests on `develop` before you
     commit the merge.
3. If a `release/*` branch is open, the release would ship without the fix. Ask the
   developer whether to merge the hotfix into that release branch as well
   (`git checkout release/<x>`, then `git merge --no-ff hotfix/<tag>`).
4. Close the request, on `develop`:
   - Set `status: done`.
   - Add a dated line to `## Notes`: `Released as <tag> (yyyy-MM-dd)`.
   - Run `git mv reqs/<file> reqs/done/<file>`.
   - Commit `chore(reqs): close REQ-0012`, with `Refs: REQ-0012`.
5. With a remote: pushing the main branch and the tag publishes the hotfix, so ask once
   more before you push. Then:

   ```bash
   git push --atomic origin <main branch> develop <tag>
   ```

   Also push the release branch if step 3 changed it.
6. Continue with "Finish".

## Merge request on the remote

1. Create the merge request from `hotfix/<tag>` into the main branch. Title:
   `Hotfix <tag>: <request title> (REQ-0012)`. Body: the goal and the review summary
   from the request, and `Refs: REQ-0012`.
2. Give the developer the URL. Tell them to use a merge commit, not a squash merge.
   Stop here. The developer runs `/ss-workflow-merge` again after it is merged.
3. When it is merged on the remote, in the main checkout:
   - `git checkout <main branch>`, then `git pull --ff-only`.
   - `git tag -a <tag> -m "Hotfix <tag>"`, then `git push origin <tag>`.
   - Continue with steps 2 to 4 of "Merge locally", then push `develop`. If the remote
     does not allow direct pushes to `develop`, open a merge request from
     `hotfix/<tag>` into `develop` instead, and close the request file inside a
     follow-up commit once that merge request is merged.

## Finish

1. Confirm all three:
   - `git merge-base --is-ancestor hotfix/<tag> <main branch>`
   - `git merge-base --is-ancestor hotfix/<tag> develop`
   - The tag exists, and points to a commit on the main branch.
2. Confirm on `develop` that the request file is in `reqs/done/` with `status: done`.
3. Run the shared clean-up (Step 5 of the skill): the worktree, the local branch, and
   the remote branch.
4. Return the main checkout to the branch it was on before (step 8 of "Prepare").
5. Offer to create a release on the platform from the tag, as in the release guide.
