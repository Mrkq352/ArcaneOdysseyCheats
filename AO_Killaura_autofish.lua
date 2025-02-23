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

-- Script 2: Fishing Functionality
local players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local isFishing = false
local fishingEnabled = false  -- This will toggle the fishing script on/off
local lastPos = Vector3.new(0, 0, 0)
local rodName = ""

local function getFishingRod(backpack)
    -- Initialize variables
    local chars
    local rodName
    
    -- Determine where to look for the rod
    if backpack then
        chars = players.LocalPlayer.Backpack:GetChildren()
    else
        chars = players.LocalPlayer.Character:GetChildren()
    end
    
    -- Search for the rod
    local rod = nil
    for _, child in pairs(chars) do
        if string.match(child.Name, "Rod") then
            if not backpack then
                rodName = child.Name
            end
            
            -- Skip if we're checking backpack and names don't match
            if backpack and rodName and child.Name ~= rodName then
            end
            
            rod = child
            break
        end
    end
    
    return rod
end

function triggerRod()
    local rod = getFishingRod()
    if not (rod) then 
        return rod 
    end 
    local toolEvent = ReplicatedStorage.RS.Remotes.Misc:WaitForChild("ToolAction")
    toolEvent:FireServer(rod)
end

function startFishing()
    if not (isFishing) then
        triggerRod()
        isFishing = true
        return true
    else
        return false
    end
end

-- Key to toggle the fishing functionality using UIS
UIS.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.F14 then
        fishingEnabled = not fishingEnabled  -- Toggle the state
        print("Fishing Enabled: " .. tostring(fishingEnabled))
    end
end)

local gotfish = false
local lastGotFish = false

-- Main fishing loop
spawn(function()
    while wait(0.1) do 
        if fishingEnabled then
            local ply = players.LocalPlayer
            local pmodel = ply.Character
            local root = pmodel.HumanoidRootPart

            spawn(function()
                local GotFish = pmodel:FindFirstChild("FishBiteGoal")
                if GotFish and GotFish.value then
                    rodName = getFishingRod().Name
                    triggerRod()
                    gotfish = true
                end
            end)

            if lastGotFish ~= gotfish and not (gotfish) then
                -- Unequip then equip the fishing rod
                local rod = getFishingRod()
                if rod then
                    rod.Parent = ply.Backpack
                    wait(1)
                    rod.Parent = ply.Character
                    wait(1)
                    isFishing = true
                    triggerRod()
                end
            end

            lastGotFish = gotfish

            if gotfish then
                gotfish = false
            else
                startFishing()    
            end

            spawn(function()
                local rod = getFishingRod(true)
                if rod then
                    isFishing = false
                end
            end)    

            local currentPos = pmodel.HumanoidRootPart.Position
            if (lastPos - currentPos).magnitude > 1.9 then
                isFishing = false    
            end
            lastPos = currentPos
        else
            isFishing = false  -- Make sure fishing stops when disabled
        end
    end
end)
