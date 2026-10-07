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

## Recommending the version

Inputs:

- **Last version**: the last release tag on the main branch, without the `v`. If there
  is no tag yet, there is no last version.
- **Current version**: the value in `version-source`. If `version-source` is `none`,
  there is no current version apart from the last tag.
- **Changes**: the commits on `develop` since the last tag, without merge commits.

### First release (no tag yet)

Recommend the current version from `version-source`, for example `0.1.0`. Do not raise
it: nothing was released under that number yet. If `version-source` is `none`,
recommend `0.1.0`.

### Later releases

Find the highest change level in the commits:

| Change level | How to recognize it |
|--------------|---------------------|
| Breaking | `BREAKING CHANGE:` in a commit body, or `!` after the type (`feat!:`) |
| Feature | A `feat` commit |
| Fix | Anything else (`fix`, `perf`, `refactor`, `docs`, …) |

Then raise the last version:

| Last version | Breaking | Feature | Fix |
|--------------|----------|---------|-----|
| `1.0.0` or higher | MAJOR + 1 (`1.4.2` → `2.0.0`) | MINOR + 1 (`1.4.2` → `1.5.0`) | PATCH + 1 (`1.4.2` → `1.4.3`) |
| Below `1.0.0` | MINOR + 1 (`0.4.2` → `0.5.0`) | MINOR + 1 (`0.4.2` → `0.5.0`) | PATCH + 1 (`0.4.2` → `0.4.3`) |

Below `1.0.0`, a breaking change does not raise MAJOR. Going to `1.0.0` is the
developer's decision: offer it as an option, and do not recommend it on your own.

A part cannot go above 99. If the part to raise is already 99, recommend raising the
next higher part instead (`1.4.99` → `1.5.0`), and say why. If MAJOR is 99 and would
have to be raised, there is no valid next version: say so, and ask the developer.

### Prereleases

- If the last tag is a prerelease (`1.0.0-beta1`), the release is still heading for
  the same `X.Y.Z`. Offer these candidates: the next prerelease of the same stage
  (`1.0.0-beta2`), the first prerelease of the next stage (`alpha` → `beta1`, `beta` →
  `rc1`), and the final version (`1.0.0`). Recommend the next prerelease of the same
  stage, unless the developer said that the version is ready. A stage never goes
  back: after `rc1`, there is no `beta3` of the same `X.Y.Z`.
- If the last tag is a final version, recommend a final version. Offer a prerelease of
  it as an alternative, for example `1.5.0-beta1`. The developer chooses the stage:
  `alpha1`, `beta1`, and `rc1` are all valid starts.

### If `version-source` is already ahead

If the current version in `version-source` is higher than the last version, and no tag
exists for it, someone already chose the next version. Recommend that one.

### Validation

A version is valid when all of these hold:

- It has the form from "Format": `X.Y.Z` or `X.Y.Z-<stage><R>`, with no leading `v`.
  `X`, `Y`, and `Z` are from 0 to 99, the stage is `alpha`, `beta`, or `rc`, and `<R>`
  is 1 or higher. Other suffixes (`-preview1`, `-beta.1`, `-beta`) are not valid.
- It is higher than the last version, by the order from "Format". A prerelease is
  lower than its final version: `1.0.0-rc1` < `1.0.0`.
- The tag `v<version>` exists neither locally (`git tag -l`) nor on the remote
  (`git ls-remote --tags origin`).
- No branch `release/v<version>` exists.

## Setting the version

The goal: after this step, every place that states the product version says the
release version.

### 1. The version source

`version-source` in the root `AGENTS.md` names the file and the field that hold the
product version. How the version is written there depends on the project type, so
read the current value first and keep its form.

- If `version-source` is `none`, the version only exists as the git tag. Skip to
  section 3.
- Otherwise, set the field to the release version.
- Some fields cannot hold the full version. Keep the form that the field already
  uses, and say in the report what you wrote. Common cases:
  - A field with four numeric parts and no prerelease part: write
    `MAJOR.MINOR.PATCH.0`. If the same file has a text field for the full version,
    write the full version there.
  - Separate numeric defines or constants for major, minor, and patch: set each one.
  - A build number or a date that the build fills in by itself: leave it alone.
- If a tool of the project's toolchain is the normal way to change the version, and
  the "Toolchain" section of the root `AGENTS.md` names it, use that tool.

### 2. Other places that carry the version

The "Toolchain" section of the root `AGENTS.md` may list other places that have to
carry the version. Update each of them.

Then search the source folder (`source-dir`), `samples/`, and `tests/` for the last
version string, to find places that nobody listed, such as project files, package
manifests, resource files, and installer definitions. For each hit that states the
product version:

- Set it to the release version, in the form that the place already uses.
- Do not restructure how the project stores its version during a release, even if a
  single place would be cleaner. Mention it in the report as a possible follow-up
  request.
- If a part carries its own version on purpose (a separately versioned component or
  a third-party library), leave it alone. If you cannot tell, ask the developer.

### 3. Documentation

Search `README*.md` and `docs/` for the last version string. Update the places that
state the current version, such as install commands, badges, and "current version"
lines. Leave history alone: changelog entries, migration notes, and examples that
mention an old version on purpose. If a hit is unclear, show it and ask.

### 4. Changelog

If the repository has a `CHANGELOG.md`, add a section for this version at the top,
with the date and the closed requests grouped by type (id and title). Follow the
format of the existing entries. Do not create a changelog if there is none.

### 5. Check

Search the repository for the last version string once more, outside `reqs/` and the
git history. Report the hits that remain, and say why each one was left.
