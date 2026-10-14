--!strict
-- ClientInit: Punto de entrada principal en el cliente (Montaje instantáneo y asíncrono)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local UIController = require(script.Parent.Controllers.UIController)
local CameraController = require(script.Parent.Controllers.CameraController)
local MovementController = require(script.Parent.Controllers.MovementController)

-- 1. Montar inmediatamente la interfaz de usuario, cámara procedural y control de movimiento
UIController.InitializeUI()
CameraController.Initialize()
MovementController.Initialize()

-- 2. Animación de golpe en cliente (combo de 3 tajos dinámicos: hombro, torso y paso fluido)
local TweenService = game:GetService("TweenService")

local COMBO_SHOULDER_ANGLES = {
    CFrame.Angles(math.rad(105), math.rad(-45), math.rad(25)), -- Tajo horizontal derecha a izquierda
    CFrame.Angles(math.rad(75), math.rad(50), math.rad(-30)),  -- Tajo ascendente diagonal
    CFrame.Angles(math.rad(125), 0, math.rad(-10)),            -- Golpe de gracia descendente
}
local COMBO_ROOT_ANGLES = {
    CFrame.Angles(0, math.rad(-16), 0),                        -- Torsión de torso a la izquierda
    CFrame.Angles(0, math.rad(16), 0),                         -- Torsión de torso a la derecha
    CFrame.Angles(math.rad(-10), 0, 0),                        -- Inclinación de torso al frente
}

local comboIndex = 0
local lastSwing = 0
local isSwinging = false

local origShoulderC0: CFrame? = nil
local origRootC0: CFrame? = nil
local activeJoint: Motor6D? = nil
local activeRootJoint: Motor6D? = nil
local hookedTools: { [Tool]: boolean } = {}

-- Inicializa y cachea las articulaciones neutrales del personaje para evitar deformaciones
local function SetupCharacterJoints(char: Model)
    origShoulderC0 = nil
    origRootC0 = nil
    activeJoint = nil
    activeRootJoint = nil

    for _, desc in ipairs(char:GetDescendants()) do
        if desc:IsA("Motor6D") then
            if (desc.Name == "RightShoulder" or desc.Name == "Right Shoulder") or 
               (desc.Part1 and (desc.Part1.Name == "RightUpperArm" or desc.Part1.Name == "Right Arm")) then
                activeJoint = desc
                origShoulderC0 = desc.C0
            elseif desc.Name == "Root" or desc.Name == "RootJoint" or (desc.Part0 and desc.Part0.Name == "HumanoidRootPart") then
                activeRootJoint = desc
                origRootC0 = desc.C0
            end
        end
    end
end

local function PlaySwing(): boolean
    local now = os.clock()
    if isSwinging or (now - lastSwing < 0.24) then return false end
    comboIndex = (now - lastSwing > 0.85) and 1 or ((comboIndex % 3) + 1)
    lastSwing = now
    isSwinging = true

    local player = game.Players.LocalPlayer
    local char = player.Character
    if not char then
        isSwinging = false
        return true
    end

    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?

    -- 1. Sonido de golpe con variación de pitch por combo
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://9114223171"
    sound.Volume = 0.75
    sound.PlaybackSpeed = 1.0 + (comboIndex * 0.1)
    sound.Parent = hrp or char
    sound:Play()
    game:GetService("Debris"):AddItem(sound, 1.5)

    -- 2. Sacudida sutil de cámara
    if comboIndex == 3 then
        CameraController.Shake(0.55, 0.18, 32)
    else
        CameraController.Shake(0.3, 0.12, 25)
    end

    -- 3. Movimiento del personaje y paso marcial fluido (conserva dirección de carrera con ApplyImpulse)
    if hrp and hum and hum.Health > 0 then
        local moveDir = hum.MoveDirection
        local pushDir = moveDir.Magnitude > 0.1 and moveDir.Unit or hrp.CFrame.LookVector
        local pushImpulse = comboIndex == 3 and 24 or 14
        hrp:ApplyImpulse(pushDir * (pushImpulse * hrp.AssemblyMass * 0.15))
    end

    -- 4. Reproducir animación nativa de Roblox en Animator (R15 y R6)
    if hum and hum.Health > 0 then
        local animator = hum:FindFirstChildOfClass("Animator")
        if not animator then
            animator = Instance.new("Animator")
            animator.Parent = hum
        end
        if animator then
            local isR15 = hum.RigType == Enum.RigType.R15
            local animId = isR15
                and (comboIndex == 3 and "rbxassetid://522638767" or "rbxassetid://522635560")
                or (comboIndex == 3 and "rbxassetid://129967478" or "rbxassetid://129967390")

            pcall(function()
                local anim = Instance.new("Animation")
                anim.AnimationId = animId
                local track = animator:LoadAnimation(anim)
                track.Priority = Enum.AnimationPriority.Action
                track:Play(0.05, 1, 1.35)
            end)
        end
    end

    -- 5. Animación procedural fluida de hombro y torso
    if activeJoint and origShoulderC0 then
        local targetC0 = origShoulderC0 * COMBO_SHOULDER_ANGLES[comboIndex]
        TweenService:Create(activeJoint, TweenInfo.new(0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            C0 = targetC0,
        }):Play()
    end
    if activeRootJoint and origRootC0 then
        local targetRootC0 = origRootC0 * COMBO_ROOT_ANGLES[comboIndex]
        TweenService:Create(activeRootJoint, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            C0 = targetRootC0,
        }):Play()
    end

    -- Retorno suave a la pose neutral
    task.delay(0.14, function()
        if activeJoint and origShoulderC0 then
            TweenService:Create(activeJoint, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                C0 = origShoulderC0,
            }):Play()
        end
        if activeRootJoint and origRootC0 then
            TweenService:Create(activeRootJoint, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                C0 = origRootC0,
            }):Play()
        end
        task.wait(0.1)
        isSwinging = false
    end)

    return true
end

-- Conecta la activación del arma directamente en el cliente
local function HookTool(tool: Tool)
    if hookedTools[tool] then return end
    hookedTools[tool] = true

    tool.Activated:Connect(function()
        if PlaySwing() then
            local remotes = ReplicatedStorage:FindFirstChild("Remotes")
            local reqAttack = remotes and remotes:FindFirstChild("RequestAttack") :: RemoteEvent?
            if reqAttack then
                reqAttack:FireServer()
            end
        end
    end)
end

-- Rastrear personaje y herramientas para enlazar golpes inmediatamente
local player = game.Players.LocalPlayer

local function OnCharacterAdded(char: Model)
    task.spawn(function()
        char:WaitForChild("HumanoidRootPart", 5)
        SetupCharacterJoints(char)
    end)

    char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            HookTool(child)
        end
    end)

    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then
            HookTool(child)
        end
    end
end

if player.Character then
    OnCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(OnCharacterAdded)

player.Backpack.ChildAdded:Connect(function(child)
    if child:IsA("Tool") then
        HookTool(child)
    end
end)
for _, child in ipairs(player.Backpack:GetChildren()) do
    if child:IsA("Tool") then
        HookTool(child)
    end
end

-- 3. Atajos de teclado y clic de ataque
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F then
        UIController.OpenReactorModal()
    elseif input.KeyCode == Enum.KeyCode.M then
        UIController.OpenShopModal()
    elseif input.KeyCode == Enum.KeyCode.H then
        UIController.ToggleCinematicMode()
    elseif input.KeyCode == Enum.KeyCode.T then
        UIController.ToggleTopHUD()
    elseif input.KeyCode == Enum.KeyCode.B then
        UIController.ToggleNavigationDock()
    elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local tool = character and character:FindFirstChildOfClass("Tool")

        -- Si el arma está en la mochila, equiparla automáticamente y atacar
        if not tool and humanoid then
            local bpTool = player.Backpack:FindFirstChildOfClass("Tool")
            if bpTool then
                humanoid:EquipTool(bpTool)
                HookTool(bpTool)
                task.defer(function()
                    if PlaySwing() then
                        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
                        local reqAttack = remotes and remotes:FindFirstChild("RequestAttack") :: RemoteEvent?
                        if reqAttack then
                            reqAttack:FireServer()
                        end
                    end
                end)
                return
            end
        end

        -- Ataque sin herramienta en mano (combo cuerpo a cuerpo)
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        local reqAttack = remotes and remotes:FindFirstChild("RequestAttack") :: RemoteEvent?
        if reqAttack and PlaySwing() then
            reqAttack:FireServer()
        end
    end
end)

-- Asegurar que la mochila/hotbar esté activa y equipar arma al aparecer
local StarterGui = game:GetService("StarterGui")
task.spawn(function()
    pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
    end)
    local function AutoEquipWeapon(char: Model)
        local hum = char:WaitForChild("Humanoid", 6) :: Humanoid?
        if not hum then return end

        task.spawn(function()
            for _ = 1, 15 do
                local tool = player.Backpack:FindFirstChild("AuraWeapon") :: Tool?
                if tool then
                    hum:EquipTool(tool)
                    HookTool(tool)
                    break
                end
                local charTool = char:FindFirstChild("AuraWeapon") :: Tool?
                if charTool then
                    HookTool(charTool)
                    break
                end
                task.wait(0.2)
            end
        end)
    end
    if player.Character then AutoEquipWeapon(player.Character) end
    player.CharacterAdded:Connect(AutoEquipWeapon)
end)

-- 3. Conectar a los eventos de red de forma asíncrona y segura
task.spawn(function()
    local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10) :: Folder?
    if not Remotes then
        warn("[ClientInit] No se encontró la carpeta Remotes en ReplicatedStorage tras 10 segundos.")
        return
    end

    local StateReplicated = Remotes:WaitForChild("StateReplicated", 10) :: RemoteEvent?
    local NotificationEvent = Remotes:WaitForChild("NotificationEvent", 10) :: RemoteEvent?

    if StateReplicated then
        StateReplicated.OnClientEvent:Connect(function(profile)
            UIController.UpdateFromProfile(profile)
        end)
    end

    if NotificationEvent then
        NotificationEvent.OnClientEvent:Connect(function(data)
            if data.Type == "GlobalRoll" then
                UIController.ShowNotification("🌟 ¡" .. data.PlayerName .. " OBTUVO " .. data.Title .. "!", data.Color)
            elseif data.Type == "PersonalRoll" then
                UIController.ShowNotification("⚡ ¡NUEVA AURA DESBLOQUEADA: " .. data.Title .. "!", data.Color)
            elseif data.Type == "LevelUp" then
                UIController.ShowNotification("⭐ " .. data.Title, data.Color)
            elseif data.Title then
                UIController.ShowNotification(data.Title, data.Color)
            end
        end)
    end
end)

print("[Overcharged] Cliente iniciado con éxito y UI montada.")
