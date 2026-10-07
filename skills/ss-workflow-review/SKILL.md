---
name: ss-workflow-review
description: Verify and review an implemented request of an ss-workflow repository in the root checkout. Checks out the request branch, runs the build, the tests and the verification scripts (Verify), offers a code review of the request's changes, then guides the developer through the manual check (Review), applies small fixes, or sends the request back for rework. Use when the developer wants to start, continue, or finish the review of a request that is waiting in the review status.
argument-hint: "[REQ-id]"
---

# ss-workflow-review

Verify and review one request in the root checkout, on its request branch.

- **Verify**: you run the build, the test projects, and the verification scripts.
- **Code review** (optional): if the developer wants it, the `code-review` skill reads
  the request's changes for bugs.
- **Review**: the developer checks the result by hand, and you guide them.

The request is closed later, when the developer runs `/ss-workflow-merge`. This skill
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
- Report results as they are. A failed or skipped check is never recorded as passed.
- Only the developer decides that the Review passed.
- Never force-push, and never rebase a pushed branch.

## Step 1: Preconditions and target

1. If the root `AGENTS.md` has no `ss-workflow-version:`, stop and point to
   `/ss-workflow-init`.
2. If this is a linked worktree (`git rev-parse --git-dir` and `--git-common-dir`
   give different paths), stop. Explain that Verify and Review run in the root
   checkout.
3. If a remote exists, run `git fetch --prune`.
4. Check the current branch:

| Current branch | Action |
|----------------|--------|
| `develop` | Check that `git status --porcelain` shows no changes to tracked files. If it does, stop and report them. Choose the request (below), then continue with Step 2. |
| A request or `hotfix/*` branch whose request file says `review` | A review is open here. If `$ARGUMENTS` is empty or names this request, continue it at Step 3. Otherwise, say that the root checkout is busy with this review, and ask whether to pause it first. To pause: commit and push the notes, check that there are no uncommitted changes, and run `git checkout develop`. |
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
| Merge into `develop` (for a hotfix: into the main branch and `develop`) | If the status is not `done`, set `status: review`, and add a dated line to `## Notes` that says the developer chose to merge from the status it had, without restarting the review. Commit `chore(reqs): mark REQ-0012 for review`, and push. Leave the root checkout on this branch, and hand over to the merge: invoke the `ss-workflow-merge` skill for this branch. If you cannot invoke it, read `${CLAUDE_PLUGIN_ROOT}/skills/ss-workflow-merge/SKILL.md` and the guide for the branch kind, and follow them. That skill still says so when no Verify result or no passed Review is recorded, and asks before it merges. |

If the developer chooses neither, change nothing and stop. Say that the root checkout
stays on this branch, and that `git checkout develop` frees it. For an `in-progress`
request, also say that `/ss-workflow-check-req REQ-0012` offers to free it and to
continue the implementation in a worktree.

Choosing the request, on `develop`:

- `$ARGUMENTS` names a request: use it, if its effective status is `review`. If it is
  `in-progress`, the implementation is not finished: point to
  `/ss-workflow-check-req`. If it is `ready` or a draft, say so.
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
   here. Check that the worktree has no uncommitted changes and no unpushed commits,
   then remove it (`git worktree remove <path>`). If it has uncommitted changes, stop
   and report them.
2. `git checkout <branch>`. If the branch exists only on the remote, this creates the
   local branch from `origin/<branch>`. With a remote, run `git pull --ff-only`.
3. Bring the branch up to date. The base is `develop`, or the main branch for a hotfix.
   If the base has commits that the branch does not have, merge it into the branch
   (`git merge origin/develop`, or `git merge develop` without a remote). Resolve the
   conflicts here. If a conflict is not trivial, ask the developer. Push.

## Step 3: Read what to check

Read the request file on this branch:

- `## Spec`: the acceptance criteria, and "How to verify"
- `## Notes`: the implementation summary (what changed, what to run, what to look at by
  hand), earlier Verify results, and earlier review feedback

Show the developer a short overview: the request, the change
(`git diff <base>...HEAD --stat`), and the plan for Verify and Review.

## Step 4: Verify

Run these in order, and keep the output of each:

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
| Caused by the environment, not by the request (a missing tool, a flaky test that also fails on `develop`) | Report it as such. Ask the developer how to treat it. Do not record it as passed. |

If you are not sure whether a problem is small or large, ask the developer.

Record the result in `## Notes`:

```markdown
### Verify (yyyy-MM-dd)
- build: passed
- tests: passed (132 passed, 0 failed)
- verify script: not configured
- Fixed during Verify: <commits, or "none">
- Not verified automatically: <criteria left for the Review>
```

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
3. The scope is `<base>...<branch>`: three dots, so that only the changes of this
   request are read, and not what `develop` gained in the meantime. `<base>` is the
   ref that Step 2 merged from: `origin/develop` with a remote, `develop` without one,
   and the main branch in the same way for a hotfix. Do not run the code review
   without a scope. Its default scope is the commits that are not pushed yet, and in
   this workflow every commit is pushed.
4. Invoke the `code-review` skill with that scope as its argument, for example
   `origin/develop...feat/REQ-0012-gui-button`. Do not pass `--fix` or `--comment`:
   fixes are made by the rules below. The code review may run in the background. Wait
   for its findings before you go on.
5. If you cannot invoke it, do not read the diff yourself and call that a code review.
   Say that it is not available, show the command that the developer can type
   (`/code-review <base>...<branch>`), and record `- Not available` as in step 2.
6. Never start the cloud review (`ultra`) yourself. If the developer wants it, show
   the command for them to type: `/code-review ultra develop`, or with the main branch
   for a hotfix. Its findings are handled like the others.
7. Show the findings to the developer. Check each one against the code before you act
   on it:

| Kind of finding | Action |
|-----------------|--------|
| A real problem with a small, localized fix | Fix it here, on the request branch. Commit it as a normal commit (`fix: …`, with `Refs: REQ-xxxx`) and push. |
| A real problem that needs a large change or a spec decision | Do not fix it here. Propose to send the request back (Step 7, "Rework needed"). |
| A problem in code that this request did not change | Leave the code alone. Record it as a follow-up, and suggest `/ss-workflow-new-req` for it. |
| Not a problem, or you are not sure | Say why, and let the developer decide. Do not drop a finding silently. |

8. Record the result in `## Notes`:

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
9. If a fix changed the code, run Verify again (Step 4). Run the code review again
   only if the developer asks.

## Step 6: Review

Guide the developer through the manual check:

1. List what to check by hand: every acceptance criterion that is not ticked yet, and
   the "Review by hand" points from the implementation summary.
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
| Review passed | Tick the remaining acceptance criteria that the developer confirmed. Add `### Review (yyyy-MM-dd)` with `Passed` and any remarks to `## Notes`. Commit `docs(reqs): record review result of REQ-0012`, and push. Switch the root checkout back to `develop`. Tell the developer that `/ss-workflow-merge REQ-0012` closes the request. Do not merge on your own. |
| Small changes | Collect the findings, and add them to `## Notes` under `### Review (yyyy-MM-dd)`. Fix them here on the request branch, with normal commits, and push. Run Verify again (Step 4), then return to Step 6 for the points that changed. |
| Rework needed | Add the findings to `## Notes` under `### Review (yyyy-MM-dd)`, as a clear list of what has to change. Untick the criteria that are no longer met. Set `status: in-progress`. Commit `chore(reqs): reopen REQ-0012 after review`, and push. Switch the root checkout back to `develop`. Tell the developer that `/ss-workflow-check-req REQ-0012` continues the implementation in a worktree. |
| Still reviewing | Commit and push the notes written so far. Leave the root checkout on the request branch, so the developer can keep trying things. Say that the root checkout stays busy until the review is continued with `/ss-workflow-review`, or paused by switching back to `develop`. |
| Drop the request | Point to `/ss-workflow-merge`, which closes a request without merging it. |

If the findings change the spec, update `## Spec` together with the developer, and say
so in the commit body.

Before you switch the root checkout back to `develop`, check that
`git status --porcelain` shows no changes to tracked files. If Verify or the
application left changes in tracked files (generated files, snapshots, settings), show
them and ask whether to commit or to discard them.

## Step 8: Report

Tell the developer, in `discussion-language`:

- The Verify result, check by check
- The code review: its findings and what was done with each, or that it was skipped
  or not available
- The Review outcome, and the fixes made during the review
- The status of the request, and which branch the root checkout is on
- The next step: `/ss-workflow-merge REQ-0012` after a passed review,
  `/ss-workflow-check-req REQ-0012` after "Rework needed", or `/ss-workflow-review`
  to continue
