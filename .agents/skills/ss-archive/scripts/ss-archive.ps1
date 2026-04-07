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

Move-Item -LiteralPath $proposalDir -Destination $destination

if (Test-Path -LiteralPath (Join-Path $destination "proposal.json")) {
    $proposalManifest = [ordered]@{
        proposal_name = $proposalName
        proposal_path = Get-StoredProposalPath -RepoRoot $repoRoot -ProposalDir $destination
        status        = "archived"
        archived_at   = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    }

    $proposalManifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $destination "proposal.json")
}

if (Test-Path -LiteralPath $sessionsDir) {
    $openProposalPath = Get-StoredProposalPath -RepoRoot $repoRoot -ProposalDir $proposalDir
    Get-ChildItem -LiteralPath $sessionsDir -Filter *.json -File | ForEach-Object {
        $boundProposalPath = Get-SessionProposalPath -SessionFile $_.FullName
        if ($boundProposalPath -and ($boundProposalPath -eq $openProposalPath -or $boundProposalPath -eq "proposes/$proposalName")) {
            Remove-Item -LiteralPath $_.FullName -Force
        }
    }
}

Write-Output $destination
