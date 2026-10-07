---
name: ss-workflow-init
description: Initialize the current directory as an ss-workflow repository (gitflow branches, reqs/ request tracking, AGENTS.md/CLAUDE.md, README, folder layout), convert an existing project to that layout, or upgrade a repo initialized by an older ss-workflow version. Use only when the developer explicitly asks to initialize, convert, or upgrade the workflow.
argument-hint: "[--upgrade]"
disable-model-invocation: true
---

# ss-workflow-init

Turn the current working directory into an ss-workflow repository. Work step by step,
ask the developer before every change that is hard to undo, and never lose existing
content or git history.

Plugin version (the version this run installs): read `version` from
`${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`.

Supporting files (read them when the step that needs them comes up):

- [references/questionnaire.md](references/questionnaire.md): questions to ask, defaults, and the placeholders each answer fills
- [references/layout.md](references/layout.md): target layout, and which template produces each file
- [references/convert-existing.md](references/convert-existing.md): converting a project that already has code
- [references/upgrade.md](references/upgrade.md): upgrading a repo created by an older ss-workflow version
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
- Commit messages are English and follow the convention in
  `templates/root-AGENTS.md` (section "Commit convention"). Make several small commits,
  not one large commit.
- Templates live in `${CLAUDE_PLUGIN_ROOT}/skills/ss-workflow-init/templates/`. Read each
  template, replace every `{{PLACEHOLDER}}`, and write the result. Before writing a
  file, check that no `{{` remains in it.
- Keep the `<!-- ss-workflow:managed ... -->` / `<!-- /ss-workflow:managed -->` markers
  in generated files. Upgrades only rewrite text between those markers, so text outside
  them belongs to the developer.

## Step 1: Detect the current state

Collect the following without changing anything:

1. Directory contents: run `git ls-files` if this is a repo, otherwise list the
   directory, ignoring `bin/`, `obj/`, `.vs/`, `node_modules/`.
2. Git state:
   - `git rev-parse --is-inside-work-tree`
   - `git branch -a`
   - `git remote -v`
   - `git status --porcelain`
3. Solution and projects: `*.sln` / `*.slnx` files, `*.csproj` / `*.vbproj` /
   `*.fsproj` files, test projects (those that reference xunit, nunit, or MSTest), and
   other ecosystems (`package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, ...).
4. Existing agent files: `AGENTS.md` and `CLAUDE.md` at any level, and `README*.md`.
5. Workflow marker: whether the root `AGENTS.md` contains `ss-workflow-version:`.
6. Remote tooling: whether `gh` and `glab` are installed and authenticated
   (`gh auth status`, `glab auth status`).

Pick the mode:

| Mode | Condition | Continue with |
|------|-----------|---------------|
| **Upgrade** | Root `AGENTS.md` has `ss-workflow-version:` | [references/upgrade.md](references/upgrade.md), then stop |
| **Convert** | The directory already has source code or other content | Step 2, then [references/convert-existing.md](references/convert-existing.md) at Step 4 |
| **New** | Empty directory, or only scratch files | Step 2 |

Tell the developer which mode you picked and what you found, in a short summary.

## Step 2: Precondition checks

- If `git status --porcelain` shows uncommitted changes, stop. Ask the developer to
  commit or stash them first, because the conversion moves files and needs a clean
  baseline.
- If the current branch is a detached HEAD or is in the middle of a merge or rebase,
  stop and report it.

## Step 3: Questionnaire

Follow [references/questionnaire.md](references/questionnaire.md). Ask in the order
given there, skip questions whose answers you already detected (state the detected
value instead), and finish by showing a summary table of every answer and asking the
developer to confirm it.

## Step 4: Plan the file changes

Build the list of files to create or modify from
[references/layout.md](references/layout.md). In **Convert** mode, also build the
move plan from [references/convert-existing.md](references/convert-existing.md).

Show the developer a single tree of the final layout. Mark each entry as `new`,
`moved from <path>`, `merged`, or `unchanged`. Ask for approval. If the developer asks
for changes, adjust the plan and show it again.

## Step 5: Git branches

Use `{{MAIN_BRANCH}}` (`master` or `main`) from the questionnaire.

- **No repo**: run `git init -b {{MAIN_BRANCH}}`.
- **Existing repo**:
  - If the main branch is missing but the other name (`master` / `main`) exists, ask
    whether to use the existing one instead. Never rename a branch without approval.
  - If `develop` exists, check it out.
  - If `develop` is missing, create it later (see Step 7), not now.

## Step 6: Generate the files

Generate in this order. Each group becomes one commit (Step 7):

0. **Convert mode only**: apply the approved moves first, as their own commit. See
   [references/convert-existing.md](references/convert-existing.md).
1. **Ignore and build files**
   - `.gitignore`: if the project is .NET and `dotnet` is available, run
     `dotnet new gitignore`. Otherwise use `templates/gitignore.template`. In both
     cases, make sure the file contains every entry in the "ss-workflow" block of the
     template.
   - `Directory.Build.props` (.NET only): use `templates/Directory.Build.props`. If the
     projects already set `<Version>`, move the value here (Convert mode) and remove it
     from the individual project files.
2. **Agent files**: every `AGENTS.md` / `CLAUDE.md` pair listed in `layout.md`.
3. **Folders**: `reqs/done/.gitkeep`, `external/.gitkeep`, and `tests/` and `samples/`
   when kept.
4. **Docs**: `docs/{{PROJECT_SLUG}}-spec.md`.
5. **READMEs**: the root README files, plus a `README.md` for each project in `src/`
   that does not have one.

## Step 7: Commit

Commit each group from Step 6 separately, for example:

```
chore: add gitignore and Directory.Build.props
docs(agents): add ss-workflow AGENTS.md and CLAUDE.md files
chore: add reqs, external, tests and samples folders
docs: add project spec skeleton
docs: add README and README-zh-TW
```

Branch placement:

- **New**: commit on `{{MAIN_BRANCH}}`, then run `git branch develop` and
  `git checkout develop`. Both long-lived branches now start from the same initial
  history.
- **Convert / existing repo without `develop`**: create `develop` from
  `{{MAIN_BRANCH}}` first, then commit on `develop`. Ask whether to also fast-forward
  `{{MAIN_BRANCH}}` now. This is allowed before v1.0.0, per the pre-1.0 rule in
  root AGENTS.md.
- **Existing `develop`**: commit on `develop`.

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

- If a remote exists, ask whether to push `{{MAIN_BRANCH}}` and `develop`
  (`git push -u origin <branch>`).
- If no remote exists, mention that the workflow works locally, and that claiming
  requests (`/ss-workflow-check-req`) is safer with a remote.

## Step 10: Report

Summarize in the discussion language:

- Mode, ss-workflow version written, main branch, and current branch
- Created, moved, and merged files, plus the commit list (`git log --oneline`)
- What the developer still needs to fill in, such as the spec in
  `docs/{{PROJECT_SLUG}}-spec.md` and the README description
- The optional `verify-command` setting in root `AGENTS.md`, for a verification script
  that `/ss-workflow-review` runs after the build and the tests
- Next step: `/ss-workflow-new-req` to create the first request
