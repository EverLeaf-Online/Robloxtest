# Grow a Tiny Planet

This repository now uses the uploaded Qwen implementation as the source of truth.

## Rojo

Run the project with:

```powershell
rojo serve --port 34873
```

Connect the Roblox Studio Rojo plugin to `localhost:34873`.

The project maps shared modules into `ReplicatedStorage/Shared`, server code into `ServerScriptService`, client controllers into `StarterPlayerScripts`, and the UI controller into `StarterGui`.

`RemoteSetup.server.lua` creates the required `ReplicatedFirst/Remotes` instances at runtime.

Marketplace IDs remain `0` until real Game Pass and Developer Product IDs are configured in `GameConfig.lua`.
