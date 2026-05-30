local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local KEY = Enum.KeyCode.E
local MAX_DIST = 1200
local LOCK_FOV = 65
local CAM_OFFSET = Vector3.new(4, 1.5, 18)
local ICON = "rbxassetid://263401222"
local MAX_ANGLE = math.rad(80)

local locked = false
local target = nil
local cloneUI = nil
local humConn = nil
local tHumConn = nil
local unlockTween = nil
local oldAutoRotate = nil
local oldMouseLock = nil
local smoothCamPos = nil
local renderConn = nil

local char = Player.Character or Player.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid")
local root = char:WaitForChild("HumanoidRootPart")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LockOnGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = Player.PlayerGui

local btnSize = 80
local btn = Instance.new("ImageButton")
btn.Name = "LockButton"
btn.Size = UDim2.new(0, btnSize, 0, btnSize)
btn.Position = UDim2.new(1, -btnSize - 20, 1, -btnSize - 120)
btn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
btn.BackgroundTransparency = 0.2
btn.Image = ICON
btn.ImageColor3 = Color3.fromRGB(255, 255, 255)
btn.Parent = screenGui

Instance.new("UICorner", btn).CornerRadius = UDim.new(0.25, 0)

local btnStroke = Instance.new("UIStroke", btn)
btnStroke.Color = Color3.fromRGB(255, 255, 255)
btnStroke.Thickness = 2
btnStroke.Transparency = 0.1

local function refreshButton()
	local c = locked and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(255, 255, 255)
	TweenService:Create(btn, TweenInfo.new(0.12), {ImageColor3 = c}):Play()
	TweenService:Create(btnStroke, TweenInfo.new(0.12), {Color = c}):Play()
end

local function createIndicator(targetHead)
	if not targetHead then return end
	if cloneUI then cloneUI:Destroy() end

	local gui = Instance.new("BillboardGui")
	gui.Name = "LockIndicator"
	gui.Adornee = targetHead
	gui.Size = UDim2.new(0, 70, 0, 70)
	gui.StudsOffset = Vector3.new(0, 2.5, 0)
	gui.AlwaysOnTop = true
	gui.Parent = targetHead

	local glow = Instance.new("Frame", gui)
	glow.Name = "Glow"
	glow.Size = UDim2.new(1.2, 0, 1.2, 0)
	glow.Position = UDim2.new(-0.1, 0, -0.1, 0)
	glow.BackgroundTransparency = 1
	Instance.new("UICorner", glow).CornerRadius = UDim.new(1, 0)
	local glowStroke = Instance.new("UIStroke", glow)
	glowStroke.Color = Color3.fromRGB(255, 255, 255)
	glowStroke.Thickness = 3
	glowStroke.Transparency = 0.6

	local img = Instance.new("ImageLabel", gui)
	img.Name = "Icon"
	img.Size = UDim2.new(1, 0, 1, 0)
	img.BackgroundTransparency = 1
	img.Image = ICON
	img.ImageColor3 = Color3.fromRGB(255, 255, 255)

	cloneUI = gui
end

local function stopLock()
	if not locked and not unlockTween then return end
	if renderConn then renderConn:Disconnect(); renderConn = nil end
	if cloneUI then cloneUI:Destroy(); cloneUI = nil end
	if humConn then humConn:Disconnect(); humConn = nil end
	if tHumConn then tHumConn:Disconnect(); tHumConn = nil end
	if unlockTween then unlockTween:Cancel(); unlockTween = nil end
	if hum and oldAutoRotate ~= nil then
		hum.AutoRotate = oldAutoRotate
		oldAutoRotate = nil
	end
	if oldMouseLock ~= nil then
		Player.DevEnableMouseLock = oldMouseLock
		oldMouseLock = nil
	end
	locked = false
	target = nil
	smoothCamPos = nil
	refreshButton()

	local currentRoot = char and char:FindFirstChild("HumanoidRootPart")
	if currentRoot and currentRoot.Parent then
		local behind = CFrame.new(currentRoot.CFrame * Vector3.new(0, 3, 14), currentRoot.Position + Vector3.new(0, 2, 0))
		unlockTween = TweenService:Create(Camera, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = behind, FieldOfView = 70})
		local conn; conn = unlockTween.Completed:Connect(function()
			conn:Disconnect()
			unlockTween = nil
			Camera.CameraType = Enum.CameraType.Custom
		end)
		unlockTween:Play()
	else
		Camera.FieldOfView = 70
		Camera.CameraType = Enum.CameraType.Custom
	end
end

local function startLock(targetHead)
	if unlockTween then unlockTween:Cancel(); unlockTween = nil end

	target = targetHead
	locked = true
	smoothCamPos = Camera.CFrame.Position
	createIndicator(targetHead)
	refreshButton()

	local targetHum = targetHead.Parent:FindFirstChildOfClass("Humanoid")
	if targetHum then
		tHumConn = targetHum.Died:Connect(stopLock)
	end
	if hum then
		oldAutoRotate = hum.AutoRotate
		hum.AutoRotate = false
		humConn = hum.Died:Connect(stopLock)
	end

	oldMouseLock = Player.DevEnableMouseLock
	Player.DevEnableMouseLock = false

	Camera.CameraType = Enum.CameraType.Scriptable
	Camera.FieldOfView = LOCK_FOV

	renderConn = RunService.RenderStepped:Connect(function(dt)
		if not target or not target.Parent then stopLock(); return end
		if not char or not char.Parent then stopLock(); return end

		local currentRoot = char:FindFirstChild("HumanoidRootPart")
		local myHead = char:FindFirstChild("Head")
		if not currentRoot or not myHead then stopLock(); return end

		local targetPos = target.Position
		local rootPos = currentRoot.Position

		currentRoot.CFrame = CFrame.new(rootPos, Vector3.new(targetPos.X, rootPos.Y, targetPos.Z))

		local basePos = currentRoot.CFrame * Vector3.new(CAM_OFFSET.X, 0, CAM_OFFSET.Z)
		local goalPos = Vector3.new(basePos.X, myHead.Position.Y + CAM_OFFSET.Y, basePos.Z)

		local alpha = 1 - math.exp(-18 * dt)
		smoothCamPos = smoothCamPos:Lerp(goalPos, alpha)

		Camera.CFrame = CFrame.new(smoothCamPos, targetPos)
	end)
end

local function getBestTarget()
	local camPos = Camera.CFrame.Position
	local camLook = Camera.CFrame.LookVector
	local bestTarget = nil
	local bestScore = math.huge

	local function checkCharacter(model)
		if model == char then return end
		local head = model:FindFirstChild("Head")
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if not head or not humanoid or humanoid.Health <= 0 then return end

		local pos = head.Position
		local dist = (pos - camPos).Magnitude
		if dist > MAX_DIST then return end

		local dir = (pos - camPos).Unit
		local angle = math.acos(math.clamp(camLook:Dot(dir), -1, 1))
		if angle > MAX_ANGLE then return end

		local score = dist * 0.3 + (angle * 80)

		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.IgnoreWater = true
		rayParams.FilterDescendantsInstances = {char}
		local result = workspace:Raycast(camPos, pos - camPos, rayParams)
		if not result or result.Instance:IsDescendantOf(model) then
			if score < bestScore then
				bestScore = score
				bestTarget = head
			end
		end
	end

	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= Player and plr.Character then
			checkCharacter(plr.Character)
		end
	end

	local charsFolder = workspace:FindFirstChild("Characters")
	if charsFolder then
		for _, model in ipairs(charsFolder:GetChildren()) do
			if model:IsA("Model") then
				checkCharacter(model)
			end
		end
	end

	return bestTarget
end

local function tryLock()
	if locked then stopLock(); return end

	local targetHead = getBestTarget()
	if not targetHead then return end

	startLock(targetHead)
end

ContextActionService:BindAction("LockOn", function(_, inputState)
	if inputState ~= Enum.UserInputState.Begin then return end
	tryLock()
end, false, KEY)

btn.Activated:Connect(tryLock)

btn.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		TweenService:Create(btn, TweenInfo.new(0.1), {Size = UDim2.new(0, btnSize * 0.9, 0, btnSize * 0.9)}):Play()
	end
end)

btn.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		TweenService:Create(btn, TweenInfo.new(0.1), {Size = UDim2.new(0, btnSize, 0, btnSize)}):Play()
	end
end)

Player.CharacterAdded:Connect(function(c)
	char = c
	hum = c:WaitForChild("Humanoid")
	root = c:WaitForChild("HumanoidRootPart")
	stopLock()
end)

Player.CharacterRemoving:Connect(function()
	stopLock()
end)
