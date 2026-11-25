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

## Role

This skill has two roles, one after the other:

- **Engineering lead who reviews the request** (Steps 2 to 4b). You look at the
  requests from the lead's side: which one is next, whether the approved spec can be
  built as it is, and whether it is small enough and in the right order. You do not
  rewrite a spec that fails the review: it goes back to `/ss-workflow:new-req`.
- **Software engineer** (Step 5 on, and [references/implement.md](references/implement.md)).
  Once the lead lets the request start, you build exactly what the spec says in its
  worktrees. You decide only what "Left to the implementation" names, and ask about
  everything else.

## Ground rules

- Read the root `AGENTS.md` ("Workflow settings", "Working agreement", "Workspace and
  projects", "Branching model", "Commit convention"), `reqs/AGENTS.md`, and
  `projects/AGENTS.md` first. They are the source of truth. If they differ from this
  skill, follow them.
- Talk to the developer in `discussion-language`.
- One invocation handles one request. Never implement two requests in one worktree.
- A request is implemented only inside its own worktrees. This skill never changes
  files in the root checkout, and never switches the root checkout or its projects to
  another branch. The exceptions, each only after the developer approves:
  - switching the root checkout back to `develop` when it holds the branch of a
    request that is not in review, and `git submodule update <path>` to put a project
    of the root checkout back at its gitlink (see
    [references/anomalies.md](references/anomalies.md));
  - the commit on `develop` that updates a gitlink that is behind (Step 3), when the
    root checkout is on `develop` and clean.

  A repair that changes a request file on a request branch that no worktree holds is
  made in a temporary worktree of that branch (`git worktree add
  .claude/worktrees/<branch with "/" replaced by "-"> <branch>`), committed and pushed
  there, and the worktree is removed afterwards.
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
- Evidence, not guesses: a state that you report (an anomaly, a leftover worktree, the
  cause of a failed build) names the command and the output that show it. What you
  conclude without such evidence, say as inferred. In the implementation, follow
  `## Evidence` as [references/implement.md](references/implement.md) describes.
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
   each file in `reqs/` on `<develop-ref>` whose id has no request branch has the
   status that its file says, normally `ready` (`git ls-tree --name-only <develop-ref>
   reqs/`, then `git show <develop-ref>:<path>`). Any other status there is an
   anomaly: see [references/anomalies.md](references/anomalies.md).
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
   `/ss-workflow:review`. For a draft that a split created and that is not discussed
   yet (its `## Original` starts with `Split from:`, and its `## Spec` holds at most a
   `Depends on:` line), note "not discussed yet", the request it was split from, and
   its `Depends on:`; `/ss-workflow:new-req REQ-<id>` continues it. Below the table, list the projects whose gitlink is behind,
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
  - `ready`: use it, without asking again: naming it is the choice. Review it
    (Step 4b), then start it (Step 5).
  - `in-progress` with a worktree: ask whether to resume it there. If yes, continue
    with Step 6, using the worktree path.
  - `in-progress` without a worktree: the request was reopened by a review, or its
    worktree was lost. Ask whether to continue it. If yes, recreate the worktrees
    (see "Recreate the worktrees" below), and continue with Step 6. Git refuses this
    while the root checkout or one of its projects is on that branch: apply the repair
    from [references/anomalies.md](references/anomalies.md) first.
  - `review`: say that the implementation is finished, and point to
    `/ss-workflow:review`.
  - `done` (merge pending, or merged): say that the request is closed, and point to
    `/ss-workflow:merge` for a pending merge.
  - A draft: say that it needs approval through `/ss-workflow:new-req` first.
- No `$ARGUMENTS`: the candidates are every request that can be worked on now:
  - `ready`: start it (Step 4b, then Step 5).
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
   the line `Depends on: REQ-0011` at the start of "Scope" ("Request size" in
   `reqs/AGENTS.md`), or is stated in the spec ("Architecture", "Scope", or
   `## Notes`) in words, for example "SSDisp needs the new API of REQ-0011".
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

### Parallel start

With two or more `ready` candidates, also tell which of them can be implemented at the
same time, each in its own session. One session implements one request: the request
has its own branches and worktrees, so nothing is shared while it is built. Judge it
like this, without checking anything out (`git show <branch>:reqs/<file>`):

1. **Startable now**: every `Depends on:` request of the candidate (and every request
   that its spec names as needed, see rule 2 above) is `done`. A candidate that waits
   for a request that is not `done` is not part of any set: say "waits for REQ-0011".
   It builds on the code of that request, so it starts after the merge.
2. **Overlap** of two startable candidates, and of a startable candidate with every
   request that is `in-progress` or in `review` (their branches are not merged yet):
   - Different projects (their `projects` lists share no project) and no file of the
     workspace in common: independent.
   - Otherwise compare the paths in "File changes" of "Detailed design", per project
     and for workspace files. A path that both change is an overlap: name the
     requests, the project, and the paths.
   - A spec without a readable "File changes" gives "overlap unknown": say so, and do
     not call the pair independent.
3. **The set to start together**: go through the startable candidates in the order of
   "Recommend one", and take each one that overlaps with none already taken. The
   others stay candidates, with the overlap named.

Show it as a table below the candidates (id, startable or waiting for, overlaps with,
in the recommended set), and add one sentence: Verify, Review, and the merge run in the
root checkout one request at a time, so the finished requests queue up there.

An overlap is a warning, never a block: it may be harmless, and the developer knows the
code. The developer may start overlapping requests together. Describe an overlap by
what both requests change (the project and the paths, and for a new file that both add,
that both add it), and say that the merge may need conflict resolution. Do not say that
a conflict is certain, and do not advise to postpone, reorder, or combine the requests:
that is the developer's decision.

- No candidates: report this and mention the next useful action, such as drafts to
  finish, requests waiting for `/ss-workflow:review`, or `/ss-workflow:new-req`.
- One candidate: confirm it with the developer.
- Several candidates: ask with AskUserQuestion. Show the top three as options, the
  recommended one first with "(Recommended)" in its label. A `ready` request that
  waits for a request that is not `done` (see "Parallel start") is not an option: it
  stays in the table with what it waits for, and the developer can still name it
  through "Other". Each description says what
  choosing it does (start, resume, or recreate the worktrees) and why it has its
  place. When the recommended set has two or more requests, add the option "Start
  together: REQ-0011, REQ-0013" (naming them) after the first option. The developer
  can name any other request, or any other set of requests, through "Other".

The choice is the developer's answer: do not ask again whether to resume or to start
it. Continue with the action of the chosen candidate. For "Start together" or a set
that the developer named, this session takes the first request of the set, and the
others get a session of their own once this session has created the worktrees (end of
Step 5): see "Start the other requests of a set" there.

A request whose `projects` names a project that is not in "Workflow settings" cannot
be started: report it, and point to `/ss-workflow:new-req` to fix the request, or to
`/ss-workflow:init --add` to add the project.

## Step 4b: Lead review of the spec (a request that is about to start)

Do this for a `ready` request, before Step 5 creates anything. Skip it for an
`in-progress` request that you resume: its `## Notes` holds the review from its start,
and `### Lead review` only exists for requests that started after this step was added.

You are the engineering lead. The spec was approved, but you read it as the person who
will assign it: can it be built as written? Read the request file on its branch without
checking anything out (`git show <branch>:reqs/<file>`), and check:

1. **Complete**: every part of "Spec" in `reqs/AGENTS.md` is there, "Detailed design"
   has the sections that the request needs (a section without content says "None"; a
   spec approved before ss-workflow 0.13.0 is not faulted for a section that did not
   exist then), the sections that the project's skills require are there ("Project
   skills" in `reqs/AGENTS.md`), there is no program code, no word that leaves a
   decision open, and `## Q&A` has no pending entry. Judge substance, not form: a gap
   that no implementer could build differently, such as a one-line omission, is noted
   as a remark under "Result" and does not stop the start.
2. **Small enough**: compare the spec with "Request size" in `reqs/AGENTS.md`. A spec
   that mixes a must-fix with wishes, mixes types, or mixes cheap and expensive
   changes, or whose signals say that the Review would need more than one sitting, is
   too large.
3. **Ordered**: a `Depends on:` request is `done` (in `reqs/done/`, merged), or is
   started first. If a dependency is not done, say so and recommend it first.
4. **Evidence in order**: no entry that the spec cites is `to trace`; each `inferred`
   one has its `## Q&A` entry; each `to test` or `developer-stated` one has a check in
   "How to verify".
5. **Checkable**: each acceptance criterion can be ticked by a check that "How to
   verify" names, by Verify or by hand. A check by hand says its steps, its expected
   result, and how the result is observed (what the agent observes, and what only the
   developer sees or does). A missing observation is a remark under "Result", not a
   finding: the implementation summary adds it under "Review by hand".
6. **Overlap** (a remark, never a finding): compare "File changes" of the spec with
   the one of every other request that is `in-progress` or in `review`, as "Parallel
   start" in Step 4 describes (same project and path, or workspace file). Name each
   overlap with its request and paths in the result. It never fails the review, never
   stops the start, and never leads to a question: the developer sees it, and the
   merge resolves what really conflicts.

Show the result. No finding: record it (below) and go on to Step 5. With findings, ask
with AskUserQuestion:

| Option | Action |
|--------|--------|
| Send it back (Recommended) | Do not start. Say what to fix, and point to `/ss-workflow:new-req REQ-0012`, which reopens a `ready` request as a draft (for a request that is too large: to split it). Go back to Step 4 for another request. |
| Start anyway | The developer accepts the findings. Record each one as an entry in `## Q&A` (stage `implementation`) with the answer, and continue with Step 5. |
| Cancel | Stop without changing anything. |

Record the review in `## Notes` in the start commit of Step 5, so that nothing is
committed before the request starts:

```markdown
### Lead review (yyyy-MM-dd)
- Complete: passed
- Small enough: passed
- Ordered: passed (Depends on: REQ-0011, done)
- Evidence in order: passed
- Checkable: passed
- Overlap: none / REQ-0013 also changes SSLib `build.sh` (remark)
- Result: started / started anyway (findings accepted in Q4)
```

A failed check is written as `failed (<reason>)`.

## Step 5: Start the request and create the worktrees

Decide the names first:

| Item | Value |
|------|-------|
| Workspace branch | The request branch, which exists since the draft (`<type>/REQ-<id>-<slug>`). For `type: hotfix`: a new branch `hotfix/<name>-v<version>`, with the hotfix version from the first line of the spec's "Scope" part (`Hotfix: <name> v<released version> → v<hotfix version>`; in a spec written before ss-workflow 0.12.4, find the version in the spec's text, and ask when it is not there). For a `ready` request on `develop` from before ss-workflow 0.8.0: a new branch `<type>/REQ-<id>-<slug>`. |
| Project branch | `<type>/<slug>`, for example `feat/gui-button`, the same in each project of the request, with no request id. For `type: hotfix`: `hotfix/v<version>`. None for `projects: []`. A request that went back to `ready` may still name its kept project branch in `project-branch`: use that name. Step 1 below checks that the name is free. |
| Workspace base | Where the workspace branch starts: the workspace main branch for a hotfix (`origin/<main-branch>` with a remote), `<develop-ref>` otherwise. A new workspace branch is created from it. For the request branch that exists since the draft, it is only used in diffs (`<workspace base>...HEAD`), which start where the branch left `develop`. |
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
     The exception is a project branch that this request kept when it went back to
     `ready` (its `project-branch` names it, and `git -C <root>/<path> log <project
     develop-ref>..<project branch>` shows only this request's earlier work): it is
     reused, and step 4 creates its worktree without `-b`. Otherwise, propose another short, descriptive kebab-case name after the type (for example
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
     its draft branch first: `git checkout hotfix/REQ-<id>-<slug> -- reqs/<file>`
     (from `<develop-ref>` for a request from before 0.8.0). `git checkout` copies
     the file byte for byte; a shell redirection could change its encoding.
   - Set `status: in-progress`, `branch: <workspace branch>`, and
     `project-branch: <project branch>` in the request file (add the
     `project-branch:` line after `branch:` if the file has none; leave it empty for
     `projects: []`). Add the `### Lead review` entry of Step 4b to `## Notes`, and the
     `## Q&A` entries of findings that the developer accepted.
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

     A kept project branch that step 1 reuses gets its worktree without `-b`:
     `git -C <root>/<path> worktree add <worktree path>/<path> <project branch>`.
     Then bring it up to date with `<project base>` as Step 3.2 of
     [references/implement.md](references/implement.md) describes.

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
6. **Start the other requests of a set** (only after "Start together" or a set that
   the developer named in Step 4). One session implements one request, so each other
   request of the set gets a session of its own, started in the root checkout of the
   workspace (not in this worktree) with the prompt `/ss-workflow:check-req REQ-0013`:
   - If you can start a new session for the developer (for example through a tool of
     the app that you run in), start one for each other request, one after another,
     a few seconds apart.
   - Otherwise, give the developer the exact line `/ss-workflow:check-req REQ-0013`
     for each of them, and say to run each one in a new session in the root checkout.
   - Name the overlaps of the set again (Step 4, "Parallel start"), so that the
     developer knows where the merge may conflict.

   Two sessions may create branches or worktrees in the same repository at the same
   moment. When git reports a lock (`index.lock`, or "Unable to create ... .lock"),
   wait a few seconds and run the command again once. Never delete a lock file.

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
   project branch. Create a missing one as "Recreate the worktrees" in Step 5
   describes: its project branch exists already, so do not create a branch, and do
   not rename it. The names of the table at the top of Step 5 (`<workspace base>`,
   `<project base>`) hold in this step too, from the request's `type`.
4. Act on the status:

| Status | Action |
|--------|--------|
| `in-progress` | Resume. Find where the work stopped: `git status` in the workspace worktree and in each project, `git -C <path> log <project develop-ref>..HEAD --oneline` for each project, and `## Notes`, including review feedback if the request was reopened. Summarize it for the developer. Continue with [references/implement.md](references/implement.md) from its Step 2. |
| `review` or `done` | The implementation is finished, and these worktrees should no longer exist. Check that they have no uncommitted changes and no unpushed commits, then remove them as in Step 4 of [references/implement.md](references/implement.md). Point to `/ss-workflow:review` (for `review`) or `/ss-workflow:merge` (for `done`). |
| No request file, or `draft` / `ready` | This is an anomaly. See [references/anomalies.md](references/anomalies.md). |
