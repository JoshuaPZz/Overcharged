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
    label.Size = UDim2.fromOffset(140, 46)
    -- Dispersión aleatoria alrededor del punto de clic
    local offsetX = math.random(-40, 40)
    label.Position = UDim2.fromOffset(startPos.X + offsetX - 70, startPos.Y - 23)
    label.BackgroundTransparency = 1
    label.ZIndex = 20

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2.5
    stroke.Color = Color3.new(0, 0, 0)
    stroke.Parent = label

    -- Pop de escala al aparecer (más jugoso que un simple fade)
    local pop = Instance.new("UIScale")
    pop.Scale = 0.4
    pop.Parent = label

    label.Parent = screenGui

    TweenService:Create(pop, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.12 }):Play()
    task.delay(0.12, function()
        if pop and pop.Parent then
            TweenService:Create(pop, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
        end
    end)

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

-- Ejecuta la acción de clic con animación "Squash & Stretch" enriquecida
function ReactorController.HandleCoreClick(coreButton: GuiButton, lastPower: number)
    -- 1. Squash & Stretch Tween con un pequeño giro aleatorio
    local spin = (math.random() > 0.5) and 5 or -5
    local clickDown = TweenService:Create(coreButton, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.fromScale(0.86, 0.86),
        Rotation = spin,
    })
    local bounceBack = TweenService:Create(coreButton, TweenInfo.new(0.3, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
        Size = UDim2.fromScale(1.0, 1.0),
        Rotation = 0,
    })

    clickDown:Play()
    clickDown.Completed:Once(function()
        bounceBack:Play()
    end)

    -- 1b. Pulso del anillo de neón para reforzar el impacto
    local stroke = coreButton:FindFirstChild("UIStroke") :: UIStroke?
    if stroke then
        stroke.Thickness = 8
        TweenService:Create(stroke, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Thickness = 5,
        }):Play()
    end

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
