# Merging a hotfix

A hotfix belongs to one project, named in the request's `projects`.

| Repository | Branch | Starts from | Merges into | Tag |
|------------|--------|-------------|-------------|-----|
| The project | `hotfix/v<version>` | its `main-branch` | its `main-branch`; then `main-branch` merges back into `develop-branch` | `v<version>`, on the merge commit of its main branch |
| The workspace | `hotfix/<name>-v<version>` | the workspace main branch | the workspace main branch and `develop` | `<name>/v<version>`, on the merge commit of the main branch |

All of this runs in the root checkout. The hotfix worktrees were removed when the
implementation was finished. The request file was copied onto the workspace hotfix
branch by the start commit, so that branch carries its only copy. A hotfix started
before ss-workflow 0.8.0 also left an old copy in `reqs/` on `develop`, with
`status: ready`.

The project goes first, the workspace last, as for a request. The tagged version is
built and packaged as `${CLAUDE_PLUGIN_ROOT}/skills/release/references/package.md`
describes (called "package.md" below), and everything is published at the end. As
for a release, the main branch merges back into the develop branch, so that the
hotfix tag is reachable from there (see "Merging a release").

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
4. When `version-source` is a file, it contains exactly this version on the project
   hotfix branch. If it does not, set it and commit `chore(release): bump version to
   <version>` in the project. Skip this step for `git-tag` and `none`.
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

1. Note the starting point, as package.md says, in the project and in the workspace.
2. The project's main branch, with the tag:

   ```bash
   git -C <path> checkout <main-branch>
   git -C <path> pull --ff-only                      # with a remote
   git -C <path> merge --no-ff hotfix/v<version> -m "Merge hotfix/v<version> into <main-branch>" -m "Hotfix v<version>"
   git -C <path> tag -a v<version> -m "Hotfix v<version>"
   ```

3. "Build the tagged version" and "Make the package" in package.md.
4. Merge the main branch back into the project's develop branch:

   ```bash
   git -C <path> checkout <develop-branch>
   git -C <path> pull --ff-only                      # with a remote
   git -C <path> merge --no-ff <main-branch> -m "Merge <main-branch> into <develop-branch>" -m "Hotfix v<version>"
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

   The first merge of this kind in a project that was released before ss-workflow
   0.10.0 also brings the old merge commits of the main branch; their content is
   already on the develop branch. Then check: `git -C <path> merge-base
   --is-ancestor v<version> <develop-branch>`.
5. If the project has an open `release/*` branch, the release would ship without the
   fix. Ask the developer whether to merge the main branch into that release branch
   as well, the same way as in step 4 (`-m "Merge <main-branch> into
   release/vX.Y.Z"`). Its next release candidate then contains the fix.
6. Nothing is pushed yet. Continue with "Merge the workspace"; "Publish" pushes the
   project's branches and the tag together.

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
3. When it is merged on the remote, the merge is public before its tag and its
   package. Continue locally: note the starting point, check out and pull the main
   branch, tag the merge commit (`git -C <path> tag -a v<version> -m "Hotfix
   v<version>"`), build and package it (step 3 of "Locally"), and merge the main
   branch back into the develop branch as in step 4 of "Locally" (step 5 for an open
   release branch). If the remote does not allow direct pushes to the develop branch,
   open a merge request from `<main-branch>` into `<develop-branch>` during "Publish",
   and continue the workspace once it is merged.

## Merge the workspace

Only when the project's hotfix is merged into its main branch, the main branch is
merged back into its develop branch (locally at least), and the project tag exists.

1. **Close the request on the workspace hotfix branch**:
   - Set `status: done`.
   - Add a dated line to `## Notes`: `Released as <name> v<version> (yyyy-MM-dd)`.
   - `git mv reqs/<file> reqs/done/<file>`
   - Set the project's gitlink to the tagged commit:
     `git -C <path> checkout --detach v<version>`, then `git add <path>`.
   - Commit `chore(reqs): close REQ-0012`, with `Refs: REQ-0012`. Do not push it
     yet: it records a project commit that is not on the remote before "Publish".
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
   git update-index --cacheinfo 160000,<sha of the project's local develop branch>,<path>
   git commit -m "Merge hotfix/<name>-v<version> into develop" -m "Hotfix <name> v<version>" -m "Refs: REQ-0012"
   git submodule update
   ```

   After this commit, `develop` has the request only in `reqs/done/`, with
   `status: done`, and the project's gitlink is its develop branch, which contains the
   hotfix.

   A conflict in a workspace file, usually a doc that `develop` changed since the
   release, is resolved before the commit: keep `develop`'s text and add the hotfix's
   change to it. Show it to the developer unless it is trivial.
4. Continue with "Publish".

## Publish

"Publish" in package.md, with these pushes:

- The project: `git -C <path> push --atomic origin <main-branch> <develop-branch>
  v<version>`, plus `release/vX.Y.Z` when step 5 of "Locally" changed it (after a
  merge request: everything but the main branch).
- The workspace: `git push --atomic origin <main branch> develop
  hotfix/<name>-v<version> <name>/v<version>`.

The platform release is a final release, with the package as its asset.

If the remote refuses a push because a branch is protected, do not work around it.
Undo the run in both repositories, as "Before the first tag" in package.md says, and
continue with "With a merge request" for that repository, or stop without a remote
platform and say what has to be merged on the remote. A refused project develop
branch alone is handled as in the release guide: push the main branch and the tag,
and open a merge request from `<main-branch>` into `<develop-branch>`.

## Finish

1. Confirm:
   - `git -C <path> merge-base --is-ancestor hotfix/v<version> <main-branch>` and
     `git -C <path> merge-base --is-ancestor v<version> <develop-branch>` in the
     project
   - `git merge-base --is-ancestor hotfix/<name>-v<version> <main branch>` and
     `… develop` in the workspace
   - Both tags exist, `v<version>` on a commit of the project's main branch, and
     `<name>/v<version>` on a commit of the workspace main branch.
2. Confirm on `develop` that the request file is in `reqs/done/` with `status: done`,
   and that no copy of it is left in `reqs/`.
3. Run the shared clean-up (Step 5 of the skill): the local branches, and the remote
   branches when pushing is allowed. If something was not pushed, say which branches
   and tags still have to be pushed, per repository.
