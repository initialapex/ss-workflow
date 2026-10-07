# src/

Source projects of {{PROJECT_NAME}}.

<!-- ss-workflow:managed id=src-rules -->
## Rules

- One folder per project. The folder name equals the project name, for example
  `src/MyLib/MyLib.csproj`.
- Every project folder has a `README.md` that covers what the project is for, its main
  types or entry points, and how it relates to the other projects. Update the README
  when the project's responsibilities change.
- The solution file is `{{SOLUTION_FILE}}`, in this folder next to the project
  folders. Add every new project to it. The projects in `tests/` and `samples/`
  belong to the same solution, with relative paths.
- Do not set `<Version>`, `<VersionPrefix>`, or `<VersionSuffix>` in project files.
  The version comes from `Directory.Build.props` at the repository root.
- Shared build settings belong in `Directory.Build.props`, not in individual
  project files.
- Reference other projects with `<ProjectReference>`; never reference build output
  in `bin/`.
- Third-party binaries go to `external/`, not into `src/`.
- Build: `{{BUILD_COMMAND}}`
<!-- /ss-workflow:managed -->
