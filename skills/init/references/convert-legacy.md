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
2. Restore the layout of the toolchain in the old repository, and remove the workflow
   files from it (commits on its `develop`).
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

Propose a move table, from what the toolchain expects. For example, a Visual Studio
solution:

| Current path | New path | Reason |
|--------------|----------|--------|
| `src/SSDisp.sln` | `SSDisp.sln` | The solution sits at the root of its repository |
| `src/SSDisp/` | `SSDisp/` | Source project, next to the solution |
| `tests/SSDisp.Test/` | `SSDisp.Test/` | Test project, merged into the source |
| `samples/SSDisp.Sample/` | (deleted) | The developer's choice |
| `external/` | `external/` | Kept in place: the build refers to it |

- The target follows the toolchain, not a fixed rule: a Keil or a custom layout keeps
  its own conventions. If the old layout already fits the toolchain, nothing moves.
- Ask about each project in `tests/` and `samples/` separately: merge it into the
  source (at the place that the table shows), or delete it. A deleted project stays
  in the history.
- `external/` stays where it is by default, because the build refers to it. The
  developer can change that in the table.
- Ask with AskUserQuestion. If the developer changes the table, show it again.

Apply it on `develop`:

- Use `git mv` for every move, so git records each one as a rename, and `git rm -r`
  for every deletion.
- Fix every path that the moves break: the references inside project, solution,
  workspace, and build files, the paths between projects, and the paths in CI files
  and scripts. Paths inside a project file are usually relative to that file, so
  moving the file changes all of them.
- Files that a tool finds by walking up from the project folder (shared build
  settings, package configuration, editor configuration) have to stay where every
  project still finds them, normally the repository root.
- Rewrite the commands of the old "Workflow settings" for the new paths. They now run
  in the project folder: `msbuild src/SSDisp.sln` becomes `msbuild SSDisp.sln`.
- Verify with the rewritten build command that the project still builds. If tests
  exist, verify that the test command passes too. If the build fails for reasons
  unrelated to the moves (it also failed before them), report it, and ask how to
  continue. If there is no build command, ask the developer to build in their IDE
  before you commit.
- Commit: `refactor: move the projects back to the <toolchain> layout`. Put the path
  table in the commit body, including the deletions.

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
| `docs/` | Ask file by file. The spec (`docs/<slug>-spec.md`) moves to the workspace. Every other file moves to the workspace by default; the developer can name files that are product documentation (a user manual, API docs), which stay. |

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
   version source rewritten for the new paths in section 3.
3. Create the workspace in that folder as **New** mode of `SKILL.md` does (Steps 5 to
   8), with the old repository as its project:
   - URL: the old repository's `origin` URL, as [add-project.md](add-project.md)
     section 2 says. If its `develop` was not pushed in section 4, clone from the local
     path and record the `origin` URL, as the table there says: the commits are then
     in the workspace's copy too, and reach the remote with the next push of the
     project.
   - The project's section in `src/AGENTS.md` gets the old "Toolchain" and "Project
     rules" texts. The old "Project notes" go to "Project notes" of the new root
     `AGENTS.md`. Show both.
4. Copy the docs that move: `git -C <old repo> archive <base> <paths> | tar -x` in the
   workspace, then commit `docs: move the docs from <name>`.

Already done when: the workspace folder is a git repository with `src/<name>` in
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
   - `git checkout -b req/REQ-<id>-<slug> develop` in the workspace.
   - Write its request file from the old branch
     (`git -C <old repo> show req/REQ-<id>-<slug>:reqs/<file>`), with
     `projects: [<name>]` added after `type:`. Nothing else changes.
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
  or kept; the workspace has its own copy of the project in `src/<name>`.

## 9. Report

- The old repository: the move table, the removed files, the commits, and what was
  pushed
- The workspace: its path, its remote, its commits, and what was pushed
- The requests that moved: ready, done, and drafts, with their ids
- Docs that stayed in the project repository
- What the developer still has to push, per repository
- That the workspace records `ss-workflow-version: 0.6.0` (or the plugin version), and
  that the old repository has no workflow marker any more
- Next step: open the workspace, and continue with `/ss-workflow:check-req` or
  `/ss-workflow:new-req` there
