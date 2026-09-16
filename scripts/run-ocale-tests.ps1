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

if (-not (Get-Command rocale-cli -ErrorAction SilentlyContinue)) {
    throw "rocale-cli was not found in PATH. Install the official Roblox/rocale-cli before running OCALE tests."
}

if (-not (Test-Path "test.project.json") -or -not (Test-Path "spec.lua")) {
    throw "Run this script from the repository root; test.project.json/spec.lua were not found."
}

Write-Host "Running Scrap-to-Bot Jest suite through Roblox Open Cloud Luau Execution..."

& rocale-cli run `
    --universeId $env:ROBLOX_UNIVERSE_ID `
    --placeId $env:ROBLOX_PLACE_ID `
    --load.project test.project.json `
    --script spec.lua `
    --timeout 300 `
    --verbose

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
