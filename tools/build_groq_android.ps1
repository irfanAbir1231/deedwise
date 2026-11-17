$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectPath
$previousJavaOptions = $env:JAVA_TOOL_OPTIONS
try {
    if (-not (Test-Path -LiteralPath 'config/groq.local.json')) {
        Copy-Item -LiteralPath 'config/groq.example.json' -Destination 'config/groq.local.json'
        throw 'Paste your key in config/groq.local.json, then run this script again.'
    }
    $config = Get-Content -LiteralPath 'config/groq.local.json' -Raw | ConvertFrom-Json
    if ([string]::IsNullOrWhiteSpace($config.GROQ_API_KEY)) {
        throw 'GROQ_API_KEY is empty in config/groq.local.json.'
    }
    $buildTemp = Join-Path $projectPath '.build-tmp'
    New-Item -ItemType Directory -Path $buildTemp -Force | Out-Null
    $env:JAVA_TOOL_OPTIONS = $previousJavaOptions + ' -Djava.io.tmpdir="' + $buildTemp + '" -Djdk.net.unixdomain.tmpdir="' + $buildTemp + '"'
    # A fresh define also invalidates the stale Flutter/Gradle kernel cache.
    $revision = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    flutter build apk --debug --split-per-abi --target-platform android-arm64 --dart-define-from-file=config/groq.local.json "--dart-define=BUILD_REVISION=$revision"
    if ($LASTEXITCODE -ne 0) { throw 'Android build failed.' }
} finally {
    $env:JAVA_TOOL_OPTIONS = $previousJavaOptions
    Pop-Location
}
