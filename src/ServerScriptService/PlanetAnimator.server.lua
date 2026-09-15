local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local accumulator = 0

RunService.Heartbeat:Connect(function(deltaTime)
	accumulator += deltaTime
	if accumulator < 1 / 20 then
		return
	end
	accumulator = 0

	local planets = Workspace:FindFirstChild("Planets")
	if not planets then
		return
	end
	local now = Workspace:GetServerTimeNow()
	for _, planet in ipairs(planets:GetChildren()) do
		if planet:IsA("Model") and planet.PrimaryPart then
			local center = planet.PrimaryPart.Position
			local moon = planet:FindFirstChild("Moon")
			if moon and moon:IsA("BasePart") then
				local phase = moon:GetAttribute("OrbitPhase") or 0
				local angle = now * 0.28 + phase
				local offset = Vector3.new(math.cos(angle) * 70, math.sin(angle * 0.7) * 12, math.sin(angle) * 70)
				moon.CFrame = CFrame.new(center + offset)
			end

			local animals = planet:FindFirstChild("Animals")
			if animals then
				for _, animal in ipairs(animals:GetChildren()) do
					if animal:IsA("Model") and animal.PrimaryPart then
						local baseCF = animal:GetAttribute("BaseCFrame")
						if typeof(baseCF) == "CFrame" then
							local phase = tonumber(animal:GetAttribute("AnimationPhase")) or 0
							local bob = math.sin(now * 2.2 + phase) * 0.28
							local turn = math.sin(now * 1.3 + phase) * math.rad(5)
							animal:PivotTo(baseCF * CFrame.new(0, bob, 0) * CFrame.Angles(0, turn, 0))
						end
					end
				end
			end
		end
	end
end)
