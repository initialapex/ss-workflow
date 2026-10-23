# Merging a release

A release belongs to one project.

| Repository | What happens | Tag |
|------------|--------------|-----|
| The project | `release/v<version>` merges into its `main-branch` and `develop-branch` | `v<version>`, on the merge commit of its main branch |
| The workspace | `develop` records the project's develop branch, then merges into the workspace main branch, where every project's gitlink is set to its main branch | `<name>/v<version>`, on that merge commit |

The workspace has no release branch. Its main branch is the set of the latest
released projects, with the request records of that time. Releases have no worktree:
all of this runs in the root checkout, which stays on `develop` while the project is
on its release branch.

`/ss-workflow:release` prepares the release branch (the version number, the
open-request check). This guide only merges it.

## Prepare (both methods)

1. The project tag is the branch name without `release/`, for example
   `v1.0.0-beta1`. The version is the tag without the `v`. The workspace tag is
   `<name>/v<version>`.
2. The root checkout is on `develop`, and the project is on the release branch
   (`git -C <path> branch --show-current`). `git -C <path> status --porcelain` is
   empty, and so is the workspace's status apart from ` M <path>` for this project.
3. The project's `version-source` contains exactly this version. If it does not, stop
   and point to `/ss-workflow:release`. Skip this step if `version-source` is `none`.
4. Neither tag exists yet: check `git -C <path> tag -l v<version>` and `git tag -l
   <name>/v<version>`, and with a remote `git ls-remote --tags origin <tag>` in each
   repository. If one exists, stop and report it.
5. Run the project's `build-command` and `test-command`, plus `verify-command` if it is
   set, in its folder. They must pass. A command that is empty is skipped: say so in
   the summary of the next step.
6. Show the developer what will be released: the project and the version, the number
   of project commits (`git -C <path> log <main-branch>..HEAD --oneline`), and the
   requests of this project closed since the last workspace tag of the project (files
   added to `reqs/done/` since `<name>/v*`, whose `projects` contains the project, or
   that have no `projects` while the project is `legacy-project`).
   Ask for a go-ahead.

## Merge the project

By the project's merge method (Step 3 of the skill).

### Locally

1. Main branch:

   ```bash
   git -C <path> checkout <main-branch>
   git -C <path> pull --ff-only                      # with a remote
   git -C <path> merge --no-ff release/v<version> -m "Merge release/v<version> into <main-branch>" -m "Release v<version>"
   ```

2. Check that the main branch now equals the release:
   `git -C <path> diff <main-branch> release/v<version> --stat` must be empty. If it
   is not, the main branch has changes that never reached the develop branch, usually
   a hotfix that was not merged back. Stop, report the difference, and ask the
   developer.
3. Tag the merge commit: `git -C <path> tag -a v<version> -m "Release v<version>"`.
4. Develop branch:

   ```bash
   git -C <path> checkout <develop-branch>
   git -C <path> pull --ff-only                      # with a remote
   git -C <path> merge --no-ff release/v<version> -m "Merge release/v<version> into <develop-branch>" -m "Release v<version>"
   ```

   If git answers "Already up to date", the release branch has no commit of its own
   and the develop branch did not move: there is nothing to merge, so continue.

   If this merge has conflicts, resolve them. For `version-source`, keep the higher
   version. Then run the build and the tests again.
5. With a remote: pushing the main branch and the tag publishes the release, so ask
   once more before you push, whatever `push-policy` says. Then push everything of
   the project in one step:

   ```bash
   git -C <path> push --atomic origin <main-branch> <develop-branch> v<version>
   ```

   With `push-policy: never`, or if the developer says no, do not push. Show this
   command, and say that the release is merged and tagged in this repository only
   until the developer runs it. Without a remote, the local tag is the release.

   If the remote refuses the push because the main branch or the develop branch is
   protected, do not work around it. The tag and the merge commits stay local. With a
   remote platform, ask whether to continue with "With a merge request": then delete
   the local tag (`git -C <path> tag -d v<version>`) and undo the two unpublished
   merge commits (`git -C <path> reset --hard HEAD^` on each branch, while `HEAD` is
   that merge commit), so that the tag is created on the commit that the remote
   produces. Without a platform, stop, and tell the developer what has to be pushed by
   someone who is allowed to.
6. Continue with "Merge the workspace".

### With a merge request

1. Push the release branch: `git -C <path> push -u origin release/v<version>`. If you
   may not push it, stop here, and say which branch the developer has to push.
2. Create the merge request from `release/v<version>` into the project's main branch,
   in the project folder, with the title `Release v<version>` and a body that lists
   the changes of this version, grouped by type, one line each in English. Describe
   each change in the project's terms, with no request id and no workspace name (see
   "Workspace and projects" in the root `AGENTS.md`).
3. Give the developer the URL. Tell them to use a merge commit, not a squash merge.
   Switch the project back to its gitlink (`git submodule update <path>`), and stop.
   The developer runs `/ss-workflow:merge <name> release/v<version>` again after it is
   merged.
4. When it is merged on the remote:
   - `git -C <path> checkout <main-branch>`, then `git -C <path> pull --ff-only`.
   - Tag the merge commit and push the tag: `git -C <path> tag -a v<version> -m
     "Release v<version>"`, then `git -C <path> push origin v<version>`. Ask before
     this push. With `push-policy: never`, show the command instead.
   - Merge the release branch into the develop branch: locally as in step 4 of
     "Locally", then push it. If the remote does not allow direct pushes to the
     develop branch, open a second merge request from `release/v<version>` into it and
     wait for it.

## Merge the workspace

Only when the project's release is merged into its main branch and its develop
branch, and the project tag exists.

1. On `develop`, record the project's develop branch, which now contains the release:
   `git -C <path> checkout --detach <develop-ref of the project>`, then `git add
   <path>`. If the gitlink changed, commit `chore(release): update <name> to
   v<version>`. If the release had no commit of its own, the develop branch did not
   move, and nothing changes: no commit.

   Then the workspace docs that state the project's current version: search
   `docs/<name>/` and `docs/overview.md` for the previous version (from the last
   `<name>/v*` tag), as "Documentation" in the release skill's
   `references/version.md` describes. Show the hits, and change the ones that the
   developer agrees to, on `develop` and before step 2, so that the workspace main
   branch shows the released version too. Commit `docs(<name>): update the version
   to v<version>`. No hit, or no agreement: no commit.
2. Merge `develop` into the workspace main branch, with every project at its latest
   release:

   ```bash
   git checkout <main branch>
   git pull --ff-only                      # with a remote
   git merge --no-ff --no-commit develop
   # for every project in projects, not only this one:
   git update-index --cacheinfo 160000,<sha of that project's main branch>,<path>
   git commit -m "Merge develop into <main branch>" -m "Release <name> v<version>"
   git tag -a <name>/v<version> -m "Release <name> v<version>"
   ```

   The merge usually conflicts on the gitlinks, because the main branch records the
   projects' main branches and `develop` their develop branches. `update-index` with
   each project's main branch resolves every gitlink. Other conflicts in the
   workspace (request files, docs) are resolved with `develop`'s side: the main branch
   receives no other commits. Use the project main branch as the remote shows it
   (`origin/<main-branch>`) when it was pushed, the local one otherwise.
3. Check: `git rev-parse <main branch>:<path>` equals `git -C <path> rev-parse
   v<version>^{commit}`, and every other project's gitlink equals its main branch.
4. `git checkout develop`, then `git submodule update`.
5. With a remote: pushing the workspace main branch and the tag publishes the
   release's record, so ask before you push. Then `git push --atomic origin <main
   branch> develop <name>/v<version>`. With `push-policy: never`, show the command
   instead. If the remote refuses the push because a branch is protected, delete the
   local tag, undo the unpublished merge commit, and with a remote platform open a
   merge request from `develop` into the main branch; without one, stop and say what
   has to be merged on the remote. After a remote merge, the gitlinks have to be set
   on the main branch as in step 2: a merge request cannot do that, so the next run of
   this skill adds a commit `chore(release): point <main branch> to the released
   projects` on a short-lived branch and merges it the same way.
6. Continue with "Finish".

## Finish

1. Confirm:
   - `git -C <path> merge-base --is-ancestor release/v<version> <main-branch>` and
     `… <develop-branch>` in the project
   - Both tags exist: `v<version>` on a commit of the project's main branch,
     `<name>/v<version>` on a commit of the workspace main branch
   - The workspace main branch's gitlink of the project is the release commit.
2. Run the shared clean-up (Step 5 of the skill). There is no worktree. Delete the
   project's local release branch (`git -C <path> branch -d release/v<version>`), and
   the remote one when pushing is allowed. If the release was not pushed, the
   confirmations above hold for the local branches only: say what still has to be
   pushed, per repository.
3. Leave the root checkout on `develop`, with every project at its gitlink.
4. If the project tag is on the remote and the project's `remote-platform` is not
   `none`, offer to create a release on the platform from the tag, and do it only if
   the developer agrees, in the project folder:
   - GitHub: `gh release create v<version> --generate-notes`, with `--prerelease` when
     the version has a prerelease part
   - GitLab: `glab release create v<version>`

## Pre-1.0 sync without a release branch

Before a project's v1.0.0, the root `AGENTS.md` allows merging its develop branch
straight into its main branch. Offer this only when the project's current version is
below `1.0.0` and the developer asks for it. The current version is the value in its
`version-source`, or its last tag when `version-source` is `none`.

1. The root checkout is on `develop` and clean, and the project's build and tests
   pass on its develop branch.
2. Ask whether to tag this state. The tag is `v` plus the version in `version-source`.
   If that tag already exists, the version must be raised first: point to
   `/ss-workflow:release <name>`. When `version-source` is `none`, ask the developer
   for the tag.
3. Merge in the project:

   ```bash
   git -C <path> checkout <main-branch>
   git -C <path> pull --ff-only                      # with a remote
   git -C <path> merge --no-ff <develop-branch> -m "Merge <develop-branch> into <main-branch>"
   git -C <path> tag -a v<version> -m "Release v<version>"     # only if the developer wants the tag
   ```

4. With a remote, ask, then push: `git -C <path> push --atomic origin <main-branch>
   v<version>`. With `push-policy: never`, show the command instead.
5. The workspace main branch follows as in "Merge the workspace", steps 2 to 5, with
   the workspace tag `<name>/v<version>` only if the project got a tag.
