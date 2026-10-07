---
name: ss-workflow-release
description: Release a new version of an ss-workflow repository. On develop it recommends the next version number, creates the release branch, checks for unfinished requests and worktrees, sets the version number everywhere, and hands over to the release merge (main branch, develop, tag). On a release branch it continues a release that was started earlier. Use when the developer asks to release, publish, or cut a new version.
argument-hint: "[version, e.g. 1.2.0 or 1.0.0-beta1]"
---

# ss-workflow-release

Prepare a release on a `release/v<version>` branch, then hand it over to the release
merge rules of `/ss-workflow-merge`.

Input: `$ARGUMENTS` (optional version; skips the recommendation)

| Where | What it does |
|-------|--------------|
| `develop`, root checkout | Start a release: Steps 1 to 4, then continue with Step 5 |
| A `release/*` branch, root checkout | Continue the release from Step 5 |
| Anywhere else | The root checkout is busy with something else (a `req/*` branch means a spec discussion, a request branch means a review), or this is a worktree. Say which, and stop. |

Supporting file:

- [references/version.md](references/version.md): how to recommend the version, and
  where to set it

## Ground rules

- Read the root `AGENTS.md` ("Workflow settings", "Branching model", "Versioning",
  "Commit convention") and `reqs/AGENTS.md` first. They are the source of truth.
- Talk to the developer in `discussion-language`.
- A release branch has no worktree. Everything runs in the root checkout. If this
  session is inside a linked worktree, stop and say so.
- Only one release at a time. If a `release/*` branch already exists, continue that
  one. Do not start a second one.
- A release branch takes only release work: the version number, release notes, and
  fixes for problems that block the release. New features go through requests on
  `develop`.
- Never force-push. Never rebase a pushed branch.

## Step 1: Preconditions (on `develop`)

1. If the root `AGENTS.md` has no `ss-workflow-version:`, stop and point to
   `/ss-workflow-init`.
2. `git status --porcelain` must show no changes to tracked files. If it does, stop
   and report them.
3. If a remote exists, run `git fetch --prune --tags` and `git pull --ff-only`.
4. Look for an open release: `git branch -a --list "*release/*"`. If one exists, tell
   the developer, and ask whether to continue it (`git checkout release/<tag>`, then
   Step 5). Do not create another.
5. Find the last release tag on the main branch:
   `git describe --tags --abbrev=0 <main branch>`. There may be none yet.
6. Check that there is something to release: `git log <last tag>..develop --oneline`
   (without a tag: all commits on `develop`). If it is empty, say that `develop` has
   nothing new since the last release, and stop.

## Step 2: Show what the release contains

Summarize the changes since the last tag:

- The requests closed since then: the files added to `reqs/done/`
  (`git diff --name-only --diff-filter=A <last tag>..develop -- reqs/done/`), each
  with its id, title, and type
- The number of commits by type (`feat`, `fix`, …), and every commit that has
  `BREAKING CHANGE:` in its body or `!` after its type

## Step 3: Choose the version

Follow "Recommending the version" in [references/version.md](references/version.md).

- If `$ARGUMENTS` gives a version, validate it and use it. If it is invalid, say why
  and continue with the recommendation.
- Otherwise, recommend a version with the reason for it, and ask with AskUserQuestion.
  Put the recommended version first, and offer the other sensible candidates (for
  example a prerelease, or the next higher bump). The developer can type any other
  version through "Other".

The tag is `v<version>`. The branch is `release/v<version>`.

## Step 4: Create the release branch

```bash
git checkout -b release/v<version> develop
git push -u origin release/v<version>      # with a remote
```

## Step 5: Bring the release branch up to date

Run this step when the skill starts on an existing release branch. Directly after
Step 4, there is nothing to do here.

1. Check that `git status --porcelain` shows no changes to tracked files. With a
   remote, run `git fetch --prune --tags` and `git pull --ff-only`.
2. If `develop` has commits that the release branch does not have
   (`git log HEAD..develop --oneline`), show them. Ask whether to include them in this
   release. If yes, run `git merge develop`, and resolve conflicts if there are any.

## Step 6: Check for unfinished work

Collect the following:

- The requests in `reqs/` (not `reqs/done/`), with their effective status. Read the
  status of a claimed request from its request branch, as `/ss-workflow-check-req`
  does in its overview.
- The drafts: the `req/*` branches
- The worktrees from `git worktree list`, other than the root checkout
- Open `hotfix/*` branches

Sort them into two groups:

| Group | Requests |
|-------|----------|
| Unfinished | `in-progress` (being implemented in a worktree, or reopened), `review` (waiting for or under Verify and Review), and merge pending |
| Not started | Drafts on `req/*` branches, and `ready` requests |

If the "Unfinished" group is empty and there is no open hotfix, continue with Step 7.
Mention the "Not started" requests only as information: they do not block a release.

Otherwise, show both groups and ask the developer with AskUserQuestion:

| Option | Action |
|--------|--------|
| Release without them | Continue with Step 7. List these requests in the final report as "not part of this release". |
| Finish them first | Stop here. Explain the way back: switch the root checkout to `develop` (`git checkout develop`), finish the requests with `/ss-workflow-check-req`, `/ss-workflow-review`, and `/ss-workflow-merge`, then run `git checkout release/v<version>` and `/ss-workflow-release` again. Step 5 then offers to include the new commits. |
| Cancel the release | Confirm it once more. Then run `git checkout develop`, delete the release branch (`git branch -D`, and `git push origin --delete` with a remote), and stop. |

An open hotfix must be merged before the release: point to `/ss-workflow-merge`, and
treat it like "Finish them first".

## Step 7: Set the version

Follow "Setting the version" in [references/version.md](references/version.md).

If something had to change, commit and push:

```
chore(release): bump version to <version>
```

If nothing had to change, say that the version numbers already match.

## Step 8: Verify

Run `build-command` and `test-command` on the release branch. Both must pass.

If they fail, stop and report the failure. A fix for it is committed on the release
branch as a normal `fix:` commit, and only after the developer agrees. Then run this
step again.

## Step 9: Hand over to the merge

Continue directly with the release merge. Invoke the `ss-workflow-merge` skill for
this branch. If you cannot invoke it, read
`${CLAUDE_PLUGIN_ROOT}/skills/ss-workflow-merge/SKILL.md` and its
`references/release.md`, and follow them.

That skill asks the developer for the go-ahead, merges into the main branch and
`develop`, creates the tag, asks again before it pushes, and deletes the release
branch.

## Step 10: Report

After the merge skill finishes, add to its report, in `discussion-language`:

- The released version and its tag
- The requests in this release, grouped by type
- The requests that are not part of this release (from Step 6)
- A reminder of anything the developer still does by hand, such as publishing a
  package or announcing the release
