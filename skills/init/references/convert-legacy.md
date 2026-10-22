# Converting a repository of ss-workflow 0.5.0 and older

Up to 0.5.0, ss-workflow kept everything in one repository: the code in `src/`,
`tests/`, and `samples/`, and the requests in `reqs/`. From 0.6.0 on, the requests live
in a workspace repository, and each project is a submodule with its own layout. This
guide converts the old repository:

- **The old repository becomes the project (source) repository.** It keeps its
  remote, its whole history, and its version tags. Nothing is rewritten. It goes back
  to the layout of its toolchain, and loses the workflow files.
- **A new workspace repository** takes the requests and the docs, and adds the old
  repository as its first project.

Run it from the root checkout of the old repository, when `references/upgrade.md`
finds a repo version below `0.6.0`. It works for every older version: the old
settings are read where they exist, and the questionnaire asks for the rest.

The old layout cannot be kept with this plugin version. If the developer declines the
conversion, stop: nothing changes, and the repository stays on its recorded version.

Every step below says how to tell that it is already done, so that a conversion that
stopped halfway can be continued.

## 1. Tell the developer what changes

Show "What changes" of `migrations/0.6.0.md`, then this plan, in `discussion-language`:

1. Check that no work is in progress.
2. Restore the layout of the toolchain in the old repository (for Visual Studio: the
   solution at the root, every project folder next to it, and no `src/`, `tests/`,
   or `samples/` left), and remove the workflow files from it (commits on its
   `develop`).
3. Create the workspace, add the old repository as its project, and move the requests,
   the drafts, and the docs there.

Ask for a go-ahead.

## 2. Preconditions

Fetch first (`git fetch --prune --tags`), then collect:

| Check | How |
|-------|-----|
| No claimed request that is not finished | Request branches other than `req/*`: `git branch -a --list "*REQ-*"`. Each one is `in-progress`, `review`, or merge pending (`done` but not merged). |
| No release or hotfix | `git branch -a --list "*release/*" "*hotfix/*"` |
| No worktree | `git worktree list` lists only the root checkout |
| Clean and on `develop` | `git status --porcelain` is empty, `git branch --show-current` is `develop`, and with a remote `develop` equals `origin/develop` |

If any check fails, stop and list what was found. The other skills of this plugin
version only work in a workspace, so the developer finishes that work in one of two
ways, and then runs `/ss-workflow:init` again:

- Install ss-workflow 0.5.0 for the time being (a marketplace that points to the tag
  `v0.5.0` of the ss-workflow repository), finish with its `/ss-workflow:review`,
  `/ss-workflow:merge`, and `/ss-workflow:release`, and update the plugin again.
- Or ask the agent to finish it by hand, following the old repository's root
  `AGENTS.md` ("Branching model", "Remote and pushing") and `reqs/AGENTS.md`, which
  describe the old merge, release, and close steps. Dropping a claimed request is
  also a way to finish it.

Drafts (`req/*` branches) and `ready` requests do not block: they move to the
workspace.

Record the commit of `develop` now as `<base>`. The requests and docs are copied from
it later.

## 3. The layout of the toolchain

Read the project as section 1 of [add-project.md](add-project.md) says, and the
"Repository layout", "Toolchain", and "Project rules" sections of the old agent files.

The goal: after the conversion, the project repository, and so `projects/<name>` in
the workspace, looks the way its toolchain creates a new project. The folders `src/`,
`tests/`, and `samples/` were the layout of the old workflow, not of the toolchain, so
they do not stay as wrappers around the projects.

Propose a move table.

**A Visual Studio solution** (a `.sln` or `.slnx` file) has a fixed target, the layout
that Visual Studio creates:

- The solution file sits at the root of the project repository.
- Every project of the solution (the folder of each `.csproj`, `.vcxproj`, `.vbproj`,
  `.fsproj`, or other project file) sits directly at the root, next to the solution:
  the source projects from `src/`, the test projects from `tests/`, and the sample
  projects from `samples/`.
- `src/`, `tests/`, and `samples/` are gone afterwards. The layout already fits only
  when the solution is at the root and no project folder is inside one of them.
- Files in `src/` that are neither the solution nor a project folder, such as
  `Directory.Build.props`, `Directory.Packages.props`, `NuGet.config`, `global.json`,
  or `.editorconfig`, move to the root as well: the tools find them by walking up
  from the project folders, so they stay above every project.
- If a moved folder has the name of a file or folder that already exists at the root
  (for example `docs`), ask for another name.

| Current path | New path | Reason |
|--------------|----------|--------|
| `src/SSDisp.sln` | `SSDisp.sln` | The solution sits at the root of its repository |
| `src/SSDisp/` | `SSDisp/` | Source project, next to the solution |
| `tests/SSDisp.Test/` | `SSDisp.Test/` | Test project, next to the solution |
| `samples/SSDisp.Sample/` | `SSDisp.Sample/` | Sample project, next to the solution |
| `external/` | `external/` | Third-party files: the developer's choice, see below |

The result in the workspace:

```text
projects/SSDisp/
├─ SSDisp.sln
├─ SSDisp/
├─ SSDisp.Test/
├─ SSDisp.Sample/
└─ external/
```

**Other toolchains** (Keil, CMake, a custom layout) follow their own conventions:
propose the table from them, and ask when you cannot tell what the toolchain expects.
If the old layout already fits the toolchain, nothing moves.

**Test and sample projects** are kept by default, at the place that the toolchain
gives them (for Visual Studio, next to the solution). Ask about each project in
`tests/` and `samples/` separately: keep it, or delete it. A deleted project stays in
the history, and its entry is removed from the solution or the build files.

**Third-party folders** (`external/`, `lib/`, `vendor/`, or any folder of files that
the repository commits and that is not a project of the build) are the developer's
choice. Ask about each one with AskUserQuestion:

| Choice | What happens |
|--------|--------------|
| Keep it in the project repository (default) | It stays in the project repository, at the root (`external/`). If it was inside `src/`, `tests/`, or `samples/`, it moves to the root with the projects. |
| Move it to the workspace's `projects/` | It becomes a project of its own: a new repository that keeps the folder's history, added to the workspace as the submodule `projects/<folder>` next to this project (section 5). It is removed from this project, and the paths to it leave the project repository: from `SSDisp/SSDisp.csproj`, `..\external\x.dll` becomes `..\..\external\x.dll`. This project then builds only next to it, in the workspace or in a checkout with the same neighbor. Say so. |
| Remove it | `git rm -r`. It stays in the history. The references to it are removed too; if the build still needs its files (from a package manager, for example), say how the build gets them. |
| Other | The developer says where it goes. Propose the rows of the table and the path fixes for it. |

For a folder that moves to the workspace's `projects/`, ask for the new repository's
URL: the developer creates an empty repository on the remote platform, or names a
local path for a bare repository (`git init --bare <path>`; see the URL table of
[add-project.md](add-project.md), section 2). Then, before the moves, copy its
history from `<base>`, with the main and the develop branch names of this project:

```bash
git subtree split --prefix=<folder path at base> -b split/<folder> <base>
git push <new repository URL> split/<folder>:refs/heads/<main-branch> split/<folder>:refs/heads/<develop-branch>
git branch -D split/<folder>
```

Pushing to the new repository asks first, as every push does with `ask`.

Ask with AskUserQuestion. If the developer changes the table, show it again.

Apply it on `develop`:

- Use `git mv` for every move, so git records each one as a rename, and `git rm -r`
  for every deletion and for each folder that moved to the workspace's `projects/`.
  `git mv` does not create a missing target folder: create it first.
- Fix every path that the moves break: the references inside project, solution,
  workspace, and build files, the paths between projects, and the paths in CI files
  and scripts. Paths inside a project file are usually relative to that file, so
  moving the file changes all of them. For Visual Studio:
  - In the solution, project paths are relative to the solution:
    `..\tests\SSDisp.Test\SSDisp.Test.csproj` becomes
    `SSDisp.Test\SSDisp.Test.csproj`, and `SSDisp\SSDisp.csproj` stays.
  - In a project file, a `ProjectReference` from `tests/SSDisp.Test/` to
    `..\..\src\SSDisp\SSDisp.csproj` becomes `..\SSDisp\SSDisp.csproj`, and a path
    from `src/SSDisp/` to `..\..\external\` becomes `..\external\`.
  - Check `$(SolutionDir)` and `$(MSBuildThisFileDirectory)` paths, and the
    `Directory.Build.props` that every project imports.
- Files that a tool finds by walking up from the project folder (shared build
  settings, package configuration, editor configuration) have to stay where every
  project still finds them, normally the repository root.
- Rewrite the commands of the old "Workflow settings" for the new paths. They now run
  in the project folder: `msbuild src/SSDisp.sln` becomes `msbuild SSDisp.sln`.
- Verify with the rewritten build command that the project still builds. If tests
  exist, verify that the test command passes too. If the build fails for reasons
  unrelated to the moves (it also failed before them), report it, and ask how to
  continue. If there is no build command, ask the developer to build in their IDE
  before you commit. If a folder moved to the workspace's `projects/`, the build needs
  that neighbor: verify it in the workspace after section 5, and say so.
- Commit: `refactor: move the projects back to the <toolchain> layout`. Put the path
  table in the commit body, including the deletions and the folders that moved to
  their own repository.

Already done when: `develop` has a commit with that subject after `<base>`, or nothing
had to move.

## 4. Remove the workflow files from the old repository

Before removing anything, collect what belongs to the developer, for the workspace
(section 5):

- From the old root `AGENTS.md`: the "Workflow settings" values, "Toolchain",
  "Repository layout", and "Project notes".
- From `src/AGENTS.md`: "Project rules".
- From `tests/AGENTS.md`, `samples/AGENTS.md`, and every `CLAUDE.md`: any text outside
  the managed blocks that the template does not have.

Then, on `develop`, remove:

| Path | Note |
|------|------|
| `reqs/` | Copied to the workspace in section 5 |
| Root `AGENTS.md` and `CLAUDE.md` | If the developer wrote rules there that are about the code itself and should stay with the project (for other agents that work in it directly), offer to keep them in a shorter project `AGENTS.md`, without the workflow sections |
| `src/AGENTS.md`, `src/CLAUDE.md`, `tests/AGENTS.md`, `tests/CLAUDE.md`, `samples/AGENTS.md`, `samples/CLAUDE.md` | Where they still exist after section 3 |
| `.claude/settings.json` | Only the plugin registration (`extraKnownMarketplaces`, `enabledPlugins` for ss-workflow). Keep other settings. |
| The ss-workflow block of `.gitignore` | Keep the toolchain patterns |
| `docs/` | Ask file by file. The spec (`docs/<slug>-spec.md`, where `<slug>` is the kebab-case of the old project name) moves to the workspace as `docs/<name>/spec.md`. Every other file moves to the workspace too by default, into `docs/<name>/` with the same relative path, because it is about this project; the developer can name files that are product documentation (a user manual, API docs), which stay. Show the table of old and new paths. |

- `README.md` and `README-zh-TW.md` are product documentation: they stay. Fix links
  to removed files (`reqs/`, `AGENTS.md`, `samples/`), and the build commands, if
  they point to the old paths.
- Search the old repository for other references to the removed files (scripts, CI
  files), and show them.
- Show the full list of removals, and get an answer.
- Commit: `chore: remove the ss-workflow files`, with the body
  `They moved to the <workspace name> repository.`
- Push `develop` as the old `push-policy` allows (ask first with `ask`). The workspace
  in section 5 clones the project from its remote, so the commits must be there; with
  `never`, or without a remote, the workspace clones from the local path instead (see
  section 5).

The main branch of the old repository keeps the old files until the next release of
the project. That is expected, and not a problem: a release merges `develop`.

Already done when: `develop` has no `reqs/` folder and no ss-workflow `AGENTS.md`.

## 5. Create the workspace

1. Ask where (default `../<name>-workspace`, next to the old repository), the
   workspace name (default the folder name), and the workspace's remote URL, if
   there is one yet.
2. Run the questionnaire for the workspace, with the answers of the old "Workflow
   settings" as the defaults: languages, main branch, remote platform, merge method,
   push policy, marketplace source. Its Round 3 for the project is mostly answered
   by the old settings: the project type and kind, and the commands, project file, and
   version source rewritten for the new paths in section 3. `{{LEGACY_PROJECT}}` is
   the project's name: the requests without `projects` in `reqs/done/` belong to it.
3. Create the workspace in that folder as **New** mode of `SKILL.md` does (Steps 5 to
   8), with the old repository as its project:
   - URL: the old repository's `origin` URL, as [add-project.md](add-project.md)
     section 2 says. If its `develop` was not pushed in section 4, clone from the local
     path and record the `origin` URL, as the table there says: the commits are then
     in the workspace's copy too, and reach the remote with the next push of the
     project.
   - The project's section in `projects/AGENTS.md` gets the old "Toolchain" and "Project
     rules" texts. The old "Project notes" go to "Project notes" of the new root
     `AGENTS.md`. Show both.
   - If the old repository has a spec, do not create `docs/<name>/spec.md` from the
     template: the old spec takes its place in step 4. `docs/overview.md` is created
     from the template.
   - Each third-party folder that moved to the workspace's `projects/` in section 3 is
     a project too, added after this one as [add-project.md](add-project.md) says,
     from its new repository, with the folder's name as its `name`. Propose
     `project-kind: library`, a `project-type` that says what it holds (for example
     "third-party binaries"), and empty commands. The section of `<name>` in
     `projects/AGENTS.md` says that it refers to `projects/<folder>` as its neighbor.
     Then build `<name>` in the workspace with its `build-command`, which section 3
     left to this point.
4. Copy the docs that move, each to its new path from the table of section 4:
   `git -C <old repo> show <base>:<old path> > <new path>` in the workspace (create
   the folder first). Then commit `docs: move the docs from <name>`, with the table
   of old and new paths in the body. Fix the links between the moved files, and the
   links to them in the README files.

Already done when: the workspace folder is a git repository with `projects/<name>` in
`.gitmodules`.

## 6. Move the requests

In the workspace, on `develop`:

1. Copy the request files of `<base>`: `git -C <old repo> archive <base> reqs | tar -x`.
   Then restore the workspace's own `reqs/AGENTS.md` and `reqs/CLAUDE.md` (the copy
   overwrote them).
2. The files in `reqs/done/` stay byte for byte as they are.
3. Each request in `reqs/` (they are `ready`) gets `projects: [<name>]`, on the line
   after `type:`. Nothing else in it changes.
4. Commit:

   ```
   chore(workspace): import the requests of <name>

   Imported from <name>@<short sha of base>.
   ```

5. For each draft (`req/REQ-<id>-<slug>` in the old repository, local or remote):
   - `git checkout -b <type>/REQ-<id>-<slug> develop` in the workspace, with the
     `type` of its request file: drafts live on their request branch now.
   - Write its request file from the old branch
     (`git -C <old repo> show req/REQ-<id>-<slug>:reqs/<file>`), with
     `projects: [<name>]` added after `type:`, and `project-branch:` after `branch:`.
     Nothing else changes.
   - Commit `docs(reqs): move draft REQ-<id> from <name>` with `Refs: REQ-<id>`, push
     as allowed, and switch back to `develop`.
6. The id scan of the workspace now sees every id of the old repository: the files,
   and the draft branches. New requests continue after the highest one.

Already done when: the workspace's `develop` has the files of `<base>`'s `reqs/`, and
a `req/` branch exists for each old draft.

## 7. The workspace main branch and the version tag

- The workspace main branch got the project's main branch as its gitlink (Step 6 of
  `SKILL.md`), which is the latest release.
- If the old repository has release tags, tag that commit of the workspace main branch
  with `<name>/v<latest version>`, for example `SSDisp/v1.4.0`, so that the next
  release of the project knows which requests are new since then. Pushing the tag
  asks first.

Already done when: the tag exists.

## 8. Clean up the old repository

Only after the developer has checked the workspace:

- Delete each draft branch of the old repository that was copied in section 6
  (`git branch -D`, and `git push origin --delete` when pushing is allowed). These
  branches hold unmerged commits, so ask for each one, or once for the list that you
  show.
- The old repository's root checkout is now a plain clone of the project. The
  developer works in the workspace from now on. Say that this clone can be deleted
  or kept; the workspace has its own copy of the project in `projects/<name>`.

## 9. Report

- The old repository: the move table, the removed files, the commits, and what was
  pushed
- Third-party folders: which stayed in the project, which became a project of their
  own in `projects/` (with the new repository's URL), and which were removed
- The workspace: its path, its remote, its commits, and what was pushed
- The requests that moved: ready, done, and drafts, with their ids
- Docs that stayed in the project repository
- What the developer still has to push, per repository
- That the workspace records `ss-workflow-version: 0.6.0` (or the plugin version), and
  that the old repository has no workflow marker any more
- Next step: open the workspace, and continue with `/ss-workflow:check-req` or
  `/ss-workflow:new-req` there
