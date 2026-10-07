# Implementing a request

Everything here happens inside the request's worktree, on the request branch.

## Step 1: Prepare

1. Read the request file completely: `## Spec`, `## Original`, and `## Notes`.
2. Read the AGENTS.md of every folder you will change (`src/`, `tests/`, `samples/`),
   the `README.md` of each affected project, and `docs/*-spec.md`.
3. Confirm that the baseline works before you change anything: run `build-command`,
   and `test-command` if tests exist. If the baseline is already broken, tell the
   developer before you continue. Do not fix unrelated failures inside this request
   without asking.
4. Write a short implementation plan (the steps, and the files or projects affected)
   and show it to the developer. Wait for an answer only if the plan needs a decision
   that the spec does not cover. Otherwise, start.

## Step 2: Implement

- Work through the acceptance criteria. Stay inside the request's scope. If you find
  something worth doing outside the scope, record it in `## Notes` as a follow-up, and
  suggest `/ss-workflow-new-req` for it at the end.
- **If the spec is unclear or turns out to be wrong, stop and ask.** Do not guess.
  When the developer decides, update `## Spec`, and record the decision and its reason
  in `## Notes` with the date.
- Commit often. One commit holds one reason for change. Follow the commit convention,
  and end every commit with `Refs: REQ-xxxx`.
- Push after every commit if a remote exists.
- Add or update tests in `tests/` for every behavior change in `src/`.
- When the public API or the behavior changes, update the affected sample in
  `samples/`, the project `README.md`, and `docs/*-spec.md` in this branch.
- Do not change the version. Do not touch other requests' files.
- When an acceptance criterion is met and verified, tick it in `## Spec` (`- [x]`).

## Step 3: Verify

1. Run `build-command` and `test-command`. Both must pass.
2. Check each acceptance criterion against the actual behavior, not only against the
   tests. For GUI changes, run the sample or the application if you can. If you
   cannot, say exactly what the developer needs to check by hand.
3. Bring the branch up to date. If a remote exists, run `git fetch` first. If
   `develop` has new commits (for a hotfix: the main branch), merge it into the request
   branch (`git merge develop`), resolve the conflicts, and run the build and the tests
   again. Do not rebase, because the branch is already pushed.
4. Review your own diff (`git diff develop...HEAD`) for leftover debug code, unrelated
   changes, and missing files.

If something cannot be finished, do not hand the request over as complete. Report what
is missing, and ask whether to continue, to change the spec, or to split the rest into
a new request.

## Step 4: Hand over for review

1. Add a review summary to `## Notes`:

   ```markdown
   ### Review summary (yyyy-MM-dd)
   - What changed: ...
   - How to verify: <commands to run, sample to start, what to look at>
   - Not verified automatically: <manual checks left for the developer>
   - Follow-ups: <out-of-scope findings, if any>
   ```

2. Set `status: review` in the request file, on this branch. Commit and push:

   ```
   chore(reqs): mark REQ-0012 for review

   Refs: REQ-0012
   ```

3. Report to the developer, in `discussion-language`:
   - What was done, criterion by criterion
   - The build and test results
   - How to review: the worktree path, `git diff develop...HEAD`, and what to run
   - What needs a manual check
   - The next step: after the review, run `/ss-workflow-merge`. To request changes,
     run `/ss-workflow-check-req` in this worktree.

Do not merge. Do not remove the worktree. The request stays in the worktree until the
developer has reviewed it.

## Hotfix differences

A `hotfix/*` branch starts from the main branch, so the request file is not on it.

- Read the request with `git show develop:reqs/<file>`.
- Do not add the request file to the hotfix branch.
- Status and `## Notes` changes (ticked criteria, the review summary, `review`, and
  reopening) are committed on `develop` in the main checkout, then pushed. Before you
  do this, check that the main checkout is on `develop` and that the request file has
  no uncommitted changes. If the main checkout is on another branch, for example
  during a release, tell the developer and ask them how to proceed. Do not switch
  branches there.
- Set the hotfix version in `version-source` on the hotfix branch as its own commit:
  `chore(release): bump version to <version>`.
- Step 3.3 merges the main branch, not `develop`. The diff base for the review is the
  main branch.
