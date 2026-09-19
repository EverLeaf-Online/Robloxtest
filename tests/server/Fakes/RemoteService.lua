--!strict

local RemoteService = {}

function RemoteService.BindRequest(_name: string, _callback: (...any) -> ()) end

function RemoteService.Get(_name: string): RemoteEvent
	error("RemoteService.Get is not available in service integration tests")
end

return RemoteService
