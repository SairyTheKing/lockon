local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local LockonEnabled = false
local LockedTarget = nil
local TargetGui = nil

local function notify(message)
    NotificationLibrary:SendNotification("Info", message, 3)
end

local function createTargetGui(character)
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "TargetOverlay"
    billboard.Adornee = root
    billboard.Size = UDim2.new(0, 200, 0, 300) 
    billboard.StudsOffset = Vector3.new(0, 0, 0)
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    billboard.MaxDistance = 10000
    billboard.Parent = root

    local image = Instance.new("ImageLabel")
    image.Size = UDim2.new(1, 0, 1, 0)
    image.BackgroundTransparency = 1
    image.Image = "rbxassetid://263401222"
    image.ImageTransparency = 0.2
    image.Parent = billboard

    TargetGui = billboard
end

local function removeTargetGui()
    if TargetGui then
        TargetGui:Destroy()
        TargetGui = nil
    end
end

local function getClosestPlayer()
    local closestPlayer = nil
    local shortestDistance = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Head") then
            local headPos = player.Character.Head.Position
            local screenPos, onScreen = Camera:WorldToViewportPoint(headPos)

            if onScreen then
                local dist = (Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)).Magnitude
                if dist < shortestDistance then
                    shortestDistance = dist
                    closestPlayer = player
                end
            end
        end
    end

    return closestPlayer
end

RunService.RenderStepped:Connect(function()
    if LockonEnabled and LockedTarget and LockedTarget.Character then
        local char = LockedTarget.Character
        local head = char:FindFirstChild("Head")
        local root = char:FindFirstChild("HumanoidRootPart")

        if head and root then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, head.Position)

            if TargetGui then
                local distance = (Camera.CFrame.Position - root.Position).Magnitude
                local scale = math.clamp(1 / (distance / 25), 0.3, 1) -- scale factor
                local width = 150 * scale
                local height = 150 * scale
                TargetGui.Size = UDim2.new(0, width, 0, height)
            end
        end
    end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == Enum.KeyCode.J then
        LockonEnabled = not LockonEnabled
        notify("Lockon " .. (LockonEnabled and "Enabled" or "Disabled"))

        if not LockonEnabled and LockedTarget then
            notify("Lockon target unlocked")
            LockedTarget = nil
            removeTargetGui()
        end
    end

    if input.UserInputType == Enum.UserInputType.MouseButton2 and LockonEnabled then
        if LockedTarget then
            notify("Unlocked from " .. LockedTarget.Name)
            LockedTarget = nil
            removeTargetGui()
        else
            local target = getClosestPlayer()
            if target then
                LockedTarget = target
                notify("You have locked onto " .. target.Name)
                createTargetGui(target.Character)
            else
                notify("No valid target to lock onto")
            end
        end
    end
end)
