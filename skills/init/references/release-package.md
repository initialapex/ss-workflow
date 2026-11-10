# The release package script (`New-ReleasePackage.ps1`)

A release builds the tagged version and uploads its package with the platform release
(see `${CLAUDE_PLUGIN_ROOT}/skills/release/references/package.md`). The package can be
made two ways:

| Way | Settings of the project in root `AGENTS.md` | Who decides what goes into the zip |
|-----|---------------------------------------------|------------------------------------|
| The package script, in the project | `package-command` runs the script; `package-files` is empty | `tools/package.psd1` in the project repository |
| The agent | `package-files` lists glob patterns; `package-command` is empty or prepares the files | The agent, from `package-files` |

The script is the better way for a Windows project that ships binaries: the zip is
the same whoever makes it, the developer and a CI job can run it without the
workspace, and the list of files is versioned with the code that produces them. It
does not depend on `version-source`: a project may use it with a version in a file,
`git-tag`, or `none`.

## What the plugin ships

`${CLAUDE_PLUGIN_ROOT}/skills/init/scripts/New-ReleasePackage.ps1`, for Windows
PowerShell 3.0 or later with .NET Framework 4.5 or later. Its help at the top of the
file is the reference. In short:

- It reads `package.psd1` next to it, a PowerShell data file:

  ```powershell
  @{
      Name      = 'SSDisp'                  # the zip is SSDisp-v<version>.zip
      Platforms = @('x86', 'x64')           # optional: one zip per platform
      Files     = @(
          @{ From = 'SSDisp\bin\{Platform}\Release\*.exe'; To = '' }
          @{ From = 'SSDisp\bin\{Platform}\Release\*.dll'; To = '' }
          @{ From = 'config';                             To = 'config' }
      )
  }
  ```

  `From` is relative to the repository root, with wildcards; a folder brings its
  files with their subfolders. `To` is the folder in the zip. `{Platform}` stands for
  each entry of `Platforms`. The patterns point at the `Release` output: a package is
  always made from the release build.
- **Platforms are listed, not discovered.** With no `Platforms` or one entry, the run
  writes `<Name>-v<version>.zip`; with several, `<Name>-v<version>-<platform>.zip`
  for each. The solution may define more platforms than the project ships (`Any CPU`,
  `Mixed Platforms`); only the listed ones are packaged. `build-command` must build
  each of them: a pattern that matches nothing fails the run.
- **The version**: `-Version`, else the highest version tag on `HEAD` (the zip drops
  the `v`), else, when `Update-GitVersion.ps1` is next to it, the generator's version
  (`1.2.3-4-g1a2b3c4` after a tag). Without any of them it fails.
- **It refuses** uncommitted changes in tracked files or submodules (untracked files
  do not count), a missing version, an unknown placeholder, and two different files
  with the same name in the zip. It writes no zip when any package of the run fails.
- It writes into `dist/` of the repository root by default (`-OutputDirectory` to
  change it), which the project's `.gitignore` must list, and prints each zip as
  `Package: <full path>`. That line is what a release reads.

## Where the files go in a project

```
<project>/
├─ .gitignore              dist/
└─ tools/
   ├─ New-ReleasePackage.ps1
   └─ package.psd1
```

`package-command` of the project:

```
powershell -NoProfile -ExecutionPolicy Bypass -File tools\New-ReleasePackage.ps1
```

`New-ReleasePackage.ps1` is copied unchanged; it carries its version in the line
`ss-workflow-script: New-ReleasePackage <version>`. `package.psd1` belongs to the
project and is never overwritten by an update.

## When the developer is asked

The package script is optional, and it is set up by its own request, separate from
the conversion to `git-tag` ([git-version.md](git-version.md)):

- **Init**: Round 3 of the questionnaire, for each project that ships a package,
  asks whether to make the package script ([questionnaire.md](questionnaire.md)).
- **Add project**: the same question, in the questionnaire for the new project.
- **Upgrade**: the migration that introduced the script asks for each project (see
  `migrations/0.10.0.md`).

For each yes, the project's entry keeps its current `package-command` and
`package-files` for now, and the request below is started after the commit of the
init, the added project, or the upgrade.

## The package script request

Invoke the `ss-workflow:new-req` skill once per project, with the text below as its
input (filled in for that project, in `reqs-language`), with the root checkout on
`develop`, one request after another. It becomes the request's `## Original`; new-req
drafts the spec from it and discusses it with the developer as usual. If you cannot
invoke it, tell the developer to run `/ss-workflow:new-req` with that text.

Before invoking it, propose `Platforms` and `Files` to the developer, and put their
answer into the text:

- Platforms: read the `.sln` (`project-file`), section
  `SolutionConfigurationPlatforms`, and list the platforms of its `Release|<platform>`
  entries. Ask which of them ship. One platform, or `Any CPU` alone, means no
  `Platforms`.
- Files: the executables and libraries of the release output (`OutputPath`,
  `OutDir` of the project files), and anything else the developer names
  (configuration files, documents).

```
Type: chore. Project: <name>.
Make the release package of <name> with the package script of ss-workflow
<plugin version>.

- Copy New-ReleasePackage.ps1 from ${CLAUDE_PLUGIN_ROOT}/skills/init/scripts/ into
  <name>/tools/, unchanged.
- Write <name>/tools/package.psd1: Name = '<name>', Platforms = <the platforms that
  ship, or none>, Files = <the files, from the Release output>.
- Add dist/ to the project's .gitignore.
- Workspace: set package-command of <name> to
  "powershell -NoProfile -ExecutionPolicy Bypass -File tools\New-ReleasePackage.ps1",
  empty its package-files, and describe the script in "Toolchain" of its section in
  projects/AGENTS.md (tools/package.psd1 lists the files; a new output file or
  platform is added there; Windows PowerShell 3.0 or later needed).

Verify: the release build of every listed platform, then the script with
-Version 0.0.0 on a clean checkout, writes one zip per platform into dist/ with
the expected files; git status of the project stays clean.
```

The request changes `package-command` and `package-files` on its workspace branch, so
the new values reach `develop` with the merge, together with the files they need.
Until then, a release packages the project the old way.
