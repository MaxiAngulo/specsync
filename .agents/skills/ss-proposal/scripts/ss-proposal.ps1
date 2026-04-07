param(
    [Parameter(Mandatory = $true)]
    [string]$Name,
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
    $resolvedProposalDir = (Resolve-Path -LiteralPath $ProposalDir).Path.TrimEnd('\')

    if ($resolvedProposalDir.StartsWith($resolvedRepoRoot + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
        return $resolvedProposalDir.Substring($resolvedRepoRoot.Length + 1).Replace('\', '/')
    }

    return $resolvedProposalDir.Replace('\', '/')
}

function Write-SessionBinding {
    param(
        [string]$SessionFile,
        [string]$SessionId,
        [string]$ProposalDir,
        [string]$RepoRoot
    )

    $now = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $createdAt = $now

    if (Test-Path -LiteralPath $SessionFile) {
        try {
            $existing = Get-Content -LiteralPath $SessionFile -Raw | ConvertFrom-Json
            if ($existing.created_at) {
                $createdAt = [string]$existing.created_at
            }
        } catch {
        }
    }

    $binding = [ordered]@{
        session_id    = $SessionId
        proposal_name = Split-Path -Leaf $ProposalDir
        proposal_path = Get-StoredProposalPath -RepoRoot $RepoRoot -ProposalDir $ProposalDir
        created_at    = $createdAt
        updated_at    = $now
    }

    $binding | ConvertTo-Json | Set-Content -LiteralPath $SessionFile
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $scriptDir)))
$proposesDir = Join-Path $repoRoot "proposes"
$specsyncDir = Join-Path $repoRoot ".specsync"
$sessionsDir = Join-Path $specsyncDir "sessions"
$sessionId = Get-SessionId -SessionInput $Session
$sessionFile = Join-Path $sessionsDir "$sessionId.json"
$timestamp = (Get-Date).ToUniversalTime().ToString("yyMMdd'T'HHmm")
$folderName = "$timestamp-$Name"
$targetDir = Join-Path $proposesDir $folderName
$createdAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

New-Item -ItemType Directory -Force -Path $proposesDir | Out-Null
New-Item -ItemType Directory -Force -Path $specsyncDir | Out-Null
New-Item -ItemType Directory -Force -Path $sessionsDir | Out-Null
New-Item -ItemType Directory -Force -Path $targetDir | Out-Null

$proposalManifest = [ordered]@{
    proposal_name = $folderName
    proposal_path = Get-StoredProposalPath -RepoRoot $repoRoot -ProposalDir $targetDir
    status        = "open"
    created_at    = $createdAt
}

$proposalManifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $targetDir "proposal.json")
Write-SessionBinding -SessionFile $sessionFile -SessionId $sessionId -ProposalDir $targetDir -RepoRoot $repoRoot
Write-Output $targetDir

