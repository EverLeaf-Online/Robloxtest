--# selene: allow(incorrect_standard_library_use)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DevPackages = ReplicatedStorage:WaitForChild("DevPackages")
local Jest = require(DevPackages:WaitForChild("Jest"))
local runCLI = Jest.runCLI

local processServiceExists, ProcessService = pcall(function()
	return game:GetService("ProcessService")
end)

local function appendLine(lines, value)
	if value == nil then
		return
	end

	local text = tostring(value)
	if #text > 2000 then
		text = string.sub(text, 1, 2000) .. "..."
	end
	table.insert(lines, text)
end

local function buildFailureSummary(results)
	local lines = {
		string.format(
			"Jest failed: %s failed tests across %s failed suites (%s total tests, %s total suites)",
			tostring(results.numFailedTests or "?"),
			tostring(results.numFailedTestSuites or "?"),
			tostring(results.numTotalTests or "?"),
			tostring(results.numTotalTestSuites or "?")
		),
	}

	for _, suite in ipairs(results.testResults or {}) do
		local suiteFailed = (suite.numFailingTests or 0) > 0
			or suite.testExecError ~= nil
			or suite.failureMessage ~= nil
		if suiteFailed then
			appendLine(lines, "Suite: " .. tostring(suite.testFilePath or "<unknown>"))

			if suite.testExecError ~= nil then
				appendLine(
					lines,
					suite.testExecError.message or suite.testExecError.stack or suite.testExecError
				)
			end

			if suite.failureMessage ~= nil then
				appendLine(lines, suite.failureMessage)
			end

			for _, assertion in ipairs(suite.testResults or {}) do
				if assertion.status == "failed" then
					appendLine(
						lines,
						"Test: " .. tostring(assertion.fullName or assertion.title or "<unknown>")
					)
					for _, message in ipairs(assertion.failureMessages or {}) do
						appendLine(lines, message)
					end
				end
			end
		end
	end

	local summary = table.concat(lines, "\n")
	if #summary > 12000 then
		summary = string.sub(summary, 1, 12000) .. "\n...failure output truncated..."
	end
	return summary
end

local status, result = runCLI(ReplicatedStorage.Shared, {
	ci = true,
	verbose = true,
}, { ReplicatedStorage.Shared }):awaitStatus()

if status == "Rejected" then
	warn(result)
	if processServiceExists then
		ProcessService:ExitAsync(1)
	end
	error("Jest runner rejected: " .. tostring(result))
end

local success = result.results.success == true
if processServiceExists then
	ProcessService:ExitAsync(if success then 0 else 1)
end

if not success then
	local summary = buildFailureSummary(result.results)
	warn(summary)
	error(summary)
end

return nil
