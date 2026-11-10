# Building, packaging, and publishing a tagged version

Every version is built from its tag, packaged, and published only after every local
step succeeded: `/ss-workflow:release` follows this for alpha, beta, and release
candidate versions, and the release and hotfix guides of `/ss-workflow:merge` for
final versions.

`<path>` is the project's `path`, `<name>` its `name`, and `<version>` the version
without the `v`.

## Before the first tag: note the starting point

Before the run creates its first tag or merge commit, note the commit of every branch
that it will change, in the project and in the workspace (`git rev-parse <branch>`).
Nothing of the run is on a remote until "Publish", so a run that fails before it can
be undone exactly:

- Delete the tags that the run created: `git -C <path> tag -d v<version>`, and `git tag
  -d <name>/v<version>` in the workspace.
- Put each changed branch back: check it out, then `git reset --hard <noted commit>`.
  Only for commits that are not on a remote: check with `git branch -r --contains
  <commit>` first.

Undo only with the developer's agreement, and say what it removes.

## Build the tagged version

1. Check out the tag in the project: `git -C <path> checkout --detach v<version>`.
   `git -C <path> status --porcelain` must be empty.
2. With `version-source: git-tag`, check that the build sees the tag: `git -C <path>
   describe --tags --exact-match HEAD` prints `v<version>` (another tag on the same
   commit is a problem: report it).
3. Run the project's `setup-command` if it is set, then its `build-command`, in its
   folder. If `build-command` is empty, say that the build is not configured, and ask
   the developer to build this checkout themselves and to say when it is done.
4. `git -C <path> status --porcelain` must still be empty. If the build changed a
   tracked file or created a file that git does not ignore, stop and report it: with
   `git-tag`, an unignored generated file makes every build `-dirty`. The fix belongs
   to the release or hotfix branch (or to a request for an alpha or beta version);
   undo the run's tags first.
5. Run `package-command` if it is set, in the project folder. A command that fails
   stops the run; undo the run's tags first.

## Make the package

A version has a package in one of two ways:

- **`package-command` printed `Package: <path>` lines**, as the plugin's package
  script `New-ReleasePackage.ps1` does
  (`${CLAUDE_PLUGIN_ROOT}/skills/init/references/release-package.md`): those files
  are the packages, one per platform, and the rest of this section is skipped. Check
  that each file exists and that its name contains `-v<version>`: a different version
  (`-dirty`, `-1-g<sha>`, another tag) means the build did not run on the tag; stop
  and report it. List each zip and its entries for the report.
- **Otherwise, `package-files` is set**: the steps below make one zip.

With neither, the version has no package.

1. Expand each pattern of `package-files` in the project folder. A pattern that
   matches nothing is an error: stop and report it, because the build or the package
   command did not produce what the release ships.
2. Copy the matched files into the staging folder `.claude/packages/<name>-v<version>/`
   of the workspace root, keeping their paths relative to the deepest folder that
   contains all of them. The workspace ignores `.claude/packages/`. Remove an old
   staging folder of the same version first.
3. Zip the staging folder's contents into `.claude/packages/<name>-v<version>.zip`,
   with the shell's tool, for example:
   - PowerShell: `Compress-Archive -Path .claude/packages/<name>-v<version>/* -DestinationPath .claude/packages/<name>-v<version>.zip -Force`
   - bash: `(cd .claude/packages/<name>-v<version> && zip -qr ../<name>-v<version>.zip .)`
4. List the zip and the files in it for the report.

## Publish

Only when every local step of the run succeeded, in every repository: the merges, the
tags, the build of the tagged version, and the package.

1. Show what will be published, per repository: the branches and the tags to push,
   and the package with the platform release. Pushing a tag publishes a version, so
   ask once, right before it, whatever `push-policy` says. With `push-policy: never`,
   or if the developer says no, push nothing: show the commands, and say that the
   version exists in this repository only until the developer runs them. The package
   stays in `.claude/packages/`.
2. Push the project first, with everything of this run in one step: `git -C <path>
   push --atomic origin <branches> v<version>`. Then the workspace, which records the
   project's commits: `git push --atomic origin <branches> <name>/v<version>`. The
   guide names the branches.
3. If the remote refuses a push because a branch is protected, do not work around it:
   the guide says how to continue with a merge request. Without a remote, the local
   tag is the version.
4. **Platform release**: when the project tag is on the remote and the project's
   `remote-platform` is not `none`, create the release from the tag, in the project
   folder, with every package of the version as its assets (`<zips>`: one or one per
   platform):
   - GitHub: `gh release create v<version> <zips> --verify-tag --title v<version>
     --generate-notes`, with `--prerelease` for an alpha, beta, or release candidate
     version
   - GitLab: `glab release create v<version> <zips> --name v<version> --notes
     "<notes>"`, where the notes list the changes of this version grouped by type
   Without a package, create the release without an asset. The title and the
   notes describe the project's changes, with no request id and no workspace name.
   Without a remote platform, report the zips' paths: the developer publishes them.
