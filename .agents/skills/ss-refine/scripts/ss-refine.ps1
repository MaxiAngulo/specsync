param(
    [string]$Proposal,
    [string]$Request,
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

function Resolve-SessionProposalDir {
    param(
        [string]$SessionFile,
        [string]$RepoRoot
    )

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

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $scriptDir)))
$proposesDir = Join-Path $repoRoot "proposes"
$specsyncDir = Join-Path $repoRoot ".specsync"
$sessionsDir = Join-Path $specsyncDir "sessions"
$sessionId = Get-SessionId -SessionInput $Session
$sessionFile = Join-Path $sessionsDir "$sessionId.json"

New-Item -ItemType Directory -Force -Path $specsyncDir | Out-Null
New-Item -ItemType Directory -Force -Path $sessionsDir | Out-Null

if ($Proposal) {
    if (Test-Path -LiteralPath $Proposal) {
        $proposalDir = (Resolve-Path -LiteralPath $Proposal).Path
    } else {
        $proposalDir = Join-Path $proposesDir $Proposal
    }
    if (-not (Test-Path -LiteralPath $proposalDir)) {
        throw "Proposal not found: $Proposal"
    }
    Write-SessionBinding -SessionFile $sessionFile -SessionId $sessionId -ProposalDir $proposalDir -RepoRoot $repoRoot
} else {
    $proposalDir = Resolve-SessionProposalDir -SessionFile $sessionFile -RepoRoot $repoRoot
}

if (-not (Test-Path -LiteralPath $proposalDir)) {
    throw "Session proposal folder not found: $proposalDir"
}

$proposalName = Split-Path -Leaf $proposalDir
$userRequest = if ($Request) { $Request.Trim() } else { "Use the current user request from the conversation." }
@"
# Orchestration

- Session id: $sessionId
- Session binding: .specsync/sessions/$sessionId.json
- Bound proposal: $proposalName
- Orchestrator agent: .specsync/agents/specsync-orchestrator/AGENT.md
- Orchestrator input: $userRequest
- Managed spec root: specs/<matching-path> when a spec delta is needed
- Managed source roots: <source-root>/<matching-path> for relative roots and <root-key>/<matching-path> for absolute or external roots
- Support skill routing: inspect .specsync/skills and ask each relevant skill whether its owned files need deltas.
- Source routing: use .specsync/skills/specsync-source-code/SKILL.md for proposal-folder source deltas.
- Consistency rule: do not leave proposal-folder spec and source deltas with contradictory behavior.
"@ | Set-Content -LiteralPath (Join-Path $proposalDir "orchestration.md")

Write-Output $proposalDir

