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

-- 2. Animación de golpe en cliente (combo de 3 tajos: derecha, izquierda, estocada)
local TweenService = game:GetService("TweenService")
local COMBO_ANGLES = {
    CFrame.Angles(math.rad(110), math.rad(-35), 0),
    CFrame.Angles(math.rad(80), math.rad(40), math.rad(-20)),
    CFrame.Angles(math.rad(95), 0, 0),
}
local comboIndex = 0
local lastSwing = 0
local swinging = false

local function PlaySwing()
    local now = os.clock()
    if swinging or now - lastSwing < 0.28 then return false end
    comboIndex = (now - lastSwing > 0.9) and 1 or (comboIndex % 3) + 1
    lastSwing = now

    local char = game.Players.LocalPlayer.Character
    if not char then return true end
    local joint: Motor6D? = nil
    local upperArm = char:FindFirstChild("RightUpperArm")
    if upperArm then
        joint = upperArm:FindFirstChild("RightShoulder") :: Motor6D?
    else
        local torso = char:FindFirstChild("Torso")
        joint = torso and torso:FindFirstChild("Right Shoulder") :: Motor6D?
    end

    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://9114223171"
    sound.Volume = 0.7
    sound.PlaybackSpeed = 1 + comboIndex * 0.08
    sound.Parent = char:FindFirstChild("HumanoidRootPart") or char
    sound:Play()
    game:GetService("Debris"):AddItem(sound, 2)

    -- Impulso hacia delante (más fuerte en el golpe final del combo)
    local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    if hrp then
        local push = comboIndex == 3 and 38 or 18
        local look = hrp.CFrame.LookVector
        hrp.AssemblyLinearVelocity = Vector3.new(look.X * push, hrp.AssemblyLinearVelocity.Y, look.Z * push)
    end

    if joint then
        swinging = true
        local orig = joint.C0
        TweenService:Create(joint, TweenInfo.new(0.07, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            C0 = orig * COMBO_ANGLES[comboIndex],
        }):Play()
        task.delay(0.12, function()
            local t = TweenService:Create(joint, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { C0 = orig })
            t:Play()
            t.Completed:Wait()
            swinging = false
        end)
    end
    return true
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
        local player = game.Players.LocalPlayer
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local tool = character and character:FindFirstChildOfClass("Tool")

        -- Si el arma está en la mochila, equiparla automáticamente en la mano
        if not tool and humanoid then
            local bpTool = player.Backpack:FindFirstChildOfClass("Tool")
            if bpTool then
                humanoid:EquipTool(bpTool)
                tool = bpTool
            end
        end

        -- Enviar orden de ataque sin trabas
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
    local player = game.Players.LocalPlayer
    local function AutoEquipWeapon(char: Model)
        local hum = char:WaitForChild("Humanoid", 6) :: Humanoid?
        if not hum then return end

        task.spawn(function()
            for _ = 1, 15 do
                local tool = player.Backpack:FindFirstChild("AuraWeapon") :: Tool?
                if tool then
                    hum:EquipTool(tool)
                    break
                end
                if char:FindFirstChild("AuraWeapon") then
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
