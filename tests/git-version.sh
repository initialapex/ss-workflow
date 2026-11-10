#!/usr/bin/env bash
# Tests skills/init/scripts/Update-GitVersion.ps1 and GitVersion.targets, the version
# generator that a project with "version-source: git-tag" uses. It builds throwaway
# repositories in a temporary folder and runs the script with Windows PowerShell.
# When the .NET SDK is installed, it also builds a C# project that imports
# GitVersion.targets and reads the version attributes of the built assembly.
#
# It never touches this repository.
#
# Usage:  bash tests/git-version.sh
#         KEEP=1 bash tests/git-version.sh    # keep the sandbox for inspection
set -o pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS="$ROOT/skills/init/scripts"
command -v powershell.exe >/dev/null 2>&1 || { echo "SKIP: Windows PowerShell (powershell.exe) is not available"; exit 0; }
S="$(mktemp -d "${TMPDIR:-/tmp}/ss-workflow-ver-XXXXXX")" || exit 1
cd "$S" || exit 1
S="$(pwd -W 2>/dev/null || pwd)"
echo "sandbox: $S"
export GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_0=core.autocrlf GIT_CONFIG_VALUE_0=false \
  GIT_CONFIG_KEY_1=protocol.file.allow GIT_CONFIG_VALUE_1=always
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid
PASS=0; FAIL=0
ok()   { echo "  PASS  $1"; PASS=$((PASS+1)); }
ng()   { echo "  FAIL  $1"; FAIL=$((FAIL+1)); }
yes_() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else ng "$d"; fi; }
no_()  { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ng "$d"; else ok "$d"; fi; }
eq_()  { if [ "$2" = "$3" ]; then ok "$1"; else ng "$1 (got '$2', want '$3')"; fi; }
sec()  { echo; echo "== $1"; }
PS="$(cygpath -w "$SCRIPTS/Update-GitVersion.ps1" 2>/dev/null || echo "$SCRIPTS/Update-GitVersion.ps1")"
ver()  { powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$PS" -RepoPath "$1" -PrintOnly | tr -d '\r'; }
gen()  { local repo="$1"; shift; powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$PS" -RepoPath "$repo" "$@" | tr -d '\r'; }
commit() { echo "$2" >> "$1/file.txt"; git -C "$1" add -A; git -C "$1" commit -q -m "$2"; }
short() { git -C "$1" rev-parse HEAD | cut -c1-7; }

sec "no git, no commit, no tag: 0.1.0-unknown"
mkdir -p plain; eq_ "a folder outside any repository" "$(ver "$S/plain")" "0.1.0-unknown"
git init -q empty; eq_ "a repository without commits" "$(ver "$S/empty")" "0.1.0-unknown"
git init -q r; commit "$S/r" "first"
eq_ "a repository without tags" "$(ver "$S/r")" "0.1.0-unknown"

sec "on a tag, after it, and dirty"
git -C r tag -a v1.2.3 -m "Release v1.2.3"
eq_ "HEAD is the tag" "$(ver "$S/r")" "1.2.3"
echo "untracked" > r/new.txt
eq_ "an untracked file does not make it dirty" "$(ver "$S/r")" "1.2.3"
echo "changed" >> r/file.txt
eq_ "a changed tracked file makes it dirty" "$(ver "$S/r")" "1.2.3-dirty"
git -C r checkout -q -- file.txt; rm r/new.txt
commit "$S/r" "second"; commit "$S/r" "third"
eq_ "two commits after the tag: distance and a 7-character sha" "$(ver "$S/r")" "1.2.3-2-g$(short "$S/r")"
echo "changed" >> r/file.txt
eq_ "after the tag and dirty" "$(ver "$S/r")" "1.2.3-2-g$(short "$S/r")-dirty"
git -C r checkout -q -- file.txt

sec "only version tags count"
for t in v1.2 v1.2.3.4 v1.2.3-beta.1 v1.2.3-beta v01.2.3 v1.2.3-preview1 v100.0.0 v1.2.3-rc0 release-9.0.0 V9.0.0 9.0.0; do
  git -C r tag "$t"
done
eq_ "other tag formats are ignored" "$(ver "$S/r")" "1.2.3-2-g$(short "$S/r")"
git -C r tag v1.2.4-alpha1
eq_ "a lightweight tag counts" "$(ver "$S/r")" "1.2.4-alpha1"
git -C r checkout -q -b other HEAD~1; commit "$S/r" "elsewhere"; git -C r tag v9.0.0; git -C r checkout -q master
eq_ "a tag that HEAD does not contain is ignored" "$(ver "$S/r")" "1.2.4-alpha1"

sec "the highest version wins, compared as versions"
git init -q o; commit "$S/o" "first"
git -C o tag v2.0.0-alpha2; git -C o tag v2.0.0-alpha10
eq_ "alpha10 is higher than alpha2" "$(ver "$S/o")" "2.0.0-alpha10"
git -C o tag v2.0.0-beta1; eq_ "beta1 is higher than alpha10" "$(ver "$S/o")" "2.0.0-beta1"
git -C o tag v2.0.0-rc1; eq_ "rc1 is higher than beta1" "$(ver "$S/o")" "2.0.0-rc1"
git -C o tag v2.0.0; eq_ "the final version is higher than rc1" "$(ver "$S/o")" "2.0.0"
git -C o tag v1.99.99; eq_ "numbers compare as numbers" "$(ver "$S/o")" "2.0.0"

sec "the highest version, not the nearest tag"
git init -q h; commit "$S/h" "first"; git -C h tag v1.2.0
git -C h checkout -q -b develop; commit "$S/h" "feature"; git -C h tag v1.3.0-alpha1
git -C h checkout -q master; echo "fix" > h/fix.txt; git -C h add fix.txt; git -C h commit -q -m "fix"; git -C h tag v1.2.1
git -C h checkout -q develop; git -C h merge -q --no-ff master -m "Merge master into develop"
echo "  NOTE  git describe --tags: $(git -C h describe --tags)"
eq_ "a hotfix merged back does not hide the alpha" "$(ver "$S/h")" "1.3.0-alpha1-2-g$(short "$S/h")"

sec "submodules"
git init -q sub; commit "$S/sub" "sub first"
git init -q p; commit "$S/p" "first"; git -C p tag v3.0.0
git -C p submodule add -q "$S/sub" sub 2>/dev/null; git -C p commit -q -m "add sub"; git -C p tag -f v3.0.0 >/dev/null
eq_ "clean with a submodule" "$(ver "$S/p")" "3.0.0"
echo "untracked" > p/sub/u.txt
eq_ "an untracked file in the submodule does not make it dirty" "$(ver "$S/p")" "3.0.0"
rm p/sub/u.txt; commit "$S/p/sub" "sub second"
eq_ "a new commit in the submodule makes it dirty" "$(ver "$S/p")" "3.0.0-dirty"
git -C p/sub checkout -q HEAD~1
echo "changed" >> p/sub/file.txt
eq_ "a changed file in the submodule makes it dirty" "$(ver "$S/p")" "3.0.0-dirty"

sec "the generated files"
CS="$(cygpath -w "$S/out/GitVersion.g.cs" 2>/dev/null || echo "$S/out/GitVersion.g.cs")"
H="$(cygpath -w "$S/out/version.h" 2>/dev/null || echo "$S/out/version.h")"
git -C o checkout -q --detach v2.0.0-rc1 2>/dev/null; git -C o tag -d v2.0.0 >/dev/null
yes_ "it writes a .cs and a .h file in one run" gen "$S/o" -OutputPath "$CS","$H" -Prefix APP_
yes_ ".cs: AssemblyVersion with four numbers" grep -q 'AssemblyVersion("2.0.0.0")' out/GitVersion.g.cs
yes_ ".cs: AssemblyFileVersion with four numbers" grep -q 'AssemblyFileVersion("2.0.0.0")' out/GitVersion.g.cs
yes_ ".cs: AssemblyInformationalVersion with the full version" grep -q 'AssemblyInformationalVersion("2.0.0-rc1")' out/GitVersion.g.cs
yes_ ".h: the prefixed numeric macros" sh -c "grep -q '#define APP_VERSION_MAJOR 2' out/version.h && grep -q '#define APP_VERSION_BUILD 0' out/version.h"
yes_ ".h: the full version as a string" grep -q '#define APP_VERSION_STRING "2.0.0-rc1"' out/version.h
yes_ ".h: the numeric string for a resource file" grep -q '#define APP_VERSION_NUMERIC_STRING "2.0.0.0"' out/version.h
yes_ ".h: an include guard" grep -q '#ifndef APP_GIT_VERSION_VERSION_H' out/version.h
no_ "no byte order mark" sh -c "head -c3 out/GitVersion.g.cs | od -An -tx1 | grep -q 'ef bb bf'"
before=$(stat -c %Y out/GitVersion.g.cs); sleep 1
eq_ "an unchanged version leaves the file alone" "$(gen "$S/o" -OutputPath "$CS" | sed 's/.*(\(.*\))$/\1/')" "unchanged"
eq_ "and its time stamp" "$(stat -c %Y out/GitVersion.g.cs)" "$before"
git -C o tag v2.0.0
eq_ "a new version rewrites it" "$(gen "$S/o" -OutputPath "$CS" | sed 's/.*(\(.*\))$/\1/')" "written"
yes_ "with the new version" grep -q 'AssemblyInformationalVersion("2.0.0")' out/GitVersion.g.cs
no_ "an unsupported file type fails" gen "$S/o" -OutputPath "$S/out/version.txt"
yes_ "the script carries its version for the upgrade check" grep -q '^# ss-workflow-script: Update-GitVersion [0-9]' "$SCRIPTS/Update-GitVersion.ps1"
yes_ "and so does the targets file" grep -q 'ss-workflow-script: GitVersion.targets [0-9]' "$SCRIPTS/GitVersion.targets"

sec "an SDK-style C# project that imports GitVersion.targets"
if ! command -v dotnet >/dev/null 2>&1; then
  echo "  SKIP  the .NET SDK is not installed"
else
  git init -q cs; mkdir -p cs/tools cs/App
  cp "$SCRIPTS/Update-GitVersion.ps1" "$SCRIPTS/GitVersion.targets" cs/tools/
  cat > cs/App/App.csproj <<'EOF'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net10.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>
  <Import Project="..\tools\GitVersion.targets" />
</Project>
EOF
  cat > cs/App/Program.cs <<'EOF'
using System.Reflection;
var a = typeof(Program).Assembly;
Console.WriteLine($"{a.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion}|{a.GetName().Version}|{a.GetCustomAttribute<AssemblyFileVersionAttribute>()?.Version}");
EOF
  printf "bin/\nobj/\n" > cs/.gitignore
  git -C cs add -A; git -C cs commit -q -m "first"; git -C cs tag -a v1.4.0 -m "Release v1.4.0"
  build() { ( cd cs/App && dotnet build -nologo -v q -c Release >"$S/build.log" 2>&1 ); }
  run() { dotnet "cs/App/bin/Release/net10.0/App.dll" | tr -d '\r'; }
  if build; then
    ok "the project builds with the generated version file"
    eq_ "the assembly carries the tag's version" "$(run)" "1.4.0|1.4.0.0|1.4.0.0"
    eq_ "the build leaves the repository clean" "$(git -C cs status --porcelain | wc -l | tr -d ' ')" "0"
    g=$(ls cs/App/obj/Release/net10.0/GitVersion.g.cs 2>/dev/null)
    yes_ "the generated file is in obj/, which git ignores" git -C cs check-ignore -q "App/obj/Release/net10.0/GitVersion.g.cs"
    before=$(stat -c %Y "$g"); sleep 1; build
    eq_ "a second build leaves the generated file alone" "$(stat -c %Y "$g")" "$before"
    echo "// change" >> cs/App/Program.cs; git -C cs commit -q -am "second"
    build && eq_ "one commit after the tag" "$(run)" "1.4.0-1-g$(short "$S/cs")|1.4.0.0|1.4.0.0"
    echo "// dirty" >> cs/App/Program.cs
    build && eq_ "with uncommitted changes" "$(run)" "1.4.0-1-g$(short "$S/cs")-dirty|1.4.0.0|1.4.0.0"
  else
    ng "the project builds with the generated version file (see $S/build.log)"; cat "$S/build.log" | tail -20
  fi
fi

sec "an old-style C# project built by MSBuild 4 (as Visual Studio 2012 does)"
MSB4=/c/Windows/Microsoft.NET/Framework/v4.0.30319/MSBuild.exe
if [ ! -x "$MSB4" ]; then
  echo "  SKIP  the MSBuild of the .NET Framework is not installed"
else
  git init -q old; mkdir -p old/tools old/App/Properties
  cp "$SCRIPTS/Update-GitVersion.ps1" "$SCRIPTS/GitVersion.targets" old/tools/
  cat > old/App/App.csproj <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<Project ToolsVersion="4.0" DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <PropertyGroup>
    <Configuration Condition=" '$(Configuration)' == '' ">Debug</Configuration>
    <Platform Condition=" '$(Platform)' == '' ">AnyCPU</Platform>
    <OutputType>Exe</OutputType>
    <RootNamespace>App</RootNamespace>
    <AssemblyName>App</AssemblyName>
    <TargetFrameworkVersion>v4.5</TargetFrameworkVersion>
  </PropertyGroup>
  <PropertyGroup Condition=" '$(Configuration)|$(Platform)' == 'Release|AnyCPU' ">
    <OutputPath>bin\Release\</OutputPath>
    <Optimize>true</Optimize>
  </PropertyGroup>
  <ItemGroup>
    <Reference Include="System" />
  </ItemGroup>
  <ItemGroup>
    <Compile Include="Program.cs" />
    <Compile Include="Properties\AssemblyInfo.cs" />
  </ItemGroup>
  <Import Project="$(MSBuildToolsPath)\Microsoft.CSharp.targets" />
  <Import Project="..\tools\GitVersion.targets" />
</Project>
EOF
  cat > old/App/Properties/AssemblyInfo.cs <<'EOF'
using System.Reflection;
[assembly: AssemblyTitle("App")]
EOF
  cat > old/App/Program.cs <<'EOF'
using System;
using System.Reflection;
class Program
{
    static void Main()
    {
        Assembly a = typeof(Program).Assembly;
        var info = (AssemblyInformationalVersionAttribute)Attribute.GetCustomAttribute(a, typeof(AssemblyInformationalVersionAttribute));
        var file = (AssemblyFileVersionAttribute)Attribute.GetCustomAttribute(a, typeof(AssemblyFileVersionAttribute));
        Console.WriteLine(info.InformationalVersion + "|" + a.GetName().Version + "|" + file.Version);
    }
}
EOF
  printf "bin/\nobj/\n" > old/.gitignore
  git -C old add -A; git -C old commit -q -m "first"; git -C old tag -a v2.1.0-beta3 -m "v2.1.0-beta3"
  # Dash switches: Git Bash would rewrite /p:... into a path.
  build4() { ( cd old/App && "$MSB4" App.csproj -nologo -v:q -p:Configuration=Release >"$S/build4.log" 2>&1 ); }
  run4() { old/App/bin/Release/App.exe | tr -d '\r'; }
  if build4; then
    ok "MSBuild 4 builds the project with the generated version file"
    eq_ "the assembly carries the tag's version" "$(run4)" "2.1.0-beta3|2.1.0.0|2.1.0.0"
    eq_ "the build leaves the repository clean" "$(git -C old status --porcelain | wc -l | tr -d ' ')" "0"
    yes_ "the generated file is in obj/" test -f old/App/obj/Release/GitVersion.g.cs
    echo "// change" >> old/App/Program.cs; git -C old commit -q -am "second"
    build4 && eq_ "one commit after the tag" "$(run4)" "2.1.0-beta3-1-g$(short "$S/old")|2.1.0.0|2.1.0.0"
  else
    ng "MSBuild 4 builds the project with the generated version file (see $S/build4.log)"; tail -20 "$S/build4.log"
  fi
fi

echo
echo "RESULT: $PASS passed, $FAIL failed"
cd /
if [ "$FAIL" -eq 0 ] && [ -z "$KEEP" ]; then
  rm -rf "$S"
else
  echo "sandbox kept: $S"
fi
[ "$FAIL" -eq 0 ]
