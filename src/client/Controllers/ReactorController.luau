--!strict
-- ReactorController: Controlador cliente para clics, juiciness táctil y sonidos
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RequestClick = Remotes:WaitForChild("RequestClick") :: RemoteEvent
local RequestUpgrade = Remotes:WaitForChild("RequestUpgrade") :: RemoteEvent

local ReactorController = {}

-- Genera un efecto de texto flotante que sale disparado hacia arriba al hacer clic
function ReactorController.SpawnFloatingText(startPos: Vector2, text: string, color: Color3)
    local screenGui = playerGui:FindFirstChild("OverchargedHUD")
    if not screenGui then return end

    local label = Instance.new("TextLabel")
    label.Text = text
    label.TextColor3 = color
    label.Font = Enum.Font.FredokaOne
    label.TextScaled = true
    label.Size = UDim2.fromOffset(120, 40)
    -- Dispersión aleatoria alrededor del punto de clic
    local offsetX = math.random(-40, 40)
    label.Position = UDim2.fromOffset(startPos.X + offsetX - 60, startPos.Y - 20)
    label.BackgroundTransparency = 1
    label.ZIndex = 20

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    stroke.Color = Color3.new(0, 0, 0)
    stroke.Parent = label

    label.Parent = screenGui

    -- Animación de ascenso y desvanecimiento
    local targetPos = UDim2.fromOffset(label.Position.X.Offset, label.Position.Y.Offset - 90)
    local tweenInfo = TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    local moveTween = TweenService:Create(label, tweenInfo, {
        Position = targetPos,
        TextTransparency = 1,
    })
    local strokeTween = TweenService:Create(stroke, tweenInfo, {
        Transparency = 1,
    })

    moveTween:Play()
    strokeTween:Play()

    moveTween.Completed:Once(function()
        label:Destroy()
    end)
end

-- Ejecuta la acción de clic con animación "Squash & Stretch"
function ReactorController.HandleCoreClick(coreButton: GuiButton, lastPower: number)
    -- 1. Squash & Stretch Tween
    local clickDown = TweenService:Create(coreButton, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.fromScale(0.88, 0.88)
    })
    local bounceBack = TweenService:Create(coreButton, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.fromScale(1.0, 1.0)
    })

    clickDown:Play()
    clickDown.Completed:Once(function()
        bounceBack:Play()
    end)

    -- 2. Efecto de texto flotante
    local absPos = coreButton.AbsolutePosition
    local absSize = coreButton.AbsoluteSize
    local center = Vector2.new(absPos.X + absSize.X / 2, absPos.Y + absSize.Y / 2)
    ReactorController.SpawnFloatingText(center, "+" .. tostring(lastPower), Color3.fromRGB(255, 230, 80))

    -- 3. Emitir petición al servidor
    RequestClick:FireServer()
end

-- Envía petición de compra de mejora
function ReactorController.BuyUpgrade(upgradeKey: string)
    RequestUpgrade:FireServer(upgradeKey)
end

-- Envía petición para mejorar la casa de la parcela
function ReactorController.UpgradeHouse()
    local RequestHouseUpgrade = Remotes:FindFirstChild("RequestHouseUpgrade") :: RemoteEvent?
    if RequestHouseUpgrade then
        RequestHouseUpgrade:FireServer()
    end
end

-- Envía petición para comprar una Torre Tesla automatizadora
function ReactorController.BuyTeslaTower()
    local RequestBuyAutomator = Remotes:FindFirstChild("RequestBuyAutomator") :: RemoteEvent?
    if RequestBuyAutomator then
        RequestBuyAutomator:FireServer()
    end
end

return ReactorController
