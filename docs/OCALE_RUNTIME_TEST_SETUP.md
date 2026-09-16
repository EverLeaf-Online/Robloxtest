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

Create a dedicated Open Cloud API key scoped only to this test experience with the two permissions required by Roblox's current `rocale-cli` flow:

- `universe-places:write`
- `luau-execution-sessions:write`

Do not add an IP restriction for the GitHub Actions key because GitHub-hosted runner egress addresses are not stable. Keep the blast radius small by restricting the key to only the dedicated test experience and only the two scopes above.

Do not commit, paste, or reuse the API key.

## GitHub configuration

In `EverLeaf-Online/Robloxtest`, configure one repository Actions secret:

- `ROBLOX_API_KEY` = the dedicated OCALE test API key

No GitHub Universe/Place variables are required; the dedicated non-secret IDs are committed in `.github/workflows/ocale-runtime-tests.yml`.

The workflow exposes the expected local environment names internally:

- `ROBLOX_UNIVERSE_ID=10766713640`
- `ROBLOX_PLACE_ID=75490500628229`

## Running in GitHub Actions

Workflow: `OCALE Runtime Tests`

The workflow runs for same-repository pull requests and also supports `workflow_dispatch` once present on the default branch. Before `ROBLOX_API_KEY` exists, the OCALE execution steps safely skip instead of failing the PR.

When configured, the workflow:

1. checks that the API key secret exists;
2. installs pinned Rokit 1.2.0 from the pinned installer source;
3. installs the project-pinned toolchain, including `rocale-cli` 0.1.3;
4. installs Wally packages;
5. verifies `rocale-cli` is available;
6. loads `test.project.json` into the dedicated test place through Open Cloud;
7. runs `spec.lua` and the Jest suite;
8. fails the Actions job if Jest/OCALE fails.

OCALE jobs use a universe-specific concurrency group so runtime-test runs do not overlap.

## Running locally on Windows

From the repository root in PowerShell, set the values only for the current shell session:

```powershell
$env:ROBLOX_API_KEY = "<test-api-key>"
$env:ROBLOX_UNIVERSE_ID = "10766713640"
$env:ROBLOX_PLACE_ID = "75490500628229"
rokit install
wally install
./scripts/run-ocale-tests.ps1
```

Do not put the API key in committed files, a PowerShell profile, or any script that may enter source control. Local `.env*` files are ignored as an additional safeguard, but GitHub Actions secrets remain the preferred CI storage mechanism.

## Security boundaries

- Test and production Roblox places must not share API keys.
- The test key must have only the two required permissions and only the test resource scope.
- Do not expose `ROBLOX_API_KEY` as a workflow-dispatch input, repository variable, Actions output, committed file, chat message, or screenshot.
- Universe and Place IDs are identifiers, not credentials.
- Rotate the key immediately if it is ever exposed.

## Gate before interactive gameplay testing

Setup is complete when:

- the dedicated private Roblox test experience/place exists;
- the OCALE key is restricted to this test experience with `universe-places:write` and `luau-execution-sessions:write`;
- `ROBLOX_API_KEY` is configured as a GitHub Actions repository secret;
- `OCALE Runtime Tests` executes rather than skips;
- the Jest/OCALE run succeeds.

Only after that gate should the interactive Studio smoke-test checklist begin.
