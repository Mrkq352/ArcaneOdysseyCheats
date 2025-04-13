-- Script 1: Combat Functionality
local UIS = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
getgenv().bul = false  -- Start with `bul` set to false by default

-- Function to toggle `getgenv().bul` using the "F13" key
UIS.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.F13 then
        getgenv().bul = not getgenv().bul

        -- Display notification based on the state of `bul`
        if getgenv().bul then
            StarterGui:SetCore("SendNotification", {
                Title = "Script Status",
                Text = "ON",
                Duration = 1  -- Duration in seconds
            })
        else
            StarterGui:SetCore("SendNotification", {
                Title = "Script Status",
                Text = "OFF",
                Duration = 1
            })
        end
    end
end)

-- Main loop to deal damage when `getgenv().bul` is true
spawn(function() -- Run this in a separate thread
    while true do
        if getgenv().bul then
            for i, v in pairs(workspace.Enemies:GetChildren()) do
                if v:IsA("Model") and v:FindFirstChildOfClass("Humanoid") and v:FindFirstChildOfClass("Humanoid").Health > 0 and game.Players.LocalPlayer:DistanceFromCharacter(v.PrimaryPart.Position) < 21 then
                    local args = {
                        [1] = 0,
                        [2] = game:GetService("Players").LocalPlayer.Character,
                        [3] = v,
                        [4] = game:GetService("Players").LocalPlayer.Character:FindFirstChildOfClass("Tool"),
                        [5] = "Slash"
                    }
                    game:GetService("ReplicatedStorage").RS.Remotes.Combat.DealWeaponDamage:FireServer(unpack(args))
                end
            end
        end
        task.wait(0) -- Add a small delay to prevent lag
    end
end)

