--!strict
-- CrateService: Cofres y Cajas Destruibles con Potenciadores, Auras y Energía en la Arena
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("OverchargedShared")
local Types = require(Shared.Types.GameTypes)
local GameConfig = require(Shared.Config.GameConfig)

local DataService = require(script.Parent.DataService)

local CrateService = {}

local CratesFolder: Folder
local ActiveCrates: { [Model]: {
    Def: any,
    CurrentHits: number,
    MaxHits: number,
    SpawnPos: Vector3,
    IsBroken: boolean,
} } = {}

-- Tabla de Buffs de Frenesí de Combate temporales: [UserId] = timestamp expiración
local FrenzyBuffs: { [number]: number } = {}

-- Devuelve si un jugador tiene el buff de Frenesí activo
function CrateService.HasFrenzyBuff(player: Player): boolean
    local expireTime = FrenzyBuffs[player.UserId]
    if expireTime and os.clock() < expireTime then
        return true
    end
    return false
end

-- Efecto de estallido al romper un cofre
local function SpawnCrateBreakEffect(position: Vector3, color: Color3)
    local p = Instance.new("Part")
    p.Size = Vector3.new(0.5, 0.5, 0.5)
    p.Position = position
    p.Transparency = 1
    p.Anchored = true
    p.CanCollide = false
    p.Parent = Workspace

    local att = Instance.new("Attachment", p)
    local emit = Instance.new("ParticleEmitter")
    emit.Rate = 0
    emit.Speed = NumberRange.new(15, 30)
    emit.Lifetime = NumberRange.new(0.4, 0.7)
    emit.SpreadAngle = Vector2.new(180, 180)
    emit.Color = ColorSequence.new(color, GameConfig.PALETTE.ENERGY_GOLD)
    emit.LightEmission = 0.9
    emit.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1.5),
        NumberSequenceKeypoint.new(0.4, 2.2),
        NumberSequenceKeypoint.new(1, 0),
    })
    emit.Parent = att
    emit:Emit(30)

    -- Anillo de choque brillante
    local ring = Instance.new("Part")
    ring.Shape = Enum.PartType.Cylinder
    ring.Size = Vector3.new(0.2, 2, 2)
    ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi/2)
    ring.Material = Enum.Material.Neon
    ring.Color = color
    ring.Transparency = 0.2
    ring.Anchored = true
    ring.CanCollide = false
    ring.Parent = Workspace

    TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.1, 18, 18),
        Transparency = 1,
    }):Play()

    task.delay(0.7, function()
        if p and p.Parent then p:Destroy() end
        if ring and ring.Parent then ring:Destroy() end
    end)
end

-- Muestra número de golpe o recompensa flotante
local function SpawnFloatingPopup(position: Vector3, text: string, color: Color3)
    local p = Instance.new("Part")
    p.Size = Vector3.new(0.1, 0.1, 0.1)
    p.Position = position + Vector3.new(math.random(-10, 10)/10, 0, math.random(-10, 10)/10)
    p.Transparency = 1
    p.Anchored = true
    p.CanCollide = false
    p.Parent = Workspace

    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.fromOffset(170, 36)
    bb.StudsOffset = Vector3.new(0, 1.2, 0)
    bb.AlwaysOnTop = true
    bb.Adornee = p
    bb.Parent = p

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.FredokaOne
    lbl.Text = text
    lbl.TextColor3 = color
    lbl.TextSize = 15
    lbl.Parent = bb

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1.5
    stroke.Color = Color3.new(0, 0, 0)
    stroke.Parent = lbl

    TweenService:Create(p, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = position + Vector3.new(0, 3.8, 0),
    }):Play()

    TweenService:Create(lbl, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        TextTransparency = 1,
    }):Play()

    task.delay(0.65, function()
        if p and p.Parent then p:Destroy() end
    end)
end

-- Actualiza el Billboard del Cofre
local function UpdateCrateHUD(crateModel: Model)
    local state = ActiveCrates[crateModel]
    if not state then return end

    local primary = crateModel.PrimaryPart
    if not primary then return end

    local bb = primary:FindFirstChild("CrateHUD") :: BillboardGui?
    if not bb then return end

    local lbl = bb:FindFirstChild("HitsText") :: TextLabel?
    if lbl then
        local remaining = state.MaxHits - state.CurrentHits
        lbl.Text = string.format("%s (%d/%d Golpes)", state.Def.Name, remaining, state.MaxHits)
    end
end

-- Construye el modelo 3D estilizado de un Cofre según su tipo
local function CreateCrateModel(chestKey: string, chestDef: any, spawnPos: Vector3): Model
    local model = Instance.new("Model")
    model.Name = "Crate_" .. chestDef.Id

    local palette = GameConfig.PALETTE

    -- Cuerpo principal del cofre (Chunky Beveled Box)
    local box = Instance.new("Part")
    box.Name = "HumanoidRootPart"
    box.Size = Vector3.new(4.2, 3.0, 3.2)
    box.Position = spawnPos + Vector3.new(0, 1.5, 0)
    box.Material = Enum.Material.SmoothPlastic
    box.Color = palette.DEEP_SLATE
    box.Anchored = true
    box.CanCollide = true
    box.Parent = model
    model.PrimaryPart = box

    -- Tapa superior abovedada
    local lid = Instance.new("Part")
    lid.Size = Vector3.new(4.4, 1.2, 3.4)
    lid.Position = box.Position + Vector3.new(0, 2.0, 0)
    lid.Material = Enum.Material.SmoothPlastic
    lid.Color = Color3.fromRGB(35, 42, 60)
    lid.Anchored = true
    lid.CanCollide = true
    lid.Parent = model

    -- Herrajes y marco de neón temático
    local trim = Instance.new("Part")
    trim.Size = Vector3.new(4.5, 0.4, 3.5)
    trim.Position = box.Position + Vector3.new(0, 1.35, 0)
    trim.Material = Enum.Material.Neon
    trim.Color = chestDef.Color
    trim.Transparency = 0.2
    trim.Anchored = true
    trim.CanCollide = false
    trim.Parent = model

    -- Cerradura / Gema de poder frontal
    local lockGem = Instance.new("Part")
    lockGem.Shape = Enum.PartType.Ball
    lockGem.Size = Vector3.new(1.2, 1.2, 1.2)
    lockGem.Position = box.Position + Vector3.new(0, 1.2, -1.65)
    lockGem.Material = Enum.Material.Neon
    lockGem.Color = chestDef.Color
    lockGem.Anchored = true
    lockGem.CanCollide = false
    lockGem.Parent = model

    local gemLight = Instance.new("PointLight")
    gemLight.Range = 10
    gemLight.Brightness = 1.2
    gemLight.Color = chestDef.Color
    gemLight.Parent = lockGem

    -- BILLBOARD GUI DE ESTADO DEL COFRE (Ocluido por objetos 3D y con distancia corta)
    local bb = Instance.new("BillboardGui")
    bb.Name = "CrateHUD"
    bb.Size = UDim2.fromOffset(160, 32)
    bb.StudsOffset = Vector3.new(0, 3.4, 0)
    bb.AlwaysOnTop = false -- ¡FALSO para no flotar a través de la cámara!
    bb.Adornee = box
    bb.MaxDistance = 35 -- Solo visible al acercarse al cofre
    bb.Parent = box

    local hitsLabel = Instance.new("TextLabel")
    hitsLabel.Name = "HitsText"
    hitsLabel.Size = UDim2.fromScale(1, 1)
    hitsLabel.BackgroundTransparency = 1
    hitsLabel.Font = Enum.Font.FredokaOne
    hitsLabel.Text = string.format("%s (%d/%d Golpes)", chestDef.Name, chestDef.MaxHealth, chestDef.MaxHealth)
    hitsLabel.TextColor3 = chestDef.Color
    hitsLabel.TextSize = 12
    hitsLabel.Parent = bb
    local s = Instance.new("UIStroke")
    s.Thickness = 1.5
    s.Color = Color3.new(0, 0, 0)
    s.Parent = hitsLabel

    model.Parent = CratesFolder
    return model
end

-- Spawnea un cofre en una posición aleatoria de la Gran Isla
local function SpawnCrate(chestKey: string)
    local chestDef = GameConfig.CHESTS[chestKey]
    if not chestDef then return end

    local angle = math.random() * math.pi * 2
    local dist = math.random(35, GameConfig.CENTER_ISLAND_RADIUS - 20)
    local spawnPos = Vector3.new(math.cos(angle) * dist, GameConfig.ISLAND_HEIGHT + 1.2, math.sin(angle) * dist)

    local model = CreateCrateModel(chestKey, chestDef, spawnPos)

    ActiveCrates[model] = {
        Def = chestDef,
        CurrentHits = 0,
        MaxHits = chestDef.MaxHealth,
        SpawnPos = spawnPos,
        IsBroken = false,
    }
end

-- Daña un cofre al ser golpeado por un arma
function CrateService.DamageCrate(crateModel: Model, attacker: Player): boolean
    local state = ActiveCrates[crateModel]
    if not state or state.IsBroken then return false end

    state.CurrentHits += 1
    local primary = crateModel.PrimaryPart
    local hitPos = primary and primary.Position or Vector3.new(0, 0, 0)

    -- Animación Squash & Stretch al recibir impacto
    if primary then
        local origSize = primary.Size
        primary.Size = Vector3.new(origSize.X * 1.2, origSize.Y * 0.8, origSize.Z * 1.2)
        task.delay(0.08, function()
            if primary and primary.Parent then
                primary.Size = origSize
            end
        end)
    end

    SpawnFloatingPopup(hitPos + Vector3.new(0, 2.5, 0), "💥 ¡GOLPE! (-1)", state.Def.Color)
    UpdateCrateHUD(crateModel)

    -- ¿Se rompieron todos los golpes requeridos?
    if state.CurrentHits >= state.MaxHits then
        state.IsBroken = true
        SpawnCrateBreakEffect(hitPos, state.Def.Color)

        local profile = DataService.GetProfile(attacker)
        local def = state.Def

        if profile then
            local ReactorService = require(script.Parent.ReactorService)
            profile.Energy += def.EnergyReward
            ReactorService.AddAuraXP(attacker, def.XPReward)

            -- Recompensa específica de tipo
            if def.Id == "aura_chest" then
                profile.OverchargeMeter = math.clamp(profile.OverchargeMeter + def.OverchargeReward, 0, profile.MaxOvercharge)
                SpawnFloatingPopup(hitPos + Vector3.new(0, 4, 0), "💎 ¡AURA +140 XP / +50% SOBRECARGA!", GameConfig.PALETTE.CYAN_PLASMA)
            elseif def.Id == "frenzy_chest" then
                -- Buff de Frenesí (2X Daño y +50% velocidad)
                FrenzyBuffs[attacker.UserId] = os.clock() + (def.BuffDuration or 25)
                local NotificationEvent = ReplicatedStorage.Remotes.NotificationEvent :: RemoteEvent
                NotificationEvent:FireClient(attacker, {
                    Type = "FrenzyBuff",
                    Title = "🔥 ¡FRENESÍ DE COMBATE ACTIVADO! (2X DAÑO POR 25s)",
                    Color = GameConfig.PALETTE.CRIMSON_SPARK,
                })
                SpawnFloatingPopup(hitPos + Vector3.new(0, 4, 0), "🔥 ¡FRENESÍ 2X ACTIVADO!", GameConfig.PALETTE.CRIMSON_SPARK)
            else
                SpawnFloatingPopup(hitPos + Vector3.new(0, 4, 0), "💰 +" .. tostring(def.EnergyReward) .. " ENERGÍA", GameConfig.PALETTE.ENERGY_GOLD)
            end

            local StateReplicated = ReplicatedStorage.Remotes.StateReplicated :: RemoteEvent
            StateReplicated:FireClient(attacker, profile)
        end

        ActiveCrates[crateModel] = nil
        crateModel:Destroy()

        -- Respawn automático
        task.delay(def.RespawnTime, function()
            for key, val in pairs(GameConfig.CHESTS) do
                if val.Id == def.Id then
                    SpawnCrate(key)
                    break
                end
            end
        end)
        return true
    end

    return false
end

-- Encuentra todos los cofres dentro del alcance de ataque
function CrateService.GetCratesInRange(position: Vector3, range: number): {Model}
    local results: {Model} = {}
    for crateModel, state in pairs(ActiveCrates) do
        if not state.IsBroken and crateModel.PrimaryPart then
            local dist = (crateModel.PrimaryPart.Position - position).Magnitude
            if dist <= range then
                table.insert(results, crateModel)
            end
        end
    end
    return results
end

-- Inicializa todos los cofres en la Gran Isla Central
function CrateService.Initialize()
    CratesFolder = Instance.new("Folder")
    CratesFolder.Name = "ArenaCrates"
    CratesFolder.Parent = Workspace

    -- Población inicial de cofres repartidos
    -- 5 Cofres de Energía
    for _ = 1, 5 do
        SpawnCrate("EnergyChest")
    end

    -- 4 Cofres de Aura
    for _ = 1, 4 do
        SpawnCrate("AuraChest")
    end

    -- 3 Cofres de Frenesí
    for _ = 1, 3 do
        SpawnCrate("FrenzyChest")
    end
end

return CrateService
