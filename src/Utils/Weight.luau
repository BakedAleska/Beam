--!nonstrict
-- @author : BakedAleska
-- @date : 02/25/2026

-- #SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- #IMPORT
local replica = require(ReplicatedStorage.Packages.replica)
local MaidModule = require(ReplicatedStorage.Packages.maid)

-- #VARIABLES
local Player = Players.LocalPlayer

--> Declare
local Weight = {}

function Weight.Listen()
	replica.OnNew("Events", function(Replica)
		if not Replica.Tags["Body"] then
			return
		end

		if Replica.Tags["Body"] ~= Player then
			return
		end

		local Data = Replica.Data

		if Data.Event == "changeGravity" then
			local Workspace = game:GetService("Workspace")
			Workspace.Gravity = 196.2 * Data.Value

			if Data.Duration then
				task.delay(Data.Duration, function()
					Workspace.Gravity = 196.2
				end)
			else
				local Character = Player.Character
				if not Character then
					return
				end

				local Humanoid = Character:FindFirstChildOfClass("Humanoid")
				if not Humanoid then
					return
				end

				local Maid = MaidModule.new()

				local function ResetGravity()
					Workspace.Gravity = 196.2
					Maid:DoCleaning()
				end

				Maid.FloorMaterial = Humanoid:GetPropertyChangedSignal("FloorMaterial"):Connect(function()
					if Humanoid.FloorMaterial ~= Enum.Material.Air then
						ResetGravity()
					end
				end)

				Maid.StateChanged = Humanoid.StateChanged:Connect(function(_, State)
					if State == Enum.HumanoidStateType.Landed then
						ResetGravity()
					end
				end)
			end
		end
	end)
end

return Weight
