<#
.SYNOPSIS
    Zips the release build of this repository into its release package, named
    after the version.

.DESCRIPTION
    The files come from package.psd1 (next to this script by default), a
    PowerShell data file:

        @{
            Name      = 'App'                   # the zip is App-v<version>.zip
            Platforms = @('x86', 'x64')         # optional: one zip per platform
            Files     = @(
                @{ From = 'App\bin\{Platform}\Release\*.exe'; To = '' }
                @{ From = 'App\bin\{Platform}\Release\*.dll'; To = '' }
                @{ From = 'config';                          To = 'config' }
            )
        }

    From is a path relative to the root of the git repository, with wildcards. A
    file goes into the folder To of the zip ('' is the top). A folder puts its files,
    with their subfolders, into To. {Platform} stands for each entry of Platforms.
    A From that matches nothing fails the run: the build did not produce it.

    With no Platforms or one platform, the run writes <Name>-v<version>.zip; with
    several, <Name>-v<version>-<platform>.zip for each of them.

    The version is, in this order: -Version; the highest version tag on HEAD
    (vX.Y.Z or vX.Y.Z-<alpha|beta|rc><R>, the zip drops the v); or, when
    Update-GitVersion.ps1 is next to this script, the version it reads from the
    tags (for example 1.2.3-4-g1a2b3c4 after a tag). The run refuses to package
    uncommitted changes in tracked files or submodules (untracked files do not
    count), and a repository without a version.

    Each zip written is printed as "Package: <full path>". Zip entries use '/'.

    Requires Windows PowerShell 3.0 or later, .NET Framework 4.5 or later, and git.

.PARAMETER ConfigPath
    The package configuration. Defaults to package.psd1 next to this script.

.PARAMETER OutputDirectory
    The folder of the zip files. Defaults to dist in the root of the repository,
    which git must ignore. Relative paths are relative to the current folder.

.PARAMETER Version
    The version to name the package after, for example 1.2.3 or 1.2.3-rc1.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tools\New-ReleasePackage.ps1
#>
#Requires -Version 3.0
# ss-workflow-script: New-ReleasePackage 1.0.0
[CmdletBinding()]
param(
    [string] $ConfigPath = '',
    [string] $OutputDirectory = '',
    [string] $Version = ''
)

# Native commands write to stderr on failure; failures are read from $LASTEXITCODE.
$ErrorActionPreference = 'Continue'

$ScriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Path
$TagPattern = '^v(0|[1-9][0-9]?)\.(0|[1-9][0-9]?)\.(0|[1-9][0-9]?)(?:-(alpha|beta|rc)([1-9][0-9]*))?$'
$VersionPattern = '^(0|[1-9][0-9]?)\.(0|[1-9][0-9]?)\.(0|[1-9][0-9]?)(-[0-9A-Za-z][0-9A-Za-z.-]*)?$'
$NamePattern = '^[A-Za-z0-9][A-Za-z0-9._-]*$'

function Stop-Run {
    param([string] $Message)
    [Console]::Error.WriteLine("New-ReleasePackage: $Message")
    exit 1
}

function Invoke-Git {
    # Runs git in the script's repository and returns its output lines; nothing on failure.
    param([string[]] $Arguments)
    $output = & git -C $ScriptFolder @Arguments 2>$null
    if ($LASTEXITCODE -ne 0) { return }
    $output | Where-Object { $_ -ne $null -and $_ -ne '' }
}

function Get-VersionKey {
    # Sorts like the version: X, Y, Z, then alpha 1, beta 2, rc 3, final 4, then R.
    param($Match)
    $stage = switch ($Match.Groups[4].Value) { 'alpha' { 1 } 'beta' { 2 } 'rc' { 3 } default { 4 } }
    $r = if ($Match.Groups[5].Success) { [int]$Match.Groups[5].Value } else { 0 }
    return '{0:D3}{1:D3}{2:D3}{3}{4:D6}' -f [int]$Match.Groups[1].Value, [int]$Match.Groups[2].Value,
        [int]$Match.Groups[3].Value, $stage, $r
}

function Join-EntryName {
    param([string] $Folder, [string] $Name)
    if ($Folder) { return "$Folder/$Name" }
    return $Name
}

# --- The repository ---------------------------------------------------------------

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Stop-Run 'git is not on the PATH' }
$top = @(Invoke-Git @('rev-parse', '--show-toplevel'))
if ($top.Count -eq 0) { Stop-Run "not inside a git repository: $ScriptFolder" }
$RepoRoot = [System.IO.Path]::GetFullPath($top[0])

$changes = @(Invoke-Git @('status', '--porcelain', '--untracked-files=no', '--ignore-submodules=untracked'))
if ($changes.Count -gt 0) {
    Stop-Run ("the repository has uncommitted changes; a package is made from a clean checkout:`n  " +
        ($changes -join "`n  "))
}

# --- The configuration ------------------------------------------------------------

if (-not $ConfigPath) { $ConfigPath = Join-Path $ScriptFolder 'package.psd1' }
if (-not (Test-Path -LiteralPath $ConfigPath)) { Stop-Run "no package configuration: $ConfigPath" }
try {
    $text = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $ConfigPath).ProviderPath)
    $block = [scriptblock]::Create($text)
    # A data file: literals only, no commands and no variables.
    $block.CheckRestrictedLanguage([string[]]@(), [string[]]@(), $false)
    $config = & $block
} catch {
    Stop-Run "cannot read ${ConfigPath}: $($_.Exception.Message)"
}
if ($config -isnot [hashtable]) { Stop-Run "$ConfigPath must hold one hashtable, @{ ... }" }

$Name = [string]$config['Name']
if ($Name -notmatch $NamePattern) { Stop-Run "Name in $ConfigPath must be a file name without spaces, for example 'App'" }

$platforms = @($config['Platforms'] | Where-Object { $_ } | ForEach-Object { [string]$_ })
foreach ($p in $platforms) {
    if ($p -notmatch $NamePattern) { Stop-Run "Platforms in ${ConfigPath}: '$p' is not a valid platform name" }
}

$files = @($config['Files'] | Where-Object { $_ })
if ($files.Count -eq 0) { Stop-Run "Files in $ConfigPath lists nothing to package" }
foreach ($f in $files) {
    if ($f -isnot [hashtable] -or -not $f['From']) { Stop-Run "each entry of Files in $ConfigPath needs From, as @{ From = '...'; To = '' }" }
}
$usesPlatform = @($files | Where-Object { "$($_['From'])$($_['To'])" -match '\{Platform\}' }).Count -gt 0
if ($usesPlatform -and $platforms.Count -eq 0) { Stop-Run "Files in $ConfigPath uses {Platform}, but Platforms is empty" }

# --- The version --------------------------------------------------------------------

if ($Version) {
    $Version = $Version -replace '^v', ''
    if ($Version -notmatch $VersionPattern) { Stop-Run "-Version '$Version' is not a version such as 1.2.3 or 1.2.3-rc1" }
} else {
    $best = $null
    $bestKey = ''
    foreach ($tag in @(Invoke-Git @('tag', '--points-at', 'HEAD'))) {
        $m = [regex]::Match($tag.Trim(), $TagPattern)
        if (-not $m.Success) { continue }
        $key = Get-VersionKey $m
        if ($key -gt $bestKey) { $bestKey = $key; $best = $m }
    }
    if ($null -ne $best) {
        $Version = $best.Value.Substring(1)
    } else {
        $generator = Join-Path $ScriptFolder 'Update-GitVersion.ps1'
        if (-not (Test-Path -LiteralPath $generator)) {
            Stop-Run 'HEAD has no version tag (vX.Y.Z); check out a tag, or pass -Version'
        }
        $Version = @(& $generator -PrintOnly -RepoPath $ScriptFolder) | Select-Object -Last 1
    }
}
if ($Version -like '*-unknown') { Stop-Run 'the repository has no version tag (vX.Y.Z); pass -Version' }
if ($Version -like '*-dirty') { Stop-Run "the version $Version has uncommitted changes" }

# --- What goes into each zip --------------------------------------------------------

if (-not $OutputDirectory) { $OutputDirectory = Join-Path $RepoRoot 'dist' }
if (-not [System.IO.Path]::IsPathRooted($OutputDirectory)) {
    $OutputDirectory = Join-Path (Get-Location).ProviderPath $OutputDirectory
}
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)

$runs = @()
if ($platforms.Count -eq 0) {
    $runs += , @{ Platform = ''; Suffix = '' }
} else {
    foreach ($p in $platforms) {
        $suffix = if ($platforms.Count -gt 1) { "-$p" } else { '' }
        $runs += , @{ Platform = $p; Suffix = $suffix }
    }
}

$packages = @()
foreach ($run in $runs) {
    $label = if ($run.Platform) { " (platform $($run.Platform))" } else { '' }
    $entries = [ordered]@{}
    foreach ($f in $files) {
        $from = ([string]$f['From']).Replace('{Platform}', $run.Platform)
        $to = ([string]$f['To']).Replace('{Platform}', $run.Platform).Replace('\', '/').Trim('/')
        if ("$from$to" -match '\{[^}]*\}') { Stop-Run "unknown placeholder in Files of ${ConfigPath}: $($f['From']) -> $($f['To'])" }
        $items = @(Get-Item -Path (Join-Path $RepoRoot $from) -Force -ErrorAction SilentlyContinue)
        if ($items.Count -eq 0) { Stop-Run "nothing matches From '$from'$label; did the release build run?" }
        foreach ($item in $items) {
            if ($item.PSIsContainer) {
                $base = $item.FullName.TrimEnd('\')
                $found = @(Get-ChildItem -LiteralPath $item.FullName -Recurse -Force | Where-Object { -not $_.PSIsContainer })
                $pairs = $found | ForEach-Object {
                    @{ Name = (Join-EntryName $to ($_.FullName.Substring($base.Length + 1).Replace('\', '/'))); Source = $_.FullName }
                }
            } else {
                $pairs = @(@{ Name = (Join-EntryName $to $item.Name); Source = $item.FullName })
            }
            foreach ($pair in $pairs) {
                if ($entries.Contains($pair.Name)) {
                    if ($entries[$pair.Name] -ne $pair.Source) { Stop-Run "two files would be $($pair.Name) in the zip$label" }
                    continue
                }
                $entries[$pair.Name] = $pair.Source
            }
        }
    }
    $zip = Join-Path $OutputDirectory ("{0}-v{1}{2}.zip" -f $Name, $Version, $run.Suffix)
    $packages += , @{ Path = $zip; Entries = $entries }
}

# --- Write the zips -----------------------------------------------------------------
# Everything was checked above, so a failure here is an I/O problem.

try {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
} catch {
    Stop-Run '.NET Framework 4.5 or later is needed to write zip files'
}

if (-not (Test-Path -LiteralPath $OutputDirectory)) { New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null }
foreach ($package in $packages) {
    $path = $package.Path
    $stream = $null
    $archive = $null
    try {
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force -ErrorAction Stop }
        $stream = [System.IO.File]::Open($path, [System.IO.FileMode]::CreateNew)
        $archive = New-Object System.IO.Compression.ZipArchive($stream, [System.IO.Compression.ZipArchiveMode]::Create)
        foreach ($entry in $package.Entries.GetEnumerator()) {
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $entry.Value, $entry.Key,
                [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
        }
    } catch {
        $message = $_.Exception.Message
        if ($archive) { $archive.Dispose(); $archive = $null }
        if ($stream) { $stream.Dispose(); $stream = $null }
        Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
        Stop-Run "cannot write ${path}: $message"
    } finally {
        if ($archive) { $archive.Dispose() }
        if ($stream) { $stream.Dispose() }
    }
    Write-Output "Package: $path"
}
exit 0
