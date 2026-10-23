---
name: merge
description: Close a reviewed request of an ss-workflow workspace by merging its project branches into the projects' develop branches and then the workspace branch into develop, or merge a project's release or hotfix into its main branch and develop with a tag and record it in the workspace main branch, following the gitflow rules of the workspace. Also finishes a merge that already happened on a remote (closes the request, deletes the branches) and closes a dropped request. Use when the developer says a request is reviewed and should be merged or closed, asks to merge a release or hotfix, or asks to clean up after a merge request was merged.
argument-hint: "[REQ-id | branch]"
---

# merge

Merge one request, release, or hotfix according to its kind, then clean up. For a
request, running this skill is the developer's sign-off: the request is closed.

Every merge has two layers. The projects are merged first, in their own repositories.
The workspace comes last, and records the result: the closed request and the
gitlinks of the projects' merge commits.

Input: `$ARGUMENTS` (optional `REQ-xxxx`, a workspace branch name, or
`<project> release/v…`)

| Kind | Projects | Workspace | Guide |
|------|----------|-----------|-------|
| Request (`feat/…`, `fix/…`, `docs/…`, …) | Each project branch into its `develop-branch` | The request branch into `develop` | [references/request.md](references/request.md) |
| Release `release/v…` of one project | Into its `main-branch` and `develop-branch`, tagged `v<version>` | `develop` into the main branch, tagged `<name>/v<version>` | [references/release.md](references/release.md) |
| Hotfix of one project | `hotfix/v…` into its `main-branch` and `develop-branch`, tagged `v<version>` | `hotfix/<name>-v…` into the main branch, tagged `<name>/v<version>`, and into `develop` | [references/hotfix.md](references/hotfix.md) |

A draft or a `ready` request is not merged here: its spec discussion or its
implementation is not finished.

## Ground rules

- Read the root `AGENTS.md` ("Workflow settings", "Working agreement", "Workspace and
  projects", "Branching model", "Commit convention"), `reqs/AGENTS.md`, and
  `projects/AGENTS.md` first. They are the source of truth.
- Talk to the developer in `discussion-language`.
- This skill runs in the root checkout of the workspace, not in a worktree. It
  switches the root checkout and its projects between the request branches, the
  develop branches, and the main branches, and leaves the workspace on `develop` with
  every project at its gitlink (`git submodule update`).
- A request or a hotfix must have the effective status `review`, or must already be
  closed on its workspace branch by an earlier run of this skill (merge pending). If
  it is `in-progress`, stop and point to `/ss-workflow:check-req`.
- If the request's `## Notes` has no passed Review, or no Verify result, say so. Say
  it too when the last Verify has a check that is `failed` or `did not run`, when a
  `### Behavior changes` item was not confirmed in the Review, or when `## Q&A` has a
  pending entry. Ask the developer whether to run `/ss-workflow:review` first, or to
  merge anyway. The developer may merge without a review, but must decide it
  knowingly: record the question and the answer in `## Q&A` (stage `review`), in the
  commit that closes the request.
- Always merge with `--no-ff`, so that every request, release, and hotfix stays visible
  as one merge commit in each repository. Never squash. Never rebase a pushed branch.
  Never force-push.
- **Settings per repository**: each project uses its entry's `remote-platform`,
  `remote-cli` (from the platform), `merge-method`, and `push-policy`, and the
  workspace values where the entry leaves them empty. The workspace uses its own.
- **Pushing**: follow "Remote and pushing" in the root `AGENTS.md`, per repository.
  Where this skill says "push", push only when that repository has a remote and its
  `push-policy` allows it: `auto` pushes, `ask` asks before the first push of this
  run, and `never` does not push. A missing `push-policy` means `auto`. Steps that
  fetch or pull apply only with a remote. When a push is skipped, go on, and list the
  unpushed branches in the report. Push a project before the workspace commit that
  records its gitlink.
- Pushing a main branch or a tag publishes a version. Ask right before that push,
  every time, also with `push-policy: auto`. With `push-policy: never`, do not push:
  show the command, and the developer runs it.
- Branch names: `<branch>` is the workspace branch of the request, and `<project
  branch>` is the request's `project-branch` in each of its projects. When
  `project-branch` is missing or empty (a request started before ss-workflow 0.8.0),
  the project branch has the name of the workspace branch.
- Merge commits use these messages, and are exempt from the `<type>(<scope>)` rule.
  In the workspace:

  ```
  Merge <source branch> into <target branch>

  <request title, or "Release <name> vX.Y.Z" / "Hotfix <name> vX.Y.Z">

  Refs: REQ-0012
  ```

  Leave out the `Refs:` line for a release. In a project:

  ```
  Merge <source branch> into <target branch>

  <one line in English that describes the change, or "Release vX.Y.Z" / "Hotfix vX.Y.Z">
  ```

  A project merge commit has no `Refs:` line and never names the request or the
  workspace (see "Workspace and projects" in the root `AGENTS.md`). Write the
  description from the request's spec in the project's terms: the request title may
  be in another language, or name things that only the workspace knows.
- A project's `setup-command`, `build-command`, `test-command`, and `verify-command`
  come from its entry in `projects`, run in its folder, and depend on its toolchain.
  Where a guide says to run them, a command that is empty is skipped: say that it is
  not configured, and do not invent one.
- If a merge has conflicts that are not trivial, show them and ask the developer how to
  resolve them. Do not guess at the intent of other people's changes. A conflict on a
  gitlink in the workspace is resolved by the rule of the guide, never by guessing:
  `git update-index --cacheinfo 160000,<sha>,<path>` with the commit that the guide
  names.

## Step 1: Preconditions and target

1. If the root `AGENTS.md` has no `ss-workflow-version:`, stop and point to
   `/ss-workflow:init`. If the version is below `0.6.0`, the repository has the
   single-repository layout: stop, and point to `/ss-workflow:init`, which converts
   it.
2. If this is a linked worktree or a project folder, stop. Explain that merges run in
   the root checkout of the workspace.
3. `git status --porcelain` must be empty. If it shows a project (` M <path>`), check
   `git -C <path> status --porcelain` and its branch: a project on the request branch
   of the target is expected (a review left it there), anything else is reported, and
   the skill stops.
4. If the workspace has a remote, run `git fetch --prune --tags`. For each project with
   a remote, run `git -C <path> fetch --prune --tags`.
5. Find the target:

| Situation | Target |
|-----------|--------|
| `$ARGUMENTS` is a `REQ-xxxx` id | The request: its workspace branch (the branch whose name contains `REQ-<id>-`, or the `hotfix/<name>-v*` branch that carries its file), and in each project of its `projects` the project branch that the request file on that workspace branch names |
| `$ARGUMENTS` is a workspace branch name | That branch |
| `$ARGUMENTS` names a project's `release/v…` branch, or the root checkout's project is on one | That release |
| The root checkout is on a request or `hotfix/*` branch | That branch |
| The root checkout is on `develop`, without arguments | List the candidates and ask: requests with the effective status `review` (say for each whether its Review passed), requests whose merge is pending on a remote, open `release/*` branches in the projects, and open `hotfix/*` branches. If the developer asks to bring a project's develop branch to its main branch without a release branch, see "Pre-1.0 sync" in [references/release.md](references/release.md). If there are no candidates, say so and stop. |
| The root checkout is on a request branch whose file says `draft` (a spec discussion), on a `req/*` branch from before ss-workflow 0.8.0, or on the main branch | Explain what the root checkout is busy with, and stop. |

6. If the root checkout is on another branch than the target and than `develop`, it is
   busy with something else. Say what, and stop.
7. Tell the developer what you are about to merge, and into what, in each repository,
   before you start.

## Step 2: Check the remote state

Do this for each repository of the target that has a remote: each project branch,
then the workspace branch.

First check git itself: if `git merge-base --is-ancestor <branch> origin/<target>`
succeeds (in a project: `git -C <path> merge-base --is-ancestor <project branch>
…`), that branch is already merged
on the remote, with or without a merge request. Its merge steps are done: the guide
continues with the next repository, or with "Finish" when the workspace is merged.

A run that stopped halfway shows here: projects merged while the workspace branch is
not. That is the normal state after a merge request in a project, or a protected
develop branch. The guide continues from where this check finds the work.

If the repository's `remote-platform` is not `none`, also look for a merge request of
the branch with its `remote-cli`, in its folder:

- GitHub: `gh pr view <branch> --json state,url,baseRefName,mergeCommit` (in a
  project: `<project branch>`)
- GitLab: `glab mr view <branch> --output json`

| Result | Action |
|--------|--------|
| Merged | The merge of that repository is done on the remote. Continue with the next repository of the guide. |
| Open | Show the URL. Ask whether to wait for the remote merge (stop here; the developer runs this skill again later), or to merge locally now (the push then closes the merge request). |
| Closed without merging | Show it. Ask whether to merge locally, to open a new merge request, or to stop. |
| None | Continue with Step 3. |

## Step 3: Choose the merge method

For each repository of the target, read its `merge-method`:

| Value | Action |
|-------|--------|
| `local` | Merge locally, then push. |
| `remote` | Open a merge request on the remote. If that repository's `remote-platform` is `none`, there is nothing to open it with: say so, and merge locally. |
| `ask`, or missing | If `remote-platform` is not `none`, ask the developer with AskUserQuestion: "Merge locally and push" or "Open a merge request on the remote". If there is no remote platform, merge locally. Ask once per repository. |

A merge request needs the branch on the remote, with all its commits. If the branch
is not pushed and you may not push it (`push-policy: never`, or the developer
declined), follow the "Prepare" section of the guide, then stop: say which branch the
developer has to push, and that running this skill again opens the merge request.

Without a remote, "Merge locally" is the whole merge of that repository: the steps
that pull and push are skipped, and the merge is confirmed on the local branches.

## Step 4: Follow the guide

Continue with the guide for the kind (the table at the top). Each guide has a
"Prepare" section, the merge of the projects, the merge of the workspace, and a
"Finish" section.

## Step 5: Clean up (shared by all guides)

Run this only after every merge is confirmed, either by
`git merge-base --is-ancestor <branch> <target>` for every target in every
repository, or by a merge request in the state "merged".

1. Switch the root checkout to `develop`, and run `git submodule update`.
2. **Leftover worktrees**: the worktrees of a request are normally removed when its
   implementation is finished. If `git worktree list` or `git -C <path> worktree list`
   still shows one for these branches, check that it has no uncommitted changes, and
   remove them in the order that "Workspace and projects" in the root `AGENTS.md`
   gives (the project worktrees first). If a folder is in use, tell the developer to
   close the programs that hold it, and continue.
3. **Local branches**: `git branch -d <branch>` in the workspace, and
   `git -C <path> branch -d <project branch>` in each project. If git refuses because a remote
   did a squash merge, and the merge request state is "merged", use `-D`.

   `git branch -d` is not a safety check. It also deletes a branch that is pushed but
   not merged, with only a warning, and in this workflow most branches are pushed. The
   confirmation at the start of this step is what protects the work, so never skip it.
4. **Remote branches**: if one still exists and pushing is allowed for that
   repository, `git push origin --delete <branch>` (in a project: `git -C <path>
   push origin --delete <project branch>`). Otherwise, leave it, and name it in the report as a branch that the
   developer can delete on the remote.
5. Run `git worktree prune` (and `git -C <path> worktree prune` for each project), and
   with a remote `git fetch --prune`.

If a target was merged locally and not pushed, the merge exists in this repository
only. Keep that in the report: the remote still shows the branch as it was.

## Step 6: Report

Tell the developer, in `discussion-language`:

- What was merged into what, per repository, the merge commits, and the tags
- That the request is closed, with its id and title
- What was pushed, and what is not on the remote yet: per repository, the branches and
  tags that the developer has to push, with the command
- What ran before the merge (build, tests, verify script, per project) and its result,
  what did not run and why, and what the developer accepted although it failed or did
  not run
- What was cleaned up, and anything that could not be removed
- That the root checkout is on `develop`
- The next step: other requests waiting for `/ss-workflow:review`,
  `/ss-workflow:check-req` for the next request, or `/ss-workflow:release <project>`
  when it is time to release a project

## Closing a dropped request

When the developer wants to close an approved request without merging its code (a
draft is discarded with `/ss-workflow:new-req` instead, and leaves no record):

1. Confirm it. Name the branches and the number of commits that will be abandoned, in
   the workspace (`git log develop..<branch> --oneline`) and in each project
   (`git -C <path> log <project develop-ref>..<project branch> --oneline`).
2. Record the closed request on `develop` through a short-lived branch, so that
   `develop` is only changed by a merge, and the request's other changes (code, docs)
   stay out:
   - `git checkout -b drop/REQ-<id> develop`
   - Take the latest request file from the workspace request branch
     (`git show <branch>:reqs/<file> > reqs/<file>`), so that its notes are kept. A
     request from before ss-workflow 0.8.0 may have its file on `develop` already.
   - Set `status: done`, and add a dated line to `## Notes` that says the request was
     dropped and why.
   - Add the question and the developer's answer to `## Q&A` (stage `review`): that
     the request is dropped, and why.
   - `git mv reqs/<file> reqs/done/<file>`, then commit `chore(reqs): drop REQ-0012`.
     The gitlinks do not change: no project code reaches `develop`.
   - Merge it into `develop` with `--no-ff`, push, and delete the `drop/REQ-<id>` branch.
3. Ask separately whether to delete the request branches, because their commits are
   not merged. Only after a clear yes, per branch: `git branch -D <branch>` (in a
   project: `git -C <path> branch -D <project branch>`), and delete the remote branch when
   pushing is allowed for that repository. Otherwise, keep the branches and say that
   they still exist.
