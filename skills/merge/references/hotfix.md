# Merging a hotfix

A hotfix belongs to one project, named in the request's `projects`.

| Repository | Branch | Starts from | Merges into | Tag |
|------------|--------|-------------|-------------|-----|
| The project | `hotfix/v<version>` | its `main-branch` | its `main-branch` and `develop-branch` | `v<version>`, on the merge commit of its main branch |
| The workspace | `hotfix/<name>-v<version>` | the workspace main branch | the workspace main branch and `develop` | `<name>/v<version>`, on the merge commit of the main branch |

All of this runs in the root checkout. The hotfix worktrees were removed when the
implementation was finished. The request file was copied onto the workspace hotfix
branch by the start commit, so that branch carries its only copy. A hotfix started
before ss-workflow 0.8.0 also left an old copy in `reqs/` on `develop`, with
`status: ready`.

The project goes first, the workspace last, as for a request.

## Prepare (both methods)

1. The project tag is `v<version>`, the workspace tag `<name>/v<version>`, from the
   branch names.
2. Check out the workspace hotfix branch in the root checkout:
   `git checkout hotfix/<name>-v<version>`, with a remote `git pull --ff-only`, then
   `git submodule update`. Check out the project hotfix branch:
   `git -C <path> checkout hotfix/v<version>`, with a remote `git -C <path> pull
   --ff-only`.
3. **Status**: the request file on the workspace branch must say `status: review`. If
   it says `in-progress`, switch back to `develop`, stop, and point to
   `/ss-workflow:check-req`. If it says `done`, the request was already closed by an
   earlier run: skip to the first merge that Step 2 of the skill did not find done.
4. The project's `version-source` on the project hotfix branch contains exactly this
   version. If it does not, set it and commit `chore(release): bump version to
   <version>` in the project. Skip this step if `version-source` is `none`.
5. Neither tag exists yet (`git -C <path> tag -l v<version>` and `git tag -l
   <name>/v<version>`, and with a remote `git ls-remote --tags origin <tag>` in each
   repository).
6. If the project's main branch has commits that the project hotfix branch does not
   have, merge it into the hotfix branch and resolve the conflicts there.
7. If step 4 or step 6 changed anything, run the project's `build-command` and
   `test-command`, plus `verify-command` if it is set. They must pass. If they fail,
   stop, and point to `/ss-workflow:review`.

## Merge the project

By the project's merge method (Step 3 of the skill).

### Locally

1. The project's main branch, with the tag:

   ```bash
   git -C <path> checkout <main-branch>
   git -C <path> pull --ff-only                      # with a remote
   git -C <path> merge --no-ff hotfix/v<version> -m "Merge hotfix/v<version> into <main-branch>" -m "Hotfix v<version>"
   git -C <path> tag -a v<version> -m "Hotfix v<version>"
   ```

2. The project's develop branch:

   ```bash
   git -C <path> checkout <develop-branch>
   git -C <path> pull --ff-only                      # with a remote
   git -C <path> merge --no-ff hotfix/v<version> -m "Merge hotfix/v<version> into <develop-branch>" -m "Hotfix v<version>"
   ```

   If the develop branch did not change the version since the last release, the
   version does not conflict, and it takes the hotfix version. Other conflicts are
   possible, because the develop branch has moved on:
   - `version-source`: keep the higher of the two versions. An open release branch
     normally has the higher one.
   - Code: keep the fix, and adapt it to the current code. If the right resolution is
     not obvious, ask the developer.
   - After you resolve a conflict, run the build and the tests before you commit the
     merge.
3. If the project has an open `release/*` branch, the release would ship without the
   fix. Ask the developer whether to merge the hotfix into that release branch as
   well, with the same merge as in step 2.
4. With a remote: pushing the main branch and the tag publishes the hotfix, so ask once
   more before you push, whatever `push-policy` says. Then:

   ```bash
   git -C <path> push --atomic origin <main-branch> <develop-branch> v<version>
   ```

   Also push the release branch if step 3 changed it. With `push-policy: never`, or
   if the developer says no, do not push: show the command, and say that the hotfix
   is merged and tagged in this repository only until the developer runs it.

   If the remote refuses the push because a branch is protected, do not work around
   it. Delete the local tag, undo the unpublished merge commits (`git -C <path> reset
   --hard HEAD^` on each branch, while `HEAD` is that merge commit), and continue with
   a merge request below, or stop without a remote platform and say what has to be
   merged on the remote.

### With a merge request

1. Create the merge request from `hotfix/v<version>` into the project's main branch,
   in the project folder. Title: `Hotfix v<version>: <what the fix does>`, in
   English. Body: the goal, and the Verify and Review results of the request as they
   are recorded (also what failed or did not run), with no request id, no workspace
   name, and no `Refs:` line (see "Workspace and projects" in the root `AGENTS.md`).
   It needs the branch on the remote: if you may not
   push it, stop, and say which branch the developer has to push.
2. Give the developer the URL. Tell them to use a merge commit, not a squash merge.
   Switch the root checkout back to `develop` (`git submodule update`), and stop. The
   developer runs `/ss-workflow:merge` again after it is merged.
3. When it is merged on the remote: tag the merge commit on the project's main branch
   (`git -C <path> tag -a v<version> -m "Hotfix v<version>"`, then push the tag; ask
   first, and with `push-policy: never` show the command), and merge the hotfix into
   the project's develop branch as in step 2 of "Locally". If the remote does not
   allow direct pushes to the develop branch, do that merge on a short-lived branch
   created from it, and open a merge request from that branch.

## Merge the workspace

Only when the project's hotfix is merged into its main branch and its develop branch,
and the project tag exists.

1. **Close the request on the workspace hotfix branch**:
   - Set `status: done`.
   - Add a dated line to `## Notes`: `Released as <name> v<version> (yyyy-MM-dd)`.
   - `git mv reqs/<file> reqs/done/<file>`
   - Set the project's gitlink to the tagged commit:
     `git -C <path> checkout --detach v<version>`, then `git add <path>`.
   - Commit `chore(reqs): close REQ-0012`, with `Refs: REQ-0012`, and push.
2. The workspace main branch, with the workspace tag:

   ```bash
   git checkout <main branch>
   git pull --ff-only                      # with a remote
   git merge --no-ff hotfix/<name>-v<version> -m "Merge hotfix/<name>-v<version> into <main branch>" -m "Hotfix <name> v<version>" -m "Refs: REQ-0012"
   git tag -a <name>/v<version> -m "Hotfix <name> v<version>"
   ```

   The project's gitlink on the main branch is now the hotfix release; the other
   projects keep their releases. Check it: `git rev-parse <main branch>:<path>` equals
   `git -C <path> rev-parse v<version>^{commit}`.
3. `develop`. Do not let git commit this merge by itself: the gitlink has to point to
   the project's develop branch, and an old copy of the request file (from before
   0.8.0) has to go, in the same commit:

   ```bash
   git checkout develop
   git pull --ff-only                      # with a remote
   git merge --no-ff --no-commit hotfix/<name>-v<version>
   git rm reqs/<file>                      # only if develop has an old copy that says "ready"
   git update-index --cacheinfo 160000,<sha of the project's develop branch>,<path>
   git commit -m "Merge hotfix/<name>-v<version> into develop" -m "Hotfix <name> v<version>" -m "Refs: REQ-0012"
   git submodule update
   ```

   After this commit, `develop` has the request only in `reqs/done/`, with
   `status: done`, and the project's gitlink is its develop branch, which contains the
   hotfix.

   A conflict in a workspace file, usually a doc that `develop` changed since the
   release, is resolved before the commit: keep `develop`'s text and add the hotfix's
   change to it. Show it to the developer unless it is trivial.
4. With a remote: ask once more before you push, because the main branch and the tag
   publish the hotfix. Then `git push --atomic origin <main branch> develop
   <name>/v<version>`. With `push-policy: never`, or if the developer says no, show the
   command instead. If the remote refuses the push because a branch is protected,
   handle it as in "Merge the project" above, with the workspace's merge requests.
5. Continue with "Finish".

## Finish

1. Confirm:
   - `git -C <path> merge-base --is-ancestor hotfix/v<version> <main-branch>` and
     `… <develop-branch>` in the project
   - `git merge-base --is-ancestor hotfix/<name>-v<version> <main branch>` and
     `… develop` in the workspace
   - Both tags exist, `v<version>` on a commit of the project's main branch, and
     `<name>/v<version>` on a commit of the workspace main branch.
2. Confirm on `develop` that the request file is in `reqs/done/` with `status: done`,
   and that no copy of it is left in `reqs/`.
3. Run the shared clean-up (Step 5 of the skill): the local branches, and the remote
   branches when pushing is allowed. If something was not pushed, say which branches
   and tags still have to be pushed, per repository.
4. If the project tag is on the remote and the project's `remote-platform` is not
   `none`, offer to create a release on the platform from the tag, as in the release
   guide.
