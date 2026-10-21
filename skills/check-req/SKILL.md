---
name: check-req
description: Check the state of all requests in an ss-workflow workspace, repair inconsistent ones, claim a ready request by creating its branches (in the workspace and in each project of the request) and worktrees, and implement it there. In a request worktree, resume the implementation. When the implementation is finished, it marks the request for review and removes the worktrees. Use when the developer asks what requests are pending, or wants to start or continue the implementation of a request.
argument-hint: "[REQ-id]"
---

# check-req

Where this skill runs decides what it does:

| Where | What it does |
|-------|--------------|
| The root checkout of the workspace, on any branch | Overview of all requests → repair anomalies → claim one `ready` request → implement it in new worktrees |
| A request worktree (the workspace worktree, or a project folder inside it) | Resume the implementation of that request |

Input: `$ARGUMENTS` (optional `REQ-xxxx` to pick a specific request)

This skill covers the implementation only. Verify and Review happen later in the root
checkout, when the developer runs `/ss-workflow:review`.

Supporting files:

- [references/anomalies.md](references/anomalies.md): inconsistent states and how to repair them
- [references/implement.md](references/implement.md): how to implement a request and hand it over

## Ground rules

- Read the root `AGENTS.md` ("Workflow settings", "Working agreement", "Workspace and
  projects", "Branching model", "Commit convention"), `reqs/AGENTS.md`, and
  `src/AGENTS.md` first. They are the source of truth. If they differ from this
  skill, follow them.
- Talk to the developer in `discussion-language`.
- One invocation handles one request. Never implement two requests in one worktree.
- A request is implemented only inside its own worktrees. This skill never changes
  files in the root checkout, and never switches the root checkout or its projects to
  another branch. The one exception is a repair that the developer approves:
  switching the root checkout back to `develop` when it holds the branch of a request
  that is not in review (see [references/anomalies.md](references/anomalies.md)).
- In a worktree, write code and try to compile it. Do not run tests, scripts, or
  executables there.
- Never force-push, and never rebase a branch that has been pushed.
- **Pushing**: follow "Remote and pushing" in the root `AGENTS.md`, for each
  repository on its own: the workspace with the workspace settings, and each project
  with its entry's `push-policy` (the workspace value when the entry leaves it
  empty). Where this skill says "push", push only when that repository has a remote
  and its `push-policy` allows it: `auto` pushes, `ask` asks before the first push of
  this run, and `never` does not push. A missing `push-policy` means `auto`. Steps
  that fetch or pull apply only with a remote. When a push is skipped, go on, and
  list the unpushed branches in the report.
- Report results as they are: what ran and passed, what ran and failed, and what did
  not run and why. Nothing that did not run is reported as passed.
- Do not take over an `in-progress` request without asking: another session may be
  working on it.

## Step 1: Find out where you are

1. If the root `AGENTS.md` has no `ss-workflow-version:`, stop and point to
   `/ss-workflow:init`. If the version is below `0.6.0`, the repository has the
   single-repository layout: stop, and point to `/ss-workflow:init`, which converts
   it.
2. Collect the following:
   - `git branch --show-current`
   - `git rev-parse --show-toplevel --git-dir --git-common-dir`. Inside a project
     folder, `--show-superproject-working-tree` gives the workspace (worktree) that
     holds it: continue from there. If the workspace's git dir and common dir differ,
     this is a linked worktree.
   - `git worktree list --porcelain`. The first entry is the root checkout.
   - For each project in `projects`: `git -C <root>/<path> worktree list --porcelain`.
3. If the workspace has a remote, run `git fetch --prune`. For each project with a
   remote, run `git -C <root>/<path> fetch --prune`.
4. Choose the ref that stands for `develop` in this run, called `<develop-ref>` below.
   Choose it the same way for each project, with its `develop-branch`, called
   `<project develop-ref>`:

   | Situation | `<develop-ref>` |
   |-----------|-----------------|
   | No remote | `develop` |
   | A remote, and the local `develop` has no commits of its own (`git log origin/develop..develop --oneline` is empty) | `origin/develop` |
   | A remote, and the local `develop` is ahead of `origin/develop` | `develop`. Tell the developer that other machines cannot see those requests (or commits) until `develop` is pushed. |
   | A remote, and both have commits that the other one lacks | `develop`, and also read the requests that only `origin/develop` has. Tell the developer that `develop` has to be brought together with the remote (`git pull` on `develop`), and do not claim a request that only one side has. |

   In a project's submodule, the local develop branch may not exist yet; then the
   project's `<project develop-ref>` is `origin/<develop-branch>`.
5. Route:
   - A linked worktree → **Step 6**.
   - The root checkout → **Step 2**. The root checkout may be on any branch: this
     skill reads `develop` through `<develop-ref>` and does not need it checked out.

## Step 2: Overview

Build the list of requests without checking anything out.

1. **Drafts**: each `req/REQ-…` branch of the workspace, local or remote. Read the
   title from its request file (`git show <branch>:reqs/<file>`).
2. **Approved requests**: each file in `reqs/` on `<develop-ref>`
   (`git ls-tree --name-only <develop-ref> reqs/`, then `git show <develop-ref>:<path>`).
3. **The request branches** of each approved request:
   - In the workspace: a local or remote branch whose name contains `REQ-<id>-` and
     does not start with `req/`. For `type: hotfix`: a `hotfix/<name>-v*` branch that
     contains the request file in `reqs/` or `reqs/done/`.
   - In each project of its `projects`: the branch with the same name, local or
     remote (for a hotfix: `hotfix/v<version>`).
4. **The effective status**:
   - No workspace request branch: the status on `<develop-ref>`, normally `ready`.
   - With a workspace request branch: the status in the request file on that branch
     (`in-progress`, `review`, or `done`). `done` on a branch that is not merged means
     "merge pending".
5. For each request branch, in the workspace and in each project, also collect:
   - whether it exists locally, on the remote, or both
   - its worktree path, from the worktree lists of Step 1
   - whether the root checkout (or the project in it) is on it
   - with a remote, the unpushed commits: `git log origin/<branch>..<branch> --oneline`,
     or that the branch is not on the remote at all
   - whether it is merged: `git merge-base --is-ancestor <branch> <develop-ref>` (in
     a project, against `<project develop-ref>`)
6. **Gitlinks behind**: for each project, the commits that `develop`'s gitlink lacks:
   `git -C <root>/<path> rev-list --count $(git rev-parse <develop-ref>:<path>)..<project develop-ref>`.
7. Show a table sorted by status, then priority, then id:

   | ID | Title | Type | Projects | Priority | Status | Branches / worktree | Notes |
   |----|-------|------|----------|----------|--------|---------------------|-------|

   Put anomalies in the Notes column. For `review` requests, note that they wait for
   `/ss-workflow:review`. Below the table, list the projects whose gitlink is behind,
   with the number of commits.

## Step 3: Repair anomalies

Compare what you collected with [references/anomalies.md](references/anomalies.md). If
there are anomalies, list them with the proposed repair for each, and ask the developer
which ones to apply. Apply the approved repairs before you claim anything.

If the developer declines a repair, continue, but do not claim the request it affects.

A gitlink that is behind is not an anomaly of a request. Offer the update that
"Workspace and projects" in the root `AGENTS.md` describes, but only when the root
checkout is on `develop` and clean; otherwise only report it. The claim does not need
it: project branches start from the project's latest develop branch anyway.

## Step 4: Choose a request

Candidates are the requests with the effective status `ready`, sorted by `priority`
(`high` > `normal` > `low`), then by id.

- `$ARGUMENTS` names a request:
  - `ready`: use it.
  - `in-progress` with a worktree: ask whether to resume it there. If yes, continue
    with Step 6, using the worktree path.
  - `in-progress` without a worktree: the request was reopened by a review, or its
    worktree was lost. Ask whether to continue it. If yes, recreate the worktrees
    (see "Recreate the worktrees" below), and continue with Step 6. Git refuses this
    while the root checkout or one of its projects is on that branch: apply the repair
    from [references/anomalies.md](references/anomalies.md) first.
  - `review`: say that the implementation is finished, and point to
    `/ss-workflow:review`.
  - A draft: say that it needs approval through `/ss-workflow:new-req` first.
- No candidates: report this and mention the next useful action, such as drafts to
  finish, requests waiting for `/ss-workflow:review`, or `/ss-workflow:new-req`.
- One candidate: confirm it with the developer.
- Several candidates: ask with AskUserQuestion. Show the top three as options, with the
  recommended one first. The developer can name any other request through "Other".

A request whose `projects` names a project that is not in "Workflow settings" cannot
be claimed: report it, and point to `/ss-workflow:new-req` to fix the request, or to
`/ss-workflow:init --add` to add the project.

## Step 5: Claim and create the worktrees

Decide the names first:

| Item | Value |
|------|-------|
| Branch | `<type>/REQ-<id>-<slug>`, for example `feat/REQ-0012-gui-button`, in the workspace and in each project. For `type: hotfix`: `hotfix/<name>-v<version>` in the workspace and `hotfix/v<version>` in the project, with the version from the request's spec. |
| Workspace base | `<develop-ref>`. For `type: hotfix`: the workspace main branch (`origin/<main branch>` with a remote). |
| Project base | `<project develop-ref>`, the latest develop branch of the project (not the gitlink). For `type: hotfix`: the project's main branch (`origin/<main-branch>` with a remote). |
| Worktree path | `<root checkout>/.claude/worktrees/<workspace branch with "/" replaced by "-">`, with each project at its `path` inside it |

Creating the workspace branch is the claim.

- In one repository, git creates a branch name only once, so two local sessions
  cannot both succeed at step 2. This needs no remote.
- Across machines, pushing the branch does not decide it yet: two machines can both
  push the same starting commit, and the remote accepts both. The push of the claim
  commit in step 4 decides, because the remote accepts only the first one.
- When nothing is pushed (no remote, `push-policy: never`, or the developer declined),
  the claim holds in this repository only. Say so. If a later push of this branch is
  rejected because another machine claimed the request in the meantime, do not force
  anything: show both branches to the developer, who decides which claim stands.
- The project branches are created only after the claim holds (step 5), so a lost
  claim leaves nothing in the projects.
- A request with `projects: []` changes workspace files only. It gets the workspace
  branch and no project branch: step 1 checks the workspace only, and step 5 creates
  the detached project worktrees only.

1. **Check the remotes first**:
   - Workspace: `git ls-remote --heads origin "*REQ-<id>-*"` (for a hotfix:
     `hotfix/<name>-v<version>`). If it lists a branch other than a `req/` branch, the
     request is already claimed. Go back to Step 4.
   - Each project of the request: `git -C <root>/<path> ls-remote --heads origin
     <branch>`. A branch there without a workspace branch is an anomaly: see
     [references/anomalies.md](references/anomalies.md) before you continue.
2. **Create the workspace branch and worktree** in one command:

   ```bash
   git worktree add --no-track -b <branch> <worktree path> <workspace base>
   ```

   If git says that the branch already exists, another session claimed the request.
   Tell the developer, and go back to Step 4.
3. **Publish the branch** when pushing is allowed:

   ```bash
   git -C <worktree path> push -u origin <branch>
   ```

   If the remote rejects this push, or the push of the claim commit in the next step,
   another machine claimed the request at the same time. Remove the worktree and the
   local branch (`git worktree remove <worktree path>`, `git branch -D <branch>`),
   tell the developer, and go back to Step 4.
4. **Record the claim** as the first commit on the workspace branch, in the worktree:
   - For `type: hotfix`, the request file is not on this branch yet. Copy it first:
     `git show <develop-ref>:reqs/<file> > reqs/<file>`.
   - Set `status: in-progress` and `branch: <workspace branch>` in the request file.
   - Commit and push:

     ```
     chore(reqs): claim REQ-0012

     Refs: REQ-0012
     ```

5. **Create the project worktrees** inside the workspace worktree, from the root
   checkout's submodules:
   - Each project of the request, with its branch:

     ```bash
     git -C <root>/<path> worktree add --no-track -b <project branch> <worktree path>/<path> <project base>
     git -C <worktree path>/<path> push -u origin <project branch>     # when pushing is allowed for that project
     ```

   - Every other project, detached at the gitlink of the workspace branch, because a
     build may refer to it, and the docs of a workspace-only request may describe it:

     ```bash
     git -C <root>/<path> worktree add --detach <worktree path>/<path> $(git -C <worktree path> rev-parse HEAD:<path>)
     ```

   - Nested submodules of a project: `git -C <worktree path>/<path> submodule update
     --init --recursive`.
   - If the root checkout's submodule of a project is not initialized, run
     `git -C <root> submodule update --init <path>` first. If the root checkout's
     project is on the project branch itself (an anomaly), git refuses the worktree:
     apply the repair from [references/anomalies.md](references/anomalies.md).
6. Tell the developer the worktree path, the branches, and whether the claim and the
   project branches are on the remotes.

From here on, every file path and every command belongs to the worktree. Continue with
[references/implement.md](references/implement.md).

### Recreate the worktrees

For an `in-progress` request without a worktree:

```bash
git worktree add <worktree path> <workspace branch>
git -C <root>/<path> worktree add <worktree path>/<path> <project branch>      # each project of the request
git -C <root>/<path> worktree add --detach <worktree path>/<path> <gitlink>   # every other project
```

Use the local branches if they exist, or `origin/<branch>` (git then creates the
local branch with tracking). A project branch that is missing for a project of the
request is an anomaly: see [references/anomalies.md](references/anomalies.md).

## Step 6: In a request worktree

1. Identify the request: the file in `reqs/` of the workspace worktree whose `branch`
   equals the workspace worktree's branch.
2. If a remote exists, run `git pull --ff-only` on the workspace branch, and on each
   project branch of the request whose project has a remote.
3. Check that each project of the request has its worktree at `<path>`, on its
   project branch. Create a missing one as in Step 5.5.
4. Act on the status:

| Status | Action |
|--------|--------|
| `in-progress` | Resume. Find where the work stopped: `git status` in the workspace worktree and in each project, `git -C <path> log <project develop-ref>..HEAD --oneline` for each project, and `## Notes`, including review feedback if the request was reopened. Summarize it for the developer. Continue with [references/implement.md](references/implement.md) from its Step 2. |
| `review` or `done` | The implementation is finished, and these worktrees should no longer exist. Check that they have no uncommitted changes and no unpushed commits, then remove them as in Step 4 of [references/implement.md](references/implement.md). Point to `/ss-workflow:review` (for `review`) or `/ss-workflow:merge` (for `done`). |
| No request file, or `draft` / `ready` | This is an anomaly. See [references/anomalies.md](references/anomalies.md). |
