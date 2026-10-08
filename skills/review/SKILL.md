---
name: review
description: Verify and review an implemented request of an ss-workflow repository in the root checkout. Checks out the request branch, runs the build, the tests and the verification scripts (Verify), offers a code review of the request's changes, then guides the developer through the manual check (Review), applies small fixes, or sends the request back for rework. Use when the developer wants to start, continue, or finish the review of a request that is waiting in the review status.
argument-hint: "[REQ-id]"
---

# review

Verify and review one request in the root checkout, on its request branch.

- **Verify**: you run the build, the test projects, and the verification scripts.
- **Code review** (optional): if the developer wants it, the `code-review` skill reads
  the request's changes for bugs.
- **Review**: the developer checks the result by hand, and you guide them.

The request is closed later, when the developer runs `/ss-workflow:merge`. This skill
never merges. In one case it hands over to that skill: when the developer chooses to
merge from an undefined state (Step 1).

Input: `$ARGUMENTS` (optional `REQ-xxxx`)

## Ground rules

- Read the root `AGENTS.md` ("Workflow settings", "Working agreement", "Commit
  convention") and `reqs/AGENTS.md` first. They are the source of truth.
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
- A commit that records a result stages only the request file (`git add reqs/<file>`).
  Do not use `git add -A` or `git commit -a` for it.
- Never force-push, and never rebase a pushed branch.
- **Pushing**: follow "Remote and pushing" in the root `AGENTS.md`. Where this skill
  says "push", push only when a remote exists and `push-policy` allows it: `auto`
  pushes, `ask` asks before the first push of this run, and `never` does not push. A
  missing `push-policy` means `auto`. Steps that fetch or pull apply only with a
  remote. When a push is skipped, go on, and list the unpushed branches in the report.

## Uncommitted changes

During a review, the developer may change code by hand, and the build, the tests, and
the application may write files. Run `git status --porcelain`, which also lists
untracked files, at these points:

- when you continue an open review (Step 1)
- before each run of Verify (Step 4)
- before the code review (Step 5), because it reads commits only
- before you act on the outcome (Step 7)

Commit your own pending changes to the request file first, so that the list holds
other changes only. If the output is then empty, go on. Otherwise:

1. Show the list. Say for each entry what you think it is: a change that you made, a
   change by the developer, or a generated file.
2. Every entry needs a decision. Nothing is left undecided, and nothing is committed
   that the developer has not seen in the list. Ask the developer:

| Decision | Action |
|----------|--------|
| It belongs to the request | Commit it (step 3). This includes new files: a source file that is not tracked breaks the build for everyone else. |
| It is a generated or local file | Add a pattern for it to `.gitignore`, and commit that as `chore: ignore <what>`, with `Refs: REQ-xxxx`. |
| It is not wanted | Discard it: `git restore <path>` for a tracked file, and delete an untracked one. Do this only after the developer confirms, because it cannot be undone. |
| Keep it uncommitted for now | The developer is still trying something. This is allowed only while the review stays open (see below). |

3. Commit what belongs to the request as a normal commit: `fix: …` or the type that
   fits, with `Refs: REQ-xxxx`. If the diff does not tell you what a change by the
   developer is for, ask. Stage with `git add -A` when no entry is kept uncommitted.
   Otherwise, stage the paths by name. Push. Add a line to `## Notes` under
   `### Review (yyyy-MM-dd)`: `Changed by the developer: <commit> <what>`.
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
   `/ss-workflow:init`.
2. If this is a linked worktree (`git rev-parse --git-dir` and `--git-common-dir`
   give different paths), stop. Explain that Verify and Review run in the root
   checkout.
3. If a remote exists, run `git fetch --prune`.
4. Check the current branch:

| Current branch | Action |
|----------------|--------|
| `develop` | Check that `git status --porcelain` shows no changes to tracked files. If it does, stop and report them. Choose the request (below), then continue with Step 2. |
| A request or `hotfix/*` branch whose request file says `review` | A review is open here. If `$ARGUMENTS` is empty or names this request, check for uncommitted changes (see "Uncommitted changes"), and continue the review at Step 3. Otherwise, say that the root checkout is busy with this review, and ask whether to pause it first. To pause: commit and push the notes, check that there are no uncommitted changes, and run `git checkout develop`. |
| A request or `hotfix/*` branch whose request file says anything else | The workflow does not define this state. Continue with "Undefined state" below. |
| Any other branch | The root checkout is busy: a `req/*` branch means a spec discussion, and a `release/*` branch means a release. Say which one, and stop. |

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
   - the commits that the branch has and its base does not
     (`git log <base>..HEAD --oneline`), and the output of `git status --porcelain`
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

## Step 2: Check out the request branch

1. If a worktree still holds the branch (`git worktree list`), git cannot check it out
   here. Check that the worktree has no uncommitted changes, then remove it
   (`git worktree remove <path>`). Its commits stay on the branch. If it has
   uncommitted changes, stop and report them.
2. `git checkout <branch>`. If the branch exists only on the remote, this creates the
   local branch from `origin/<branch>`. With a remote, run `git pull --ff-only`.
3. Bring the branch up to date. The base is `develop`, or the main branch for a hotfix.
   If the base has commits that the branch does not have, merge it into the branch
   (`git merge origin/develop`, or `git merge develop` without a remote). Resolve the
   conflicts here. If a conflict is not trivial, ask the developer. Push.

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
   (`git diff --name-only <base>...HEAD`), and compare them with the agent behavior
   files in "Working agreement" of the root `AGENTS.md`: `AGENTS.md`, `CLAUDE.md`,
   files under `.claude/`, a `SKILL.md` and the files in its folder, and the paths in
   `agent-files`. Each such file needs an item under `### Behavior changes` in
   `## Notes`. If the entry is missing or does not cover a file, write the missing
   items now from the diff, as "Results and behavior changes" in `reqs/AGENTS.md`
   describes, and commit them with the next commit of the request file. Every item
   becomes a point of the Review (Step 6).

If a `## Q&A` entry is pending, ask the developer that question before the Review
starts, and complete the entry.

Show the developer a short overview: the request, the change
(`git diff <base>...HEAD --stat`), the agent behavior files that it changes, and the
plan for Verify and Review.

## Step 4: Verify

Check for uncommitted changes first (see "Uncommitted changes"). Then run these in
order, and keep the output of each:

1. `setup-command`, if the checkout needs preparation after the branch switch
2. `build-command`
3. `test-command`
4. `verify-command`
5. The commands and scripts that the request names for Verify
6. For a hotfix: check that `version-source` holds the hotfix version, unless it is
   `none`

The first four commands come from "Workflow settings" in the root `AGENTS.md`, and they
depend on the project's toolchain. Read the "Toolchain" section there for how to find
and run the tools. A command that is empty is skipped and recorded as "not
configured". Do not invent a command for it. If neither a build command nor a test
command is configured, say clearly that Verify checked nothing automatically, and that
the Review has to cover everything.

Then go through the acceptance criteria. Tick (`- [x]`) each criterion that these
checks actually prove. Leave the others for the Review.

If a check fails:

| Kind of problem | Action |
|-----------------|--------|
| Small: a localized fix that changes neither the design nor the spec | Fix it here, on the request branch. Commit it as a normal commit (`fix: …`, with `Refs: REQ-xxxx`) and push. Run the failed check again, and then all checks once more at the end. |
| Large: the approach is wrong, a part is missing, or the fix needs a spec decision | Do not fix it here. Show the developer what failed, and propose to send the request back (Step 7, "Rework needed"). |
| Caused by the environment, not by the request (a missing tool, a flaky test that also fails on `develop`) | Report it as such, with what shows that the request is not the cause. Ask the developer how to treat it, and record the question and the answer in `## Q&A`. The check stays `failed` or `did not run` in the record, with the cause. It is never recorded as passed. |

If you are not sure whether a problem is small or large, ask the developer.

Record the result in `## Notes`:

```markdown
### Verify (yyyy-MM-dd)
- Working tree: clean
- setup: did not run (not needed)
- build: passed
- tests: failed (2 of 132 failed: <names>; <cause, if known>)
- verify script: not configured
- request scripts: did not run (<reason>)
- Fixed during Verify: <commits, or "none">
- Not verified automatically: <criteria left for the Review>
```

Write one line for each of the checks above, with `passed`, `failed (<reason>)`,
`did not run (<reason>)`, or `not configured`. Do not leave out a check because it
did not run. When a check was run again after a fix, record the last run, and name
the fix under "Fixed during Verify".

Commit and push: `docs(reqs): record verify result of REQ-0012`, with `Refs: REQ-0012`.

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
4. The scope is `<base>...<branch>`: three dots, so that only the changes of this
   request are read, and not what `develop` gained in the meantime. `<base>` is the
   ref that Step 2 merged from: `origin/develop` with a remote, `develop` without one,
   and the main branch in the same way for a hotfix. Do not run the code review
   without a scope. Its default scope is the commits that are not pushed yet, and in
   this workflow the commits are normally pushed already.
5. Invoke the `code-review` skill with that scope as its argument, for example
   `origin/develop...feat/REQ-0012-gui-button`. Do not pass `--fix` or `--comment`:
   fixes are made by the rules below. The code review may run in the background. Wait
   for its findings before you go on.
6. If you cannot invoke it, do not read the diff yourself and call that a code review.
   Say that it is not available, show the command that the developer can type
   (`/code-review <base>...<branch>`), and record `- Not available` as in step 2.
7. Never start the cloud review (`ultra`) yourself. If the developer wants it, show
   the command for them to type: `/code-review ultra develop`, or with the main branch
   for a hotfix. Its findings are handled like the others.
8. Show the findings to the developer. Check each one against the code before you act
   on it:

| Kind of finding | Action |
|-----------------|--------|
| A real problem with a small, localized fix | Fix it here, on the request branch. Commit it as a normal commit (`fix: …`, with `Refs: REQ-xxxx`) and push. |
| A real problem that needs a large change or a spec decision | Do not fix it here. Propose to send the request back (Step 7, "Rework needed"). |
| A problem in code that this request did not change | Leave the code alone. Record it as a follow-up, and suggest `/ss-workflow:new-req` for it. |
| Not a problem, or you are not sure | Say why, and let the developer decide. Do not drop a finding silently. |

9. Record the result in `## Notes`:

   ```markdown
   ### Code review (yyyy-MM-dd)
   - Scope: origin/develop...feat/REQ-0012-gui-button
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
| Review passed | First check that the last recorded Verify counts: it ran on a clean working tree, and the branch has no commit after it that changes files outside `reqs/`. If it does not count, run Verify again (Step 4) before you record anything. If that Verify has a check that is `failed` or `did not run`, or the developer did not confirm a behavior change, say so once more and ask whether the Review passes anyway: record the question and the answer in `## Q&A`. Then tick the remaining acceptance criteria that the developer confirmed, and only those. Add `### Review (yyyy-MM-dd)` with `Passed`, the behavior changes that the developer confirmed, what was accepted although it failed or did not run, and any remarks to `## Notes`. Commit `docs(reqs): record review result of REQ-0012`, and push. Switch the root checkout back to `develop`. Tell the developer that `/ss-workflow:merge REQ-0012` closes the request. Do not merge on your own. |
| Small changes | Collect the findings, and add them to `## Notes` under `### Review (yyyy-MM-dd)`. Fix them here on the request branch, with normal commits, and push. Run Verify again (Step 4), then return to Step 6 for the points that changed. |
| Rework needed | Add the findings to `## Notes` under `### Review (yyyy-MM-dd)`, as a clear list of what has to change. Untick the criteria that are no longer met. Set `status: in-progress`. Commit `chore(reqs): reopen REQ-0012 after review`, and push. Switch the root checkout back to `develop`. Tell the developer that `/ss-workflow:check-req REQ-0012` continues the implementation in a worktree. |
| Still reviewing | Commit and push the notes written so far. Leave the root checkout on the request branch, so the developer can keep trying things. Changes that the developer keeps uncommitted stay as they are: name them in the report. Say that the root checkout stays busy until the review is continued with `/ss-workflow:review`, or paused by switching back to `develop`. |
| Drop the request | Point to `/ss-workflow:merge`, which closes a request without merging it. |

If the findings change the spec, update `## Spec` together with the developer, and say
so in the commit body.

Before you act on "Review passed" or "Rework needed", check for uncommitted changes
(see "Uncommitted changes"). Both switch the root checkout back to `develop`, and
`git status --porcelain` must be empty before that, untracked files included. After
"Rework needed", a change that is not committed would not reach the worktree.

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
