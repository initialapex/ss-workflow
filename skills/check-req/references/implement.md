# Implementing a request

Everything here happens inside the request's worktree, on the request branch.

**What may run in a worktree:** `setup-command`, if the worktree needs preparation,
and `build-command`, to compile. Nothing else: no tests, no scripts, no executables,
no sample applications, no flashing or deploying. Those belong to Verify, which the
developer starts later in the root checkout with `/ss-workflow:review`.

Both commands come from "Workflow settings" in the root `AGENTS.md`, and they depend
on the project's toolchain. Read the "Toolchain" section there, and the "Project
rules" in the source folder's `AGENTS.md`, before you build or change anything.

- If `build-command` is empty, the project cannot be built from a shell. Do not
  invent a build command. Skip the build, and record "build: not configured".
- If a command cannot run in the worktree because of the environment (for example a
  step that needs network access, an IDE, or a license, or a sandbox restriction),
  that is not a failure of the request. Record it in `## Notes` and continue.

## Step 1: Prepare

1. Read the request file completely: `## Spec`, `## Original`, and `## Notes`.
2. Read the AGENTS.md of every folder you will change (the source folder, `tests/`,
   `samples/`), the `README.md` of each affected project or module, and
   `docs/*-spec.md`.
3. Run `setup-command` if the worktree needs it. Then try `build-command` once before
   you change anything, to know the baseline. If the
   code does not compile before your changes, tell the developer before you continue.
4. If `## Spec` has no "Architecture" part, stop. Propose one, and ask the developer to
   confirm it. Write it into `## Spec`, and record the question and the answer in
   `## Q&A` (stage `implementation`).
5. Write a short implementation plan (the steps, and the files or projects affected)
   that follows the "Architecture" part of the spec, and show it to the developer. Wait for an answer only if the plan needs a decision
   that the spec does not cover. Otherwise, start.

## Step 2: Implement

- Work through the acceptance criteria. Stay inside the request's scope. If you find
  something worth doing outside the scope, record it in `## Notes` as a follow-up, and
  suggest `/ss-workflow:new-req` for it at the end.
- Build what the "Architecture" part of the spec describes. Do not change the
  architecture on your own. If it does not fit the code as you find it, that is an
  error in the spec: see the next point.
- **If the spec is unclear or turns out to be wrong, stop and ask.** Do not guess.
  Add the question to `## Q&A` (stage `implementation`), as "Questions and answers" in
  `reqs/AGENTS.md` describes. When the developer decides, complete the entry with the
  answer in their own words and the decision, and update `## Spec`. If the session
  ends before the answer comes, the entry stays with `A: (pending)`, and the next
  session asks again. If the file has no `## Q&A` section yet (an older request), add
  it between `## Original` and `## Notes`.
- If the request was reopened by a review, the feedback is in `## Notes`. Address every
  point of it.
- Commit often. One commit holds one reason for change. Follow the commit convention,
  and end every commit with `Refs: REQ-xxxx`.
- Push after every commit (see "Pushing" in the skill's ground rules).
- Add or update the tests in `tests/` for every behavior change in the source code,
  if the project has automated tests. Write them
  carefully, because you cannot run them here.
- Register every new file with the build in the way that "Project rules" describe.
  A file that the build does not know is a common cause of a failed Verify.
- When the public interface or the behavior changes, update the affected sample in
  `samples/`, the project `README.md`, and `docs/*-spec.md` in this branch.
- Do not change the version (except on a hotfix branch, see below). Do not touch other
  requests' files.
- Do not tick the acceptance criteria. They are ticked during Verify and Review, when
  they have actually been checked.
- Note every agent behavior file that you change: `AGENTS.md`, `CLAUDE.md`, a file
  under `.claude/`, a `SKILL.md` or a file in its folder, or a path in `agent-files`
  (see "Working agreement" in the root `AGENTS.md`). Before you change one, be sure
  how an agent behaves with the current text, because Step 4 asks for it.

## Step 3: Check your work

1. Try `build-command`. Fix every compile error that your changes caused.
2. Bring the branch up to date. If a remote exists, run `git fetch` first. If `develop`
   has new commits (for a hotfix: the main branch), merge it into the request branch
   (`git merge origin/develop`, or `git merge develop` without a remote), resolve the
   conflicts, and try the build again. Do not rebase: the branch may be pushed.
3. Read your own diff (`git diff <base>...HEAD`) for leftover debug code, unrelated
   changes, and missing files. Because nothing was run, also read it once more for
   logic errors, as a reviewer would.

If something cannot be finished, do not hand the request over as complete. Report what
is missing, and ask whether to continue, to change the spec, or to split the rest into
a new request.

## Step 4: Hand over and remove the worktree

1. Add an implementation summary to `## Notes`:

   ```markdown
   ### Implementation summary (yyyy-MM-dd)
   - What changed: ...
   - Architecture: as in the spec / changed with the developer's decision in Q<n>
   - Ran in the worktree: <each command that ran, with `passed` or `failed (<reason>)`; "nothing" if none ran>
   - Did not run: tests, scripts, and executables (left to Verify); <the build, if it did not run: `not configured` / `could not run (<reason>)`>
   - Not done: <acceptance criteria or parts of the spec that are not implemented, with the reason; or "none">
   - Verify: <commands, test projects, and scripts to run in the root checkout>
   - Review by hand: <what the developer needs to look at or try, and how to start it>
   - Follow-ups: <out-of-scope findings, if any>
   ```

   Write every line from what happened in this worktree, not from what you expect.
   "Ran in the worktree" lists only commands that you ran and whose output you saw. A
   build that failed is `failed`, also when you think that the cause lies outside the
   request. Keep all the lines: write "none" or "nothing" where that is the fact.

   If the branch changes an agent behavior file
   (`git diff --name-only <base>...HEAD`, compared with the list in "Working
   agreement"), also add the entry that "Results and behavior changes" in
   `reqs/AGENTS.md` describes, with one item for each such file:

   ```markdown
   ### Behavior changes (yyyy-MM-dd)
   - `<path>`
     - Diff: <the changed lines, quoted. For a long change: `git diff <base>...<branch> -- <path>`>
     - Before: <what an agent did, and in which situation>
     - After: <what an agent does now>
   ```

   Describe behavior, not the edit: "Before: the agent pushed after every commit.
   After: it asks before the first push", and not "reworded the push rule". If a
   change does not alter any behavior (a typo, a renamed heading that nothing looks
   up), say exactly that for the file. List these items under "Review by hand" too:
   no build or test proves them.

2. Set `status: review` in the request file. Commit and push:

   ```
   chore(reqs): mark REQ-0012 for review

   Refs: REQ-0012
   ```

3. Confirm that nothing would be lost with the worktree:
   - `git status --porcelain` is empty. Untracked files that matter must be committed
     first.
   - When pushing is allowed: `git log origin/<branch>..HEAD --oneline` is empty.
   - When nothing is pushed (no remote, `push-policy: never`, or the developer
     declined): the commits stay on the local branch, which survives the worktree.
     Check that the branch exists (`git rev-parse --verify <branch>`) and that `HEAD`
     is its tip, and keep the list of unpushed commits for the report.

   Do not remove the worktree until these hold.
4. Remove the worktree and keep the branch. Run this from the root checkout, not from
   inside the worktree:

   ```bash
   git -C <root checkout> worktree remove <worktree path>
   ```

   If the folder cannot be deleted because it is in use (this session's working
   directory, an editor, or Visual Studio), say so. The developer can close those
   programs and delete it later, and `/ss-workflow:check-req` reports a leftover
   worktree in its overview. Do not use `--force` without asking.
5. Report to the developer, in `discussion-language`:
   - What was implemented, criterion by criterion, and what was not done
   - What ran in the worktree, with its result, and what did not run and why
   - That nothing was tested or run yet
   - The behavior changes, if the request changed agent behavior files
   - The questions in `## Q&A` that are still pending, if any
   - That the worktree is removed, and the branch `<branch>` holds the work
   - Whether the branch is on the remote, or which commits the developer still has to
     push
   - The next step: `/ss-workflow:review REQ-0012` in the root checkout starts Verify
     and Review

Do not merge. The request now waits in `review` until the developer starts the review.

## Hotfix differences

A `hotfix/v<version>` branch starts from the main branch.

- The claim commit copies the request file from `develop` onto this branch. After
  that, the file is handled like any other request file: its status and its notes are
  committed on the hotfix branch.
- Set the hotfix version in `version-source` on the hotfix branch as its own commit:
  `chore(release): bump version to <version>`. Skip this if `version-source` is
  `none`.
- Step 3.2 merges the main branch, not `develop`. The diff base is the main branch.
