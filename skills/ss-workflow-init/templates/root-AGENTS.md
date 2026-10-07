# {{PROJECT_NAME}}

{{PROJECT_DESCRIPTION}}

## Workflow settings

This repository follows the ss-workflow process. The ss-workflow skills read the
values below; edit them here when they change.

```yaml
ss-workflow-version: {{SS_WORKFLOW_VERSION}}
initialized: {{INIT_DATE}}
discussion-language: {{DISCUSSION_LANG}}
readme-languages: {{README_LANGS}}
agent-doc-language: {{AGENT_DOC_LANG}}
reqs-language: {{REQS_LANG}}
docs-language: {{DOCS_LANG}}
project-type: {{PROJECT_TYPE}}
project-kind: {{PROJECT_KIND}}
main-branch: {{MAIN_BRANCH}}
remote-platform: {{REMOTE_PLATFORM}}
remote-cli: {{REMOTE_CLI}}
merge-method: {{MERGE_METHOD}}
source-dir: {{SOURCE_DIR}}
project-file: {{PROJECT_FILE}}
version-source: {{VERSION_SOURCE}}
setup-command: {{SETUP_COMMAND}}
build-command: {{BUILD_COMMAND}}
test-command: {{TEST_COMMAND}}
verify-command:
```

The workflow itself does not depend on the project type. The settings from
`source-dir` to `verify-command` describe this project's toolchain:

| Setting | Meaning | When it is empty |
|---------|---------|------------------|
| `project-file` | The main solution, workspace, or top-level build file | The project has none |
| `version-source` | The file and the field that hold the product version | `none`: the version only exists as a git tag |
| `setup-command` | What a fresh checkout or worktree needs before it can build | Nothing is needed |
| `build-command` | Compiles the project from a shell | The step is skipped and reported as "not configured" |
| `test-command` | Runs the automated tests | The step is skipped and reported as "not configured" |
| `verify-command` | An extra verification script that `/ss-workflow-review` runs after the build and the tests | No extra script |

## Toolchain

<!-- Written during initialization, and maintained by the developer. ss-workflow
     upgrades never modify this section. -->

{{TOOLCHAIN_NOTES}}

<!-- ss-workflow:managed id=working-agreement -->
## Working agreement

- Discuss with the developer in `discussion-language`; keep technical terms in English.
- Agent-facing docs (AGENTS.md, CLAUDE.md) use `agent-doc-language`.
- Request files (`reqs/`) use `reqs-language`; developer docs (`docs/`) use `docs-language`.
- All work starts from a request in `reqs/`. Do not implement features or fixes that
  have no request. If the developer asks for something directly, offer to create a
  request first with `/ss-workflow-new-req`.
- Where each kind of work happens:

  | Work | Where | Skill |
  |------|-------|-------|
  | Spec discussion | Root checkout, on a `req/REQ-…` branch | `/ss-workflow-new-req` |
  | Implementation | A worktree, on the request branch | `/ss-workflow-check-req` |
  | Verify (build, tests, scripts) and Review (the developer's manual check) | Root checkout, on the request branch | `/ss-workflow-review` |
  | Merge and release | Root checkout | `/ss-workflow-merge`, `/ss-workflow-release` |

- The root checkout is the repository's primary working tree. Its home branch is
  `develop`. A skill that switches it to another branch first checks that it is on
  `develop` with no uncommitted changes to tracked files, and returns it to `develop`
  when it is done. Only one of these activities uses the root checkout at a time.
- In a worktree, write code and try to compile it: run `setup-command` if the
  worktree needs it, then `build-command`. Do not run tests, scripts, or executables
  there. If a command is empty or cannot run in the worktree, note that in the request
  and leave it to Verify.
- Follow the "Toolchain" section below and the "Project rules" in the source folder's
  `AGENTS.md`. They hold what is specific to this project type.
<!-- /ss-workflow:managed -->

## Repository layout

<!-- Written during initialization from the developer's answers, and maintained by
     the developer. ss-workflow upgrades never modify this section. Init removes the
     rows of folders that the project does not use, and adds rows for other
     top-level folders that the toolchain needs. -->

| Path | Purpose | Rules |
|------|---------|-------|
| `{{SOURCE_DIR}}/` | The main project file and the source code. Each project or module has its own folder with a `README.md`. | `{{SOURCE_DIR}}/AGENTS.md` |
| `reqs/` | Requests: one Markdown file per request; finished requests live in `reqs/done/` | `reqs/AGENTS.md` |
| `docs/` | Project spec, developer-readable docs, knowledge base | Write for humans in `docs-language` |
| `external/` | Git submodules and third-party files | Do not edit vendored content |
| `tests/` | Automated tests for the source code | `tests/AGENTS.md` |
| `samples/` | Sample and demo projects that show how to use the library | `samples/AGENTS.md` |

<!-- ss-workflow:managed id=branching -->
## Branching model

The repository follows gitflow. `main-branch` and `develop` are long-lived.

| Branch | Created from | Merges into | Name example | Worktree |
|--------|--------------|-------------|--------------|----------|
| Spec discussion `req/*` | `develop` | `develop` | `req/REQ-0012-gui-button` | No |
| Request (`feat`, `fix`, `docs`, `refactor`, `perf`, `test`, `chore`) | `develop` | `develop` | `feat/REQ-0012-gui-button` | During implementation only, under `.claude/worktrees/` |
| `release/*` | `develop` | `main-branch` and `develop` | `release/v1.0.0-beta1` | No |
| `hotfix/*` | `main-branch` | `main-branch` and `develop` | `hotfix/v1.0.1` | During implementation only, under `.claude/worktrees/` |

- A `req/*` branch only changes one request file. It is merged into `develop` when
  the developer approves the spec.
- Creating a request or hotfix branch claims the request. When the implementation is
  finished, its worktree is removed and the branch is kept for Verify and Review.

- `main-branch` receives commits only when a version is released. Every merge into it
  gets a tag that matches the release or hotfix name (for example `v1.0.0-beta1`).
- Before v1.0.0 is released, `develop` may be merged straight into `main-branch` and
  tagged `v0.x.y`, which allows fast iteration.
- `develop` is the integration branch; most changes land here through request branches.
- Never force-push `main-branch` or `develop`. Never rewrite published history.
- Before any merge, run `git fetch`. If a remote exists, check whether the merge
  request was already merged there (`remote-cli`: `gh pr view` / `glab mr view`).
- `merge-method` decides how branches are merged: `local` (merge locally, then push),
  `remote` (open a merge request on the remote), or `ask` (ask every time).
- Use `/ss-workflow-merge` to merge and `/ss-workflow-release` to release; do not merge
  long-lived branches by hand.
<!-- /ss-workflow:managed -->

<!-- ss-workflow:managed id=commits -->
## Commit convention

Commit messages are always in English.

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
  - `Refs: REQ-0012` when the commit belongs to a request
  - `BREAKING CHANGE: <what changed, why, and how to migrate>` for incompatible changes

Commit often while you implement. Each commit is one reason for change, not a
bundle of unrelated files. On request branches, push after every commit.

Merge commits are the exception to the header format. They are always created with
`--no-ff` and use the subject `Merge <source branch> into <target branch>`.
<!-- /ss-workflow:managed -->

<!-- ss-workflow:managed id=versioning -->
## Versioning

- A version is `X.Y.Z` for a final version, or `X.Y.Z-<stage><R>` for a prerelease,
  for example `1.2.0` or `1.0.0-beta1`. `X`, `Y`, and `Z` are MAJOR, MINOR, and PATCH,
  each from 0 to 99. `<stage>` is `alpha`, `beta`, or `rc`, and `<R>` counts from 1. A
  final version has no suffix.
- For the same `X.Y.Z`, the order is `alpha` < `beta` < `rc` < final, and within one
  stage by `<R>` as a number.
- The tag is the version with a leading `v`: `v1.2.0`, `v1.0.0-alpha1`.
- The single version source is `version-source`. Do not set the product version
  anywhere else. If the toolchain forces a second place to carry it, list that place
  in the "Toolchain" section, so that a release updates it too.
- If `version-source` is `none`, the version only exists as the git tag.
- Only `/ss-workflow-release` and hotfix branches change the version.
<!-- /ss-workflow:managed -->

## Project notes

<!-- Project-specific rules, architecture notes, and conventions go here.
     ss-workflow upgrades never modify this section. -->
