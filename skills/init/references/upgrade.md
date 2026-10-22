# Upgrading an ss-workflow repository

Run this when root `AGENTS.md` contains `ss-workflow-version: <x>`.

## 1. Compare versions

- Repo version: the `ss-workflow-version:` value in root `AGENTS.md`.
- Plugin version: `version` in the plugin's `.claude-plugin/plugin.json`. `SKILL.md`
  gives the full path of that file at its top.

| Result | Action |
|--------|--------|
| Repo version = plugin version | Report "up to date", then run the health check (section 5). |
| Repo version < plugin version | Upgrade (sections 2 to 4), then run the health check. |
| Repo version > plugin version | The installed plugin is older than the repo. Tell the developer to update the plugin (`/plugin marketplace update ss-workflow`), then stop. |

An upgrade has three parts, in this order: the migrations (section 2), the managed
blocks (section 3), and the version (section 4). Do all of them before you commit.

**A repo version below `0.6.0`** is the single-repository layout, and the upgrade is
the conversion into a workspace. Do not run sections 2 to 4 in the old repository:
the current templates are workspace templates, and the old repository's workflow
files are moved or removed by the conversion anyway. Instead:

1. Tell the developer the "What changes" part of every migration file from the repo
   version up to `0.6.0`, in version order. They describe how the workflow behaves
   now.
2. Follow [convert-legacy.md](convert-legacy.md). The workspace is created from the
   current templates and records the plugin version. What the earlier migrations
   would have carried over is handled there: the conversion's questionnaire asks for
   every setting that the old repository lacks (for example `push-policy`), the texts
   that the developer wrote move to the workspace (replace old skill names in them,
   see `0.4.0.md`), and the request files get their new sections from the skills that
   next write them (see `0.5.0.md`).
3. If the plugin is newer than `0.6.0`, the later migrations run in the new workspace
   afterwards: run `/ss-workflow:init` there.

## 2. Apply the migrations

The folder `migrations/` of this skill (`SKILL.md` gives its full path) holds one file
per plugin version that needs more than new template text: `<version>.md`, for
example `0.5.0.md`. `README.md` in that folder describes the format.

1. List the files whose version is higher than the repo version, and not higher than
   the plugin version. Compare versions as numbers, part by part (`0.10.0` is higher
   than `0.9.0`).
2. Apply them from the lowest version to the highest, one after another. Do not skip
   one, and do not merge the steps of two files: a later migration may rely on what an
   earlier one did.
3. For each file:
   - Tell the developer its "What changes" part, in `discussion-language`, before you
     change anything. These are changes in how the workflow behaves.
   - Follow its "Steps". A step that changes text outside the managed blocks, or asks
     a question, needs the developer's answer. A step that the repository already
     fulfills is skipped: say so.
   - Run its "Check" part.
4. A version without a migration file needs nothing beyond section 3.

Whatever the migration files say, also compare the keys of the "Workflow settings"
block in root `AGENTS.md` with those in `templates/root-AGENTS.md`. Add each missing
key at the position it has in the template, with the value that keeps the current
behavior. If no migration file names that value, ask the developer. Never change the
value of a key that is already there.

## 3. Upgrade the managed blocks

Generated files contain managed blocks:

```
<!-- ss-workflow:managed id=<block-id> -->
...
<!-- /ss-workflow:managed -->
```

For each generated file listed in [layout.md](layout.md):

1. Render the current template with the answers recorded in root `AGENTS.md`, in the
   "Workflow settings" block.
2. For each managed block: if the rendered text differs from the file, replace only
   the text between the markers. Leave everything outside the markers untouched.
3. If the template now contains a block that the file lacks, insert it at the same
   position as in the template.
4. If the file has a block that the template no longer contains, ask before removing it.
5. If a file from `layout.md` is missing entirely, create it. This happens when a new
   version introduces a new file.

## 4. Record the version and commit

- Set `ss-workflow-version:` to the plugin version.
- Show the developer the diff of all changes, and get approval before committing.
  Nothing outside the managed blocks changes without it.
- Commit on `develop`: `chore(workflow): upgrade ss-workflow to v<version>`. In the
  body, list the migrations that were applied and the changed files.
- Push `develop` as "Remote and pushing" in root `AGENTS.md` allows. If the file does
  not have that section yet, ask before you push.

Existing request files are changed only when a migration file says so, and then every
`## Original` section is kept byte for byte, and no answered `## Q&A` entry is
changed.

If the upgrade stops halfway (the developer declines a step, or a check fails), do
not set the new version. Report which migrations were applied and which were not, and
leave the changes uncommitted for the developer to look at.

## 5. Health check

Report and offer to fix:

- Missing folders, or missing AGENTS.md / CLAUDE.md files.
- Missing `develop` or main branch, in the workspace or in a project.
- `.gitignore` missing entries from the ss-workflow block.
- The entries of `projects` and the submodules of `.gitmodules` differ: a project
  without a submodule, a submodule without an entry, or a `path` that does not match.
- A submodule that is not initialized (`git submodule status` starts with `-`).
- A project without `docs/<name>/spec.md`, or a missing `docs/overview.md`: offer to
  create it from its template.
- Request files without `projects` while `legacy-project` is empty, or names a
  project that is not in `projects`.
- A gitlink of `develop` that is behind its project's develop branch (see "Workspace
  and projects" in root `AGENTS.md`), and a gitlink of the main branch that is not its
  project's main branch.
- Project worktrees (`git -C src/<name> worktree list`) whose workspace worktree is
  gone, or whose request is already in `review`.
- The root checkout is not on `develop`. Say which activity holds it: a request branch
  whose file says `draft` (or a `req/*` branch) is a spec discussion, another request
  branch is a review, and a project on a `release/*`
  branch is a release.
- Request files on `develop` with invalid frontmatter or an unknown `status`.
- Request files on `develop` with `status: done` that are not in `reqs/done/`.
- Keys of the "Workflow settings" block that the template has and root `AGENTS.md`
  lacks, or values that are not allowed for their key (for example a `push-policy`
  other than `auto`, `ask`, or `never`).
- `remote-platform` that says `github` or `gitlab` while `git remote` lists nothing,
  or `merge-method: remote` while `remote-platform` is `none`, for the workspace or a
  project.
- A project from a local path without a remote whose `push-policy` is not `never`.
- Worktrees from `git worktree list` whose branch has already been merged into
  `develop`, or whose request is already in `review`.
- `req/*` branches whose request is already on `develop`.

For the state of the individual requests and their branches, point to the overview of
`/ss-workflow:check-req`.

Do not fix anything without the developer's approval. Each fix is its own commit, and
changes to request files on `develop` go through a `req/` branch.
