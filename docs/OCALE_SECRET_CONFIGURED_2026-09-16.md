# OCALE Secret Configuration

Status date: **2026-09-16**

The dedicated `ROBLOX_API_KEY` for the private Scrap-to-Bot Factory test experience has been configured in GitHub Actions secrets.

- Universe ID: `10766713640`
- Place ID: `75490500628229`
- Secret name: `ROBLOX_API_KEY`
- Secret value is intentionally not stored in source control.

This commit exists to trigger a fresh same-repository PR workflow after the secret was configured so `OCALE Runtime Tests` can execute instead of skipping.
