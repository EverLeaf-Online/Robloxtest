# OCALE Runtime Test Setup

This project uses a dedicated Roblox test experience/place for automated Luau/Jest execution. Do not reuse IDs or credentials from another EverLeaf Roblox project.

## Roblox test environment

Create a separate private Roblox experience for automation, for example:

- Experience: `Scrap-to-Bot Factory - Tests`
- Place: `OCALE Test Place`

The experience/place can remain private. Record:

- Universe ID
- Place ID

Create an Open Cloud API key scoped only to this test experience/place with these permissions required by Roblox's current `rocale-cli` flow:

- `universe-places:write`
- `luau-execution-sessions:write`

Use a dedicated test key. Do not commit the key, paste it into source files, or reuse a production key.

## GitHub configuration

In `EverLeaf-Online/Robloxtest`, configure:

Repository secret:

- `ROBLOX_API_KEY` = the dedicated OCALE test API key

Repository variables:

- `ROBLOX_TEST_UNIVERSE_ID` = the test experience Universe ID
- `ROBLOX_TEST_PLACE_ID` = the OCALE test Place ID

The workflow maps those values to the environment names used by the local runner scripts:

- `ROBLOX_UNIVERSE_ID`
- `ROBLOX_PLACE_ID`

## Running in GitHub Actions

Use the workflow:

`OCALE Runtime Tests`

It is manual (`workflow_dispatch`) until the runtime environment is proven stable. The workflow:

1. validates the secret/variables are configured;
2. installs pinned Rokit 1.2.0;
3. installs the project-pinned toolchain, including `rocale-cli` 0.1.3;
4. installs Wally packages;
5. verifies `rocale-cli` is available;
6. loads `test.project.json` into the dedicated test place through Open Cloud;
7. runs `spec.lua` and the Jest suite;
8. fails the Actions job if Jest/OCALE fails.

OCALE jobs use a concurrency group so multiple runtime-test runs for the same test universe do not overlap.

## Running locally on Windows

From the repository root in PowerShell, set the values only for the current shell session:

```powershell
$env:ROBLOX_API_KEY = "<test-api-key>"
$env:ROBLOX_UNIVERSE_ID = "<test-universe-id>"
$env:ROBLOX_PLACE_ID = "<test-place-id>"
rokit install
wally install
./scripts/run-ocale-tests.ps1
```

Do not put the API key in PowerShell profile files, `.env` files committed to Git, or shell history scripts.

## Security boundaries

- Test and production Roblox places must use different API keys where practical.
- The test key should have only the two permissions above and only the test resource scope.
- Never expose `ROBLOX_API_KEY` as a workflow-dispatch input, repository variable, Actions output, or committed file.
- Universe and Place IDs are identifiers, not secrets; store them as repository variables.
- Rotate the key if it is ever pasted into a public issue, PR, log, chat screenshot, or committed file.

## Gate before gameplay testing

The setup is considered complete when:

- the dedicated Roblox test experience/place exists;
- `ROBLOX_API_KEY` is configured as a GitHub Actions secret;
- both test IDs are configured as GitHub Actions variables;
- the `OCALE Runtime Tests` workflow completes successfully;
- the Jest output reports success.

Only after this gate should the interactive Studio smoke-test checklist begin.
