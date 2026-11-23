# CHANGELOG

## v0.14.1 (2026-11-23)

### feature

1. Run the cold read of `new-req` with a spec reader and evidence readers (one per 6 `verified` entries, at most 4) at the same time, and from the second run on read only the changed parts of the spec and the new, changed, or downgraded evidence entries
2. Look for the same kind of gap in the rest of the spec before the next cold read run

### misc

1. Add an eval grader for the parallel readers of the cold read in `new-req`

### contribution

1. Scott Chang (initialapex@gmail.com)

## v0.14.0 (2026-11-23)

### feature

1. Write the project's `CHANGELOG.md` as feature, bugfix, misc, and contribution: merging a request adds its changes to `## Unreleased`, a release candidate or final version turns that into a version section (a final version folds its prerelease sections into one), a hotfix writes its own section, and released versions that the file lacks are filled in from `git log`
2. Use the version section as the notes of the platform release, with the contributors' names only

### misc

1. Cover the changelog in the release and merge evals, with three new eval cases and fixture scenarios

### contribution

1. Scott Chang (initialapex@gmail.com)

## v0.13.0 (2026-11-18)

### feature

1. Give each skill a stage role (requirements engineer, engineering lead and software engineer, CI and CD engineer, and a specialist reviewer per project skill), with a lead review before `check-req` creates branches and worktrees
2. Split a request that is too large by importance, type, and cost, with `Depends on: REQ-xxxx`, and add the GUI rules
3. Describe a script by its behavior, not its lines, in `new-req`

### bugfix

1. Tick only the criteria that "How to verify" assigns to Verify in `review`
2. Write the Q&A entry of a dropped request in the standard format and stage the whole close in `merge`
3. Update the docs that follow a listed change in `check-req`

### misc

1. Move the version generator and the package script to the `ss-build` plugin
2. Take the Visual Studio specifics out of the legacy conversion
3. Take technology out of the workflow and use the project skills (`skills` in the project entry) instead
4. Point the UI and UX principles to `ss-design:ui-ux`
5. Add skill evals for `check-req` (with a workspace fixture, a hotfix, dependencies, and `push-policy: never`), `merge`, `release`, `review`, `new-req`, and `init`, and cover the lead review and the request split
6. Describe the stage roles, request sizing, and GUI rules in the README files, and ignore `.vscode`

### contribution

1. Scott Chang (initialapex@gmail.com)

## v0.12.4 (2026-11-16)

### bugfix

1. Close gaps in the repairs, the resumes, and the checks of `new-req` in `check-req`
2. Finish remote merges of releases, and keep gitlinks out of fixes, in `merge`
3. Check before an upgrade and read the projects before adding them in `init`
4. Define "not applicable", the hotfix Scope line, and develop commits in the request rules

### misc

1. Describe how to install ss-workflow from the scott-skills marketplace

### contribution

1. Scott Chang (initialapex@gmail.com)

## v0.12.3 (2026-11-15)

### bugfix

1. Pick "Add project" in an existing workspace, and release a tested prerelease, in `init`
2. Use existing branches for worktrees, and reserve hotfix ids, in `check-req`
3. Keep develop's gitlinks in a hotfix, and unblock releases and drops, in `merge`
4. Run the migration checks after the managed blocks in `init`

### contribution

1. Scott Chang (initialapex@gmail.com)

## v0.12.1 (2026-11-14)

### feature

1. Write terms out in full instead of abbreviating them in `init`

### misc

1. Describe the rule against abbreviations

### contribution

1. Scott Chang (initialapex@gmail.com)

## v0.12.0 (2026-11-12)

### feature

1. Analyze problems and code from evidence in `new-req`, re-check and extend the evidence in `check-req`, and check it in Verify and Review in `review`
2. Define the evidence rules in `reqs/AGENTS.md`

### misc

1. Describe the evidence rules and the trace

### contribution

1. Scott Chang (initialapex@gmail.com)

## v0.11.0 (2026-11-12)

### feature

1. Write a detailed design and cold-read the spec in `new-req`, implement from it in `check-req`, and check the changes against it in `review`
2. Define the parts of a spec in `reqs/AGENTS.md`

### misc

1. Describe the detailed design and the cold read

### contribution

1. Scott Chang (initialapex@gmail.com)

## v0.10.0 (2026-11-10)

### feature

1. **BREAKING**: tag prereleases (alpha, beta, release candidate) on the develop branch and on release branches, with the version format `X.Y.Z-<stage><R>`
2. Generate the project version from git tags (`version-source: git-tag`), and import `GitVersion.targets` in each project file, from Visual Studio 2010 on
3. Add the release package script `New-ReleasePackage.ps1`

### misc

1. State that tags keep the `v` and that generated versions drop it

### contribution

1. Scott Chang (initialapex@gmail.com)

## v0.9.1 (2026-10-22)

### bugfix

1. Put a converted Visual Studio solution at the root of its project in `init`

### contribution

1. Claude (noreply@anthropic.com)

## v0.9.0 (2026-10-22)

### feature

1. **BREAKING**: keep the projects in `projects/` instead of `src/`

### contribution

1. Claude (noreply@anthropic.com)

## v0.8.0 (2026-10-22)

### feature

1. **BREAKING**: carry a request on one branch from the draft to the implementation
2. **BREAKING**: keep the workspace out of the projects' history: no request id, workspace name, or `Refs:` footer in a project
3. Recommend the next request in `check-req`, unfinished work included

### contribution

1. Claude (noreply@anthropic.com)

## v0.7.0 (2026-10-21)

### feature

1. Let a request change workspace files, and give every project its own docs folder

### misc

1. Describe the docs layout and workspace-only requests

### contribution

1. Claude (noreply@anthropic.com)

## v0.6.0 (2026-10-21)

### feature

1. **BREAKING**: set up a workspace with the projects as git submodules in `init`
2. Settle the projects of a request in `new-req`, and claim and implement in the workspace and the projects in `check-req`
3. Verify and review on both layers of branches in `review`, and merge the projects first, then the workspace, in `merge`
4. Release one project at a time

### misc

1. Cover the workspace and submodule git sequences in the tests
2. Describe the workspace layout in the spec and the README files, and keep empty project settings without a trailing space

### contribution

1. Scott Chang (initialapex@gmail.com)

## v0.5.0 (2026-10-08)

### feature

1. Add the push policy, the Q&A record, and migrations

### misc

1. Cover repositories without a remote or a push in the tests

### contribution

1. Scott Chang (initialapex@gmail.com)

## v0.4.0 (2026-10-07)

### misc

1. Drop the `ss-workflow-` prefix from the skill names

### contribution

1. Scott Chang (initialapex@gmail.com)

## v0.3.0 (2026-10-07)

### feature

1. Add the ss-workflow plugin with the `init`, `new-req`, `check-req`, `merge`, and `release` skills
2. Add the `review` skill: decide every uncommitted change during a review, offer a code review between Verify and Review, and ask what to do when the request branch is not in review
3. Discuss the spec of a request on its own branch, and settle the architecture and explore needs without a solution in `new-req`
4. Claim a request by branch and remove its worktree in `check-req`, and merge from the root checkout
5. Read the toolchain commands from the workflow settings, ask for the project type instead of assuming .NET, and place the solution file in `src`
6. Define the version format and its limits in `release`
7. Restyle the README files and the generated README files with badges and alerts

### bugfix

1. Free the root checkout before `check-req` recreates a worktree
2. Stop using the plugin root variable in the reference files of `init`
3. Correct the claim and branch deletion rules found by testing

### misc

1. Add a script that checks the git sequences of the skills
2. Add the MIT license and the author name, the README files, and the spec of the revised flow and of the setup that does not depend on the project type

### contribution

1. Scott Chang (initialapex@gmail.com)
