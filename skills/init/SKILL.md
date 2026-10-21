---
name: init
description: Initialize an ss-workflow workspace (a repository that holds the requests, docs, and agent files, with each project as a git submodule under src/), add projects to it from a remote URL or a local git path, or upgrade a repository initialized by an older ss-workflow version, including the conversion of the single-repository layout of 0.5.0 and older. Use only when the developer explicitly asks to initialize, add a project, convert, or upgrade the workflow.
argument-hint: "[--upgrade] [--add <url|path>]... [<url|path>...]"
disable-model-invocation: true
---

# init

Set up an ss-workflow workspace. The workspace repository holds the requests, the
docs, and the agent files. Each project stays in its own repository, with its own
layout, and is added as a git submodule at `src/<name>`. Work step by step, ask the
developer before every change that is hard to undo, and never lose existing content
or git history.

Input: `$ARGUMENTS`: `--upgrade`, and the projects to add, as remote URLs or local
paths of git repositories (each one plain or after `--add`).

Plugin version (the version this run installs): read `version` from
`${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`.

Supporting files (read them when the step that needs them comes up):

- [references/questionnaire.md](references/questionnaire.md): questions to ask, defaults, and the placeholders each answer fills
- [references/layout.md](references/layout.md): target layout, and which template produces each file
- [references/add-project.md](references/add-project.md): adding a project from a URL or a local path
- [references/convert-legacy.md](references/convert-legacy.md): converting a repository in the layout of ss-workflow 0.5.0 and older
- [references/upgrade.md](references/upgrade.md): upgrading a workspace created by an older ss-workflow version
- `migrations/`: one file per plugin version that needs more than new template text
  when a repository is upgraded. `${CLAUDE_PLUGIN_ROOT}/skills/init/migrations/` is
  its full path.
- `templates/`: file templates with `{{PLACEHOLDER}}` tokens

## Ground rules

- Talk to the developer in the discussion language. The default is Traditional Chinese
  (zh-TW) with technical terms kept in English. Once the questionnaire has answered it,
  use that answer.
- Ask questions with the AskUserQuestion tool, at most 4 per call. Put the recommended
  option first.
- Never overwrite an existing file silently. If a target file exists, show what would
  change and ask whether to merge, replace, or skip it.
- Never rewrite git history. Never force-push. Push only after the developer agrees.
- Init writes nothing into a project repository. The only exceptions: creating a
  missing `develop` branch there, and the conversion in
  [references/convert-legacy.md](references/convert-legacy.md). Both need the
  developer's approval.
- Commit messages are English and follow the convention in
  `templates/root-AGENTS.md` (section "Commit convention"). Make several small commits,
  not one large commit.
- Templates live in `${CLAUDE_PLUGIN_ROOT}/skills/init/templates/`. Read each
  template, replace every `{{PLACEHOLDER}}`, and write the result. Before writing a
  file, check that no `{{` remains in it.
- Keep the `<!-- ss-workflow:managed ... -->` / `<!-- /ss-workflow:managed -->` markers
  in generated files. Upgrades only rewrite text between those markers, so text outside
  them belongs to the developer.

## Step 1: Detect the current state

Collect the following without changing anything:

1. Directory contents: run `git ls-files` if this is a repo, otherwise list the
   directory, leaving out build output and dependency folders.
2. Git state:
   - `git rev-parse --is-inside-work-tree`
   - `git branch -a`
   - `git remote -v`
   - `git status --porcelain`
   - `.gitmodules`, if there is one
3. Existing agent files: `AGENTS.md` and `CLAUDE.md` at any level, and `README*.md`.
4. Workflow marker: whether the root `AGENTS.md` contains `ss-workflow-version:`, and
   which version.
5. Remote tooling: whether `gh` and `glab` are installed and authenticated
   (`gh auth status`, `glab auth status`).
6. For each project in `$ARGUMENTS`: whether it is a URL or a local path, and for a
   local path, whether it is a git repository and whether it has an `origin`.

Pick the mode:

| Mode | Condition | Continue with |
|------|-----------|---------------|
| **Upgrade** | Root `AGENTS.md` has `ss-workflow-version:` | [references/upgrade.md](references/upgrade.md), then stop. A version below `0.6.0` is the single-repository layout: the upgrade is the conversion in [references/convert-legacy.md](references/convert-legacy.md). |
| **Add project** | The directory is already a workspace (root `AGENTS.md` has `projects:`), and `$ARGUMENTS` names projects | [references/add-project.md](references/add-project.md) for each project, then Step 10 |
| **Inside a project** | The directory is a git repository with code, but not a workspace | Propose a workspace next to it, `../<name>-workspace`, with this repository as its first project. The repository itself does not change. If the developer agrees, continue in that new directory as **New**, with this repository's path in the project list. |
| **New** | Empty directory, or only scratch files | Step 2 |

Tell the developer which mode you picked and what you found, in a short summary.

A new workspace may start without any project. Projects are added later with
`/ss-workflow:init --add <url|path>`. For a brand-new project without any code yet,
the developer first creates an empty repository (on a remote, or locally), and then
adds it.

## Step 2: Precondition checks

- If the directory is a repository and `git status --porcelain` shows uncommitted
  changes, stop. Ask the developer to commit or stash them first.
- If the current branch is a detached HEAD or is in the middle of a merge or rebase,
  stop and report it.
- For each project to add: it must be reachable (`git ls-remote <url>`, or a git
  repository at the local path). If it is not, say so, and leave it out unless the
  developer fixes it.

## Step 3: Questionnaire

Follow [references/questionnaire.md](references/questionnaire.md). Ask in the order
given there, skip questions whose answers you already detected (state the detected
value instead), and finish by showing a summary table of every answer and asking the
developer to confirm it. Round 3 is asked once per project.

## Step 4: Plan the file changes

Build the list of files to create from [references/layout.md](references/layout.md),
and the list of submodules from [references/add-project.md](references/add-project.md).

Show the developer a single tree of the final layout. Mark each entry as `new`,
`submodule <url>`, or `unchanged`. Ask for approval. If the developer asks for
changes, adjust the plan and show it again.

## Step 5: Git branches

Use `{{MAIN_BRANCH}}` (`master` or `main`) from the questionnaire.

- **No repo**: run `git init -b {{MAIN_BRANCH}}`.
- **Existing empty repo**:
  - If the main branch is missing but the other name (`master` / `main`) exists, ask
    whether to use the existing one instead. Never rename a branch without approval.
  - If `develop` exists, check it out.
  - If `develop` is missing, create it later (see Step 7), not now.

## Step 6: Generate the files and add the projects

Generate in this order. Each group becomes one commit (Step 7):

1. **Ignore file**: `.gitignore` from `templates/gitignore.template`. Keep an existing
   one, and add the ss-workflow block.
2. **Projects**: add each project as a submodule, as
   [references/add-project.md](references/add-project.md) says. The gitlinks on
   `{{MAIN_BRANCH}}` point to each project's main branch.
3. **Agent files**: every `AGENTS.md` / `CLAUDE.md` pair listed in `layout.md`, with
   one entry in `projects` and one section in `src/AGENTS.md` per project.
4. **Folders**: `reqs/done/.gitkeep`.
5. **Docs**: `docs/overview.md`, and `docs/<name>/spec.md` for each project (see
   [references/add-project.md](references/add-project.md), section 4).
6. **READMEs**: the root README files, with one row per project.

Init does not create project files, build files, or version files, and it does not
write into the project repositories. Those belong to the projects' toolchains.

## Step 7: Commit

Commit each group from Step 6 separately, for example:

```
chore: add gitignore
chore(workspace): add the SSLib and SSDisp projects
docs(agents): add ss-workflow AGENTS.md and CLAUDE.md files
chore: add reqs folder
docs: add the workspace overview and the project specs
docs: add README and README-zh-TW
```

Branch placement:

- **New**: commit on `{{MAIN_BRANCH}}`, then run `git branch develop` and
  `git checkout develop`. Both long-lived branches now start from the same initial
  history.
- **Existing repo without `develop`**: create `develop` from `{{MAIN_BRANCH}}` first,
  then commit on `develop`.
- **Existing `develop`**: commit on `develop`.

Then point `develop`'s gitlinks to each project's develop branch:
`git -C src/<name> checkout --detach <develop-ref of the project>` for each project,
`git add src`, and commit `chore(workspace): point the projects to develop`. Skip the
commit if no gitlink changed.

## Step 8: Register the plugin for the team (optional)

If the developer gave a marketplace source in the questionnaire, run these commands:

```bash
claude plugin marketplace add <marketplace-source> --scope project
claude plugin install ss-workflow@ss-workflow --scope project
```

They write `extraKnownMarketplaces` and `enabledPlugins` into `.claude/settings.json`.
Commit it as `chore: register ss-workflow plugin for the project`.

If the `claude` CLI is not available from the shell, print both commands so the
developer can run them, and do not handwrite the JSON.

## Step 9: Remote

- If the workspace has a remote and `{{PUSH_POLICY}}` is not `never`, ask whether to
  push `{{MAIN_BRANCH}}` and `develop` (`git push -u origin <branch>`). With `never`,
  show the two commands for the developer to run.
- A project whose `develop` branch was created by init needs it pushed too, as that
  project's `push-policy` allows. Ask first.
- If the workspace has no remote, say that the workflow works completely without one:
  a local branch is the claim, and branches are merged locally. A remote is only
  needed to share the work between machines, and it can be added later. Teammates
  can only clone the workspace with its projects when every project has a URL that
  they can reach.

## Step 10: Report

Summarize in the discussion language:

- Mode, ss-workflow version written, main branch, and current branch
- The projects: name, path, URL in `.gitmodules`, branches, and whether init created
  a `develop` branch in it
- Created and merged files, plus the commit list (`git log --oneline`)
- What the developer still needs to fill in, such as `docs/overview.md`, the spec of
  each project in `docs/<name>/spec.md`, the README description, and the empty
  commands of each project
- Project repositories whose `.gitignore` misses build output: suggest a request
- The optional `verify-command` of each project, for a verification script that
  `/ss-workflow:review` runs after the build and the tests
- The optional `agent-files` setting, for files outside the built-in list that tell an
  agent how to behave, such as prompt files that a product ships
- What was pushed, and what the developer still has to push, per repository
- Next step: `/ss-workflow:new-req` to create the first request, or
  `/ss-workflow:init --add <url|path>` to add a project
