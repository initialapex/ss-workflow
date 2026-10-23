---
name: check-req
description: Check the state of all requests in an ss-workflow workspace, repair inconsistent ones, recommend which request to work on next, resume an in-progress request in its worktree, or start a ready request by creating its branches (in the workspace and in each project of the request) and worktrees, and implement it there. In a request worktree, resume the implementation. When the implementation is finished, it marks the request for review and removes the worktrees. Use when the developer asks what requests are pending, or wants to start or continue the implementation of a request.
argument-hint: "[REQ-id]"
---

# check-req

Where this skill runs decides what it does:

| Where | What it does |
|-------|--------------|
| The root checkout of the workspace, on any branch | Overview of all requests → repair anomalies → recommend which request to work on, then start a `ready` one or resume an `in-progress` one → implement it in its worktrees. With a request id (for example from `/ss-workflow:new-req` right after the approval), only that request is checked and started. |
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
  `projects/AGENTS.md` first. They are the source of truth. If they differ from this
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
   | A remote, and both have commits that the other one lacks | `develop`, and also read the requests that only `origin/develop` has. Tell the developer that `develop` has to be brought together with the remote (`git pull` on `develop`), and do not start a request that only one side has. |

   In a project's submodule, the local develop branch may not exist yet; then the
   project's `<project develop-ref>` is `origin/<develop-branch>`.
5. Route:
   - A linked worktree → **Step 6**.
   - The root checkout → **Step 2**. The root checkout may be on any branch: this
     skill reads `develop` through `<develop-ref>` and does not need it checked out.

## Step 2: Overview

Build the list of requests without checking anything out. When `$ARGUMENTS` names a
request, collect that request only, skip the table, and check only its anomalies in
Step 3.

1. **Requests on their branches**: each workspace branch, local or remote, whose name
   contains `REQ-<id>-` (for example `feat/REQ-0012-gui-button`, or
   `hotfix/REQ-0013-fix-crash` for a hotfix that is not started yet), and each
   `hotfix/<name>-v*` branch, which carries its request file. Read the request file on
   the branch (`git ls-tree --name-only <branch> reqs/ reqs/done/`, then `git show
   <branch>:<path>`). Use the local branch when it exists, and the remote one
   otherwise. Its `status` is the effective status: `draft`, `ready`, `in-progress`,
   `review`, or `done`. `done` on a branch that is not merged means "merge pending".
2. **Requests from before ss-workflow 0.8.0**: each `req/REQ-…` branch is a draft, and
   each file in `reqs/` on `<develop-ref>` whose id has no request branch is `ready`
   (`git ls-tree --name-only <develop-ref> reqs/`, then `git show <develop-ref>:<path>`).
   A file in `reqs/` on `<develop-ref>` whose id has a request branch is the old copy:
   the branch holds the status.
3. **The project branches** of each request that is started: in each project of its
   `projects`, the branch named in `project-branch` of the request file on the
   workspace branch, local or remote. If the field is missing or empty, the request
   was started before ss-workflow 0.8.0, and the project branch has the name of the
   workspace branch (for a hotfix: `hotfix/v<version>`). A project branch is never
   found by its name alone: other developers create branches in the same projects
   from their own workspaces.
4. For each request branch, in the workspace and in each project, also collect:
   - whether it exists locally, on the remote, or both
   - its worktree path, from the worktree lists of Step 1
   - whether the root checkout (or the project in it) is on it
   - with a remote, the unpushed commits: `git log origin/<branch>..<branch> --oneline`,
     or that the branch is not on the remote at all
   - whether it is merged: `git merge-base --is-ancestor <branch> <develop-ref>` (in
     a project, against `<project develop-ref>`)
5. **Gitlinks behind**: for each project, the commits that `develop`'s gitlink lacks:
   `git -C <root>/<path> rev-list --count $(git rev-parse <develop-ref>:<path>)..<project develop-ref>`.
6. Show a table sorted by status, then priority, then id:

   | ID | Title | Type | Projects | Priority | Status | Branches / worktree | Notes |
   |----|-------|------|----------|----------|--------|---------------------|-------|

   Put anomalies in the Notes column. For `review` requests, note that they wait for
   `/ss-workflow:review`. Below the table, list the projects whose gitlink is behind,
   with the number of commits.

## Step 3: Repair anomalies

Compare what you collected with [references/anomalies.md](references/anomalies.md). If
there are anomalies, list them with the proposed repair for each, and ask the developer
which ones to apply. Apply the approved repairs before you start anything.

If the developer declines a repair, continue, but do not start the request it affects.

A gitlink that is behind is not an anomaly of a request. Offer the update that
"Workspace and projects" in the root `AGENTS.md` describes, but only when the root
checkout is on `develop` and clean; otherwise only report it. Starting does not need
it: project branches start from the project's latest develop branch anyway.

## Step 4: Choose a request

- `$ARGUMENTS` names a request:
  - `ready`: use it, without asking again: naming it is the choice.
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
- No `$ARGUMENTS`: the candidates are every request that can be worked on now:
  - `ready`: start it (Step 5).
  - `in-progress` with a worktree: resume it there (Step 6, with the worktree path).
  - `in-progress` without a worktree: recreate the worktrees ("Recreate the
    worktrees" below), then Step 6.

  Leave out an `in-progress` request that was started on another machine (its branch
  exists only on the remote, or the remote has start or implementation commits that
  this repository lacks): show it in the overview only, because someone else may be
  working on it.

### Recommend one

Sort the candidates by these rules, the first rule that tells two apart decides:

1. `type: hotfix` first: it fixes a released version.
2. A request that another candidate depends on comes before it. A dependency is
   stated in the spec ("Architecture", "Scope", or `## Notes`), for example "SSDisp
   needs the new API of REQ-0011".
3. `priority`: `high` > `normal` > `low`.
4. `in-progress` before `ready`: finish what was started before something new. Its
   branches already exist and drift further from the develop branches every day.
5. Among `in-progress`: one that a review sent back for rework (`## Notes` has a
   `### Review` entry with findings) first, because the developer is waiting for it;
   then one with a worktree, which resumes without any setup.
6. The lower id: the older request.

Show the candidates as a table in this order (id, title, type, priority, status,
what choosing it does, and the reason for its place), and say in one sentence why the
first one is recommended. Mark a candidate whose worktree has uncommitted changes as
"may be in use by another session": choosing it anyway is the developer's decision.

- No candidates: report this and mention the next useful action, such as drafts to
  finish, requests waiting for `/ss-workflow:review`, or `/ss-workflow:new-req`.
- One candidate: confirm it with the developer.
- Several candidates: ask with AskUserQuestion. Show the top three as options, the
  recommended one first with "(Recommended)" in its label. Each description says what
  choosing it does (start, resume, or recreate the worktrees) and why it has its
  place. The developer can name any other request through "Other".

The choice is the developer's answer: do not ask again whether to resume or to start
it. Continue with the action of the chosen candidate.

A request whose `projects` names a project that is not in "Workflow settings" cannot
be started: report it, and point to `/ss-workflow:new-req` to fix the request, or to
`/ss-workflow:init --add` to add the project.

## Step 5: Start the request and create the worktrees

Decide the names first:

| Item | Value |
|------|-------|
| Workspace branch | The request branch, which exists since the draft (`<type>/REQ-<id>-<slug>`). For `type: hotfix`: a new branch `hotfix/<name>-v<version>`, with the version from the request's spec. For a `ready` request on `develop` from before ss-workflow 0.8.0: a new branch `<type>/REQ-<id>-<slug>`. |
| Project branch | `<type>/<slug>`, for example `feat/gui-button`, the same in each project of the request, with no request id. For `type: hotfix`: `hotfix/v<version>`. None for `projects: []`. Step 1 checks that the name is free. |
| Workspace base | Only for a new workspace branch: the workspace main branch for a hotfix (`origin/<main branch>` with a remote), `<develop-ref>` otherwise. |
| Project base | `<project develop-ref>`, the latest develop branch of the project (not the gitlink). For `type: hotfix`: the project's main branch (`origin/<main-branch>` with a remote). |
| Worktree path | `<root checkout>/.claude/worktrees/<workspace branch with "/" replaced by "-">`, with each project at its `path` inside it |

Starting needs no lock. The request branch exists since the draft, and its status
says whether the work has started. Each developer usually has a workspace of their
own; when one workspace is shared through its remote, a pushed `in-progress` shows
the others that the request is taken.

A request with `projects: []` changes workspace files only. It gets no project branch:
step 1 checks the workspace only, and step 4 creates the detached project worktrees
only.

1. **Check before you start**:
   - The root checkout is not on the request branch, and no worktree holds it
     (`git worktree list`). `/ss-workflow:new-req` switches the root checkout back to
     `develop` before it hands over. If another worktree holds the branch, another
     session works on the request: go back to Step 4.
   - With a remote: if `origin/<branch>` has commits that the local branch lacks,
     bring them in with `git branch -f <branch> origin/<branch>` when the local
     branch has no commits of its own (otherwise stop and show both). If the request
     file there says `in-progress` already, it was started on another machine: ask
     the developer before you continue.
   - Each project of the request: the project branch must not exist yet, locally
     (`git -C <root>/<path> rev-parse --verify -q refs/heads/<project branch>`) or on
     the remote (`git -C <root>/<path> ls-remote --heads origin <project branch>`).
     A branch with that name belongs to someone else's work, not to this request.
     Propose another short, descriptive kebab-case name after the type (for example
     `feat/gui-button-color`), check it the same way in every project of the
     request, and ask the developer to confirm it. For a hotfix, a taken
     `hotfix/v<version>` means that the version is being fixed already: stop, and
     tell the developer.
2. **Create the workspace worktree**:

   ```bash
   git worktree add <worktree path> <branch>                                  # the request branch
   git worktree add --no-track -b <branch> <worktree path> <workspace base>   # a new branch: hotfix, or a ready request from before 0.8.0
   ```

   If the request branch exists only on the remote, create the local branch first:
   `git branch --track <branch> origin/<branch>`.
3. **Record the start** as a commit on the workspace branch, in the worktree:
   - For `type: hotfix`, the request file is not on the new branch yet. Copy it from
     its draft branch first: `git show hotfix/REQ-<id>-<slug>:reqs/<file> >
     reqs/<file>` (from `<develop-ref>` for a request from before 0.8.0).
   - Set `status: in-progress`, `branch: <workspace branch>`, and
     `project-branch: <project branch>` in the request file (add the
     `project-branch:` line after `branch:` if the file has none; leave it empty for
     `projects: []`).
   - Commit and push (`git push -u origin <branch>` for a new branch):

     ```
     chore(reqs): start REQ-0012

     Refs: REQ-0012
     ```

   - If the remote rejects the push because its branch has commits that this one
     lacks, the request changed on another machine. Do not force anything: remove
     the worktree, show both sides to the developer, and stop.
   - For a hotfix: once this commit exists, delete the draft branch
     `hotfix/REQ-<id>-<slug>` (`git branch -D`, and on the remote when pushing is
     allowed). The request file on the new branch replaces it.
4. **Create the project worktrees** inside the workspace worktree, from the root
   checkout's submodules:
   - Each project of the request, with its branch:

     ```bash
     git -C <root>/<path> worktree add --no-track -b <project branch> <worktree path>/<path> <project base>
     git -C <worktree path>/<path> push -u origin <project branch>     # when pushing is allowed for that project
     ```

     If git says that the branch already exists, or the remote rejects the push
     because the branch appeared there in the meantime, the name was taken after
     step 1. Remove the project worktrees that you created for this request and
     their branches (they have no commits yet), pick a new name as in step 1, set it
     in `project-branch` with a commit `chore(reqs): rename the project branch of
     REQ-0012`, and create the project worktrees again.

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
5. Tell the developer the worktree path, the branches, and whether the start commit
   and the project branches are on the remotes.

From here on, every file path and every command belongs to the worktree. Continue with
[references/implement.md](references/implement.md).

### Recreate the worktrees

For an `in-progress` request without a worktree:

```bash
git worktree add <worktree path> <workspace branch>
git -C <root>/<path> worktree add <worktree path>/<path> <project branch>      # each project of the request
git -C <root>/<path> worktree add --detach <worktree path>/<path> <gitlink>   # every other project
```

The project branch is the request's `project-branch` (or, when that is empty, the
name of the workspace branch). Use the local branches if they exist, or
`origin/<branch>` (git then creates the local branch with tracking). A project branch that is missing for a project of the
request is an anomaly: see [references/anomalies.md](references/anomalies.md).

## Step 6: In a request worktree

1. Identify the request: the file in `reqs/` of the workspace worktree whose `branch`
   equals the workspace worktree's branch.
2. If a remote exists, run `git pull --ff-only` on the workspace branch, and on each
   project branch of the request whose project has a remote.
3. Check that each project of the request has its worktree at `<path>`, on its
   project branch. Create a missing one as in Step 5.4.
4. Act on the status:

| Status | Action |
|--------|--------|
| `in-progress` | Resume. Find where the work stopped: `git status` in the workspace worktree and in each project, `git -C <path> log <project develop-ref>..HEAD --oneline` for each project, and `## Notes`, including review feedback if the request was reopened. Summarize it for the developer. Continue with [references/implement.md](references/implement.md) from its Step 2. |
| `review` or `done` | The implementation is finished, and these worktrees should no longer exist. Check that they have no uncommitted changes and no unpushed commits, then remove them as in Step 4 of [references/implement.md](references/implement.md). Point to `/ss-workflow:review` (for `review`) or `/ss-workflow:merge` (for `done`). |
| No request file, or `draft` / `ready` | This is an anomaly. See [references/anomalies.md](references/anomalies.md). |
