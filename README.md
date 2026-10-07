English | [繁體中文](README-zh-TW.md)

# ss-workflow

A Claude Code plugin that gives a repository a request-driven development workflow on
top of gitflow. Every change starts as a request file whose spec you approve. An agent
implements it in its own git worktree, you verify and review it in the root checkout,
and skills merge and release it by the same rules every time.

> **Status: 0.1.0, early.** The six skills are written and the plugin manifest
> validates, but the workflow has not yet been run end to end on a real project.

## Skills

| Skill | When to use it | Where it runs | What it does |
|-------|----------------|---------------|--------------|
| `/ss-workflow-init` | Once per repository, and again after a plugin update | Root checkout | Creates the folder layout, the git branches, `AGENTS.md` / `CLAUDE.md`, and the README files. Converts an existing project, or upgrades a repository made by an older version. |
| `/ss-workflow-new-req` | You have a new feature, fix, or other change | Root checkout, on a `req/` branch | Writes the request file, discusses the spec with you, and merges it into `develop` as `ready` when you approve. |
| `/ss-workflow-check-req` | You want to see what is pending, or start or continue an implementation | Root checkout for the overview and the claim; a worktree for the implementation | Lists all requests, repairs inconsistent ones, claims a `ready` request by creating its branch and worktree, and implements it. Then it marks the request for review and removes the worktree. |
| `/ss-workflow-review` | An implemented request waits for you | Root checkout, on the request branch | Verify: runs the build, the tests, and the verification scripts. Review: guides you through the manual check. Applies small fixes, or sends the request back for rework. |
| `/ss-workflow-merge` | You accept a reviewed request, or a release or hotfix is ready | Root checkout | Closes the request and merges its branch, creates the tag for releases and hotfixes, and deletes the branches. |
| `/ss-workflow-release` | You want to release a new version | Root checkout | Recommends the version, creates the release branch, checks for unfinished work, sets the version number, and hands over to the release merge. |

The root checkout is the repository's primary working tree. Tests, scripts, and
executables only run there. In a worktree, the agent writes code and tries to compile
it, because running things in a worktree is more restricted.

Each skill belongs to the `ss-workflow` plugin, so its full name is
`/ss-workflow:ss-workflow-init`, and so on. Claude Code also accepts the short name
shown above when no other skill uses it.

## How a request moves

```mermaid
flowchart LR
    draft -->|you approve the spec| ready
    ready -->|a session creates the request branch| in-progress
    in-progress -->|implemented, worktree removed| review
    review -->|rework needed| in-progress
    review -->|you run the merge skill| done
```

| Status | Meaning | Where the work happens | Set by |
|--------|---------|------------------------|--------|
| `draft` | The spec is under discussion | Root checkout, on a `req/REQ-…` branch | `/ss-workflow-new-req` |
| `ready` | You approved the spec; the request is on `develop` and waits to be claimed | (nothing) | `/ss-workflow-new-req` |
| `in-progress` | Claimed; being implemented | A worktree, on the request branch | `/ss-workflow-check-req` |
| `review` | Implemented; the worktree is removed and the branch is kept; waiting for or under Verify and Review | Root checkout, on the request branch | `/ss-workflow-check-req`, then `/ss-workflow-review` |
| `done` | Closed; the file is in `reqs/done/` | Root checkout | `/ss-workflow-merge` |

A request is one Markdown file, `reqs/REQ-0012-20260907-gui-button.md`. Its YAML
frontmatter is the only place that holds its state, and your original text is kept
unchanged in its `## Original` section.

- A draft only exists on its `req/` branch. `develop` only holds requests you approved.
- Creating the request branch is the claim: git creates a branch name only once, so
  two sessions cannot claim the same request.
- Small problems found during Verify or Review are fixed in the root checkout. A
  request that needs larger rework goes back to `in-progress` and into a worktree.

## Branching model

| Branch | Created from | Merges into | Example |
|--------|--------------|-------------|---------|
| Spec discussion | `develop` | `develop` | `req/REQ-0012-gui-button` |
| Request | `develop` | `develop` | `feat/REQ-0012-gui-button` |
| Release | `develop` | `master` and `develop`, plus a tag | `release/v1.0.0-beta1` |
| Hotfix | `master` | `master` and `develop`, plus a tag | `hotfix/v1.0.1` |

- `master` (or `main`) only receives releases and hotfixes. Before v1.0.0, `develop`
  may also be merged into it directly.
- Request and hotfix branches are implemented in git worktrees under
  `.claude/worktrees/`, so several sessions can implement several requests in
  parallel. A worktree only lives during the implementation.
- Spec discussions, reviews, merges, and releases share the root checkout, so only one
  of them runs at a time.
- Every merge uses `--no-ff`. A branch can be merged locally, or through a merge
  request on GitHub or GitLab.

## Repository layout after init

```
repo/
├─ AGENTS.md, CLAUDE.md      workflow rules for agents (CLAUDE.md imports AGENTS.md)
├─ README.md, README-zh-TW.md
├─ Directory.Build.props     the single version source (.NET projects)
├─ src/                      source projects, one folder each, each with a README.md
├─ reqs/                     open requests; finished ones in reqs/done/
├─ docs/                     project spec, developer docs, knowledge base
├─ external/                 submodules and third-party binaries
├─ tests/                    test projects (optional)
└─ samples/                  sample and demo projects (optional)
```

The layout is designed around Visual Studio / .NET projects. For other project types,
init asks which parts to keep.

## Requirements

- [Claude Code](https://code.claude.com/docs)
- git
- Optional: the `gh` or `glab` CLI, for merge requests on GitHub or GitLab
- Optional: the .NET SDK, for .NET projects

## Installation

Add this repository as a plugin marketplace, then install the plugin. Run these inside
a Claude Code session:

```
/plugin marketplace add <owner>/ss-workflow
/plugin install ss-workflow@ss-workflow
```

Replace `<owner>/ss-workflow` with the GitHub repository, or use the full git URL for
another host.

To let everyone who works in a project get the plugin, `/ss-workflow-init` can
register the marketplace in the project's `.claude/settings.json`.

## Quick start

```
/ss-workflow-init                      set up the repository (answer the questions)
/ss-workflow-new-req add a dark theme  create a request and agree on its spec
/ss-workflow-check-req                 claim it and implement it in a worktree
/ss-workflow-review                    verify it and review it in the root checkout
/ss-workflow-merge                     accept it: close it and merge it into develop
/ss-workflow-release                   release a new version
```

## Updating

The marketplace compares the `version` in `.claude-plugin/plugin.json` with the
installed version.

```
/plugin marketplace update ss-workflow
```

A plugin update does not change the files that init generated in your project. After
an update, run `/ss-workflow-init` in the project again. It compares the
`ss-workflow-version` recorded in the root `AGENTS.md` with the plugin version, and
updates only the blocks marked `<!-- ss-workflow:managed -->`. Your own text outside
those blocks stays as it is.

## Developing this plugin

```
.claude-plugin/
├─ plugin.json               plugin manifest; "version" is the single version source
└─ marketplace.json          makes this repository its own marketplace
skills/
├─ ss-workflow-init/         SKILL.md, references/, templates/
├─ ss-workflow-new-req/      SKILL.md
├─ ss-workflow-check-req/    SKILL.md, references/
├─ ss-workflow-review/       SKILL.md
├─ ss-workflow-merge/        SKILL.md, references/
└─ ss-workflow-release/      SKILL.md, references/
ss-workflow-skill.md         the design spec (Traditional Chinese)
```

Validate the manifests, and load the plugin from the working copy for one session:

```bash
claude plugin validate .
```

```bash
claude --plugin-dir /path/to/ss-workflow
```

When you publish a change, raise `version` in `.claude-plugin/plugin.json`. Without a
new version, installed copies do not update.

The design decisions behind the skills are recorded in
[ss-workflow-skill.md](ss-workflow-skill.md).

## License

MIT. See [LICENSE](LICENSE).
