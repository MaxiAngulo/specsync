param()

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $scriptDir)))
$templatesDir = Join-Path $repoRoot ".specsync\templantes"
$specsDir = Join-Path $repoRoot "specs"
$proposalsDir = Join-Path $repoRoot "proposes"
$archiveDir = Join-Path $repoRoot "proposals-archive"
$specsyncDir = Join-Path $repoRoot ".specsync"
$sessionsDir = Join-Path $specsyncDir "sessions"
$sourceRootsFile = Join-Path $specsyncDir "source-roots.txt"

foreach ($path in @($specsDir, $proposalsDir, $archiveDir, $specsyncDir, $sessionsDir)) {
    New-Item -ItemType Directory -Force -Path $path | Out-Null
}

Get-ChildItem -Path $templatesDir -Recurse -File | ForEach-Object {
    $relativePath = $_.FullName.Substring($templatesDir.Length + 1)
    $destination = Join-Path $specsDir $relativePath
    $destinationDir = Split-Path -Parent $destination
    New-Item -ItemType Directory -Force -Path $destinationDir | Out-Null
    if (-not (Test-Path -LiteralPath $destination)) {
        Copy-Item -LiteralPath $_.FullName -Destination $destination
    }
}

if (-not (Test-Path -LiteralPath $sourceRootsFile)) {
    Set-Content -LiteralPath $sourceRootsFile -Value "src"
    # Auto-detect common test-code root folders and add them when present
    foreach ($testDir in @("test", "tests")) {
        if (Test-Path -LiteralPath (Join-Path $repoRoot $testDir) -PathType Container) {
            Add-Content -LiteralPath $sourceRootsFile -Value $testDir
        }
    }
}

Write-Output $repoRoot
