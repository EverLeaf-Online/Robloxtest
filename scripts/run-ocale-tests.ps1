$ErrorActionPreference = "Stop"

$required = @(
    "ROBLOX_API_KEY",
    "ROBLOX_UNIVERSE_ID",
    "ROBLOX_PLACE_ID"
)

foreach ($name in $required) {
    $value = [Environment]::GetEnvironmentVariable($name)
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Missing required environment variable: $name"
    }
}

if (-not (Get-Command rojo -ErrorAction SilentlyContinue)) {
    throw "rojo was not found in PATH."
}

$repoRoot = (Get-Location).Path
$projectFile = Join-Path $repoRoot "test.project.json"
$specFile = Join-Path $repoRoot "spec.lua"
$buildDir = Join-Path $repoRoot ".build"
$placeFile = Join-Path $buildDir "ocale-tests.rbxl"

if (-not (Test-Path $projectFile) -or -not (Test-Path $specFile)) {
    throw "Run this script from the repository root; test.project.json/spec.lua were not found."
}

$rocaleCli = if ([string]::IsNullOrWhiteSpace($env:ROCALE_CLI)) { "rocale-cli" } else { $env:ROCALE_CLI }
$rocaleWorkDir = if ([string]::IsNullOrWhiteSpace($env:ROCALE_WORKDIR)) { $repoRoot } else { $env:ROCALE_WORKDIR }

if ($rocaleCli -notmatch "[\\/]") {
    if (-not (Get-Command $rocaleCli -ErrorAction SilentlyContinue)) {
        throw "rocale-cli was not found in PATH."
    }
} else {
    $resolvedCli = Join-Path $rocaleWorkDir $rocaleCli
    if (-not (Test-Path $resolvedCli)) {
        throw "rocale-cli was not found at: $resolvedCli"
    }
}

New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

Write-Host "Building dedicated OCALE test place..."
& rojo build $projectFile --output $placeFile
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Add-Type -AssemblyName System.Net.Http
$publishUrl = "https://apis.roblox.com/universes/v1/$($env:ROBLOX_UNIVERSE_ID)/places/$($env:ROBLOX_PLACE_ID)/versions?versionType=Published"
$versionNumber = $null
$maxPublishAttempts = 2

for ($attempt = 1; $attempt -le $maxPublishAttempts; $attempt++) {
    $client = [System.Net.Http.HttpClient]::new()
    $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Post, $publishUrl)
    $request.Headers.Add("x-api-key", $env:ROBLOX_API_KEY)
    $request.Headers.Accept.ParseAdd("application/json")

    $bytes = [System.IO.File]::ReadAllBytes($placeFile)
    $content = [System.Net.Http.ByteArrayContent]::new($bytes)
    $content.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::new("application/octet-stream")
    $request.Content = $content

    try {
        $response = $client.SendAsync($request).GetAwaiter().GetResult()
        $body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        $statusCode = [int]$response.StatusCode

        if ($response.IsSuccessStatusCode) {
            $data = $body | ConvertFrom-Json
            if ($null -eq $data.versionNumber -or [int64]$data.versionNumber -le 0) {
                throw "Roblox publish response did not contain a valid versionNumber."
            }
            $versionNumber = [int64]$data.versionNumber
            break
        }

        if ($statusCode -eq 409 -and $attempt -lt $maxPublishAttempts) {
            Write-Warning "Roblox place publish returned HTTP 409; retrying in 15s ($attempt/$maxPublishAttempts)..."
            Start-Sleep -Seconds 15
            continue
        }

        if ($statusCode -eq 409) {
            Write-Error "Roblox place publish is conflict-locked (HTTP 409). The OCALE no-publish probe proves the API key, universe/place pairing, and Luau Execution scope are valid. Close any active Roblox Studio/Team Create session for this test place, allow the edit session to release, then rerun.`n$body"
        }

        throw "Roblox place publish failed with HTTP $statusCode. $body"
    } finally {
        $request.Dispose()
        $client.Dispose()
    }
}

if ($null -eq $versionNumber) {
    throw "Roblox place publish did not return a usable version number."
}

Write-Host "Published OCALE test place version $versionNumber."
Write-Host "Running Scrap-to-Bot Jest suite through Roblox Open Cloud Luau Execution..."

Push-Location $rocaleWorkDir
try {
    & $rocaleCli run `
        --universeId $env:ROBLOX_UNIVERSE_ID `
        --placeId $env:ROBLOX_PLACE_ID `
        --load.version $versionNumber `
        --script $specFile `
        --timeout 300 `
        --verbose

    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
} finally {
    Pop-Location
}
