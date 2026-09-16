# OCALE Runtime Test Setup

This project uses a dedicated private Roblox test experience/place for automated Luau/Jest execution. Do not reuse IDs or credentials from another EverLeaf Roblox project.

## Roblox test environment

Dedicated test environment:

- Experience: `Scrap-to-Bot Factory - Tests`
- Universe ID: `10766713640`
- Start place: `Scrap-to-Bot Factory - Tests`
- Place ID: `75490500628229`
- Audience: Private

The Universe ID and Place ID are not secrets and are intentionally bound directly into the OCALE GitHub workflow.

Create a dedicated Open Cloud API key scoped only to this test experience with:

- `universe-places:write`
- `luau-execution-sessions:write`

Do not add an IP restriction for the GitHub Actions key because GitHub-hosted runner egress addresses are not stable. Keep the blast radius small by restricting the key to only the dedicated test experience and only the two scopes above.

Do not commit, paste, or reuse the API key.

## GitHub configuration

In `EverLeaf-Online/Robloxtest`, configure one repository Actions secret:

- `ROBLOX_API_KEY` = the dedicated OCALE test API key

No GitHub Universe/Place variables are required; the dedicated non-secret IDs are committed in `.github/workflows/ocale-runtime-tests.yml`.

The workflow exposes:

- `ROBLOX_UNIVERSE_ID=10766713640`
- `ROBLOX_PLACE_ID=75490500628229`

## GitHub Actions runtime path

Workflow: `OCALE Runtime Tests`

The workflow runs for same-repository pull requests and supports `workflow_dispatch` once present on the default branch. Before `ROBLOX_API_KEY` exists, OCALE execution safely skips.

The workflow intentionally builds Roblox's tagged `rocale-cli` v0.1.3 source at commit `d154b3cc9a834adf7408d5cf78f079a4ea33efe6` instead of relying on the published Linux release binary. Its build environment matches the upstream release toolchain where required.

When configured, the workflow:

1. verifies the API-key secret exists;
2. installs the project toolchain and Wally packages;
3. builds and verifies the pinned OCALE CLI;
4. runs a no-publish Luau Execution probe against the current cloud place version;
5. builds `test.project.json` into a binary `.rbxl`;
6. publishes that binary with Roblox's Place Publishing API using `Content-Type: application/octet-stream` and `versionType=Published`;
7. reads the exact returned `versionNumber`;
8. runs `spec.lua` through OCALE against that exact uploaded version;
9. fails the job if the publish, OCALE task, or Jest suite fails.

OCALE jobs use a universe-specific concurrency group so two jobs do not write/run against the dedicated test place concurrently.

## Verified setup state — 2026-09-16

The following are already verified in GitHub Actions:

- `ROBLOX_API_KEY` is present and accepted by Roblox;
- Universe `10766713640` and Place `75490500628229` are correctly paired;
- Luau Execution authorization is valid;
- a no-upload OCALE task completed on cloud place version 3 in about 2.3 seconds;
- the probe printed `OCALE_PROBE_OK`;
- normal repository CI remains green.

The remaining blocker is the Place Publishing API. Both `Saved` and documented `Published` place-version writes currently return:

```text
HTTP 409 Conflict
Save failed. Server is busy and unable to process your upload request. Please try again in a couple minutes.
```

Roblox has documented this same response when a place has an active Studio/Team Create edit session. Before rerunning OCALE, close every Studio session editing this dedicated test place and allow the collaborative/edit session time to release. The runner makes only one bounded retry for a 409 and then fails with a focused lock diagnostic rather than consuming repeated CI minutes.

## Running locally on Windows

The PowerShell runner uses the same build -> publish -> exact-version OCALE flow as CI.

From the repository root:

```powershell
$env:ROBLOX_API_KEY = "<test-api-key>"
$env:ROBLOX_UNIVERSE_ID = "10766713640"
$env:ROBLOX_PLACE_ID = "75490500628229"
rokit install
wally install
./scripts/run-ocale-tests.ps1
```

`rojo` and a working official `rocale-cli` must be available. If using the source-built CLI layout used by CI, set `ROCALE_WORKDIR` and `ROCALE_CLI` to that source tree and `./build/rocale-cli` respectively.

Do not put the API key in committed files, a PowerShell profile, or any script that may enter source control. Local `.env*` files are ignored, as is `.build/`.

## Security boundaries

- Test and production Roblox places must not share API keys.
- The test key must have only the required permissions and only the test resource scope.
- Do not expose `ROBLOX_API_KEY` as a workflow-dispatch input, repository variable, Actions output, committed file, chat message, or screenshot.
- Universe and Place IDs are identifiers, not credentials.

## Gate before interactive gameplay testing

The automated setup gate is complete when:

- the no-publish OCALE probe succeeds;
- the test-place publish returns a valid version number;
- Jest executes through OCALE against that exact version and passes.

Only after that gate should the interactive Studio smoke-test checklist begin.
