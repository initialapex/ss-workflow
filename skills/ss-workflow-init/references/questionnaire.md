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
built-in rule.

## Round 1: Languages

| Question | Default | Placeholder |
|----------|---------|-------------|
| Discussion language with the agent | Traditional Chinese (zh-TW), technical terms in English | `{{DISCUSSION_LANG}}` |
| README languages | `README.md` in English + `README-zh-TW.md` | `{{README_LANGS}}` |
| Language of agent-facing docs (AGENTS.md, CLAUDE.md) | English | `{{AGENT_DOC_LANG}}` |
| Language of requests (`reqs/`) and docs (`docs/`) | Same as the discussion language | `{{REQS_LANG}}`, `{{DOCS_LANG}}` |

Commit messages are always English. Do not ask about them.

## Round 2: Project

| Question | Default | Placeholder |
|----------|---------|-------------|
| Project name | Directory name | `{{PROJECT_NAME}}`; `{{PROJECT_SLUG}}` = kebab-case of the name |
| One-sentence description | (free text) | `{{PROJECT_DESCRIPTION}}` |
| Project type and toolchain | What you detected; otherwise ask in plain text, with no default | `{{PROJECT_TYPE}}` |
| Library or application? | What you detected | `{{PROJECT_KIND}}` (`library` / `application`) |

`{{PROJECT_TYPE}}` is free text in the developer's own words, specific enough to tell
the toolchain, for example "Visual Studio solution, old-style C# projects built with
MSBuild", "Keil MDK-ARM, STM32F4", or "ESP32 firmware with ESP-IDF v5". Do not offer a
fixed list, and do not assume a type when the directory is empty.

## Round 3: Toolchain

These answers hold everything that is specific to the project type. For each one,
propose a value from what you found in the repository and from what you know about
that toolchain, say that it is a proposal, and let the developer confirm or correct
it. If you are not sure that a value is right for this toolchain, say so and ask. Do
not guess a command.

Any of these may stay empty. An empty command means that the step is skipped and
reported as "not configured". The developer can fill it in later in root `AGENTS.md`.

| Question | Placeholder | Notes |
|----------|-------------|-------|
| Main project file: the solution, workspace, or top-level build file | `{{PROJECT_FILE}}` | A path from the repository root. By default it lives in the source folder, for example `src/MyApp.sln`. Empty for a new project that has none yet. |
| Setup command: what a fresh checkout needs before it can build (restore packages, fetch components, generate files) | `{{SETUP_COMMAND}}` | Often empty. |
| Build command | `{{BUILD_COMMAND}}` | The command that compiles the project from a shell. Empty if the project can only be built inside an IDE. |
| Test command | `{{TEST_COMMAND}}` | The command that runs the automated tests. Empty if there are none. |
| Version source: the file and the field that hold the product version | `{{VERSION_SOURCE}}` | For example ``src/SharedAssemblyInfo.cs (AssemblyVersion, AssemblyFileVersion)`` or ``src/main/version.h (#define FW_VERSION)``. `none` if the version only exists as a git tag. |
| Tool notes: tools that must be installed, how to find tools that are not on `PATH`, and known limits | `{{TOOLCHAIN_NOTES}}` | Free text for the "Toolchain" section of root `AGENTS.md`. Do not put a machine-specific absolute path into a command; describe how to locate the tool instead. |
| Project rules: what an agent must know to change this project correctly | `{{PROJECT_RULES}}` | Free text for the "Project rules" section of the source folder's `AGENTS.md`. For example: whether new source files must be added to a project file by hand, which files are generated and must not be edited, where build output goes, and naming conventions. |
| Ignore patterns: build output and local files of this toolchain | `{{IGNORE_PATTERNS}}` | Lines for `.gitignore`, in addition to the ss-workflow block. |

In Convert mode, try the build command once after the developer confirms it, so that a
wrong command is found now and not during the first request.

## Round 4: Folders and branches

`reqs/` and `docs/` are part of the workflow and always exist. The code folders depend
on the project.

| Question | Default | Placeholder / effect |
|----------|---------|----------------------|
| Source folder | `src/`. In Convert mode, the existing folder if the developer keeps the current layout. | `{{SOURCE_DIR}}` |
| Keep `tests/` for automated tests? | Yes if the project has or will have tests that run from a command | `{{HAS_TESTS}}` |
| Keep `samples/` for sample or demo projects? | Yes if the kind is `library`, otherwise no | `{{HAS_SAMPLES}}` |
| Keep `external/` for submodules and third-party files? | Yes | `{{HAS_EXTERNAL}}` |
| Other top-level folders that the toolchain needs, with their purpose | None | Extra rows in the "Repository layout" table of root `AGENTS.md` |
| Main branch name | `master`; use the existing name if the repo already has `main` | `{{MAIN_BRANCH}}` |
| Current version (Convert mode only) | The value in the version source, otherwise the latest tag, otherwise `0.1.0` | `{{INITIAL_VERSION}}` (for new projects: `0.1.0`) |

## Round 5: Remote and team

| Question | Default | Placeholder |
|----------|---------|-------------|
| Remote platform | Detected from `git remote -v`; otherwise "None for now" | `{{REMOTE_PLATFORM}}` (`github` / `gitlab` / `none`) |
| Remote URL (only when there is no remote yet and the developer wants one) | (free text) | Run `git remote add origin <url>` in Step 9 |
| How to merge finished branches (only when there is a remote platform) | "Ask every time" | `{{MERGE_METHOD}}` (`ask` / `local` / `remote`); `local` when there is no remote platform |
| Register the ss-workflow plugin in `.claude/settings.json` for teammates? | Yes, if the developer can give the marketplace source (`owner/repo` or a git URL) | `{{MARKETPLACE_SOURCE}}`; empty means skip Step 8 |

For `{{REMOTE_CLI}}`, use `gh` for github, `glab` for gitlab, and `none` otherwise.

## Confirmation

Show the full answer table with every placeholder and its value. Ask the developer to
confirm or correct it. Do not create files before this confirmation.

## Derived placeholders

| Placeholder | Value |
|-------------|-------|
| `{{SS_WORKFLOW_VERSION}}` | The plugin version: `version` in the plugin's `.claude-plugin/plugin.json`. `SKILL.md` gives the full path of that file at its top. |
| `{{INIT_DATE}}` | Today's date, `yyyy-MM-dd` |
| `{{SUBPROJECT_NAME}}` | Folder name of the project or module, used in `project-README.md` |
