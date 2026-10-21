# Implementing a request

Everything here happens inside the request's worktrees: the workspace worktree on the
workspace request branch, and inside it, at each project's `path`, a worktree of that
project on its project branch.

- Code, tests, and project files are committed in the project worktrees, on the
  project branches.
- The workspace branch gets the commits for the request file and the gitlinks, and
  the request's changes to workspace files: the docs, the README files, and the agent
  files outside their managed blocks (see "Workspace and projects" in the root
  `AGENTS.md`). Commit them in the workspace worktree, separately from the request
  file, with `Refs: REQ-xxxx`, for example `docs(SSLib): describe the new frame API`.
  Never change a managed block, `ss-workflow-version`, `.gitmodules`, or a `projects`
  entry.
- A request with `projects: []` has no project worktree to commit in. Everything it
  changes is a workspace file, and nothing builds it: skip the build steps below, and
  record "build: not applicable (workspace files only)".

**What may run in a worktree:** a project's `setup-command`, if the worktree needs
preparation, and its `build-command`, to compile. Both run in the project folder.
Nothing else: no tests, no scripts, no executables, no sample applications, no
flashing or deploying. Those belong to Verify, which the developer starts later in the
root checkout with `/ss-workflow:review`.

Both commands come from the project's entry in `projects` ("Workflow settings" in the
root `AGENTS.md`), and they depend on the project's toolchain. Read the project's
section in `src/AGENTS.md` ("Toolchain" and "Project rules"), and the project's own
`AGENTS.md`, `CLAUDE.md`, and README if it has them, before you build or change
anything.

- If `build-command` is empty, the project cannot be built from a shell. Do not
  invent a build command. Skip the build, and record "build: not configured".
- If a command cannot run in the worktree because of the environment (for example a
  step that needs network access, an IDE, or a license, or a sandbox restriction),
  that is not a failure of the request. Record it in `## Notes` and continue.

## Step 1: Prepare

1. Read the request file completely: `## Spec`, `## Original`, `## Q&A`, and
   `## Notes`.
2. For each project of the request, read what the paragraph above lists, plus the
   `README.md` of each affected part of the project, and its docs in the workspace
   (`docs/<name>/`, at least `spec.md`). Read `docs/overview.md` too.
3. For each project, run `setup-command` if the worktree needs it. Then try
   `build-command` once before you change anything, to know the baseline. If the code
   does not compile before your changes, tell the developer before you continue.
4. If `## Spec` has no "Architecture" part, stop. Propose one, and ask the developer to
   confirm it. Write it into `## Spec`, and record the question and the answer in
   `## Q&A` (stage `implementation`).
5. Write a short implementation plan (the steps, and the files or parts affected in
   each project) that follows the "Architecture" part of the spec, and show it to the
   developer. Wait for an answer only if the plan needs a decision that the spec does
   not cover. Otherwise, start.

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
- The request needs a project that is not in its `projects`: stop and ask. If the
  developer agrees, add it to `projects` (record it in `## Q&A`), and create its
  branch and worktree as Step 5.5 of `SKILL.md` does, replacing the detached one.
- If the request was reopened by a review, the feedback is in `## Notes`. Address every
  point of it.
- Commit often, in the project where the change is. One commit holds one reason for
  change. Follow the commit convention. End every project commit with
  `Refs: <workspace-name>#REQ-xxxx`, and every workspace commit with `Refs: REQ-xxxx`.
- Push after every commit (see "Pushing" in the skill's ground rules), each repository
  as its own `push-policy` allows.
- Add or update the automated tests of the project for every behavior change, if the
  project has them. Write them carefully, because you cannot run them here.
- Register every new file with the build in the way that "Project rules" describe.
  A file that the build does not know is a common cause of a failed Verify.
- When the public interface or the behavior changes, update the affected samples and
  READMEs in the project, and in the workspace worktree the project's docs
  (`docs/<name>/spec.md` and the other files in `docs/<name>/` that describe it). When
  the way the projects work together changes, update `docs/overview.md`. List these
  updates under "What changed".
- When a project of the request uses another project of the request (a new API of
  SSLib that SSDisp calls), the projects refer to each other as their build defines
  it. Do not change how the build finds a neighbor project unless the spec says so.
- Do not change a version (except on a hotfix branch, see below). Do not touch other
  requests' files.
- Do not tick the acceptance criteria. They are ticked during Verify and Review, when
  they have actually been checked.
- Note every agent behavior file that you change, in the workspace or in a project:
  `AGENTS.md`, `CLAUDE.md`, a file under `.claude/`, a `SKILL.md` or a file in its
  folder, or a path in `agent-files` (see "Working agreement" in the root
  `AGENTS.md`). Before you change one, be sure how an agent behaves with the current
  text, because Step 4 asks for it.

## Step 3: Check your work

1. Try `build-command` in each project of the request. Fix every compile error that
   your changes caused.
2. Bring the branches up to date. For each project with a remote, run
   `git fetch` first. If the project's develop branch has new commits (for a hotfix:
   its main branch), merge it into the project branch
   (`git merge origin/<develop-branch>`, or `git merge <develop-branch>` without a
   remote), resolve the conflicts, and try the build again. Do the same for the
   workspace branch with `develop` (for a hotfix: the workspace main branch). Do not
   rebase: the branches may be pushed.
3. Read your own diff in each project (`git -C <path> diff <project base>...HEAD`) for
   leftover debug code, unrelated changes, and missing files. Because nothing was
   run, also read it once more for logic errors, as a reviewer would. Read the
   workspace diff too (`git diff <workspace base>...HEAD`, leaving out the request
   file and the gitlinks): the docs must match what the code now does.

If something cannot be finished, do not hand the request over as complete. Report what
is missing, and ask whether to continue, to change the spec, or to split the rest into
a new request.

## Step 4: Hand over and remove the worktrees

1. Add an implementation summary to `## Notes`:

   ```markdown
   ### Implementation summary (yyyy-MM-dd)
   - What changed: <per project, and the workspace files, or "workspace files: none">
   - Architecture: as in the spec / changed with the developer's decision in Q<n>
   - Ran in the worktree: <each command that ran, with its project and `passed` or `failed (<reason>)`; "nothing" if none ran>
   - Did not run: tests, scripts, and executables (left to Verify); <the build of a project, if it did not run: `not configured` / `could not run (<reason>)`>
   - Not done: <acceptance criteria or parts of the spec that are not implemented, with the reason; or "none">
   - Verify: <commands, test projects, and scripts to run in the root checkout, per project>
   - Review by hand: <what the developer needs to look at or try, and how to start it>
   - Follow-ups: <out-of-scope findings, if any>
   ```

   Write every line from what happened in these worktrees, not from what you expect.
   "Ran in the worktree" lists only commands that you ran and whose output you saw. A
   build that failed is `failed`, also when you think that the cause lies outside the
   request. Keep all the lines: write "none" or "nothing" where that is the fact.

   If a branch changes an agent behavior file
   (`git -C <path> diff --name-only <project base>...HEAD` for each project, and
   `git diff --name-only <workspace base>...HEAD` for the workspace, compared with the
   list in "Working agreement"), also add the entry that "Results and behavior
   changes" in `reqs/AGENTS.md` describes, with one item for each such file:

   ```markdown
   ### Behavior changes (yyyy-MM-dd)
   - `<path>`
     - Diff: <the changed lines, quoted. For a long change: `git -C <project path> diff <base>...<branch> -- <file>`>
     - Before: <what an agent did, and in which situation>
     - After: <what an agent does now>
   ```

   Describe behavior, not the edit: "Before: the agent pushed after every commit.
   After: it asks before the first push", and not "reworded the push rule". If a
   change does not alter any behavior (a typo, a renamed heading that nothing looks
   up), say exactly that for the file. List these items under "Review by hand" too:
   no build or test proves them.

2. Set `status: review` in the request file. Stage it together with the gitlink of
   each project of the request (`git add reqs <path>...`), so that the commit records
   the project commits that go to review. Commit and push:

   ```
   chore(reqs): mark REQ-0012 for review

   Refs: REQ-0012
   ```

   Check that the gitlinks match: `git rev-parse HEAD:<path>` equals
   `git -C <path> rev-parse HEAD` for each project of the request.
3. Confirm that nothing would be lost with the worktrees, in the workspace worktree
   and in each project worktree:
   - `git status --porcelain` is empty. Untracked files that matter must be committed
     first. In the workspace worktree it is empty only when every project is clean
     and at its gitlink.
   - When pushing is allowed for that repository: `git log origin/<branch>..HEAD
     --oneline` is empty.
   - When nothing is pushed (no remote, `push-policy: never`, or the developer
     declined): the commits stay on the local branch, which survives the worktree.
     The project branches live in the root checkout's `.git/modules/<path>`. Check
     that each branch exists (`git rev-parse --verify <branch>`, and
     `git -C <root>/<path> rev-parse --verify <branch>`) and that `HEAD` of each
     worktree is its tip, and keep the list of unpushed commits for the report.

   Do not remove the worktrees until these hold.
4. Remove the worktrees and keep the branches. Run this from the root checkout, not
   from inside a worktree, in this order:

   ```bash
   git -C <root>/<path> worktree remove <worktree path>/<path>     # each project, also the detached ones
   git -C <worktree path> restore <path>                           # put back the empty folder
   git -C <root> worktree remove <worktree path>                   # the workspace worktree last
   ```

   Git refuses to remove the workspace worktree while it still holds a project
   worktree, and removing a project worktree deletes its folder, which the workspace
   sees as a deleted gitlink until `restore` puts the empty folder back.

   If a folder cannot be deleted because it is in use (this session's working
   directory, an editor, or Visual Studio), say so. The developer can close those
   programs and delete it later, and `/ss-workflow:check-req` reports a leftover
   worktree in its overview. Do not use `--force` without asking.
5. Report to the developer, in `discussion-language`:
   - What was implemented, criterion by criterion and per project, and what was not
     done
   - What ran in the worktrees, with its result, and what did not run and why
   - That nothing was tested or run yet
   - The behavior changes, if the request changed agent behavior files
   - The questions in `## Q&A` that are still pending, if any
   - That the worktrees are removed, and which branches hold the work
   - Per repository, whether the branch is on the remote, or which commits the
     developer still has to push
   - The next step: `/ss-workflow:review REQ-0012` in the root checkout starts Verify
     and Review

Do not merge. The request now waits in `review` until the developer starts the review.

## Hotfix differences

A hotfix names one project. The workspace branch `hotfix/<name>-v<version>` starts
from the workspace main branch, and the project branch `hotfix/v<version>` from the
project's main branch. The other projects are detached at the workspace main branch's
gitlinks, which are their latest releases.

- The claim commit copies the request file from `develop` onto the workspace hotfix
  branch. After that, the file is handled like any other request file: its status and
  its notes are committed on the workspace hotfix branch.
- Set the hotfix version in the project's `version-source` on the project hotfix
  branch as its own commit: `chore(release): bump version to <version>`. Skip this if
  `version-source` is `none`. If the workspace docs state the project's current
  version (`docs/<name>/`, `docs/overview.md`), update them on the workspace hotfix
  branch: `docs(<name>): update the version to v<version>`.
- Step 3.2 merges the main branches, not the develop branches. The diff base is the
  project's main branch.
