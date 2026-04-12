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

function Get-StoredProposalPath {
    param(
        [string]$RepoRoot,
        [string]$ProposalDir
    )

    $resolvedRepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path.TrimEnd('\')
    $normalizedProposalDir = $ProposalDir.TrimEnd('\')

    if ($normalizedProposalDir.StartsWith($resolvedRepoRoot + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
        return $normalizedProposalDir.Substring($resolvedRepoRoot.Length + 1).Replace('\', '/')
    }

    return $normalizedProposalDir.Replace('\', '/')
}

function Get-SourceRoots {
    param([string]$FilePath)
    if (-not (Test-Path -LiteralPath $FilePath)) { return @('src') }
    $roots = Get-Content -LiteralPath $FilePath | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    if (-not $roots) { return @('src') }
    return $roots
}

function Get-RootKey {
    param([string]$Root)
    return (($Root -replace '[:\\/ ]+', '__') -replace '[^A-Za-z0-9._-]', '_').Trim('_')
}

function Get-ProposalSourceDir {
    param([string]$ProposalDir, [string]$SourceRoot)
    if ([System.IO.Path]::IsPathRooted($SourceRoot)) {
        return (Join-Path $ProposalDir (Get-RootKey -Root $SourceRoot))
    }
    $normalized = $SourceRoot -replace '[\\/]+', '\'
    return (Join-Path $ProposalDir $normalized)
}

function Get-SessionProposalPath {
    param(
        [string]$SessionFile
    )

    if (-not (Test-Path -LiteralPath $SessionFile)) {
        return $null
    }

    try {
        $binding = Get-Content -LiteralPath $SessionFile -Raw | ConvertFrom-Json
        return [string]$binding.proposal_path
    } catch {
        return $null
    }
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $scriptDir)))
$proposesDir = Join-Path $repoRoot "proposes"
$archiveDir = Join-Path $repoRoot "proposals-archive"
$specsyncDir = Join-Path $repoRoot ".specsync"
$sessionsDir = Join-Path $specsyncDir "sessions"
$sessionId = Get-SessionId -SessionInput $Session
$sessionFile = Join-Path $sessionsDir "$sessionId.json"

if ($Proposal) {
    if (Test-Path -LiteralPath $Proposal) {
        $proposalDir = (Resolve-Path -LiteralPath $Proposal).Path
    } else {
        $proposalDir = Join-Path $proposesDir $Proposal
    }
} else {
    if (-not (Test-Path -LiteralPath $sessionFile)) {
        throw "No proposal is bound to the current SpecSync session."
    }
    $proposalPath = Get-SessionProposalPath -SessionFile $sessionFile
    if (-not $proposalPath) {
        throw "No proposal is bound to the current SpecSync session."
    }

    if ([System.IO.Path]::IsPathRooted($proposalPath)) {
        $proposalDir = $proposalPath
    } else {
        $proposalDir = Join-Path $repoRoot ($proposalPath -replace '/', '\')
    }
}

if (-not (Test-Path -LiteralPath $proposalDir)) {
    throw "Proposal not found: $proposalDir"
}

New-Item -ItemType Directory -Force -Path $archiveDir | Out-Null
$proposalName = Split-Path -Leaf $proposalDir
$destination = Join-Path $archiveDir $proposalName

if (Test-Path -LiteralPath $destination) {
    throw "Archive destination already exists: $destination"
}

$archivedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$sourceRootsFile = Join-Path $specsyncDir 'source-roots.txt'
$gitCmd = Get-Command git -ErrorAction SilentlyContinue

if ($gitCmd) {
    New-Item -ItemType Directory -Force -Path $destination | Out-Null

    $proposalMd = Join-Path $proposalDir 'proposal.md'
    if (Test-Path -LiteralPath $proposalMd) {
        Copy-Item -LiteralPath $proposalMd -Destination (Join-Path $destination 'proposal.md') -Force
    }

    $patchFile = Join-Path $destination 'changes.patch'
    $patchLines = New-Object System.Collections.Generic.List[string]

    function Invoke-GitDiff {
        param([string]$LiveFile, [string]$ProposalFile)
        $diffOutput = & git diff --no-index -- $LiveFile $ProposalFile 2>$null
        if ($LASTEXITCODE -gt 1) {
            throw "git diff failed with exit code $LASTEXITCODE for: $LiveFile vs $ProposalFile"
        }
        if ($diffOutput) {
            foreach ($line in $diffOutput) { $patchLines.Add($line) }
        }
    }

    $proposalSpecsDir = Join-Path $proposalDir 'specs'
    if (Test-Path -LiteralPath $proposalSpecsDir -PathType Container) {
        $resolvedSpecsProposalDir = (Resolve-Path -LiteralPath $proposalSpecsDir).Path.TrimEnd('\')
        $liveSpecsDir = Join-Path $repoRoot 'specs'
        Get-ChildItem -LiteralPath $proposalSpecsDir -Recurse -File | Sort-Object FullName | ForEach-Object {
            $relPath = $_.FullName.Substring($resolvedSpecsProposalDir.Length + 1).Replace('\', '/')
            $liveFile = Join-Path $liveSpecsDir ($relPath -replace '/', '\')
            if (Test-Path -LiteralPath $liveFile -PathType Leaf) {
                Invoke-GitDiff -LiveFile $liveFile -ProposalFile $_.FullName
            } else {
                Invoke-GitDiff -LiveFile '/dev/null' -ProposalFile $_.FullName
            }
        }
    }

    foreach ($sourceRoot in (Get-SourceRoots -FilePath $sourceRootsFile)) {
        $proposalRootDir = Get-ProposalSourceDir -ProposalDir $proposalDir -SourceRoot $sourceRoot
        if (-not (Test-Path -LiteralPath $proposalRootDir -PathType Container)) { continue }
        $liveRoot = if ([System.IO.Path]::IsPathRooted($sourceRoot)) { $sourceRoot } else { Join-Path $repoRoot $sourceRoot }
        $resolvedProposalRootDir = (Resolve-Path -LiteralPath $proposalRootDir).Path.TrimEnd('\')
        Get-ChildItem -LiteralPath $proposalRootDir -Recurse -File | Sort-Object FullName | ForEach-Object {
            $relPath = $_.FullName.Substring($resolvedProposalRootDir.Length + 1).Replace('\', '/')
            $liveFile = Join-Path $liveRoot ($relPath -replace '/', '\')
            if (Test-Path -LiteralPath $liveFile -PathType Leaf) {
                Invoke-GitDiff -LiveFile $liveFile -ProposalFile $_.FullName
            } else {
                Invoke-GitDiff -LiveFile '/dev/null' -ProposalFile $_.FullName
            }
        }
    }

    $deletionsFile = Join-Path $proposalDir 'deletions.txt'
    if (Test-Path -LiteralPath $deletionsFile) {
        Get-Content -LiteralPath $deletionsFile | ForEach-Object {
            $deletionPath = ($_ -replace '#.*$', '').Trim()
            if (-not $deletionPath) { return }
            if ($deletionPath -match '\.\.') { return }
            if ([System.IO.Path]::IsPathRooted($deletionPath)) { return }
            $liveFile = Join-Path $repoRoot ($deletionPath -replace '/', '\')
            if (Test-Path -LiteralPath $liveFile -PathType Leaf) {
                Invoke-GitDiff -LiveFile $liveFile -ProposalFile '/dev/null'
            }
        }
    }

    if ($patchLines.Count -gt 0) {
        Set-Content -LiteralPath $patchFile -Value $patchLines
    }

    [ordered]@{
        proposal_name  = $proposalName
        proposal_path  = "proposals-archive/$proposalName"
        status         = 'archived'
        archive_format = 'patch'
        archived_at    = $archivedAt
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $destination 'proposal.json')

    Remove-Item -LiteralPath $proposalDir -Recurse -Force
} else {
    Move-Item -LiteralPath $proposalDir -Destination $destination

    [ordered]@{
        proposal_name  = $proposalName
        proposal_path  = "proposals-archive/$proposalName"
        status         = 'archived'
        archive_format = 'folder'
        archived_at    = $archivedAt
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $destination 'proposal.json')
}

if (Test-Path -LiteralPath $sessionsDir) {
    Get-ChildItem -LiteralPath $sessionsDir -Filter *.json -File | ForEach-Object {
        $boundProposalPath = Get-SessionProposalPath -SessionFile $_.FullName
        if ($boundProposalPath -and $boundProposalPath -eq "proposes/$proposalName") {
            Remove-Item -LiteralPath $_.FullName -Force
        }
    }
}

Write-Output $destination
