<#
.SYNOPSIS
    Writes the version of this repository, read from its git tags, into generated
    source files.

.DESCRIPTION
    The version comes from the highest version tag that HEAD contains:

        1.2.3                          HEAD is the tag v1.2.3
        1.2.3-dirty                    the same, with uncommitted changes
        1.2.3-4-g1a2b3c4               four commits after v1.2.3
        1.2.3-beta4-5-g1a2b3c4-dirty   five commits after v1.2.3-beta4, with changes
        0.1.0-unknown                  no version tag, or no git

    Only tags of the form vX.Y.Z or vX.Y.Z-<alpha|beta|rc><R> count (X, Y, Z from 0
    to 99, R from 1, no leading zeros), annotated or lightweight. Of those that HEAD
    contains, the highest version wins (final > rc > beta > alpha), not the nearest
    tag. Untracked files do not make the version dirty; changes in submodules do.

    The output format follows the file extension of each -OutputPath:

        .cs   AssemblyVersion and AssemblyFileVersion "X.Y.Z.0",
              AssemblyInformationalVersion with the full version
        .h    <PREFIX>VERSION_MAJOR, _MINOR, _PATCH, _BUILD (0), _STRING (the full
              version), and _NUMERIC_STRING ("X.Y.Z.0"), usable from .rc files too

    A file is written only when its content changes, so an unchanged version does
    not trigger a rebuild. The generated files must be ignored by git.

    Requires Windows PowerShell 3.0 or later, and git 1.8.5 or later on the PATH.

.PARAMETER OutputPath
    One or more files to write. Relative paths are relative to the current folder.

.PARAMETER Prefix
    The prefix of the macros in a .h file, for example "APP_" for APP_VERSION_MAJOR.
    Empty by default (VERSION_MAJOR).

.PARAMETER RepoPath
    A folder inside the git repository. Defaults to the folder of this script.

.PARAMETER PrintOnly
    Print the version and write nothing.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tools\Update-GitVersion.ps1 -OutputPath obj\GitVersion.g.cs
#>
#Requires -Version 3.0
# ss-workflow-script: Update-GitVersion 1.0.0
[CmdletBinding()]
param(
    [string[]] $OutputPath = @(),
    [string] $Prefix = '',
    [string] $RepoPath = '',
    [switch] $PrintOnly
)

# Windows PowerShell leaves $PSScriptRoot empty in parameter defaults (5.1) or
# altogether (before 3.0), so take the folder from the invocation.
if (-not $RepoPath) { $RepoPath = Split-Path -Parent $MyInvocation.MyCommand.Path }

# Native commands write to stderr on failure; with 'Stop', Windows PowerShell 5.1
# would turn that into a terminating error, so failures are read from $LASTEXITCODE.
$ErrorActionPreference = 'Continue'

$TagPattern = '^v(0|[1-9][0-9]?)\.(0|[1-9][0-9]?)\.(0|[1-9][0-9]?)(?:-(alpha|beta|rc)([1-9][0-9]*))?$'
$Unknown = [pscustomobject]@{ Major = 0; Minor = 1; Patch = 0; Full = '0.1.0-unknown' }

function Invoke-Git {
    # Runs git in the repository and returns its output lines; nothing on failure.
    # Callers wrap the call in @() so that one line stays an array of one line.
    param([string[]] $Arguments)
    $output = & git -C $RepoPath @Arguments 2>$null
    if ($LASTEXITCODE -ne 0) { return }
    $output | Where-Object { $_ -ne $null -and $_ -ne '' }
}

function Get-VersionKey {
    # Returns a string that sorts like the version: X, Y, Z, then the stage
    # (alpha 1, beta 2, rc 3, final 4), then R.
    param($Match)
    $stage = switch ($Match.Groups[4].Value) { 'alpha' { 1 } 'beta' { 2 } 'rc' { 3 } default { 4 } }
    $r = if ($Match.Groups[5].Success) { [int]$Match.Groups[5].Value } else { 0 }
    return '{0:D3}{1:D3}{2:D3}{3}{4:D6}' -f [int]$Match.Groups[1].Value, [int]$Match.Groups[2].Value,
        [int]$Match.Groups[3].Value, $stage, $r
}

function Get-GitVersion {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return $Unknown }
    if (@(Invoke-Git @('rev-parse', '--git-dir')).Count -eq 0) { return $Unknown }
    $head = @(Invoke-Git @('rev-parse', '--verify', '-q', 'HEAD'))
    if ($head.Count -eq 0) { return $Unknown }

    $best = $null
    $bestKey = ''
    foreach ($tag in @(Invoke-Git @('tag', '--list', 'v*', '--merged', 'HEAD'))) {
        $m = [regex]::Match($tag.Trim(), $TagPattern)
        if (-not $m.Success) { continue }
        $key = Get-VersionKey $m
        if ($key -gt $bestKey) { $bestKey = $key; $best = $m }
    }
    if ($null -eq $best) { return $Unknown }

    $tagName = $best.Value
    $full = $tagName.Substring(1)
    $distance = @(Invoke-Git @('rev-list', '--count', "$tagName..HEAD"))
    if ($distance.Count -gt 0 -and [int]$distance[0] -gt 0) {
        # A fixed length of 7, not git's adaptive abbreviation.
        $full += '-{0}-g{1}' -f [int]$distance[0], $head[0].Substring(0, 7)
    }
    $changes = @(Invoke-Git @('status', '--porcelain', '--untracked-files=no', '--ignore-submodules=untracked'))
    if ($changes.Count -gt 0) {
        $full += '-dirty'
    }
    return [pscustomobject]@{
        Major = [int]$best.Groups[1].Value
        Minor = [int]$best.Groups[2].Value
        Patch = [int]$best.Groups[3].Value
        Full  = $full
    }
}

function Get-CSharpText {
    param($Version)
    $numeric = '{0}.{1}.{2}.0' -f $Version.Major, $Version.Minor, $Version.Patch
    return @(
        '// <auto-generated>'
        '//   Generated by Update-GitVersion.ps1 from the git tags. Do not edit or commit.'
        '// </auto-generated>'
        "[assembly: System.Reflection.AssemblyVersion(""$numeric"")]"
        "[assembly: System.Reflection.AssemblyFileVersion(""$numeric"")]"
        "[assembly: System.Reflection.AssemblyInformationalVersion(""$($Version.Full)"")]"
        ''
    ) -join "`r`n"
}

function Get-HeaderText {
    param($Version, [string] $FileName)
    $numeric = '{0}.{1}.{2}.0' -f $Version.Major, $Version.Minor, $Version.Patch
    $guard = ($Prefix + 'GIT_VERSION_' + ($FileName -replace '[^A-Za-z0-9]', '_')).ToUpperInvariant()
    $p = $Prefix + 'VERSION_'
    return @(
        '/* Generated by Update-GitVersion.ps1 from the git tags. Do not edit or commit. */'
        "#ifndef $guard"
        "#define $guard"
        ''
        "#define $($p)MAJOR $($Version.Major)"
        "#define $($p)MINOR $($Version.Minor)"
        "#define $($p)PATCH $($Version.Patch)"
        "#define $($p)BUILD 0"
        "#define $($p)STRING ""$($Version.Full)"""
        "#define $($p)NUMERIC_STRING ""$numeric"""
        ''
        "#endif /* $guard */"
        ''
    ) -join "`r`n"
}

function Write-IfChanged {
    # Writes UTF-8 without a byte order mark, and only when the content differs.
    param([string] $Path, [string] $Text)
    $ErrorActionPreference = 'Stop'
    if (-not [System.IO.Path]::IsPathRooted($Path)) { $Path = Join-Path (Get-Location).Path $Path }
    $full = [System.IO.Path]::GetFullPath($Path)
    if ((Test-Path -LiteralPath $full) -and ([System.IO.File]::ReadAllText($full) -ceq $Text)) { return $false }
    $folder = Split-Path -Parent $full
    if (-not (Test-Path -LiteralPath $folder)) { New-Item -ItemType Directory -Path $folder -Force | Out-Null }
    [System.IO.File]::WriteAllText($full, $Text, (New-Object System.Text.UTF8Encoding $false))
    return $true
}

$version = Get-GitVersion
if ($PrintOnly -or $OutputPath.Count -eq 0) {
    Write-Output $version.Full
    exit 0
}

# With -File, Windows PowerShell passes "a.cs,b.h" as one string: split it here.
$paths = @($OutputPath | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
foreach ($path in $paths) {
    switch -Regex ([System.IO.Path]::GetExtension($path).ToLowerInvariant()) {
        '^\.cs$' { $text = Get-CSharpText $version }
        '^\.(h|hpp)$' { $text = Get-HeaderText $version ([System.IO.Path]::GetFileName($path)) }
        default {
            [Console]::Error.WriteLine("Update-GitVersion: unsupported output file type: $path (supported: .cs, .h, .hpp)")
            exit 1
        }
    }
    try {
        $written = Write-IfChanged $path $text
    } catch {
        [Console]::Error.WriteLine("Update-GitVersion: cannot write ${path}: $($_.Exception.Message)")
        exit 1
    }
    $state = if ($written) { 'written' } else { 'unchanged' }
    Write-Output "Update-GitVersion: $($version.Full) -> $path ($state)"
}
exit 0
