--!strict

local AnalyticsService = {}

local creditSources: { any } = {}

function AnalyticsService.Reset()
	table.clear(creditSources)
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

function AnalyticsService.GetCreditSources(): { any }
	return creditSources
end

return AnalyticsService
