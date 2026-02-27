--!nonstrict
-- @author : BakedAleska
-- @date : 02/22/2026

-- #SERVICES
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- #IMPORT
local maid = require(ReplicatedStorage.Packages.maid)
local replica = require(ReplicatedStorage.Packages.replica)

-- #VARIABLES
local Player = Players.LocalPlayer

--> Declare
local Forces = {}

local Maid = maid.new()

local function Return_Direction(RootPart: BasePart, Direction: string)
	local Forward = Forces.Normalize_Vector(RootPart.CFrame.LookVector)
	local Right = Forces.Normalize_Vector(RootPart.CFrame.RightVector)

	if Direction == "Backward" then
		return -Forward
	elseif Direction == "Right" then
		return Right
	elseif Direction == "Left" then
		return -Right
	else
		return Forward
	end
end

function Forces.Attachment(Parent)
	local Attachment = Instance.new("Attachment")
	Attachment.Parent = Parent

	return Attachment
end

function Forces.Normalize_Vector(Vector: Vector3)
	local XZ = Vector3.new(Vector.X, 0, Vector.Z)
	local M = XZ.Magnitude
	return (M > 1e-6) and (XZ / M) or Vector3.zero
end

function Forces.Listen()
	replica.OnNew("Events", function(Replica)
		if not Replica.Tags["Body"] then
			return
		end

		if Replica.Tags["Body"] ~= Player then
			return
		end

		local Data = Replica.Data

		local Character = Player.Character or Player.CharacterAdded:Wait()
		local RootPart = Character:FindFirstChild("HumanoidRootPart")

		if Data.Event == "applyForce" then
			if Data.Force == "LinearVelocity" then
				Forces.Linear_Velocity(RootPart, Data.Velocity, Data.Duration, Data.Max)
			elseif Data.Force == "AdaptiveLinearVelocity" then
				Forces.Adaptive_Linear_Velocity(RootPart, Data.Velocity, Data.Duration, Data.Direction, Data.Max)
			elseif Data.Force == "AssemblyLinearVelocity" then
				Forces.Assembly_Linear_Velocity(RootPart, Data.Velocity)
			end
		elseif Data.Event == "destroyForces" then
			if RootPart then
				Forces.Destroy_Forces(RootPart)
			end
		end
	end)
end

function Forces.Linear_Velocity(RootPart: BasePart, Velocity: Vector3, Duration: number, Max: number?)
	local Attachment = Forces.Attachment(RootPart)
	Attachment.Name = "VelocityAttachment"

	local LinearVelocity = Instance.new("LinearVelocity")
	LinearVelocity.VectorVelocity = Velocity
	LinearVelocity.Attachment0 = Attachment
	LinearVelocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	LinearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	LinearVelocity.MaxAxesForce = Max or Vector3.new(50000, 50000, 50000)
	LinearVelocity.Parent = Attachment

	Debris:AddItem(Attachment, Duration)
end

function Forces.Adaptive_Linear_Velocity(
	RootPart: BasePart,
	Velocity: Vector3,
	Duration: number,
	Direction: string,
	Max: number?
)
	local Attachment = Forces.Attachment(RootPart)
	Attachment.Name = "VelocityAttachment"

	local LinearVelocity = Instance.new("LinearVelocity")
	LinearVelocity.Attachment0 = Attachment
	LinearVelocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	LinearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	LinearVelocity.MaxAxesForce = Max
	LinearVelocity.Parent = Attachment

	local Elapsed = 0
	local Connection: RBXScriptConnection?
	local function Cleanup()
		if Connection then
			Connection:Disconnect()
			Connection = nil
		end

		if Attachment.Parent then
			Attachment:Destroy()
		end
	end

	Connection = RunService.Heartbeat:Connect(function(dt)
		if not RootPart or not RootPart.Parent then
			Cleanup()
			return
		end

		Elapsed += dt

		if Elapsed >= Duration then
			Cleanup()
			return
		end

		local Dir = Return_Direction(RootPart, Direction)
		local HorizontalSpeed = Vector3.new(Velocity.X, 0, Velocity.Z).Magnitude
		local Lift = Velocity.Y
		LinearVelocity.VectorVelocity = (Dir == Vector3.zero) and Vector3.zero
			or (Dir * HorizontalSpeed + Vector3.new(0, Lift, 0))
	end)
	Maid:GiveTask(Connection)
end

function Forces.Vector_Force(RootPart: BasePart, Force: Vector3, Duration: number)
	local Attachment = Forces.Attachment(RootPart)
	Attachment.Name = "VelocityAttachment"
	local VectorForce = Instance.new("VectorForce")
	VectorForce.Force = Force
	VectorForce.RelativeTo = Enum.ActuatorRelativeTo.World
	VectorForce.Attachment0 = Attachment
	VectorForce.ApplyAtCenterOfMass = true
	VectorForce.Parent = Attachment

	Debris:AddItem(VectorForce, Duration)
end

function Forces.Assembly_Linear_Velocity(RootPart: BasePart, Velocity: Vector3)
	RootPart.AssemblyLinearVelocity = Velocity
end

function Forces.Destroy_Forces(RootPart: BasePart)
	Maid:DoCleaning()

	RootPart.AssemblyLinearVelocity = Vector3.zero

	for _, Desc in ipairs(RootPart:GetChildren()) do
		if
			(Desc:IsA("Attachment") and Desc.Name == "VelocityAttachment")
			or Desc:IsA("LinearVelocity")
			or Desc:IsA("VectorForce")
		then
			Desc:Destroy()
		elseif Desc:IsA("BasePart") then
			Desc.AssemblyLinearVelocity = Vector3.zero
		end
	end
end

return Forces
