local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

-- Initialize core services first
local player = Players.LocalPlayer
if not player then
    warn("Player not found")
    return
end

-- Default Configuration
local DEFAULT_CONFIG = {
    TOGGLE_GUI_KEY = Enum.KeyCode.F15, -- Key to open/close the GUI
    SCAN_INTERVAL = 5, -- Scan every 5 seconds
    MIN_DISTANCE = 0, -- Minimum distance for ESP to show (in studs)
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
        NIMBUS_SEALED_CHEST = Color3.fromRGB(135, 206, 235), -- Sky blue
        GOLDEN = Color3.fromRGB(255, 215, 0) -- Gold color for golden fruits/herbs
    }
}

-- Current Configuration (can be modified via GUI)
local CONFIG = {
    TOGGLE_GUI_KEY = DEFAULT_CONFIG.TOGGLE_GUI_KEY,
    SCAN_INTERVAL = DEFAULT_CONFIG.SCAN_INTERVAL,
    MIN_DISTANCE = DEFAULT_CONFIG.MIN_DISTANCE,
    MAX_DISTANCE = DEFAULT_CONFIG.MAX_DISTANCE
}

-- State initialization
local State = {
    adornments = {},
    playerGui = player:WaitForChild("PlayerGui"),
    trackedObjects = {},
    playerPosition = Vector3.new(0, 0, 0),
    scanInProgress = false,
    scanningEnabled = false,
    visibilityEnabled = true, -- Visibility is enabled by default
    guiVisible = false
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
    -- Check for an "Open" child
    local openValue = object:FindFirstChild("Open")
    if openValue then
        -- If it's a BoolValue, check its value
        if openValue:IsA("BoolValue") then
            return openValue.Value
        end
        -- If it's not a BoolValue, assume the chest is opened if the "Open" child exists
        return true
    end
    -- If no "Open" child is found, assume the chest is closed
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
    boxAdornment.Visible = State.visibilityEnabled
    boxAdornment.Parent = object

    local billboard = Instance.new("BillboardGui")
    billboard.Adornee = object
    billboard.Size = UDim2.new(0, 100, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Enabled = State.visibilityEnabled

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
    if distance < CONFIG.MIN_DISTANCE or distance > CONFIG.MAX_DISTANCE then
        cleanupAdornment(object)
        return
    end

    local objectName = object.Name:lower()
    local parent = object.Parent
    local parentName = parent and parent.Name:lower() or ""
    local isGolden = object:FindFirstChild("Golden") ~= nil -- Check for the "Golden" child
    local itemName = getItemName(object)

    local visualConfig

    -- Chests use predefined labels
    if objectName:match("golden chest") or parentName:match("golden chest") then
        visualConfig = {color = DEFAULT_CONFIG.COLORS.GOLDEN_CHEST, label = "Golden Chest"}
    elseif objectName:match("silver chest") or parentName:match("silver chest") then
        visualConfig = {color = DEFAULT_CONFIG.COLORS.SILVER_CHEST, label = "Silver Chest"}
    elseif objectName:match("treasure chest") or parentName:match("treasure chest") then
        visualConfig = {color = DEFAULT_CONFIG.COLORS.TREASURE_CHEST, label = "Treasure Chest"}
    elseif objectName:match("bronze sealed chest") then
        visualConfig = {color = DEFAULT_CONFIG.COLORS.BRONZE_SEALED_CHEST, label = "Bronze Sealed Chest"}
    elseif objectName:match("dark sealed chest") then
        visualConfig = {color = DEFAULT_CONFIG.COLORS.DARK_SEALED_CHEST, label = "Dark Sealed Chest"}
    elseif objectName:match("nimbus sealed chest") then
        visualConfig = {color = DEFAULT_CONFIG.COLORS.NIMBUS_SEALED_CHEST, label = "Nimbus Sealed Chest"}
    else
        -- Other objects use the ObjectText from the ProximityPrompt
        if objectName:match("fruit") then
            visualConfig = {color = isGolden and DEFAULT_CONFIG.COLORS.GOLDEN or DEFAULT_CONFIG.COLORS.FRUIT, label = itemName}
        elseif objectName:match("herb") then
            visualConfig = {color = isGolden and DEFAULT_CONFIG.COLORS.GOLDEN or DEFAULT_CONFIG.COLORS.HERB, label = itemName}
        else
            visualConfig = {color = DEFAULT_CONFIG.COLORS[objectName:upper()] or Color3.new(1, 1, 1), label = itemName}
        end
    end

    if visualConfig then
        State.trackedObjects[object] = visualConfig
        createVisualElements(object, visualConfig.color, visualConfig.label)
    end
end

local function startScan()
    if State.scanInProgress or not State.scanningEnabled then return end
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

-- GUI Creation
local function createGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ESPGui"
    screenGui.Parent = State.playerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 500, 0, 300) -- Wider frame for 2 columns
    frame.Position = UDim2.new(0.5, -250, 0.5, -150)
    frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    frame.BorderSizePixel = 0
    frame.Visible = false
    frame.Parent = screenGui

    -- Column 1
    local scanButton = Instance.new("TextButton")
    scanButton.Size = UDim2.new(0.4, 0, 0.1, 0)
    scanButton.Position = UDim2.new(0.05, 0, 0.05, 0)
    scanButton.Text = "Scanning: OFF"
    scanButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0) -- Red when off
    scanButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    scanButton.Font = Enum.Font.SourceSansBold
    scanButton.TextSize = 14
    scanButton.Parent = frame

    local visibilityButton = Instance.new("TextButton")
    visibilityButton.Size = UDim2.new(0.4, 0, 0.1, 0)
    visibilityButton.Position = UDim2.new(0.05, 0, 0.2, 0)
    visibilityButton.Text = "Visibility: ON"
    visibilityButton.BackgroundColor3 = Color3.fromRGB(0, 255, 0) -- Green when on
    visibilityButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    visibilityButton.Font = Enum.Font.SourceSansBold
    visibilityButton.TextSize = 14
    visibilityButton.Parent = frame

    local scanNowButton = Instance.new("TextButton")
    scanNowButton.Size = UDim2.new(0.4, 0, 0.1, 0)
    scanNowButton.Position = UDim2.new(0.05, 0, 0.35, 0)
    scanNowButton.Text = "Scan Now"
    scanNowButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    scanNowButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    scanNowButton.Font = Enum.Font.SourceSansBold
    scanNowButton.TextSize = 14
    scanNowButton.Parent = frame

    -- Column 2
    local minDistanceLabel = Instance.new("TextLabel")
    minDistanceLabel.Size = UDim2.new(0.4, 0, 0.05, 0)
    minDistanceLabel.Position = UDim2.new(0.55, 0, 0.05, 0)
    minDistanceLabel.Text = "Min Distance: " .. CONFIG.MIN_DISTANCE
    minDistanceLabel.BackgroundTransparency = 1
    minDistanceLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    minDistanceLabel.Font = Enum.Font.SourceSansBold
    minDistanceLabel.TextSize = 14
    minDistanceLabel.Parent = frame

    local minDistanceInput = Instance.new("TextBox")
    minDistanceInput.Size = UDim2.new(0.4, 0, 0.05, 0)
    minDistanceInput.Position = UDim2.new(0.55, 0, 0.1, 0)
    minDistanceInput.PlaceholderText = "Enter Min Distance"
    minDistanceInput.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    minDistanceInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    minDistanceInput.Font = Enum.Font.SourceSansBold
    minDistanceInput.TextSize = 14
    minDistanceInput.Parent = frame

    local maxDistanceLabel = Instance.new("TextLabel")
    maxDistanceLabel.Size = UDim2.new(0.4, 0, 0.05, 0)
    maxDistanceLabel.Position = UDim2.new(0.55, 0, 0.2, 0)
    maxDistanceLabel.Text = "Max Distance: " .. CONFIG.MAX_DISTANCE
    maxDistanceLabel.BackgroundTransparency = 1
    maxDistanceLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    maxDistanceLabel.Font = Enum.Font.SourceSansBold
    maxDistanceLabel.TextSize = 14
    maxDistanceLabel.Parent = frame

    local maxDistanceInput = Instance.new("TextBox")
    maxDistanceInput.Size = UDim2.new(0.4, 0, 0.05, 0)
    maxDistanceInput.Position = UDim2.new(0.55, 0, 0.25, 0)
    maxDistanceInput.PlaceholderText = "Enter Max Distance"
    maxDistanceInput.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    maxDistanceInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    maxDistanceInput.Font = Enum.Font.SourceSansBold
    maxDistanceInput.TextSize = 14
    maxDistanceInput.Parent = frame

    local resetButton = Instance.new("TextButton")
    resetButton.Size = UDim2.new(0.4, 0, 0.1, 0)
    resetButton.Position = UDim2.new(0.55, 0, 0.35, 0)
    resetButton.Text = "Reset to Defaults"
    resetButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    resetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    resetButton.Font = Enum.Font.SourceSansBold
    resetButton.TextSize = 14
    resetButton.Parent = frame

    local keybindLabel = Instance.new("TextLabel")
    keybindLabel.Size = UDim2.new(0.4, 0, 0.05, 0)
    keybindLabel.Position = UDim2.new(0.55, 0, 0.45, 0)
    keybindLabel.Text = "Keybind: " .. tostring(CONFIG.TOGGLE_GUI_KEY)
    keybindLabel.BackgroundTransparency = 1
    keybindLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    keybindLabel.Font = Enum.Font.SourceSansBold
    keybindLabel.TextSize = 14
    keybindLabel.Parent = frame

    local keybindInput = Instance.new("TextBox")
    keybindInput.Size = UDim2.new(0.4, 0, 0.05, 0)
    keybindInput.Position = UDim2.new(0.55, 0, 0.5, 0)
    keybindInput.PlaceholderText = "Press a key to set keybind"
    keybindInput.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    keybindInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    keybindInput.Font = Enum.Font.SourceSansBold
    keybindInput.TextSize = 14
    keybindInput.Parent = frame

    -- Toggle scanning (like F15 before)
    scanButton.MouseButton1Click:Connect(function()
        State.scanningEnabled = not State.scanningEnabled
        scanButton.Text = "Scanning: " .. (State.scanningEnabled and "ON" or "OFF")
        scanButton.BackgroundColor3 = State.scanningEnabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
        if State.scanningEnabled then
            startScan()
            -- Start periodic scans
            while State.scanningEnabled do
                wait(CONFIG.SCAN_INTERVAL)
                if State.scanningEnabled then
                    startScan()
                end
            end
        end
    end)

    -- Toggle visibility
    visibilityButton.MouseButton1Click:Connect(function()
        State.visibilityEnabled = not State.visibilityEnabled
        visibilityButton.Text = "Visibility: " .. (State.visibilityEnabled and "ON" or "OFF")
        visibilityButton.BackgroundColor3 = State.visibilityEnabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
        for _, adornmentGroup in pairs(State.adornments) do
            adornmentGroup.box.Visible = State.visibilityEnabled
            adornmentGroup.billboard.Enabled = State.visibilityEnabled
        end
    end)

    -- Scan Now button
    scanNowButton.MouseButton1Click:Connect(function()
        startScan()
    end)

    -- Update Min Distance
    minDistanceInput.FocusLost:Connect(function()
        local newDistance = tonumber(minDistanceInput.Text)
        if newDistance and newDistance >= 0 then
            CONFIG.MIN_DISTANCE = newDistance
            minDistanceLabel.Text = "Min Distance: " .. CONFIG.MIN_DISTANCE
            startScan() -- Rescan with new distance
        else
            minDistanceInput.Text = ""
        end
    end)

    -- Update Max Distance
    maxDistanceInput.FocusLost:Connect(function()
        local newDistance = tonumber(maxDistanceInput.Text)
        if newDistance and newDistance >= 0 then
            CONFIG.MAX_DISTANCE = newDistance
            maxDistanceLabel.Text = "Max Distance: " .. CONFIG.MAX_DISTANCE
            startScan() -- Rescan with new distance
        else
            maxDistanceInput.Text = ""
        end
    end)

    -- Reset to Defaults
    resetButton.MouseButton1Click:Connect(function()
        CONFIG.MIN_DISTANCE = DEFAULT_CONFIG.MIN_DISTANCE
        CONFIG.MAX_DISTANCE = DEFAULT_CONFIG.MAX_DISTANCE
        minDistanceLabel.Text = "Min Distance: " .. CONFIG.MIN_DISTANCE
        maxDistanceLabel.Text = "Max Distance: " .. CONFIG.MAX_DISTANCE
        minDistanceInput.Text = ""
        maxDistanceInput.Text = ""
        startScan() -- Rescan with default distances
    end)

    -- Keybind Customization
    keybindInput.FocusLost:Connect(function()
        local key = keybindInput.Text
        local keyCode = Enum.KeyCode[key]
        if keyCode then
            CONFIG.TOGGLE_GUI_KEY = keyCode
            keybindLabel.Text = "Keybind: " .. tostring(CONFIG.TOGGLE_GUI_KEY)
            keybindInput.Text = ""
        else
            keybindInput.Text = ""
        end
    end)

    return screenGui, frame
end

-- Main initialization
local function init()
    if not workspace:FindFirstChild("Map") then
        warn("Map folder not found in workspace - ESP will not function")
        return
    end

    -- Create the GUI
    local gui, frame = createGUI()

    -- Toggle GUI visibility with F15
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if input.KeyCode == CONFIG.TOGGLE_GUI_KEY and not gameProcessed then
            State.guiVisible = not State.guiVisible
            frame.Visible = State.guiVisible
        end
    end)

    -- Handle player respawn
    player.CharacterAdded:Connect(function()
        -- Update player position when the character respawns
        updatePlayerPosition()
    end)

    workspace.Map.DescendantAdded:Connect(handleNewObject)
    workspace.Map.DescendantRemoving:Connect(cleanupAdornment)

    -- Continuously update distances for existing markers
    RunService.Heartbeat:Connect(function()
        updatePlayerPosition()
        for object, config in pairs(State.trackedObjects) do
            if object and object.Parent then
                local distance = getObjectDistance(object)
                if distance < CONFIG.MIN_DISTANCE or distance > CONFIG.MAX_DISTANCE then
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
print("Press F15 to open/close the GUI")
