local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local KEY = Enum.KeyCode.T
local MAX_DIST = 1200
local LOCK_FOV = 75
local CAM_OFFSET = Vector3.new(3, 1, 22)
local ICON = "rbxassetid://263401222"
local MAX_ANGLE = math.rad(80)

local locked = false
local target = nil
local cloneUI = nil
local humConn = nil
local tHumConn = nil
local unlockTween = nil
local fovTween = nil
local oldAutoRotate = nil
local oldMouseLock = nil
local oldRotationType = nil
local oldFOV = nil
local smoothCamPos = nil
local smoothLookDir = nil
local renderConn = nil
local rotConn = nil

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

local function cleanupConnections()
	if renderConn then renderConn:Disconnect(); renderConn = nil end
	if rotConn then rotConn:Disconnect(); rotConn = nil end
	if humConn then humConn:Disconnect(); humConn = nil end
	if tHumConn then tHumConn:Disconnect(); tHumConn = nil end
	if fovTween then fovTween:Cancel(); fovTween = nil end
end

local function stopLock()
	if not locked and not unlockTween then return end

	cleanupConnections()

	if cloneUI then cloneUI:Destroy(); cloneUI = nil end
	if unlockTween then unlockTween:Cancel(); unlockTween = nil end

	if hum and oldAutoRotate ~= nil then
		hum.AutoRotate = oldAutoRotate
		oldAutoRotate = nil
	end
	if oldMouseLock ~= nil then
		Player.DevEnableMouseLock = oldMouseLock
		oldMouseLock = nil
	end
	if oldRotationType ~= nil then
		UserGameSettings.RotationType = oldRotationType
		oldRotationType = nil
	end

	local restoreFOV = oldFOV or 70
	oldFOV = nil

	locked = false
	target = nil
	smoothCamPos = nil
	smoothLookDir = nil
	refreshButton()

	local currentRoot = char and char:FindFirstChild("HumanoidRootPart")
	if currentRoot and currentRoot.Parent then
		local behindCF = currentRoot.CFrame * CFrame.new(0, 3, 14)
		local lookAt = currentRoot.Position + Vector3.new(0, 2, 0)
		unlockTween = TweenService:Create(Camera, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(behindCF.Position, lookAt),
			FieldOfView = restoreFOV
		})
		local conn; conn = unlockTween.Completed:Connect(function()
			conn:Disconnect()
			unlockTween = nil
			Camera.CameraType = Enum.CameraType.Custom
		end)
		unlockTween:Play()
	else
		Camera.FieldOfView = restoreFOV
		Camera.CameraType = Enum.CameraType.Custom
	end
end

local function startLock(targetHead)
	cleanupConnections()
	if unlockTween then unlockTween:Cancel(); unlockTween = nil end

	target = targetHead
	locked = true
	smoothCamPos = Camera.CFrame.Position
	oldFOV = Camera.FieldOfView

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

	oldRotationType = UserGameSettings.RotationType
	UserGameSettings.RotationType = Enum.RotationType.MovementRelative

	Camera.CameraType = Enum.CameraType.Scriptable

	fovTween = TweenService:Create(Camera, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = LOCK_FOV})
	fovTween:Play()

	local initRoot = char and char:FindFirstChild("HumanoidRootPart")
	if initRoot then
		local lv = initRoot.CFrame.LookVector
		local flat = Vector3.new(lv.X, 0, lv.Z)
		smoothLookDir = flat.Magnitude > 0.001 and flat.Unit or Vector3.new(0, 0, -1)
	else
		smoothLookDir = Vector3.new(0, 0, -1)
	end

	rotConn = RunService.Heartbeat:Connect(function(dt)
		if not locked or not target or not target.Parent then return end
		local currentRoot = char and char:FindFirstChild("HumanoidRootPart")
		if not currentRoot or not smoothLookDir then return end

		local targetPos = target.Position
		local rootPos = currentRoot.Position
		local targetDir = Vector3.new(targetPos.X - rootPos.X, 0, targetPos.Z - rootPos.Z)
		if targetDir.Magnitude <= 0.001 then return end

		targetDir = targetDir.Unit
		local newDir = smoothLookDir:Lerp(targetDir, 1 - math.exp(-15 * dt))
		smoothLookDir = newDir.Magnitude > 0.001 and newDir.Unit or targetDir
		currentRoot.CFrame = CFrame.new(rootPos, rootPos + smoothLookDir)
	end)

	renderConn = RunService.RenderStepped:Connect(function(dt)
		if not locked then return end
		if not target or not target.Parent then stopLock(); return end
		if not char or not char.Parent then stopLock(); return end

		local currentRoot = char:FindFirstChild("HumanoidRootPart")
		if not currentRoot or not smoothCamPos then stopLock(); return end

		local rootPos = currentRoot.Position
		local targetPos = target.Position

		local basePos = currentRoot.CFrame * Vector3.new(CAM_OFFSET.X, 0, CAM_OFFSET.Z)
		local stableY = rootPos.Y + hum.HipHeight + CAM_OFFSET.Y

		local xzAlpha = 1 - math.exp(-10 * dt)
		local yAlpha = 1 - math.exp(-6 * dt)

		smoothCamPos = Vector3.new(
			smoothCamPos.X + (basePos.X - smoothCamPos.X) * xzAlpha,
			smoothCamPos.Y + (stableY   - smoothCamPos.Y) * yAlpha,
			smoothCamPos.Z + (basePos.Z - smoothCamPos.Z) * xzAlpha
		)

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
	cleanupConnections()
	if unlockTween then unlockTween:Cancel(); unlockTween = nil end
	if fovTween then fovTween:Cancel(); fovTween = nil end
	if cloneUI then cloneUI:Destroy(); cloneUI = nil end

	if oldRotationType ~= nil then
		UserGameSettings.RotationType = oldRotationType
		oldRotationType = nil
	end
	if oldMouseLock ~= nil then
		Player.DevEnableMouseLock = oldMouseLock
		oldMouseLock = nil
	end
	oldAutoRotate = nil

	Camera.FieldOfView = oldFOV or 70
	oldFOV = nil
	Camera.CameraType = Enum.CameraType.Custom

	locked = false
	target = nil
	smoothCamPos = nil
	smoothLookDir = nil

	char = c
	hum = c:WaitForChild("Humanoid")
	root = c:WaitForChild("HumanoidRootPart")
	refreshButton()
end)

Player.CharacterRemoving:Connect(function()
	stopLock()
end)
