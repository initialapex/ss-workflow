---
name: release
description: Release a new version of one project of an ss-workflow workspace. On the workspace develop it recommends the project's next version, then either tags an alpha or beta version on the project's develop branch, or opens the release branch release/vX.Y.Z in the project repository. On a release branch it tags release candidates, or hands the final version over to the release merge (the project's main branch with the tag, back into develop, then the workspace main branch and tag). Every tagged version is built from its tag and packaged before anything is pushed. It checks for unfinished requests and worktrees of that project, and sets the version where a file carries it. Use when the developer asks to release, publish, or cut a new version, prerelease, or release candidate of a project.
argument-hint: "[project] [version, e.g. 1.2.0, 1.2.0-rc1 or 1.3.0-beta2]"
---

# release

Release one version of one project. Every project has its own version, so a project
that did not change is not released.

| Version | Where | How |
|---------|-------|-----|
| Alpha, beta | The tip of the project's develop branch | Part A of this skill |
| Release candidate | The tip of `release/vX.Y.Z` in the project | Part B, which leaves the release branch open |
| Final | The project's main branch, after `release/vX.Y.Z` | Part B, then the release merge of `/ss-workflow:merge` |

Input: `$ARGUMENTS`: the project (its `name` in "Workflow settings"; may be left out
when the workspace has one project), and an optional version that skips the
recommendation.

| Where | What it does |
|-------|--------------|
| The workspace on `develop`, root checkout, the project at its gitlink, and no `release/*` branch in the project | Steps 1 to 3, then Part A or Part B |
| The workspace on `develop`, root checkout, and the project has a `release/*` branch (locally or on its remote; the project at its gitlink or on that branch) | Steps 1 to 3 for that release branch, then Part B from Step B2 |
| Anywhere else | The root checkout is busy with something else (a request branch whose file says `draft` means a spec discussion, another request branch means a review), or this is a worktree. Say which, and stop. |

Supporting files:

- [references/version.md](references/version.md): where each kind of version goes,
  how to recommend and validate it, and where to set it
- [references/package.md](references/package.md): building the tagged version, the
  package, and publishing

## Ground rules

- Read the root `AGENTS.md` ("Workflow settings", "Workspace and projects",
  "Branching model", "Versioning", "Commit convention"), `reqs/AGENTS.md`, and the
  project's section in `projects/AGENTS.md` first. They are the source of truth.
- Talk to the developer in `discussion-language`.
- A release has no worktree. Everything runs in the root checkout: the workspace stays
  on `develop`, and the project in it switches to the commit or the branch that the
  release works on. If this session is inside a linked worktree, stop and say so.
  Between two release candidates the project goes back to its gitlink, so that the
  root checkout is free for reviews and spec discussions while a release candidate
  is tested.
- Only one release branch per project at a time. If the project already has one,
  continue it. Do not open a second one. While it is open, the project gets no alpha
  or beta tag. Two projects can be released one after the other.
- A release branch takes only release work: the version number, release notes, and
  small fixes for problems found in the release candidates. A larger change goes
  through a request into the project's develop branch, and Step B2 then merges the
  develop branch into the release branch for the next release candidate.
- Release commits are made in the project. Like every project commit, they carry no
  request id, no workspace name, and no `Refs:` footer that points to the workspace.
- A tag is created locally, the tagged version is built and packaged, and only then
  is anything published ("Publish" in [references/package.md](references/package.md)).
- Never force-push. Never rebase a pushed branch.
- **Pushing**: follow "Remote and pushing" in the root `AGENTS.md`, for the project
  with its entry's `push-policy` (the workspace value when the entry leaves it empty).
  Where this skill says "push", push only when the project has a remote and its
  `push-policy` allows it: `auto` pushes, `ask` asks before the first push of this
  run, and `never` does not push. A missing `push-policy` means `auto`. Pushing a tag
  always asks first. Steps that fetch or pull apply only with a remote. When a push is
  skipped, go on, and list the unpushed branches and tags in the report.
- Report results as they are: what ran and passed, what ran and failed, and what did
  not run and why. Nothing that did not run is reported as passed.

## Step 1: Preconditions

1. If the root `AGENTS.md` has no `ss-workflow-version:`, stop and point to
   `/ss-workflow:init`. If the version is below `0.6.0`, the repository has the
   single-repository layout: stop, and point to `/ss-workflow:init`, which converts
   it.
2. **The project**: from `$ARGUMENTS`, or the only entry of `projects`. If there are
   several and none is named, list them with their last tag and the number of commits
   on their develop branch since then, and ask which one.
3. The root checkout is on `develop`, and `git status --porcelain` is empty, apart from
   ` M <path>` when the project is on its release branch. If it is not, stop and
   report it.
4. With a remote, run `git fetch --prune --tags` and `git pull --ff-only` in the
   workspace, then `git submodule update`. In the project: `git -C <path> fetch
   --prune --tags`.
5. Look for an open release of the project: `git -C <path> branch -a --list
   "*release/*"`. If one exists, this run continues it: tell the developer, check it
   out (`git -C <path> checkout release/vX.Y.Z`, or `git -C <path> checkout -b
   release/vX.Y.Z --track origin/release/vX.Y.Z` when it is only on the remote), and
   continue with Step 2. A `release/*` branch whose name has a prerelease suffix
   (`release/v1.0.0-beta1`) comes from before ss-workflow 0.10.0: finish it as a final
   version of its `X.Y.Z`, or ask the developer.
6. Read the project's tags as "The project's tags" in
   [references/version.md](references/version.md) describes: the last final, the
   target, and the highest of the target. Find the workspace's tags of the project
   too (`git tag -l "<name>/v*"`): the workspace tag of the last final is
   `<name>/v<last final>`. Do not use `git describe` on the workspace main branch for
   it: the main branch contains the alpha and beta tags of `develop`.
7. Check that there is something to release: `git -C <path> log <last tag>..<the
   commit to release> --oneline`, where the commit is the project's develop-ref, or
   the release branch, and the last tag is the newest version tag that is an ancestor
   of it (without a tag: all commits). If it is empty, say that the project has
   nothing new since that tag, and stop.

## Step 2: Show what the release contains

Summarize the changes since the last final tag, and for a prerelease or a release
candidate also mark what is new since the previous tag of the target:

- The requests of this project closed since the workspace's last final tag of the
  project: the files added to `reqs/done/` (`git diff --name-only --diff-filter=A
  <name>/v<last final>..develop -- reqs/done/`, or since the start when there is no
  such tag), whose `projects` contains the project. A request without `projects` is
  from before the workspace layout, and belongs to `legacy-project` in "Workflow
  settings". A request with `projects: []` changed workspace files only, and belongs
  to no release. Show each with its id, title, and type.
- The project commits by type (`feat`, `fix`, …), and every commit that has
  `BREAKING CHANGE:` in its body or `!` after its type
- Project changes made outside this workspace: by people who work on the project
  without it, or from another developer's own workspace. Project commits carry no
  request id, so find them through the requests: each closed request above names its
  project merge commits in the `Merged into develop` line of its `## Notes`
  (`<name> <short sha>`). On the first-parent line of the project's develop branch
  since the last final tag (`git -C <path> log --first-parent --oneline <last
  final>..<project develop-ref>`), every commit that is not one of those merge
  commits, and not a merge of the main branch back into the develop branch, came from
  outside this workspace. For a closed request without that line (closed by hand),
  match the merge whose subject names its `project-branch`. Show these changes,
  because no request of this workspace describes them. They count for the version and
  the changelog like the requests.

## Step 3: Choose the version

Follow "Recommending the version" in [references/version.md](references/version.md),
for the situation of this run: on the develop branch, or on the open release branch.

- If `$ARGUMENTS` gives a version, validate it ("Validation") and use it. A final or
  `rc` version on the develop branch means: open its release branch, and tag that
  version on it. If the version is invalid, say why and continue with the
  recommendation.
- Otherwise, recommend with the reason, and ask with AskUserQuestion. Put the
  recommended choice first, and offer the other candidates of the situation. The
  developer can type any other version through "Other".

The project tag is `v<version>`. An alpha or beta version continues with Part A. Opening
the release branch, a release candidate, or a final version continues with Part B.

## Part A: An alpha or beta version on the develop branch

### Step A1: Check that it is allowed

- The project's `version-source` is `git-tag` or `none`. If it is a file, the version
  cannot change without a commit on the develop branch: say so, offer a release
  candidate on a release branch instead, and mention that `version-source: git-tag`
  allows alpha and beta versions.
- The project has no `release/*` branch.

### Step A2: Check for unfinished work

As Step B3. For an alpha or beta version, "Release without them" is the usual answer:
say so.

### Step A3: Check out and verify

1. `git -C <path> checkout --detach <project develop-ref>`. If `develop`'s gitlink is
   behind it, show the commits in between (`git -C <path> log --oneline
   <gitlink>..<project develop-ref>`): they become part of this version, and the
   workspace records them in Step A5.
2. Run the checks of Step B5 on this commit.

### Step A4: Tag, build, and package

1. Note the starting point, as [references/package.md](references/package.md) says.
2. `git -C <path> tag -a v<version> -m "Release v<version>"`
3. "Build the tagged version" and "Make the package" in
   [references/package.md](references/package.md).

### Step A5: Record it in the workspace

On `develop` in the root checkout:

1. `git add <path>`. If the gitlink changed, commit `chore(release): update <name> to
   v<version>`.
2. `git tag -a <name>/v<version> -m "Release <name> v<version>"` on `develop`, whose
   gitlink is now the tagged commit.

### Step A6: Publish

"Publish" in [references/package.md](references/package.md): the project pushes only
its tag (`git -C <path> push origin v<version>`), and the workspace pushes `develop`
and its tag (`git push --atomic origin develop <name>/v<version>`). The platform
release is a prerelease.

If the remote refuses the push of the workspace's `develop` (a protected branch),
delete the workspace tag, move the gitlink commit to a short-lived branch
(`chore/<name>-v<version>`, then `git reset --hard <noted commit>` on `develop`), push
that branch, and open a merge request where `remote-platform` allows one. Once it is
merged, tag the merge commit with `<name>/v<version>` and push the tag (ask first).

Then `git submodule update <path>`, and report (Step 10).

## Part B: The release branch

### Step B1: Open the release branch

Only when Step 1 found no release branch.

```bash
git -C <path> checkout -b release/vX.Y.Z <project develop-ref>
git -C <path> push -u origin release/vX.Y.Z      # when pushing is allowed
```

`X.Y.Z` is the final version that the branch prepares, also when its first tag is a
release candidate. The workspace shows ` M <path>` while the project is on the
release branch: the root checkout is busy with this release until the project goes
back to its gitlink.

### Step B2: Bring the release branch up to date

Run this step when the skill starts on an existing release branch. Directly after
Step B1, there is nothing to do here.

1. Check that `git -C <path> status --porcelain` is empty. With a remote, run
   `git -C <path> pull --ff-only`.
2. If the project's develop branch has commits that the release branch does not have
   (`git -C <path> log HEAD..<project develop-ref> --oneline`), show them. They are
   the larger changes for this version that went through requests. Ask whether to
   include them in this release. If yes, run `git -C <path> merge --no-ff <project
   develop-ref> -m "Merge <develop-branch> into release/vX.Y.Z"`, and resolve
   conflicts if there are any (for `version-source`, keep the release branch's
   version). A final version after such a merge is possible, but recommend a
   release candidate first.
3. Small fixes for a problem found in a release candidate are committed here, on the
   release branch, as normal `fix:` commits, after the developer agrees to each one.

### Step B3: Check for unfinished work

Collect the following, for this project only:

- The open requests whose `projects` contains the project, with their effective
  status: those on request branches, and those in `reqs/` on `develop` from before
  ss-workflow 0.8.0. Collect them as `/ss-workflow:check-req` does in its overview.
- The worktrees of the project (`git -C <path> worktree list`), other than the root
  checkout's submodule
- Open hotfixes of the project: `hotfix/*` branches in the project

Sort them into two groups:

| Group | Requests |
|-------|----------|
| Unfinished | `in-progress` (being implemented in a worktree, or reopened), `review` (waiting for or under Verify and Review), and merge pending |
| Not started | Drafts and `ready` requests |

If the "Unfinished" group is empty and there is no open hotfix, continue with the
next step. Mention the "Not started" requests only as information: they do not block
a release.

Otherwise, show both groups and ask the developer with AskUserQuestion:

| Option | Action |
|--------|--------|
| Release without them | Continue. List these requests in the final report as "not part of this release". |
| Finish them first | Stop here. Explain the way back: put the project back at its gitlink (`git submodule update <path>`), finish the requests with `/ss-workflow:check-req`, `/ss-workflow:review`, and `/ss-workflow:merge`, then run `/ss-workflow:release <name>` again. On a release branch, it continues the release, and Step B2 offers to include the new commits. |
| Cancel the release | Confirm it once more. Put the project back (`git submodule update <path>`). On a release branch that has no tag yet, ask whether to delete it (`git -C <path> branch -D release/vX.Y.Z`, and `git -C <path> push origin --delete release/vX.Y.Z` if it is on the remote and pushing is allowed). A release branch with release candidates stays: its tags are published. Stop. |

An open hotfix of the project must be merged before the release: point to
`/ss-workflow:merge`, and treat it like "Finish them first".

### Step B4: Set the version

Follow "Setting the version" in [references/version.md](references/version.md), for
the version of this run (a release candidate or the final version).

With `version-source: git-tag` or `none`, no file carries the version; only the docs
and the changelog of a final version may change. If something had to change, commit
in the project and push:

```
chore(release): bump version to <version>
```

or, for the docs and the changelog alone, `docs: update the docs for v<version>`. If
nothing had to change, say that the version numbers already match.

### Step B5: Verify

Run the project's `build-command` and `test-command` on the release branch, in its
folder, plus `verify-command` if it is set. They must pass. These commands come from
the project's entry in "Workflow settings" and depend on its toolchain. A command that
is empty is skipped: tell the developer that this check is not configured, and ask
them to confirm that they checked the release build themselves. Report each command
with `passed`, `failed (<reason>)`, or `not configured`.

With `version-source: git-tag`, this build is not tagged yet, and carries a version
such as `1.2.0-rc1-2-g1a2b3c4`: the build of the tagged version follows in Step B6 or
in the merge.

If another project of the workspace builds against this one (its "Project rules" or
build files refer to it), say so: its build uses the gitlink of this project, which
changes only when the workspace records the release.

If they fail, stop and report the failure. A fix for it is committed on the release
branch as a normal `fix:` commit, and only after the developer agrees. Then run this
step again.

### Step B6: A release candidate

For an `rc` version:

1. Note the starting point, as [references/package.md](references/package.md) says.
2. Tag the tip of the release branch: `git -C <path> tag -a v<version> -m "Release
   v<version>"`.
3. "Build the tagged version" and "Make the package" in
   [references/package.md](references/package.md).
4. "Publish": the project pushes the release branch and the tag (`git -C <path> push
   --atomic origin release/vX.Y.Z v<version>`). The workspace has nothing to push: a
   release candidate has no workspace tag, because `develop` records the project's
   develop branch, not its release branch. The platform release is a prerelease.
5. Put the project back at its gitlink: `git submodule update <path>`. The release
   branch stays open.

Then report (Step 10), with the way forward: test the release candidate; run
`/ss-workflow:release <name>` again for a small fix and the next release candidate,
or for the final version.

### Step B7: The final version

Continue directly with the release merge. Invoke the `ss-workflow:merge` skill for
this project's release branch. If you cannot invoke it, read
`${CLAUDE_PLUGIN_ROOT}/skills/merge/SKILL.md` and its `references/release.md`, and
follow them.

That skill asks the developer for the go-ahead, merges into the project's main
branch, creates the project tag, builds and packages the tagged version, merges the
main branch back into the develop branch, records the release in the workspace main
branch with the workspace tag, publishes everything after one more question (with
`push-policy: never` it shows the push commands instead), and deletes the release
branch.

## Step 10: Report

After the last step (or after the merge skill finishes), add to the report, in
`discussion-language`:

- The released project, its version, and its tags (none in the workspace for a
  release candidate)
- The requests in this release, grouped by type
- The requests of this project that are not part of this release (from Step B3)
- Project commits without a request, if Step 2 found any
- The checks that were not configured, and that the developer confirmed the release
  build themselves
- The package: the zip and its files, and where it was uploaded, or that the project
  has no `package-files`
- What is not on the remotes yet, with the commands that push it, per repository
- For an open release branch: that it stays open, and how to continue it
- A reminder of anything the developer still does by hand, such as announcing the
  release
