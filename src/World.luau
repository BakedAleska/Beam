--!nonstrict
-- @author : BakedAleska
-- @date : 02/20/2026

-- #SERVICES
local ServerScriptService = game:GetService("ServerScriptService")

-- #IMPORT
local Replicator = require(script.Parent.Replicator)

-- #CONSTANTS
local NEXT_ID = 0
local DEBUG = false

--> Declare
local World = {}
World.__index = World
World.Instance = nil :: any
World.Cache = nil :: { any }? -- Cached system modules

-- #TYPES
export type world = {
	Alive: { [number]: boolean },
	Components: { [string]: { [number]: any } },
	Bodies: { [Instance]: number },
	Events: { [string]: { event } },
	Next: { [string]: { event } },
	Craft_Entity: () -> number,
	Register_Component: (Name: string, Weak: boolean?) -> (),
	Register_Body: (Entity: number, Body: Instance) -> (),
	Count: (Components: { string }) -> string?,
	Kill: (Entity: number) -> (),
	For_Each: (Entity: number, Components: { string }) -> boolean,
	Assign_Component: (Entity: number, Key: string, Data: { any }) -> (),
	Unassign_Component: (Entity: number, Key: string) -> (),
	Return_Entity: (Reference: Instance) -> number?,
	Fire_Event: (Event: event) -> (),
	Read_Entity_Event: (Entity: number, Name: string) -> (boolean, number?),
	Read_Event: (Name: string) -> { event }?,
	Subscribe_To: (Event: string, Callback: (Entity: number, Data: any) -> ()) -> (),
	Update: (dt: number) -> (),
}

export type event = {
	Event: string,
	Entity: number,
	Body: Instance?,
	Priority: number?,
}

local function Assert_Event_Shape(Event: any)
	if type(Event) ~= "table" then
		error("[World] Event must be a table.", 3)
	end
	if type(Event.Event) ~= "string" then
		error("[World] Event must have valid name string.", 3)
	end
	if type(Event.Entity) ~= "number" then
		error("[World] Event must have valid entity.", 3)
	end
end

function World.new(): world
	local self = setmetatable({
		Alive = {},
		Components = {},
		Bodies = setmetatable({}, { __mode = "k" }), -- Weak keys: auto-cleanup when Instance destroyed

		Events = {}, -- The world event queue (read-only for systems)
		Next = {}, -- The next-frame event queue
	}, World)
	World.Instance = self

	for _, Entry in pairs(ServerScriptService.Server.Components:GetChildren()) do
		if Entry:IsA("ModuleScript") then
			self.Components[Entry.Name] = {}
		end
	end

	return self
end

function World.Register_Component(Name: string, Weak: boolean?)
	if not World.Instance.Components[Name] then
		if Weak then
			World.Instance.Components[Name] = setmetatable({}, { __mode = "v" })
		else
			World.Instance.Components[Name] = {}
		end
	end
end

function World.Register_Body(Entity: number, Body: Instance)
	World.Instance.Bodies[Body] = Entity
end

function World.Return_Entity(Reference: Instance): number?
	return World.Instance.Bodies[Reference]
end

function World.Craft_Entity(): number
	NEXT_ID += 1

	World.Instance.Alive[NEXT_ID] = true

	return NEXT_ID
end

function World.Count(Components: { string }): string?
	local Counter = math.huge
	local Smallest: string? = nil

	for _, Name in Components do
		local Pool = World.Instance.Components[Name]
		if Pool then
			local Count = 0
			for _ in pairs(Pool) do
				Count += 1
			end

			if Count < Counter then
				Counter = Count
				Smallest = Name
			end
		end
	end

	return Smallest
end

function World.For_Each(Entity: number, Components: { string }): boolean
	for _, Component in Components do
		local Pool = World.Instance.Components[Component]
		if not Pool or not Pool[Entity] then
			return false
		end
	end
	return true
end

function World.Fire_Event(Event: event)
	Assert_Event_Shape(Event)

	local Copy = table.clone(Event)

	local Events = World.Instance.Next
	local Bucket = Events[Copy.Event]
	if not Bucket then
		Bucket = {}
		Events[Copy.Event] = Bucket
	end

	Replicator.Replicate(Event, Event.Body)

	Bucket[#Bucket + 1] = Copy

	if DEBUG then
		print("Firing event:", Copy.Event, "for entity:", Copy.Entity)
		print("Current Events table:", World.Instance.Events)
	end
end

function World.Read_Entity_Event(Entity: number, Name: string): (boolean, number?)
	if not World.Instance.Events[Name] then
		return false, 0 -- 0 = No event.
	end

	local Bucket = World.Instance.Events[Name]
	for i = 1, #Bucket do
		if Bucket[i].Entity == Entity then
			return true
		end
	end

	return false, 1 -- Event, but no entity in event.
end

function World.Read_Event(Name: string)
	return World.Instance.Events[Name]
end

function World.Subscribe_To(Event: string, Callback: (Entity: number, Data: any) -> ())
	local Events = World.Instance.Events[Event] or {}

	for i = 1, #Events do
		local Specified = Events[i]

		Callback(Specified.Entity, Specified)
	end
end

function World.Assign_Component(Entity: number, Key: string, Data: { any })
	if not World.Instance.Components[Key] then
		error(`"{Key}" is not a registered component key`)
	end

	World.Instance.Components[Key][Entity] = Data

	if typeof(Data) == "table" then
		for _, value in pairs(Data) do
			if typeof(value) == "Instance" then
				World.Instance.Bodies[value] = Entity
				break
			end
		end
	end
end

function World.Unassign_Component(Entity: number, Key: string)
	local Pool = World.Instance.Components[Key]
	if Pool then
		Pool[Entity] = nil
	end
end

function World.Kill(entity: number)
	World.Instance.Alive[entity] = nil

	for _, Pool in pairs(World.Instance.Components) do
		local data = Pool[entity]
		if typeof(data) == "table" then
			for _, value in pairs(data) do
				if typeof(value) == "Instance" then
					World.Instance.Bodies[value] = nil
				end
			end
		end
		Pool[entity] = nil
	end
end

function World.Update(dt)
	if not World.Cache then
		local Modules = {}
		for _, Module in pairs(script.Parent.Systems:GetChildren()) do
			if Module:IsA("ModuleScript") then
				Modules[#Modules + 1] = Module
			end
		end

		table.sort(Modules, function(a, b)
			return a.Name < b.Name
		end)

		local Systems = {}
		for i = 1, #Modules do
			local System = require(Modules[i])
			if System.Update then
				Systems[#Systems + 1] = System
			end
		end

		World.Cache = Systems
	end

	for i = 1, #World.Cache do
		World.Cache[i].Update(World, dt)
	end

	local Events = World.Instance.Events
	World.Instance.Events = World.Instance.Next
	World.Instance.Next = Events

	for _, Bucket in pairs(World.Instance.Events) do
		table.sort(Bucket, function(a, b)
			return (a.Priority or 0) > (b.Priority or 0)
		end)
	end

	for _, Bucket in pairs(World.Instance.Next) do
		table.clear(Bucket)
	end
	table.clear(World.Instance.Next)
end

return World
