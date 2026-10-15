$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
try {
    flutter build apk --release
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter release APK build failed with exit code $LASTEXITCODE."
    }

    $releaseDirectory = Join-Path $repoRoot 'build\app\outputs\flutter-apk'
    $releaseApk = Join-Path $releaseDirectory 'app-release.apk'
    $brandedApk = Join-Path $releaseDirectory 'WorkLog.apk'

    if (-not (Test-Path -LiteralPath $releaseApk -PathType Leaf)) {
        throw "Flutter completed without producing the expected APK: $releaseApk"
    }

    Copy-Item -LiteralPath $releaseApk -Destination $brandedApk -Force
    Write-Output "Release APK ready: $brandedApk"
} finally {
    Pop-Location
}
