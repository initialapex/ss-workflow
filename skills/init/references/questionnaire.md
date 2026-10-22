# Init questionnaire

Ask the questions in the rounds below. Use AskUserQuestion, at most 4 questions per
call, when the answer is a choice between options. Put the recommended option first
and mark it "(Recommended)". Ask in plain text when the answer is free-form. If you
already detected a value in Step 1, do not ask about it; state the detected value and
let the developer correct it.

Every answer fills one or more template placeholders. Keep a running answer table.

The workflow does not depend on any project type. It works the same for a Visual
Studio solution, a Keil project, an ESP32 firmware, a web application, or anything
else. Everything that depends on the project type is an answer in Round 3, not a
built-in rule, and each project of the workspace has its own answers.

In **Add project** mode, ask only Round 3 (and Round 4 for the new project's
branches), and use the workspace's recorded settings for everything else.

## Round 1: Languages

| Question | Default | Placeholder |
|----------|---------|-------------|
| Discussion language with the agent | Traditional Chinese (zh-TW), technical terms in English | `{{DISCUSSION_LANG}}` |
| README languages | `README.md` in English + `README-zh-TW.md` | `{{README_LANGS}}` |
| Language of agent-facing docs (AGENTS.md, CLAUDE.md) | English | `{{AGENT_DOC_LANG}}` |
| Language of requests (`reqs/`) and docs (`docs/`) | Same as the discussion language | `{{REQS_LANG}}`, `{{DOCS_LANG}}` |

Commit messages are always English. Do not ask about them.

## Round 2: Workspace

| Question | Default | Placeholder |
|----------|---------|-------------|
| Workspace name | The directory name, for example `SSDisp-workspace`. It names the workspace in its own files only: the history of a project never mentions it. | `{{WORKSPACE_NAME}}` |
| One-sentence description | (free text) | `{{WORKSPACE_DESCRIPTION}}` |
| The projects to add | The URLs and paths in `$ARGUMENTS`; may be none | One entry each, see Round 3 |

## Round 3: Each project

Ask this round once per project. The answers fill the placeholders of
`templates/projects-entry.yaml` and `templates/src-AGENTS-project.md`. For each one,
propose a value from what you found in the project and from what you know about that
toolchain, say that it is a proposal, and let the developer confirm or correct it. If
you are not sure that a value is right for this toolchain, say so and ask. Do not
guess a command.

Read the project from its submodule folder after it is added, or from the local path:
the files that identify a toolchain (solution, workspace, and project files, build
files, package manifests), its README and agent files, and where the version is set.

Any of the commands may stay empty. An empty command means that the step is skipped
and reported as "not configured". The developer can fill it in later in root
`AGENTS.md`.

| Question | Placeholder | Notes |
|----------|-------------|-------|
| Project name | `{{ENTRY_NAME}}` | The repository name by default, for example `SSDisp`. It becomes the folder `src/<name>`, its docs folder `docs/<name>/`, the tag prefix `<name>/v1.2.0`, and the hotfix branch `hotfix/<name>-v1.0.1`. No spaces and no `/`. |
| One-sentence description | `{{ENTRY_DESCRIPTION}}` | From its README if it has one |
| Project type and toolchain | `{{ENTRY_TYPE}}` | Free text in the developer's own words, specific enough to tell the toolchain, for example "Visual Studio solution, old-style C# projects built with MSBuild", "Keil MDK-ARM, STM32F4", or "ESP32 firmware with ESP-IDF v5". Do not offer a fixed list, and do not assume a type for an empty repository. |
| Library or application? | `{{ENTRY_KIND}}` | `library` / `application` |
| Main project file: the solution, workspace, or top-level build file | `{{ENTRY_PROJECT_FILE}}` | Relative to the project folder, for example `SSDisp.sln`. Empty for a project that has none yet. |
| Setup command: what a fresh checkout needs before it can build (restore packages, fetch components, generate files) | `{{ENTRY_SETUP_COMMAND}}` | Runs in the project folder. Often empty. |
| Build command | `{{ENTRY_BUILD_COMMAND}}` | Runs in the project folder. Empty if the project can only be built inside an IDE. |
| Test command | `{{ENTRY_TEST_COMMAND}}` | Runs in the project folder. Empty if there are no automated tests. |
| Version source: the file and the field that hold the project's version | `{{ENTRY_VERSION_SOURCE}}` | Relative to the project folder, for example ``SSDisp/Properties/AssemblyInfo.cs (AssemblyVersion, AssemblyFileVersion)`` or ``main/version.h (#define FW_VERSION)``. `none` if the version only exists as a git tag. |
| Tool notes: tools that must be installed, how to find tools that are not on `PATH`, other places that must carry the version, and known limits | `{{ENTRY_TOOLCHAIN_NOTES}}` | Free text for "Toolchain" in the project's section of `src/AGENTS.md`. Do not put a machine-specific absolute path into a command; describe how to locate the tool instead. |
| Project rules: what an agent must know to change this project correctly | `{{ENTRY_PROJECT_RULES}}` | Free text for "Project rules" in the project's section. For example: whether new source files must be added to a project file by hand, which files are generated and must not be edited, where build output goes, and naming conventions. |
| Remote settings of this project, if they differ from the workspace's | `{{ENTRY_REMOTE_PLATFORM}}`, `{{ENTRY_MERGE_METHOD}}`, `{{ENTRY_PUSH_POLICY}}` | Empty means the workspace value. Detect the platform from the project's URL. Propose `push-policy: never` for a project from a local path without a remote (see [add-project.md](add-project.md)). Explain that other people may use the project's repository, so `ask` can fit there even when the workspace uses `auto`. |

After the developer confirms the build command, try it once in the project folder, so
that a wrong command is found now and not during the first request.

Also check whether the project's `.gitignore` covers the build output. Do not change
it: list what is missing for the report, as a candidate for a request.

## Round 4: Branches

| Question | Default | Placeholder / effect |
|----------|---------|----------------------|
| Workspace main branch name | `master`; use the existing name if the repo already has `main` | `{{MAIN_BRANCH}}` |
| Each project's main branch | The branch that its remote's `HEAD` points to (`git ls-remote --symref <url> HEAD`) | `{{ENTRY_MAIN_BRANCH}}` |
| Each project's develop branch | `develop` if it exists. If it does not exist, ask: create `develop` from the main branch (and push it, as the project's `push-policy` allows), or name an existing branch that serves as develop. | `{{ENTRY_DEVELOP_BRANCH}}` |

## Round 5: Remote and team

| Question | Default | Placeholder |
|----------|---------|-------------|
| Remote platform of the workspace | Detected from `git remote -v`; otherwise "None for now" | `{{REMOTE_PLATFORM}}` (`github` / `gitlab` / `none`). Use `none` for any other remote too, such as a plain git server: it only means that the skills cannot open merge requests. |
| Remote URL of the workspace (only when there is no remote yet and the developer wants one) | (free text) | Run `git remote add origin <url>` in Step 9 |
| How to merge finished branches (only when there is a remote platform) | "Ask every time" | `{{MERGE_METHOD}}` (`ask` / `local` / `remote`); `local` when there is no remote platform |
| Who pushes to the remote (only when there is a remote, or the developer plans one) | "The agent pushes by itself" | `{{PUSH_POLICY}}` (`auto` / `ask` / `never`); `auto` when there is no remote |
| Register the ss-workflow plugin in `.claude/settings.json` for teammates? | Yes, if the developer can give the marketplace source (`owner/repo` or a git URL) | `{{MARKETPLACE_SOURCE}}`; empty means skip Step 8 |

These are the workspace values, and the defaults of every project that does not set
its own in Round 3. For `{{REMOTE_CLI}}`, use `gh` for github, `glab` for gitlab, and
`none` otherwise.

Explain the three answers to the push question when you ask it:

| Answer | What it means | Fits |
|--------|---------------|------|
| `auto` (Recommended) | The agent pushes its topic branches after every commit, and `develop` after a merge that the developer asked for. Other sessions and machines see new requests and status changes at once. | Several machines or sessions that share a remote |
| `ask` | The agent commits locally, and asks before the first push of a skill run. | The developer wants to see what leaves the machine |
| `never` | The agent never pushes and never deletes a remote branch. It lists what the developer has to push. | Strict rules about who publishes, or a remote that agents must not write to |

For every answer, the agent asks before it pushes a main branch or a tag, and it
never force-pushes. The workflow also works without any remote: the questions of this
round then only record `none`, `local`, and `auto`.

## Confirmation

Show the full answer table with every placeholder and its value, one block per
project. Ask the developer to confirm or correct it. Do not create files or add
submodules before this confirmation.

## Derived placeholders

| Placeholder | Value |
|-------------|-------|
| `{{SS_WORKFLOW_VERSION}}` | The plugin version: `version` in the plugin's `.claude-plugin/plugin.json`. `SKILL.md` gives the full path of that file at its top. |
| `{{INIT_DATE}}` | Today's date, `yyyy-MM-dd` |
| `{{ENTRY_URL}}` | The URL recorded in `.gitmodules` for the project |
| `{{PROJECTS}}` | `templates/projects-entry.yaml` rendered once per project, in the order the projects were added. ` []` when there is none. |
| `{{PROJECT_SECTIONS}}` | `templates/src-AGENTS-project.md` rendered once per project. Empty when there is none. |
| `{{PROJECT_ROWS}}` | One table row per project for the root READMEs: `` \| <name> \| [`src/<name>`](src/<name>) \| <URL> \| [`docs/<name>/spec.md`](docs/<name>/spec.md) \| <description> \| ``. When there is none, one row that says that no project is added yet, and how to add one. |
| `{{LEGACY_PROJECT}}` | The project's `name` when the workspace is created by the conversion in [convert-legacy.md](convert-legacy.md); empty otherwise, without a trailing space (`legacy-project:`) |
