--!strict
-- MapService: Generación procedural y gestión física del mapa 3D
-- (6 Islas de Jugadores en círculo + 1 Gran Isla Central de Combate)
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("OverchargedShared")
local GameConfig = require(Shared.Config.GameConfig)

local MapService = {}

local MapFolder: Folder
local IslandFolders: { [number]: Folder } = {}
local CenterIslandFolder: Folder

-- Configuración de Iluminación y Post-Procesado Gráfico AAA (Estilo Stylized Moderno / Golden Hour)
local function SetupLighting()
    pcall(function()
        Lighting.Technology = Enum.Technology.Future
    end)

    Lighting.ClockTime = 17.2 -- Atardecer épico dorado
    Lighting.GeographicLatitude = 38
    Lighting.Brightness = 2.5
    Lighting.GlobalShadows = true
    Lighting.ShadowSoftness = 0.15
    Lighting.ExposureCompensation = 0.05
    Lighting.Ambient = Color3.fromRGB(45, 50, 75)
    Lighting.OutdoorAmbient = Color3.fromRGB(90, 100, 140)
    Lighting.EnvironmentDiffuseScale = 1.0
    Lighting.EnvironmentSpecularScale = 1.0

    -- 1. Bloom Effect
    local bloom = Lighting:FindFirstChild("GameBloom") or Instance.new("BloomEffect")
    bloom.Name = "GameBloom"
    bloom.Intensity = 0.8
    bloom.Size = 24
    bloom.Threshold = 1.8
    bloom.Parent = Lighting

    -- 2. Color Correction
    local colorCorrection = Lighting:FindFirstChild("GameColorCorrection") or Instance.new("ColorCorrectionEffect")
    colorCorrection.Name = "GameColorCorrection"
    colorCorrection.Contrast = 0.12
    colorCorrection.Saturation = 0.20
    colorCorrection.TintColor = Color3.fromRGB(250, 248, 255)
    colorCorrection.Parent = Lighting

    -- 3. Atmosphere (Profundidad de vacío flotante de Skywars)
    local atmosphere = Lighting:FindFirstChild("GameAtmosphere") or Instance.new("Atmosphere")
    atmosphere.Name = "GameAtmosphere"
    atmosphere.Density = 0.28
    atmosphere.Offset = 0.25
    atmosphere.Color = Color3.fromRGB(185, 210, 255)
    atmosphere.Decay = Color3.fromRGB(95, 115, 165)
    atmosphere.Glare = 0.30
    atmosphere.Haze = 1.50
    atmosphere.Parent = Lighting

    -- 4. SunRays (Rayos solares estilizados)
    local sunRays = Lighting:FindFirstChild("GameSunRays") or Instance.new("SunRaysEffect")
    sunRays.Name = "GameSunRays"
    sunRays.Intensity = 0.10
    sunRays.Spread = 0.80
    sunRays.Parent = Lighting

    -- 5. Depth of Field (Cinematográfico en islas distantes)
    local dof = Lighting:FindFirstChild("GameDepthOfField") or Instance.new("DepthOfFieldEffect")
    dof.Name = "GameDepthOfField"
    dof.FarIntensity = 0.15
    dof.FocusDistance = 60
    dof.InFocusRadius = 50
    dof.NearIntensity = 0
    dof.Parent = Lighting

    -- 6. Skybox Cósmico / Atardecer
    local sky = Lighting:FindFirstChild("GameSky") or Instance.new("Sky")
    sky.Name = "GameSky"
    sky.SkyboxBk = "rbxassetid://6444884337"
    sky.SkyboxDn = "rbxassetid://6444884785"
    sky.SkyboxFt = "rbxassetid://6444884337"
    sky.SkyboxLf = "rbxassetid://6444884337"
    sky.SkyboxRt = "rbxassetid://6444884337"
    sky.SkyboxUp = "rbxassetid://6444885310"
    sky.StarCount = 3000
    sky.Parent = Lighting

    -- 7. Nubes Volumétricas en el Vacío Inferior
    local terrain = Workspace:FindFirstChildOfClass("Terrain")
    if terrain then
        local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
        clouds.Cover = 0.65
        clouds.Density = 0.70
        clouds.Parent = terrain
    end
end

-- Crea una plataforma circular sólida
local function CreateCylinderPlatform(name: string, position: Vector3, radius: number, thickness: number, material: Enum.Material, color: Color3, parent: Instance): Part
    local part = Instance.new("Part")
    part.Name = name
    part.Shape = Enum.PartType.Cylinder
    part.Size = Vector3.new(thickness, radius * 2, radius * 2)
    part.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
    part.Material = material
    part.Color = color
    part.Anchored = true
    part.CanCollide = true
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.Parent = parent
    return part
end

-- PROPS Y ELEMENTOS AMBIENTALES ESTILIZADOS (Low-Poly PBR / Stylized Modern)

-- Árbol estilizado con follaje cónico escalonado
local function CreateStylizedTree(position: Vector3, parent: Instance): Model
    local model = Instance.new("Model")
    model.Name = "StylizedTree"

    -- Tronco de madera mate
    local trunk = Instance.new("Part")
    trunk.Name = "Trunk"
    trunk.Size = Vector3.new(2.0, 7.5, 2.0)
    trunk.Position = position + Vector3.new(0, 3.75, 0)
    trunk.Material = Enum.Material.SmoothPlastic
    trunk.Color = Color3.fromRGB(68, 48, 36)
    trunk.Anchored = true
    trunk.CanCollide = true
    trunk.Parent = model

    -- 3 Capas de copa verde esmeralda escalonadas
    local leafTiers = {
        { y = 7.0, size = Vector3.new(8.5, 3.2, 8.5), color = Color3.fromRGB(16, 185, 129) },
        { y = 9.5, size = Vector3.new(6.6, 3.0, 6.6), color = Color3.fromRGB(5, 150, 105) },
        { y = 12.0, size = Vector3.new(4.4, 2.8, 4.4), color = Color3.fromRGB(4, 120, 87) },
    }
    for idx, tier in ipairs(leafTiers) do
        local leaves = Instance.new("Part")
        leaves.Name = "Leaves_" .. tostring(idx)
        leaves.Size = tier.size
        leaves.Position = position + Vector3.new(0, tier.y, 0)
        leaves.Material = Enum.Material.SmoothPlastic
        leaves.Color = tier.color
        leaves.Anchored = true
        leaves.CanCollide = true
        leaves.Parent = model
    end

    model.Parent = parent
    return model
end

-- Roca poligonal biselada suave
local function CreateStylizedRock(position: Vector3, size: Vector3, rotY: number, parent: Instance): Part
    local rock = Instance.new("Part")
    rock.Name = "StylizedRock"
    rock.Size = size
    rock.Position = position
    rock.CFrame = CFrame.new(position) * CFrame.Angles(math.rad(10), math.rad(rotY), math.rad(8))
    rock.Material = Enum.Material.SmoothPlastic
    rock.Color = Color3.fromRGB(68, 78, 98)
    rock.Anchored = true
    rock.CanCollide = true
    rock.Parent = parent
    return rock
end

-- Baldosa / Piedra de camino redondeada
local function CreateSteppingStone(position: Vector3, radius: number, parent: Instance): Part
    local stone = Instance.new("Part")
    stone.Name = "SteppingStone"
    stone.Shape = Enum.PartType.Cylinder
    stone.Size = Vector3.new(0.35, radius * 2, radius * 2)
    stone.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
    stone.Material = Enum.Material.SmoothPlastic
    stone.Color = Color3.fromRGB(60, 70, 90)
    stone.Anchored = true
    stone.CanCollide = true
    stone.TopSurface = Enum.SurfaceType.Smooth
    stone.BottomSurface = Enum.SurfaceType.Smooth
    stone.Parent = parent
    return stone
end

-- Flora y hongos luminosos
local function CreateGlowingFlora(position: Vector3, color: Color3, parent: Instance): Model
    local flora = Instance.new("Model")
    flora.Name = "GlowingFlora"

    local stem = Instance.new("Part")
    stem.Size = Vector3.new(0.5, 2.0, 0.5)
    stem.Position = position + Vector3.new(0, 1.0, 0)
    stem.Material = Enum.Material.SmoothPlastic
    stem.Color = Color3.fromRGB(45, 55, 75)
    stem.Anchored = true
    stem.CanCollide = false
    stem.Parent = flora

    local cap = Instance.new("Part")
    cap.Shape = Enum.PartType.Ball
    cap.Size = Vector3.new(2.2, 1.2, 2.2)
    cap.Position = position + Vector3.new(0, 2.2, 0)
    cap.Material = Enum.Material.Neon
    cap.Color = color
    cap.Transparency = 0.2
    cap.Anchored = true
    cap.CanCollide = false
    cap.Parent = flora

    local light = Instance.new("PointLight")
    light.Range = 9
    light.Brightness = 1.0
    light.Color = color
    light.Parent = cap

    flora.Parent = parent
    return flora
end

-- Construye la Gran Isla Central (Coliseo Rúnico, Pilones y Titán de Sobrecarga)
local function BuildCentralIsland()
    CenterIslandFolder = Instance.new("Folder")
    CenterIslandFolder.Name = "CentralIsland"
    CenterIslandFolder.Parent = MapFolder

    local centerPos = Vector3.new(0, GameConfig.ISLAND_HEIGHT, 0)
    local radius = GameConfig.CENTER_ISLAND_RADIUS
    local palette = GameConfig.PALETTE

    -- 1. BASE DEL COLISEO (SmoothPlastic Vinilo PBR, cero texturas de barro)
    local mainPlatform = CreateCylinderPlatform(
        "CentralArenaFloor",
        centerPos,
        radius,
        14,
        Enum.Material.SmoothPlastic,
        palette.DEEP_SLATE,
        CenterIslandFolder
    )

    -- Anillo de borde biselado carmesí (transparencia elegante, no cegadora)
    local neonRing = Instance.new("Part")
    neonRing.Name = "ArenaBorderNeon"
    neonRing.Shape = Enum.PartType.Cylinder
    neonRing.Size = Vector3.new(1.0, radius * 2, radius * 2)
    neonRing.CFrame = CFrame.new(centerPos + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90))
    neonRing.Material = Enum.Material.Neon
    neonRing.Color = palette.CRIMSON_SPARK
    neonRing.Transparency = 0.4
    neonRing.Anchored = true
    neonRing.CanCollide = false
    neonRing.Parent = CenterIslandFolder

    -- Borde de contención exterior
    CreateCylinderPlatform(
        "ArenaOuterCurb",
        centerPos + Vector3.new(0, 0.6, 0),
        radius - 2.5,
        0.8,
        Enum.Material.SmoothPlastic,
        Color3.fromRGB(25, 30, 45),
        CenterIslandFolder
    )

    -- Superficie de combate interior
    CreateCylinderPlatform(
        "BattleRing",
        centerPos + Vector3.new(0, 0.8, 0),
        radius - 6,
        1,
        Enum.Material.SmoothPlastic,
        Color3.fromRGB(34, 40, 58),
        CenterIslandFolder
    )

    -- 2. RUNAS Y LÍNEAS DE ENERGÍA ANCESTRALES (Con opacidad balanceada)
    local function CreateRunicRing(name: string, r: number, color: Color3, yOff: number)
        local ring = Instance.new("Part")
        ring.Name = name
        ring.Shape = Enum.PartType.Cylinder
        ring.Size = Vector3.new(0.12, r * 2, r * 2)
        ring.CFrame = CFrame.new(centerPos + Vector3.new(0, yOff, 0)) * CFrame.Angles(0, 0, math.rad(90))
        ring.Material = Enum.Material.Neon
        ring.Color = color
        ring.Transparency = 0.45
        ring.Anchored = true
        ring.CanCollide = false
        ring.Parent = CenterIslandFolder

        -- Máscara central
        CreateCylinderPlatform(
            name .. "_Mask",
            centerPos + Vector3.new(0, yOff + 0.02, 0),
            r - 2.5,
            0.14,
            Enum.Material.SmoothPlastic,
            Color3.fromRGB(34, 40, 58),
            CenterIslandFolder
        )
    end

    CreateRunicRing("RunicRingOuter", 165, palette.CYAN_PLASMA, 0.84)
    CreateRunicRing("RunicRingMid", 110, palette.MINT_OASIS, 0.86)
    CreateRunicRing("RunicRingInner", 55, palette.CRIMSON_SPARK, 0.88)

    -- Meseta circular intermedia elevada (Zona de Mobs Golem y Cofres de Aura)
    CreateCylinderPlatform(
        "MidPlateauFloor",
        centerPos + Vector3.new(0, 1.2, 0),
        125,
        1.8,
        Enum.Material.SmoothPlastic,
        Color3.fromRGB(36, 44, 66),
        CenterIslandFolder
    )

    -- 8 Columnas y Monolitos de Ruinas Ancestrales en el perímetro intermedio
    for colIdx = 1, 8 do
        local colAngle = (colIdx - 1) * (math.pi / 4) + 0.2
        local colPos = centerPos + Vector3.new(math.cos(colAngle) * 145, 0, math.sin(colAngle) * 145)

        local col = Instance.new("Part")
        col.Name = "AncientRuinCol_" .. tostring(colIdx)
        col.Size = Vector3.new(5.0, 14.0, 5.0)
        col.Position = colPos + Vector3.new(0, 7.0, 0)
        col.Material = Enum.Material.SmoothPlastic
        col.Color = palette.DEEP_SLATE
        col.Anchored = true
        col.CanCollide = true
        col.Parent = CenterIslandFolder

        local cap = Instance.new("Part")
        cap.Size = Vector3.new(3.0, 3.0, 3.0)
        cap.Position = colPos + Vector3.new(0, 15.0, 0)
        cap.Material = Enum.Material.Neon
        cap.Color = palette.CYAN_PLASMA
        cap.Transparency = 0.25
        cap.Anchored = true
        cap.CanCollide = false
        cap.Parent = CenterIslandFolder
    end

    -- FORMACIÓN ROCOSA INFERIOR DE LA GRAN ISLA CONTINENTAL
    local centerRockLayers = {
        { offsetY = -8, radMult = 0.88, thick = 10, color = Color3.fromRGB(32, 38, 55) },
        { offsetY = -20, radMult = 0.65, thick = 16, color = Color3.fromRGB(26, 32, 46) },
        { offsetY = -38, radMult = 0.42, thick = 22, color = Color3.fromRGB(20, 25, 38) },
        { offsetY = -58, radMult = 0.20, thick = 20, color = Color3.fromRGB(16, 20, 30) },
    }
    for idx, layer in ipairs(centerRockLayers) do
        CreateCylinderPlatform(
            "CenterRockUnderlayer_" .. tostring(idx),
            centerPos + Vector3.new(0, layer.offsetY, 0),
            radius * layer.radMult,
            layer.thick,
            Enum.Material.SmoothPlastic,
            layer.color,
            CenterIslandFolder
        )
    end

    -- 6 Líneas de energía radiales elegantes hacia los puentes
    for i = 1, GameConfig.ISLAND_COUNT do
        local angle = (i - 1) * (2 * math.pi / GameConfig.ISLAND_COUNT)
        local strip = Instance.new("Part")
        strip.Name = "EnergyConduit_" .. tostring(i)
        strip.Size = Vector3.new(1.8, 0.15, radius - 26)
        strip.CFrame = CFrame.new(centerPos + Vector3.new(math.cos(angle) * (radius / 2), 0.88, math.sin(angle) * (radius / 2)))
            * CFrame.Angles(0, -angle + math.pi/2, 0)
        strip.Material = Enum.Material.Neon
        strip.Color = palette.CYAN_PLASMA
        strip.Transparency = 0.45
        strip.Anchored = true
        strip.CanCollide = false
        strip.Parent = CenterIslandFolder

        -- Pilón de Energía Perimetral (Monolito cibernético de bienvenida)
        local pylonPos = centerPos + Vector3.new(math.cos(angle) * (radius - 12), 0, math.sin(angle) * (radius - 12))
        local pylonModel = Instance.new("Model")
        pylonModel.Name = "EnergyPylon_" .. tostring(i)

        local pylonBase = Instance.new("Part")
        pylonBase.Size = Vector3.new(4.5, 12, 4.5)
        pylonBase.Position = pylonPos + Vector3.new(0, 6, 0)
        pylonBase.Material = Enum.Material.SmoothPlastic
        pylonBase.Color = palette.DEEP_SLATE
        pylonBase.Anchored = true
        pylonBase.CanCollide = true
        pylonBase.Parent = pylonModel

        local pylonCrystal = Instance.new("Part")
        pylonCrystal.Size = Vector3.new(2.4, 4.5, 2.4)
        pylonCrystal.Position = pylonPos + Vector3.new(0, 14, 0)
        pylonCrystal.CFrame = CFrame.new(pylonPos + Vector3.new(0, 14, 0)) * CFrame.Angles(math.rad(15), math.rad(45), math.rad(10))
        pylonCrystal.Material = Enum.Material.Neon
        pylonCrystal.Color = palette.CYAN_PLASMA
        pylonCrystal.Transparency = 0.2
        pylonCrystal.Anchored = true
        pylonCrystal.CanCollide = false
        pylonCrystal.Parent = pylonModel

        local pLight = Instance.new("PointLight")
        pLight.Range = 16
        pLight.Brightness = 1.2
        pLight.Color = palette.CYAN_PLASMA
        pLight.Parent = pylonCrystal

        pylonModel.Parent = CenterIslandFolder
    end

    -- 3. ALTAR MULTINIVEL Y TITÁN DE SOBRECARGA
    local altarTier1 = CreateCylinderPlatform(
        "TitanAltarT1",
        centerPos + Vector3.new(0, 1.4, 0),
        26,
        2.5,
        Enum.Material.SmoothPlastic,
        palette.DEEP_SLATE,
        CenterIslandFolder
    )
    local altarTier2 = CreateCylinderPlatform(
        "TitanAltarT2",
        centerPos + Vector3.new(0, 3.2, 0),
        19,
        2.5,
        Enum.Material.SmoothPlastic,
        Color3.fromRGB(36, 44, 64),
        CenterIslandFolder
    )
    local altarTrim = CreateCylinderPlatform(
        "TitanAltarTrim",
        centerPos + Vector3.new(0, 4.6, 0),
        19,
        0.4,
        Enum.Material.Neon,
        palette.ENERGY_GOLD,
        CenterIslandFolder
    )
    altarTrim.Transparency = 0.3

    -- MODELO DEL TITÁN DE SOBRECARGA (Esculpido Facetado AAA)
    local titanModel = Instance.new("Model")
    titanModel.Name = "TitanBoss"
    titanModel.Parent = CenterIslandFolder

    local titanOrigin = centerPos + Vector3.new(0, 26, 0)

    -- Torso / Monolito Geométrico
    local torso = Instance.new("Part")
    torso.Name = "TitanTorso"
    torso.Size = Vector3.new(16, 24, 12)
    torso.Position = titanOrigin
    torso.Material = Enum.Material.SmoothPlastic
    torso.Color = palette.DEEP_SLATE
    torso.Anchored = true
    torso.CanCollide = true
    torso.Parent = titanModel

    -- Placa pectoral estilizada
    local chestArmor = Instance.new("Part")
    chestArmor.Size = Vector3.new(14, 14, 3)
    chestArmor.Position = titanOrigin + Vector3.new(0, 2, -5.2)
    chestArmor.Material = Enum.Material.SmoothPlastic
    chestArmor.Color = Color3.fromRGB(38, 48, 72)
    chestArmor.Anchored = true
    chestArmor.CanCollide = true
    chestArmor.Parent = titanModel

    -- Hombreras escalonadas
    local shoulderLeft = Instance.new("Part")
    shoulderLeft.Size = Vector3.new(7, 8, 8)
    shoulderLeft.Position = titanOrigin + Vector3.new(-11, 7, 0)
    shoulderLeft.Material = Enum.Material.SmoothPlastic
    shoulderLeft.Color = Color3.fromRGB(38, 48, 72)
    shoulderLeft.Anchored = true
    shoulderLeft.CanCollide = true
    shoulderLeft.Parent = titanModel

    local shoulderRight = Instance.new("Part")
    shoulderRight.Size = Vector3.new(7, 8, 8)
    shoulderRight.Position = titanOrigin + Vector3.new(11, 7, 0)
    shoulderRight.Material = Enum.Material.SmoothPlastic
    shoulderRight.Color = Color3.fromRGB(38, 48, 72)
    shoulderRight.Anchored = true
    shoulderRight.CanCollide = true
    shoulderRight.Parent = titanModel

    -- Cabeza de Golem Ancestral con corona dorada
    local headPart = Instance.new("Part")
    headPart.Size = Vector3.new(8, 8, 8)
    headPart.Position = titanOrigin + Vector3.new(0, 16, 0)
    headPart.Material = Enum.Material.SmoothPlastic
    headPart.Color = palette.DEEP_SLATE
    headPart.Anchored = true
    headPart.CanCollide = true
    headPart.Parent = titanModel

    local crown = Instance.new("Part")
    crown.Size = Vector3.new(11, 4.5, 7)
    crown.Position = titanOrigin + Vector3.new(0, 21, 0)
    crown.Material = Enum.Material.Neon
    crown.Color = palette.ENERGY_GOLD
    crown.Transparency = 0.2
    crown.Anchored = true
    crown.CanCollide = false
    crown.Parent = titanModel

    -- Visor luminoso en la cabeza
    local visor = Instance.new("Part")
    visor.Size = Vector3.new(6, 1.6, 2)
    visor.Position = titanOrigin + Vector3.new(0, 16.5, -3.8)
    visor.Material = Enum.Material.Neon
    visor.Color = palette.CYAN_PLASMA
    visor.Anchored = true
    visor.CanCollide = false
    visor.Parent = titanModel

    -- OJO CICLÓPEO / NÚCLEO DÉBIL (Punto de impacto clave)
    local weakspot = Instance.new("Part")
    weakspot.Name = "TitanWeakspot"
    weakspot.Shape = Enum.PartType.Ball
    weakspot.Size = Vector3.new(7.2, 7.2, 7.2)
    weakspot.Position = titanOrigin + Vector3.new(0, 2, -6.0)
    weakspot.Material = Enum.Material.Neon
    weakspot.Color = palette.CYAN_PLASMA
    weakspot.Anchored = true
    weakspot.CanCollide = true
    weakspot.Parent = titanModel

    local weakspotLight = Instance.new("PointLight")
    weakspotLight.Range = 40
    weakspotLight.Brightness = 2.0
    weakspotLight.Color = palette.CYAN_PLASMA
    weakspotLight.Parent = weakspot

    -- Anillos de iris protectores
    local irisRing = Instance.new("Part")
    irisRing.Shape = Enum.PartType.Cylinder
    irisRing.Size = Vector3.new(1.0, 9.5, 9.5)
    irisRing.CFrame = CFrame.new(weakspot.Position + Vector3.new(0, 0, 0.4)) * CFrame.Angles(0, math.pi/2, 0)
    irisRing.Material = Enum.Material.Neon
    irisRing.Color = palette.CRIMSON_SPARK
    irisRing.Transparency = 0.3
    irisRing.Anchored = true
    irisRing.CanCollide = false
    irisRing.Parent = titanModel

    -- GUANTELETES FLOTANTES
    local handLeft = Instance.new("Part")
    handLeft.Name = "HandLeft"
    handLeft.Size = Vector3.new(7, 9, 6)
    handLeft.Position = titanOrigin + Vector3.new(-20, -2, -4)
    handLeft.Material = Enum.Material.SmoothPlastic
    handLeft.Color = palette.DEEP_SLATE
    handLeft.Anchored = true
    handLeft.CanCollide = true
    handLeft.Parent = titanModel

    local handLeftNeon = Instance.new("Part")
    handLeftNeon.Size = Vector3.new(5.5, 1.2, 5.5)
    handLeftNeon.Position = handLeft.Position + Vector3.new(0, 4.2, 0)
    handLeftNeon.Material = Enum.Material.Neon
    handLeftNeon.Color = palette.CYAN_PLASMA
    handLeftNeon.Transparency = 0.25
    handLeftNeon.Anchored = true
    handLeftNeon.CanCollide = false
    handLeftNeon.Parent = titanModel

    local handRight = Instance.new("Part")
    handRight.Name = "HandRight"
    handRight.Size = Vector3.new(7, 9, 6)
    handRight.Position = titanOrigin + Vector3.new(20, -2, -4)
    handRight.Material = Enum.Material.SmoothPlastic
    handRight.Color = palette.DEEP_SLATE
    handRight.Anchored = true
    handRight.CanCollide = true
    handRight.Parent = titanModel

    local handRightNeon = Instance.new("Part")
    handRightNeon.Size = Vector3.new(5.5, 1.2, 5.5)
    handRightNeon.Position = handRight.Position + Vector3.new(0, 4.2, 0)
    handRightNeon.Material = Enum.Material.Neon
    handRightNeon.Color = palette.CYAN_PLASMA
    handRightNeon.Transparency = 0.25
    handRightNeon.Anchored = true
    handRightNeon.CanCollide = false
    handRightNeon.Parent = titanModel

    -- BILLBOARD GUI DEL JEFE (Barra de Vida & Título)
    local bossBillboard = Instance.new("BillboardGui")
    bossBillboard.Name = "TitanBossHUD"
    bossBillboard.Size = UDim2.fromScale(14, 4)
    bossBillboard.StudsOffset = Vector3.new(0, 24, 0)
    bossBillboard.AlwaysOnTop = false
    bossBillboard.Adornee = torso
    bossBillboard.MaxDistance = 140
    bossBillboard.Parent = torso

    local bossTitle = Instance.new("TextLabel")
    bossTitle.Size = UDim2.fromScale(1, 0.35)
    bossTitle.Position = UDim2.fromScale(0, 0)
    bossTitle.BackgroundTransparency = 1
    bossTitle.Font = Enum.Font.FredokaOne
    bossTitle.Text = GameConfig.TITAN.Title
    bossTitle.TextColor3 = palette.ENERGY_GOLD
    bossTitle.TextScaled = true
    bossTitle.Parent = bossBillboard
    local titleStroke = Instance.new("UIStroke")
    titleStroke.Thickness = 2
    titleStroke.Color = Color3.new(0, 0, 0)
    titleStroke.Parent = bossTitle

    local hpBg = Instance.new("Frame")
    hpBg.Name = "BossHPBg"
    hpBg.Size = UDim2.fromScale(0.9, 0.28)
    hpBg.Position = UDim2.fromScale(0.05, 0.4)
    hpBg.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
    hpBg.Parent = bossBillboard
    local hpBgCorner = Instance.new("UICorner")
    hpBgCorner.CornerRadius = UDim.new(0, 8)
    hpBgCorner.Parent = hpBg
    local hpStroke = Instance.new("UIStroke")
    hpStroke.Thickness = 2
    hpStroke.Color = palette.CRIMSON_SPARK
    hpStroke.Parent = hpBg

    local hpFill = Instance.new("Frame")
    hpFill.Name = "BossHPFill"
    hpFill.Size = UDim2.fromScale(1, 1)
    hpFill.BackgroundColor3 = palette.CRIMSON_SPARK
    hpFill.BorderSizePixel = 0
    hpFill.Parent = hpBg
    local hpFillCorner = Instance.new("UICorner")
    hpFillCorner.CornerRadius = UDim.new(0, 8)
    hpFillCorner.Parent = hpFill

    local hpText = Instance.new("TextLabel")
    hpText.Name = "BossHPText"
    hpText.Size = UDim2.fromScale(1, 1)
    hpText.BackgroundTransparency = 1
    hpText.Font = Enum.Font.FredokaOne
    hpText.Text = "50,000 / 50,000 HP (Punto Débil: Ojo)"
    hpText.TextColor3 = Color3.fromRGB(255, 255, 255)
    hpText.TextScaled = true
    hpText.ZIndex = 5
    hpText.Parent = hpBg

    local hintSub = Instance.new("TextLabel")
    hintSub.Size = UDim2.fromScale(1, 0.25)
    hintSub.Position = UDim2.fromScale(0, 0.72)
    hintSub.BackgroundTransparency = 1
    hintSub.Font = Enum.Font.GothamBold
    hintSub.Text = "🎯 ¡Ataca el Ojo Central para ganar XP de Aura y Sobre-energía masiva!"
    hintSub.TextColor3 = palette.CYAN_PLASMA
    hintSub.TextScaled = true
    hintSub.Parent = bossBillboard

    -- ANIMACIÓN DE LEVITACIÓN FLOTANTE (Living Hovering Idle)
    task.spawn(function()
        local baseTorsoY = torso.Position.Y
        local baseHandLY = handLeft.Position.Y
        local baseHandRY = handRight.Position.Y
        local t = 0
        while true do
            t += 0.05
            local offset = math.sin(t * 1.5) * 1.6
            local handOffset = math.cos(t * 1.8) * 1.8

            torso.Position = Vector3.new(torso.Position.X, baseTorsoY + offset, torso.Position.Z)
            chestArmor.Position = Vector3.new(chestArmor.Position.X, baseTorsoY + 2 + offset, chestArmor.Position.Z)
            shoulderLeft.Position = Vector3.new(shoulderLeft.Position.X, baseTorsoY + 7 + offset, shoulderLeft.Position.Z)
            shoulderRight.Position = Vector3.new(shoulderRight.Position.X, baseTorsoY + 7 + offset, shoulderRight.Position.Z)
            headPart.Position = Vector3.new(headPart.Position.X, baseTorsoY + 16 + offset, headPart.Position.Z)
            crown.Position = Vector3.new(crown.Position.X, baseTorsoY + 21 + offset, crown.Position.Z)
            visor.Position = Vector3.new(visor.Position.X, baseTorsoY + 16.5 + offset, visor.Position.Z)
            weakspot.Position = Vector3.new(weakspot.Position.X, baseTorsoY + 2 + offset, weakspot.Position.Z)
            irisRing.Position = Vector3.new(irisRing.Position.X, baseTorsoY + 2 + offset, irisRing.Position.Z)

            handLeft.Position = Vector3.new(handLeft.Position.X, baseHandLY + handOffset, handLeft.Position.Z)
            handLeftNeon.Position = Vector3.new(handLeftNeon.Position.X, baseHandLY + 4.2 + handOffset, handLeftNeon.Position.Z)
            handRight.Position = Vector3.new(handRight.Position.X, baseHandRY - handOffset, handRight.Position.Z)
            handRightNeon.Position = Vector3.new(handRightNeon.Position.X, baseHandRY + 4.2 - handOffset, handRightNeon.Position.Z)

            task.wait(0.03)
        end
    end)

    -- 4. VOLUMEN DE DETECCIÓN DE ZONA PvP
    local pvpVolume = Instance.new("Part")
    pvpVolume.Name = "PvPZoneVolume"
    pvpVolume.Shape = Enum.PartType.Cylinder
    pvpVolume.Size = Vector3.new(120, radius * 2, radius * 2)
    pvpVolume.CFrame = CFrame.new(centerPos + Vector3.new(0, 60, 0)) * CFrame.Angles(0, 0, math.rad(90))
    pvpVolume.Transparency = 1
    pvpVolume.Anchored = true
    pvpVolume.CanCollide = false
    pvpVolume.Parent = CenterIslandFolder
end

-- Construye una isla individual de jugador (Lush Stylized Floating Island + Puente Suspendido)
local function BuildPlayerIsland(islandIndex: number)
    local islandFolder = Instance.new("Folder")
    islandFolder.Name = "Island_" .. tostring(islandIndex)
    islandFolder.Parent = MapFolder
    IslandFolders[islandIndex] = islandFolder

    local angle = (islandIndex - 1) * (2 * math.pi / GameConfig.ISLAND_COUNT)
    local islandX = math.cos(angle) * GameConfig.ORBIT_RADIUS
    local islandZ = math.sin(angle) * GameConfig.ORBIT_RADIUS
    local islandPos = Vector3.new(islandX, GameConfig.ISLAND_HEIGHT, islandZ)
    local radius = GameConfig.PLAYER_ISLAND_RADIUS
    local palette = GameConfig.PALETTE

    -- 1. CÉSPED ESTILIZADO DUAL-TONE (SmoothPlastic Verde Menta Vibrante)
    local floor = CreateCylinderPlatform(
        "IslandFloor",
        islandPos,
        radius,
        5.5,
        Enum.Material.SmoothPlastic,
        palette.MINT_OASIS, -- Verde Menta vibrante
        islandFolder
    )

    -- Borde biselado esmeralda
    CreateCylinderPlatform(
        "IslandRimEmerald",
        islandPos + Vector3.new(0, 0.15, 0),
        radius,
        0.5,
        Enum.Material.SmoothPlastic,
        Color3.fromRGB(16, 185, 129),
        islandFolder
    )

    -- Anillo sutil de energía (Transparente y limpio, no cegador)
    local neonBorder = Instance.new("Part")
    neonBorder.Name = "IslandNeonBorder"
    neonBorder.Shape = Enum.PartType.Cylinder
    neonBorder.Size = Vector3.new(0.6, (radius - 1) * 2, (radius - 1) * 2)
    neonBorder.CFrame = CFrame.new(islandPos + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, 0, math.rad(90))
    neonBorder.Material = Enum.Material.Neon
    neonBorder.Color = palette.CYAN_PLASMA
    neonBorder.Transparency = 0.45
    neonBorder.Anchored = true
    neonBorder.CanCollide = false
    neonBorder.Parent = islandFolder

    -- FORMACIÓN ROCOSA INFERIOR (Estalactita de Isla Flotante Fantasy)
    local rockLayers = {
        { offsetY = -5, radMult = 0.88, thick = 6, color = Color3.fromRGB(35, 42, 60) },
        { offsetY = -12, radMult = 0.68, thick = 8, color = Color3.fromRGB(30, 36, 52) },
        { offsetY = -21, radMult = 0.44, thick = 10, color = Color3.fromRGB(25, 30, 44) },
        { offsetY = -32, radMult = 0.22, thick = 12, color = Color3.fromRGB(20, 24, 36) },
    }
    for idx, layer in ipairs(rockLayers) do
        CreateCylinderPlatform(
            "RockUnderlayer_" .. tostring(idx),
            islandPos + Vector3.new(0, layer.offsetY, 0),
            radius * layer.radMult,
            layer.thick,
            Enum.Material.SmoothPlastic,
            layer.color,
            islandFolder
        )
    end

    -- SENDEROS ORGÁNICOS CON STEPPING STONES (Piedras Redondeadas, Cero Barro Cobblestone)
    local function PlaceSteppingStonePath(startPos: Vector3, endPos: Vector3, count: number)
        for s = 1, count do
            local alpha = s / (count + 1)
            local stonePos = startPos:Lerp(endPos, alpha) + Vector3.new(math.sin(s * 1.5) * 0.8, 0.32, 0)
            CreateSteppingStone(stonePos, math.random(14, 18) / 10, islandFolder)
        end
    end

    -- Sendero Spawn -> Reactor
    PlaceSteppingStonePath(islandPos + Vector3.new(0, 0, -14), islandPos + Vector3.new(0, 0, 0), 6)
    -- Sendero Reactor -> Parcela de Casa
    PlaceSteppingStonePath(islandPos + Vector3.new(0, 0, 0), islandPos + Vector3.new(16, 0, 8), 6)

    -- PROPS AMBIENTALES: ÁRBOLES ESTILIZADOS
    CreateStylizedTree(islandPos + Vector3.new(-22, 0, -18), islandFolder)
    CreateStylizedTree(islandPos + Vector3.new(24, 0, -16), islandFolder)
    CreateStylizedTree(islandPos + Vector3.new(-26, 0, 14), islandFolder)

    -- PROPS AMBIENTALES: ROCAS SUAVES BISELADAS
    CreateStylizedRock(islandPos + Vector3.new(-16, 1.2, -24), Vector3.new(4, 3, 3.5), 35, islandFolder)
    CreateStylizedRock(islandPos + Vector3.new(20, 1.0, -26), Vector3.new(3.5, 2.5, 4), 70, islandFolder)
    CreateStylizedRock(islandPos + Vector3.new(-22, 1.2, 22), Vector3.new(4.5, 3.2, 4), 115, islandFolder)

    -- FLORA BRILLANTE Y HONGOS
    CreateGlowingFlora(islandPos + Vector3.new(-12, 0, -22), palette.CYAN_PLASMA, islandFolder)
    CreateGlowingFlora(islandPos + Vector3.new(16, 0, -20), palette.MINT_OASIS, islandFolder)

    -- CRISTALES LUMINOSOS FLOTANTES EN EL PERÍMETRO (Monolitos orbitales)
    for cIdx = 1, 4 do
        local cAngle = (cIdx - 1) * (math.pi / 2) + 0.35
        local crystalPos = islandPos + Vector3.new(math.cos(cAngle) * (radius - 5), 4, math.sin(cAngle) * (radius - 5))

        local crystal = Instance.new("Part")
        crystal.Name = "FloatingCrystal_" .. tostring(cIdx)
        crystal.Size = Vector3.new(2.0, 4.8, 2.0)
        crystal.Position = crystalPos
        crystal.CFrame = CFrame.new(crystalPos) * CFrame.Angles(math.rad(15), math.rad(cIdx * 45), math.rad(10))
        crystal.Material = Enum.Material.Neon
        crystal.Color = palette.CYAN_PLASMA
        crystal.Transparency = 0.2
        crystal.Anchored = true
        crystal.CanCollide = false
        crystal.Parent = islandFolder

        local cLight = Instance.new("PointLight")
        cLight.Range = 12
        cLight.Brightness = 1.0
        cLight.Color = palette.CYAN_PLASMA
        cLight.Parent = crystal
    end

    -- FAROLAS CYBER CON FAROL SUSPENDIDO CÁLIDO
    local function CreateStylizedLamp(lampPos: Vector3)
        local pole = Instance.new("Part")
        pole.Size = Vector3.new(0.6, 7.5, 0.6)
        pole.Position = lampPos + Vector3.new(0, 3.75, 0)
        pole.Material = Enum.Material.SmoothPlastic
        pole.Color = palette.DEEP_SLATE
        pole.Anchored = true
        pole.CanCollide = true
        pole.Parent = islandFolder

        local arm = Instance.new("Part")
        arm.Size = Vector3.new(2.2, 0.5, 0.5)
        arm.Position = lampPos + Vector3.new(0.8, 7.5, 0)
        arm.Material = Enum.Material.SmoothPlastic
        arm.Color = palette.DEEP_SLATE
        arm.Anchored = true
        arm.CanCollide = false
        arm.Parent = islandFolder

        local lantern = Instance.new("Part")
        lantern.Shape = Enum.PartType.Ball
        lantern.Size = Vector3.new(1.6, 1.6, 1.6)
        lantern.Position = lampPos + Vector3.new(1.6, 6.8, 0)
        lantern.Material = Enum.Material.Neon
        lantern.Color = palette.ENERGY_GOLD
        lantern.Transparency = 0.15
        lantern.Anchored = true
        lantern.CanCollide = false
        lantern.Parent = islandFolder

        local lLight = Instance.new("PointLight")
        lLight.Range = 16
        lLight.Brightness = 1.6
        lLight.Color = palette.ENERGY_GOLD
        lLight.Parent = lantern
    end

    CreateStylizedLamp(islandPos + Vector3.new(-7, 0, -12))
    CreateStylizedLamp(islandPos + Vector3.new(7, 0, -12))

    -- 2. SpawnLocation personal de la isla (Pad de Teletransporte Futurista)
    local spawnLocation = Instance.new("SpawnLocation")
    spawnLocation.Name = "IslandSpawn"
    spawnLocation.Size = Vector3.new(10, 0.8, 10)
    spawnLocation.Position = islandPos + Vector3.new(0, 0.4, -15)
    spawnLocation.Material = Enum.Material.SmoothPlastic
    spawnLocation.Color = palette.DEEP_SLATE
    spawnLocation.Anchored = true
    spawnLocation.CanCollide = true
    spawnLocation.Duration = 0
    spawnLocation.Enabled = true
    spawnLocation.Parent = islandFolder

    local spawnRing = Instance.new("Part")
    spawnRing.Shape = Enum.PartType.Cylinder
    spawnRing.Size = Vector3.new(0.2, 8.5, 8.5)
    spawnRing.CFrame = spawnLocation.CFrame * CFrame.new(0, 0.45, 0) * CFrame.Angles(0, 0, math.pi/2)
    spawnRing.Material = Enum.Material.Neon
    spawnRing.Color = palette.CYAN_PLASMA
    spawnRing.Transparency = 0.3
    spawnRing.Anchored = true
    spawnRing.CanCollide = false
    spawnRing.Parent = islandFolder

    -- 3. Pedestal y Núcleo 3D interactivo en la isla
    local pedestal = Instance.new("Part")
    pedestal.Name = "ReactorPedestal"
    pedestal.Size = Vector3.new(8, 3.5, 8)
    pedestal.Position = islandPos + Vector3.new(0, 1.75, 0)
    pedestal.Material = Enum.Material.SmoothPlastic
    pedestal.Color = palette.DEEP_SLATE
    pedestal.Anchored = true
    pedestal.CanCollide = true
    pedestal.Parent = islandFolder
    Instance.new("CylinderMesh", pedestal)

    local coreOrb = Instance.new("Part")
    coreOrb.Name = "WorldReactorCore"
    coreOrb.Shape = Enum.PartType.Ball
    coreOrb.Size = Vector3.new(5.5, 5.5, 5.5)
    coreOrb.Position = islandPos + Vector3.new(0, 7.5, 0)
    coreOrb.Material = Enum.Material.Neon
    coreOrb.Color = palette.ELECTRIC_COBALT
    coreOrb.Anchored = true
    coreOrb.CanCollide = false
    coreOrb.Parent = islandFolder

    local clickDetector = Instance.new("ClickDetector")
    clickDetector.MaxActivationDistance = 32
    clickDetector.Parent = coreOrb

    local coreLight = Instance.new("PointLight")
    coreLight.Range = 22
    coreLight.Brightness = 1.8
    coreLight.Color = palette.ELECTRIC_COBALT
    coreLight.Parent = coreOrb

    -- Anillo orbital giratorio alrededor del reactor de isla
    local reactorRing = Instance.new("Part")
    reactorRing.Shape = Enum.PartType.Cylinder
    reactorRing.Size = Vector3.new(0.3, 8.5, 8.5)
    reactorRing.CFrame = coreOrb.CFrame * CFrame.Angles(math.rad(25), 0, math.pi/2)
    reactorRing.Material = Enum.Material.Neon
    reactorRing.Color = palette.CYAN_PLASMA
    reactorRing.Transparency = 0.35
    reactorRing.Anchored = true
    reactorRing.CanCollide = false
    reactorRing.Parent = islandFolder

    -- Rotación procedural viva del anillo del reactor
    task.spawn(function()
        local spin = 0
        while reactorRing and reactorRing.Parent do
            spin += 1.8
            reactorRing.CFrame = coreOrb.CFrame * CFrame.Angles(math.rad(25), math.rad(spin), math.pi/2)
            task.wait(0.03)
        end
    end)

    -- 4. Cartel de propiedad flotante sobre la isla
    local signPart = Instance.new("Part")
    signPart.Name = "OwnerSignPart"
    signPart.Size = Vector3.new(1, 1, 1)
    signPart.Position = islandPos + Vector3.new(0, 16, 0)
    signPart.Transparency = 1
    signPart.Anchored = true
    signPart.CanCollide = false
    signPart.Parent = islandFolder

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "IslandOwnerTag"
    billboard.Size = UDim2.fromScale(10, 2.5)
    billboard.StudsOffset = Vector3.new(0, 0, 0)
    billboard.AlwaysOnTop = true
    billboard.Adornee = signPart
    billboard.Parent = signPart

    local textLabel = Instance.new("TextLabel")
    textLabel.Name = "OwnerText"
    textLabel.Size = UDim2.fromScale(1, 1)
    textLabel.BackgroundTransparency = 1
    textLabel.Font = Enum.Font.FredokaOne
    textLabel.Text = "⚡ Isla #" .. tostring(islandIndex) .. " (Disponible)"
    textLabel.TextColor3 = Color3.fromRGB(240, 245, 255)
    textLabel.TextScaled = true
    textLabel.Parent = billboard
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2.5
    stroke.Color = Color3.new(0, 0, 0)
    stroke.Parent = textLabel

    -- 5. PUENTE SUSPENDIDO ESTILIZADO (Sin barras de neón cegadoras / Estilo AAA)
    local centerPos = Vector3.new(0, GameConfig.ISLAND_HEIGHT, 0)
    local dirToCenter = (centerPos - islandPos).Unit

    local startPoint = islandPos + (dirToCenter * (radius - 1)) + Vector3.new(0, 0.4, 0)
    local endPoint = centerPos - (dirToCenter * (GameConfig.CENTER_ISLAND_RADIUS - 1)) + Vector3.new(0, 0.4, 0)

    local bridgeDistance = (endPoint - startPoint).Magnitude
    local bridgeMid = (startPoint + endPoint) / 2

    -- Plataforma principal del puente (SmoothPlastic PBR Gris Naval)
    local bridgeFloor = Instance.new("Part")
    bridgeFloor.Name = "BridgeFloor"
    bridgeFloor.Size = Vector3.new(12, 1.6, bridgeDistance)
    bridgeFloor.CFrame = CFrame.lookAt(bridgeMid, endPoint)
    bridgeFloor.Material = Enum.Material.SmoothPlastic
    bridgeFloor.Color = Color3.fromRGB(36, 44, 62)
    bridgeFloor.Anchored = true
    bridgeFloor.CanCollide = true
    bridgeFloor.TopSurface = Enum.SurfaceType.Smooth
    bridgeFloor.Parent = islandFolder

    -- Nervios / Tablones transversales de refuerzo estructural (cada 8 studs)
    local ribCount = math.floor(bridgeDistance / 8)
    for r = 1, ribCount do
        local ribOffset = (r - (ribCount / 2)) * 8
        local rib = Instance.new("Part")
        rib.Name = "BridgeRib_" .. tostring(r)
        rib.Size = Vector3.new(12.6, 0.3, 1.4)
        rib.CFrame = bridgeFloor.CFrame * CFrame.new(0, 0.85, ribOffset)
        rib.Material = Enum.Material.SmoothPlastic
        rib.Color = palette.DEEP_SLATE
        rib.Anchored = true
        rib.CanCollide = true
        rib.Parent = islandFolder
    end

    -- Guía central de energía tenue (recesada con transparencia, CERO resplandor plano)
    local bridgeCenterStrip = Instance.new("Part")
    bridgeCenterStrip.Name = "BridgeCenterStrip"
    bridgeCenterStrip.Size = Vector3.new(1.2, 0.1, bridgeDistance)
    bridgeCenterStrip.CFrame = bridgeFloor.CFrame * CFrame.new(0, 0.82, 0)
    bridgeCenterStrip.Material = Enum.Material.Neon
    bridgeCenterStrip.Color = palette.CYAN_PLASMA
    bridgeCenterStrip.Transparency = 0.5
    bridgeCenterStrip.Anchored = true
    bridgeCenterStrip.CanCollide = false
    bridgeCenterStrip.Parent = islandFolder

    -- Postes estructurales de barandilla (cada 16 studs con gemas de luz)
    local postCount = math.floor(bridgeDistance / 16)
    for p = 1, postCount do
        local postOffset = (p - (postCount / 2)) * 16

        -- Poste izquierdo
        local postL = Instance.new("Part")
        postL.Size = Vector3.new(0.8, 3.6, 0.8)
        postL.CFrame = bridgeFloor.CFrame * CFrame.new(-6.0, 2.0, postOffset)
        postL.Material = Enum.Material.SmoothPlastic
        postL.Color = palette.DEEP_SLATE
        postL.Anchored = true
        postL.CanCollide = true
        postL.Parent = islandFolder

        local gemL = Instance.new("Part")
        gemL.Size = Vector3.new(1.0, 0.4, 1.0)
        gemL.CFrame = postL.CFrame * CFrame.new(0, 2.0, 0)
        gemL.Material = Enum.Material.Neon
        gemL.Color = palette.CYAN_PLASMA
        gemL.Transparency = 0.2
        gemL.Anchored = true
        gemL.CanCollide = false
        gemL.Parent = islandFolder

        -- Poste derecho
        local postR = Instance.new("Part")
        postR.Size = Vector3.new(0.8, 3.6, 0.8)
        postR.CFrame = bridgeFloor.CFrame * CFrame.new(6.0, 2.0, postOffset)
        postR.Material = Enum.Material.SmoothPlastic
        postR.Color = palette.DEEP_SLATE
        postR.Anchored = true
        postR.CanCollide = true
        postR.Parent = islandFolder

        local gemR = Instance.new("Part")
        gemR.Size = Vector3.new(1.0, 0.4, 1.0)
        gemR.CFrame = postR.CFrame * CFrame.new(0, 2.0, 0)
        gemR.Material = Enum.Material.Neon
        gemR.Color = palette.CYAN_PLASMA
        gemR.Transparency = 0.2
        gemR.Anchored = true
        gemR.CanCollide = false
        gemR.Parent = islandFolder
    end

    -- Cables de energía semi-transparentes conectando los postes (Cables de suspensión)
    local cableL = Instance.new("Part")
    cableL.Name = "BridgeCableL"
    cableL.Size = Vector3.new(0.2, 0.2, bridgeDistance)
    cableL.CFrame = bridgeFloor.CFrame * CFrame.new(-6.0, 3.2, 0)
    cableL.Material = Enum.Material.Neon
    cableL.Color = palette.CYAN_PLASMA
    cableL.Transparency = 0.6
    cableL.Anchored = true
    cableL.CanCollide = true
    cableL.Parent = islandFolder

    local cableR = Instance.new("Part")
    cableR.Name = "BridgeCableR"
    cableR.Size = Vector3.new(0.2, 0.2, bridgeDistance)
    cableR.CFrame = bridgeFloor.CFrame * CFrame.new(6.0, 3.2, 0)
    cableR.Material = Enum.Material.Neon
    cableR.Color = palette.CYAN_PLASMA
    cableR.Transparency = 0.6
    cableR.Anchored = true
    cableR.CanCollide = true
    cableR.Parent = islandFolder

    -- Arco monumental de entrada a mitad del puente
    local archway = Instance.new("Part")
    archway.Name = "BridgeArchway"
    archway.Size = Vector3.new(14.5, 9, 1.4)
    archway.CFrame = bridgeFloor.CFrame * CFrame.new(0, 4.5, 0)
    archway.Material = Enum.Material.Neon
    archway.Color = palette.ENERGY_GOLD
    archway.Transparency = 0.4
    archway.Anchored = true
    archway.CanCollide = false
    archway.Parent = islandFolder

    -- 6. Anillo perimetral sutil de Safezone (Limpio y al nivel del suelo, NADA de cilindros gigantes flotando)
    local safeRing = Instance.new("Part")
    safeRing.Name = "SafezoneBorderRing"
    safeRing.Shape = Enum.PartType.Cylinder
    safeRing.Size = Vector3.new(0.4, (radius + 0.5) * 2, (radius + 0.5) * 2)
    safeRing.CFrame = CFrame.new(islandPos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi/2)
    safeRing.Material = Enum.Material.Neon
    safeRing.Color = palette.MINT_OASIS
    safeRing.Transparency = 0.5
    safeRing.Anchored = true
    safeRing.CanCollide = false
    safeRing.Parent = islandFolder

    -- 7. Fundación de la Casa / Base personal
    local houseBase = Instance.new("Part")
    houseBase.Name = "HousePlotFoundation"
    houseBase.Size = Vector3.new(24, 1.2, 24)
    houseBase.Position = islandPos + Vector3.new(18, 1.2, 10)
    houseBase.Material = Enum.Material.WoodPlanks
    houseBase.Color = Color3.fromRGB(150, 110, 70)
    houseBase.Anchored = true
    houseBase.CanCollide = true
    houseBase.Parent = islandFolder

    -- 8. PADS FÍSICOS DE COMPRA EN EL SUELO (Tycoon Purchase Pads con Neón pulsante y carteles oscilantes)
    local function CreatePurchasePad(name: string, padPos: Vector3, padColor: Color3, titleText: string, subText: string): Model
        local padModel = Instance.new("Model")
        padModel.Name = name
        padModel.Parent = islandFolder

        -- Marco exterior SmoothPlastic oscuro biselado
        local curb = Instance.new("Part")
        curb.Name = "PadCurb"
        curb.Shape = Enum.PartType.Cylinder
        curb.Size = Vector3.new(0.5, 8.5, 8.5)
        curb.CFrame = CFrame.new(padPos + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90))
        curb.Material = Enum.Material.SmoothPlastic
        curb.Color = palette.DEEP_SLATE
        curb.Anchored = true
        curb.CanCollide = true
        curb.Parent = padModel

        -- Núcleo interior Neon pulsante
        local inner = Instance.new("Part")
        inner.Name = "PadInner"
        inner.Shape = Enum.PartType.Cylinder
        inner.Size = Vector3.new(0.65, 7.2, 7.2)
        inner.CFrame = CFrame.new(padPos + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, 0, math.rad(90))
        inner.Material = Enum.Material.Neon
        inner.Color = padColor
        inner.Transparency = 0.25
        inner.Anchored = true
        inner.CanCollide = false
        inner.Parent = padModel

        -- Cartel flotante BillboardGui oscilando en altura
        local signHolder = Instance.new("Part")
        signHolder.Name = "SignHolder"
        signHolder.Size = Vector3.new(0.5, 0.5, 0.5)
        signHolder.Position = padPos + Vector3.new(0, 4.2, 0)
        signHolder.Transparency = 1
        signHolder.Anchored = true
        signHolder.CanCollide = false
        signHolder.Parent = padModel

        local bbg = Instance.new("BillboardGui")
        bbg.Name = "PadBillboard"
        bbg.Size = UDim2.fromScale(6, 2.5)
        bbg.StudsOffset = Vector3.new(0, 0, 0)
        bbg.AlwaysOnTop = false
        bbg.Adornee = signHolder
        bbg.MaxDistance = 45
        bbg.Parent = signHolder

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Name = "PadTitle"
        titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
        titleLabel.Position = UDim2.new(0, 0, 0, 0)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Font = Enum.Font.FredokaOne
        titleLabel.Text = titleText
        titleLabel.TextColor3 = padColor
        titleLabel.TextScaled = true
        titleLabel.Parent = bbg

        local stroke1 = Instance.new("UIStroke", titleLabel)
        stroke1.Thickness = 2
        stroke1.Color = Color3.fromRGB(0, 0, 0)

        local subLabel = Instance.new("TextLabel")
        subLabel.Name = "PadSub"
        subLabel.Size = UDim2.new(1, 0, 0.4, 0)
        subLabel.Position = UDim2.new(0, 0, 0.55, 0)
        subLabel.BackgroundTransparency = 1
        subLabel.Font = Enum.Font.GothamBold
        subLabel.Text = subText
        subLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        subLabel.TextScaled = true
        subLabel.Parent = bbg

        local stroke2 = Instance.new("UIStroke", subLabel)
        stroke2.Thickness = 1.5
        stroke2.Color = Color3.fromRGB(0, 0, 0)

        -- Oscilación suave procedural del cartel: math.sin(os.clock() * 3)
        task.spawn(function()
            local baseY = signHolder.Position.Y
            while signHolder and signHolder.Parent do
                local offset = math.sin(os.clock() * 3) * 0.4
                signHolder.Position = Vector3.new(signHolder.Position.X, baseY + offset, signHolder.Position.Z)
                task.wait(0.04)
            end
        end)

        return padModel
    end

    CreatePurchasePad("HouseUpgradePad", islandPos + Vector3.new(16, 0, -4), palette.MINT_OASIS, "🏠 MEJORAR CASA", "Pisar para construir")
    CreatePurchasePad("TeslaTowerPad", islandPos + Vector3.new(-18, 0, 0), palette.CYAN_PLASMA, "⚡ TORRE TESLA", "Pisar para instalar")

    -- 9. CONDUCTOS DE ENERGÍA VISUALES (Beam de energía entre Núcleo y Casa)
    local attCore = Instance.new("Attachment")
    attCore.Name = "CoreEnergyAttachment"
    attCore.Position = Vector3.new(0, 0, 0)
    attCore.Parent = coreOrb

    local attHouse = Instance.new("Attachment")
    attHouse.Name = "HouseEnergyAttachment"
    attHouse.Position = Vector3.new(0, 2, 0)
    attHouse.Parent = houseBase

    local beam = Instance.new("Beam")
    beam.Name = "ReactorHouseEnergyBeam"
    beam.Attachment0 = attCore
    beam.Attachment1 = attHouse
    beam.Texture = ""
    beam.TextureSpeed = 2.2
    beam.Color = ColorSequence.new(palette.CYAN_PLASMA)
    beam.Width0 = 1.2
    beam.Width1 = 1.2
    beam.LightEmission = 0.95
    beam.Transparency = NumberSequence.new(0.25)
    beam.Segments = 16
    beam.Parent = islandFolder

    -- Producción visible: orbes de energía viajan del núcleo a la casa
    task.spawn(function()
        while islandFolder.Parent do
            local orb = Instance.new("Part")
            orb.Shape = Enum.PartType.Ball
            orb.Size = Vector3.new(1.1, 1.1, 1.1)
            orb.Material = Enum.Material.Neon
            orb.Color = palette.ENERGY_GOLD
            orb.Anchored = true
            orb.CanCollide = false
            orb.CanQuery = false
            orb.CastShadow = false
            orb.Position = coreOrb.Position
            orb.Parent = islandFolder
            local tw = TweenService:Create(orb, TweenInfo.new(1.4, Enum.EasingStyle.Sine), {
                Position = houseBase.Position + Vector3.new(0, 3, 0),
                Size = Vector3.new(0.4, 0.4, 0.4),
            })
            tw:Play()
            tw.Completed:Once(function() orb:Destroy() end)
            task.wait(1.2)
        end
    end)
end

-- Inicializa y genera todo el mundo físico
function MapService.InitializeMap()
    MapFolder = Instance.new("Folder")
    MapFolder.Name = "Map"
    MapFolder.Parent = Workspace

    SetupLighting()
    BuildCentralIsland()

    for i = 1, GameConfig.ISLAND_COUNT do
        BuildPlayerIsland(i)
    end

    print("[MapService] Mapa 3D generado con éxito: 6 Islas orbitales + Isla Central.")
end

-- Obtiene la carpeta de una isla
function MapService.GetIslandFolder(islandIndex: number): Folder?
    return IslandFolders[islandIndex]
end

return MapService
