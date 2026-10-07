# Converting an existing project

Goal: bring the existing project into the workflow without breaking its build or
losing history. The developer approves the plan before any file moves.

The workflow only requires `reqs/`, `docs/`, the agent files, and the git branches.
Moving the code into `src/`, `tests/`, and `samples/` is optional. Many toolchains
depend on where their files are, so the developer decides how far the layout changes.

## 1. Understand the project first

- Read the existing `README*`, `AGENTS.md`, and `CLAUDE.md` files, plus any docs
  folders.
- Find the main project file and the build files, and read them far enough to know:
  which folders hold the source code, the tests, and the samples or demos; how the
  parts refer to each other; where the version is set; and where build output goes.
- Find what refers to paths: project and workspace files, build scripts, CI files
  (`.github/workflows`, `.gitlab-ci.yml`), and IDE settings.
- Ask the developer about every folder whose purpose you cannot tell.

Use what you learn here for the proposals in Round 3 of the questionnaire.

## 2. Propose the layout

Offer these options with AskUserQuestion. Recommend the first one when the toolchain
finds its files by location, or when moving them would disturb other people's open
branches. Otherwise, recommend the second one.

1. **Keep the current layout.** Nothing moves. Init adds the workflow files, and the
   "Repository layout" table in root `AGENTS.md` describes the folders as they are.
   `{{SOURCE_DIR}}` is the existing source folder.
2. **Move into the standard layout.** Show the move plan as a table:

   | Current path | New path | Reason |
   |--------------|----------|--------|
   | `MyApp.sln` | `src/MyApp.sln` | the main project file lives in the source folder |
   | `MyLib/` | `src/MyLib/` | source project |
   | `MyLib.Tests/` | `tests/MyLib.Tests/` | automated tests |
   | `Demo/` | `samples/Demo/` | demo application |
   | `Documentation/` | `docs/` | docs folder |
   | `lib/vendor/` | `external/vendor/` | third-party files |

3. **Adjust.** The developer describes which parts move.

## 3. Apply the moves

Skip this section if nothing moves.

- Use `git mv` for every move, so git records each one as a rename.
- Fix every path that the moves break: the references inside project, workspace, and
  build files, the paths between projects, and the paths in CI files and scripts.
  Paths inside a project file are usually relative to that file, so moving the file
  changes all of them.
- Files that a tool finds by walking up from the project folder (shared build
  settings, package configuration, editor configuration) have to stay where every
  project still finds them. This is normally the repository root.
- Verify with the confirmed `{{BUILD_COMMAND}}` that the project still builds. If
  tests exist, verify that `{{TEST_COMMAND}}` passes too.
  - If the build fails, fix the path problems.
  - If the build fails for reasons unrelated to the moves (it also failed before
    them), report this and ask the developer how to continue.
  - If there is no build command, ask the developer to open and build the project in
    their IDE before you commit the moves.
- Commit the moves on their own, before any generated files:
  `refactor: move projects into ss-workflow layout`. Put the path table in the
  commit body.

## 4. Merge the existing agent and README files

| Existing file | Action |
|---------------|--------|
| Root `CLAUDE.md` with project-specific rules | Move the rules into root `AGENTS.md`, under "Toolchain" or "Project notes", or into "Project rules" of the source folder's `AGENTS.md`, wherever each rule belongs. Replace `CLAUDE.md` with the template. Show the developer the diff first. |
| Root `AGENTS.md` | Keep the developer's content outside the managed blocks, and insert the managed blocks. |
| `README.md` | Keep the existing content. Add only missing sections from the template, such as the language links and the "Building the source" section. Ask first. |
| `.gitignore` | Keep it. Add the ss-workflow block and the missing ignore patterns. |

## 5. The version

Find every place that states the product version. If there is more than one, tell the
developer, and ask which one is the single `version-source`. Ask whether to
consolidate the others now. If the toolchain needs them to stay, list them in the
"Toolchain" section of root `AGENTS.md`, so that a release updates them too.

Do not restructure how the project stores its version without the developer's
approval.

## 6. Existing tasks and issues

If the project has a TODO list, an issue export, or a backlog file, ask whether to turn
those items into requests. Do not create request files during init: requests are
created with `/ss-workflow:new-req`, one at a time, each on its own `req/` branch. Give
the developer the list of items you found, so they can start with the first one.
