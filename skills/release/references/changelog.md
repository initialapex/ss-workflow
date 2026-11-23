# Changelog

`CHANGELOG.md` in the project's root folder lists what each version of the project
changed. It is a file of the project: it names no request id, no workspace, and no
workspace file (see "Workspace and projects" in the root `AGENTS.md`). Paths below are
relative to the project folder, `<path>` is the project's `path`, and `<name>` its
`name`.

Three skills write it, each at its own moment:

| Moment | Who | What is written |
|--------|-----|-----------------|
| A request's project branch is merged into the develop branch | `/ss-workflow:merge` (request) | The branch's changes, in `## Unreleased` ("Add the changes of a branch") |
| A release candidate or a final version of a release branch | `/ss-workflow:release` | The section of the version ("Write the section of a version") |
| A hotfix | `/ss-workflow:merge` (hotfix) | The section of the hotfix version ("Write the section of a version") |
| An alpha or beta version | `/ss-workflow:release` | Nothing: this version has no commit. Only the notes of the platform release are made ("Notes for the platform release") |

Every run that writes a version section first fills in the versions that the file
lacks ("Fill in the missing versions").

## Format

```markdown
# CHANGELOG

## Unreleased

### feature

1. Add the CSV export to the report window

## v1.1.0 (2026-11-23)

### feature

1. Add the zoom slider to the preview
2. Add the retry option to the upload

### bugfix

1. Fix the crash when the device is unplugged while scanning

### misc

1. Update the build to the new SDK

### contribution

1. Scott Chang (scott@example.com)
2. Amy Lin (amy@example.com)

## v1.0.0 (2026-10-02)
...
```

- The file starts with `# CHANGELOG`, then `## Unreleased` when there is something
  that no version has yet, then one section per version, newest first, in version
  order (not by date). A prerelease section sits above the other sections of its
  `X.Y.Z`: `rc2` above `rc1`.
- A version heading is `## v<version> (yyyy-MM-dd)`: the tag name, and the day the
  section is written (for a backfilled version, the day of its tag). `## Unreleased`
  has no date.
- The subsections come in this order: `### feature`, `### bugfix`, `### misc`,
  `### contribution`. A subsection without an entry is left out. `## Unreleased` has
  no `### contribution`: it is written when the section becomes a version.
- Each subsection is a numbered list that starts at 1. An entry is one line (it may
  wrap) that says what the project does now, in the project's terms, with no commit
  hash. A breaking change starts with `**BREAKING**:` and says what to change.
- The language of the entries is the language of the existing entries. A new file is
  in English.
- Contribution entries are `<name> (<email>)`.

## Which commits count

The commits of a range: `git -C <path> log --no-merges <range>`.

Leave out:

- Merge commits (`--no-merges` does it).
- The release's own housekeeping: `chore(release): …`, `docs: update the changelog …`,
  and `docs: update the docs for v…`.

Sort the others by their commit type:

| Commit type | Subsection |
|-------------|------------|
| `feat` | feature |
| `fix` | bugfix |
| `perf`, `refactor`, `docs`, `style`, `test`, `build`, `ci`, `chore`, and any other | misc |

A commit without a type prefix (history from before the Commit convention): read the
subject and the diff. A new capability is a feature, a correction is a bugfix, and the
rest is misc. A commit with `BREAKING CHANGE:` in its body or `!` after its type is
breaking, whatever its subsection.

Write one entry per change, not per commit: the commits of one change (the commit, and
the fixups that follow it on the same branch) are one line, and a change that a later
commit of the same range reverts is not listed. Describe the change from its commits
and its diff, in the project's terms; do not copy a subject that only makes sense to the
developer who wrote it.

## Contribution

The authors of the commits of the range: `git -C <path> log --no-merges
--format="%aN <%aE>" <range>`, without the housekeeping commits. Git applies the project's `.mailmap` itself with `%aN`
and `%aE`. Count a person once, by email without regard to case, and list the people
with the most commits first, then by name. Leave out a bot (a name that ends with
`[bot]`). Only the commits that "Which commits count" lets through count: a person who
made release housekeeping commits only (the version bump, the changelog) is not listed.

Write `<name> (<email>)` in the file. The notes of a platform release carry the name
only ("Notes for the platform release").

## Add the changes of a branch

Used by the merge of a request, for each project of the request, on the project branch
that is up to date with the develop branch (Step "Changelog" of "Prepare" in the merge
skill's `references/request.md`).

1. If the project has no `CHANGELOG.md`, do nothing and say so in the report. The first
   release candidate or final version of the project creates the file, with every
   version that was released ("Fill in the missing versions").
2. The range is `<develop ref>..HEAD`, where the develop ref is `origin/<develop-branch>`
   with a remote, and the local branch otherwise. If it holds no counting commit, do
   nothing.
3. Describe the changes as "Which commits count" says. Append each entry to the list of
   its subsection (`feature`, `bugfix`, `misc`) in `## Unreleased`. Create the
   subsection, and the `## Unreleased` heading directly under `# CHANGELOG`, when they
   are missing. Entries that other branches added are not touched.
4. If the branch already changed `CHANGELOG.md` (`git diff <develop ref>...HEAD --stat
   -- CHANGELOG.md`, an earlier run), add only the changes that its entries do not
   describe yet.
5. Commit in the project, on the project branch: `docs: update the changelog`, with no
   request id and no `Refs:` footer.

## Write the section of a version

Used for a release candidate and for a final version on a release branch (by
`/ss-workflow:release`), and for the hotfix version on a hotfix branch (by
`/ss-workflow:merge`). The tip is the branch's `HEAD`.

1. **Fill in the missing versions** first.
2. The base of the range:
   - Final version of a release branch: the last final tag that is an ancestor of the
     tip. Without one, the start of the history.
   - Hotfix: the last final tag that is an ancestor of the project's main branch.
   - Release candidate: the highest version tag, prerelease or final, that is an
     ancestor of the tip (the previous tag of the target). Without one, the start of
     the history.
3. The entries:
   - **A release candidate**: the entries of `## Unreleased`, if the file has it. Then
     read the counting commits of `<base>..<tip>` and add an entry for every change
     that no entry describes. Compare by meaning, not by text. What is typically missing
     is the changes of developers who work on the project without this workspace, and
     the fixes made on the release branch.
   - **A final version**: the entries of `## Unreleased` and of every
     `## v<X.Y.Z>-…` section of the same `X.Y.Z` (alpha, beta, and release candidate
     sections that exist), joined per subsection in the order of the versions, with
     the same change only once. Then read the counting commits of `<base>..<tip>`,
     where the base is the last final, and add what no entry describes.
   - **A hotfix**: read the counting commits of `<base>..<tip>`. The file has no
     `## Unreleased` on the main branch.
   - Do not remove an entry because the file lists it and git does not show its commit:
     an entry may stand for a change that a squash or an old history rewrite hides. Say
     so in the report.
4. Write the section `## v<version> (yyyy-MM-dd)` with the subsections of "Format",
   and a `### contribution` for the authors of `<base>..<tip>` ("Contribution"). A
   final version counts the whole range from the last final, so its contribution is
   computed again, and not joined from the prerelease sections.
5. Replace the sections that the new one took over: `## Unreleased` and, for a final
   version, the `## v<X.Y.Z>-…` sections of the same `X.Y.Z`. The new section takes the
   place of the topmost of them (directly under `# CHANGELOG` for a hotfix, above the
   section of the previous final). The other sections stay exactly as they are,
   including those in another format.
6. Run again on a branch that already has the section (a fix on the release branch
   after the first run, or a run that continues): keep its entries, add what the
   commits show and the entries do not, and compute the date and the contribution
   again.
7. Commit in the project, on the branch: `docs: update the changelog for v<version>`.
   The commit has no request id and no `Refs:` footer, and holds `CHANGELOG.md` only.

## Fill in the missing versions

Make the file complete for the versions that were released before this run.

1. The released versions are the final tags of the project (`v<X.Y.Z>` with no suffix,
   "The project's tags" in `references/version.md`), in version order. A prerelease has
   no section of its own here: its changes belong to the final version that follows.
2. A final tag is missing when the file has no heading `## v<X.Y.Z>`, with or without a
   date. The version that this run writes has no tag yet and is not missing: "Write the
   section of a version" does it.
3. Without a `CHANGELOG.md`, create it with `# CHANGELOG` and the missing sections.
4. For each missing version, the range runs from the previous final tag in version order
   to its tag; for the first final tag, from the start of the history. Write the section
   from the counting commits of that range only, as "Which commits count", "Format",
   and "Contribution" say, and date it with the day of its tag
   (`git -C <path> log -1 --format=%cs v<version>`).
5. Put each section at the place of its version. Sections that exist are not touched,
   whatever their format. New sections follow "Format".
6. They are part of the commit of the run that needed them, not a commit of their own.
   Say in the report which versions were written, with their ranges, or that the file
   was complete.

## Notes for the platform release

The body of a platform release (`references/package.md`, "Publish"): the subsections of
the version, as "Format" shows them, without the version heading.

- A release candidate or a final version: take the section `## v<version>` of
  `CHANGELOG.md` at the tag.
- An alpha or beta version has no section, because it makes no commit. Make the same
  subsections from the counting commits of `<base>..<tag>`, where the base is the
  highest version tag, prerelease or final, that is an ancestor of the tag (without
  one: the start of the history), as "Write the section of a version" does it, but do not
  write a file. Entries may reuse the wording of `## Unreleased` of the tagged tree,
  which describes the same commits.
- A platform release is public: write the contribution with the names only. The emails
  stay in `CHANGELOG.md`.

Save the notes to `.claude/packages/<name>-v<version>-notes.md` in the workspace root
(the folder that the workspace ignores), and give that file to the platform command.
