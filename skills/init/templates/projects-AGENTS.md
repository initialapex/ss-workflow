# projects/

The projects of {{WORKSPACE_NAME}}. Each folder here is a git submodule: a project
repository with its own layout, branches, and versions. A project can hold anything
that is versioned: source code, firmware, documents, or analysis reports. Its entry in `projects`
(root `AGENTS.md`) holds its settings, and its section below holds its rules.

<!-- ss-workflow:managed id=projects-rules -->
## Rules

- Do not reorganize a project to fit the workflow. Each project keeps the layout of
  its toolchain, including where its tests, samples, and third-party files live.
- Commit a project's files (code, documents, data) only in the project repository,
  on its project branch. The workspace
  records the project commit as a gitlink (see "Workspace and projects" in the root
  `AGENTS.md`).
- Paths in a project's settings (`project-file`, `version-source`) are relative to
  the project folder, and its commands run in that folder.
- A project's version is set only in its `version-source`. Do not set it anywhere
  else.
- Never commit build output. If a project's `.gitignore` misses it, say so; fixing it
  is a change to that project and needs a request.
- If a project has its own `AGENTS.md`, `CLAUDE.md`, or README, read and follow them
  too. If they contradict the workflow rules, ask the developer.
- Build with the project's `build-command`. If a fresh checkout or worktree needs
  preparation first, run its `setup-command`.
- Follow the project's section below. It holds what is specific to that project's
  toolchain.
- A project's spec and its other docs are in the workspace, in `docs/<name>/`. When a
  request changes the behavior that they describe, update them on the workspace
  request branch, in the same request.
<!-- /ss-workflow:managed -->
{{PROJECT_SECTIONS}}
