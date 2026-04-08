--!nonstrict
-- @author : BakedAleska
-- @date : 02/20/2026

-- #CONSTANTS
local __DEBUG__ = false

-- #SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- #IMPORT
local Signal = require(ReplicatedStorage.Packages.signal)

-- #VARIABLES
local NextId = 0

--> Declare
local World = {}
World.__index = World
World.Singleton = nil :: world? -- Used to keep static references in functions (.) instead of needing the unique instance anytime a world function is called (:)

-- #TYPES
export type world = {
	Alive: { [number]: boolean },
	Components: { [string]: { [number]: any } },
	Bodies: { [Instance]: number },
	Crafted: any,
	Killed: any,
	AssignedComponent: any,
	RemovedComponent: any,
	Fired: any,
	Events: { [string]: { event } },
	Next: { [string]: { event } },
	CraftEntity: () -> number,
	RegisterBody: (Entity: number, Body: Instance) -> (),
	Count: (Components: { string }) -> string?,
	Kill: (Entity: number) -> (),
	AddSystem: (Module: ModuleScript, Priority: number?) -> (),
	RemoveSystem: (Name: string) -> boolean,
	ForEach: (Entity: number, Components: { string }) -> boolean,
	GetComponent: (Entity: number, Key: string) -> any,
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

export type system = {
	Name: string,
	Instance: any,
	Priority: number,
}

function World.new(): world
	local self = setmetatable({
		Alive = {},
		Components = {},
		Bodies = setmetatable({}, { __mode = "k" }), -- Weak keys: auto-cleanup when Instance destroyed

		Crafted = Signal.new(),
		Killed = Signal.new(),

		AssignedComponent = Signal.new(),
		RemovedComponent = Signal.new(),
		Fired = Signal.new(),

		Systems = {} :: { { system } }, -- The world systems
		Events = {}, -- The world event queue (read-only for systems)
		Next = {}, -- The next-frame event queue (used to prevent skipped events [system priority also mediates this])
	}, World)

	World.Singleton = self

	return self
end

--[[
Adds a new system to the Systems table. with optional priority -- default priority 1. Used to keep a reference to systems in the 
world singleton.
--]]
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
		Instance = Result,
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

--[[
Removes a system from the Systems table. If the system has a valid Destroy method, it's called. 
--]]
function World.RemoveSystem(Name: string)
	for i = #World.Singleton.Systems, 1, -1 do
		local Entry = World.Singleton.Systems[i]
		if Entry.Name == Name then
			local System = Entry.Instance
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

--[[
Registers a "body" to be associated with an entity. Allows for easier retreival of entity specific components.

EX: The players entity would have a Player body of type 'Player' 
such that ReturnEntity can be called to receive the entities ID.
--]]
function World.RegisterBody(Entity: number, Body: Instance): Instance?
	if World.Singleton.Bodies[Body] then
		warn(string.format("[World] Body %s, already present.", Body.Name))
		return
	end

	World.Singleton.Bodies[Body] = Entity

	return Body
end

--[[
Retrieves the Instance body associated with a given entity ID from the Bodies table. 
Essentially a reverse ReturnEntity
--]]
function World.FetchBody(Entity: number): Instance?
	for Instance, Mapped in pairs(World.Singleton.Bodies) do
		if Mapped == Entity then
			return Instance
		end
	end
	return nil
end

--[[
Returns the entity ID associated with a given Instance from the Bodies table. 
--]]
function World.ReturnEntity(Reference: Instance): number?
	return World.Singleton.Bodies[Reference]
end

--[[
Creates a new entity in the world, returning that entities id. 
--]]
function World.CraftEntity(): number
	NextId += 1

	World.Singleton.Alive[NextId] = true
	World.Singleton.Crafted:Fire(NextId)

	return NextId
end

--[[
Returns the component, within a given table of components, 
which is associated with the smallest number of entities. 

Used: primarily for fast, mutli-component access; alongside ForEach

EX: Say a system needs C1, C2, C3 each of which being components, instead of looping through all entities in the game
loop through the entities in whichever component has the LEAST amount of entities associated with it given
from Count
--]]
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

--[[
Iterates through multiuple Components, given an entity: and returns a boolean representing 
whether or not that entity has all the listed components. 
--]]
function World.ForEach(Entity: number, Components: { string }): boolean
	for _, Component in Components do
		local Pool = World.Singleton.Components[Component]
		if not Pool or not Pool[Entity] then
			return false
		end
	end
	return true
end

--[[
Fires an event to be processed in the next frame. The event is added to the Next event queue. 

Events are processed in the next frame to ensure no skipped events.

SKIPPED EVENT CASE: If System1 is loaded in the same frame but before System2, and System1 listens for an event from 
System2, then that event is skipped. By listening to events in the NEXT frame this is not a concern. Priority also helps
mitigate this, but this is a surefire way to avoid micromanagement.
--]]
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
	World.Singleton.Fired:Fire(Copy.Event, Copy)

	if __DEBUG__ then
		print("Firing event:", Copy.Event, "for entity:", Copy.Entity)
		print("Current Events table:", World.Singleton.Events)
	end
end

--[[
Checks if a specific entity has a fired event of the given name in the current Events table. 

This is useful for checking if an entity received a specific event in the current frame. 

SubscribeTo is the more commonly used "Do X when this event happens" function.
--]]
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

--[[
Returns the array of all events with a given name from the current Events table. 

Each event in the array is an event table containing Event, Entity, Body (optional), and Priority (optional) fields. 
--]]
function World.ReadEvent(Name: string)
	return World.Singleton.Events[Name]
end

--[[
Calls the provided callback for each entity that has the specified event in the current Events table. 

The Event parameter should match the Event field of fired events (keep event case consistent). 
--]]
function World.SubscribeTo(Event: string, Callback: (Entity: number, Data: any) -> ())
	local Bucket = World.Singleton.Events[Event]
	if not Bucket then
		return
	end

	local Sorted = {}
	for _, EventData in pairs(Bucket) do
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

--[[
Returns the specific component instance associated with an entity.
--]]
function World.GetComponent(Entity: number, Key: string) --~NoDocumentation
	local Pool = World.Singleton.Components[Key]
	if not Pool then
		return nil
	end

	return Pool[Entity]
end

--[[
Given an entity, a key (name for the component) and the components data, stores a component and its data in Components. 
--]]
function World.AssignComponent(Entity: number, Key: string, Data: { any }, Weak: boolean?)
	if not World.Singleton.Components[Key] then
		World.Singleton.Components[Key] = {}
	end

	if Weak and not getmetatable(World.Singleton.Components[Key]) then
		setmetatable(World.Singleton.Components[Key], { __mode = "k" })
	end

	local Previous = World.Singleton.Components[Key][Entity]
	World.Singleton.Components[Key][Entity] = Data

	if typeof(Data) == "table" then
		for _, value in pairs(Data) do
			if typeof(value) == "Instance" then
				World.Singleton.Bodies[value] = Entity
				break
			end
		end
	end

	World.Singleton.AssignedComponent:Fire(Entity, Key, Data, Previous)
end

--[[
Removes a component from an entity by deleting it from the Components table. 
--]]
function World.UnassignComponent(Entity: number, Key: string)
	local Pool = World.Singleton.Components[Key]
	if Pool then
		local Previous = Pool[Entity]
		Pool[Entity] = nil
		if Previous ~= nil then
			World.Singleton.RemovedComponent:Fire(Entity, Key, Previous)
		end
	end
end

--[[
Destroys the specified entity. 
--]]
function World.Kill(entity: number)
	local Removed = 0
	World.Singleton.Alive[entity] = nil

	for Key, Pool in pairs(World.Singleton.Components) do
		local data = Pool[entity]
		if typeof(data) == "table" then
			for _, value in pairs(data) do
				if typeof(value) == "Instance" then
					World.Singleton.Bodies[value] = nil
				end
			end
		end
		if data ~= nil then
			Pool[entity] = nil
			Removed += 1
			World.Singleton.RemovedComponent:Fire(entity, Key, data)
		end
	end

	World.Singleton.Killed:Fire(entity, Removed)
end

--[[
Updates all systems and processes events. Should be called once per frame, normally by using RunService. Swaps Events with Next, then clears the Next queue. 
--]]
function World.Update(dt) --~Add: Rate limiting (X times per second)
	for _, Entry in ipairs(World.Singleton.Systems) do
		local Module = Entry.Instance
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
