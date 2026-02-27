--!nonstrict
-- @author : BakedAleska
-- @date : 02/20/2026

-- #SERVICES
local ServerScriptService = game:GetService("ServerScriptService")

-- #CONSTANTS
local NEXT_ID = 0
local DEBUG = false

--> Declare
local World = {}
World.__index = World
World.Singleton = nil :: world?

-- #TYPES
export type world = {
	Alive: { [number]: boolean },
	Components: { [string]: { [number]: any } },
	Bodies: { [Instance]: number },
	Events: { [string]: { event } },
	Next: { [string]: { event } },
	CraftEntity: () -> number,
	RegisterBody: (Entity: number, Body: Instance) -> (),
	Count: (Components: { string }) -> string?,
	Kill: (Entity: number) -> (),
	AddSystem: (Module: ModuleScript, Priority: number?) -> (),
	RemoveSystem: (Name: string) -> boolean,
	ForEach: (Entity: number, Components: { string }) -> boolean,
	AssignComponent: (Entity: number, Key: string, Data: { any }) -> (),
	UnassignComponent: (Entity: number, Key: string) -> (),
	ReturnEntity: (Reference: Instance) -> number?,
	FireEvent: (Event: event) -> (),
	ReadEntityEvent: (Entity: number, Name: string) -> (boolean, number?),
	ReadEvent: (Name: string) -> { event }?,
	SubscribeTo: (Event: string, Callback: (Entity: number, Data: any) -> ()) -> (),
	Update: (dt: number) -> (),
}

export type event = {
	Event: string,
	Entity: number,
	Body: Instance?,
	Priority: number?,
}

function World.new(): world
	local self = setmetatable({
		Alive = {},
		Components = {},
		Bodies = setmetatable({}, { __mode = "k" }), -- Weak keys: auto-cleanup when Instance destroyed

		Systems = {},
		Events = {}, -- The world event queue (read-only for systems)
		Next = {}, -- The next-frame event queue
	}, World)

	World.Singleton = self

	for _, Entry in pairs(ServerScriptService.Server.Components:GetChildren()) do
		if Entry:IsA("ModuleScript") then
			self.Components[Entry.Name] = {}
		end
	end

	return self
end

function World.AddSystem(Module: ModuleScript, Priority: number?)
	if not Module or not Module:IsA("ModuleScript") then
		warn("[World] AddSystem expected a ModuleScript.")
		return
	end

	local Ok, Result = pcall(require, Module)
	if not Ok then
		warn(string.format("[World] Failed to require system %s: %s", Module.Name, Result))
		return
	end

	for _, Entry in ipairs(World.Singleton.Systems) do
		if Entry.Name == Module.Name then
			warn(string.format("[World] System %s is already registered.", Module.Name))
			return
		end
	end

	if type(Result) ~= "table" then
		warn(string.format("[World] System %s did not return a table.", Module.Name))
	end

	if not (type(Result) == "table" and type(Result.Update) == "function") then
		warn(string.format("[World] System %s has no Update method and will not run.", Module.Name))
	end

	local Entry = {
		Name = Module.Name,
		Module = Result,
		Priority = Priority or 0,
	}

	World.Singleton.Systems[#World.Singleton.Systems + 1] = Entry

	table.sort(World.Singleton.Systems, function(a, b)
		if a.Priority == b.Priority then
			return a.Name < b.Name
		end
		return a.Priority > b.Priority
	end)
end

function World.RemoveSystem(Name: string)
	for i = #World.Singleton.Systems, 1, -1 do
		local Entry = World.Singleton.Systems[i]
		if Entry.Name == Name then
			local System = Entry.Module
			if type(System) == "table" and type(System.Destroy) == "function" then
				local Ok, Err = pcall(System.Destroy, System)
				if not Ok then
					warn(string.format("[World] Destroy failed for system %s: %s", Name, Err))
				end
			end
			table.remove(World.Singleton.Systems, i)
			return true
		end
	end

	return false
end

function World.RegisterBody(Entity: number, Body: Instance)
	if World.Singleton.Bodies[Body] then
		warn(string.format("[World] Body %s, already present.", Body.Name))
		return
	end

	World.Singleton.Bodies[Body] = Entity
end

function World.ReturnEntity(Reference: Instance): number?
	return World.Singleton.Bodies[Reference]
end

function World.CraftEntity(): number
	NEXT_ID += 1

	World.Singleton.Alive[NEXT_ID] = true

	return NEXT_ID
end

function World.Count(Components: { string }): string?
	local Counter = math.huge
	local Smallest: string? = nil

	for _, Name in Components do
		local Pool = World.Singleton.Components[Name]
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

function World.ForEach(Entity: number, Components: { string }): boolean
	for _, Component in Components do
		local Pool = World.Singleton.Components[Component]
		if not Pool or not Pool[Entity] then
			return false
		end
	end
	return true
end

function World.FireEvent(Event: event)
	if type(Event) ~= "table" then
		error("[World] Event must be a table.", 3)
	end
	if type(Event.Event) ~= "string" then
		error("[World] Event must have valid name string.", 3)
	end
	if type(Event.Entity) ~= "number" then
		error("[World] Event must have valid entity.", 3)
	end

	local Copy = table.clone(Event)

	local Events = World.Singleton.Next
	local Bucket = Events[Copy.Event]
	if not Bucket then
		Bucket = {}
		Events[Copy.Event] = Bucket
	end

	Bucket[Copy.Entity] = Copy

	if DEBUG then
		print("Firing event:", Copy.Event, "for entity:", Copy.Entity)
		print("Current Events table:", World.Singleton.Events)
	end
end

function World.ReadEntityEvent(Entity: number, Name: string): (boolean, number?)
	if not World.Singleton.Events[Name] then
		return false, 0 -- 0 = No event.
	end

	local Bucket = World.Singleton.Events[Name]
	if Bucket[Entity] then
		return true
	end

	return false, 1 -- Event, but no entity in event.
end

function World.ReadEvent(Name: string)
	return World.Singleton.Events[Name]
end

function World.SubscribeTo(Event: string, Callback: (Entity: number, Data: any) -> ())
	local Bucket = World.Singleton.Events[Event]
	if not Bucket then
		return
	end

	local Sorted = {}
	for Entity, EventData in pairs(Bucket) do
		Sorted[#Sorted + 1] = EventData
	end

	table.sort(Sorted, function(a, b)
		return (a.Priority or 0) > (b.Priority or 0)
	end)

	for i = 1, #Sorted do
		local Specified = Sorted[i]
		Callback(Specified.Entity, Specified)
	end
end

function World.AssignComponent(Entity: number, Key: string, Data: { any }, Weak: boolean?)
	if not World.Singleton.Components[Key] then
		error(`"{Key}" is not a registered component key`)
	end

	if Weak and not getmetatable(World.Singleton.Components[Key]) then
		setmetatable(World.Singleton.Components[Key], { __mode = "k" })
	end

	World.Singleton.Components[Key][Entity] = Data

	if typeof(Data) == "table" then
		for _, value in pairs(Data) do
			if typeof(value) == "Instance" then
				World.Singleton.Bodies[value] = Entity
				break
			end
		end
	end
end

function World.UnassignComponent(Entity: number, Key: string)
	local Pool = World.Singleton.Components[Key]
	if Pool then
		Pool[Entity] = nil
	end
end

function World.Kill(entity: number)
	World.Singleton.Alive[entity] = nil

	for _, Pool in pairs(World.Singleton.Components) do
		local data = Pool[entity]
		if typeof(data) == "table" then
			for _, value in pairs(data) do
				if typeof(value) == "Instance" then
					World.Singleton.Bodies[value] = nil
				end
			end
		end
		Pool[entity] = nil
	end
end

function World.Update(dt)
	for _, Entry in ipairs(World.Singleton.Systems) do
		local Module = Entry.Module
		if type(Module) == "table" and type(Module.Update) == "function" then
			Module.Update(dt)
		end
	end

	local Events = World.Singleton.Events
	World.Singleton.Events = World.Singleton.Next
	World.Singleton.Next = Events

	-- Clear all event buckets for next frame
	for _, Bucket in pairs(World.Singleton.Next) do
		table.clear(Bucket)
	end
end

return World
