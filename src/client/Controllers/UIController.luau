--!strict
-- UIController: Interfaz gráfica limpia, moderna y con ventanas desplegables (Modales con botón de cerrar [X])
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("OverchargedShared")
local Types = require(Shared.Types.GameTypes)
local GameConfig = require(Shared.Config.GameConfig)
local FormatNumber = require(Shared.Utils.FormatNumber)
local SoundUtil = require(Shared.Utils.SoundUtil)

local ReactorController = require(script.Parent.ReactorController)
local CameraController = require(script.Parent.CameraController)

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
local OverchargeBarBg: Frame
local OverchargeLabel: TextLabel
local OverchargeReadyStroke: UIStroke
local OverchargeShine: Frame

local ShopModal: Frame
local UpgradesContainer: ScrollingFrame

local NotificationBanner: TextLabel
local CachedProfile: Types.PlayerProfile? = nil

-- Estado de la animación de sobrecarga
local FXOverlay: Frame
local CoreGlowStroke: UIStroke
local CoreGlowPulse: Frame
local CoreOrbit: Frame
local CoreSpinLevel = 1
local CoreElectrons: { {
    Frame: Frame,
    RadiusX: number,
    RadiusY: number,
    Rotation: number,
    Speed: number,
    Phase: number,
} } = {}
local LastOverchargeRatio = 0

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

-- Centro en pantalla del núcleo (o del viewport si el modal está cerrado)
local function GetCoreCenter(): Vector2
    if ReactorModal and ReactorModal.Visible and CoreButton then
        local pos = CoreButton.AbsolutePosition
        local size = CoreButton.AbsoluteSize
        if size.X > 0 and size.Y > 0 then
            return Vector2.new(pos.X + size.X / 2, pos.Y + size.Y / 2)
        end
    end
    local camera = Workspace.CurrentCamera
    if camera then
        local vp = camera.ViewportSize
        return Vector2.new(vp.X / 2, vp.Y / 2)
    end
    return Vector2.new(400, 300)
end

-- Destello de pantalla completa (flash de sobrecarga)
local function PlayScreenFlash(color: Color3)
    if not FXOverlay then return end

    local flash = Instance.new("Frame")
    flash.Name = "BurstFlash"
    flash.Size = UDim2.fromScale(1, 1)
    flash.BackgroundColor3 = color
    flash.BackgroundTransparency = 0.55
    flash.BorderSizePixel = 0
    flash.Active = false
    flash.ZIndex = 2
    flash.Parent = FXOverlay

    TweenService:Create(flash, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundTransparency = 1,
    }):Play()

    task.delay(0.55, function()
        if flash and flash.Parent then flash:Destroy() end
    end)
end

-- Onda expansiva circular desde un punto de pantalla
local function SpawnShockwaveRing(center: Vector2, color: Color3, startDiameter: number, endDiameter: number, duration: number?)
    if not FXOverlay then return end

    local ring = Instance.new("Frame")
    ring.Name = "BurstRing"
    ring.AnchorPoint = Vector2.new(0.5, 0.5)
    ring.Position = UDim2.fromOffset(math.floor(center.X), math.floor(center.Y))
    ring.Size = UDim2.fromOffset(startDiameter, startDiameter)
    ring.BackgroundTransparency = 1
    ring.BorderSizePixel = 0
    ring.Active = false
    ring.ZIndex = 1
    ring.Parent = FXOverlay

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.5, 0)
    corner.Parent = ring

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 6
    stroke.Color = color
    stroke.Transparency = 0.1
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = ring

    local d = duration or 0.65
    TweenService:Create(ring, TweenInfo.new(d, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Size = UDim2.fromOffset(endDiameter, endDiameter),
    }):Play()
    TweenService:Create(stroke, TweenInfo.new(d, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Transparency = 1,
        Thickness = 1,
    }):Play()

    task.delay(d + 0.05, function()
        if ring and ring.Parent then ring:Destroy() end
    end)
end

-- Explosión de partículas de "champaña" (pop de dopamina)
local function SpawnParticleBurst(center: Vector2, colorA: Color3, colorB: Color3, count: number)
    if not FXOverlay then return end

    for i = 1, count do
        local dot = Instance.new("Frame")
        dot.Name = "BurstParticle"
        dot.AnchorPoint = Vector2.new(0.5, 0.5)
        dot.Position = UDim2.fromOffset(math.floor(center.X), math.floor(center.Y))
        local size = math.random(8, 16)
        dot.Size = UDim2.fromOffset(size, size)
        dot.BackgroundColor3 = (i % 2 == 0) and colorA or colorB
        dot.BorderSizePixel = 0
        dot.Active = false
        dot.ZIndex = 3
        dot.Parent = FXOverlay

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = dot

        local angle = (i / count) * math.pi * 2 + math.random() * 0.5
        local dist = math.random(140, 360)
        local targetX = center.X + math.cos(angle) * dist
        local targetY = center.Y + math.sin(angle) * dist
        local dur = 0.6 + math.random() * 0.25

        TweenService:Create(dot, TweenInfo.new(dur, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Position = UDim2.fromOffset(math.floor(targetX), math.floor(targetY)),
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(2, 2),
        }):Play()

        task.delay(dur + 0.05, function()
            if dot and dot.Parent then dot:Destroy() end
        end)
    end
end

-- Esquinas decorativas estilo HUD premium
local function AddCornerAccents(parent: GuiObject, color: Color3, length: number, thickness: number)
    local corners = {
        { ax = 0, ay = 0, px = 0, py = 0 },
        { ax = 1, ay = 0, px = 1, py = 0 },
        { ax = 0, ay = 1, px = 0, py = 1 },
        { ax = 1, ay = 1, px = 1, py = 1 },
    }

    for _, c in ipairs(corners) do
        local h = Instance.new("Frame")
        h.Name = "CornerAccentH"
        h.BackgroundColor3 = color
        h.BackgroundTransparency = 0.15
        h.BorderSizePixel = 0
        h.Size = UDim2.fromOffset(length, thickness)
        h.AnchorPoint = Vector2.new(c.ax, c.ay)
        h.Position = UDim2.new(c.px, 0, c.py, 0)
        h.ZIndex = 4
        h.Parent = parent

        local v = Instance.new("Frame")
        v.Name = "CornerAccentV"
        v.BackgroundColor3 = color
        v.BackgroundTransparency = 0.15
        v.BorderSizePixel = 0
        v.Size = UDim2.fromOffset(thickness, length)
        v.AnchorPoint = Vector2.new(c.ax, c.ay)
        v.Position = UDim2.new(c.px, 0, c.py, 0)
        v.ZIndex = 4
        v.Parent = parent
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

    -- Capa de efectos (destellos, ondas y partículas de sobrecarga)
    FXOverlay = Instance.new("Frame")
    FXOverlay.Name = "FXOverlay"
    FXOverlay.Size = UDim2.fromScale(1, 1)
    FXOverlay.BackgroundTransparency = 1
    FXOverlay.Active = false
    FXOverlay.ZIndex = 200
    FXOverlay.Parent = ScreenGui

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

    -- ═══ LOGO / WORDMARK DEL JUEGO (esquina superior izquierda, branding con degradado) ═══
    local wordmark = Instance.new("TextLabel")
    wordmark.Name = "GameWordmark"
    wordmark.Size = UDim2.fromOffset(280, 40)
    wordmark.Position = UDim2.new(0, 18, 0, 16)
    wordmark.BackgroundTransparency = 1
    wordmark.Font = Enum.Font.FredokaOne
    wordmark.Text = "OVERCHARGED"
    wordmark.TextColor3 = Color3.fromRGB(255, 255, 255)
    wordmark.TextXAlignment = Enum.TextXAlignment.Left
    wordmark.TextYAlignment = Enum.TextYAlignment.Center
    wordmark.TextSize = 30
    wordmark.Parent = ScreenGui

    local wordmarkStroke = Instance.new("UIStroke")
    wordmarkStroke.Thickness = 2.5
    wordmarkStroke.Color = Color3.fromRGB(0, 0, 0)
    wordmarkStroke.Parent = wordmark

    local wordmarkGradient = Instance.new("UIGradient")
    wordmarkGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, palette.ENERGY_GOLD),
        ColorSequenceKeypoint.new(0.5, palette.CYAN_PLASMA),
        ColorSequenceKeypoint.new(1, palette.MINT_OASIS),
    })
    wordmarkGradient.Parent = wordmark

    local wordmarkSub = Instance.new("TextLabel")
    wordmarkSub.Name = "GameWordmarkSub"
    wordmarkSub.Size = UDim2.fromOffset(280, 16)
    wordmarkSub.Position = UDim2.new(0, 20, 0, 52)
    wordmarkSub.BackgroundTransparency = 1
    wordmarkSub.Font = Enum.Font.GothamBold
    wordmarkSub.Text = "⚡ AURA FARMING ARENA ⚡"
    wordmarkSub.TextColor3 = palette.CYAN_PLASMA
    wordmarkSub.TextXAlignment = Enum.TextXAlignment.Left
    wordmarkSub.TextSize = 12
    wordmarkSub.Parent = ScreenGui

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
    AddCornerAccents(ReactorModal, palette.CYAN_PLASMA, 20, 3)
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

    local reactorTitleStroke = Instance.new("UIStroke")
    reactorTitleStroke.Thickness = 1.5
    reactorTitleStroke.Color = Color3.fromRGB(0, 0, 0)
    reactorTitleStroke.Parent = reactorTitle

    local reactorTitleGradient = Instance.new("UIGradient")
    reactorTitleGradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), palette.CYAN_PLASMA)
    reactorTitleGradient.Parent = reactorTitle

    local reactorDivider = Instance.new("Frame")
    reactorDivider.Name = "ReactorDivider"
    reactorDivider.Size = UDim2.new(1, -30, 0, 2)
    reactorDivider.Position = UDim2.new(0, 15, 0, 45)
    reactorDivider.BackgroundColor3 = palette.CYAN_PLASMA
    reactorDivider.BackgroundTransparency = 0.35
    reactorDivider.BorderSizePixel = 0
    reactorDivider.ZIndex = 3
    reactorDivider.Parent = ReactorModal

    -- ═══ LOGO DEL REACTOR: Emblema atómico procedural (discos, anillos orbitales y electrones) ═══
    local coreCenterWrapper = Instance.new("Frame")
    coreCenterWrapper.Name = "CoreCenterWrapper"
    coreCenterWrapper.Size = UDim2.fromOffset(180, 180)
    coreCenterWrapper.Position = UDim2.new(0.5, -90, 0, 58)
    coreCenterWrapper.BackgroundTransparency = 1
    coreCenterWrapper.Parent = ReactorModal

    -- Halo de resplandor detrás del núcleo (late al acercarse al 100%)
    CoreGlowPulse = Instance.new("Frame")
    CoreGlowPulse.Name = "CoreGlowPulse"
    CoreGlowPulse.AnchorPoint = Vector2.new(0.5, 0.5)
    CoreGlowPulse.Position = UDim2.fromScale(0.5, 0.5)
    CoreGlowPulse.Size = UDim2.fromScale(1.15, 1.15)
    CoreGlowPulse.BackgroundColor3 = palette.CYAN_PLASMA
    CoreGlowPulse.BackgroundTransparency = 0.9
    CoreGlowPulse.BorderSizePixel = 0
    CoreGlowPulse.ZIndex = 0
    CoreGlowPulse.Parent = coreCenterWrapper
    CreateCorner(CoreGlowPulse, 1000)

    CoreButton = Instance.new("TextButton")
    CoreButton.Name = "ReactorCore"
    CoreButton.AnchorPoint = Vector2.new(0.5, 0.5)
    CoreButton.Position = UDim2.fromScale(0.5, 0.5)
    CoreButton.Size = UDim2.fromScale(1, 1)
    CoreButton.BackgroundColor3 = palette.ELECTRIC_COBALT
    CoreButton.BackgroundTransparency = 0.06
    CoreButton.Text = ""
    CoreButton.AutoButtonColor = false
    CoreButton.ZIndex = 2
    CoreButton.Parent = coreCenterWrapper
    CreateCorner(CoreButton, 1000)

    local coreGrad = Instance.new("UIGradient")
    coreGrad.Color = ColorSequence.new(Color3.fromRGB(40, 90, 220), Color3.fromRGB(10, 20, 45))
    coreGrad.Rotation = 90
    coreGrad.Parent = CoreButton

    CoreGlowStroke = CreateStroke(CoreButton, 5, palette.CYAN_PLASMA)

    -- Disco interno pulsante (núcleo de energía)
    local innerDisc = Instance.new("Frame")
    innerDisc.Name = "InnerDisc"
    innerDisc.AnchorPoint = Vector2.new(0.5, 0.5)
    innerDisc.Position = UDim2.fromScale(0.5, 0.5)
    innerDisc.Size = UDim2.fromScale(0.58, 0.58)
    innerDisc.BackgroundColor3 = palette.CYAN_PLASMA
    innerDisc.BackgroundTransparency = 0.55
    innerDisc.BorderSizePixel = 0
    innerDisc.ZIndex = 1
    innerDisc.Parent = CoreButton
    CreateCorner(innerDisc, 1000)

    -- Contenedor de anillos orbitales y electrones
    CoreOrbit = Instance.new("Frame")
    CoreOrbit.Name = "CoreOrbit"
    CoreOrbit.Size = UDim2.fromScale(1, 1)
    CoreOrbit.BackgroundTransparency = 1
    CoreOrbit.ZIndex = 3
    CoreOrbit.Parent = CoreButton

    local orbitDefs = {
        { rx = 0.44, ry = 0.18, rot = 0 },
        { rx = 0.44, ry = 0.18, rot = 60 },
        { rx = 0.44, ry = 0.18, rot = 120 },
    }

    for idx, def in ipairs(orbitDefs) do
        local ring = Instance.new("Frame")
        ring.Name = "OrbitRing_" .. tostring(idx)
        ring.AnchorPoint = Vector2.new(0.5, 0.5)
        ring.Position = UDim2.fromScale(0.5, 0.5)
        ring.Size = UDim2.fromScale(def.rx * 2, def.ry * 2)
        ring.BackgroundTransparency = 1
        ring.Rotation = def.rot
        ring.ZIndex = 3
        ring.Parent = CoreOrbit
        CreateCorner(ring, 1000)

        local ringStroke = Instance.new("UIStroke")
        ringStroke.Thickness = 2
        ringStroke.Color = palette.CYAN_PLASMA
        ringStroke.Transparency = 0.35
        ringStroke.Parent = ring
    end

    -- Electrones orbitales animados
    CoreElectrons = {}
    for idx, def in ipairs(orbitDefs) do
        local electron = Instance.new("Frame")
        electron.Name = "Electron_" .. tostring(idx)
        electron.AnchorPoint = Vector2.new(0.5, 0.5)
        electron.Position = UDim2.fromScale(0.5, 0.5)
        electron.Size = UDim2.fromOffset(11, 11)
        electron.BackgroundColor3 = palette.ENERGY_GOLD
        electron.BorderSizePixel = 0
        electron.ZIndex = 5
        electron.Parent = CoreOrbit
        CreateCorner(electron, 1000)

        local eStroke = Instance.new("UIStroke")
        eStroke.Thickness = 2
        eStroke.Color = Color3.fromRGB(255, 255, 255)
        eStroke.Transparency = 0.2
        eStroke.Parent = electron

        table.insert(CoreElectrons, {
            Frame = electron,
            RadiusX = def.rx,
            RadiusY = def.ry,
            Rotation = math.rad(def.rot),
            Speed = 0.9 + idx * 0.12,
            Phase = idx * 2.0,
        })
    end

    -- Símbolo central del átomo (logo reconocible)
    local coreSymbol = Instance.new("TextLabel")
    coreSymbol.Name = "CoreSymbol"
    coreSymbol.AnchorPoint = Vector2.new(0.5, 0.5)
    coreSymbol.Position = UDim2.fromScale(0.5, 0.5)
    coreSymbol.Size = UDim2.fromScale(1, 1)
    coreSymbol.BackgroundTransparency = 1
    coreSymbol.Font = Enum.Font.FredokaOne
    coreSymbol.Text = "⚛"
    coreSymbol.TextColor3 = Color3.fromRGB(255, 255, 255)
    coreSymbol.TextSize = 62
    coreSymbol.ZIndex = 2
    coreSymbol.Parent = CoreButton

    local symbolStroke = Instance.new("UIStroke")
    symbolStroke.Thickness = 2.5
    symbolStroke.Color = Color3.fromRGB(0, 0, 0)
    symbolStroke.Transparency = 0.35
    symbolStroke.Parent = coreSymbol

    -- Barra de Sobrecarga dentro del modal (marcas, brillo deslizante y alerta de "listo")
    OverchargeBarBg = Instance.new("Frame")
    OverchargeBarBg.Name = "OverchargeBarBg"
    OverchargeBarBg.Size = UDim2.new(1, -40, 0, 28)
    OverchargeBarBg.Position = UDim2.new(0, 20, 0, 250)
    OverchargeBarBg.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
    OverchargeBarBg.Parent = ReactorModal
    CreateCorner(OverchargeBarBg, 14)
    OverchargeReadyStroke = CreateStroke(OverchargeBarBg, 2, palette.ELECTRIC_COBALT)
    OverchargeReadyStroke.Transparency = 0.5

    OverchargeFill = Instance.new("Frame")
    OverchargeFill.Name = "Fill"
    OverchargeFill.Size = UDim2.fromScale(0, 1)
    OverchargeFill.BackgroundColor3 = palette.ENERGY_GOLD
    OverchargeFill.BorderSizePixel = 0
    OverchargeFill.ClipsDescendants = true
    OverchargeFill.Parent = OverchargeBarBg
    CreateCorner(OverchargeFill, 14)

    local fillGrad = Instance.new("UIGradient")
    fillGrad.Color = ColorSequence.new(Color3.fromRGB(255, 240, 150), palette.ENERGY_GOLD)
    fillGrad.Rotation = 90
    fillGrad.Parent = OverchargeFill

    -- Brillo que recorre la barra
    OverchargeShine = Instance.new("Frame")
    OverchargeShine.Name = "Shine"
    OverchargeShine.Size = UDim2.fromScale(0.18, 1)
    OverchargeShine.Position = UDim2.fromScale(-0.3, 0)
    OverchargeShine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    OverchargeShine.BackgroundTransparency = 0.4
    OverchargeShine.BorderSizePixel = 0
    OverchargeShine.ZIndex = 2
    OverchargeShine.Parent = OverchargeFill

    local shineGrad = Instance.new("UIGradient")
    shineGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.5, 0),
        NumberSequenceKeypoint.new(1, 1),
    })
    shineGrad.Rotation = 0
    shineGrad.Parent = OverchargeShine

    -- Marcas de progreso cada 10%
    for i = 1, 9 do
        local tick = Instance.new("Frame")
        tick.Name = "Tick_" .. tostring(i)
        tick.Size = UDim2.new(0, 1, 0.5, 0)
        tick.Position = UDim2.fromScale(i / 10, 0.25)
        tick.BackgroundColor3 = Color3.fromRGB(90, 110, 150)
        tick.BackgroundTransparency = 0.4
        tick.BorderSizePixel = 0
        tick.ZIndex = 4
        tick.Parent = OverchargeBarBg
    end

    OverchargeLabel = Instance.new("TextLabel")
    OverchargeLabel.Name = "ProgressLabel"
    OverchargeLabel.Size = UDim2.fromScale(1, 1)
    OverchargeLabel.BackgroundTransparency = 1
    OverchargeLabel.Font = Enum.Font.FredokaOne
    OverchargeLabel.Text = "SOBRECARGA: 0%"
    OverchargeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    OverchargeLabel.TextSize = 14
    OverchargeLabel.ZIndex = 5
    OverchargeLabel.Parent = OverchargeBarBg

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

    local shopTitleStroke = Instance.new("UIStroke")
    shopTitleStroke.Thickness = 1.5
    shopTitleStroke.Color = Color3.fromRGB(0, 0, 0)
    shopTitleStroke.Parent = shopTitle

    local shopTitleGradient = Instance.new("UIGradient")
    shopTitleGradient.Color = ColorSequence.new(palette.ENERGY_GOLD, Color3.fromRGB(255, 255, 255))
    shopTitleGradient.Parent = shopTitle

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

    -- Conexión de clic del núcleo con animación Squash & Stretch + feedback extra
    CoreButton.MouseButton1Down:Connect(function()
        local clickPower = 1
        if CachedProfile and CachedProfile.Upgrades["Turbine"] then
            clickPower = math.max(1, CachedProfile.Upgrades["Turbine"].Level)
        end
        ReactorController.HandleCoreClick(CoreButton, clickPower)

        -- Sonido y pequeña onda en cada clic para reforzar la respuesta táctil
        SoundUtil.Play2D(SoundUtil.SOUNDS.CLICK, 0.45, true)
        SpawnShockwaveRing(GetCoreCenter(), palette.CYAN_PLASMA, 20, 190, 0.35)
    end)

    -- Animación continua de electrones orbitales (con aceleración al sobrecargar)
    task.spawn(function()
        local t = 0
        while true do
            task.wait(0.03)
            t += 0.03

            for _, e in ipairs(CoreElectrons) do
                local f = e.Frame
                if f and f.Parent then
                    local ang = t * e.Speed * CoreSpinLevel + e.Phase
                    local x = e.RadiusX * math.cos(ang)
                    local y = e.RadiusY * math.sin(ang)
                    local cosR = math.cos(e.Rotation)
                    local sinR = math.sin(e.Rotation)
                    local rx = x * cosR - y * sinR
                    local ry = x * sinR + y * cosR
                    f.Position = UDim2.fromScale(0.5 + rx, 0.5 + ry)
                end
            end

            -- Decaimiento suave del impulso de giro tras una sobrecarga
            if CoreSpinLevel > 1 then
                CoreSpinLevel += (1 - CoreSpinLevel) * 0.06
                if CoreSpinLevel < 1.02 then
                    CoreSpinLevel = 1
                end
            end
        end
    end)

    -- Brillo deslizante sobre la barra de sobrecarga
    task.spawn(function()
        while true do
            if OverchargeShine and OverchargeShine.Parent then
                OverchargeShine.Position = UDim2.fromScale(-0.3, 0)
                TweenService:Create(OverchargeShine, TweenInfo.new(0.85, Enum.EasingStyle.Linear), {
                    Position = UDim2.fromScale(1.1, 0),
                }):Play()
            end
            task.wait(1.5)
        end
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

-- Celebración de sobrecarga completada: el pico de dopamina del jugador
function UIController.PlayOverchargeBurst()
    local palette = GameConfig.PALETTE
    local gold = palette.ENERGY_GOLD
    local cyan = palette.CYAN_PLASMA
    local center = GetCoreCenter()

    -- Capa de sonido: impacto pesado + confirmación brillante
    SoundUtil.Play2D(SoundUtil.SOUNDS.AURA_ACTIVATE, 1, false)
    task.delay(0.05, function()
        SoundUtil.Play2D(SoundUtil.SOUNDS.LEVEL_UP, 0.7, false)
    end)

    -- Destello de pantalla y ondas expansivas
    PlayScreenFlash(cyan)
    SpawnShockwaveRing(center, gold, 30, 1100, 0.7)
    SpawnShockwaveRing(center, cyan, 10, 750, 0.55)
    SpawnParticleBurst(center, gold, cyan, 30)

    -- Texto flotante celebratorio
    ReactorController.SpawnFloatingText(center, "¡SOBRECARGA!", gold)
    ReactorController.SpawnFloatingText(Vector2.new(center.X, center.Y + 28), "¡AURA DESBLOQUEADA!", cyan)

    -- Salto elástico y giro acelerado del logo
    CoreSpinLevel = 9
    if CoreButton then
        local scale = CoreButton:FindFirstChildOfClass("UIScale")
        if not scale then
            scale = Instance.new("UIScale")
            scale.Parent = CoreButton
        end
        scale.Scale = 1
        TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.32 }):Play()
        task.delay(0.13, function()
            if scale and scale.Parent then
                TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Scale = 1 }):Play()
            end
        end)
    end

    -- El anillo exterior destella y el halo pulsa
    if CoreGlowStroke then
        CoreGlowStroke.Thickness = 10
        CoreGlowStroke.Transparency = 0
        TweenService:Create(CoreGlowStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Thickness = 5,
        }):Play()
    end

    if CoreGlowPulse then
        CoreGlowPulse.BackgroundTransparency = 0.3
        TweenService:Create(CoreGlowPulse, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundTransparency = 0.9,
        }):Play()
    end

    -- La barra destella a blanco y da una palmada
    if OverchargeFill then
        OverchargeFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        TweenService:Create(OverchargeFill, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundColor3 = gold,
        }):Play()
    end

    if OverchargeBarBg then
        local barScale = OverchargeBarBg:FindFirstChildOfClass("UIScale")
        if not barScale then
            barScale = Instance.new("UIScale")
            barScale.Parent = OverchargeBarBg
        end
        barScale.Scale = 1
        TweenService:Create(barScale, TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.12 }):Play()
        task.delay(0.12, function()
            if barScale and barScale.Parent then
                TweenService:Create(barScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
            end
        end)
    end

    -- Sacudida de cámara + micro-parón para vender el impacto
    CameraController.Shake(1.4, 0.45, 30)
    CameraController.ApplyHitstop()
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

    -- Detección de sobrecarga completada: la barra cae de casi llena a 0 al hacer roll
    if LastOverchargeRatio >= 0.75 and progressRatio < (LastOverchargeRatio - 0.3) then
        UIController.PlayOverchargeBurst()
    end
    LastOverchargeRatio = progressRatio

    TweenService:Create(OverchargeFill, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.fromScale(progressRatio, 1)
    }):Play()

    OverchargeLabel.Text = string.format("SOBRECARGA: %.0f%%", progressRatio * 100)

    -- Anticipación: la barra se enciende y el núcleo late al acercarse al 100%
    local hot = progressRatio >= 0.8
    if OverchargeReadyStroke then
        OverchargeReadyStroke.Transparency = hot and 0 or 0.5
        OverchargeReadyStroke.Color = hot and GameConfig.PALETTE.ENERGY_GOLD or GameConfig.PALETTE.ELECTRIC_COBALT
    end
    if CoreGlowPulse then
        local glowScale = hot and 1.22 or 1.15
        TweenService:Create(CoreGlowPulse, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.fromScale(glowScale, glowScale),
        }):Play()
    end

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
