---
name: new-req
description: Create a new request (feature, fix, docs change, hotfix) in an ss-workflow repository. Opens the request branch in the root checkout, writes the request file, discusses with the developer a spec detailed enough that every implementer builds the same thing, has it cold-read by a fresh subagent, and on approval starts the implementation right away or keeps the request ready on its branch. Use when the developer asks to add a request, requirement, feature, or bug fix to the workflow, hands over a requirement .md file, or wants to continue a draft request.
argument-hint: "[requirement.md | REQ-id | short description]"
---

# new-req

Discuss one request on its own request branch, `<type>/REQ-<id>-<slug>`, in the root
checkout. The same branch later carries the implementation and the review, and
reaches `develop` only with the merge. When the developer approves the spec, start
the implementation right away through `/ss-workflow:check-req`, or keep the request
`ready` on its branch for later. This skill writes the request. It never implements
it itself.

Input: `$ARGUMENTS`

## Ground rules

- Read the root `AGENTS.md` ("Workflow settings", "Working agreement") and
  `reqs/AGENTS.md` first. `reqs/AGENTS.md` is the source of truth for the file name,
  the frontmatter, the parts of the spec, and the lifecycle. If it differs from this
  skill, follow it. If it has no "Spec" section (a workspace that is not upgraded to
  ss-workflow 0.11.0 yet), read that section from
  `${CLAUDE_PLUGIN_ROOT}/skills/init/templates/reqs-AGENTS.md`, follow it, and suggest
  `/ss-workflow:init` to upgrade the workspace in the report.
- Talk to the developer in `discussion-language`. Write the request in `reqs-language`.
  Keep the headings `## Spec`, `## Original`, `## Q&A`, and `## Notes` in English,
  because other skills look them up.
- This skill runs in the root checkout of the workspace, not in a worktree.
- Until the approval, the request branch changes only its own request file. Nothing
  is committed in the project repositories.
- One request per request branch.
- Never edit the `## Original` section after it is written.
- A request is approved only after the developer explicitly approves the spec.
- Commit the request file three times at most: when the draft is created (this
  reserves the id), when the developer pauses the draft, and when the developer
  approves it. Between those, the discussion only changes the file in the working
  tree.
- Every question that you ask the developer about the request, and its answer, goes
  into `## Q&A`, as "Questions and answers" in `reqs/AGENTS.md` describes.
- **Pushing**: follow "Remote and pushing" in the root `AGENTS.md`. Where this skill
  says "push", push only when a remote exists and `push-policy` allows it: `auto`
  pushes, `ask` asks before the first push of this run, and `never` does not push. A
  missing `push-policy` means `auto`. Steps that fetch or pull apply only with a
  remote. When a push is skipped, go on, and list the unpushed branches in the report.
- Commit messages are English and follow the root `AGENTS.md` section
  "Commit convention".

## Step 1: Preconditions

1. If the root `AGENTS.md` has no `ss-workflow-version:`, stop and tell the developer to
   run `/ss-workflow:init` first. If the version is below `0.6.0`, the repository has
   the single-repository layout: stop, and point to `/ss-workflow:init`, which
   converts it into a workspace.
2. If this is a linked worktree (`git rev-parse --git-dir` and `--git-common-dir`
   give different paths), stop. Explain that spec discussions run in the root
   checkout.
3. If a remote exists, run `git fetch --prune`.
4. Check the current branch with `git branch --show-current`:

| Current branch | Action |
|----------------|--------|
| `develop` | Check that `git status --porcelain` shows no changes. If it does, stop and report them: for a project (` M projects/<name>`), `git -C projects/<name> status --porcelain` and `git -C projects/<name> branch --show-current` tell what it is. A project on a `release/*` branch means that a release is open. With a remote, run `git pull --ff-only` and `git submodule update`. Continue with Step 2. |
| A request branch whose request file says `draft`, or a `req/REQ-…` branch from before ss-workflow 0.8.0 | A spec discussion is open here. If `$ARGUMENTS` is empty or names this request, resume it at Step 5. Otherwise, ask whether to pause this draft first (commit it, push it, and switch to `develop`). |
| Any other branch | The root checkout is busy: a request or hotfix branch in another status means a review. Say which one, and stop. |

## Step 2: Decide what to do with the input

| `$ARGUMENTS` | Action |
|--------------|--------|
| A `REQ-xxxx` id | Find its request branch (a local or remote branch whose name contains `REQ-xxxx-`), or a `req/REQ-xxxx-…` branch from before ss-workflow 0.8.0. Read the status in its request file. `draft`: check it out, pull it, and resume at Step 5. `ready`: say so, and ask what the developer wants to change; to change it, check out the branch, set `status: draft`, and continue at Step 5, so that it is approved again. Any later status: the spec is approved and the work has started; point to `/ss-workflow:check-req` (`in-progress`) or `/ss-workflow:review` (`review`). A `ready` request in `reqs/` on `develop` without a branch (from before 0.8.0) is changed on a new request branch with the same id. |
| A path to a `.md` / text file | Read it. Its full content becomes `## Original`, verbatim. |
| Free text | That text becomes `## Original`, verbatim. |
| Empty | List the open drafts: the request branches, local and remote, whose request file says `draft` (and `req/*` branches from before 0.8.0), each with its title. Ask whether to continue one of them or to create a new one. For a new one, ask the developer to describe what they need. Their answer becomes `## Original`. |

Then check the following:

- **Several requests in one input**: if the input describes changes that can be
  implemented and reviewed independently, propose splitting it, and ask. Handle the
  resulting requests one after another: finish this skill for the first one, then
  start again for the next one with its part of the original text.
- **Duplicates**: compare with the titles and specs of the requests on the request
  branches (any status), the requests in `reqs/` on `develop` from before 0.8.0, and
  the titles in `reqs/done/`. If one overlaps, show it and ask whether to extend that
  request (only if it is still a draft, or `ready` and not started), create a
  follow-up, or continue.

## Step 3: Open the request branch

1. **id**: the highest id in use, plus 1. Use `REQ-0001` when none is in use. An id is
   in use when:
   - a file in `reqs/` or `reqs/done/` on `develop` has it, or
   - a branch name contains it: `git branch -a --list "*REQ-*"`.
2. **type**: infer it from the content (`feat`, `fix`, `docs`, `refactor`, `perf`,
   `test`, `chore`). Use `hotfix` only when the problem affects a released version and
   cannot wait for the next release. Confirm `hotfix` with the developer.
3. **title**: a short imperative phrase. **slug**: lowercase English kebab-case, at
   most five words, that names the change (`gui-button`). The project branch takes
   it too (`feat/gui-button`), so it must make sense in the project's history, where
   the request id never appears.
4. **priority**: `normal`, unless the developer says otherwise. Use `high` for
   `hotfix`.
5. Create the request branch, and push it after the first commit (Step 4). The local
   branch reserves the id for the other sessions in this repository, and the pushed
   branch reserves it for other machines:

   ```bash
   git checkout -b <type>/REQ-<id>-<slug> develop
   ```

   If the remote now has another branch with the same id (fetch and list again),
   another session took the id at the same time. Rename your branch to the next free
   id (`git branch -m`, delete the wrong remote branch, and push again).

   If the branch is not pushed, the id is reserved in this repository only. Another
   machine may take the same id in the meantime. This shows at the next fetch, or when
   the developer pushes. Then renumber the newer request: the branch, the file name,
   and `id`.

## Step 4: Create the draft file

1. Write `reqs/REQ-<id>-<yyyyMMdd>-<slug>.md` in the format from `reqs/AGENTS.md`,
   with `status: draft`, an empty `branch:` and `project-branch:`, and today's date
   in `created`. `/ss-workflow:check-req` fills in `branch` and `project-branch`
   when the request is started.
   `projects` holds the projects that the input names or clearly means, by their
   `name` in "Workflow settings", and `[]` when it is not clear yet. The spec
   discussion settles it.
2. Put the original input into `## Original`, byte for byte. If the input came from a
   file, add one line above it: `Source: <original path>`. `## Q&A` starts empty, apart
   from its comment.
3. If the source file is inside the repository (for example, the developer dropped it
   into `reqs/`), ask whether to delete it on this branch now that its content is
   preserved in `## Original`. Leave files outside the repository alone.
4. Commit, and push the branch (`git push -u origin <branch>`, when pushing is
   allowed), so that the draft and its id are not lost:

   ```
   docs(reqs): add draft REQ-0012 gui button modification

   Refs: REQ-0012
   ```

## Step 5: Understand the context

Before you ask the developer anything, read what the request touches:

- `docs/overview.md`, and for each affected project its docs in `docs/<name>/` (at
  least `spec.md`), its section in `projects/AGENTS.md`, and its own `README.md`. Do not
  read the docs of every project: only those of the projects that the request
  touches or uses.
- The relevant source files, enough to know what exists today. The root checkout has
  each project at the commit that `develop` records, which may be behind the
  project's develop branch. Read the latest one without checking anything out:
  `git -C projects/<name> fetch`, then `git -C projects/<name> show
  origin/<develop-branch>:<file>` (or `git -C projects/<name> grep <pattern>
  origin/<develop-branch>`).
- Related requests in `reqs/` and `reqs/done/`

Do not ask the developer questions that the repository already answers.

When you continue a draft, read its `## Q&A` first, and start with the entries that
are still pending. A draft from an older ss-workflow version may lack the section, and
may have an "Open questions" part in its spec:

- Add `## Q&A` between `## Original` and `## Notes`.
- Turn each open question into an entry with `A: (pending)` and today's date, and
  remove the "Open questions" part.
- Leave earlier decisions in `## Notes` where they are. Do not turn them into entries.
- A draft from before the workspace layout lacks `projects`: add it after `type:`.
- A draft from before ss-workflow 0.11.0 has no "Detailed design": add the part after
  "Architecture", and write it during the discussion. Rewrite any program code in its
  spec as tables and plain sentences ("No code" in "Spec" of `reqs/AGENTS.md`).
- A draft on a `req/REQ-<id>-<slug>` branch (from before ss-workflow 0.8.0): rename
  the branch to `<type>/REQ-<id>-<slug>` (`git branch -m`; with a remote, push the
  new name and delete the old one when pushing is allowed), and add
  `project-branch:` after `branch:` in the file.

## Step 6: Discuss and write the spec

### What the spec settles

Write `## Spec` as "Spec" in `reqs/AGENTS.md` describes: its standard, the rule
"No code", the parts, and the sections of "Detailed design". The standard is the test
for every part: anyone who implements the spec from the spec and the repository
alone, a senior engineer, a junior engineer, or another agent, builds almost the same
thing. The spec settles everything that the developer or a user sees or uses
("Scope"), the software architecture ("Architecture"), and every decision below it on
which two implementers could reasonably differ ("Detailed design"). Only what
"Left to the implementation" names is decided in the code.

The spec contains no program code and no pseudo-code. Describe types, members, and
flows in tables and plain sentences, and write every name out. Examples of data
formats and of commands that a user types are the only code blocks allowed.

The spec also settles `projects` in the frontmatter: every project that the request
changes. A project that the request only needs to read (a dependency that does not
change) is not listed. `projects: []` is right only when the request changes
workspace files and nothing else, for example a knowledge base article, a change to
`docs/overview.md`, or to a `## Project: <name>` section in `projects/AGENTS.md`. Such a
request has no project branches, and Verify has nothing to run for it, so "How to
verify" names the Review for every criterion. Managed blocks, `ss-workflow-version`,
`.gitmodules`, and the `projects` entries are not changed by a request (see
"Workspace and projects" in the root `AGENTS.md`): point to an ss-workflow upgrade or
`/ss-workflow:init --add` instead.

For `type: hotfix`, `projects` names exactly one project. Also state the affected
released version of that project and the hotfix version: the next patch version
after the highest final version tag that the project's main branch contains (`git -C
projects/<name> tag -l "v*" --merged origin/<main-branch>`, without prerelease tags,
compared as versions), in the form that "Versioning" in the root `AGENTS.md`
describes. The main branch can contain alpha and beta tags through the develop
branch, so the nearest tag (`git describe`) is not always the released version.

### How to start

Look at `## Original`:

- It says what to build: draft the spec, and go to "Rounds".
- It only describes a need or a problem, without a way to solve it: explore first.
  1. Ask about the problem itself, and only what the repository does not answer: who
     needs this, what they do today, what is wrong with that, and which limits apply
     (compatibility, performance, hardware, time).
  2. Propose two or three ways to solve it, from what you read in the code. For each
     one, say how it works for the user, its architecture in a few lines, what it
     affects, and its cost and risks. Recommend one, and say why. Ask with
     AskUserQuestion, with the recommended one first.
  3. Draft the spec from the way that the developer chose or changed.

### Architecture

Propose the architecture yourself, from the existing code. Do not ask the developer to
design it. If more than one structure is reasonable, show the alternatives with their
trade-offs, and recommend one. The developer confirms the architecture, like the rest
of the spec.

### Detailed design

Write the detailed design yourself, from the architecture and the existing code, once
the developer agrees with the architecture:

- Read the code that the change touches, and follow its conventions: where files of
  this kind live, how types and members are named, how errors are reported, how
  tests are named. A new name follows the names around it.
- Fill in every section that "Spec" in `reqs/AGENTS.md` lists, in its order. Walk
  through every acceptance criterion, and check that "File changes", "Types and public
  members", "Flows", "Errors and edge cases", and "Tests" together show how it is met.
- Do not ask the developer about each name or row. The developer reads the detailed
  design with the rest of the spec, and changes what they want. Ask a question only
  where the code does not decide and the choice changes behavior, or where the
  reasonable options differ in a way that the developer would care about (an
  exception or an error code, a new dependency, a stored format).
- Keep the size in proportion: a one-line fix gets a few lines, a new feature gets
  tables. Never leave a section out: write "None" in one line when it has nothing.

### When the developer does not know

If the developer cannot answer a question, do not decide it silently. Propose a
default, and say why. If the developer accepts it, write it into the spec, complete
the entry in `## Q&A` (the answer says that the developer accepted the proposed
default), and record it in `## Notes` as
`Assumption (yyyy-MM-dd): <what>, because <why>`, so that it is checked again in the
Review.

A question that only somebody else can answer, or that the developer wants to answer
later, stays in `## Q&A` with `A: (pending)`. The request stays a draft until it is
answered.

### Rounds

Go through these rounds with the developer:

1. Show the draft spec, and ask only the questions whose answers change what gets
   built. Use AskUserQuestion when the answer is a choice between options. Ask in plain
   text when the answer is free-form.
2. Update the file after each round:
   - Add each question of this round to `## Q&A`, with the answer in the developer's
     own words and the decision that follows from it. Add a question that got no
     answer with `A: (pending)`.
   - Complete the pending entries that were answered in this round. Do not change an
     entry that already has an answer: a changed decision is a new entry.
   - Write the decisions into `## Spec`.

   Do not commit after each round. The file stays changed in the root checkout until
   the developer pauses or approves (Step 7).
3. Flag what the developer may not have considered: breaking changes, effects on other
   projects or samples, missing tests, and documentation that would need updating.
4. If the request turns out to be too large for one branch, propose splitting it
   (Step 2).

`## Q&A` holds the questions and the decisions. Use `## Notes` for what is not an
answer to a question: assumptions, and facts found in the code that explain a choice,
each with the date.

### Cold read

When `## Q&A` has no pending entry and every part of the spec is written, check the
standard with a reader who did not take part in the discussion:

1. Save the request file in the working tree (it is not committed yet).
2. Start a new subagent with the Agent tool: a fresh agent (general-purpose), not a
   fork, so that it knows nothing of this discussion. Give it:
   - the path of the request file, with the instruction to read `## Spec` only, and
     not `## Original`, `## Q&A`, or `## Notes`: the spec has to stand on its own
   - the paths of the projects of the request, and how to read their latest code
     without checking anything out (`git -C projects/<name> show
     origin/<develop-branch>:<file>`, `git -C projects/<name> grep <pattern>
     origin/<develop-branch>`), and the path of `reqs/AGENTS.md`, whose section "Spec"
     is the standard
   - the task: "Read the spec as the engineer who has to implement it, and do not
     implement anything or change any file. List every place where you would have to
     guess or choose, or where two engineers could build different things: a missing
     or vague file, type, member, parameter, type of a value, data layout, step of a
     flow, thread, error behavior, setting, dependency, or test; a word that leaves a
     decision open; a contradiction between parts of the spec, or between the spec and
     the code (a name, file, or member that the spec assumes and the code does not
     have); a section of 'Detailed design' that is missing; and any program code or
     pseudo-code in the spec. For each finding, give the part of the spec, what is
     unclear, and the options that you see. Report 'No findings' if there are none."
3. Go through the findings yourself. For each one:
   - The code or the existing conventions answer it: fix the spec.
   - It needs the developer's decision: ask it in the next round, and record it in
     `## Q&A` as usual.
   - It is not a real gap (the spec answers it, and the reader missed it): say why
     when you show the findings.
   - The developer wants to leave it open: add it to "Left to the implementation".
4. Show the developer the findings and what you did with each.
5. If the spec changed, run the cold read again with a new subagent. List for it the
   findings that are already settled, so that it does not report them again. Stop
   when a run brings no finding that is a real gap. After the third run with real
   gaps, show the ones that are left, let the developer decide on each of them, and
   write the decisions into the spec. The cold read ends there.
6. Record the result in `## Notes`:

   ```markdown
   ### Cold read (yyyy-MM-dd)
   - Runs: 2
   - Findings: 7 (spec fixed: 4; asked: Q5, Q6; not a gap: 1, <why>)
   - Left open by the developer: <findings added to "Left to the implementation", or "none">
   ```

If no subagent can be started, check the spec yourself against the task above, item
by item, and record `- Did not run (<reason>); self-check instead`, with the
findings, in the same entry. Say so to the developer before the approval.

## Step 7: Approval

When `## Q&A` has no pending entry, "Architecture" and "Detailed design" are filled
in, `projects` names at least one project (or is `[]`, and "Scope" changes workspace
files only), and the last cold read (Step 6) left no real gap open, show the final
spec and ask with AskUserQuestion. A cold read counts only when `## Spec` has not
changed since it ended: after a later change (in a later round, or through "Other"),
run it again first. While entries are pending, list them, and offer only "Keep as draft"
and "Discard". The developer can ask for more changes through "Other": then go back
to Step 6.

| Option | Action |
|--------|--------|
| Approve and start now (Recommended) | Step 8, then Step 9. |
| Approve, start later | Step 8, then Step 10. |
| Keep as draft | Commit the file (`docs(reqs): update draft REQ-0012`, with `Refs: REQ-0012`) and push. Switch the root checkout back to `develop` (`git submodule update`). The branch keeps the draft, and the developer continues later with `/ss-workflow:new-req REQ-0012`. Then go to Step 10. |
| Discard | Confirm once more, because the draft and its original text are deleted. Then switch to `develop`, delete the branch (`git branch -D`, and `git push origin --delete` if it is on the remote and pushing is allowed), and go to Step 10. Nothing reaches `develop`. |

## Step 8: Approve

1. If `type` changed during the discussion, the branch name no longer matches. Rename
   it: `git branch -m <type>/REQ-<id>-<slug>`; with a remote, push the new name and
   delete the old one when pushing is allowed.
2. Set `status: ready`. Commit and push:

   ```
   docs(reqs): approve REQ-0012

   <one or two sentences that summarize the goal>

   Refs: REQ-0012
   ```

3. Switch the root checkout back to `develop`, then `git submodule update`. The
   request stays on its branch: `develop` gets it with the merge.

## Step 9: Start the implementation

Invoke the `check-req` skill (`/ss-workflow:check-req REQ-0012`). It starts the
request: it records the start on the request branch, creates the project branches
and the worktrees, and implements the request there. Do not create branches or
worktrees yourself here.

If the skill cannot be invoked, tell the developer to run
`/ss-workflow:check-req REQ-0012`, and go to Step 10.

## Step 10: Report

Tell the developer, in `discussion-language`:

- The request id, title, type, projects, priority, and status
- Its branch, and whether the implementation started, waits as `ready`, is a draft,
  or was discarded
- The questions that are still pending in `## Q&A`, for a draft
- The cold read: how many runs, and what was left open, or that it did not run and why
- What is not on the remote yet: the branches that were not pushed
- That the root checkout is back on `develop`
- The next step: `/ss-workflow:check-req REQ-0012` starts a `ready` request, and
  `/ss-workflow:new-req REQ-0012` continues a draft
