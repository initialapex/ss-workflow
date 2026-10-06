# Converting an existing project

Goal: move the existing project into the ss-workflow layout without breaking the build
or losing history. The developer approves the plan before any file moves.

## 1. Understand the project first

- Read the existing `README*`, `AGENTS.md`, and `CLAUDE.md` files, plus any docs
  folders.
- For .NET, parse each `.sln` / `.slnx` for project paths. Read each project file for
  `<ProjectReference>`, `<Version>`, and the test framework packages.
- Classify each project as one of: **source** (goes to `src/`), **test** (goes to
  `tests/`), **sample/demo** (goes to `samples/`), or **unknown**. Ask the developer
  about every unknown project.
- Note any build scripts, CI files (`.github/workflows`, `.gitlab-ci.yml`), and other
  files that contain hard-coded project paths.

## 2. Propose the move plan

Show a table, then ask for approval with AskUserQuestion:

| Current path | New path | Reason |
|--------------|----------|--------|
| `MyLib/MyLib.csproj` | `src/MyLib/MyLib.csproj` | source project |
| `MyLib.Tests/` | `tests/MyLib.Tests/` | references xunit |
| `Demo/` | `samples/Demo/` | WPF app referencing MyLib |
| `Documentation/` | `docs/` | docs folder |
| `lib/vendor.dll` | `external/vendor.dll` | binary dependency |

Offer these options:
1. Apply the full plan (Recommended)
2. Apply the plan, but keep the source projects where they are. Choose this if moving
   would disrupt other people's open branches.
3. Adjust the plan (the developer describes the changes)

If the developer keeps some paths, record them in root `AGENTS.md` under
"Repository layout". This makes later skills follow the actual layout.

## 3. Apply the moves

- Use `git mv` for every move, so git records each one as a rename.
- Fix every path that the moves break:
  - Paths in `.sln`: use `dotnet sln remove` and `dotnet sln add`, or edit the
    relative paths directly.
  - `<ProjectReference Include="...">` relative paths in the project files.
  - Paths in CI files and build scripts.
- Verify that `{{BUILD_COMMAND}}` succeeds. If tests exist, verify that
  `{{TEST_COMMAND}}` passes too.
  - If the build fails, fix the path problems.
  - If the build fails for reasons unrelated to the moves (it also failed before
    them), report this and ask the developer how to continue.
- Commit the moves on their own, before any generated files:
  `refactor: move projects into ss-workflow layout`. Put the path table in the
  commit body.

## 4. Merge the existing agent and README files

| Existing file | Action |
|---------------|--------|
| Root `CLAUDE.md` with project-specific rules | Move the rules into root `AGENTS.md`, outside the managed blocks, under "Project notes". Replace `CLAUDE.md` with the template. Show the developer the diff first. |
| Root `AGENTS.md` | Keep the developer's content outside the managed blocks, and insert the managed blocks. |
| `README.md` | Keep the existing content. Add only missing sections from the template, such as the language links and the "Building the source" section. Ask first. |
| Version in individual project files | Move it into `Directory.Build.props` as `{{INITIAL_VERSION}}`, and remove `<Version>` / `<VersionPrefix>` from the project files. |

## 5. Existing tasks and issues

If the project has a TODO list, an issue export, or a backlog file, ask whether to turn
those items into requests now. If yes, create one `REQ-xxxx` file per item with
`status: draft`, and keep the original text in `## Original`. Otherwise, leave the
items for `/ss-workflow-new-req`.
