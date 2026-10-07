# Upgrading an ss-workflow repository

Run this when root `AGENTS.md` contains `ss-workflow-version: <x>`.

## 1. Compare versions

- Repo version: the `ss-workflow-version:` value in root `AGENTS.md`.
- Plugin version: `version` in the plugin's `.claude-plugin/plugin.json`. `SKILL.md`
  gives the full path of that file at its top.

| Result | Action |
|--------|--------|
| Repo version = plugin version | Report "up to date", then run the health check (section 3). |
| Repo version < plugin version | Upgrade (section 2), then run the health check. |
| Repo version > plugin version | The installed plugin is older than the repo. Tell the developer to update the plugin (`/plugin marketplace update ss-workflow`), then stop. |

## 2. Upgrade the managed blocks

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

Then:

- Set `ss-workflow-version:` to the plugin version.
- Show the developer the diff of all changes, and get approval before committing.
- Commit on `develop`: `chore(workflow): upgrade ss-workflow to v<version>`. List the
  changed files in the body.

If a newer version changes the request file format (`reqs/AGENTS.md`, section
"Request file format"), also migrate the existing request files in `reqs/` and
`reqs/done/`. Keep every `## Original` section byte for byte.

## 3. Health check

Report and offer to fix:

- Missing folders, or missing AGENTS.md / CLAUDE.md files.
- Missing `develop` or main branch.
- `.gitignore` missing entries from the ss-workflow block.
- The root checkout is not on `develop`. Say which activity holds it: a `req/*` branch
  is a spec discussion, a request branch is a review, a `release/*` branch is a
  release.
- Request files on `develop` with invalid frontmatter or an unknown `status`.
- Request files on `develop` with `status: done` that are not in `reqs/done/`.
- Worktrees from `git worktree list` whose branch has already been merged into
  `develop`, or whose request is already in `review`.
- `req/*` branches whose request is already on `develop`.

For the state of the individual requests and their branches, point to the overview of
`/ss-workflow:check-req`.

Do not fix anything without the developer's approval. Each fix is its own commit, and
changes to request files on `develop` go through a `req/` branch.
