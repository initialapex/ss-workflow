# {{SOURCE_DIR}}/

Source code of {{PROJECT_NAME}}.

<!-- ss-workflow:managed id=src-rules -->
## Rules

- The main project file, if the project has one, is `project-file` in the root
  `AGENTS.md`. It lives in this folder.
- One folder per project or module. Every such folder has a `README.md` that covers
  what it is for, its main entry points, and how it relates to the others. Update the
  README when its responsibilities change.
- The product version is set only in `version-source` (root `AGENTS.md`). Do not set
  it anywhere else.
- Third-party code and binaries go to `external/`, not into this folder.
- Never commit build output.
- Build with `build-command` from the root `AGENTS.md`. If a fresh checkout or
  worktree needs preparation first, run `setup-command`.
- Follow "Project rules" below. They hold what is specific to this project's
  toolchain.
<!-- /ss-workflow:managed -->

## Project rules

<!-- Written during initialization, and maintained by the developer. ss-workflow
     upgrades never modify this section. It says what an agent must know to change
     this project correctly: how new files and projects are registered with the build,
     which files are generated and must not be edited, where build output goes, and
     the naming conventions. -->

{{PROJECT_RULES}}
