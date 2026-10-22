# Adding a project

Goal: add an existing project to the workspace as a git submodule at `projects/<name>`,
without changing the project's files or history. The developer approves the plan
before any submodule is added.

The same steps serve a new workspace (one run per project) and `--add` on an existing
workspace.

## 1. Understand the project first

Read it where it is (the local path, or a temporary look with `git ls-remote` and the
README on the platform), or from its submodule folder once it is added:

- The existing `README*`, `AGENTS.md`, and `CLAUDE.md` files, plus any docs folders.
- The main project file and the build files, far enough to know which folders hold the
  source code, the tests, and the samples or demos, how the parts refer to each
  other, where the version is set, and where build output goes.
- Its branches: `git ls-remote --heads --symref <url>` (or `git -C <path> branch -a`).
- Paths outside the project that it refers to, such as a sibling project
  (`..\SSLib\SSLib.csproj`). Inside the workspace, the projects are siblings in
  `projects/`. If a project expects a neighbor at a different relative path, tell the
  developer: that is a change to the project, which needs a request.

Use what you learn here for the proposals in Round 3 of the questionnaire. Ask the
developer about every folder whose purpose you cannot tell.

## 2. Decide the URL

`.gitmodules` records a URL that every clone of the workspace uses, so it must be one
that teammates can reach.

| Input | Clone from | URL in `.gitmodules` |
|-------|------------|----------------------|
| A remote URL (https, ssh) | The URL | The URL |
| A local path whose repository has an `origin` | The local path, which saves the download | The `origin` URL. The developer's local working copy does not change. |
| A local path without an `origin` | The local path | The local path, after the developer agrees (see below) |

For a local path without an `origin`, explain first:

- Nobody else can clone the workspace with this project, because the path exists on
  this machine only.
- The project's `origin` will be the developer's working copy. Git refuses a push to
  the branch that a working copy has checked out, so this project gets
  `push-policy: never`: its commits stay in the workspace's copy until the developer
  moves them.
- The better setup is a bare repository as a shared remote, for example
  `git clone --bare <path> <path>.git`, added by that URL. The URL can also be
  changed later with `git submodule set-url projects/<name> <url>`.

Ask which one the developer wants.

## 3. Add the submodule

1. Check that `projects/<name>` does not exist yet, and that no other project has the same
   name.
2. Add it:

   | Case | Commands |
   |------|----------|
   | Remote URL | `git submodule add <url> projects/<name>` |
   | Local path with an `origin` | `git clone <path> projects/<name>`, then `git -C projects/<name> remote set-url origin <origin URL>`, then `git submodule add <origin URL> projects/<name>` (git adds the existing clone in place), then `git submodule absorbgitdirs projects/<name>` |
   | Local path without an `origin` | `git -c protocol.file.allow=always submodule add <path> projects/<name>`. Git refuses a local path for a submodule without that option. Later commands that clone it (`git submodule update --init` in a new clone) need it too. |

3. Run `git -C projects/<name> fetch origin` and check the branches from Round 4:
   - The main branch must exist.
   - If the develop branch does not exist and the developer chose to create it:
     `git -C projects/<name> branch <develop-branch> origin/<main-branch>`, then push it as
     the project's `push-policy` allows (ask first). This is the only change that init
     makes in a project repository.
4. Point the gitlink of the branch you are committing on:
   - On the workspace main branch: `git -C projects/<name> checkout --detach
     origin/<main-branch>` (the latest release).
   - On `develop`: `git -C projects/<name> checkout --detach origin/<develop-branch>`.

   In a new workspace, Step 7 of `SKILL.md` makes both commits. In **Add project**
   mode, see section 5.
5. Nested submodules of the project: `git -C projects/<name> submodule update --init
   --recursive`.

## 4. Record the project

- Append the entry from `templates/projects-entry.yaml` to `projects` in root
  `AGENTS.md`. If `projects` was `[]`, replace the `[]`.
- Append the section from `templates/projects-AGENTS-project.md` to `projects/AGENTS.md`.
- Add the project's row to the project table of each root README.
- Create `docs/<name>/spec.md` from `templates/project-spec.md`. If the workspace
  already has a spec of this project (from a conversion, or written by hand), keep it
  and do not create another one.
- Add a line for the project to "Projects" in `docs/overview.md`: what it is
  responsible for, and a link to `<name>/spec.md`.
- Show these changes to the developer before you write them: they are outside the
  managed blocks.

## 5. Commit in Add project mode

The root checkout must be on `develop` and clean.

1. On `develop`: commit `.gitmodules`, the gitlink (the project's develop branch), and
   the files of section 4, including `docs/<name>/spec.md`:

   ```
   chore(workspace): add the <name> project

   <url>, main branch <main-branch>, develop branch <develop-branch>.
   ```

2. The workspace main branch gets the project at its latest release. Ask first,
   because this changes the main branch. Then:

   ```bash
   git checkout <main branch>
   git merge --no-ff --no-commit develop
   git update-index --cacheinfo 160000,<sha of the project's main branch>,projects/<name>
   git commit -m "Merge develop into <main branch>" -m "Add the <name> project."
   git checkout develop
   git submodule update
   ```

   In that merge, set the gitlink of every other project to its main branch too, as
   "Branching model" in root `AGENTS.md` describes for releases. If the developer
   prefers to wait, the main branch gets the project with the next release of any
   project.
3. Push as the workspace's `push-policy` allows. Pushing the main branch asks first,
   as always.

## 6. Existing tasks and issues

If the project has a TODO list, an issue export, or a backlog file, ask whether to turn
those items into requests. Do not create request files during init: requests are
created with `/ss-workflow:new-req`, one at a time, each on its own `req/` branch. Give
the developer the list of items you found, so they can start with the first one.
