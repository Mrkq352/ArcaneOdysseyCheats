-- ESP Script
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
    MAX_DISTANCE = 1000,
    BATCH_SIZE = 100,  -- Number of objects to process per batch
    BATCH_DELAY = 0.03,  -- Delay between batches in seconds
    TOGGLE_KEY = Enum.KeyCode.F15,
    COLORS = {
        FRUIT = Color3.fromRGB(0, 255, 0),
        GOLDEN = Color3.fromRGB(255, 223, 0),
        HERB = Color3.fromRGB(0, 255, 0),
        TREASURE_CHEST = Color3.fromRGB(139, 69, 19),
        SILVER_CHEST = Color3.fromRGB(176, 224, 230),
        GOLDEN_CHEST = Color3.fromRGB(255, 223, 0),
        BRONZE_SEALED_CHEST = Color3.fromRGB(212,169,107),  -- Bronze color
        NIMBUS_SEALED_CHEST = Color3.fromRGB(135, 206, 235), -- Light blue color
        DARK_SEALED_CHEST = Color3.fromRGB(75, 0, 130) --Dark sea chest color
    }
}

-- State initialization
local State = {
    adornments = {},
    playerGui = player:WaitForChild("PlayerGui"),
    trackedObjects = {},
    playerPosition = Vector3.new(0, 0, 0),
    scanInProgress = false,
    scanQueue = {},
    lastScanTime = 0,
    scanInterval = 1  -- Scan every 1 second
}

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
        -- If the object is a model, try to get its primary part or first child that's a BasePart
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

local function createNotification(message)
    if not State.playerGui then return end
    
    local screenGui = Instance.new("ScreenGui")
    local notification = Instance.new("TextLabel")
    
    notification.Size = UDim2.new(0, 300, 0, 50)
    notification.Position = UDim2.new(0.5, -150, 0.1, 0)
    notification.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    notification.BackgroundTransparency = 0.5
    notification.Text = message
    notification.TextColor3 = Color3.fromRGB(255, 255, 255)
    notification.TextScaled = true
    notification.Parent = screenGui
    screenGui.Parent = State.playerGui

    task.delay(1, function()
        notification.TextTransparency = 1
        task.wait(0.5)
        screenGui:Destroy()
    end)
end

local function getItemName(object)
    local prompt = object:FindFirstChild("ProximityPrompt")
    
    if not prompt then
        for _, child in ipairs(object:GetChildren()) do
            if child:IsA("ProximityPrompt") then
                prompt = child
                break
            end
        end
    end
    
    if not prompt and object.Parent then
        prompt = object.Parent:FindFirstChild("ProximityPrompt")
    end
    
    if prompt then
        return prompt.ObjectText ~= "" and prompt.ObjectText or prompt.ActionText
    end
    
    if object.Parent and object.Parent.Name:lower():match("chest") then
        return object.Parent.Name
    end
    
    return object.Name
end
local function shouldTrackObject(object)
    if not (object:IsA("BasePart") or object:IsA("Model")) then return false end
    
    -- Check distance first to avoid unnecessary processing
    local distance = getObjectDistance(object)
    if distance > CONFIG.MAX_DISTANCE then return false end
    
    local objectName = object.Name:lower()
    local parent = object.Parent
    local parentName = parent and parent.Name:lower() or ""
    
    if objectName:match("herbspawn") or objectName:match("fruitspawn") then
        return false
    end
    
    if objectName:match("^%w+ chest$") or parentName:match("^%w+ chest$") then
        if parent then
            return parent:FindFirstChild("ProximityPrompt") ~= nil or
                   parent:FindFirstChild("Base") ~= nil
        end
    end
    
    return objectName:match("^fruit$") or
           objectName:match("^herb$")
end

local function isObjectOpened(object)
    return object:FindFirstChild("Open") ~= nil
end

local function createVisualElements(object, color, label)
    if not CONFIG.ENABLED then return end
    if not object or not object.Parent then return end
    
    local distance = getObjectDistance(object)
    if distance > CONFIG.MAX_DISTANCE then
        cleanupAdornment(object)
        return
    end

    local existing = State.adornments[object]
    if existing and existing.box and existing.box.Parent and existing.billboard and existing.billboard.Parent then
        existing.billboard.Enabled = CONFIG.ENABLED
        existing.box.Visible = CONFIG.ENABLED
        
        -- Update distance in existing billboard
        local textLabel = existing.billboard:FindFirstChild("TextLabel")
        if textLabel then
            textLabel.Text = string.format("%s\n%.1fm", label, distance)
        end
        return
    end

    cleanupAdornment(object)

    local boxAdornment = Instance.new("BoxHandleAdornment")
    boxAdornment.Adornee = object
    boxAdornment.Size = (object:IsA("BasePart") and object.Size or Vector3.new(2, 2, 2)) + Vector3.new(0.1, 0.1, 0.1)
    boxAdornment.Color3 = color
    boxAdornment.Transparency = 0.3
    boxAdornment.AlwaysOnTop = true
    boxAdornment.ZIndex = 5
    boxAdornment.Visible = CONFIG.ENABLED
    boxAdornment.Parent = object

    local billboard = Instance.new("BillboardGui")
    billboard.Adornee = object
    billboard.Size = UDim2.new(0, 100, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Enabled = CONFIG.ENABLED
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = string.format("%s\n%.1fm", label, distance)
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
    if isObjectOpened(object) then return end

    local objectName = object.Name:lower()
    local parent = object.Parent
    local parentName = parent and parent.Name:lower() or ""
    local isGolden = object:FindFirstChild("Golden") ~= nil
    local itemName = getItemName(object)

    local visualConfig

    -- Check for sealed chests first
    if parent and parent.Name == "Temporary" then
        if objectName:match("bronze sealed chest") then
            visualConfig = {
                color = CONFIG.COLORS.BRONZE_SEALED_CHEST,
                label = itemName
            }
        elseif objectName:match("nimbus sealed chest") then
            visualConfig = {
                color = CONFIG.COLORS.NIMBUS_SEALED_CHEST,
                label = itemName
            }
        elseif objectName:match("dark sealed chest") then
            visualConfig = {
                color = CONFIG.COLORS.DARK_SEALED_CHEST,
                label = itemName
            }
        end
    elseif objectName:match("^treasure") or parentName:match("^treasure") then
        local chestType = "Treasure Chest"
        local color = CONFIG.COLORS.TREASURE_CHEST
        
        if objectName:match("silver") or parentName:match("silver") then
            chestType = "Silver Chest"
            color = CONFIG.COLORS.SILVER_CHEST
        elseif objectName:match("golden") or parentName:match("golden") then
            chestType = "Golden Chest"
            color = CONFIG.COLORS.GOLDEN_CHEST
        end
        
        visualConfig = {color = color, label = chestType}
    else
        if objectName:match("fruit") then
            visualConfig = {
                color = isGolden and CONFIG.COLORS.GOLDEN or CONFIG.COLORS.FRUIT,
                label = itemName
            }
        elseif objectName:match("herb") then
            visualConfig = {
                color = isGolden and CONFIG.COLORS.GOLDEN or CONFIG.COLORS.HERB,
                label = itemName
            }
        end
    end

    if visualConfig then
        State.trackedObjects[object] = visualConfig
        createVisualElements(object, visualConfig.color, visualConfig.label)
    end
end

local function processBatch(objects, startIndex)
    if not CONFIG.ENABLED then return end
    
    local endIndex = math.min(startIndex + CONFIG.BATCH_SIZE, #objects)
    
    for i = startIndex, endIndex do
        local object = objects[i]
        if object and object.Parent then
            handleNewObject(object)
        end
    end
    
    if endIndex < #objects then
        -- Schedule next batch
        task.wait(CONFIG.BATCH_DELAY)
        processBatch(objects, endIndex + 1)
    else
        State.scanInProgress = false
    end
end

local function startScan()
    if State.scanInProgress then return end

    local currentTime = tick()
    if currentTime - State.lastScanTime < State.scanInterval then return end
    State.lastScanTime = currentTime

    State.scanInProgress = true
    local objectsToScan = {}

    -- Ensure workspace.Map exists before scanning
    local map = workspace:FindFirstChild("Map")
    if not map then 
        State.scanInProgress = false
        return 
    end

    -- Scan all existing objects inside workspace.Map
    for _, object in ipairs(map:GetDescendants()) do
        if shouldTrackObject(object) then
            table.insert(objectsToScan, object)
        end
    end

    -- Ensure Temporary folder inside Map is scanned
    local temporary = map:FindFirstChild("Temporary")
    if temporary then
        for _, object in ipairs(temporary:GetChildren()) do
            if shouldTrackObject(object) then
                table.insert(objectsToScan, object)
            end
        end
    end

    -- Process all found objects
    if #objectsToScan > 0 then
        processBatch(objectsToScan, 1)
    else
        State.scanInProgress = false
    end
end


local function toggleESP()
    CONFIG.ENABLED = not CONFIG.ENABLED
    createNotification(CONFIG.ENABLED and "ESP Enabled" or "ESP Disabled")
    
    if CONFIG.ENABLED then
        -- Clear any old ESP remnants before rescanning
        for object in pairs(State.adornments) do
            cleanupAdornment(object)
        end
        State.trackedObjects = {}

        -- Run a full scan to detect all objects, even old ones
        startScan()  -- This will initiate the full scan when ESP is enabled
    else
        -- Clear ESP when disabling
        for object in pairs(State.adornments) do
            cleanupAdornment(object)
        end
        State.trackedObjects = {}
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
        end
    end)

    workspace.Map.DescendantAdded:Connect(handleNewObject)
    workspace.Map.DescendantRemoving:Connect(cleanupAdornment)

    -- Timer-based scanning
   spawn(function()
    while true do
        if CONFIG.ENABLED then
            startScan()
            updatePlayerPosition()
            
            -- Update existing ESP
            local existingObjects = {}
            for object, config in pairs(State.trackedObjects) do
                table.insert(existingObjects, {object = object, config = config})
            end
            
            -- Process existing objects in batches too
            for i = 1, #existingObjects, CONFIG.BATCH_SIZE do
                local endIndex = math.min(i + CONFIG.BATCH_SIZE - 1, #existingObjects)
                for j = i, endIndex do
                    local data = existingObjects[j]
                    if data.object and data.object.Parent then
                        createVisualElements(data.object, data.config.color, data.config.label)
                    else
                        cleanupAdornment(data.object)
                    end
                end
                task.wait(CONFIG.BATCH_DELAY)
            end
        end
        wait(1.5)  -- Increased main loop interval to 1.5 seconds
    end
    end)
end

-- Start the ESP system
init()
print("ESP Script loaded successfully")
print("Press F15 to toggle ESP")
