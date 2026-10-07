# Init questionnaire

Ask the questions in the rounds below with AskUserQuestion, at most 4 questions per
call. Put the recommended option first and mark it "(Recommended)". If you already
detected a value in Step 1, do not ask about it; state the detected value and let the
developer correct it.

Every answer fills one or more template placeholders. Keep a running answer table.

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
| One-sentence description | (free text, use "Other") | `{{PROJECT_DESCRIPTION}}` |
| Project type | Detected type, otherwise ".NET / Visual Studio" | `{{PROJECT_TYPE}}` |
| Library or application? | Detected from the project files | `{{PROJECT_KIND}}` (`library` / `application`) |

For the project type, offer these options: ".NET / Visual Studio", "Node.js",
"Python", and "Other". The type determines the following values:

| Type | `{{BUILD_COMMAND}}` | `{{TEST_COMMAND}}` | `{{VERSION_SOURCE}}` |
|------|---------------------|--------------------|----------------------|
| .NET / Visual Studio | `dotnet build {{SOLUTION_FILE}}` | `dotnet test {{SOLUTION_FILE}}` | `Directory.Build.props` (`<Version>`) |
| Node.js | `npm run build` | `npm test` | `package.json` (`version`) |
| Python | (ask) | `pytest` | `pyproject.toml` (`project.version`) |
| Other | (ask) | (ask) | (ask) |

`{{SOLUTION_FILE}}` is the existing `.sln` / `.slnx` file, or `{{PROJECT_NAME}}.sln`
for a new .NET project. For a new .NET project, do not create projects. Run
`dotnet new sln -n {{PROJECT_NAME}}` only if the developer agrees. Projects come
later through requests.

## Round 3: Folders and branches

| Question | Default | Placeholder / effect |
|----------|---------|----------------------|
| Keep `tests/`? | Yes for .NET; ask for other types | `{{HAS_TESTS}}` |
| Keep `samples/`? | Yes if the kind is `library`, otherwise no | `{{HAS_SAMPLES}}` |
| Main branch name | `master`; use the existing name if the repo already has `main` | `{{MAIN_BRANCH}}` |
| Current version (Convert mode only) | Latest tag, otherwise `0.1.0` | `{{INITIAL_VERSION}}` (for new projects: `0.1.0`) |

## Round 4: Remote and team

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
| `{{SS_WORKFLOW_VERSION}}` | `version` from `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` |
| `{{INIT_DATE}}` | Today's date, `yyyy-MM-dd` |
| `{{SUBPROJECT_NAME}}` | Folder name of the project, used in `project-README.md` |
