#!/usr/bin/env bash
# Tests skills/init/scripts/New-ReleasePackage.ps1, the release package script that a
# project copies into its tools/ folder. It builds throwaway repositories in a
# temporary folder, with fake build output, and runs the script with Windows
# PowerShell.
#
# It never touches this repository.
#
# Usage:  bash tests/release-package.sh
#         KEEP=1 bash tests/release-package.sh    # keep the sandbox for inspection
set -o pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS="$ROOT/skills/init/scripts"
command -v powershell.exe >/dev/null 2>&1 || { echo "SKIP: Windows PowerShell (powershell.exe) is not available"; exit 0; }
S="$(mktemp -d "${TMPDIR:-/tmp}/ss-workflow-pkg-XXXXXX")" || exit 1
cd "$S" || exit 1
S="$(pwd -W 2>/dev/null || pwd)"
echo "sandbox: $S"
export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.autocrlf GIT_CONFIG_VALUE_0=false
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid
PASS=0; FAIL=0
ok()   { echo "  PASS  $1"; PASS=$((PASS+1)); }
ng()   { echo "  FAIL  $1"; FAIL=$((FAIL+1)); }
yes_() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else ng "$d"; fi; }
no_()  { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ng "$d"; else ok "$d"; fi; }
eq_()  { if [ "$2" = "$3" ]; then ok "$1"; else ng "$1 (got '$2', want '$3')"; fi; }
sec()  { echo; echo "== $1"; }
psrun() { powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass "$@" | tr -d '\r'; }
# pkg <repo> [args]: runs the repository's own copy of the script
pkg()  { local repo="$1"; shift; psrun -File "$repo/tools/New-ReleasePackage.ps1" "$@"; }
# entries <zip>: the entry names of a zip, sorted, on one line
entries() { psrun -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; \$z = [IO.Compression.ZipFile]::OpenRead('$1'); \$z.Entries | ForEach-Object { \$_.FullName }; \$z.Dispose()" | LC_ALL=C sort | tr '\n' ' '; }
config() { cat > "$1/tools/package.psd1"; }
# repo <name> [with-generator]: a repository with the script and fake Release output
repo() {
  git init -q "$1"; mkdir -p "$1/tools" "$1/config/sub"
  cp "$SCRIPTS/New-ReleasePackage.ps1" "$1/tools/"
  [ -n "$2" ] && cp "$SCRIPTS/Update-GitVersion.ps1" "$1/tools/"
  for p in x86 x64; do
    mkdir -p "$1/App/bin/$p/Release"
    echo "exe $p" > "$1/App/bin/$p/Release/App.exe"; echo "dll $p" > "$1/App/bin/$p/Release/Lib.dll"
    echo "pdb $p" > "$1/App/bin/$p/Release/App.pdb"
  done
  echo '{}' > "$1/config/app.json"; echo '{}' > "$1/config/sub/more.json"
  printf "bin/\ndist/\n" > "$1/.gitignore"
}

sec "one package from a tag"
repo r
config r <<'EOF'
@{
    Name  = 'App'
    Files = @(
        @{ From = 'App\bin\x64\Release\*.exe'; To = '' }
        @{ From = 'App\bin\x64\Release\*.dll'; To = '' }
        @{ From = 'config'; To = 'config' }
    )
}
EOF
git -C r add -A; git -C r commit -q -m first; git -C r tag -a v1.2.0 -m v1.2.0
out="$(pkg "$S/r")"
eq_ "it prints the package it wrote" "$out" "Package: $(cygpath -w "$S/r/dist/App-v1.2.0.zip")"
yes_ "the zip is in dist/ of the repository, named after the tag without the v" test -f r/dist/App-v1.2.0.zip
eq_ "files go into To, a folder keeps its subfolders, only the listed files" "$(entries "$S/r/dist/App-v1.2.0.zip")" "App.exe Lib.dll config/app.json config/sub/more.json "
config r <<'EOF'
@{ Name = 'App'; Files = @( @{ From = 'App\bin\x64\Release\App.exe'; To = '' }, @{ From = 'App\bin\x64\Release\*.exe'; To = '' } ) }
EOF
git -C r commit -q -am overlap; git -C r tag -f v1.2.0 >/dev/null
yes_ "two patterns that match the same file put it in once" pkg "$S/r" -OutputDirectory "$S/o0"
git -C r reset -q --hard HEAD~1; git -C r tag -f v1.2.0 >/dev/null
eq_ "dist/ is ignored, so the repository stays clean" "$(git -C r status --porcelain | wc -l | tr -d ' ')" "0"
yes_ "a second run replaces the zip" pkg "$S/r"

sec "the version"
git -C r tag v1.2.0-rc1
eq_ "of several version tags on HEAD, the highest" "$(pkg "$S/r" -OutputDirectory "$S/o1")" "Package: $(cygpath -w "$S/o1/App-v1.2.0.zip")"
eq_ "-Version wins, with or without the v" "$(pkg "$S/r" -OutputDirectory "$S/o1" -Version v1.3.0-beta2)" "Package: $(cygpath -w "$S/o1/App-v1.3.0-beta2.zip")"
no_ "an invalid -Version fails" pkg "$S/r" -OutputDirectory "$S/o1" -Version 1.2
echo "x" > r/new.txt
yes_ "an untracked file does not stop it" pkg "$S/r" -OutputDirectory "$S/o1"
rm r/new.txt
echo "# changed" >> r/tools/package.psd1
no_ "uncommitted changes stop it" pkg "$S/r" -OutputDirectory "$S/o1"
git -C r checkout -q -- tools/package.psd1
echo "x" >> r/config/app.json; git -C r commit -q -am second
no_ "after the tag, without the version generator, it fails" pkg "$S/r" -OutputDirectory "$S/o1"
yes_ "and says why" sh -c "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File '$S/r/tools/New-ReleasePackage.ps1' -OutputDirectory '$S/o1' 2>&1 | grep -q 'no version tag'"
yes_ "-Version still works there" pkg "$S/r" -OutputDirectory "$S/o1" -Version 1.2.1

sec "with the version generator next to it"
repo g with-generator
config g <<'EOF'
@{ Name = 'App'; Files = @( @{ From = 'App\bin\x64\Release\App.exe'; To = 'bin' } ) }
EOF
git -C g add -A; git -C g commit -q -m first
no_ "no tag at all fails (0.1.0-unknown)" pkg "$S/g"
git -C g tag v2.0.0-alpha1; echo "x" >> g/config/app.json; git -C g commit -q -am second
sha=$(git -C g rev-parse HEAD | cut -c1-7)
eq_ "after a tag, the generator's version" "$(pkg "$S/g")" "Package: $(cygpath -w "$S/g/dist/App-v2.0.0-alpha1-1-g$sha.zip")"
eq_ "a single file into a folder" "$(entries "$S/g/dist/App-v2.0.0-alpha1-1-g$sha.zip")" "bin/App.exe "

sec "platforms"
config r <<'EOF'
@{
    Name      = 'App'
    Platforms = @('x86', 'x64')
    Files     = @(
        @{ From = 'App\bin\{Platform}\Release\*.exe'; To = '' }
        @{ From = 'App\bin\{Platform}\Release\*.dll'; To = 'lib' }
    )
}
EOF
git -C r commit -q -am platforms; git -C r tag v1.3.0
out="$(pkg "$S/r" -OutputDirectory "$S/o2" | tr '\n' ' ')"
eq_ "several platforms: one zip each, with the platform in the name" "$out" "Package: $(cygpath -w "$S/o2/App-v1.3.0-x86.zip") Package: $(cygpath -w "$S/o2/App-v1.3.0-x64.zip") "
eq_ "each with its platform's files" "$(entries "$S/o2/App-v1.3.0-x86.zip")" "App.exe lib/Lib.dll "
yes_ "and its content" sh -c "powershell.exe -NoProfile -Command \"Add-Type -AssemblyName System.IO.Compression.FileSystem; \\\$z=[IO.Compression.ZipFile]::OpenRead('$S/o2/App-v1.3.0-x86.zip'); \\\$r=New-Object IO.StreamReader(\\\$z.GetEntry('App.exe').Open()); \\\$r.ReadToEnd(); \\\$r.Dispose(); \\\$z.Dispose()\" | grep -q 'exe x86'"
sed -i "s/@('x86', 'x64')/@('x64')/" r/tools/package.psd1; git -C r commit -q -am one; git -C r tag -f v1.3.0 >/dev/null
eq_ "one platform: no suffix" "$(pkg "$S/r" -OutputDirectory "$S/o3")" "Package: $(cygpath -w "$S/o3/App-v1.3.0.zip")"
rm -rf r/App/bin/x86
sed -i "s/@('x64')/@('x86', 'x64')/" r/tools/package.psd1; git -C r commit -q -am two; git -C r tag -f v1.3.0 >/dev/null
no_ "a platform that was not built fails" pkg "$S/r" -OutputDirectory "$S/o4"
yes_ "and writes no zip for the other platforms" test ! -e "$S/o4"

sec "invalid configurations"
bad() {
  config r; git -C r commit -q -am "bad $1"; git -C r tag -f v1.3.0 >/dev/null
  no_ "$1" pkg "$S/r" -OutputDirectory "$S/o5"
}
bad "{Platform} without Platforms" <<'EOF'
@{ Name = 'App'; Files = @( @{ From = 'App\bin\{Platform}\Release\*.exe'; To = '' } ) }
EOF
bad "an unknown placeholder" <<'EOF'
@{ Name = 'App'; Files = @( @{ From = 'App\bin\{Configuration}\*.exe'; To = '' } ) }
EOF
bad "two different files with the same name in the zip" <<'EOF'
@{ Name = 'App'; Files = @( @{ From = 'App\bin\x64\Release\App.exe'; To = '' }, @{ From = 'App\bin\x86\Release\App.exe'; To = '' } ) }
EOF
bad "a name with a space" <<'EOF'
@{ Name = 'My App'; Files = @( @{ From = 'App\bin\x64\Release\*.exe'; To = '' } ) }
EOF
bad "no files" <<'EOF'
@{ Name = 'App'; Files = @() }
EOF
bad "a command in the data file" <<'EOF'
@{ Name = (Get-Date).ToString('yyyy'); Files = @( @{ From = 'App\bin\x64\Release\*.exe'; To = '' } ) }
EOF
bad "not a hashtable" <<'EOF'
'App'
EOF
yes_ "the script carries its version for the upgrade check" grep -q '^# ss-workflow-script: New-ReleasePackage [0-9]' "$SCRIPTS/New-ReleasePackage.ps1"

echo
echo "RESULT: $PASS passed, $FAIL failed"
cd /
if [ "$FAIL" -eq 0 ] && [ -z "$KEEP" ]; then
  rm -rf "$S"
else
  echo "sandbox kept: $S"
fi
[ "$FAIL" -eq 0 ]
