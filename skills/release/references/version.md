# Version rules

## Format

A version is `X.Y.Z` for a final version, or `X.Y.Z-<stage><R>` for a prerelease.

| Part | Rule |
|------|------|
| `X`, `Y`, `Z` | MAJOR, MINOR, and PATCH. Each is a whole number from 0 to 99, without leading zeros. |
| `<stage>` | `alpha`, `beta`, or `rc`, in lowercase |
| `<R>` | A whole number from 1, without leading zeros. It follows the stage directly, with no separator: `alpha1`, `beta2`, `rc1`. |

A final version has no suffix: `1.0.0`. The tag is the version with a leading `v`:
`v1.0.0`, `v1.0.0-alpha1`.

Order: compare `X`, then `Y`, then `Z`, as numbers. For the same `X.Y.Z`, the order is
`alpha` < `beta` < `rc` < final, and within one stage by `<R>` as a number, so
`1.0.0-alpha2` < `1.0.0-alpha10` < `1.0.0-beta1` < `1.0.0-rc1` < `1.0.0`. Compare in
this way, and not as text: as text, `alpha10` would sort before `alpha2`.

## Where each kind goes

| Kind | Tagged on | Allowed when |
|------|-----------|--------------|
| `alpha`, `beta` | The tip of the project's develop branch | `version-source` is `git-tag` or `none`, and the project has no open `release/*` branch |
| `rc` | The tip of `release/vX.Y.Z`, for that `X.Y.Z` | The release branch exists |
| Final | The merge commit of the release (or hotfix, or pre-1.0 sync) on the project's main branch | Always |

A release candidate tagged before the release branch has a commit of its own (with
`git-tag` or `none` there is no version commit) sits on a commit that the develop
branch contains too. That is expected: until the develop branch moves on, builds
there read the same release candidate.

A project whose version is in a file cannot get an alpha or beta tag: the tag would
sit on the develop branch, which takes no version commit. Offer it a release candidate
instead, and mention that `version-source: git-tag` allows alpha and beta versions.

## The project's tags

Read every tag of the project once (`git -C <path> tag -l "v*"`, after `fetch
--tags`), and keep only those that have the form of "Format" with a leading `v`. Other
tags are not versions: ignore them, and list them in the report if they start with
`v`.

From these tags:

- **Last final**: the highest final version. Without one, there is no last final.
- **Target**: the `X.Y.Z` that the develop branch is heading for. If some prerelease
  is higher than the last final, the target is the `X.Y.Z` of the highest such
  prerelease. Otherwise there is no target yet: "Choosing the target" finds one.
- **Highest of the target**: the highest prerelease whose `X.Y.Z` is the target, if
  any. Its stage decides which stages are still open: a stage never goes back, so
  after `beta2` there is no `alpha3`, and after `rc1` there is no `beta3`.

## Choosing the target

Use this when there is no target yet, and to check a target that the developer
names.

### First release (no final tag yet)

Recommend the current version from `version-source` when it is a file, for example
`0.1.0`. Do not raise it: nothing was released under that number yet. With `git-tag`
or `none`, recommend `0.1.0`.

### Later releases

The changes are the commits on the project's develop branch since the last final tag,
without merge commits (`git -C <path> log --no-merges v<last final>..<project
develop-ref>`). Find the highest change level in them:

| Change level | How to recognize it |
|--------------|---------------------|
| Breaking | `BREAKING CHANGE:` in a commit body, or `!` after the type (`feat!:`) |
| Feature | A `feat` commit |
| Fix | Anything else (`fix`, `perf`, `refactor`, `docs`, …) |

Then raise the last final:

| Last final | Breaking | Feature | Fix |
|------------|----------|---------|-----|
| `1.0.0` or higher | MAJOR + 1 (`1.4.2` → `2.0.0`) | MINOR + 1 (`1.4.2` → `1.5.0`) | PATCH + 1 (`1.4.2` → `1.4.3`) |
| Below `1.0.0` | MINOR + 1 (`0.4.2` → `0.5.0`) | MINOR + 1 (`0.4.2` → `0.5.0`) | PATCH + 1 (`0.4.2` → `0.4.3`) |

Below `1.0.0`, a breaking change does not raise MAJOR. Going to `1.0.0` is the
developer's decision: offer it as an option, and do not recommend it on your own.

A part cannot go above 99. If the part to raise is already 99, recommend raising the
next higher part instead (`1.4.99` → `1.5.0`), and say why. If MAJOR is 99 and would
have to be raised, there is no valid next version: say so, and ask the developer.

If `version-source` is a file whose version is higher than the last final, and no tag
exists for it, someone already chose the next version: recommend that one.

### A target that is outgrown

A target found from the prereleases may be too low for the changes since: for
example `1.4.3-beta1` was tagged after fixes, and a `feat` commit came later. Compare
it with the target that "Later releases" gives. If that one is higher, say so, and
offer both. Moving to the higher target leaves the old prereleases as they are.

A hotfix may also release the target as a final version (`1.4.3` while the develop
branch had `1.4.3-beta1`). Then the target is no longer above the last final, and
"Choosing the target" finds a new one.

## Recommending the version

Offer the candidates of the situation, recommended first. The developer can type any
other valid version through "Other".

| Situation | Candidates |
|-----------|------------|
| On the develop branch, prereleases allowed | The next prerelease of the highest stage of the target (`1.5.0-beta1` → `1.5.0-beta2`; recommended when the target has one), the first prerelease of the next stage (`alpha` → `beta1`), and opening the release branch `release/v<target>`. Without a target: `<target>-alpha1` and `<target>-beta1`, and opening the release branch. |
| On the develop branch, prereleases not allowed (the version is in a file) | Opening the release branch `release/v<target>` |
| Opening a release branch | The first tag on it: `<X.Y.Z>-rc1`, or the final `<X.Y.Z>` directly. A release candidate is not required. Recommend `rc1` when the release branch takes changes that were not in a prerelease yet, and the final version otherwise. |
| On `release/vX.Y.Z` | The next release candidate (`rc<R+1>`, or `rc1` when there is none yet), and the final `X.Y.Z`. Recommend the final version after a release candidate that the developer reports as good; otherwise the next release candidate. The `X.Y.Z` of a release branch never changes. |
| A hotfix | The last final tag reachable from the project's main branch, PATCH + 1. Hotfixes have no prereleases. |

## Validation

A version is valid when all of these hold:

- It has the form from "Format": `X.Y.Z` or `X.Y.Z-<stage><R>`, with no leading `v`.
  `X`, `Y`, and `Z` are from 0 to 99, the stage is `alpha`, `beta`, or `rc`, and `<R>`
  is 1 or higher. Other suffixes (`-preview1`, `-beta.1`, `-beta`) are not valid.
- Its kind fits where it is tagged ("Where each kind goes").
- It is higher than the last final, by the order from "Format". A prerelease is lower
  than its final version: `1.0.0-rc1` < `1.0.0`, so `1.0.0-rc1` is not valid once
  `1.0.0` exists.
- For a prerelease, or a final version of the target: it is higher than the highest
  tag of its `X.Y.Z`, so a stage never goes back.
- On a release branch: its `X.Y.Z` is the branch's.
- The tag `v<version>` exists neither locally (`git tag -l`) nor on the remote
  (`git ls-remote --tags origin`), in the project. The workspace tag `<name>/v<version>`
  does not exist either.
- When it opens a release branch: no branch `release/vX.Y.Z` exists in the project,
  locally or on the remote.

## Setting the version

The goal: after this step, every place that states the project's version says the
release version. All of it happens in the project, on its release or hotfix branch;
paths are relative to the project folder. The workspace changes nothing here: the
places in its docs that state the project's current version are listed now and
changed by the release merge (section 3).

An alpha or beta version has no branch of its own and gets no commit: skip this whole
section for it.

### 1. The version source

`version-source` in the project's entry of `projects` says where the project's
version comes from. How the version is written there depends on the project type, so
read the current value first and keep its form.

- If `version-source` is `git-tag` or `none`, no file is changed: the tag is the
  version. Skip to section 3. With `git-tag`, the generated files that carry the
  version must be ignored by git: if `git -C <path> status --porcelain` shows one
  after a build, stop and report it, because every build would then be `-dirty`.
- Otherwise, set the field to the release version.
- Some fields cannot hold the full version. Keep the form that the field already
  uses, and say in the report what you wrote. Common cases:
  - A field with four numeric parts and no prerelease part: write
    `MAJOR.MINOR.PATCH.0`. If the same file has a text field for the full version,
    write the full version there.
  - Separate numeric defines or constants for major, minor, and patch: set each one.
  - A build number or a date that the build fills in by itself: leave it alone.
- If a tool of the project's toolchain is the normal way to change the version, and
  "Toolchain" in the project's section of `projects/AGENTS.md` names it, use that tool.

### 2. Other places that carry the version

Skip this section with `git-tag` or `none`.

"Toolchain" in the project's section of `projects/AGENTS.md` may list other places that
have to carry the version. Update each of them.

Then search the whole project for the previous version string (the version that
`version-source` held before section 1), to find places that nobody listed, such as
project files, package manifests, resource files, and installer definitions, also in
its test and sample projects. For each hit that states the project's version:

- Set it to the release version, in the form that the place already uses.
- Do not restructure how the project stores its version during a release, even if a
  single place would be cleaner. Mention it in the report as a possible follow-up
  request.
- If a part carries its own version on purpose (a separately versioned component or
  a third-party library), leave it alone. If you cannot tell, ask the developer.

Other projects of the workspace keep their own versions. If one of them states this
project's version (a dependency with a pinned version), do not change it in the
release: mention it in the report, as a possible request for that project.

### 3. Documentation

Only for a final version: a release candidate leaves the documentation alone.

Search the project's `README*.md` and docs for the last final version string. Update
the places that state the current version, such as install commands, badges, and
"current version" lines. Leave history alone: changelog entries, migration notes, and
examples that mention an old version on purpose. If a hit is unclear, show it and
ask.

The workspace's docs may state the project's current version too, mostly in
`docs/<name>/` and `docs/overview.md`. Search them for the last final version string,
list the hits, and ask. The workspace has no release branch, so these changes are not
made here: the release merge makes them on the workspace `develop`, before it merges
`develop` into the workspace main branch (step 1 of "Merge the workspace" in the
merge skill's `references/release.md`).

### 4. Changelog

Only for a final version. If the project has a `CHANGELOG.md`, add a section for this
version at the top, with the date and the changes of this version grouped by type:
the closed requests of this project and the changes made outside this workspace (Step
2 of the skill), one line each. Describe each change in the project's terms, in the
language of the existing entries. The changelog is a file of the project, so it names
no request id and no workspace (see "Workspace and projects" in the root `AGENTS.md`).
Follow the format of the existing entries. Do not create a changelog if there is
none.

### 5. Check

Search the project for the previous version string once more, outside the git
history. Report the hits that remain, and say why each one was left.
