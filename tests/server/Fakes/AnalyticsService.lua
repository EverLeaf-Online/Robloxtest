--!strict

local AnalyticsService = {}

local creditSources: { any } = {}
local creditSinks: { any } = {}

function AnalyticsService.Reset()
	table.clear(creditSources)
	table.clear(creditSinks)
end

function AnalyticsService.RecordCreditSource(
	player: Player,
	source: string,
	amount: number,
	balance: number
)
	table.insert(creditSources, {
		Player = player,
		Source = source,
		Amount = amount,
		Balance = balance,
	})
end

function AnalyticsService.RecordCreditSink(
	player: Player,
	source: string,
	amount: number,
	balance: number
)
	table.insert(creditSinks, {
		Player = player,
		Source = source,
		Amount = amount,
		Balance = balance,
	})
end

function AnalyticsService.GetCreditSources(): { any }
	return creditSources
end

function AnalyticsService.GetCreditSinks(): { any }
	return creditSinks
end

return AnalyticsService
