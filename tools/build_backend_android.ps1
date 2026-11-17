$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
$previousJavaOptions = $env:JAVA_TOOL_OPTIONS
Push-Location -LiteralPath $projectPath
try {
    $configPath = 'config/supabase.local.json'
    if (-not (Test-Path -LiteralPath $configPath)) {
        throw 'Copy config/supabase.example.json to config/supabase.local.json and set the project publishable key. Do not use a secret or service_role key.'
    }
    $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    if ([string]::IsNullOrWhiteSpace($config.SUPABASE_PUBLISHABLE_KEY) -or [string]::IsNullOrWhiteSpace($config.SUPABASE_URL)) {
        throw 'The Supabase project URL and publishable key are required.'
    }
    if ($config.SUPABASE_PUBLISHABLE_KEY.StartsWith('sb_secret_')) {
        throw 'Secret keys must never be embedded in the app.'
    }
    $buildTemp = Join-Path $projectPath '.build-tmp'
    New-Item -ItemType Directory -Path $buildTemp -Force | Out-Null
    $env:JAVA_TOOL_OPTIONS = $previousJavaOptions + ' -Djava.io.tmpdir="' + $buildTemp + '" -Djdk.net.unixdomain.tmpdir="' + $buildTemp + '"'
    # Keep the already-authorized direct Groq path until server matching ships.
    # Private configuration values are never printed.
    $buildArgs = @('build', 'apk', '--debug', '--split-per-abi', '--target-platform', 'android-arm64', "--dart-define-from-file=$configPath")
    if (Test-Path -LiteralPath 'config/groq.local.json') {
        $buildArgs += '--dart-define-from-file=config/groq.local.json'
    }
    $buildArgs += "--dart-define=BUILD_REVISION=$([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())"
    & flutter @buildArgs
    if ($LASTEXITCODE -ne 0) { throw 'Connected Android build failed.' }
} finally {
    $env:JAVA_TOOL_OPTIONS = $previousJavaOptions
    Pop-Location
}
