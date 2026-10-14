--!strict
-- UIController: Interfaz gráfica limpia, moderna y con ventanas desplegables (Modales con botón de cerrar [X])
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("OverchargedShared")
local Types = require(Shared.Types.GameTypes)
local GameConfig = require(Shared.Config.GameConfig)
local FormatNumber = require(Shared.Utils.FormatNumber)
local SoundUtil = require(Shared.Utils.SoundUtil)

local ReactorController = require(script.Parent.ReactorController)

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local UIController = {}

-- Referencias de elementos de la interfaz
local ScreenGui: ScreenGui
local EnergyLabel: TextLabel
local AuraTitleLabel: TextLabel
local ZoneBadge: TextLabel

-- Modales desplegables (Ocultables)
local ReactorModal: Frame
local CoreButton: TextButton
local OverchargeFill: Frame
local OverchargeLabel: TextLabel

local ShopModal: Frame
local UpgradesContainer: ScrollingFrame

local NotificationBanner: TextLabel
local CachedProfile: Types.PlayerProfile? = nil

-- Estado de Number Lerp de Energía
local DisplayedEnergy = 0
local TargetEnergy = 0

-- Crea una esquina redondeada reutilizable
local function CreateCorner(parent: Instance, radius: number)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = parent
    return corner
end

-- Crea un borde de trazo reutilizable
local function CreateStroke(parent: Instance, thickness: number, color: Color3)
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = thickness
    stroke.Color = color
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = parent
    return stroke
end

-- Añade gradiente moderno sutil (Estilo Vinyl oscuro)
local function AddModernGradient(parent: Instance, col1: Color3?, col2: Color3?)
    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new(
        col1 or Color3.fromRGB(35, 38, 52),
        col2 or Color3.fromRGB(20, 22, 30)
    )
    grad.Rotation = 45
    grad.Parent = parent
    return grad
end

-- Micro-interacciones táctiles en botones (Hover 1.06x + Sonido, Click 0.92x + Sonido)
local function ApplyButtonMicroInteractions(btn: GuiButton)
    if btn:FindFirstChild("HasMicroInteractions") then return end
    local tag = Instance.new("BoolValue")
    tag.Name = "HasMicroInteractions"
    tag.Parent = btn

    local uiScale = btn:FindFirstChildOfClass("UIScale")
    if not uiScale then
        uiScale = Instance.new("UIScale")
        uiScale.Scale = 1.0
        uiScale.Parent = btn
    end

    btn.MouseEnter:Connect(function()
        SoundUtil.Play2D(SoundUtil.SOUNDS.HOVER, 0.4, true)
        TweenService:Create(uiScale, TweenInfo.new(0.12, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Scale = 1.06,
        }):Play()
    end)

    btn.MouseLeave:Connect(function()
        TweenService:Create(uiScale, TweenInfo.new(0.12, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Scale = 1.0,
        }):Play()
    end)

    btn.MouseButton1Down:Connect(function()
        SoundUtil.Play2D(SoundUtil.SOUNDS.CLICK, 0.5, true)
        TweenService:Create(uiScale, TweenInfo.new(0.08, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Scale = 0.92,
        }):Play()
    end)

    btn.MouseButton1Up:Connect(function()
        TweenService:Create(uiScale, TweenInfo.new(0.12, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Scale = 1.0,
        }):Play()
    end)
end

-- Alterna la visibilidad de un modal con animación fluida de escala (Quart Out)
local function AnimateModalToggle(modal: Frame, open: boolean)
    local scale = modal:FindFirstChildOfClass("UIScale")
    if not scale then
        scale = Instance.new("UIScale")
        scale.Scale = 1.0
        scale.Parent = modal
    end

    if open then
        modal.Visible = true
        scale.Scale = 0.88
        TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Scale = 1.0,
        }):Play()
    else
        local tween = TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
            Scale = 0.88,
        })
        tween:Play()
        task.delay(0.18, function()
            if scale.Scale <= 0.9 then
                modal.Visible = false
            end
        end)
    end
end

-- Crea un botón de cierre estándar [X] estilizado
local function CreateCloseButton(parent: Frame, onClose: () -> ()): TextButton
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.fromOffset(32, 32)
    closeBtn.Position = UDim2.new(1, -38, 0, 8)
    closeBtn.BackgroundColor3 = GameConfig.PALETTE.CRIMSON_SPARK
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Font = Enum.Font.FredokaOne
    closeBtn.TextSize = 16
    closeBtn.Parent = parent
    CreateCorner(closeBtn, 8)
    CreateStroke(closeBtn, 1.5, Color3.fromRGB(255, 120, 130))

    closeBtn.MouseButton1Click:Connect(function()
        AnimateModalToggle(parent, false)
        if onClose then onClose() end
    end)
    return closeBtn
end

-- Pulso visual en el contador de energía al ganar cantidades notorias
local function PulseEnergyLabel()
    if not EnergyLabel then return end
    local scale = EnergyLabel:FindFirstChildOfClass("UIScale")
    if not scale then
        scale = Instance.new("UIScale", EnergyLabel)
    end
    TweenService:Create(scale, TweenInfo.new(0.09, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.08 }):Play()
    task.delay(0.1, function()
        if scale and scale.Parent then
            TweenService:Create(scale, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.0 }):Play()
        end
    end)
end

-- Bucle de interpolación continua de número (Number Lerp fluido)
RunService.RenderStepped:Connect(function(dt: number)
    if DisplayedEnergy ~= TargetEnergy then
        local diff = TargetEnergy - DisplayedEnergy
        if math.abs(diff) < 2 then
            DisplayedEnergy = TargetEnergy
        else
            DisplayedEnergy = math.floor(DisplayedEnergy + diff * math.clamp(dt * 12, 0.05, 1))
        end
        if EnergyLabel then
            EnergyLabel.Text = "⚡ " .. FormatNumber.FormatCompact(DisplayedEnergy) .. " ENERGÍA"
        end
    end
end)

-- Construye toda la interfaz gráfica en memoria
function UIController.InitializeUI()
    -- 1. ScreenGui Principal
    ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "OverchargedHUD"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = playerGui

    local palette = GameConfig.PALETTE

    -- 2. Barra Superior Unificada (Estilo Vinyl Deep Slate con acentos Cyan Plasma)
    local topFrame = Instance.new("Frame")
    topFrame.Name = "TopHUD"
    topFrame.Size = UDim2.new(0, 440, 0, 96)
    topFrame.Position = UDim2.new(0.5, -220, 0, 10)
    topFrame.BackgroundColor3 = palette.DEEP_SLATE
    topFrame.BackgroundTransparency = 0.08
    topFrame.Parent = ScreenGui
    CreateCorner(topFrame, 14)
    CreateStroke(topFrame, 2, palette.CYAN_PLASMA)
    AddModernGradient(topFrame)

    EnergyLabel = Instance.new("TextLabel")
    EnergyLabel.Name = "EnergyLabel"
    EnergyLabel.Size = UDim2.new(1, -60, 0, 24)
    EnergyLabel.Position = UDim2.new(0, 10, 0, 4)
    EnergyLabel.BackgroundTransparency = 1
    EnergyLabel.Font = Enum.Font.FredokaOne
    EnergyLabel.Text = "⚡ 0 ENERGÍA"
    EnergyLabel.TextColor3 = palette.ENERGY_GOLD
    EnergyLabel.TextScaled = true
    EnergyLabel.Parent = topFrame

    -- Botón de Minimizar Barra Superior [▲] (Esquina superior derecha del marco)
    local collapseTopBtn = Instance.new("TextButton")
    collapseTopBtn.Name = "CollapseTopBtn"
    collapseTopBtn.Size = UDim2.fromOffset(32, 26)
    collapseTopBtn.Position = UDim2.new(1, -38, 0, 4)
    collapseTopBtn.BackgroundColor3 = palette.DEEP_SLATE
    collapseTopBtn.Text = "▲"
    collapseTopBtn.TextColor3 = palette.CYAN_PLASMA
    collapseTopBtn.Font = Enum.Font.FredokaOne
    collapseTopBtn.TextSize = 14
    collapseTopBtn.ZIndex = 30
    collapseTopBtn.Parent = topFrame
    CreateCorner(collapseTopBtn, 6)
    CreateStroke(collapseTopBtn, 1.5, palette.CYAN_PLASMA)
    ApplyButtonMicroInteractions(collapseTopBtn)

    AuraTitleLabel = Instance.new("TextLabel")
    AuraTitleLabel.Name = "AuraTitleLabel"
    AuraTitleLabel.Size = UDim2.new(1, 0, 0, 16)
    AuraTitleLabel.Position = UDim2.new(0, 0, 0, 29)
    AuraTitleLabel.BackgroundTransparency = 1
    AuraTitleLabel.Font = Enum.Font.GothamBold
    AuraTitleLabel.Text = "[Nv. 1] Iniciado - Kinetic Spark"
    AuraTitleLabel.TextColor3 = palette.CYAN_PLASMA
    AuraTitleLabel.TextSize = 11
    AuraTitleLabel.Parent = topFrame

    -- Indicador de Zona (Integrado dentro del TopHUD, centrado para nunca desfasarse)
    ZoneBadge = Instance.new("TextLabel")
    ZoneBadge.Name = "ZoneBadge"
    ZoneBadge.Size = UDim2.new(0, 250, 0, 20)
    ZoneBadge.Position = UDim2.new(0.5, -125, 0, 48)
    ZoneBadge.BackgroundColor3 = Color3.fromRGB(18, 22, 34)
    ZoneBadge.BackgroundTransparency = 0.2
    ZoneBadge.Font = Enum.Font.FredokaOne
    ZoneBadge.Text = "🛡 TU ISLA (#1) - SEGURO"
    ZoneBadge.TextColor3 = palette.MINT_OASIS
    ZoneBadge.TextSize = 11
    ZoneBadge.Parent = topFrame
    CreateCorner(ZoneBadge, 6)
    CreateStroke(ZoneBadge, 1, palette.MINT_OASIS)

    -- Barra de Progreso de XP de Aura (Cyan Plasma Fill)
    local xpBarBg = Instance.new("Frame")
    xpBarBg.Name = "AuraXPBarBg"
    xpBarBg.Size = UDim2.new(0.92, 0, 0, 14)
    xpBarBg.Position = UDim2.new(0.04, 0, 0, 74)
    xpBarBg.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
    xpBarBg.Parent = topFrame
    CreateCorner(xpBarBg, 6)
    CreateStroke(xpBarBg, 1, Color3.fromRGB(35, 42, 60))

    local xpFill = Instance.new("Frame")
    xpFill.Name = "AuraXPFill"
    xpFill.Size = UDim2.fromScale(0, 1)
    xpFill.BackgroundColor3 = palette.CYAN_PLASMA
    xpFill.BorderSizePixel = 0
    xpFill.Parent = xpBarBg
    CreateCorner(xpFill, 6)

    local xpLabel = Instance.new("TextLabel")
    xpLabel.Name = "AuraXPText"
    xpLabel.Size = UDim2.fromScale(1, 1)
    xpLabel.BackgroundTransparency = 1
    xpLabel.Font = Enum.Font.FredokaOne
    xpLabel.Text = "XP: 0 / 100"
    xpLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    xpLabel.TextSize = 10
    xpLabel.ZIndex = 5
    xpLabel.Parent = xpBarBg

    -- Pestaña compacta para restaurar la barra superior cuando está minimizada
    local isTopCollapsed = false
    local topRevealTab = Instance.new("TextButton")
    topRevealTab.Name = "TopRevealTab"
    topRevealTab.Size = UDim2.new(0, 140, 0, 28)
    topRevealTab.Position = UDim2.new(0.5, -70, 0, 6)
    topRevealTab.BackgroundColor3 = palette.DEEP_SLATE
    topRevealTab.Text = "▼ MOSTRAR HUD"
    topRevealTab.TextColor3 = palette.CYAN_PLASMA
    topRevealTab.Font = Enum.Font.FredokaOne
    topRevealTab.TextSize = 12
    topRevealTab.ZIndex = 30
    topRevealTab.Visible = false
    topRevealTab.Parent = ScreenGui
    CreateCorner(topRevealTab, 8)
    CreateStroke(topRevealTab, 1.5, palette.CYAN_PLASMA)
    ApplyButtonMicroInteractions(topRevealTab)

    local function SetTopCollapsed(collapsed: boolean)
        isTopCollapsed = collapsed
        local tweenInfo = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        if isTopCollapsed then
            -- Animar completamente hacia arriba y ocultar
            local tween = TweenService:Create(topFrame, tweenInfo, {
                Position = UDim2.new(0.5, -220, 0, -180),
            })
            tween:Play()
            task.delay(0.22, function()
                if isTopCollapsed then
                    topFrame.Visible = false
                    topRevealTab.Visible = true
                end
            end)
        else
            topRevealTab.Visible = false
            topFrame.Visible = true
            TweenService:Create(topFrame, tweenInfo, {
                Position = UDim2.new(0.5, -220, 0, 10),
            }):Play()
        end
    end

    collapseTopBtn.MouseButton1Click:Connect(function()
        SetTopCollapsed(true)
    end)

    topRevealTab.MouseButton1Click:Connect(function()
        SetTopCollapsed(false)
    end)

    function UIController.ToggleTopHUD()
        SetTopCollapsed(not isTopCollapsed)
    end

    -- 3. Barra Lateral de Botones de Navegación (Dock en el lateral izquierdo con pestaña retráctil permanente)
    local isDockCollapsed = false
    local dockFrame = Instance.new("Frame")
    dockFrame.Name = "NavigationDock"
    dockFrame.Size = UDim2.new(0, 170, 0, 110)
    dockFrame.Position = UDim2.new(0, 15, 0.5, -55)
    dockFrame.BackgroundTransparency = 1
    dockFrame.Parent = ScreenGui

    -- Contenedor de botones (Aislado para que UIListLayout NUNCA desplace al botón retráctil)
    local buttonsHolder = Instance.new("Frame")
    buttonsHolder.Name = "ButtonsHolder"
    buttonsHolder.Size = UDim2.new(0, 130, 0, 110)
    buttonsHolder.Position = UDim2.new(0, 0, 0, 0)
    buttonsHolder.BackgroundTransparency = 1
    buttonsHolder.Parent = dockFrame

    local dockLayout = Instance.new("UIListLayout")
    dockLayout.Padding = UDim.new(0, 10)
    dockLayout.Parent = buttonsHolder

    -- Botón para abrir la ventana de Farmeo / Clics (Electric Cobalt con borde Cyan)
    local farmToggleBtn = Instance.new("TextButton")
    farmToggleBtn.Name = "FarmToggleBtn"
    farmToggleBtn.Size = UDim2.new(1, 0, 0, 48)
    farmToggleBtn.BackgroundColor3 = palette.ELECTRIC_COBALT
    farmToggleBtn.Text = "⚛ FARMEAR"
    farmToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    farmToggleBtn.Font = Enum.Font.FredokaOne
    farmToggleBtn.TextSize = 14
    farmToggleBtn.Parent = buttonsHolder
    CreateCorner(farmToggleBtn, 10)
    CreateStroke(farmToggleBtn, 2, palette.CYAN_PLASMA)
    ApplyButtonMicroInteractions(farmToggleBtn)

    -- Botón para abrir la Tienda de Mejoras (Energy Gold con borde brillante)
    local shopToggleBtn = Instance.new("TextButton")
    shopToggleBtn.Name = "ShopToggleBtn"
    shopToggleBtn.Size = UDim2.new(1, 0, 0, 48)
    shopToggleBtn.BackgroundColor3 = palette.ENERGY_GOLD
    shopToggleBtn.Text = "🛠 MEJORAS"
    shopToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    shopToggleBtn.Font = Enum.Font.FredokaOne
    shopToggleBtn.TextSize = 14
    shopToggleBtn.Parent = buttonsHolder
    CreateCorner(shopToggleBtn, 10)
    CreateStroke(shopToggleBtn, 2, Color3.fromRGB(255, 225, 120))
    ApplyButtonMicroInteractions(shopToggleBtn)

    -- Pestaña/Botón retráctil fijo en el lateral derecho del dock (Hermana de buttonsHolder)
    local dockCollapseBtn = Instance.new("TextButton")
    dockCollapseBtn.Name = "DockCollapseBtn"
    dockCollapseBtn.Size = UDim2.fromOffset(28, 46)
    dockCollapseBtn.Position = UDim2.new(0, 134, 0.5, -23)
    dockCollapseBtn.BackgroundColor3 = palette.DEEP_SLATE
    dockCollapseBtn.Text = "◀"
    dockCollapseBtn.TextColor3 = palette.CYAN_PLASMA
    dockCollapseBtn.Font = Enum.Font.FredokaOne
    dockCollapseBtn.TextSize = 15
    dockCollapseBtn.ZIndex = 30
    dockCollapseBtn.Parent = dockFrame
    CreateCorner(dockCollapseBtn, 8)
    CreateStroke(dockCollapseBtn, 1.5, palette.CYAN_PLASMA)
    ApplyButtonMicroInteractions(dockCollapseBtn)

    local function SetDockCollapsed(collapsed: boolean)
        isDockCollapsed = collapsed
        local targetX = isDockCollapsed and -130 or 15
        dockCollapseBtn.Text = isDockCollapsed and "▶" or "◀"

        TweenService:Create(dockFrame, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(0, targetX, 0.5, -55),
        }):Play()
    end

    dockCollapseBtn.MouseButton1Click:Connect(function()
        SetDockCollapsed(not isDockCollapsed)
    end)

    function UIController.ToggleNavigationDock()
        SetDockCollapsed(not isDockCollapsed)
    end

    -- 4. MODAL DEL NÚCLEO DE FARMEAR (Oculto por defecto - Estilo Deep Slate)
    ReactorModal = Instance.new("Frame")
    ReactorModal.Name = "ReactorModal"
    ReactorModal.Size = UDim2.fromOffset(320, 370)
    ReactorModal.Position = UDim2.new(0.5, -160, 0.5, -185)
    ReactorModal.BackgroundColor3 = palette.DEEP_SLATE
    ReactorModal.BackgroundTransparency = 0.06
    ReactorModal.Visible = false -- ¡Inicia cerrado para no tapar la pantalla!
    ReactorModal.Parent = ScreenGui
    CreateCorner(ReactorModal, 16)
    CreateStroke(ReactorModal, 2.5, palette.ELECTRIC_COBALT)
    AddModernGradient(ReactorModal)
    CreateCloseButton(ReactorModal, function()
        ReactorModal.Visible = false
    end)

    local reactorTitle = Instance.new("TextLabel")
    reactorTitle.Size = UDim2.new(1, -50, 0, 40)
    reactorTitle.Position = UDim2.new(0, 15, 0, 6)
    reactorTitle.BackgroundTransparency = 1
    reactorTitle.Font = Enum.Font.FredokaOne
    reactorTitle.Text = "⚛ NÚCLEO DEL REACTOR"
    reactorTitle.TextColor3 = Color3.fromRGB(240, 245, 255)
    reactorTitle.TextXAlignment = Enum.TextXAlignment.Left
    reactorTitle.TextSize = 16
    reactorTitle.Parent = ReactorModal

    -- Botón interactivo central del reactor (Electric Cobalt con Squash & Stretch)
    local coreCenterWrapper = Instance.new("Frame")
    coreCenterWrapper.Size = UDim2.fromOffset(170, 170)
    coreCenterWrapper.Position = UDim2.new(0.5, -85, 0, 60)
    coreCenterWrapper.BackgroundTransparency = 1
    coreCenterWrapper.Parent = ReactorModal

    CoreButton = Instance.new("TextButton")
    CoreButton.Name = "ReactorCore"
    CoreButton.Size = UDim2.fromScale(1, 1)
    CoreButton.BackgroundColor3 = palette.ELECTRIC_COBALT
    CoreButton.Text = "⚛"
    CoreButton.Font = Enum.Font.FredokaOne
    CoreButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CoreButton.TextSize = 85
    CoreButton.AutoButtonColor = false
    CoreButton.Parent = coreCenterWrapper
    CreateCorner(CoreButton, 85)
    CreateStroke(CoreButton, 5, palette.CYAN_PLASMA)

    -- Barra de Sobrecarga dentro del modal
    local overchargeBarBg = Instance.new("Frame")
    overchargeBarBg.Name = "OverchargeBarBg"
    overchargeBarBg.Size = UDim2.new(1, -40, 0, 28)
    overchargeBarBg.Position = UDim2.new(0, 20, 0, 250)
    overchargeBarBg.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
    overchargeBarBg.Parent = ReactorModal
    CreateCorner(overchargeBarBg, 14)
    CreateStroke(overchargeBarBg, 1.5, palette.ELECTRIC_COBALT)

    OverchargeFill = Instance.new("Frame")
    OverchargeFill.Name = "Fill"
    OverchargeFill.Size = UDim2.fromScale(0, 1)
    OverchargeFill.BackgroundColor3 = palette.ENERGY_GOLD
    OverchargeFill.BorderSizePixel = 0
    OverchargeFill.Parent = overchargeBarBg
    CreateCorner(OverchargeFill, 14)

    OverchargeLabel = Instance.new("TextLabel")
    OverchargeLabel.Name = "ProgressLabel"
    OverchargeLabel.Size = UDim2.fromScale(1, 1)
    OverchargeLabel.BackgroundTransparency = 1
    OverchargeLabel.Font = Enum.Font.FredokaOne
    OverchargeLabel.Text = "SOBRECARGA: 0%"
    OverchargeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    OverchargeLabel.TextSize = 14
    OverchargeLabel.ZIndex = 5
    OverchargeLabel.Parent = overchargeBarBg

    local hintLabel = Instance.new("TextLabel")
    hintLabel.Size = UDim2.new(1, 0, 0, 20)
    hintLabel.Position = UDim2.new(0, 0, 0, 290)
    hintLabel.BackgroundTransparency = 1
    hintLabel.Font = Enum.Font.GothamBold
    hintLabel.Text = "Haz clics para llenar el 100% y obtener Auras raras"
    hintLabel.TextColor3 = palette.CYAN_PLASMA
    hintLabel.TextSize = 11
    hintLabel.Parent = ReactorModal

    -- 5. MODAL DE LA TIENDA DE MEJORAS (Oculto por defecto - Energy Gold Theme)
    ShopModal = Instance.new("Frame")
    ShopModal.Name = "ShopModal"
    ShopModal.Size = UDim2.fromOffset(360, 440)
    ShopModal.Position = UDim2.new(0.5, -180, 0.5, -220)
    ShopModal.BackgroundColor3 = palette.DEEP_SLATE
    ShopModal.BackgroundTransparency = 0.06
    ShopModal.Visible = false -- ¡Inicia cerrado!
    ShopModal.Parent = ScreenGui
    CreateCorner(ShopModal, 16)
    CreateStroke(ShopModal, 2.5, palette.ENERGY_GOLD)
    AddModernGradient(ShopModal)
    CreateCloseButton(ShopModal, function()
        ShopModal.Visible = false
    end)

    local shopTitle = Instance.new("TextLabel")
    shopTitle.Size = UDim2.new(1, -50, 0, 42)
    shopTitle.Position = UDim2.new(0, 16, 0, 6)
    shopTitle.BackgroundTransparency = 1
    shopTitle.Font = Enum.Font.FredokaOne
    shopTitle.Text = "⚡ MEJORAS DEL REACTOR"
    shopTitle.TextColor3 = palette.ENERGY_GOLD
    shopTitle.TextXAlignment = Enum.TextXAlignment.Left
    shopTitle.TextSize = 17
    shopTitle.Parent = ShopModal

    UpgradesContainer = Instance.new("ScrollingFrame")
    UpgradesContainer.Name = "UpgradesList"
    UpgradesContainer.Size = UDim2.new(1, -24, 1, -60)
    UpgradesContainer.Position = UDim2.new(0, 12, 0, 48)
    UpgradesContainer.BackgroundTransparency = 1
    UpgradesContainer.ScrollBarThickness = 6
    UpgradesContainer.Parent = ShopModal

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 10)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = UpgradesContainer

    -- 6. Banner de Anuncios y Tiradas
    NotificationBanner = Instance.new("TextLabel")
    NotificationBanner.Name = "NotificationBanner"
    NotificationBanner.Size = UDim2.new(0, 500, 0, 42)
    NotificationBanner.Position = UDim2.new(0.5, -250, 0, 115)
    NotificationBanner.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    NotificationBanner.BackgroundTransparency = 1
    NotificationBanner.TextTransparency = 1
    NotificationBanner.Font = Enum.Font.FredokaOne
    NotificationBanner.TextSize = 18
    NotificationBanner.ZIndex = 50
    NotificationBanner.Parent = ScreenGui
    CreateCorner(NotificationBanner, 10)

    -- 7. Conexiones de apertura y cierre de botones con animación fluida
    farmToggleBtn.MouseButton1Click:Connect(function()
        if ReactorModal.Visible then
            AnimateModalToggle(ReactorModal, false)
        else
            AnimateModalToggle(ReactorModal, true)
            AnimateModalToggle(ShopModal, false)
        end
    end)

    shopToggleBtn.MouseButton1Click:Connect(function()
        if ShopModal.Visible then
            AnimateModalToggle(ShopModal, false)
        else
            AnimateModalToggle(ShopModal, true)
            AnimateModalToggle(ReactorModal, false)
        end
    end)

    -- Registro reactivo de micro-interacciones táctiles en todos los botones
    for _, btn in ipairs(ScreenGui:GetDescendants()) do
        if btn:IsA("GuiButton") and btn.Name ~= "ReactorCore" then
            ApplyButtonMicroInteractions(btn)
        end
    end

    ScreenGui.DescendantAdded:Connect(function(desc)
        if desc:IsA("GuiButton") and desc.Name ~= "ReactorCore" then
            ApplyButtonMicroInteractions(desc)
        end
    end)

    -- Conexión de clic del núcleo con animación Squash & Stretch
    CoreButton.MouseButton1Down:Connect(function()
        local clickPower = 1
        if CachedProfile and CachedProfile.Upgrades["Turbine"] then
            clickPower = math.max(1, CachedProfile.Upgrades["Turbine"].Level)
        end
        ReactorController.HandleCoreClick(CoreButton, clickPower)
    end)

    -- Rastreador en tiempo real de posición del jugador (Safezone vs Arena)
    task.spawn(function()
        while true do
            task.wait(0.25)
            local character = localPlayer.Character
            if character then
                local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
                if root then
                    local dist = (Vector2.new(root.Position.X, root.Position.Z) - Vector2.new(0, 0)).Magnitude
                    local zoneStroke = ZoneBadge:FindFirstChild("UIStroke") :: UIStroke?
                    if dist <= (GameConfig.CENTER_ISLAND_RADIUS + 5) then
                        ZoneBadge.Text = "⚔ ARENA DE COMBATE (PvP ACTIVO)"
                        ZoneBadge.TextColor3 = palette.CRIMSON_SPARK
                        ZoneBadge.BackgroundColor3 = palette.DEEP_SLATE
                        if zoneStroke then zoneStroke.Color = palette.CRIMSON_SPARK end
                    else
                        local islandNum = CachedProfile and CachedProfile.AssignedIsland or 1
                        ZoneBadge.Text = "🛡 TU ISLA (#" .. tostring(islandNum) .. ") - SEGURO"
                        ZoneBadge.TextColor3 = palette.MINT_OASIS
                        ZoneBadge.BackgroundColor3 = palette.DEEP_SLATE
                        if zoneStroke then zoneStroke.Color = palette.MINT_OASIS end
                    end
                end
            end
        end
    end)
end

-- Muestra un anuncio animado en pantalla
function UIController.ShowNotification(text: string, color: Color3)
    NotificationBanner.Text = text
    NotificationBanner.TextColor3 = color
    NotificationBanner.BackgroundColor3 = GameConfig.PALETTE.DEEP_SLATE
    NotificationBanner.BackgroundTransparency = 0.15

    local stroke = NotificationBanner:FindFirstChild("UIStroke") or CreateStroke(NotificationBanner, 2, color)
    stroke.Color = color
    stroke.Transparency = 0

    local fadeIn = TweenService:Create(NotificationBanner, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        TextTransparency = 0,
        Position = UDim2.new(0.5, -250, 0, 126),
    })
    fadeIn:Play()

    task.delay(3.5, function()
        local fadeOut = TweenService:Create(NotificationBanner, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            TextTransparency = 1,
            BackgroundTransparency = 1,
            Position = UDim2.new(0.5, -250, 0, 112),
        })
        fadeOut:Play()
    end)
end

-- Renderiza la lista de mejoras en la tienda
local function RenderUpgrades(profile: Types.PlayerProfile)
    local palette = GameConfig.PALETTE

    for _, child in ipairs(UpgradesContainer:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    local order = 1
    for key, def in pairs(GameConfig.UPGRADES) do
        local userUpgrade = profile.Upgrades[key]
        local currentLevel = userUpgrade and userUpgrade.Level or 0
        local cost = math.floor(def.BaseCost * (def.CostMultiplier ^ currentLevel))
        local canAfford = profile.Energy >= cost

        local card = Instance.new("Frame")
        card.Name = "UpgradeCard_" .. key
        card.Size = UDim2.new(1, -8, 0, 68)
        card.BackgroundColor3 = Color3.fromRGB(24, 28, 44)
        card.LayoutOrder = order
        card.Parent = UpgradesContainer
        CreateCorner(card, 10)
        CreateStroke(card, 1.5, palette.ELECTRIC_COBALT)
        AddModernGradient(card, Color3.fromRGB(32, 38, 56), Color3.fromRGB(18, 22, 34))

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(0.65, 0, 0.45, 0)
        nameLabel.Position = UDim2.new(0, 8, 0, 6)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.Text = def.DisplayName .. " [Nv. " .. tostring(currentLevel) .. "]"
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextSize = 13
        nameLabel.Parent = card

        local descLabel = Instance.new("TextLabel")
        descLabel.Size = UDim2.new(0.65, 0, 0.45, 0)
        descLabel.Position = UDim2.new(0, 8, 0.48, 0)
        descLabel.BackgroundTransparency = 1
        descLabel.Font = Enum.Font.Gotham
        descLabel.Text = def.Description
        descLabel.TextColor3 = Color3.fromRGB(160, 180, 215)
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.TextSize = 11
        descLabel.Parent = card

        local buyBtn = Instance.new("TextButton")
        buyBtn.Name = "BuyButton"
        buyBtn.Size = UDim2.new(0.3, 0, 0.75, 0)
        buyBtn.Position = UDim2.new(0.68, 0, 0.12, 0)
        buyBtn.BackgroundColor3 = canAfford and palette.MINT_OASIS or Color3.fromRGB(50, 55, 70)
        buyBtn.Font = Enum.Font.FredokaOne
        buyBtn.Text = "⚡ " .. FormatNumber.FormatCompact(cost)
        buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        buyBtn.TextSize = 12
        buyBtn.Parent = card
        CreateCorner(buyBtn, 8)
        if canAfford then
            CreateStroke(buyBtn, 1.5, Color3.fromRGB(120, 255, 170))
        end

        buyBtn.MouseButton1Click:Connect(function()
            if profile.Energy >= cost then
                ReactorController.BuyUpgrade(key)
            end
        end)

        order += 1
    end

    -- TARJETA DE MEJORA DE CASA
    local houseLevel = profile.HouseLevel or 0
    local nextHouseLevel = houseLevel + 1
    local houseConfig = GameConfig.HOUSE_UPGRADES[nextHouseLevel]

    local houseCard = Instance.new("Frame")
    houseCard.Name = "UpgradeCard_House"
    houseCard.Size = UDim2.new(1, -8, 0, 74)
    houseCard.BackgroundColor3 = Color3.fromRGB(20, 32, 28)
    houseCard.LayoutOrder = order
    houseCard.Parent = UpgradesContainer
    CreateCorner(houseCard, 10)
    CreateStroke(houseCard, 1.5, palette.MINT_OASIS)
    AddModernGradient(houseCard, Color3.fromRGB(24, 42, 36), Color3.fromRGB(14, 26, 22))

    local houseName = Instance.new("TextLabel")
    houseName.Size = UDim2.new(0.65, 0, 0.45, 0)
    houseName.Position = UDim2.new(0, 8, 0, 6)
    houseName.BackgroundTransparency = 1
    houseName.Font = Enum.Font.GothamBold
    houseName.Text = houseConfig and ("🏠 " .. houseConfig.Name) or "🏠 Santuario Cósmico [MÁXIMO]"
    houseName.TextColor3 = palette.MINT_OASIS
    houseName.TextXAlignment = Enum.TextXAlignment.Left
    houseName.TextSize = 13
    houseName.Parent = houseCard

    local houseDesc = Instance.new("TextLabel")
    houseDesc.Size = UDim2.new(0.65, 0, 0.48, 0)
    houseDesc.Position = UDim2.new(0, 8, 0.48, 0)
    houseDesc.BackgroundTransparency = 1
    houseDesc.Font = Enum.Font.Gotham
    houseDesc.Text = houseConfig and houseConfig.Description or "+200% Multiplicador permanente activo"
    houseDesc.TextColor3 = Color3.fromRGB(180, 220, 190)
    houseDesc.TextXAlignment = Enum.TextXAlignment.Left
    houseDesc.TextSize = 11
    houseDesc.Parent = houseCard

    if houseConfig then
        local canAffordHouse = profile.Energy >= houseConfig.Cost
        local houseBuyBtn = Instance.new("TextButton")
        houseBuyBtn.Name = "BuyHouseBtn"
        houseBuyBtn.Size = UDim2.new(0.3, 0, 0.75, 0)
        houseBuyBtn.Position = UDim2.new(0.68, 0, 0.12, 0)
        houseBuyBtn.BackgroundColor3 = canAffordHouse and palette.MINT_OASIS or Color3.fromRGB(50, 55, 70)
        houseBuyBtn.Font = Enum.Font.FredokaOne
        houseBuyBtn.Text = "⚡ " .. FormatNumber.FormatCompact(houseConfig.Cost)
        houseBuyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        houseBuyBtn.TextSize = 12
        houseBuyBtn.Parent = houseCard
        CreateCorner(houseBuyBtn, 8)
        if canAffordHouse then
            CreateStroke(houseBuyBtn, 1.5, Color3.fromRGB(120, 255, 170))
        end

        houseBuyBtn.MouseButton1Click:Connect(function()
            if profile.Energy >= houseConfig.Cost then
                ReactorController.UpgradeHouse()
            end
        end)
    end
    order += 1

    -- TARJETA DE TORRE TESLA AUTOMATIZADORA
    local teslaTowers = profile.TeslaTowers or 0
    local maxTowers = GameConfig.TESLA_TOWER.MaxCount
    local teslaCost = math.floor(GameConfig.TESLA_TOWER.BaseCost * (GameConfig.TESLA_TOWER.CostMultiplier ^ teslaTowers))
    local canAffordTesla = profile.Energy >= teslaCost

    local teslaCard = Instance.new("Frame")
    teslaCard.Name = "UpgradeCard_Tesla"
    teslaCard.Size = UDim2.new(1, -8, 0, 74)
    teslaCard.BackgroundColor3 = Color3.fromRGB(20, 30, 48)
    teslaCard.LayoutOrder = order
    teslaCard.Parent = UpgradesContainer
    CreateCorner(teslaCard, 10)
    CreateStroke(teslaCard, 1.5, palette.CYAN_PLASMA)
    AddModernGradient(teslaCard, Color3.fromRGB(22, 36, 58), Color3.fromRGB(14, 22, 38))

    local teslaName = Instance.new("TextLabel")
    teslaName.Size = UDim2.new(0.65, 0, 0.45, 0)
    teslaName.Position = UDim2.new(0, 8, 0, 6)
    teslaName.BackgroundTransparency = 1
    teslaName.Font = Enum.Font.GothamBold
    teslaName.Text = string.format("⚡ Torre Tesla [%d/%d]", teslaTowers, maxTowers)
    teslaName.TextColor3 = palette.CYAN_PLASMA
    teslaName.TextXAlignment = Enum.TextXAlignment.Left
    teslaName.TextSize = 13
    teslaName.Parent = teslaCard

    local teslaDesc = Instance.new("TextLabel")
    teslaDesc.Size = UDim2.new(0.65, 0, 0.48, 0)
    teslaDesc.Position = UDim2.new(0, 8, 0.48, 0)
    teslaDesc.BackgroundTransparency = 1
    teslaDesc.Font = Enum.Font.Gotham
    teslaDesc.Text = "Dispara rayos cada 3.5s (+60 Energía / +12 XP)"
    teslaDesc.TextColor3 = Color3.fromRGB(170, 210, 240)
    teslaDesc.TextXAlignment = Enum.TextXAlignment.Left
    teslaDesc.TextSize = 11
    teslaDesc.Parent = teslaCard

    if teslaTowers < maxTowers then
        local teslaBuyBtn = Instance.new("TextButton")
        teslaBuyBtn.Name = "BuyTeslaBtn"
        teslaBuyBtn.Size = UDim2.new(0.3, 0, 0.75, 0)
        teslaBuyBtn.Position = UDim2.new(0.68, 0, 0.12, 0)
        teslaBuyBtn.BackgroundColor3 = canAffordTesla and palette.ELECTRIC_COBALT or Color3.fromRGB(50, 55, 70)
        teslaBuyBtn.Font = Enum.Font.FredokaOne
        teslaBuyBtn.Text = "⚡ " .. FormatNumber.FormatCompact(teslaCost)
        teslaBuyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        teslaBuyBtn.TextSize = 12
        teslaBuyBtn.Parent = teslaCard
        CreateCorner(teslaBuyBtn, 8)
        if canAffordTesla then
            CreateStroke(teslaBuyBtn, 1.5, palette.CYAN_PLASMA)
        end

        teslaBuyBtn.MouseButton1Click:Connect(function()
            if profile.Energy >= teslaCost then
                ReactorController.BuyTeslaTower()
            end
        end)
    end
    order += 1

    UpgradesContainer.CanvasSize = UDim2.new(0, 0, 0, order * 82)
end

-- Actualiza reactivamente toda la UI con los datos del servidor
function UIController.UpdateFromProfile(profile: Types.PlayerProfile)
    CachedProfile = profile

    -- 1. Actualizar texto de Energía con Number Lerp fluido y pulso
    if profile.Energy > TargetEnergy and (profile.Energy - TargetEnergy) >= 50 then
        PulseEnergyLabel()
    end
    TargetEnergy = profile.Energy

    -- 2. Actualizar Título de Aura y Rango de Nivel
    local level = profile.AuraLevel or 1
    local rankTitle, rankColor = GameConfig.GetAuraRank(level)
    AuraTitleLabel.Text = string.format("[Nv. %d] %s - %s", level, rankTitle, profile.CurrentAura)
    AuraTitleLabel.TextColor3 = rankColor

    -- Actualizar barra de XP de Aura
    local topFrame = ScreenGui:FindFirstChild("TopHUD")
    if topFrame then
        local xpBarBg = topFrame:FindFirstChild("AuraXPBarBg")
        if xpBarBg then
            local xpFill = xpBarBg:FindFirstChild("AuraXPFill") :: Frame?
            local xpText = xpBarBg:FindFirstChild("AuraXPText") :: TextLabel?

            if xpFill and xpText then
                local xpRatio = math.clamp(profile.AuraXP / math.max(1, profile.AuraXPNext), 0, 1)
                TweenService:Create(xpFill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    Size = UDim2.fromScale(xpRatio, 1)
                }):Play()
                xpText.Text = string.format("XP: %d / %d (Nv. %d)", profile.AuraXP, profile.AuraXPNext, level)
            end
        end
    end

    -- 3. Actualizar Barra de Sobrecarga
    local progressRatio = math.clamp(profile.OverchargeMeter / profile.MaxOvercharge, 0, 1)
    TweenService:Create(OverchargeFill, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.fromScale(progressRatio, 1)
    }):Play()

    OverchargeLabel.Text = string.format("SOBRECARGA: %.0f%%", progressRatio * 100)

    -- 4. Actualizar lista de mejoras
    RenderUpgrades(profile)
end

-- Abre el modal del núcleo (por ejemplo si tocas el reactor 3D)
function UIController.OpenReactorModal()
    AnimateModalToggle(ReactorModal, true)
    AnimateModalToggle(ShopModal, false)
end

-- Abre la tienda de mejoras
function UIController.OpenShopModal()
    AnimateModalToggle(ShopModal, true)
    AnimateModalToggle(ReactorModal, false)
end

-- Modo Cinemático: Oculta o muestra toda la interfaz gráfica de usuario
function UIController.ToggleCinematicMode()
    if ScreenGui then
        ScreenGui.Enabled = not ScreenGui.Enabled
    end
end

return UIController
