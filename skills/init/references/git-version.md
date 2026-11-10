# The version from git tags (`version-source: git-tag`)

With `version-source: git-tag`, a project has no version number in its files. The
build reads the version from the git tags and writes it into generated files that git
ignores; a release tags first and builds afterwards (see "Versioning" in root
`AGENTS.md`).

The plugin ships a generator for this, in `${CLAUDE_PLUGIN_ROOT}/skills/init/scripts/`:

| File | What it does |
|------|--------------|
| `Update-GitVersion.ps1` | Reads the highest version tag that `HEAD` contains, and writes `.cs` and `.h` files. Windows PowerShell 5.1 or later. |
| `GitVersion.targets` | Runs the script before the compiler in MSBuild: for C# it adds `obj\…\GitVersion.g.cs` to the compilation and turns off the SDK's own version attributes; for C++ (`.vcxproj`) it writes `GitVersion.g.h` next to the project file. |

**The tag has the `v`, the version it writes does not.** The project's tags always
start with `v` (`v1.2.3`, `v1.2.3-beta4`, `v1.2.3-rc1`); a tag without it does not
count. The generator drops the `v` from the tag it found and writes the rest, as
.NET versions and most version macros expect:

| State | Tag that counts | Version it writes | Numeric fields |
|-------|-----------------|-------------------|----------------|
| `HEAD` is the tagged commit | `v1.2.3` | `1.2.3` | `1.2.3.0` |
| The same, with uncommitted changes in tracked files or submodules (untracked files do not count) | `v1.2.3` | `1.2.3-dirty` | `1.2.3.0` |
| Four commits after the tag | `v1.2.3` | `1.2.3-4-g1a2b3c4` | `1.2.3.0` |
| Five commits after a prerelease tag, with changes | `v1.2.3-beta4` | `1.2.3-beta4-5-g1a2b3c4-dirty` | `1.2.3.0` |
| No version tag, a shallow clone without tags, or no git | none | `0.1.0-unknown` | `0.1.0.0` |

Only tags in the form of "Versioning" count (`vX.Y.Z` or `vX.Y.Z-<alpha|beta|rc>R`),
annotated or lightweight; of those that
`HEAD` contains, the highest version wins, not the nearest tag. The sha has 7
characters. `.cs`: `AssemblyVersion` and `AssemblyFileVersion` take the numeric
fields, `AssemblyInformationalVersion` the full version. `.h`:
`<PREFIX>VERSION_MAJOR`, `_MINOR`, `_PATCH`, `_BUILD` (0), `_STRING` (the full
version), and `_NUMERIC_STRING`, also usable in a `.rc` file. A file is written only
when its content changes.

## Toolchains

| Toolchain | Support |
|-----------|---------|
| C# with MSBuild, SDK-style or old-style projects | `GitVersion.targets`, imported from `Directory.Build.targets` |
| C++ with MSBuild (`.vcxproj`) | `GitVersion.targets`, imported from `Directory.Build.targets`; the code and the `.rc` file include `GitVersion.g.h` |
| CMake | Not yet (planned) |
| Others (Keil, ESP-IDF, Python, Node, …) | Not supported by the plugin. A project may still use `git-tag` when it generates its version from the tags in its own way: then it needs no conversion request, and "Toolchain" in its section of `projects/AGENTS.md` says how it does it. |

The generator runs on Windows only, because MSBuild starts `powershell.exe`.

## Where the files go in a project

Into the project repository, in `tools/` by default (the developer may choose another
folder):

```
<project>/
├─ Directory.Build.targets      <Import Project="$(MSBuildThisFileDirectory)tools\GitVersion.targets" />
└─ tools/
   ├─ Update-GitVersion.ps1
   └─ GitVersion.targets
```

If the project already has a `Directory.Build.targets`, add the `<Import>` to it. The
files are copied unchanged: each one carries its version in a line
`ss-workflow-script: <name> <version>`, which the upgrade compares (below).

## The conversion request

Init writes nothing into a project repository, and every project change goes through
a request (see "Workspace and projects" in root `AGENTS.md`). So when the developer
chooses `git-tag` for a project whose toolchain is supported, in init (Round 3 of the
questionnaire), when a project is added, or in an upgrade, the project keeps its
current `version-source` for now, and a request does the conversion.

After the commit of the init, the added project, or the upgrade, invoke the
`ss-workflow:new-req` skill once per project, with the text below as its input
(filled in for that project, in `reqs-language`). It becomes the request's `##
Original`; new-req drafts the spec from it and discusses it with the developer as
usual. If you cannot invoke it, tell the developer to run `/ss-workflow:new-req` with
that text.

```
Type: chore. Project: <name>.
Take the version of <name> from its git tags (version-source: git-tag), with the
version generator of ss-workflow <plugin version>.

- Copy Update-GitVersion.ps1 and GitVersion.targets from
  ${CLAUDE_PLUGIN_ROOT}/skills/init/scripts/ into <name>/tools/, unchanged.
- Import tools/GitVersion.targets from the project's Directory.Build.targets
  (create it, or add the <Import> to the existing one).
- C#: remove AssemblyVersion, AssemblyFileVersion, and AssemblyInformationalVersion
  from Properties/AssemblyInfo.cs, and <Version>, <VersionPrefix>, <AssemblyVersion>,
  <FileVersion>, and <InformationalVersion> from the project files. Other attributes
  stay.
- C++: include GitVersion.g.h where the version is used, also in the .rc file
  (FILEVERSION from the VERSION_MAJOR/MINOR/PATCH/BUILD macros, the version strings
  from VERSION_STRING), and remove the old version defines. Add GitVersion.g.h to
  the project's .gitignore.
- Workspace: set version-source of <name> to git-tag, and describe the generator in
  "Toolchain" of its section in projects/AGENTS.md (where the files are, Windows
  PowerShell needed). Remove the other places that carried the version from that
  section.

Verify: the build passes; git status of the project is clean after the build (the
generated file is ignored); on a commit with a tag vX.Y.Z the built binaries carry
X.Y.Z, and one commit after it X.Y.Z-1-g<sha>.
```

Until that request is merged, a release of the project still sets the version in its
file. The request changes `version-source` on its workspace branch, so the new value
reaches `develop` with the merge, together with the project change that it describes.

## Keeping the generator up to date

In the health check of an upgrade, and before each release of a project with
`version-source: git-tag`:

1. Find the generator files on the project's develop branch: `git -C <path> ls-tree
   -r --name-only <develop-ref> | grep -E '(^|/)(Update-GitVersion\.ps1|GitVersion\.targets)$'`.
2. Read the version in their `ss-workflow-script:` line (`git -C <path> show
   <develop-branch>:<file>`), and compare it with the file of the same name in
   `${CLAUDE_PLUGIN_ROOT}/skills/init/scripts/`.
3. Report:
   - An older version: offer a `chore` request "update the version generator of
     <name> to <version>" through `/ss-workflow:new-req`. It copies the new files
     unchanged; the plugin's migration files say when a new version needs more.
   - No file found: the conversion request has not been merged, or the project
     generates its version in its own way. Say so; do not change anything.
   - A file that differs from the plugin's file of the same version: someone changed
     it in the project. Report it; an update would overwrite that change.

A release does not stop for an older generator: it mentions it in the report.
