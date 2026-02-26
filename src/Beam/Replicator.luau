--!strict
-- @author : BakedAleska
-- @date : 02/21/2026

-- #SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- #IMPORT
local replica = require(ReplicatedStorage.Packages.replica)

--> Declare
local Replicator = {}

-- #TYPES
export type replicated = {
	Event: string,
	Entity: number,
	Body: Instance?,
	Priority: number?,
}

type config = {
	Token: any,
	Data: replicated,
	Tags: { Body: Instance? }?,
}

local TOKEN = replica.Token("Events")

function Replicator.Replicate(Pass: replicated, Body: Instance?)
	local Config: config = {
		Token = TOKEN,
		Data = Pass,
	}

	if Body then
		Config.Tags = { Body = Body }
	end

	local Replica = replica.New(Config)
	Replica:Replicate()

	task.defer(function()
		Replica:Destroy()
	end)
end

return Replicator
