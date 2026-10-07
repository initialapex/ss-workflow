# Merging a release branch

A `release/v<version>` branch merges into the main branch and into `develop`, and the
merge commit on the main branch gets the tag `v<version>`. Release branches have no
worktree: all of this runs in the root checkout.

`/ss-workflow-release` prepares the branch (the version number, the open-request
check). This guide only merges it.

## Prepare (both methods)

1. The tag name is the branch name without `release/`, for example `v1.0.0-beta1`.
   The version is the tag name without the `v`.
2. The root checkout is on the release branch, and `git status --porcelain` is empty.
3. `version-source` contains exactly this version. If it does not, stop and point to
   `/ss-workflow-release`.
4. The tag does not exist yet: check `git tag -l <tag>`, and with a remote
   `git ls-remote --tags origin <tag>`. If it exists, stop and report it.
5. Run `build-command` and `test-command`. Both must pass.
6. Show the developer what will be released: the version, the number of commits
   (`git log <main branch>..HEAD --oneline`), and the requests closed since the last
   tag (files added to `reqs/done/`). Ask for a go-ahead.

## Merge locally

1. Main branch:

   ```bash
   git checkout <main branch>
   git pull --ff-only                      # with a remote
   git merge --no-ff release/<tag> -m "Merge release/<tag> into <main branch>" -m "Release <tag>"
   ```

2. Check that the main branch now equals the release:
   `git diff <main branch> release/<tag> --stat` must be empty. If it is not, the main
   branch has changes that never reached `develop`, usually a hotfix that was not
   merged back. Stop, report the difference, and ask the developer.
3. Tag the merge commit: `git tag -a <tag> -m "Release <tag>"`.
4. `develop`:

   ```bash
   git checkout develop
   git pull --ff-only                      # with a remote
   git merge --no-ff release/<tag> -m "Merge release/<tag> into develop" -m "Release <tag>"
   ```

   If this merge has conflicts, resolve them. For `version-source`, keep the higher
   version. Then run the build and the tests again.
5. With a remote: pushing the main branch and the tag publishes the release, so ask
   once more before you push. Then push everything in one step:

   ```bash
   git push --atomic origin <main branch> develop <tag>
   ```

6. Continue with "Finish".

## Merge request on the remote

1. Push the release branch: `git push -u origin release/<tag>`.
2. Create the merge request from `release/<tag>` into the main branch, with the title
   `Release <tag>` and a body that lists the requests closed since the last tag.
3. Give the developer the URL. Tell them to use a merge commit, not a squash merge.
   Stop here. The developer runs `/ss-workflow-merge` again after it is merged.
4. When it is merged on the remote:
   - `git checkout <main branch>`, then `git pull --ff-only`.
   - Tag the merge commit on the main branch and push the tag:
     `git tag -a <tag> -m "Release <tag>"`, then `git push origin <tag>`.
   - Merge the release branch into `develop`: locally as in step 4 of "Merge locally",
     then push `develop`. If the remote does not allow direct pushes to `develop`,
     open a second merge request from `release/<tag>` into `develop` and wait for it.

## Finish

1. Confirm all three:
   - `git merge-base --is-ancestor release/<tag> <main branch>`
   - `git merge-base --is-ancestor release/<tag> develop`
   - The tag exists, and points to a commit on the main branch.
2. Run the shared clean-up (Step 5 of the skill). There is no worktree. Delete the
   local and the remote release branch.
3. Leave the root checkout on `develop`.
4. Offer to create a release on the platform from the tag, and do it only if the
   developer agrees:
   - GitHub: `gh release create <tag> --generate-notes`, with `--prerelease` when the
     version has a prerelease part
   - GitLab: `glab release create <tag>`

## Pre-1.0 sync without a release branch

Before v1.0.0, the root `AGENTS.md` allows merging `develop` straight into the main
branch. Offer this only when the version in `version-source` is below `1.0.0` and the
developer asks for it.

1. The root checkout is on `develop`, is clean, and the build and the tests pass.
2. Ask whether to tag this state. The tag is `v` plus the version in `version-source`.
   If that tag already exists, the version must be raised first: point to
   `/ss-workflow-release`.
3. Merge and return:

   ```bash
   git checkout <main branch>
   git pull --ff-only                      # with a remote
   git merge --no-ff develop -m "Merge develop into <main branch>"
   git tag -a <tag> -m "Release <tag>"     # only if the developer wants the tag
   git checkout develop
   ```

4. With a remote, ask, then push: `git push --atomic origin <main branch> <tag>`.
