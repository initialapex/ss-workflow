# Merging a release

A release belongs to one project. This guide merges its final version; release
candidates and alpha or beta versions are tagged by `/ss-workflow:release` without a
merge.

| Repository | What happens | Tag |
|------------|--------------|-----|
| The project | `release/vX.Y.Z` merges into its `main-branch`; then `main-branch` merges back into its `develop-branch` | `vX.Y.Z`, on the merge commit of its main branch |
| The workspace | `develop` records the project's develop branch, then merges into the workspace main branch, where every project's gitlink is set to its main branch | `<name>/vX.Y.Z`, on that merge commit |

The workspace has no release branch. Its main branch is the set of the latest
released projects, with the request records of that time. Releases have no worktree:
all of this runs in the root checkout, which stays on `develop` while the project is
on its release branch.

`/ss-workflow:release` prepares the release branch (the version number, the
open-request check). This guide merges it, builds and packages the tagged version as
`${CLAUDE_PLUGIN_ROOT}/skills/release/references/package.md` describes (called
"package.md" below), and publishes everything at the end.

Why the main branch merges back into the develop branch: the tag sits on the merge
commit of the main branch. Merged that way, it is an ancestor of the develop branch,
so a build on the develop branch that reads its version from the nearest tags
(`version-source: git-tag`) finds the final version, and not an older release
candidate.

## Prepare (both methods)

1. The version is the branch name without `release/v`, for example `1.2.0`; the
   project tag is `v1.2.0`, the workspace tag `<name>/v1.2.0`. A release branch from
   before ss-workflow 0.10.0 may carry a prerelease suffix (`release/v1.0.0-beta1`):
   ask the developer whether to release it as that version, as before, or as the
   final `X.Y.Z`.
2. The root checkout is on `develop`, and the project is on the release branch
   (`git -C <path> branch --show-current`). Between release candidates the project
   is at its gitlink: check out the release branch first (`git -C <path> checkout
   release/v<version>`, then `git -C <path> pull --ff-only` with a remote). `git -C <path> status --porcelain` is
   empty, and so is the workspace's status apart from ` M <path>` for this project.
3. When `version-source` is a file, it contains exactly this version. If it does not,
   stop and point to `/ss-workflow:release`. Skip this step for `git-tag` and `none`.
4. Neither tag exists yet: check `git -C <path> tag -l v<version>` and `git tag -l
   <name>/v<version>`, and with a remote `git ls-remote --tags origin <tag>` in each
   repository. If one exists, stop and report it.
5. Run the project's `build-command` and `test-command`, plus `verify-command` if it is
   set, in its folder. They must pass. A command that is empty is skipped: say so in
   the summary of the next step.
6. Show the developer what will be released: the project and the version, the release
   candidates of this version (`git -C <path> tag -l "v<version>-rc*"`), the number
   of project commits (`git -C <path> log <main-branch>..HEAD --oneline`), the
   requests of this project closed since the last final release of the project (files
   added to `reqs/done/` since `<name>/v<last final>`, whose `projects` contains the project, or
   that have no `projects` while the project is `legacy-project`), and the package
   that will be made (`package-command` or `package-files`). Ask for a go-ahead.

## Merge the project

By the project's merge method (Step 3 of the skill).

### Locally

1. Note the starting point, as package.md says.
2. Main branch:

   ```bash
   git -C <path> checkout <main-branch>
   git -C <path> pull --ff-only                      # with a remote
   git -C <path> merge --no-ff release/v<version> -m "Merge release/v<version> into <main-branch>" -m "Release v<version>"
   ```

3. Check that the main branch now equals the release:
   `git -C <path> diff <main-branch> release/v<version> --stat` must be empty. If it
   is not, the main branch has changes that never reached the develop branch, usually
   a hotfix that was not merged back. Stop, report the difference, and ask the
   developer.
4. Tag the merge commit: `git -C <path> tag -a v<version> -m "Release v<version>"`.
5. "Build the tagged version" and "Make the package" in package.md.
6. Merge the main branch back into the develop branch:

   ```bash
   git -C <path> checkout <develop-branch>
   git -C <path> pull --ff-only                      # with a remote
   git -C <path> merge --no-ff <main-branch> -m "Merge <main-branch> into <develop-branch>" -m "Release v<version>"
   ```

   If this merge has conflicts, resolve them. For `version-source`, keep the higher
   version. Then run the build and the tests again. The first merge of this kind in a
   project that was released before ss-workflow 0.10.0 also brings the old merge
   commits of the main branch: their content is already on the develop branch, so a
   conflict there is usually on the version alone.
7. Check that the tag is reachable from the develop branch: `git -C <path> merge-base
   --is-ancestor v<version> <develop-branch>`.
8. Nothing is pushed yet. Continue with "Merge the workspace"; "Publish" pushes the
   project's `<main-branch>`, `<develop-branch>`, and `v<version>` together.

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
4. When it is merged on the remote, the merge is public before its tag and its
   package. Continue locally:
   - Note the starting point, as package.md says.
   - `git -C <path> checkout <main-branch>`, then `git -C <path> pull --ff-only`.
   - Tag the merge commit: `git -C <path> tag -a v<version> -m "Release v<version>"`.
   - "Build the tagged version" and "Make the package" in package.md.
   - Merge the main branch back into the develop branch as in step 6 of "Locally". If
     the remote does not allow direct pushes to the develop branch, open a second
     merge request from `<main-branch>` into `<develop-branch>` during "Publish", and
     continue the workspace once it is merged.

## Merge the workspace

Only when the project's release is merged into its main branch, the main branch is
merged back into its develop branch (locally at least), and the project tag exists.

1. On `develop`, record the project's develop branch, which now contains the release:
   `git -C <path> checkout --detach <develop-branch>` (the local branch: it is not
   pushed yet), then `git add <path>`, and commit `chore(release): update <name> to
   v<version>`.

   Then the workspace docs that state the project's current version: search
   `docs/<name>/` and `docs/overview.md` for the previous final version (from the
   last final `<name>/v*` tag), as "Documentation" in the release skill's
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
   receives no other commits. For this project, use its local main branch, which
   holds the release; for the others, the main branch as the remote shows it
   (`origin/<main-branch>`) when they have a remote, the local one otherwise.
3. Check: `git rev-parse <main branch>:<path>` equals `git -C <path> rev-parse
   v<version>^{commit}`, and every other project's gitlink equals its main branch.
4. `git checkout develop`, then `git submodule update`.

## Publish

"Publish" in package.md, with these pushes:

- The project: `git -C <path> push --atomic origin <main-branch> <develop-branch>
  v<version>` (after a merge request: only the tag and the develop branch).
- The workspace: `git push --atomic origin <main branch> develop <name>/v<version>`.

The platform release is a final release, with the package as its asset.

If the remote refuses a push because a branch is protected, do not work around it.
Nothing of the workspace is pushed when the project push fails, because of the order.

- **The project's main branch** refused: with a remote platform, ask whether to
  continue with "With a merge request". Then undo the run in both repositories, as
  "Before the first tag" in package.md says, so that the tag is created on the commit
  that the remote produces. Without a platform, stop, and tell the developer what has
  to be pushed by someone who is allowed to.
- **The project's develop branch** refused: push the main branch and the tag alone
  (`git -C <path> push --atomic origin <main-branch> v<version>`), open a merge request
  from `<main-branch>` into `<develop-branch>`, and undo the local back-merge and the
  workspace's commits of this run. Continue the workspace after that merge request is
  merged, from "Merge the workspace".
- **The workspace** refused: delete the local workspace tag, undo the unpublished
  merge commit, and with a remote platform open a merge request from `develop` into
  the main branch; without one, stop and say what has to be merged on the remote.
  After a remote merge, the gitlinks have to be set on the main branch as in step 2
  of "Merge the workspace": a merge request cannot do that, so the next run of this
  skill adds a commit `chore(release): point <main branch> to the released projects`
  on a short-lived branch and merges it the same way.

## Finish

1. Confirm:
   - `git -C <path> merge-base --is-ancestor release/v<version> <main-branch>` and
     `git -C <path> merge-base --is-ancestor v<version> <develop-branch>` in the
     project
   - Both tags exist: `v<version>` on a commit of the project's main branch,
     `<name>/v<version>` on a commit of the workspace main branch
   - The workspace main branch's gitlink of the project is the release commit.
2. Run the shared clean-up (Step 5 of the skill). There is no worktree. Delete the
   project's local release branch (`git -C <path> branch -d release/v<version>`), and
   the remote one when pushing is allowed. The release candidate tags stay. If the
   release was not pushed, the confirmations above hold for the local branches only:
   say what still has to be pushed, per repository.
3. Leave the root checkout on `develop`, with every project at its gitlink.

## Pre-1.0 sync without a release branch

Before a project's v1.0.0, the root `AGENTS.md` allows merging its develop branch
straight into its main branch. Offer this only when the project's current version is
below `1.0.0` and the developer asks for it. The current version is the value in its
`version-source` when that is a file, or its last final tag otherwise.

1. The root checkout is on `develop` and clean, and the project's build and tests
   pass on its develop branch. The project has no `release/*` branch.
2. Ask whether to tag this state. The tag is `v` plus the version in `version-source`
   when it is a file. If that tag already exists, the version must be raised first:
   point to `/ss-workflow:release <name>`. With `git-tag` or `none`, recommend the
   version as "Choosing the target" in the release skill's `references/version.md`
   does, and ask.
3. Note the starting point, as package.md says. Merge in the project:

   ```bash
   git -C <path> checkout <main-branch>
   git -C <path> pull --ff-only                      # with a remote
   git -C <path> merge --no-ff <develop-branch> -m "Merge <develop-branch> into <main-branch>"
   git -C <path> tag -a v<version> -m "Release v<version>"     # only if the developer wants the tag
   ```

4. With a tag: "Build the tagged version" and "Make the package" in package.md.
5. Merge the main branch back: `git -C <path> checkout <develop-branch>`, then `git -C
   <path> merge --no-ff <main-branch> -m "Merge <main-branch> into <develop-branch>"`.
6. The workspace follows as in "Merge the workspace", with the workspace tag
   `<name>/v<version>` only if the project got a tag. Then "Publish", with the
   project's `<main-branch>`, `<develop-branch>`, and the tag if there is one.
