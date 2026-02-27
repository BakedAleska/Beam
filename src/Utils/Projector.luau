--!nocheck
--!nolint
-- @author : BakedAleksa
-- @date : 02/23/2026

-- #SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

-- #IMPORT
local replica = require(ReplicatedStorage.Packages.replica)

local printf = string.format

--> Types
export type properties = {
	Enabled: boolean?,
	EmitCount: number?,
	Janitor: Instance?,
	InheritColor: boolean?,
}

--> Declare
local Projector = {}

function Projector.Listen()
	replica.OnNew("Events", function(Replica)
		local Data = Replica.Data

		if Data.Event == "emitEffect" then
			Projector.Emit(Data.Effect, Data.Adornee, Data.Properties)
		elseif Data.Event == "invokeEffect" then
			Projector.Invoke(Data.Effect, Data.Adornee, Data.Arguments)
		end
	end)
end

function Projector.Emit(Effect: string, Adornee: BasePart | Attachment, Properties: properties?)
	local Container = ReplicatedStorage.Assets.Effects:FindFirstChild(Effect, true)
	if not Container then
		warn(printf("[Projector] No such effect: %s", Effect))
		return
	end

	local Emitters = if Container:IsA("Folder") then Container:GetChildren() else { Container }

	for _, Emitter in ipairs(Emitters) do
		if Emitter:IsA("ParticleEmitter") then
			local Clone = Emitter:Clone()
			local Attachment: Attachment?

			if not Adornee:IsA("Attachment") then
				Attachment = Instance.new("Attachment")
				Attachment.Parent = Adornee
				Clone.Parent = Attachment
			else
				Clone.Parent = Adornee
			end

			if Properties and Properties.Janitor then
				Properties.Janitor.Destroying:Once(function()
					if Clone then
						Clone:Destroy()
					end
					if Attachment then
						Attachment:Destroy()
					end
				end)
			end

			if Properties and Properties.Enabled then
				Clone.Enabled = true
			end

			if Properties and Properties.InheritColor then
				local Ancestor = Adornee
				while Ancestor and not Ancestor:IsA("Model") do
					Ancestor = Ancestor.Parent
				end

				local Params = RaycastParams.new()
				if Ancestor then
					Params.FilterDescendantsInstances = { Ancestor }
				end
				Params.FilterType = Enum.RaycastFilterType.Exclude
				Params.IgnoreWater = true

				local Position = if Adornee:IsA("Attachment") then Adornee.WorldPosition else Adornee.Position
				local Result = Workspace:Raycast(Position, Vector3.new(0, -10, 0), Params)
				if Result and Result.Instance:IsA("BasePart") then
					Clone.Color = ColorSequence.new(Result.Instance.Color)
				end
			end

			local Attribute = Clone:GetAttribute("EmitCount")
			local EmitCount = (Properties and Properties.EmitCount)
				or (typeof(Attribute) == "number" and Attribute)
				or 1
			Clone:Emit(EmitCount)

			if not (Properties and Properties.Janitor) then
				local Lifetime = typeof(Emitter.Lifetime) == "number" and Emitter.Lifetime
					or (Emitter.Lifetime :: NumberRange).Max
				Debris:AddItem(Clone, Lifetime + 1)
				if Attachment then
					Debris:AddItem(Attachment, Lifetime + 1)
				end
			end
		end
	end
end

function Projector.Invoke(Effect: string, Adornee: BasePart | Attachment, Arguments: {}?)
	local Module = ReplicatedStorage.Assets.Effects:FindFirstChild(Effect, true)
	if not Module or not Module:IsA("ModuleScript") then
		warn(printf("[Projector] Unable to find module: %s", Effect))
		return
	end

	local Success, Error = pcall(function()
		local Function = require(Module)
		if typeof(Function) == "function" then
			Function(Adornee, Arguments)
		else
			warn(printf("[Projector] Module did not return a function: %s", Effect))
		end
	end)

	if not Success then
		warn(printf("[Projector] Invoke error for %s: %s", Effect, Error))
	end
end

return Projector
