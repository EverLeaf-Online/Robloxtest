--# selene: allow(incorrect_standard_library_use)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DevPackages = ReplicatedStorage:WaitForChild("DevPackages")
local Jest = require(DevPackages:WaitForChild("Jest"))
local runCLI = Jest.runCLI

local processServiceExists, ProcessService = pcall(function()
	return game:GetService("ProcessService")
end)

local status, result = runCLI(ReplicatedStorage.Shared, {
	ci = true,
	verbose = true,
}, { ReplicatedStorage.Shared }):awaitStatus()

if status == "Rejected" then
	warn(result)
	if processServiceExists then
		ProcessService:ExitAsync(1)
	end
	error("Jest runner rejected")
end

local success = result.results.success == true
if processServiceExists then
	ProcessService:ExitAsync(if success then 0 else 1)
end

if not success then
	error("Jest tests failed")
end

return nil
