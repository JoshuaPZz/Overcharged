--!strict
-- AuraService: Visualización física y escalamiento visual épico según Nivel y Rareza de Aura
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("OverchargedShared")
local Types = require(Shared.Types.GameTypes)
local GameConfig = require(Shared.Config.GameConfig)
local AuraVFXModule = require(Shared.VFX.AuraVFXModule)
local SoundUtil = require(Shared.Utils.SoundUtil)

local AuraService = {}

-- Busca la definición de un Aura por su nombre
function AuraService.GetAuraByName(auraName: string): Types.AuraDefinition
    for _, aura in ipairs(GameConfig.AURAS) do
        if aura.Name == auraName then
            return aura
        end
    end
    return GameConfig.AURAS[1]
end

-- Limpia todos los efectos visuales previos en el personaje
local function ClearPreviousAuras(character: Model)
    for _, obj in ipairs(character:GetDescendants()) do
        if obj.Name == "AuraBillboard" or obj.Name == "AuraEffectFolder" or obj.Name == "AuraTrail" then
            obj:Destroy()
        end
    end
end

-- Crea un Trail (estela de movimiento) luminoso al correr
local function CreateAuraTrail(character: Model, colorA: Color3, colorB: Color3)
    local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not root then return end

    local attTop = Instance.new("Attachment")
    attTop.Name = "AuraTrail_Top"
    attTop.Position = Vector3.new(0, 1.8, 0)
    attTop.Parent = root

    local attBottom = Instance.new("Attachment")
    attBottom.Name = "AuraTrail_Bottom"
    attBottom.Position = Vector3.new(0, -1.8, 0)
    attBottom.Parent = root

    local trail = Instance.new("Trail")
    trail.Name = "AuraTrail"
    trail.Attachment0 = attTop
    trail.Attachment1 = attBottom
    trail.Color = ColorSequence.new(colorA, colorB)
    trail.Lifetime = 0.4
    trail.LightEmission = 0.9
    trail.LightInfluence = 0
    trail.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    trail.TextureLength = 1.6
    trail.TextureMode = Enum.TextureMode.Stretch
    trail.WidthScale = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(1, 0),
    })
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.15),
        NumberSequenceKeypoint.new(0.6, 0.4),
        NumberSequenceKeypoint.new(1, 1),
    })
    trail.Parent = root
end

-- Crea un Halo o Corona de energía sobre la cabeza (Nivel 75+)
local function CreateAuraHalo(head: BasePart, color: Color3, parentFolder: Folder)
    local halo = Instance.new("Part")
    halo.Name = "AuraHalo"
    halo.Shape = Enum.PartType.Cylinder
    halo.Size = Vector3.new(0.2, 3, 3)
    halo.CFrame = head.CFrame * CFrame.new(0, 1.8, 0) * CFrame.Angles(0, 0, math.rad(90))
    halo.Material = Enum.Material.Neon
    halo.Color = color
    halo.CanCollide = false
    halo.Massless = true
    halo.CastShadow = false
    halo.Parent = parentFolder

    local weld = Instance.new("WeldConstraint")
    weld.Part0 = head
    weld.Part1 = halo
    weld.Parent = halo

    -- Chispas doradas desprendiéndose del halo
    local att = Instance.new("Attachment", halo)
    local emit = Instance.new("ParticleEmitter")
    emit.Name = "HaloSparks"
    emit.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    emit.Rate = 18
    emit.Speed = NumberRange.new(0.5, 1.8)
    emit.Lifetime = NumberRange.new(0.5, 1.1)
    emit.Color = ColorSequence.new(color)
    emit.LightEmission = 1
    emit.Size = NumberSequence.new(0.45, 0)
    emit.SpreadAngle = Vector2.new(180, 180)
    emit.Parent = att
end

-- Construye las Alas de Plasma de Neón (Nivel 150+)
local function CreateEnergyWings(torso: BasePart, colorA: Color3, colorB: Color3, parentFolder: Folder, isDouble: boolean)
    local wingAngles = { { -1, 35 }, { 1, -35 } }
    if isDouble then
        table.insert(wingAngles, { -1, 65 })
        table.insert(wingAngles, { 1, -65 })
    end

    for idx, data in ipairs(wingAngles) do
        local side = data[1]
        local angleDeg = data[2]

        local wing = Instance.new("Part")
        wing.Name = "EnergyWing_" .. tostring(idx)
        wing.Size = Vector3.new(0.25, 4.5, 1.2)
        wing.CFrame = torso.CFrame * CFrame.new(side * 1.8, 1.2, 0.6) * CFrame.Angles(0, math.rad(side * 20), math.rad(angleDeg))
        wing.Material = Enum.Material.Neon
        wing.Color = (idx <= 2) and colorA or colorB
        wing.CanCollide = false
        wing.Massless = true
        wing.CastShadow = false
        wing.Parent = parentFolder

        local weld = Instance.new("WeldConstraint")
        weld.Part0 = torso
        weld.Part1 = wing
        weld.Parent = wing

        -- Núcleo brillante interior de cada ala (doble capa para mayor volumen)
        local wingCore = Instance.new("Part")
        wingCore.Name = "EnergyWingCore"
        wingCore.Size = Vector3.new(0.3, 3.6, 0.55)
        wingCore.CFrame = wing.CFrame
        wingCore.Shape = Enum.PartType.Block
        wingCore.Material = Enum.Material.Neon
        wingCore.Color = Color3.new(1, 1, 1)
        wingCore.Transparency = 0.35
        wingCore.CanCollide = false
        wingCore.Massless = true
        wingCore.CastShadow = false
        wingCore.Parent = parentFolder

        local coreWeld = Instance.new("WeldConstraint")
        coreWeld.Part0 = wing
        coreWeld.Part1 = wingCore
        coreWeld.Parent = wingCore

        -- Partículas desprendiéndose de las alas
        local att = Instance.new("Attachment", wing)
        local emit = Instance.new("ParticleEmitter")
        emit.Name = "WingSparks"
        emit.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        emit.Rate = 16
        emit.Speed = NumberRange.new(1, 3)
        emit.SpreadAngle = Vector2.new(60, 60)
        emit.Lifetime = NumberRange.new(0.4, 0.9)
        emit.Color = ColorSequence.new(colorA, colorB)
        emit.LightEmission = 1
        emit.Size = NumberSequence.new(0.6, 0)
        emit.Parent = att
    end
end

-- Equipa la representación visual del Aura y escalamiento según nivel
function AuraService.ApplyAuraToCharacter(player: Player, auraName: string)
    local character = player.Character
    if not character then return end

    local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
    local head = character:WaitForChild("Head", 5) :: BasePart?
    local torso = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
    if not humanoidRootPart or not head or not torso then return end

    local auraDef = AuraService.GetAuraByName(auraName)
    local DataService = require(script.Parent.DataService)
    local profile = DataService.GetProfile(player)
    local level = profile and profile.AuraLevel or 1

    -- Limpieza previa
    ClearPreviousAuras(character)

    local effectFolder = Instance.new("Folder")
    effectFolder.Name = "AuraEffectFolder"
    effectFolder.Parent = character

    -- 1. BILLBOARD GUI MULTINIVEL DE PRESTIGIO (Compacto y Elevado para no tapar la vista)
    local rankTitle, rankColor = GameConfig.GetAuraRank(level)

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "AuraBillboard"
    billboard.Size = UDim2.fromOffset(220, 48)
    billboard.StudsOffset = Vector3.new(0, 4.8, 0)
    billboard.AlwaysOnTop = false -- Permite oclusión natural sin tapar la pantalla
    billboard.PlayerToHideFrom = player -- Oculta su propio título para no estorbar la cámara en 3ra persona
    billboard.Adornee = head
    billboard.MaxDistance = 65
    billboard.Parent = head

    -- Nivel y Rango
    local rankLabel = Instance.new("TextLabel")
    rankLabel.Size = UDim2.new(1, 0, 0, 18)
    rankLabel.Position = UDim2.new(0, 0, 0, 0)
    rankLabel.BackgroundTransparency = 1
    rankLabel.Text = "[Nv. " .. tostring(level) .. "] ⭐ " .. rankTitle
    rankLabel.TextColor3 = rankColor
    rankLabel.TextSize = 13
    rankLabel.Font = Enum.Font.FredokaOne
    rankLabel.Parent = billboard

    local rankStroke = Instance.new("UIStroke")
    rankStroke.Thickness = 1.5
    rankStroke.Color = Color3.new(0, 0, 0)
    rankStroke.Parent = rankLabel

    local rankGradient = Instance.new("UIGradient")
    rankGradient.Color = ColorSequence.new(rankColor, Color3.fromRGB(255, 255, 255))
    rankGradient.Parent = rankLabel

    -- Título de Aura
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0, 16)
    titleLabel.Position = UDim2.new(0, 0, 0, 18)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = auraDef.Title
    titleLabel.TextColor3 = auraDef.RarityColor
    titleLabel.TextSize = 12
    titleLabel.Font = Enum.Font.FredokaOne
    titleLabel.Parent = billboard

    local titleStroke = Instance.new("UIStroke")
    titleStroke.Thickness = 1.5
    titleStroke.Color = Color3.new(0, 0, 0)
    titleStroke.Parent = titleLabel

    local titleGradient = Instance.new("UIGradient")
    titleGradient.Color = ColorSequence.new(auraDef.RarityColor, auraDef.SecondaryColor or Color3.fromRGB(255, 255, 255))
    titleGradient.Parent = titleLabel

    -- Nombre del Jugador
    local playerLabel = Instance.new("TextLabel")
    playerLabel.Size = UDim2.new(1, 0, 0, 12)
    playerLabel.Position = UDim2.new(0, 0, 0, 34)
    playerLabel.BackgroundTransparency = 1
    playerLabel.Text = player.DisplayName
    playerLabel.TextColor3 = Color3.fromRGB(220, 230, 245)
    playerLabel.TextSize = 10
    playerLabel.Font = Enum.Font.GothamBold
    playerLabel.Parent = billboard

    -- 2. SISTEMA DE AURAS PROCEDURALES SOL'S RNG / ANIME AAA
    AuraVFXModule.AttachAuraVFX(character, auraDef, level)

    -- Estela de movimiento luminosa al correr (Nivel 25+)
    if level >= 25 then
        CreateAuraTrail(character, auraDef.RarityColor, auraDef.SecondaryColor or Color3.fromRGB(255, 255, 255))
    end

    -- Halo / corona de energía sobre la cabeza (Nivel 75+)
    if level >= 75 then
        CreateAuraHalo(head, auraDef.RarityColor, effectFolder)
    end

    -- Efecto de alas a nivel alto (150+)
    if level >= 150 then
        local isDoubleWings = level >= 300
        CreateEnergyWings(torso, auraDef.RarityColor, auraDef.SecondaryColor or Color3.fromRGB(255, 255, 255), effectFolder, isDoubleWings)
    end

    -- Sonido 3D envolvente de activación
    SoundUtil.Play3D(SoundUtil.SOUNDS.AURA_ACTIVATE, humanoidRootPart, 0.75, 45)
end

return AuraService
