local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Initialize core services first
local player = Players.LocalPlayer
if not player then
    warn("Player not found")
    return
end

-- Configuration
local CONFIG = {
    ENABLED = false,
    TOGGLE_KEY = Enum.KeyCode.F15,
    CLEAR_MARKERS_KEY = Enum.KeyCode.F7, -- Key to clear all markers
    SCAN_INTERVAL = 5, -- Scan every 5 seconds
    MAX_DISTANCE = 1000, -- Maximum distance for ESP to show (in studs)
    COLORS = {
        GOLDEN_CHEST = Color3.fromRGB(255, 223, 0), -- Light gold
        SILVER_CHEST = Color3.fromRGB(176, 224, 230), -- Blueish silver
        TREASURE_CHEST = Color3.fromRGB(139, 69, 19), -- Green brown
        COCONUT = Color3.fromRGB(255, 255, 255), -- White
        FRUIT = Color3.fromRGB(255, 65, 0), -- Bright red
        HERB = Color3.fromRGB(0, 255, 0), -- Green
        SHELL = Color3.fromRGB(255, 224, 189), -- Skin
        BRONZE_SEALED_CHEST = Color3.fromRGB(212, 169, 107), -- Bronze
        DARK_SEALED_CHEST = Color3.fromRGB(75, 0, 130), -- Dark purple
        NIMBUS_SEALED_CHEST = Color3.fromRGB(135, 206, 235) -- Sky blue
    }
}

-- State initialization
local State = {
    adornments = {},
    playerGui = player:WaitForChild("PlayerGui"),
    trackedObjects = {},
    playerPosition = Vector3.new(0, 0, 0),
    scanInProgress = false
}

-- Helper functions
local function updatePlayerPosition()
    local character = player.Character
    if character then
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        if humanoidRootPart then
            State.playerPosition = humanoidRootPart.Position
            return true
        end
    end
    return false
end

local function getObjectDistance(object)
    if not object:IsA("BasePart") then 
        if object:IsA("Model") then
            local primaryPart = object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart")
            if primaryPart then
                return (State.playerPosition - primaryPart.Position).Magnitude
            end
        end
        return math.huge 
    end
    return (State.playerPosition - object.Position).Magnitude
end

local function cleanupAdornment(object)
    local adornmentGroup = State.adornments[object]
    if adornmentGroup then
        pcall(function()
            adornmentGroup.box:Destroy()
            adornmentGroup.billboard:Destroy()
        end)
        State.adornments[object] = nil
    end
    State.trackedObjects[object] = nil
end

local function clearAllMarkers()
    -- Create a copy of the adornments table to avoid modifying it while iterating
    local adornmentsCopy = {}
    for object, adornmentGroup in pairs(State.adornments) do
        adornmentsCopy[object] = adornmentGroup
    end

    -- Clean up all adornments in the copy
    for object, _ in pairs(adornmentsCopy) do
        cleanupAdornment(object)
    end

    -- Clear the trackedObjects table
    State.trackedObjects = {}
    print("All markers cleared.")
end

local function getItemName(object)
    -- Check for a ProximityPrompt named "Prompt"
    local prompt = object:FindFirstChild("Prompt")
    if prompt and prompt:IsA("ProximityPrompt") then
        -- Use the ObjectText if it's not empty, otherwise fall back to the object's name
        return prompt.ObjectText ~= "" and prompt.ObjectText or object.Name
    end
    -- If no ProximityPrompt is found, return the object's name
    return object.Name
end

local function shouldTrackObject(object)
    if not (object:IsA("BasePart") or object:IsA("Model")) then return false end
    
    local objectName = object.Name:lower()
    local parent = object.Parent
    local parentName = parent and parent.Name:lower() or ""
    
    -- Skip spawners and parts named "Lid" or "Base"
    if objectName:match("herbspawn") or objectName:match("fruitspawn") or objectName:match("lid") or objectName:match("base") then
        return false
    end
    
    -- Track specific objects
    if objectName:match("chest") or parentName:match("chest") then
        return true
    elseif objectName:match("coconut") or objectName:match("fruit") or objectName:match("herb") or objectName:match("shell") then
        return true
    end
    
    return false
end

local function isObjectOpened(object)
    local openValue = object:FindFirstChild("Open")
    if openValue and openValue:IsA("BoolValue") then
        return openValue.Value
    end
    return false
end

local function createVisualElements(object, color, label)
    if not object or not object.Parent then return end

    local existing = State.adornments[object]
    if existing then
        -- Update the distance text
        existing.billboard.TextLabel.Text = label .. " (" .. math.floor(getObjectDistance(object)) .. "m)"
        return
    end

    local boxAdornment = Instance.new("BoxHandleAdornment")
    boxAdornment.Adornee = object
    boxAdornment.Size = (object:IsA("BasePart") and object.Size or Vector3.new(2, 2, 2)) + Vector3.new(0.1, 0.1, 0.1)
    boxAdornment.Color3 = color
    boxAdornment.Transparency = 0.3
    boxAdornment.AlwaysOnTop = true
    boxAdornment.ZIndex = 5
    boxAdornment.Visible = true
    boxAdornment.Parent = object

    local billboard = Instance.new("BillboardGui")
    billboard.Adornee = object
    billboard.Size = UDim2.new(0, 100, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Enabled = true

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = label .. " (" .. math.floor(getObjectDistance(object)) .. "m)"
    textLabel.TextColor3 = color
    textLabel.TextSize = 16
    textLabel.Font = Enum.Font.SourceSansBold
    textLabel.Parent = billboard

    billboard.Parent = State.playerGui

    State.adornments[object] = {
        box = boxAdornment,
        billboard = billboard
    }
end

local function handleNewObject(object)
    if not shouldTrackObject(object) then return end
    if isObjectOpened(object) then
        cleanupAdornment(object)
        return
    end

    local distance = getObjectDistance(object)
    if distance > CONFIG.MAX_DISTANCE then
        cleanupAdornment(object)
        return
    end

    local objectName = object.Name:lower()
    local parent = object.Parent
    local parentName = parent and parent.Name:lower() or ""
    local isGolden = object:FindFirstChild("Golden") ~= nil
    local itemName = getItemName(object)

    local visualConfig

    -- Chests use predefined labels
    if objectName:match("golden chest") or parentName:match("golden chest") then
        visualConfig = {color = CONFIG.COLORS.GOLDEN_CHEST, label = "Golden Chest"}
    elseif objectName:match("silver chest") or parentName:match("silver chest") then
        visualConfig = {color = CONFIG.COLORS.SILVER_CHEST, label = "Silver Chest"}
    elseif objectName:match("treasure chest") or parentName:match("treasure chest") then
        visualConfig = {color = CONFIG.COLORS.TREASURE_CHEST, label = "Treasure Chest"}
    elseif objectName:match("bronze sealed chest") then
        visualConfig = {color = CONFIG.COLORS.BRONZE_SEALED_CHEST, label = "Bronze Sealed Chest"}
    elseif objectName:match("dark sealed chest") then
        visualConfig = {color = CONFIG.COLORS.DARK_SEALED_CHEST, label = "Dark Sealed Chest"}
    elseif objectName:match("nimbus sealed chest") then
        visualConfig = {color = CONFIG.COLORS.NIMBUS_SEALED_CHEST, label = "Nimbus Sealed Chest"}
    else
        -- Other objects use the ObjectText from the ProximityPrompt
        visualConfig = {color = CONFIG.COLORS[objectName:upper()] or Color3.new(1, 1, 1), label = itemName}
    end

    if visualConfig then
        State.trackedObjects[object] = visualConfig
        createVisualElements(object, visualConfig.color, visualConfig.label)
    end
end

local function startScan()
    if State.scanInProgress or not CONFIG.ENABLED then return end
    State.scanInProgress = true

    local map = workspace:FindFirstChild("Map")
    if not map then 
        State.scanInProgress = false
        return 
    end

    -- Update player position before scanning
    updatePlayerPosition()

    for _, object in ipairs(map:GetDescendants()) do
        handleNewObject(object)
    end

    State.scanInProgress = false
end

local function toggleESP()
    CONFIG.ENABLED = not CONFIG.ENABLED
    if CONFIG.ENABLED then
        -- Perform an immediate scan
        startScan()
        -- Start periodic scans
        while CONFIG.ENABLED do
            wait(CONFIG.SCAN_INTERVAL)
            if CONFIG.ENABLED then
                startScan()
            end
        end
    end
end

-- Main initialization
local function init()
    if not workspace:FindFirstChild("Map") then
        warn("Map folder not found in workspace - ESP will not function")
        return
    end
    
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if input.KeyCode == CONFIG.TOGGLE_KEY and not gameProcessed then
            toggleESP()
        elseif input.KeyCode == CONFIG.CLEAR_MARKERS_KEY and not gameProcessed then
            clearAllMarkers()
        end
    end)

    workspace.Map.DescendantAdded:Connect(handleNewObject)
    workspace.Map.DescendantRemoving:Connect(cleanupAdornment)

    -- Continuously update distances for existing markers, even when ESP is toggled off
    RunService.Heartbeat:Connect(function()
        updatePlayerPosition()
        for object, config in pairs(State.trackedObjects) do
            if object and object.Parent then
                local distance = getObjectDistance(object)
                if distance > CONFIG.MAX_DISTANCE then
                    cleanupAdornment(object)
                else
                    if isObjectOpened(object) then
                        cleanupAdornment(object)
                    else
                        createVisualElements(object, config.color, config.label)
                    end
                end
            else
                cleanupAdornment(object)
            end
        end
    end)
end

-- Start the ESP system
init()
print("ESP Script loaded successfully")
print("Press F15 to toggle ESP")
print("Press F7 to clear all markers")
