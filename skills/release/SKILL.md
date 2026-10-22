---
name: release
description: Release a new version of one project of an ss-workflow workspace. On the workspace develop it recommends the project's next version number, creates the release branch in the project repository, checks for unfinished requests and worktrees of that project, sets the version number everywhere, and hands over to the release merge (the project's main branch, develop, and tag, then the workspace main branch and tag). It continues a release that was started earlier when the project is already on a release branch. Use when the developer asks to release, publish, or cut a new version of a project.
argument-hint: "[project] [version, e.g. 1.2.0 or 1.0.0-beta1]"
---

# release

Prepare the release of one project on a `release/v<version>` branch in the project's
repository, then hand it over to the release merge rules of `/ss-workflow:merge`.
Every project has its own version, so a project that did not change is not released.

Input: `$ARGUMENTS`: the project (its `name` in "Workflow settings"; may be left out
when the workspace has one project), and an optional version that skips the
recommendation.

| Where | What it does |
|-------|--------------|
| The workspace on `develop`, root checkout, and the project at its gitlink | Start a release: Steps 1 to 4, then continue with Step 5 |
| The workspace on `develop`, root checkout, and the project on a `release/*` branch | Continue that release from Step 5 |
| Anywhere else | The root checkout is busy with something else (a request branch whose file says `draft` means a spec discussion, another request branch means a review), or this is a worktree. Say which, and stop. |

Supporting file:

- [references/version.md](references/version.md): how to recommend the version, and
  where to set it

## Ground rules

- Read the root `AGENTS.md` ("Workflow settings", "Workspace and projects",
  "Branching model", "Versioning", "Commit convention"), `reqs/AGENTS.md`, and the
  project's section in `src/AGENTS.md` first. They are the source of truth.
- Talk to the developer in `discussion-language`.
- A release has no worktree. Everything runs in the root checkout: the workspace stays
  on `develop`, and the project in it switches to the release branch. If this session
  is inside a linked worktree, stop and say so.
- Only one release per project at a time. If the project already has a `release/*`
  branch, continue that one. Do not start a second one. Two projects can be released
  one after the other.
- A release branch takes only release work: the version number, release notes, and
  fixes for problems that block the release. New features go through requests.
- Release commits are made in the project. Like every project commit, they carry no
  request id, no workspace name, and no `Refs:` footer that points to the workspace.
- Never force-push. Never rebase a pushed branch.
- **Pushing**: follow "Remote and pushing" in the root `AGENTS.md`, for the project
  with its entry's `push-policy` (the workspace value when the entry leaves it empty).
  Where this skill says "push", push only when the project has a remote and its
  `push-policy` allows it: `auto` pushes, `ask` asks before the first push of this
  run, and `never` does not push. A missing `push-policy` means `auto`. Steps that
  fetch or pull apply only with a remote. When a push is skipped, go on, and list the
  unpushed branches in the report.
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
   "*release/*"`. If one exists, tell the developer, and ask whether to continue it
   (`git -C <path> checkout release/<tag>`, then Step 5). Do not create another.
6. Find the project's last release tag on its main branch:
   `git -C <path> describe --tags --abbrev=0 <project main-ref>`, where `<project
   main-ref>` is `origin/<main-branch>` with a remote. There may be none yet. Find the
   workspace's last tag of the project too: `git describe --tags --abbrev=0 --match
   "<name>/v*" <main branch>`.
7. Check that there is something to release: `git -C <path> log <last tag>..<project
   develop-ref> --oneline` (without a tag: all commits on the develop branch). If it
   is empty, say that the project has nothing new since its last release, and stop.

## Step 2: Show what the release contains

Summarize the changes since the last tag:

- The requests of this project closed since the workspace's last tag of the project:
  the files added to `reqs/done/` (`git diff --name-only --diff-filter=A
  <name>/v<last>..develop -- reqs/done/`, or since the start when there is no such
  tag), whose `projects` contains the project. A request without `projects` is from
  before the workspace layout, and belongs to `legacy-project` in "Workflow
  settings". A request with `projects: []` changed workspace files only, and belongs
  to no release. Show each with its id, title, and type.
- The project commits by type (`feat`, `fix`, …), and every commit that has
  `BREAKING CHANGE:` in its body or `!` after its type
- Project changes made outside this workspace: by people who work on the project
  without it, or from another developer's own workspace. Project commits carry no
  request id, so find them through the requests: each closed request above names its
  project merge commits in the `Merged into develop` line of its `## Notes`
  (`<name> <short sha>`). On the first-parent line of the project's develop branch
  since the last tag (`git -C <path> log --first-parent --oneline <last
  tag>..<project develop-ref>`), every commit that is not one of those merge commits
  came from outside this workspace. For a closed request without that line (closed
  by hand), match the merge whose subject names its `project-branch`. Show these
  changes, because no request of this workspace describes them. They count for the
  version and the changelog like the requests.

## Step 3: Choose the version

Follow "Recommending the version" in [references/version.md](references/version.md).

- If `$ARGUMENTS` gives a version, validate it and use it. If it is invalid, say why
  and continue with the recommendation.
- Otherwise, recommend a version with the reason for it, and ask with AskUserQuestion.
  Put the recommended version first, and offer the other sensible candidates (for
  example a prerelease, or the next higher bump). The developer can type any other
  version through "Other".

The project tag is `v<version>`, the workspace tag `<name>/v<version>`, and the
branch `release/v<version>` in the project.

## Step 4: Create the release branch

```bash
git -C <path> checkout -b release/v<version> <project develop-ref>
git -C <path> push -u origin release/v<version>      # when pushing is allowed
```

The workspace shows ` M <path>` from now on, until the release is merged: the root
checkout is busy with this release.

## Step 5: Bring the release branch up to date

Run this step when the skill starts on an existing release branch. Directly after
Step 4, there is nothing to do here.

1. Check that `git -C <path> status --porcelain` is empty. With a remote, run
   `git -C <path> pull --ff-only`.
2. If the project's develop branch has commits that the release branch does not have
   (`git -C <path> log HEAD..<project develop-ref> --oneline`), show them. Ask whether
   to include them in this release. If yes, run `git -C <path> merge <project
   develop-ref>`, and resolve conflicts if there are any.

## Step 6: Check for unfinished work

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

If the "Unfinished" group is empty and there is no open hotfix, continue with Step 7.
Mention the "Not started" requests only as information: they do not block a release.

Otherwise, show both groups and ask the developer with AskUserQuestion:

| Option | Action |
|--------|--------|
| Release without them | Continue with Step 7. List these requests in the final report as "not part of this release". |
| Finish them first | Stop here. Explain the way back: put the project back at its gitlink (`git submodule update <path>`), finish the requests with `/ss-workflow:check-req`, `/ss-workflow:review`, and `/ss-workflow:merge`, then run `/ss-workflow:release <name>` again. It continues the open release branch, and Step 5 offers to include the new commits. |
| Cancel the release | Confirm it once more. Then put the project back (`git -C <path> checkout --detach <gitlink>`, or `git submodule update <path>`), delete the release branch (`git -C <path> branch -D release/v<version>`, and `git -C <path> push origin --delete` if it is on the remote and pushing is allowed), and stop. |

An open hotfix of the project must be merged before the release: point to
`/ss-workflow:merge`, and treat it like "Finish them first".

## Step 7: Set the version

Follow "Setting the version" in [references/version.md](references/version.md).

If something had to change, commit in the project and push:

```
chore(release): bump version to <version>
```

If nothing had to change, say that the version numbers already match.

## Step 8: Verify

Run the project's `build-command` and `test-command` on the release branch, in its
folder, plus `verify-command` if it is set. They must pass. These commands come from
the project's entry in "Workflow settings" and depend on its toolchain. A command that
is empty is skipped: tell the developer that this check is not configured, and ask
them to confirm that they checked the release build themselves. Report each command
with `passed`, `failed (<reason>)`, or `not configured`.

If another project of the workspace builds against this one (its "Project rules" or
build files refer to it), say so: its build uses the gitlink of this project, which
changes only when the workspace records the release.

If they fail, stop and report the failure. A fix for it is committed on the release
branch as a normal `fix:` commit, and only after the developer agrees. Then run this
step again.

## Step 9: Hand over to the merge

Continue directly with the release merge. Invoke the `ss-workflow:merge` skill for
this project's release branch. If you cannot invoke it, read
`${CLAUDE_PLUGIN_ROOT}/skills/merge/SKILL.md` and its `references/release.md`, and
follow them.

That skill asks the developer for the go-ahead, merges into the project's main branch
and develop branch, creates the project tag, records the release in the workspace
main branch with the workspace tag, asks again before each push of a main branch or a
tag (with `push-policy: never` it shows the push commands instead), and deletes the
release branch.

## Step 10: Report

After the merge skill finishes, add to its report, in `discussion-language`:

- The released project, its version, and both tags
- The requests in this release, grouped by type
- The requests of this project that are not part of this release (from Step 6)
- Project commits without a request, if Step 2 found any
- The checks of Step 8 that were not configured, and that the developer confirmed the
  release build themselves
- What is not on the remotes yet, with the commands that push it, per repository
- A reminder of anything the developer still does by hand, such as publishing a
  package or announcing the release
