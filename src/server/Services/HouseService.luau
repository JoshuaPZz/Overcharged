--!strict
-- HouseService: Construcción procedural de Casas multinivel y Torres Tesla automatizadas
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("OverchargedShared")
local Types = require(Shared.Types.GameTypes)
local GameConfig = require(Shared.Config.GameConfig)

local DataService = require(script.Parent.DataService)
local MapService = require(script.Parent.MapService)
local SoundUtil = require(Shared.Utils.SoundUtil)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local StateReplicated = Remotes:WaitForChild("StateReplicated") :: RemoteEvent
local NotificationEvent = Remotes:WaitForChild("NotificationEvent") :: RemoteEvent

local HouseService = {}

-- Crea 25 chispas de energía y anillo expansivo al construir/mejorar
local function SpawnBuildVFX(position: Vector3, color: Color3)
    local emitterPart = Instance.new("Part")
    emitterPart.Name = "BuildBurstPart"
    emitterPart.Size = Vector3.new(1, 1, 1)
    emitterPart.Position = position + Vector3.new(0, 4, 0)
    emitterPart.Transparency = 1
    emitterPart.Anchored = true
    emitterPart.CanCollide = false
    emitterPart.Parent = Workspace

    local att = Instance.new("Attachment", emitterPart)
    local sparks = Instance.new("ParticleEmitter")
    sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    sparks.Rate = 0
    sparks.Speed = NumberRange.new(14, 28)
    sparks.Lifetime = NumberRange.new(0.4, 0.8)
    sparks.SpreadAngle = Vector2.new(180, 180)
    sparks.Color = ColorSequence.new(color, Color3.fromRGB(255, 230, 100))
    sparks.LightEmission = 0.95
    sparks.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1.4),
        NumberSequenceKeypoint.new(1, 0),
    })
    sparks.Parent = att
    sparks:Emit(25)

    -- Anillo de choque de construcción
    local ring = Instance.new("Part")
    ring.Shape = Enum.PartType.Cylinder
    ring.Size = Vector3.new(0.3, 2, 2)
    ring.CFrame = CFrame.new(position + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.pi/2)
    ring.Material = Enum.Material.Neon
    ring.Color = color
    ring.Transparency = 0.2
    ring.Anchored = true
    ring.CanCollide = false
    ring.Parent = Workspace

    TweenService:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.1, 26, 26),
        Transparency = 1,
    }):Play()

    SoundUtil.Play3D(SoundUtil.SOUNDS.BUILD, emitterPart, 0.85)

    task.delay(1.5, function()
        if emitterPart and emitterPart.Parent then emitterPart:Destroy() end
        if ring and ring.Parent then ring:Destroy() end
    end)
end

-- Limpia estructuras de casa previas en la parcela
local function ClearHouseModel(islandFolder: Folder)
    local old = islandFolder:FindFirstChild("PlayerHouseModel")
    if old then old:Destroy() end
end

-- Limpia torres Tesla previas
local function ClearTeslaTowers(islandFolder: Folder)
    local old = islandFolder:FindFirstChild("TeslaTowersFolder")
    if old then old:Destroy() end
end

-- Construye Cabaña de Energía (Nivel 1)
local function BuildCabin(foundationPos: Vector3, parentFolder: Folder)
    -- Paredes principales
    local wallFrontL = Instance.new("Part")
    wallFrontL.Size = Vector3.new(8, 8, 1)
    wallFrontL.Position = foundationPos + Vector3.new(-6, 4.5, -9.5)
    wallFrontL.Material = Enum.Material.WoodPlanks
    wallFrontL.Color = Color3.fromRGB(120, 85, 55)
    wallFrontL.Anchored = true
    wallFrontL.Parent = parentFolder

    local wallFrontR = Instance.new("Part")
    wallFrontR.Size = Vector3.new(8, 8, 1)
    wallFrontR.Position = foundationPos + Vector3.new(6, 4.5, -9.5)
    wallFrontR.Material = Enum.Material.WoodPlanks
    wallFrontR.Color = Color3.fromRGB(120, 85, 55)
    wallFrontR.Anchored = true
    wallFrontR.Parent = parentFolder

    local wallBack = Instance.new("Part")
    wallBack.Size = Vector3.new(20, 8, 1)
    wallBack.Position = foundationPos + Vector3.new(0, 4.5, 9.5)
    wallBack.Material = Enum.Material.WoodPlanks
    wallBack.Color = Color3.fromRGB(120, 85, 55)
    wallBack.Anchored = true
    wallBack.Parent = parentFolder

    local wallLeft = Instance.new("Part")
    wallLeft.Size = Vector3.new(1, 8, 20)
    wallLeft.Position = foundationPos + Vector3.new(-9.5, 4.5, 0)
    wallLeft.Material = Enum.Material.WoodPlanks
    wallLeft.Color = Color3.fromRGB(120, 85, 55)
    wallLeft.Anchored = true
    wallLeft.Parent = parentFolder

    local wallRight = Instance.new("Part")
    wallRight.Size = Vector3.new(1, 8, 20)
    wallRight.Position = foundationPos + Vector3.new(9.5, 4.5, 0)
    wallRight.Material = Enum.Material.WoodPlanks
    wallRight.Color = Color3.fromRGB(120, 85, 55)
    wallRight.Anchored = true
    wallRight.Parent = parentFolder

    -- Techo inclinado
    local roofLeft = Instance.new("Part")
    roofLeft.Size = Vector3.new(13, 1, 22)
    roofLeft.CFrame = CFrame.new(foundationPos + Vector3.new(-5, 10.5, 0)) * CFrame.Angles(0, 0, math.rad(28))
    roofLeft.Material = Enum.Material.Wood
    roofLeft.Color = Color3.fromRGB(65, 45, 30)
    roofLeft.Anchored = true
    roofLeft.Parent = parentFolder

    local roofRight = Instance.new("Part")
    roofRight.Size = Vector3.new(13, 1, 22)
    roofRight.CFrame = CFrame.new(foundationPos + Vector3.new(5, 10.5, 0)) * CFrame.Angles(0, 0, math.rad(-28))
    roofRight.Material = Enum.Material.Wood
    roofRight.Color = Color3.fromRGB(65, 45, 30)
    roofRight.Anchored = true
    roofRight.Parent = parentFolder

    -- Chimenea de Plasma
    local chimney = Instance.new("Part")
    chimney.Size = Vector3.new(3, 12, 3)
    chimney.Position = foundationPos + Vector3.new(6, 9, 6)
    chimney.Material = Enum.Material.Cobblestone
    chimney.Color = Color3.fromRGB(75, 75, 85)
    chimney.Anchored = true
    chimney.Parent = parentFolder

    local fireOrb = Instance.new("Part")
    fireOrb.Shape = Enum.PartType.Ball
    fireOrb.Size = Vector3.new(1.8, 1.8, 1.8)
    fireOrb.Position = chimney.Position + Vector3.new(0, 6.2, 0)
    fireOrb.Material = Enum.Material.Neon
    fireOrb.Color = Color3.fromRGB(0, 220, 255)
    fireOrb.Anchored = true
    fireOrb.CanCollide = false
    fireOrb.Parent = parentFolder
end

-- Construye Laboratorio Tecnológico de 2 Pisos (Nivel 2)
local function BuildTechLab(foundationPos: Vector3, parentFolder: Folder)
    -- Planta Baja
    local baseBuilding = Instance.new("Part")
    baseBuilding.Size = Vector3.new(20, 9, 20)
    baseBuilding.Position = foundationPos + Vector3.new(0, 5, 0)
    baseBuilding.Material = Enum.Material.SmoothPlastic
    baseBuilding.Color = Color3.fromRGB(38, 44, 58)
    baseBuilding.Anchored = true
    baseBuilding.Parent = parentFolder

    -- Gran ventanal de observación
    local glassBay = Instance.new("Part")
    glassBay.Size = Vector3.new(14, 5, 1)
    glassBay.Position = foundationPos + Vector3.new(0, 5, -9.6)
    glassBay.Material = Enum.Material.Glass
    glassBay.Color = Color3.fromRGB(0, 180, 255)
    glassBay.Transparency = 0.35
    glassBay.Anchored = true
    glassBay.Parent = parentFolder

    -- Segundo Piso con Balcón
    local secondFloor = Instance.new("Part")
    secondFloor.Size = Vector3.new(16, 7, 14)
    secondFloor.Position = foundationPos + Vector3.new(0, 13, 2)
    secondFloor.Material = Enum.Material.SmoothPlastic
    secondFloor.Color = Color3.fromRGB(25, 30, 42)
    secondFloor.Anchored = true
    secondFloor.Parent = parentFolder

    -- Balcón con barandilla de Neón frente a la arena
    local balconyRail = Instance.new("Part")
    balconyRail.Size = Vector3.new(16, 2.5, 0.6)
    balconyRail.Position = foundationPos + Vector3.new(0, 11, -7)
    balconyRail.Material = Enum.Material.Neon
    balconyRail.Color = Color3.fromRGB(0, 220, 255)
    balconyRail.Anchored = true
    balconyRail.Parent = parentFolder

    -- Antena de radar en el tejado
    local dishPole = Instance.new("Part")
    dishPole.Size = Vector3.new(0.8, 5, 0.8)
    dishPole.Position = foundationPos + Vector3.new(4, 18, 2)
    dishPole.Material = Enum.Material.Metal
    dishPole.Color = Color3.fromRGB(150, 150, 160)
    dishPole.Anchored = true
    dishPole.Parent = parentFolder

    local dish = Instance.new("Part")
    dish.Shape = Enum.PartType.Cylinder
    dish.Size = Vector3.new(0.6, 5, 5)
    dish.CFrame = CFrame.new(foundationPos + Vector3.new(4, 20.5, 2)) * CFrame.Angles(0, math.rad(45), math.rad(45))
    dish.Material = Enum.Material.Neon
    dish.Color = Color3.fromRGB(0, 255, 140)
    dish.Anchored = true
    dish.CanCollide = false
    dish.Parent = parentFolder
end

-- Construye Santuario Cósmico (Nivel 3)
local function BuildCosmicSanctuary(foundationPos: Vector3, parentFolder: Folder)
    -- Columnas de Mármol en las 4 esquinas
    local pillarOffsets = {
        Vector3.new(-8, 9, -8),
        Vector3.new(8, 9, -8),
        Vector3.new(-8, 9, 8),
        Vector3.new(8, 9, 8),
    }

    for idx, off in ipairs(pillarOffsets) do
        local col = Instance.new("Part")
        col.Name = "SanctuaryPillar_" .. tostring(idx)
        col.Shape = Enum.PartType.Cylinder
        col.Size = Vector3.new(16, 3, 3)
        col.CFrame = CFrame.new(foundationPos + off) * CFrame.Angles(0, 0, math.rad(90))
        col.Material = Enum.Material.Marble
        col.Color = Color3.fromRGB(240, 235, 245)
        col.Anchored = true
        col.Parent = parentFolder
    end

    -- Techo abovedado celestial
    local roofBase = Instance.new("Part")
    roofBase.Size = Vector3.new(22, 2, 22)
    roofBase.Position = foundationPos + Vector3.new(0, 18, 0)
    roofBase.Material = Enum.Material.Neon
    roofBase.Color = Color3.fromRGB(255, 215, 0)
    roofBase.Anchored = true
    roofBase.Parent = parentFolder

    -- Cúpula Cósmica
    local dome = Instance.new("Part")
    dome.Shape = Enum.PartType.Ball
    dome.Size = Vector3.new(16, 12, 16)
    dome.Position = foundationPos + Vector3.new(0, 22, 0)
    dome.Material = Enum.Material.Glass
    dome.Color = Color3.fromRGB(180, 0, 255)
    dome.Transparency = 0.2
    dome.Anchored = true
    dome.Parent = parentFolder

    -- Cristal Central Levitando
    local levitatingCrystal = Instance.new("Part")
    levitatingCrystal.Name = "SanctuaryCore"
    levitatingCrystal.Size = Vector3.new(4, 7, 4)
    levitatingCrystal.Position = foundationPos + Vector3.new(0, 9, 0)
    levitatingCrystal.Material = Enum.Material.Neon
    levitatingCrystal.Color = Color3.fromRGB(255, 225, 50)
    levitatingCrystal.Anchored = true
    levitatingCrystal.CanCollide = false
    levitatingCrystal.Parent = parentFolder

    local cLight = Instance.new("PointLight")
    cLight.Range = 35
    cLight.Brightness = 4
    cLight.Color = Color3.fromRGB(255, 215, 0)
    cLight.Parent = levitatingCrystal
end

-- Construye una Torre Tesla física
local function BuildSingleTeslaTower(pos: Vector3, parentFolder: Folder, index: number)
    local base = Instance.new("Part")
    base.Name = "TeslaBase_" .. tostring(index)
    base.Size = Vector3.new(5, 2, 5)
    base.Position = pos + Vector3.new(0, 1, 0)
    base.Material = Enum.Material.Metal
    base.Color = Color3.fromRGB(45, 50, 60)
    base.Anchored = true
    base.Parent = parentFolder

    -- Mástil con anillos de bobina
    local mast = Instance.new("Part")
    mast.Shape = Enum.PartType.Cylinder
    mast.Size = Vector3.new(8, 1.4, 1.4)
    mast.CFrame = CFrame.new(pos + Vector3.new(0, 6, 0)) * CFrame.Angles(0, 0, math.rad(90))
    mast.Material = Enum.Material.DiamondPlate
    mast.Color = Color3.fromRGB(160, 100, 40)
    mast.Anchored = true
    mast.Parent = parentFolder

    -- Esfera conductora de plasma superior
    local orb = Instance.new("Part")
    orb.Name = "TeslaOrb"
    orb.Shape = Enum.PartType.Ball
    orb.Size = Vector3.new(3.5, 3.5, 3.5)
    orb.Position = pos + Vector3.new(0, 11, 0)
    orb.Material = Enum.Material.Neon
    orb.Color = Color3.fromRGB(0, 220, 255)
    orb.Anchored = true
    orb.CanCollide = false
    orb.Parent = parentFolder

    local light = Instance.new("PointLight")
    light.Range = 16
    light.Brightness = 2.5
    light.Color = Color3.fromRGB(0, 220, 255)
    light.Parent = orb
end

-- Actualiza los carteles flotantes de los pads físicos según la progresión del jugador
local function UpdatePadBillboards(islandFolder: Folder, profile: Types.PlayerProfile)
    local housePad = islandFolder:FindFirstChild("HouseUpgradePad")
    if housePad then
        local signHolder = housePad:FindFirstChild("SignHolder")
        local bbg = signHolder and signHolder:FindFirstChild("PadBillboard") :: BillboardGui?
        if bbg then
            local title = bbg:FindFirstChild("PadTitle") :: TextLabel?
            local sub = bbg:FindFirstChild("PadSub") :: TextLabel?
            local nextLvl = (profile.HouseLevel or 0) + 1
            local cfg = GameConfig.HOUSE_UPGRADES[nextLvl]
            if cfg then
                if title then title.Text = "🏠 " .. cfg.Name end
                if sub then sub.Text = "⚡ " .. tostring(cfg.Cost) .. " (Pisar)" end
            else
                if title then title.Text = "🏠 Santuario Cósmico" end
                if sub then sub.Text = "⭐ Nivel Máximo" end
            end
        end
    end

    local teslaPad = islandFolder:FindFirstChild("TeslaTowerPad")
    if teslaPad then
        local signHolder = teslaPad:FindFirstChild("SignHolder")
        local bbg = signHolder and signHolder:FindFirstChild("PadBillboard") :: BillboardGui?
        if bbg then
            local title = bbg:FindFirstChild("PadTitle") :: TextLabel?
            local sub = bbg:FindFirstChild("PadSub") :: TextLabel?
            local current = profile.TeslaTowers or 0
            if current < GameConfig.TESLA_TOWER.MaxCount then
                local cost = math.floor(GameConfig.TESLA_TOWER.BaseCost * (GameConfig.TESLA_TOWER.CostMultiplier ^ current))
                if title then title.Text = string.format("⚡ Torre Tesla [%d/%d]", current + 1, GameConfig.TESLA_TOWER.MaxCount) end
                if sub then sub.Text = "⚡ " .. tostring(cost) .. " (Pisar)" end
            else
                if title then title.Text = "⚡ Torres Tesla [MÁX]" end
                if sub then sub.Text = "⭐ Límite alcanzado" end
            end
        end
    end
end

-- Construye o reconstruye la casa del jugador según su nivel persistente
function HouseService.BuildForPlayer(player: Player, isUpgrading: boolean?)
    local profile = DataService.GetProfile(player)
    if not profile or profile.AssignedIsland == 0 then return end

    local islandFolder = MapService.GetIslandFolder(profile.AssignedIsland)
    if not islandFolder then return end

    local foundation = islandFolder:FindFirstChild("HousePlotFoundation") :: BasePart?
    if not foundation then return end

    ClearHouseModel(islandFolder)
    ClearTeslaTowers(islandFolder)

    local houseModel = Instance.new("Folder")
    houseModel.Name = "PlayerHouseModel"
    houseModel.Parent = islandFolder

    local houseLevel = profile.HouseLevel or 0
    if houseLevel == 1 then
        BuildCabin(foundation.Position, houseModel)
    elseif houseLevel == 2 then
        BuildTechLab(foundation.Position, houseModel)
    elseif houseLevel >= 3 then
        BuildCosmicSanctuary(foundation.Position, houseModel)
    end

    -- Animación pop-in (Back / Bounce) en cada elemento construido si es una compra/mejora
    if isUpgrading then
        for _, part in ipairs(houseModel:GetDescendants()) do
            if part:IsA("BasePart") then
                local finalSize = part.Size
                part.Size = Vector3.new(0.05, 0.05, 0.05)
                TweenService:Create(part, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                    Size = finalSize
                }):Play()
            end
        end
    end

    -- Construir Torres Tesla compradas
    local towersCount = profile.TeslaTowers or 0
    if towersCount > 0 then
        local teslaFolder = Instance.new("Folder")
        teslaFolder.Name = "TeslaTowersFolder"
        teslaFolder.Parent = islandFolder

        local islandFloor = islandFolder:FindFirstChild("IslandFloor") :: BasePart?
        local islandPos = islandFloor and islandFloor.Position or foundation.Position

        local towerOffsets = {
            Vector3.new(-22, 0, 10),
            Vector3.new(-24, 0, -10),
            Vector3.new(24, 0, -14),
        }

        for i = 1, math.min(towersCount, #towerOffsets) do
            BuildSingleTeslaTower(islandPos + towerOffsets[i], teslaFolder, i)
        end

        if isUpgrading then
            for _, part in ipairs(teslaFolder:GetDescendants()) do
                if part:IsA("BasePart") then
                    local finalSize = part.Size
                    part.Size = Vector3.new(0.05, 0.05, 0.05)
                    TweenService:Create(part, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                        Size = finalSize
                    }):Play()
                end
            end
        end
    end

    UpdatePadBillboards(islandFolder, profile)
end

-- Procesa la mejora de nivel de la casa
function HouseService.UpgradeHouse(player: Player)
    local profile = DataService.GetProfile(player)
    if not profile then return end

    local currentLevel = profile.HouseLevel or 0
    local nextLevel = currentLevel + 1
    local config = GameConfig.HOUSE_UPGRADES[nextLevel]
    if not config then return end -- Ya alcanzó el nivel máximo

    if profile.Energy >= config.Cost then
        profile.Energy -= config.Cost
        profile.HouseLevel = nextLevel

        local islandFolder = MapService.GetIslandFolder(profile.AssignedIsland)
        local foundation = islandFolder and islandFolder:FindFirstChild("HousePlotFoundation") :: BasePart?
        if foundation then
            SpawnBuildVFX(foundation.Position, Color3.fromRGB(80, 255, 120))
        end

        -- Reconstruir casa físicamente en el mapa con animación pop-in
        HouseService.BuildForPlayer(player, true)

        NotificationEvent:FireClient(player, {
            Type = "PersonalRoll",
            Title = "¡CASA MEJORADA: " .. config.Name .. "!",
            Color = Color3.fromRGB(80, 255, 120),
        })

        StateReplicated:FireClient(player, profile)
    end
end

-- Procesa la compra de una Torre Tesla
function HouseService.BuyTeslaTower(player: Player)
    local profile = DataService.GetProfile(player)
    if not profile then return end

    local currentTowers = profile.TeslaTowers or 0
    if currentTowers >= GameConfig.TESLA_TOWER.MaxCount then return end

    local cost = math.floor(GameConfig.TESLA_TOWER.BaseCost * (GameConfig.TESLA_TOWER.CostMultiplier ^ currentTowers))

    if profile.Energy >= cost then
        profile.Energy -= cost
        profile.TeslaTowers = currentTowers + 1

        local islandFolder = MapService.GetIslandFolder(profile.AssignedIsland)
        local foundation = islandFolder and islandFolder:FindFirstChild("HousePlotFoundation") :: BasePart?
        if foundation then
            SpawnBuildVFX(foundation.Position + Vector3.new(-20, 0, 0), Color3.fromRGB(0, 220, 255))
        end

        HouseService.BuildForPlayer(player, true)

        NotificationEvent:FireClient(player, {
            Type = "PersonalRoll",
            Title = "¡TORRE TESLA INSTALADA EN TU ISLA!",
            Color = Color3.fromRGB(0, 220, 255),
        })

        StateReplicated:FireClient(player, profile)
    end
end

-- Bucle de Automatización: Disparos eléctricos de las Torres Tesla
function HouseService.StartTeslaLoop()
    task.spawn(function()
        while true do
            task.wait(GameConfig.TESLA_TOWER.StrikeInterval)
            for _, player in ipairs(Players:GetPlayers()) do
                local profile = DataService.GetProfile(player)
                if profile and profile.AssignedIsland > 0 and (profile.TeslaTowers or 0) > 0 then
                    local islandFolder = MapService.GetIslandFolder(profile.AssignedIsland)
                    if islandFolder then
                        local core = islandFolder:FindFirstChild("WorldReactorCore") :: BasePart?
                        local teslaFolder = islandFolder:FindFirstChild("TeslaTowersFolder")

                        if core and teslaFolder then
                            for _, tower in ipairs(teslaFolder:GetChildren()) do
                                local orb = tower:FindFirstChild("TeslaOrb") :: BasePart?
                                if orb then
                                    -- Crear rayo láser/arco eléctrico efímero
                                    local bolt = Instance.new("Part")
                                    bolt.Size = Vector3.new(0.4, 0.4, (orb.Position - core.Position).Magnitude)
                                    bolt.CFrame = CFrame.new(orb.Position, core.Position) * CFrame.new(0, 0, -bolt.Size.Z / 2)
                                    bolt.Material = Enum.Material.Neon
                                    bolt.Color = Color3.fromRGB(0, 220, 255)
                                    bolt.Anchored = true
                                    bolt.CanCollide = false
                                    bolt.Parent = Workspace

                                    task.delay(0.2, function()
                                        if bolt then bolt:Destroy() end
                                    end)
                                end
                            end

                            -- Otorgar ganancias automáticas
                            local houseMult = 1.0
                            if profile.HouseLevel and profile.HouseLevel > 0 and GameConfig.HOUSE_UPGRADES[profile.HouseLevel] then
                                houseMult = GameConfig.HOUSE_UPGRADES[profile.HouseLevel].Multiplier
                            end

                            local energyGain = math.floor(GameConfig.TESLA_TOWER.EnergyPerStrike * profile.TeslaTowers * houseMult)
                            local xpGain = math.floor(GameConfig.TESLA_TOWER.XPPerStrike * profile.TeslaTowers)

                            profile.Energy += energyGain
                            local ReactorService = require(script.Parent.ReactorService)
                            ReactorService.AddAuraXP(player, xpGain)

                            StateReplicated:FireClient(player, profile)
                        end
                    end
                end
            end
        end
    end)
end

return HouseService
