--!nonstrict
-- @author : BakedAleska
-- @date : 02/21/2026

local DefaultFadeTime = 0.1
local ConditionalDebounce = 0.08

local TrackProperties = {
	Looped = true,
	Priority = true,
	TimePosition = true,
	Length = true,
}

-- #SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")

-- #IMPORT
local Maid = require(ReplicatedStorage.Packages.maid).new()
local replica = require(ReplicatedStorage.Packages.replica)

-- #VARIABLES
local Player = Players.LocalPlayer

--> Declare
local Animator = {}

local Playing: AnimationTrack? = nil
local Queued: AnimationTrack? = nil

local Conditionals = {
	Sprint = function(): boolean
		local Character = Player.Character
		if not Character then
			return false
		end

		local Humanoid = Character:FindFirstChildOfClass("Humanoid")
		if not Humanoid then
			return false
		end

		return Humanoid.FloorMaterial ~= Enum.Material.Air
	end,
}

export type Properties = { Looped: boolean?, Group: string?, FadeTime: number?, Speed: number? }

local function Fetch_Animator_Instance(Character: Model): Animator?
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	assert(Humanoid, "[Animator] No such valid humanoid for character:" .. Character.Name)

	return Humanoid:FindFirstChildOfClass("Animator")
end

local function Attach_Conditional_Watcher(Track: AnimationTrack, Conditional: () -> boolean)
	Maid.Watcher = nil

	local PendingState = Conditional()
	local PendingAt = os.clock()
	local LastApplied: boolean? = nil

	Maid.Watcher = RunService.Heartbeat:Connect(function()
		if Playing ~= Track then
			Maid.Watcher = nil
			return
		end

		local CanPlay = Conditional()
		local Now = os.clock()
		if CanPlay ~= PendingState then
			PendingState = CanPlay
			PendingAt = Now
			return
		end

		if Now - PendingAt < ConditionalDebounce then
			return
		end

		if LastApplied == CanPlay then
			return
		end

		LastApplied = CanPlay
		if CanPlay then
			if not Track.IsPlaying then
				Track:Play(DefaultFadeTime)
			end
		else
			if Track.IsPlaying then
				Track:Stop(DefaultFadeTime)
			end
		end
	end)
end

local function Preload_Animations()
	local Queue = {}

	for _, Animation in ipairs(ReplicatedStorage.Assets.Animations:GetDescendants()) do
		if Animation:IsA("Animation") then
			table.insert(Queue, Animation)
		end
	end

	if #Queue > 0 then
		ContentProvider:PreloadAsync(Queue, function()
			print("Preloaded animations.")
		end)
	end
end

function Animator.Play_Animation(Name: string, Properties: Properties?)
	local Animation = ReplicatedStorage.Assets.Animations:FindFirstChild(Name, true)
	if not Animation then
		warn(string.format("[Animator] No such valid animation %s", Name))
		return
	end

	local Conditional = Conditionals[Name]

	local Character = Player.Character or Player.CharacterAdded:Wait()
	local AnimatorInstance = Fetch_Animator_Instance(Character)
	assert(AnimatorInstance, "[Animator] No Animator object found.")

	local Track = AnimatorInstance:LoadAnimation(Animation) :: AnimationTrack

	local FadeTime = (Properties and Properties.FadeTime) or DefaultFadeTime

	if Properties then
		if Properties.Group then
			Track:SetAttribute("Group", Properties.Group)
		end

		for Property, Value in pairs(Properties) do
			if Property == "Speed" then
				Track:AdjustSpeed(Value)
			elseif TrackProperties[Property] then
				Track[Property] = Value
			end
		end
	end

	local IsLooped = Track.Looped

	if Playing then
		Maid.Watcher = nil
		local WasLooped = Playing.Looped

		if WasLooped and not IsLooped then
			Queued = Playing
		end

		if IsLooped then
			Queued = nil
		end

		Playing:Stop(FadeTime)
	end

	Playing = Track
	Track:Play(FadeTime)

	if IsLooped and Conditional then
		Attach_Conditional_Watcher(Track, Conditional)
	else
		Maid.Watcher = nil
	end

	if not IsLooped then
		Track.Stopped:Once(function()
			if Playing ~= Track then
				return
			end

			Playing = nil
			Maid.Watcher = nil

			if Queued then
				local LoopToResume = Queued
				local Resume = Conditionals[LoopToResume.Name]
				Queued = nil
				Playing = LoopToResume

				if LoopToResume.Looped and Resume then
					if Resume() then
						LoopToResume:Play(DefaultFadeTime)
					end

					Attach_Conditional_Watcher(LoopToResume, Resume)
				else
					LoopToResume:Play(DefaultFadeTime)
				end
			end
		end)
	end
end

function Animator.Stop_Animation(Name: string, FadeTime: number?)
	FadeTime = FadeTime or DefaultFadeTime

	if Playing then
		if Playing.Name == Name or Playing:GetAttribute("Group") == Name then
			Playing:Stop(FadeTime)
			Playing = nil
			Maid.Watcher = nil
		end
	end

	if Queued then
		if Queued.Name == Name or Queued:GetAttribute("Group") == Name then
			Queued:Stop(FadeTime)
			Queued = nil
		end
	end
end

function Animator.Listen()
	Preload_Animations()

	replica.OnNew("Events", function(Replica)
		local Data = Replica.Data

		if not Replica.Tags["Body"] then
			return
		end

		if Replica.Tags["Body"] ~= Player then
			return
		end

		if Data.Event == "playAnimation" then
			Animator.Play_Animation(Data.Animation, Data.Properties)
		elseif Data.Event == "stopAnimation" then
			Animator.Stop_Animation(Data.Animation, Data.FadeTime)
		end
	end)
end

return Animator
