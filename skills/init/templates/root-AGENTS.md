# {{PROJECT_NAME}}

{{PROJECT_DESCRIPTION}}

## Workflow settings

This repository is an ss-workflow workspace. The ss-workflow skills read the values
below; edit them here when they change.

```yaml
ss-workflow-version: {{SS_WORKFLOW_VERSION}}
initialized: {{INIT_DATE}}
workspace-name: {{PROJECT_NAME}}
discussion-language: {{DISCUSSION_LANG}}
readme-languages: {{README_LANGS}}
agent-doc-language: {{AGENT_DOC_LANG}}
reqs-language: {{REQS_LANG}}
docs-language: {{DOCS_LANG}}
main-branch: {{MAIN_BRANCH}}
remote-platform: {{REMOTE_PLATFORM}}
remote-cli: {{REMOTE_CLI}}
merge-method: {{MERGE_METHOD}}
push-policy: {{PUSH_POLICY}}
agent-files:
projects:{{PROJECTS}}
```

The settings above `projects` belong to this workspace repository. `remote-platform`,
`merge-method`, and `push-policy` are also the defaults for every project.

`projects` lists the projects of the workspace. Each project is a git submodule, and
every entry has these keys:

| Key | Meaning | When it is empty |
|-----|---------|------------------|
| `name` | The project name, used in branch and tag names (`<name>/v1.2.0`) | Required |
| `path` | The submodule path, `src/<name>` | Required |
| `main-branch`, `develop-branch` | The project's long-lived branches | Required |
| `project-type` | The project type and toolchain, in the developer's words | Required |
| `project-kind` | `library` or `application` | Required |
| `project-file` | The main solution, workspace, or top-level build file, relative to `path` | The project has none |
| `version-source` | The file and the field that hold the project's version, relative to `path` | `none`: the version only exists as a git tag |
| `setup-command` | What a fresh checkout or worktree needs before it can build | Nothing is needed |
| `build-command` | Compiles the project from a shell | The step is skipped and reported as "not configured" |
| `test-command` | Runs the automated tests | The step is skipped and reported as "not configured" |
| `verify-command` | An extra verification script that `/ss-workflow:review` runs after the build and the tests | No extra script |
| `remote-platform`, `merge-method`, `push-policy` | Overrides for this project's repository | The workspace value |

The commands run in the project folder (`path`). `push-policy` (`auto`, `ask`, or
`never`) is explained in "Remote and pushing". `agent-files` lists extra paths, as glob
patterns separated by commas, whose files tell an agent how to behave, for example
prompt files that a product ships (`src/<name>/...`). It adds to the built-in list in
"Working agreement", and it may stay empty.

<!-- ss-workflow:managed id=working-agreement -->
## Working agreement

- Discuss with the developer in `discussion-language`; keep technical terms in English.
- Agent-facing docs (AGENTS.md, CLAUDE.md) use `agent-doc-language`.
- Request files (`reqs/`) use `reqs-language`; developer docs (`docs/`) use `docs-language`.
- All work starts from a request in `reqs/`. Do not implement features or fixes that
  have no request. If the developer asks for something directly, offer to create a
  request first with `/ss-workflow:new-req`.
- Where each kind of work happens:

  | Work | Where | Skill |
  |------|-------|-------|
  | Spec discussion | Root checkout, on a `req/REQ-…` branch | `/ss-workflow:new-req` |
  | Implementation | A worktree of the workspace, with a worktree of each project of the request inside it | `/ss-workflow:check-req` |
  | Verify (build, tests, scripts) and Review (the developer's manual check) | Root checkout, on the request branch in the workspace and in each project | `/ss-workflow:review` |
  | Merge and release | Root checkout | `/ss-workflow:merge`, `/ss-workflow:release` |

- The root checkout is the workspace's primary working tree. Its home branch is
  `develop`, with each project checked out at the commit that `develop` records. A
  skill that switches it to another branch first checks that it is on `develop` with
  no uncommitted changes, in the workspace and in the projects, and returns it to
  `develop` (then `git submodule update`) when it is done. Only one of these
  activities uses the root checkout at a time.
- In a worktree, write code and try to compile it: run the project's `setup-command`
  if the worktree needs it, then its `build-command`. Do not run tests, scripts, or
  executables there. If a command is empty or cannot run in the worktree, note that in
  the request and leave it to Verify.
- Follow the section `## Project: <name>` in `src/AGENTS.md` for each project that you
  change, and the project's own `AGENTS.md`, `CLAUDE.md`, and README, if it has them.
  They hold what is specific to that project's toolchain.
- Report results as they are. Every report to the developer and every result written
  into a request says what ran and passed, what ran and failed, and what did not run
  and why. A check that did not run is never reported as passed, and neither is one
  that only "should" pass.
- Agent behavior files are the files that an agent reads as instructions: `AGENTS.md`,
  `CLAUDE.md`, everything under `.claude/` except `.claude/worktrees/`, a `SKILL.md`
  and the files in its folder (in the workspace and in every project), and the paths
  in `agent-files`. A change to one of them changes how agents behave, and no build or
  test shows that. A request that changes one records the behavior before and after
  (see `reqs/AGENTS.md`), and the developer confirms it in the Review.
<!-- /ss-workflow:managed -->

## Repository layout

<!-- Written during initialization, and maintained by the developer. ss-workflow
     upgrades never modify this section. -->

| Path | Purpose | Rules |
|------|---------|-------|
| `reqs/` | Requests: one Markdown file per request; finished requests live in `reqs/done/` | `reqs/AGENTS.md` |
| `docs/` | Project specs, developer-readable docs, knowledge base | Write for humans in `docs-language` |
| `src/<name>/` | One git submodule per entry in `projects`, in the project's own layout | `src/AGENTS.md` |

<!-- ss-workflow:managed id=workspace -->
## Workspace and projects

The workspace holds the requests and their history. Each project keeps its own
repository, layout, branches, and versions, and is a git submodule at its `path`.

- A project repository only receives implementation commits: code, tests, and
  version numbers. Request files, spec discussions, and review results are committed
  in the workspace only.
- Init writes nothing into a project repository. The workflow's rules for a project
  live in `src/AGENTS.md`. If the project's `.gitignore` misses build output, report
  it and suggest a request; do not change it outside a request.
- A request names its projects in `projects`. Its branch has the same name in the
  workspace and in each of those projects (a hotfix is the exception, see "Branching
  model").
- Gitlinks (the commit of each project that the workspace records):
  - `develop` records each project's `develop-branch`; `main-branch` records each
    project's `main-branch`, that is, its latest release.
  - On a request branch, every commit that records a result (the hand-over for
    review, a review result, the close) also stages the gitlinks of the request's
    projects, so the workspace records which project commit was reviewed.
  - A project's `develop-branch` may move without the workspace, when other people
    commit to that repository. `git -C <path> rev-list --count <gitlink>..<project
    develop-ref>` shows how far `develop`'s gitlink is behind. Offer a commit
    `chore(workspace): update <name> to <short sha>` on `develop`; the developer
    decides.
- Worktrees of a request:
  - The workspace worktree: `git worktree add --no-track -b <branch>
    .claude/worktrees/<branch with "/" replaced by "-"> <develop-ref>`.
  - Each project of the request, inside it:
    `git -C <root>/<path> worktree add --no-track -b <branch> <worktree>/<path>
    <project develop-ref>`. Its commits are stored in the root checkout's
    `.git/modules/<path>`, so they survive the removal of the worktree.
  - Every other project: `git -C <root>/<path> worktree add --detach
    <worktree>/<path> <gitlink>`, because a build may refer to a neighboring project.
    Nested submodules of a project: `git -C <worktree>/<path> submodule update --init
    --recursive`.
  - Removal, in this order and without `--force`: each project worktree
    (`git -C <root>/<path> worktree remove <worktree>/<path>`, then
    `git -C <worktree> restore <path>` to put back the empty folder), then the
    workspace worktree (`git worktree remove <worktree>`). Git refuses to remove a
    workspace worktree that still holds a project worktree.
- Clean means: `git status --porcelain` of the workspace is empty. It shows ` M <path>`
  for a project with new commits, changed files, or untracked files alike;
  `git -C <path> status --porcelain` tells which.
- A project added from a local path without a remote has the developer's working copy
  as its `origin`. Pushing into it fails for the branch that the working copy has
  checked out, so such a project uses `push-policy: never`, and git needs
  `-c protocol.file.allow=always` to clone it as a submodule.
<!-- /ss-workflow:managed -->

<!-- ss-workflow:managed id=branching -->
## Branching model

Both layers follow gitflow. The workspace has `main-branch` and `develop`; each
project has its own `main-branch` and `develop-branch`.

| Branch | Workspace | Project | Name example | Worktree |
|--------|-----------|---------|--------------|----------|
| Spec discussion `req/*` | From and into `develop` | (none) | `req/REQ-0012-gui-button` | No |
| Request (`feat`, `fix`, `docs`, `refactor`, `perf`, `test`, `chore`) | From and into `develop` | Same name, from and into `develop-branch` | `feat/REQ-0012-gui-button` | During implementation only, under `.claude/worktrees/` |
| Release | No branch: `develop` is merged into `main-branch` and tagged `<name>/v<version>` | `release/v<version>`, from `develop-branch`, into `main-branch` and `develop-branch`, tagged `v<version>` | `release/v1.0.0-beta1` | No |
| Hotfix | `hotfix/<name>-v<version>`, from `main-branch`, into `main-branch` and `develop` | `hotfix/v<version>`, from `main-branch`, into `main-branch` and `develop-branch` | `hotfix/SSDisp-v1.0.1`, `hotfix/v1.0.1` | During implementation only, under `.claude/worktrees/` |

- A `req/*` branch only changes one request file. It is merged into `develop` when
  the developer approves the spec.
- Creating the workspace request branch claims the request. The project branches are
  created only after the claim commit is accepted, so a lost claim leaves nothing in
  the projects. When the implementation is finished, the worktrees are removed and
  the branches are kept for Verify and Review.
- A request is merged project by project, and the workspace last: each project branch
  into its `develop-branch`, then the close commit on the workspace branch with the
  gitlinks of those merge commits, then the workspace branch into `develop`. A run
  that stopped halfway (a merge request that waits, a protected branch) continues
  where `git merge-base --is-ancestor` shows that it stopped.
- `main-branch` of a project receives commits only when a version of that project is
  released. The workspace `main-branch` receives a merge of `develop` with every
  project's release: in that merge commit, each project's gitlink is set to its
  `main-branch` (`git update-index --cacheinfo 160000,<sha>,<path>`), which also
  resolves gitlink conflicts. So the workspace `main-branch` is the set of the latest
  released projects, with the request records of that time.
- Before a project's v1.0.0 is released, its `develop-branch` may be merged straight
  into its `main-branch` and tagged `v0.x.y`, which allows fast iteration. The
  workspace `main-branch` follows as for a release.
- `develop` is the integration branch; most changes land here through request branches.
- Never force-push a long-lived branch. Never rewrite published history.
- Before any merge, run `git fetch` in that repository if it has a remote, and check
  whether the branch was already merged there: `git merge-base --is-ancestor`, and
  with a remote platform also the merge request (`remote-cli`: `gh pr view` /
  `glab mr view`).
- `merge-method` decides how branches are merged: `local` (merge locally, then push),
  `remote` (open a merge request on the remote), or `ask` (ask every time). Without a
  remote platform, branches are always merged locally.
- Use `/ss-workflow:merge` to merge and `/ss-workflow:release` to release; do not merge
  long-lived branches by hand.
<!-- /ss-workflow:managed -->

<!-- ss-workflow:managed id=remote -->
## Remote and pushing

The workflow does not need a remote. Each repository, the workspace and every
project, has a remote when its `git remote` lists `origin`. `remote-platform` answers
a different question: whether merge requests can be opened (`github`, `gitlab`). It
is `none` for every other remote, and when there is none. A project uses its own
`remote-platform`, `merge-method`, and `push-policy` when its entry in `projects` sets
them, and the workspace values otherwise.

- **Without a remote**, every step that fetches, pulls, or pushes is skipped in that
  repository, and everything else works as described: the local `develop` stands for
  `origin/develop`, creating the local branch is the claim, and branches are merged
  locally.
- **With a remote**, `push-policy` decides what the agent pushes:

  | `push-policy` | The agent |
  |---------------|-----------|
  | `auto` | Pushes the topic branches (`req/*`, request, `hotfix/*`, `release/*`) after every commit, and `develop` after a merge that the developer asked for. |
  | `ask` | Commits locally, and asks before the first push in a skill run. A yes covers the rest of that run. A no is treated like `never` for that run. |
  | `never` | Never pushes, and never deletes a remote branch. It still fetches and pulls. |

  A missing `push-policy` means `auto`.
- When a push is skipped, the skill goes on, and its report lists, per repository, the
  branches and tags that are not on the remote yet. Other machines see a request, a
  claim, or a status change only after the developer pushes it. Until then, a claim
  holds in this repository only.
- A merge request needs its branch on the remote. If the branch is not pushed, the
  skill stops before it opens the merge request, and says which branch to push.
- These rules hold for every value of `push-policy`:
  - Never force-push. Never rewrite published history.
  - Pushing a `main-branch` or a tag publishes a version. Ask the developer right
    before that push, every time.
  - Never delete a branch, local or remote, before its merge is confirmed
    (`git merge-base --is-ancestor`, or a merge request in the state "merged"). A
    branch with unmerged commits is deleted only after the developer says so for that
    branch.
  - If the remote refuses a push to `develop` or a `main-branch` (a protected branch),
    do not work around it. Open a merge request where `remote-platform` allows one.
    Otherwise, stop and tell the developer which branch has to be merged on the
    remote.
<!-- /ss-workflow:managed -->

<!-- ss-workflow:managed id=commits -->
## Commit convention

Commit messages are always in English, in the workspace and in every project.

```
<type>(<scope>): <subject>

<body>

<footer>
```

- **type** (required): `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`,
  `build`, `ci`, `chore`
- **scope** (optional): the area affected, such as a project name or layer
- **subject** (required): imperative mood, at most 50 characters, no trailing period
- **body**: wrap at 72 characters; explain what changed and why, and how the behavior
  differs from before
- **footer**:
  - In the workspace: `Refs: REQ-0012` when the commit belongs to a request
  - In a project: `Refs: <workspace-name>#REQ-0012`, because people outside this
    workspace may read the project's history
  - `BREAKING CHANGE: <what changed, why, and how to migrate>` for incompatible changes

Commit often while you implement. Each commit is one reason for change, not a
bundle of unrelated files. On request branches, push after every commit when
"Remote and pushing" allows it.

Merge commits are the exception to the header format. They are always created with
`--no-ff` and use the subject `Merge <source branch> into <target branch>`.
<!-- /ss-workflow:managed -->

<!-- ss-workflow:managed id=versioning -->
## Versioning

- Every project has its own version. A project that did not change is not released.
- A version is `X.Y.Z` for a final version, or `X.Y.Z-<stage><R>` for a prerelease,
  for example `1.2.0` or `1.0.0-beta1`. `X`, `Y`, and `Z` are MAJOR, MINOR, and PATCH,
  each from 0 to 99. `<stage>` is `alpha`, `beta`, or `rc`, and `<R>` counts from 1. A
  final version has no suffix.
- For the same `X.Y.Z`, the order is `alpha` < `beta` < `rc` < final, and within one
  stage by `<R>` as a number.
- Tags: in the project repository the version with a leading `v` (`v1.2.0`,
  `v1.0.0-alpha1`); in the workspace `<name>/v<version>` (`SSDisp/v1.2.0`).
- The single version source of a project is its `version-source`. Do not set the
  version anywhere else. If the toolchain forces a second place to carry it, list that
  place in the project's section of `src/AGENTS.md`, so that a release updates it too.
- If `version-source` is `none`, the version only exists as the git tag.
- Only `/ss-workflow:release` and hotfix branches change a version.
- The workspace itself has no version.
<!-- /ss-workflow:managed -->

## Project notes

<!-- Workspace-wide rules, architecture notes, and conventions go here.
     ss-workflow upgrades never modify this section. -->
