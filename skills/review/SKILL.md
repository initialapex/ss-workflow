---
name: review
description: Verify and review an implemented request of an ss-workflow workspace in the root checkout. Checks out the request branches of the workspace and of each project of the request, runs the build, the tests and the verification scripts (Verify), offers a code review of the request's changes, then guides the developer through the manual check (Review), applies small fixes, or sends the request back for rework. Use when the developer wants to start, continue, or finish the review of a request that is waiting in the review status.
argument-hint: "[REQ-id]"
---

# review

Verify and review one request in the root checkout of the workspace, on its request
branches: the workspace request branch, and the request's `project-branch` in each
project of the request (for a hotfix, `hotfix/v<version>` in its project). A request
claimed before ss-workflow 0.8.0 has no `project-branch`: its project branches have
the name of the workspace branch.

- **Verify**: you run the build, the test projects, and the verification scripts.
- **Code review** (optional): if the developer wants it, the `code-review` skill reads
  the request's changes for bugs.
- **Review**: the developer checks the result by hand, and you guide them.

The request is closed later, when the developer runs `/ss-workflow:merge`. This skill
never merges. In one case it hands over to that skill: when the developer chooses to
merge from an undefined state (Step 1).

Input: `$ARGUMENTS` (optional `REQ-xxxx`)

## Ground rules

- Read the root `AGENTS.md` ("Workflow settings", "Working agreement", "Workspace and
  projects", "Commit convention"), `reqs/AGENTS.md`, and the sections of the
  request's projects in `src/AGENTS.md` first. They are the source of truth.
- Code is committed in the projects, on their project branches, as commits written
  for the project's own history: no request id, no workspace name, and no `Refs:`
  footer that points to the workspace. The workspace request branch gets the request
  file and the gitlinks, and the request's changes to workspace files (docs, README
  files, agent files outside their managed blocks), with `Refs: REQ-xxxx`.
- Changes to workspace files are not built, tested, or code-reviewed. The developer
  reads each of them in the Review (Step 6).
- Talk to the developer in `discussion-language`.
- This skill runs in the root checkout, not in a worktree. Tests, scripts, and
  executables run here, not in worktrees.
- Review one request at a time. The root checkout stays on the request branch while
  the review is open.
- Report results as they are. Every check is recorded and reported as exactly one of
  `passed`, `failed` (with the reason), `did not run` (with the reason), or
  `not configured`. A failed or skipped check is never recorded as passed, whatever
  its cause, and a check is `passed` only when you ran it in this review and saw it
  pass. Do not carry a result over from the implementation summary or from an earlier
  run without saying so.
- Only the developer decides that the Review passed.
- A question to the developer whose answer decides how a result is judged, or changes
  the spec, goes into `## Q&A` with the stage `review`, as "Questions and answers" in
  `reqs/AGENTS.md` describes: for example whether a failed check is accepted, or
  whether a finding is left as it is. If the file has no `## Q&A` section yet (an
  older request), add it between `## Original` and `## Notes`.
- What passes must be what is committed. A Verify result counts only when it ran on a
  working tree without uncommitted changes (see "Uncommitted changes").
- A commit that records a result stages only the request file and the gitlinks of
  the request's projects (`git add reqs/<file> <path>...`), so that the workspace
  records which project commits the result is about. Do not use `git add -A` or
  `git commit -a` for it.
- Never force-push, and never rebase a pushed branch.
- **Pushing**: follow "Remote and pushing" in the root `AGENTS.md`, for each
  repository on its own: the workspace with the workspace settings, each project with
  its entry's `push-policy` (the workspace value when the entry leaves it empty).
  Where this skill says "push", push only when that repository has a remote and its
  `push-policy` allows it: `auto` pushes, `ask` asks before the first push of this
  run, and `never` does not push. A missing `push-policy` means `auto`. Steps that
  fetch or pull apply only with a remote. When a push is skipped, go on, and list the
  unpushed branches in the report. Push a project commit before the workspace commit
  that records its gitlink, so that the workspace never points to a commit that the
  project's remote lacks.

## Uncommitted changes

During a review, the developer may change code by hand, and the build, the tests, and
the application may write files. Run `git status --porcelain` in the workspace and
`git -C <path> status --porcelain` in each project of the request, which also list
untracked files, at these points. In the workspace, a project shows as ` M <path>`
alike for new commits, changed files, and untracked files; the project's own status
tells which. A project that is not part of the request but shows changes is a
finding too.

- when you continue an open review (Step 1)
- before each run of Verify (Step 4)
- before the code review (Step 5), because it reads commits only
- before you act on the outcome (Step 7)

Commit your own pending changes to the request file first, with the gitlinks, so that
the list holds other changes only. If the output is then empty, go on. Otherwise:

1. Show the list. Say for each entry what you think it is: a change that you made, a
   change by the developer, or a generated file.
2. Every entry needs a decision. Nothing is left undecided, and nothing is committed
   that the developer has not seen in the list. Ask the developer:

| Decision | Action |
|----------|--------|
| It belongs to the request | Commit it (step 3). This includes new files: a source file that is not tracked breaks the build for everyone else. |
| It is a generated or local file | Add a pattern for it to the `.gitignore` of the repository where it is (the project's own `.gitignore` for a file in a project), and commit that as `chore: ignore <what>` (in the workspace with its `Refs:` footer, in a project without one). In a project of the request, this is a change of the request, on its project branch. |
| It is not wanted | Discard it: `git restore <path>` for a tracked file, and delete an untracked one. Do this only after the developer confirms, because it cannot be undone. |
| Keep it uncommitted for now | The developer is still trying something. This is allowed only while the review stays open (see below). |

3. Commit what belongs to the request as a normal commit in the repository where it
   is: `fix: …` or the type that fits, described in the project's terms and without
   a `Refs:` footer in a project. A change to a workspace file is committed on the workspace request
   branch, with `Refs: REQ-xxxx`, separately from the request file. If the diff does
   not tell you what a change by the developer is for, ask.
   Stage with `git add -A` when no entry is kept uncommitted. Otherwise, stage the
   paths by name. Push. A change in a project that is not part of the request does
   not belong to it: ask whether to add the project to `projects` (record it in
   `## Q&A`, and create the project branch from the current commit), or to discard or
   keep the change. Add a line to `## Notes` under `### Review (yyyy-MM-dd)`:
   `Changed by the developer: <project> <commit> <what>`. The gitlink goes with the
   next commit that records a result.
4. If a commit changed the code after the last Verify, run Verify again (Step 4).

While changes are kept uncommitted:

- Verify may run, so that the developer sees the result, but the result does not
  count. Record it with the line
  `- Working tree: uncommitted changes in <paths>; this run does not count`.
- The code review does not cover them. Say so.
- The outcomes "Review passed" and "Rework needed" are not available. "Still
  reviewing" is.

## Step 1: Preconditions and target

1. If the root `AGENTS.md` has no `ss-workflow-version:`, stop and point to
   `/ss-workflow:init`. If the version is below `0.6.0`, the repository has the
   single-repository layout: stop, and point to `/ss-workflow:init`, which converts
   it.
2. If this is a linked worktree (`git rev-parse --git-dir` and `--git-common-dir`
   give different paths), or a project folder (`git rev-parse
   --show-superproject-working-tree` prints a path), stop. Explain that Verify and
   Review run in the root checkout of the workspace.
3. If the workspace has a remote, run `git fetch --prune`. For each project with a
   remote, run `git -C <path> fetch --prune`.
4. Check the current branch of the workspace:

| Current branch | Action |
|----------------|--------|
| `develop` | Check that `git status --porcelain` shows no changes. If it does, stop and report them; for a project, its own status and branch tell what it is (a project on a `release/*` branch means that a release is open). Choose the request (below), then continue with Step 2. |
| A request or `hotfix/*` branch whose request file says `review` | A review is open here. If `$ARGUMENTS` is empty or names this request, check for uncommitted changes (see "Uncommitted changes"), and continue the review at Step 3. Otherwise, say that the root checkout is busy with this review, and ask whether to pause it first. To pause: commit and push the notes and the gitlinks, check that there are no uncommitted changes, and run `git checkout develop` and `git submodule update`. |
| A request or `hotfix/*` branch whose request file says anything else | The workflow does not define this state. Continue with "Undefined state" below. |
| Any other branch | The root checkout is busy: a `req/*` branch means a spec discussion. Say which one, and stop. |

Undefined state: the root checkout is on a request branch, and the request file there
(in `reqs/` or `reqs/done/`) does not say `review`. A step that should have switched
the root checkout back to `develop` was interrupted, or the branch was checked out by
hand.

1. Tell the developer that you detected a state that the workflow does not define.
   Show:
   - the branch, the request, and the status in its file
   - the likely cause: `in-progress` means that a review sent the request back for
     rework; `done` means that a merge stopped after it closed the request, or that
     the merge is pending on the remote; `ready` means that a claim was interrupted
   - the commits that the branches have and their bases do not
     (`git log <base>..HEAD --oneline` in the workspace, and the same in each project
     on its project branch), and the output of `git status --porcelain` in the
     workspace and in each project
2. If `$ARGUMENTS` names another request, say that this state has to be settled first.
3. If tracked files have uncommitted changes, show them, and ask whether to commit or
   to discard them, before you act on the answer to the next question.
4. Ask with AskUserQuestion:

| Option | Action |
|--------|--------|
| Restart the review | Make the request `review` again on this branch. If its file is in `reqs/done/`, move it back (`git mv reqs/done/<file> reqs/<file>`). Set `status: review`, and add a dated line to `## Notes` that says the review was restarted, and from which status. Commit `chore(reqs): restart review of REQ-0012`, and push. Continue with Step 2. Verify and Review then run from the start: earlier results in `## Notes` do not count. |
| Merge into `develop` (for a hotfix: into the main branch and `develop`) | If the status is not `done`, set `status: review`, and add a dated line to `## Notes` that says the developer chose to merge from the status it had, without restarting the review. Commit `chore(reqs): mark REQ-0012 for review`, and push. Leave the root checkout on this branch, and hand over to the merge: invoke the `ss-workflow:merge` skill for this branch. If you cannot invoke it, read `${CLAUDE_PLUGIN_ROOT}/skills/merge/SKILL.md` and the guide for the branch kind, and follow them. That skill still says so when no Verify result or no passed Review is recorded, and asks before it merges. |

If the developer chooses neither, change nothing and stop. Say that the root checkout
stays on this branch, and that `git checkout develop` frees it. For an `in-progress`
request, also say that `/ss-workflow:check-req REQ-0012` offers to free it and to
continue the implementation in a worktree.

Choosing the request, on `develop`:

- `$ARGUMENTS` names a request: use it, if its effective status is `review`. If it is
  `in-progress`, the implementation is not finished: point to
  `/ss-workflow:check-req`. If it is `ready` or a draft, say so.
- Otherwise, list the requests with the effective status `review`. A request has it
  when its request branch (a branch whose name contains `REQ-<id>-`, or the `hotfix/*`
  branch that carries its file) holds a request file with `status: review`. Show each
  with its id, title, type, priority, and whether a Verify result is already recorded.
  If there are several, ask which one. If there are none, say so and stop.
- A request that is "merge pending" (`done` on its branch, and the branch is not
  merged) can come back when the review on the remote asks for changes. If the
  developer names such a request, check out its branch (Step 2), reopen it there
  (`git mv reqs/done/<file> reqs/<file>`, set `status: review`, commit
  `chore(reqs): reopen REQ-0012 after remote review`, and push), and continue with
  Step 3.

## Step 2: Check out the request branches

1. If a worktree still holds a branch of the request (`git worktree list`, and
   `git -C <path> worktree list` for each project), git cannot check it out here.
   Check that the worktrees have no uncommitted changes, then remove them in the order
   that "Workspace and projects" in the root `AGENTS.md` gives (the project worktrees
   first). Their commits stay on the branches. If one has uncommitted changes, stop
   and report them.
2. The workspace: `git checkout <branch>`. If the branch exists only on the remote,
   this creates the local branch from `origin/<branch>`. With a remote, run
   `git pull --ff-only`. Then `git submodule update`, which puts every project at the
   gitlink of this branch.
3. Each project of the request: `git -C <path> checkout <project branch>`, and with a
   remote `git -C <path> pull --ff-only`. The other projects stay at their gitlinks.
4. Bring the branches up to date. The base of each project branch is the project's
   develop branch, or its main branch for a hotfix: if the base has commits that the
   branch does not have, merge it into the branch (`git -C <path> merge
   origin/<develop-branch>`, or the local branch without a remote). The base of the
   workspace branch is `develop`, or the workspace main branch for a hotfix; merge it
   the same way. Resolve the conflicts here. If a conflict is not trivial, ask the
   developer. Push, the projects first.

## Step 3: Read what to check

Read the request file on this branch:

- `## Spec`: the acceptance criteria, and "How to verify"
- `## Q&A`: the decisions behind the spec, and entries that are still pending
- `## Notes`: the implementation summary (what changed, what ran, what did not run,
  what is not done, what to look at by hand), the assumptions, the behavior changes,
  earlier Verify results, and earlier review feedback

Then check two things that the implementation owes:

1. **Not done**: if the implementation summary lists criteria or parts of the spec as
   not done, tell the developer now, before anything runs. Ask whether to continue
   the review anyway, or to send the request back (Step 7, "Rework needed").
2. **Agent behavior files**: list the files that the request changes
   (`git -C <path> diff --name-only <base>...HEAD` for each project, and
   `git diff --name-only <base>...HEAD` for the workspace), and compare them with the
   agent behavior files in "Working agreement" of the root `AGENTS.md`: `AGENTS.md`,
   `CLAUDE.md`, files under `.claude/`, a `SKILL.md` and the files in its folder, in
   the workspace and in the projects, and the paths in `agent-files`. Each such file needs an item under `### Behavior changes` in
   `## Notes`. If the entry is missing or does not cover a file, write the missing
   items now from the diff, as "Results and behavior changes" in `reqs/AGENTS.md`
   describes, and commit them with the next commit of the request file. Every item
   becomes a point of the Review (Step 6).

If a `## Q&A` entry is pending, ask the developer that question before the Review
starts, and complete the entry.

Then list the workspace files that the request changes: `git diff --name-only
<base>...HEAD` in the workspace, without the request file and the gitlinks. A change
to a managed block, to `ss-workflow-version`, to `.gitmodules`, or to a `projects`
entry does not belong to a request: show it, and ask whether to undo it on this
branch.

Show the developer a short overview: the request, the change per project
(`git -C <path> diff <base>...HEAD --stat`), the workspace files that it changes, the
agent behavior files that it changes, and the plan for Verify and Review.

## Step 4: Verify

Check for uncommitted changes first (see "Uncommitted changes"). Then, for each
project of the request, run these in order in the project folder, and keep the output
of each:

1. `setup-command`, if the checkout needs preparation after the branch switch
2. `build-command`
3. `test-command`
4. `verify-command`
5. The commands and scripts that the request names for Verify
6. For a hotfix: check that the project's `version-source` holds the hotfix version,
   unless it is `none`

The first four commands come from the project's entry in `projects` ("Workflow
settings" in the root `AGENTS.md`), and they depend on the project's toolchain. Read
"Toolchain" in the project's section of `src/AGENTS.md` for how to find and run the
tools. A command that is empty is skipped and recorded as "not configured". Do not
invent a command for it. If neither a build command nor a test command is configured
for any project of the request, say clearly that Verify checked nothing
automatically, and that the Review has to cover everything.

A request with `projects: []` has no project to verify. Record
`- Workspace files only: nothing to run`, say that Verify checked nothing
automatically, and continue with the Review. Skip the code review (Step 5) too, and
record it as `- Not applicable (workspace files only)`.

When a project of the request is used by another one (SSDisp builds against SSLib),
run the dependent project's checks too: they show whether the projects fit together
on these branches.

Then go through the acceptance criteria. Tick (`- [x]`) each criterion that these
checks actually prove. Leave the others for the Review.

If a check fails:

| Kind of problem | Action |
|-----------------|--------|
| Small: a localized fix that changes neither the design nor the spec | Fix it here, on the project branch. Commit it in the project as a normal commit (`fix: …`, without a `Refs:` footer) and push. Run the failed check again, and then all checks once more at the end. |
| Large: the approach is wrong, a part is missing, or the fix needs a spec decision | Do not fix it here. Show the developer what failed, and propose to send the request back (Step 7, "Rework needed"). |
| Caused by the environment, not by the request (a missing tool, a flaky test that also fails on `develop`) | Report it as such, with what shows that the request is not the cause. Ask the developer how to treat it, and record the question and the answer in `## Q&A`. The check stays `failed` or `did not run` in the record, with the cause. It is never recorded as passed. |

If you are not sure whether a problem is small or large, ask the developer.

Record the result in `## Notes`:

```markdown
### Verify (yyyy-MM-dd)
- Working tree: clean
- SSDisp @ <short sha>
  - setup: did not run (not needed)
  - build: passed
  - tests: failed (2 of 132 failed: <names>; <cause, if known>)
  - verify script: not configured
  - request scripts: did not run (<reason>)
- Fixed during Verify: <project and commits, or "none">
- Not verified automatically: <criteria left for the Review>
```

Write one block per project of the request, with the project commit that was
checked, and one line for each of the checks above, with `passed`,
`failed (<reason>)`, `did not run (<reason>)`, or `not configured`. Do not leave out a
check because it did not run. When a check was run again after a fix, record the last
run, and name the fix under "Fixed during Verify".

Commit with the gitlinks, and push: `docs(reqs): record verify result of REQ-0012`,
with `Refs: REQ-0012`.

Report the Verify result to the developer before the Review starts. If Verify did not
pass and the problems were not fixed, do not start the code review or the Review: go
to Step 7.

## Step 5: Code review (optional)

A code review reads the changes of this request for bugs. It does not replace Verify
or the Review, and it ticks no acceptance criteria.

1. Ask the developer with AskUserQuestion whether to run a code review now: "Run a
   code review" or "Skip". Do not ask when `## Notes` already records a code review
   and the branch has no code commits after it: say so, and continue with Step 6.
   The developer can still ask for another one.
2. If the developer skips it, add `### Code review (yyyy-MM-dd)` with `- Skipped` to
   `## Notes`. It is committed with the next commit of the request file. Continue with
   Step 6.
3. Check for uncommitted changes (see "Uncommitted changes"). The code review reads
   commits only, so a change that is not committed is not reviewed.
4. The code review runs once per project of the request, in the project folder,
   because the code is there. The workspace branch needs none: its changes to
   workspace files are read by the developer in the Review (Step 6). The scope is
   `<base>...<project branch>`: three dots, so that only the changes of this request are
   read, and not what the project's develop branch gained in the
   meantime. `<base>` is the ref that Step 2 merged from in that project:
   `origin/<develop-branch>` with a remote, the local branch without one, and the
   main branch in the same way for a hotfix. Do not run the code review without a
   scope. Its default scope is the commits that are not pushed yet, and in this
   workflow the commits are normally pushed already.
5. Invoke the `code-review` skill with that scope as its argument, with the project
   folder as the working directory, for example
   `origin/develop...feat/gui-button` in `src/SSDisp`. Do not pass `--fix` or
   `--comment`: fixes are made by the rules below. The code review may run in the
   background. Wait for its findings before you go on.
6. If you cannot invoke it, do not read the diff yourself and call that a code review.
   Say that it is not available, show the command that the developer can type in the
   project folder (`/code-review <base>...<project branch>`), and record `- Not available` as
   in step 2.
7. Never start the cloud review (`ultra`) yourself. If the developer wants it, show
   the command for them to type in the project folder: `/code-review ultra
   <develop-branch>`, or with the main branch for a hotfix. Its findings are handled
   like the others.
8. Show the findings to the developer. Check each one against the code before you act
   on it:

| Kind of finding | Action |
|-----------------|--------|
| A real problem with a small, localized fix | Fix it here, on the project branch. Commit it in the project as a normal commit (`fix: …`, without a `Refs:` footer) and push. |
| A real problem that needs a large change or a spec decision | Do not fix it here. Propose to send the request back (Step 7, "Rework needed"). |
| A problem in code that this request did not change | Leave the code alone. Record it as a follow-up, and suggest `/ss-workflow:new-req` for it. |
| Not a problem, or you are not sure | Say why, and let the developer decide. Do not drop a finding silently. |

9. Record the result in `## Notes`:

   ```markdown
   ### Code review (yyyy-MM-dd)
   - Scope: SSDisp origin/develop...feat/gui-button
   - Findings: 3
   - Fixed: <commits, or "none">
   - Not fixed: <finding and reason, or "none">
   - Follow-ups: <findings outside this request, or "none">
   ```

   Commit and push: `docs(reqs): record code review result of REQ-0012`, with
   `Refs: REQ-0012`.
10. If a fix changed the code, run Verify again (Step 4). Run the code review again
    only if the developer asks.

## Step 6: Review

Guide the developer through the manual check:

1. List what to check by hand:
   - every acceptance criterion that is not ticked yet
   - the "Review by hand" points from the implementation summary
   - every item under `### Behavior changes`: show the developer the diff of the file
     and the "Before" and "After" text, and ask whether this is the behavior they
     want. If the text does not match the diff, correct the text first.
   - every other workspace file that the request changes (Step 3), such as a spec in
     `docs/<name>/`: show the diff, and ask whether it is right and whether it
     matches what the code now does. Also say when the request changes the behavior
     of a project, and its docs in `docs/<name>/` did not change.
   - every `Assumption` in `## Notes`: ask whether it still holds
   - every check that Verify recorded as `failed` or `did not run`: the developer has
     to know about it before they decide
2. For each one, say how to check it: which sample or application to start (with the
   exact command or project), which steps to perform, and what the expected result is.
3. If the developer asks, start the application or the sample for them, or run extra
   commands. This is the place where running things is allowed.
4. Wait for the developer's findings. Do not assume a result.
5. If the developer asks for a code review at this point, run Step 5 from its step 3.

## Step 7: Outcome

Ask the developer with AskUserQuestion:

| Option | Action |
|--------|--------|
| Review passed | First check that the last recorded Verify counts: it ran on a clean working tree, and no project branch of the request has a commit after the project commit that it checked. If it does not count, run Verify again (Step 4) before you record anything. If that Verify has a check that is `failed` or `did not run`, or the developer did not confirm a behavior change, say so once more and ask whether the Review passes anyway: record the question and the answer in `## Q&A`. Then tick the remaining acceptance criteria that the developer confirmed, and only those. Add `### Review (yyyy-MM-dd)` with `Passed`, the behavior changes and the workspace files that the developer confirmed, what was accepted although it failed or did not run, and any remarks to `## Notes`. Commit `docs(reqs): record review result of REQ-0012` with the gitlinks, and push. Check that the gitlinks of this commit equal the tips of the project branches. Switch the root checkout back to `develop` (`git checkout develop`, then `git submodule update`). Tell the developer that `/ss-workflow:merge REQ-0012` closes the request. Do not merge on your own. |
| Small changes | Collect the findings, and add them to `## Notes` under `### Review (yyyy-MM-dd)`. Fix them here on the project branches, with normal commits in the projects, and push. Run Verify again (Step 4), then return to Step 6 for the points that changed. |
| Rework needed | Add the findings to `## Notes` under `### Review (yyyy-MM-dd)`, as a clear list of what has to change. Untick the criteria that are no longer met. Set `status: in-progress`. Commit `chore(reqs): reopen REQ-0012 after review` with the gitlinks, and push. Switch the root checkout back to `develop` (`git checkout develop`, then `git submodule update`), so that the project branches are free for the worktrees. Tell the developer that `/ss-workflow:check-req REQ-0012` continues the implementation in a worktree. |
| Still reviewing | Commit and push the notes written so far, with the gitlinks. Leave the root checkout and its projects on the request branches, so the developer can keep trying things. Changes that the developer keeps uncommitted stay as they are: name them in the report. Say that the root checkout stays busy until the review is continued with `/ss-workflow:review`, or paused by switching back to `develop`. |
| Drop the request | Point to `/ss-workflow:merge`, which closes a request without merging it. |

If the findings change the spec, update `## Spec` together with the developer, and say
so in the commit body.

Before you act on "Review passed" or "Rework needed", check for uncommitted changes
(see "Uncommitted changes"). Both switch the root checkout back to `develop`, and
`git status --porcelain` must be empty before that, in the workspace and in every
project, untracked files included. After "Rework needed", a change that is not
committed would not reach the worktree.

## Step 8: Report

Tell the developer, in `discussion-language`:

- The Verify result, check by check, in three groups: what ran and passed, what ran
  and failed, and what did not run or is not configured, with the reason. Do not sum
  it up as "passed" while one check is in the second or third group.
- The acceptance criteria that are still not ticked
- The code review: its findings and what was done with each, or that it was skipped
  or not available
- The behavior changes of agent behavior files, and whether the developer confirmed
  each one
- The Review outcome, and the fixes made during the review
- What is not on the remote yet, if a push was skipped
- The status of the request, and which branch the root checkout is on
- The next step: `/ss-workflow:merge REQ-0012` after a passed review,
  `/ss-workflow:check-req REQ-0012` after "Rework needed", or `/ss-workflow:review`
  to continue
