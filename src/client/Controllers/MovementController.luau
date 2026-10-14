--!strict
-- MovementController: Sprint, Dash con estela de Aura, Doble Salto y Colocación de Puentes Skywars
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("OverchargedShared")
local SoundUtil = require(Shared.Utils.SoundUtil)

local localPlayer = Players.LocalPlayer
local CameraController = require(script.Parent.CameraController)

local MovementController = {}

local IsSprinting = false
local BaseWalkSpeed = 16
local SprintWalkSpeed = 26

local LastDashTime = 0
local DashCooldown = 1.4
local CanDoubleJump = false
local HasDoubleJumped = false

-- Crea estela de partículas de Dash en los pies
local function SpawnDashTrail(root: BasePart)
    local p = Instance.new("Part")
    p.Size = Vector3.new(2, 0.2, 4)
    p.CFrame = root.CFrame * CFrame.new(0, -2, -1)
    p.Material = Enum.Material.Neon
    p.Color = Color3.fromRGB(0, 210, 255)
    p.Transparency = 0.3
    p.Anchored = true
    p.CanCollide = false
    p.Parent = Workspace

    TweenService:Create(p, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.1, 0.1, 8),
        Transparency = 1,
    }):Play()

    task.delay(0.35, function()
        if p and p.Parent then p:Destroy() end
    end)
end

-- Referencias de interfaz de Dash Cooldown
local DashGui: ScreenGui?
local DashFill: Frame?
local DashLabel: TextLabel?
local DashGlow: UIStroke?

local function CreateDashCooldownUI()
    if DashGui then return end
    local playerGui = localPlayer:WaitForChild("PlayerGui")
    DashGui = Instance.new("ScreenGui")
    DashGui.Name = "DashCooldownHUD"
    DashGui.ResetOnSpawn = false
    DashGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    DashGui.Parent = playerGui

    local container = Instance.new("Frame")
    container.Name = "DashContainer"
    container.Size = UDim2.fromOffset(130, 28)
    container.Position = UDim2.new(0.5, -65, 1, -70)
    container.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
    container.BackgroundTransparency = 0.2
    container.Parent = DashGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = container

    DashGlow = Instance.new("UIStroke")
    DashGlow.Thickness = 1.5
    DashGlow.Color = Color3.fromRGB(0, 210, 255)
    DashGlow.Parent = container

    DashFill = Instance.new("Frame")
    DashFill.Name = "Fill"
    DashFill.Size = UDim2.fromScale(1, 1)
    DashFill.BackgroundColor3 = Color3.fromRGB(0, 180, 240)
    DashFill.BackgroundTransparency = 0.4
    DashFill.BorderSizePixel = 0
    DashFill.Parent = container

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 8)
    fillCorner.Parent = DashFill

    DashLabel = Instance.new("TextLabel")
    DashLabel.Size = UDim2.fromScale(1, 1)
    DashLabel.BackgroundTransparency = 1
    DashLabel.Font = Enum.Font.FredokaOne
    DashLabel.Text = "⚡ DASH [Q]"
    DashLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    DashLabel.TextSize = 13
    DashLabel.ZIndex = 5
    DashLabel.Parent = container

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1.5
    stroke.Color = Color3.fromRGB(0, 0, 0)
    stroke.Parent = DashLabel
end

-- Ejecuta el Dash de evasión con estela de energía y cooldown visual
function MovementController.PerformDash()
    local char = localPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.Health <= 0 then return end

    local now = os.clock()
    if (now - LastDashTime) < DashCooldown then return end
    LastDashTime = now

    -- Animar barra de recarga en pantalla
    if DashFill and DashGlow then
        DashFill.Size = UDim2.fromScale(0, 1)
        DashGlow.Color = Color3.fromRGB(80, 90, 110)
        TweenService:Create(DashFill, TweenInfo.new(DashCooldown, Enum.EasingStyle.Linear), {
            Size = UDim2.fromScale(1, 1)
        }):Play()
        task.delay(DashCooldown, function()
            if DashGlow then
                DashGlow.Color = Color3.fromRGB(0, 230, 255)
                TweenService:Create(DashGlow, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    Thickness = 3
                }):Play()
                task.delay(0.25, function()
                    if DashGlow then
                        TweenService:Create(DashGlow, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                            Thickness = 1.5
                        }):Play()
                    end
                end)
            end
        end)
    end

    -- Dirección del dash según hacia dónde se mueve el jugador o mira
    local moveDir = hum.MoveDirection
    if moveDir.Magnitude < 0.1 then
        moveDir = root.CFrame.LookVector
    end

    -- Impulso físico parabólico mediante AssemblyLinearVelocity
    root.AssemblyLinearVelocity = (moveDir.Unit * 68) + Vector3.new(0, 14, 0)

    -- Efectos visuales, sacudida y sonido
    SpawnDashTrail(root)
    SoundUtil.Play2D(SoundUtil.SOUNDS.DASH, 0.75, true)
    CameraController.Shake(0.75, 0.22, 28)
    CameraController.SetTargetFOV(88, 0.15)

    task.delay(0.25, function()
        if IsSprinting then
            CameraController.SetTargetFOV(82, 0.25)
        else
            CameraController.SetTargetFOV(70, 0.25)
        end
    end)
end

-- Alterna o activa el Sprint
function MovementController.SetSprinting(active: boolean)
    IsSprinting = active
    local char = localPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        local currentBase = hum:GetAttribute("BaseWalkSpeed")
        if typeof(currentBase) ~= "number" then
            hum:SetAttribute("BaseWalkSpeed", hum.WalkSpeed)
            currentBase = hum.WalkSpeed
        end
        hum.WalkSpeed = active and (currentBase + 10) or currentBase
    end

    if active then
        CameraController.SetTargetFOV(84, 0.25)
    else
        CameraController.SetTargetFOV(70, 0.25)
    end
end

-- Coloca un bloque de puente Skywars en el aire frente al jugador
function MovementController.PlaceBridgeBlock()
    local char = localPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not root then return end

    local look = root.CFrame.LookVector
    local targetPos = root.Position + (look * 5.5) + Vector3.new(0, -2.8, 0)
    -- Ajustar a grilla redondeada de 4 studs
    targetPos = Vector3.new(
        math.floor(targetPos.X / 4 + 0.5) * 4,
        math.floor(targetPos.Y / 2 + 0.5) * 2,
        math.floor(targetPos.Z / 4 + 0.5) * 4
    )

    -- Solicitar al servidor la colocación
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local reqPlace = remotes and remotes:FindFirstChild("RequestPlaceBridgeBlock") :: RemoteEvent?
    if reqPlace then
        reqPlace:FireServer(targetPos)
    end

    -- Efecto anticipado en cliente (Pop-in con Back Easing y sonido con pitch variado)
    local block = Instance.new("Part")
    block.Name = "BridgeBlockClient"
    block.Size = Vector3.zero
    block.Position = targetPos
    block.Material = Enum.Material.Metal
    block.Color = Color3.fromRGB(36, 44, 62)
    block.Anchored = true
    block.CanCollide = true
    block.Parent = Workspace

    TweenService:Create(block, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = Vector3.new(4, 1.4, 4),
    }):Play()

    SoundUtil.Play3D(SoundUtil.SOUNDS.PLACE_BLOCK, block, 0.65)
end

-- Inicializa las entradas de movimiento (PC, Móvil, Consola)
function MovementController.Initialize()
    CreateDashCooldownUI()

    -- Salto y Doble Salto
    UserInputService.JumpRequest:Connect(function()
        local char = localPlayer.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not root or not hum or hum.Health <= 0 then return end

        local state = hum:GetState()
        if (state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping) and CanDoubleJump and not HasDoubleJumped then
            HasDoubleJumped = true
            CanDoubleJump = false

            -- Impulso vertical del segundo salto
            root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 52, root.AssemblyLinearVelocity.Z)

            -- Anillo de choque y sonido en los pies
            local ring = Instance.new("Part")
            ring.Shape = Enum.PartType.Cylinder
            ring.Size = Vector3.new(0.2, 1, 1)
            ring.CFrame = root.CFrame * CFrame.new(0, -2.5, 0) * CFrame.Angles(0, 0, math.pi/2)
            ring.Material = Enum.Material.Neon
            ring.Color = Color3.fromRGB(0, 210, 255)
            ring.Anchored = true
            ring.CanCollide = false
            ring.Parent = Workspace

            TweenService:Create(ring, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = Vector3.new(0.05, 8, 8),
                Transparency = 1,
            }):Play()

            SoundUtil.Play2D(SoundUtil.SOUNDS.DASH, 0.55, true)
            task.delay(0.3, function() if ring and ring.Parent then ring:Destroy() end end)
        end
    end)

    -- Resetear estado de salto al tocar tierra
    local function ConnectCharacter(char: Model)
        local hum = char:WaitForChild("Humanoid", 5) :: Humanoid?
        if hum then
            hum.StateChanged:Connect(function(_, newState)
                if newState == Enum.HumanoidStateType.Landed then
                    CanDoubleJump = false
                    HasDoubleJumped = false
                elseif newState == Enum.HumanoidStateType.Freefall then
                    task.delay(0.12, function()
                        if not HasDoubleJumped then
                            CanDoubleJump = true
                        end
                    end)
                end
            end)
        end
    end

    if localPlayer.Character then ConnectCharacter(localPlayer.Character) end
    localPlayer.CharacterAdded:Connect(ConnectCharacter)

    -- Mapeo de teclas
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end

        if input.KeyCode == Enum.KeyCode.LeftShift then
            MovementController.SetSprinting(true)
        elseif input.KeyCode == Enum.KeyCode.Q then
            MovementController.PerformDash()
        elseif input.KeyCode == Enum.KeyCode.B then
            MovementController.PlaceBridgeBlock()
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.LeftShift then
            MovementController.SetSprinting(false)
        end
    end)
end

return MovementController
