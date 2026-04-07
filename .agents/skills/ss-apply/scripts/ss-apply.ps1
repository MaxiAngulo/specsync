param(
    [string]$Proposal,
    [string]$Session
)

$ErrorActionPreference = "Stop"

function Get-SessionId {
    param(
        [string]$SessionInput
    )

    foreach ($candidate in @($SessionInput, $env:SPECSYNC_SESSION_ID, $env:SPEC_SYNC_SESSION_ID, $env:AGENT_SESSION_ID, $env:CHAT_SESSION_ID, $env:SESSION_ID, $env:THREAD_ID)) {
        if ($candidate -and $candidate.Trim()) {
            return $candidate.Trim()
        }
    }

    throw "No SpecSync session id configured. Provide -Session or set SPECSYNC_SESSION_ID."
}

function Resolve-ProposalDir {
    param(
        [string]$ProposalInput,
        [string]$ProposesDir,
        [string]$SessionFile,
        [string]$RepoRoot
    )

    if ($ProposalInput) {
        if (Test-Path -LiteralPath $ProposalInput) {
            return (Resolve-Path -LiteralPath $ProposalInput).Path
        }
        return (Join-Path $ProposesDir $ProposalInput)
    }

    if (-not (Test-Path -LiteralPath $SessionFile)) {
        throw "No proposal is bound to the current SpecSync session."
    }

    $binding = Get-Content -LiteralPath $SessionFile -Raw | ConvertFrom-Json
    $proposalPath = [string]$binding.proposal_path
    if (-not $proposalPath) {
        throw "No proposal is bound to the current SpecSync session."
    }

    if ([System.IO.Path]::IsPathRooted($proposalPath)) {
        return $proposalPath
    }

    return (Join-Path $RepoRoot ($proposalPath -replace '/', '\'))
}

function Get-SourceRoots {
    param(
        [string]$FilePath
    )

    if (-not (Test-Path -LiteralPath $FilePath)) {
        return @("src")
    }

    $roots = Get-Content -LiteralPath $FilePath | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    if (-not $roots) {
        return @("src")
    }

    return $roots
}

function Get-RootKey {
    param(
        [string]$Root
    )

    return (($Root -replace '[:\\/ ]+', '__') -replace '[^A-Za-z0-9._-]', '_').Trim('_')
}

function Get-ProposalSourceDir {
    param(
        [string]$ProposalDir,
        [string]$SourceRoot
    )

    if ([System.IO.Path]::IsPathRooted($SourceRoot)) {
        return (Join-Path $ProposalDir (Get-RootKey -Root $SourceRoot))
    }

    $normalized = $SourceRoot -replace '[\\/]+', '\'
    return (Join-Path $ProposalDir $normalized)
}

function Get-RootStateLines {
    param(
        [string]$SourceRoot,
        [string]$DirectoryPath
    )

    $lines = New-Object System.Collections.Generic.List[string]
    if (-not (Test-Path -LiteralPath $DirectoryPath -PathType Container)) {
        $lines.Add("root`t$SourceRoot`tmissing")
        return $lines.ToArray()
    }

    $resolvedDir = (Resolve-Path -LiteralPath $DirectoryPath).Path.TrimEnd('\')
    $lines.Add("root`t$SourceRoot`tpresent")
    $files = Get-ChildItem -LiteralPath $resolvedDir -Recurse -File | Sort-Object FullName
    foreach ($file in $files) {
        $relativePath = $file.FullName.Substring($resolvedDir.Length).TrimStart('\').Replace('\', '/')
        $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        $lines.Add("file`t$SourceRoot`t$relativePath`t$hash")
    }

    return $lines.ToArray()
}

function Get-ManifestRootStateLines {
    param(
        [string]$ManifestPath,
        [string]$SourceRoot
    )

    if (-not (Test-Path -LiteralPath $ManifestPath)) {
        return @()
    }

    return Get-Content -LiteralPath $ManifestPath | Where-Object {
        $_ -like "root`t$SourceRoot`t*" -or $_ -like "file`t$SourceRoot`t*"
    }
}

function Test-LineSetsEqual {
    param(
        [string[]]$Left,
        [string[]]$Right
    )

    $leftNormalized = @($Left | Sort-Object)
    $rightNormalized = @($Right | Sort-Object)
    if ($leftNormalized.Count -ne $rightNormalized.Count) {
        return $false
    }

    for ($i = 0; $i -lt $leftNormalized.Count; $i++) {
        if ($leftNormalized[$i] -ne $rightNormalized[$i]) {
            return $false
        }
    }

    return $true
}

function Overlay-Directory {
    param(
        [string]$Source,
        [string]$Destination
    )

    if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
        return
    }

    $resolvedSource = (Resolve-Path -LiteralPath $Source).Path.TrimEnd('\')
    Get-ChildItem -LiteralPath $resolvedSource -Recurse -File | ForEach-Object {
        $relativePath = $_.FullName.Substring($resolvedSource.Length).TrimStart('\')
        $targetPath = Join-Path $Destination $relativePath
        $targetDir = Split-Path -Parent $targetPath
        New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
        Copy-Item -LiteralPath $_.FullName -Destination $targetPath -Force
    }
}

function Write-SourceStateManifest {
    param(
        [string]$ProposalDir,
        [object[]]$RootStates
    )

    $manifestPath = Join-Path $ProposalDir "source-state.txt"
    $capturedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $content = New-Object System.Collections.Generic.List[string]
    $content.Add("captured_at`t$capturedAt")
    foreach ($rootState in $RootStates) {
        foreach ($line in $rootState.Lines) {
            $content.Add($line)
        }
    }
    Set-Content -LiteralPath $manifestPath -Value $content
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $scriptDir)))
$proposesDir = Join-Path $repoRoot "proposes"
$specsyncDir = Join-Path $repoRoot ".specsync"
$sessionsDir = Join-Path $specsyncDir "sessions"
$sessionId = Get-SessionId -SessionInput $Session
$sessionFile = Join-Path $sessionsDir "$sessionId.json"
$sourceRootsFile = Join-Path $specsyncDir "source-roots.txt"
$specsDir = Join-Path $repoRoot "specs"

$proposalDir = Resolve-ProposalDir -ProposalInput $Proposal -ProposesDir $proposesDir -SessionFile $sessionFile -RepoRoot $repoRoot
if (-not (Test-Path -LiteralPath $proposalDir)) {
    throw "Proposal not found: $proposalDir"
}

$proposalSpecsDir = Join-Path $proposalDir "specs"
$proposalSourceRoots = @()
foreach ($sourceRoot in Get-SourceRoots -FilePath $sourceRootsFile) {
    $destination = if ([System.IO.Path]::IsPathRooted($sourceRoot)) { $sourceRoot } else { Join-Path $repoRoot $sourceRoot }
    $proposalRootDir = Get-ProposalSourceDir -ProposalDir $proposalDir -SourceRoot $sourceRoot
    if (Test-Path -LiteralPath $proposalRootDir -PathType Container) {
        $proposalSourceRoots += [ordered]@{
            Root        = $sourceRoot
            Destination = $destination
            ProposalDir = $proposalRootDir
        }
    }
}

if ($proposalSourceRoots.Count -gt 0) {
    $manifestPath = Join-Path $proposalDir "source-state.txt"
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        throw "Proposal source changes require a live source snapshot. Run ss-pull before ss-apply."
    }

    $changedRoots = New-Object System.Collections.Generic.List[string]
    foreach ($rootState in $proposalSourceRoots) {
        $currentLines = Get-RootStateLines -SourceRoot $rootState.Root -DirectoryPath $rootState.Destination
        $manifestLines = Get-ManifestRootStateLines -ManifestPath $manifestPath -SourceRoot $rootState.Root
        if (-not (Test-LineSetsEqual -Left $currentLines -Right $manifestLines)) {
            $changedRoots.Add($rootState.Root)
        }
    }

    if ($changedRoots.Count -gt 0) {
        throw ("Live source roots changed since the last ss-pull. Run ss-pull before ss-apply: " + ($changedRoots -join ", "))
    }
}

Overlay-Directory -Source $proposalSpecsDir -Destination $specsDir

foreach ($rootState in $proposalSourceRoots) {
    Overlay-Directory -Source $rootState.ProposalDir -Destination $rootState.Destination
}

if ($proposalSourceRoots.Count -gt 0) {
    $postApplyStates = foreach ($rootState in $proposalSourceRoots) {
        [ordered]@{
            Root  = $rootState.Root
            Lines = Get-RootStateLines -SourceRoot $rootState.Root -DirectoryPath $rootState.Destination
        }
    }
    Write-SourceStateManifest -ProposalDir $proposalDir -RootStates $postApplyStates
}

$appliedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$checkedRoots = if ($proposalSourceRoots.Count -gt 0) { $proposalSourceRoots.Root -join ", " } else { "none" }
@"
# Apply Summary

- Status: applied
- Applied UTC: $appliedAt
- Proposal: $(Split-Path -Leaf $proposalDir)
- Live source guard: passed
- Checked source roots: $checkedRoots
"@ | Set-Content -LiteralPath (Join-Path $proposalDir "apply-summary.md")

Write-Output $proposalDir
