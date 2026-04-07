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

function Replace-Directory {
    param(
        [string]$Source,
        [string]$Destination
    )

    if (Test-Path -LiteralPath $Destination) {
        Remove-Item -LiteralPath $Destination -Recurse -Force
    }

    if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
        return
    }

    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    Get-ChildItem -LiteralPath $Source -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $Destination -Recurse -Force
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

function Get-TextContent {
    param(
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }

    return [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path)
}

function Write-TextContent {
    param(
        [string]$Path,
        [string]$Content
    )

    $parent = Split-Path -Parent $Path
    if ($parent) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }

    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

function Get-GitHeadContent {
    param(
        [string]$RepoRoot,
        [string]$RelativePath
    )

    $gitRelativePath = $RelativePath.Replace('\', '/')
    & git -C $RepoRoot rev-parse --verify --quiet "HEAD:$gitRelativePath" *> $null
    if ($LASTEXITCODE -ne 0) {
        return $null
    }

    $output = & git -C $RepoRoot show "HEAD:$gitRelativePath" 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $null
    }

    return [string]::Join("`n", $output)
}

function Invoke-ThreeWayMerge {
    param(
        [string]$RepoRoot,
        [string]$CurrentContent,
        [string]$BaseContent,
        [string]$IncomingContent
    )

    $tempDir = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

    try {
        $currentFile = Join-Path $tempDir "current.md"
        $baseFile = Join-Path $tempDir "base.md"
        $incomingFile = Join-Path $tempDir "incoming.md"

        Write-TextContent -Path $currentFile -Content $CurrentContent
        Write-TextContent -Path $baseFile -Content $BaseContent
        Write-TextContent -Path $incomingFile -Content $IncomingContent

        $mergedOutput = & git -C $RepoRoot merge-file -p -- $currentFile $baseFile $incomingFile 2>$null
        $exitCode = $LASTEXITCODE
        $mergedContent = [string]::Join("`n", $mergedOutput)

        if ($exitCode -eq 0) {
            return [ordered]@{
                Success = $true
                Content = $mergedContent
            }
        }

        if ($exitCode -eq 1) {
            return [ordered]@{
                Success = $false
                Content = $mergedContent
            }
        }

        throw "git merge-file failed with exit code $exitCode."
    } finally {
        if (Test-Path -LiteralPath $tempDir) {
            Remove-Item -LiteralPath $tempDir -Recurse -Force
        }
    }
}

function Get-LineMergeKey {
    param(
        [string]$Line
    )

    $trimmed = $Line.Trim()
    if (-not $trimmed) {
        return $null
    }

    if ($trimmed -match '^#+\s+(.+)$') {
        return "heading:$($Matches[1].Trim())"
    }

    if ($trimmed -match '^([-*]|\d+\.)\s+(.+)$') {
        $body = $Matches[2].Trim()
        if ($body -match '^([^:]+):') {
            return "item:$($Matches[1].Trim())"
        }
        if ($body -match '^(.+\?)') {
            return "item:$($Matches[1].Trim())"
        }
    }

    return $null
}

function Merge-KeyedMarkdownLine {
    param(
        [string]$ProposalLine,
        [string]$LiveLine
    )

    if ($ProposalLine -eq $LiveLine) {
        return $ProposalLine
    }

    if ($ProposalLine.Contains($LiveLine)) {
        return $ProposalLine
    }

    if ($LiveLine.Contains($ProposalLine)) {
        return $LiveLine
    }

    if ($ProposalLine.Contains(':') -and $LiveLine.Contains(':')) {
        $proposalPrefix, $proposalSuffix = $ProposalLine.Split(':', 2)
        $livePrefix, $liveSuffix = $LiveLine.Split(':', 2)
        if ($proposalPrefix.Trim() -eq $livePrefix.Trim()) {
            $proposalValue = $proposalSuffix.Trim()
            $liveValue = $liveSuffix.Trim()

            if (-not $proposalValue) {
                return $LiveLine
            }

            if (-not $liveValue) {
                return $ProposalLine
            }

            if ($proposalValue -eq $liveValue) {
                return $ProposalLine
            }

            if ($proposalValue.Contains($liveValue)) {
                return $ProposalLine
            }

            if ($liveValue.Contains($proposalValue)) {
                return $LiveLine
            }
        }
    }

    return $null
}

function Try-BootstrapMergeMarkdown {
    param(
        [string]$ProposalContent,
        [string]$LiveContent
    )

    $outputLines = New-Object System.Collections.Generic.List[string]
    foreach ($line in ($ProposalContent -split "`r?`n", 0)) {
        $outputLines.Add($line)
    }

    foreach ($liveLine in ($LiveContent -split "`r?`n", 0)) {
        if ($outputLines.Contains($liveLine)) {
            continue
        }

        $handled = $false
        $mergeKey = Get-LineMergeKey -Line $liveLine
        if ($mergeKey) {
            for ($i = 0; $i -lt $outputLines.Count; $i++) {
                if ((Get-LineMergeKey -Line $outputLines[$i]) -eq $mergeKey) {
                    $mergedLine = Merge-KeyedMarkdownLine -ProposalLine $outputLines[$i] -LiveLine $liveLine
                    if ($null -eq $mergedLine) {
                        return [ordered]@{
                            Success = $false
                            Content = $null
                        }
                    }

                    $outputLines[$i] = $mergedLine
                    $handled = $true
                    break
                }
            }
        }

        if ($handled) {
            continue
        }

        if (-not $liveLine.Trim()) {
            continue
        }

        return [ordered]@{
            Success = $false
            Content = $null
        }
    }

    return [ordered]@{
        Success = $true
        Content = [string]::Join([Environment]::NewLine, $outputLines)
    }
}

function Sync-LiveSpecsIntoProposal {
    param(
        [string]$RepoRoot,
        [string]$ProposalDir
    )

    $liveSpecsDir = Join-Path $RepoRoot "specs"
    if (-not (Test-Path -LiteralPath $liveSpecsDir -PathType Container)) {
        return
    }

    $proposalSpecsDir = Join-Path $ProposalDir "specs"
    $baselineSpecsDir = Join-Path $ProposalDir ".pull-base\specs"

    $liveSpecFiles = Get-ChildItem -LiteralPath $liveSpecsDir -Recurse -File | Sort-Object FullName
    foreach ($liveSpecFile in $liveSpecFiles) {
        $relativePath = $liveSpecFile.FullName.Substring($liveSpecsDir.Length).TrimStart('\')
        $proposalFile = Join-Path $proposalSpecsDir $relativePath
        $baselineFile = Join-Path $baselineSpecsDir $relativePath

        $liveContent = Get-TextContent -Path $liveSpecFile.FullName
        $proposalContent = Get-TextContent -Path $proposalFile
        $baselineContent = Get-TextContent -Path $baselineFile
        if ($null -eq $baselineContent) {
            $baselineContent = Get-GitHeadContent -RepoRoot $RepoRoot -RelativePath ("specs/" + $relativePath.Replace('\', '/'))
        }

        if ($null -eq $proposalContent) {
            Write-TextContent -Path $proposalFile -Content $liveContent
            Write-TextContent -Path $baselineFile -Content $liveContent
            continue
        }

        if ($proposalContent -eq $liveContent) {
            Write-TextContent -Path $baselineFile -Content $liveContent
            continue
        }

        if ($null -eq $baselineContent) {
            $bootstrapMerge = Try-BootstrapMergeMarkdown -ProposalContent $proposalContent -LiveContent $liveContent
            if (-not $bootstrapMerge.Success) {
                throw "Spec merge baseline missing for specs/$($relativePath.Replace('\', '/')). Commit the live specs file or create a new proposal from the current specs state before running ss-pull."
            }

            Write-TextContent -Path $proposalFile -Content ([string]$bootstrapMerge.Content)
            Write-TextContent -Path $baselineFile -Content $liveContent
            continue
        }

        if ($proposalContent -eq $baselineContent) {
            Write-TextContent -Path $proposalFile -Content $liveContent
            Write-TextContent -Path $baselineFile -Content $liveContent
            continue
        }

        if ($liveContent -eq $baselineContent) {
            Write-TextContent -Path $baselineFile -Content $liveContent
            continue
        }

        $mergeResult = Invoke-ThreeWayMerge -RepoRoot $RepoRoot -CurrentContent $proposalContent -BaseContent $baselineContent -IncomingContent $liveContent
        if (-not $mergeResult.Success) {
            throw "Spec merge conflict during ss-pull: specs/$($relativePath.Replace('\', '/'))"
        }

        Write-TextContent -Path $proposalFile -Content ([string]$mergeResult.Content)
        Write-TextContent -Path $baselineFile -Content $liveContent
    }
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $scriptDir)))
$proposesDir = Join-Path $repoRoot "proposes"
$specsyncDir = Join-Path $repoRoot ".specsync"
$sessionsDir = Join-Path $specsyncDir "sessions"
$sessionId = Get-SessionId -SessionInput $Session
$sessionFile = Join-Path $sessionsDir "$sessionId.json"
$sourceRootsFile = Join-Path $repoRoot ".specsync\source-roots.txt"

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

Sync-LiveSpecsIntoProposal -RepoRoot $repoRoot -ProposalDir $proposalDir

$manifestPath = Join-Path $proposalDir "source-state.txt"
$rootStates = foreach ($sourceRoot in Get-SourceRoots -FilePath $sourceRootsFile) {
    $proposalRootDir = Get-ProposalSourceDir -ProposalDir $proposalDir -SourceRoot $sourceRoot
    if (Test-Path -LiteralPath $manifestPath) {
        $proposalLines = Get-RootStateLines -SourceRoot $sourceRoot -DirectoryPath $proposalRootDir
        $manifestLines = Get-ManifestRootStateLines -ManifestPath $manifestPath -SourceRoot $sourceRoot
        if ($manifestLines.Count -gt 0 -and -not (Test-LineSetsEqual -Left $proposalLines -Right $manifestLines)) {
            throw "Proposal source root contains staged edits that would be overwritten by ss-pull: $sourceRoot"
        }
        if ($manifestLines.Count -eq 0 -and (Test-Path -LiteralPath $proposalRootDir)) {
            throw "Proposal source root contains content without a captured live baseline: $sourceRoot"
        }
    } elseif (Test-Path -LiteralPath $proposalRootDir) {
        throw "Proposal source root already exists without a captured live baseline. Clear it or create a new proposal before ss-pull: $sourceRoot"
    }

    $liveRootDir = if ([System.IO.Path]::IsPathRooted($sourceRoot)) { $sourceRoot } else { Join-Path $repoRoot $sourceRoot }
    Replace-Directory -Source $liveRootDir -Destination $proposalRootDir
    [ordered]@{
        Root  = $sourceRoot
        Lines = Get-RootStateLines -SourceRoot $sourceRoot -DirectoryPath $liveRootDir
    }
}

Write-SourceStateManifest -ProposalDir $proposalDir -RootStates $rootStates
Write-Output $proposalDir
