--!strict
-- MobService: Mobs procedurales estilizados, campamentos y recompensas en la Gran Isla Central
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("OverchargedShared")
local Types = require(Shared.Types.GameTypes)
local GameConfig = require(Shared.Config.GameConfig)

local DataService = require(script.Parent.DataService)
local IslandService = require(script.Parent.IslandService)

local MobService = {}

local MobsFolder: Folder
local ActiveMobs: { [Model]: {
    Def: any,
    CurrentHP: number,
    MaxHP: number,
    SpawnPos: Vector3,
    IsDead: boolean,
    LastAttackTime: number,
} } = {}

-- Spawnea un efecto de explosión cómica de estrellas al morir un mob
local function SpawnMobDeathEffect(position: Vector3, colorA: Color3, colorB: Color3)
    local p = Instance.new("Part")
    p.Size = Vector3.new(0.5, 0.5, 0.5)
    p.Position = position
    p.Transparency = 1
    p.Anchored = true
    p.CanCollide = false
    p.Parent = Workspace

    local att = Instance.new("Attachment", p)
    local emit = Instance.new("ParticleEmitter")
    emit.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    emit.Rate = 0
    emit.Speed = NumberRange.new(12, 24)
    emit.Lifetime = NumberRange.new(0.3, 0.6)
    emit.Color = ColorSequence.new(colorA, colorB)
    emit.LightEmission = 0.8
    emit.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1.4),
        NumberSequenceKeypoint.new(0.5, 2.0),
        NumberSequenceKeypoint.new(1, 0),
    })
    emit.Parent = att
    emit:Emit(25)

    -- Anillo expansivo
    local ring = Instance.new("Part")
    ring.Shape = Enum.PartType.Cylinder
    ring.Size = Vector3.new(0.2, 2, 2)
    ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi/2)
    ring.Material = Enum.Material.Neon
    ring.Color = colorA
    ring.Transparency = 0.2
    ring.Anchored = true
    ring.CanCollide = false
    ring.Parent = Workspace

    TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.1, 16, 16),
        Transparency = 1,
    }):Play()

    task.delay(0.6, function()
        if p and p.Parent then p:Destroy() end
        if ring and ring.Parent then ring:Destroy() end
    end)
end

-- Muestra número de daño flotante estilizado
local function SpawnDamageNumber(position: Vector3, damage: number, isCrit: boolean, color: Color3)
    local p = Instance.new("Part")
    p.Size = Vector3.new(0.1, 0.1, 0.1)
    p.Position = position + Vector3.new(math.random(-10, 10)/10, 0, math.random(-10, 10)/10)
    p.Transparency = 1
    p.Anchored = true
    p.CanCollide = false
    p.Parent = Workspace

    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.fromOffset(110, 36)
    bb.StudsOffset = Vector3.new(0, 1.2, 0)
    bb.AlwaysOnTop = true
    bb.Adornee = p
    bb.Parent = p

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.FredokaOne
    lbl.Text = isCrit and ("💥 -" .. tostring(damage) .. " CRIT!") or ("-" .. tostring(damage))
    lbl.TextColor3 = color
    lbl.TextSize = isCrit and 18 or 14
    lbl.Parent = bb

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1.5
    stroke.Color = Color3.new(0, 0, 0)
    stroke.Parent = lbl

    TweenService:Create(p, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = position + Vector3.new(0, 3.5, 0),
    }):Play()

    TweenService:Create(lbl, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        TextTransparency = 1,
    }):Play()

    task.delay(0.55, function()
        if p and p.Parent then p:Destroy() end
    end)
end

-- Actualiza el Billboard de vida de un Mob
local function UpdateMobHUD(mobModel: Model)
    local state = ActiveMobs[mobModel]
    if not state then return end

    local primary = mobModel.PrimaryPart
    if not primary then return end

    local bb = primary:FindFirstChild("MobHUD") :: BillboardGui?
    if not bb then return end

    local hpBg = bb:FindFirstChild("HPBg") :: Frame?
    if hpBg then
        local hpFill = hpBg:FindFirstChild("Fill") :: Frame?
        local hpText = hpBg:FindFirstChild("Text") :: TextLabel?

        if hpFill then
            local ratio = math.clamp(state.CurrentHP / state.MaxHP, 0, 1)
            TweenService:Create(hpFill, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.fromScale(ratio, 1),
            }):Play()
        end
        if hpText then
            hpText.Text = string.format("%d / %d HP", math.max(0, state.CurrentHP), state.MaxHP)
        end
    end
end

-- Construye el modelo 3D estilizado de un Mob según su tipo
local function CreateMobModel(mobKey: string, mobDef: any, spawnPos: Vector3): Model
    local model = Instance.new("Model")
    model.Name = "Mob_" .. mobDef.Id

    local palette = GameConfig.PALETTE

    if mobKey == "Sentinel" then
        -- 1. CENTINELA DE COBALTO (Robot orbe flotante con visor cian)
        local core = Instance.new("Part")
        core.Name = "HumanoidRootPart"
        core.Shape = Enum.PartType.Ball
        core.Size = Vector3.new(3.6, 3.6, 3.6)
        core.Position = spawnPos + Vector3.new(0, 3.5, 0)
        core.Material = Enum.Material.Metal
        core.Color = palette.DEEP_SLATE
        core.Anchored = true
        core.CanCollide = true
        core.Parent = model
        model.PrimaryPart = core

        -- Visor Luminoso Frontal
        local visor = Instance.new("Part")
        visor.Size = Vector3.new(2.4, 0.8, 1.2)
        visor.CFrame = core.CFrame * CFrame.new(0, 0.3, -1.5)
        visor.Material = Enum.Material.Neon
        visor.Color = mobDef.Accent
        visor.Anchored = true
        visor.CanCollide = false
        visor.Parent = model

        -- Aro Orbital Giratorio
        local ring = Instance.new("Part")
        ring.Shape = Enum.PartType.Cylinder
        ring.Size = Vector3.new(0.3, 5.2, 5.2)
        ring.CFrame = core.CFrame * CFrame.Angles(0, 0, math.rad(90))
        ring.Material = Enum.Material.Neon
        ring.Color = mobDef.Color
        ring.Transparency = 0.3
        ring.Anchored = true
        ring.CanCollide = false
        ring.Parent = model

        -- Animación de giro del aro
        task.spawn(function()
            while ring and ring.Parent do
                ring.CFrame = core.CFrame * CFrame.Angles(os.clock() * 1.5, os.clock() * 2, 0)
                task.wait(0.04)
            end
        end)

    elseif mobKey == "PlasmaGolem" then
        -- 2. GOLEM DE PLASMA (Gigante de piedra vinilo con pecho y ojos verdes)
        local torso = Instance.new("Part")
        torso.Name = "HumanoidRootPart"
        torso.Size = Vector3.new(5.0, 6.0, 3.4)
        torso.Position = spawnPos + Vector3.new(0, 4.0, 0)
        torso.Material = Enum.Material.Metal
        torso.Color = Color3.fromRGB(34, 42, 60)
        torso.Anchored = true
        torso.CanCollide = true
        torso.Parent = model
        model.PrimaryPart = torso

        -- Cabeza de golem
        local head = Instance.new("Part")
        head.Size = Vector3.new(3.0, 2.5, 2.6)
        head.Position = torso.Position + Vector3.new(0, 4.2, 0)
        head.Material = Enum.Material.Metal
        head.Color = palette.DEEP_SLATE
        head.Anchored = true
        head.CanCollide = true
        head.Parent = model

        local eyes = Instance.new("Part")
        eyes.Size = Vector3.new(2.0, 0.6, 0.8)
        eyes.Position = head.Position + Vector3.new(0, 0.2, -1.2)
        eyes.Material = Enum.Material.Neon
        eyes.Color = mobDef.Accent
        eyes.Anchored = true
        eyes.CanCollide = false
        eyes.Parent = model

        -- Núcleo de plasma en el pecho
        local chestCore = Instance.new("Part")
        chestCore.Shape = Enum.PartType.Ball
        chestCore.Size = Vector3.new(2.4, 2.4, 2.4)
        chestCore.Position = torso.Position + Vector3.new(0, 0.4, -1.2)
        chestCore.Material = Enum.Material.Neon
        chestCore.Color = mobDef.Accent
        chestCore.Anchored = true
        chestCore.CanCollide = false
        chestCore.Parent = model

        -- Puños flotantes
        for side = -1, 1, 2 do
            local fist = Instance.new("Part")
            fist.Size = Vector3.new(2.4, 3.2, 2.4)
            fist.Position = torso.Position + Vector3.new(side * 4.2, -0.5, -0.6)
            fist.Material = Enum.Material.Metal
            fist.Color = palette.DEEP_SLATE
            fist.Anchored = true
            fist.CanCollide = true
            fist.Parent = model
        end

    else
        -- 3. ESPECTRO DEL VACÍO (Monolito etéreo con alas de neón violeta)
        local core = Instance.new("Part")
        core.Name = "HumanoidRootPart"
        core.Size = Vector3.new(3.2, 5.5, 2.4)
        core.Position = spawnPos + Vector3.new(0, 5.0, 0)
        core.Material = Enum.Material.Metal
        core.Color = Color3.fromRGB(24, 18, 38)
        core.Anchored = true
        core.CanCollide = true
        core.Parent = model
        model.PrimaryPart = core

        -- Corona de vacío
        local crown = Instance.new("Part")
        crown.Size = Vector3.new(3.6, 1.2, 2.6)
        crown.Position = core.Position + Vector3.new(0, 3.4, 0)
        crown.Material = Enum.Material.Neon
        crown.Color = mobDef.Accent
        crown.Anchored = true
        crown.CanCollide = false
        crown.Parent = model

        -- Alas de plasma violeta
        for side = -1, 1, 2 do
            local wing = Instance.new("Part")
            wing.Size = Vector3.new(0.3, 4.8, 1.8)
            wing.CFrame = core.CFrame * CFrame.new(side * 2.8, 1.2, 0.6) * CFrame.Angles(0, 0, math.rad(side * -25))
            wing.Material = Enum.Material.Neon
            wing.Color = mobDef.Accent
            wing.Transparency = 0.25
            wing.Anchored = true
            wing.CanCollide = false
            wing.Parent = model
        end
    end

    -- BILLBOARD GUI DE VIDA Y NOMBRE (Ocluido por objetos 3D y con distancia corta)
    local primary = model.PrimaryPart :: BasePart
    local bb = Instance.new("BillboardGui")
    bb.Name = "MobHUD"
    bb.Size = UDim2.fromOffset(130, 38)
    bb.StudsOffset = Vector3.new(0, 4.2, 0)
    bb.AlwaysOnTop = false -- ¡FALSO para no flotar a través del avatar ni traspasar paredes!
    bb.Adornee = primary
    bb.MaxDistance = 35 -- Solo visible al estar cerca en combate
    bb.Parent = primary

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0.45, 0)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.FredokaOne
    title.Text = mobDef.Name
    title.TextColor3 = mobDef.Accent
    title.TextSize = 11
    title.Parent = bb
    local s1 = Instance.new("UIStroke")
    s1.Thickness = 1.5
    s1.Color = Color3.new(0, 0, 0)
    s1.Parent = title

    local hpBg = Instance.new("Frame")
    hpBg.Name = "HPBg"
    hpBg.Size = UDim2.new(1, 0, 0.45, 0)
    hpBg.Position = UDim2.new(0, 0, 0.5, 0)
    hpBg.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
    hpBg.Parent = bb
    local cr = Instance.new("UICorner")
    cr.CornerRadius = UDim.new(0, 6)
    cr.Parent = hpBg

    local hpFill = Instance.new("Frame")
    hpFill.Name = "Fill"
    hpFill.Size = UDim2.fromScale(1, 1)
    hpFill.BackgroundColor3 = mobDef.Color
    hpFill.BorderSizePixel = 0
    hpFill.Parent = hpBg
    local cr2 = Instance.new("UICorner")
    cr2.CornerRadius = UDim.new(0, 6)
    cr2.Parent = hpFill

    local hpText = Instance.new("TextLabel")
    hpText.Name = "Text"
    hpText.Size = UDim2.fromScale(1, 1)
    hpText.BackgroundTransparency = 1
    hpText.Font = Enum.Font.FredokaOne
    hpText.Text = string.format("%d / %d HP", mobDef.MaxHealth, mobDef.MaxHealth)
    hpText.TextColor3 = Color3.fromRGB(255, 255, 255)
    hpText.TextSize = 9
    hpText.ZIndex = 3
    hpText.Parent = hpBg

    model.Parent = MobsFolder
    return model
end

-- Spawnea un Mob específico en un radio determinado
local function SpawnMob(mobKey: string)
    local mobDef = GameConfig.MOBS[mobKey]
    if not mobDef then return end

    local angle = math.random() * math.pi * 2
    local dist = math.random(mobDef.MinRadius, mobDef.MaxRadius)
    local spawnPos = Vector3.new(math.cos(angle) * dist, GameConfig.ISLAND_HEIGHT + 1.2, math.sin(angle) * dist)

    local model = CreateMobModel(mobKey, mobDef, spawnPos)

    ActiveMobs[model] = {
        Def = mobDef,
        CurrentHP = mobDef.MaxHealth,
        MaxHP = mobDef.MaxHealth,
        SpawnPos = spawnPos,
        IsDead = false,
        LastAttackTime = 0,
    }
end

-- Aplica daño a un Mob al recibir un golpe de arma
function MobService.DamageMob(mobModel: Model, damage: number, attacker: Player): boolean
    local state = ActiveMobs[mobModel]
    if not state or state.IsDead then return false end

    state.CurrentHP = math.max(0, state.CurrentHP - damage)
    local primary = mobModel.PrimaryPart
    local hitPos = primary and primary.Position or Vector3.new(0, 0, 0)

    SpawnDamageNumber(hitPos + Vector3.new(0, 2.5, 0), damage, damage >= 100, state.Def.Accent)
    UpdateMobHUD(mobModel)

    -- Animación de impacto Squash
    if primary then
        local origSize = primary.Size
        primary.Size = origSize * 1.15
        task.delay(0.08, function()
            if primary and primary.Parent then
                primary.Size = origSize
            end
        end)
    end

    -- Muerte del Mob
    if state.CurrentHP <= 0 then
        state.IsDead = true
        SpawnMobDeathEffect(hitPos, state.Def.Color, state.Def.Accent)

        -- Recompensa para el atacante
        local profile = DataService.GetProfile(attacker)
        if profile then
            local ReactorService = require(script.Parent.ReactorService)
            profile.Energy += state.Def.EnergyReward
            profile.OverchargeMeter = math.clamp(profile.OverchargeMeter + state.Def.OverchargeReward, 0, profile.MaxOvercharge)
            ReactorService.AddAuraXP(attacker, state.Def.XPReward)

            local StateReplicated = ReplicatedStorage.Remotes.StateReplicated :: RemoteEvent
            StateReplicated:FireClient(attacker, profile)
        end

        ActiveMobs[mobModel] = nil
        mobModel:Destroy()

        -- Respawn tras el tiempo configurado
        local def = state.Def
        task.delay(def.RespawnTime, function()
            for key, val in pairs(GameConfig.MOBS) do
                if val.Id == def.Id then
                    SpawnMob(key)
                    break
                end
            end
        end)
        return true
    end

    return false
end

-- Encuentra todos los Mobs vivos dentro de un radio de ataque
function MobService.GetMobsInRange(position: Vector3, range: number): {Model}
    local results: {Model} = {}
    for mobModel, state in pairs(ActiveMobs) do
        if not state.IsDead and mobModel.PrimaryPart then
            local dist = (mobModel.PrimaryPart.Position - position).Magnitude
            if dist <= range then
                table.insert(results, mobModel)
            end
        end
    end
    return results
end

-- Inicializa el ecosistema de Mobs en la Gran Isla Central
function MobService.Initialize()
    MobsFolder = Instance.new("Folder")
    MobsFolder.Name = "ArenaMobs"
    MobsFolder.Parent = Workspace

    -- Spawnea población balanceada en la Gran Isla
    -- 6 Centinelas de Cobalto en la zona exterior
    for _ = 1, 6 do
        SpawnMob("Sentinel")
    end

    -- 5 Golems de Plasma en la zona media
    for _ = 1, 5 do
        SpawnMob("PlasmaGolem")
    end

    -- 3 Espectros del Vacío cerca de la zona interior
    for _ = 1, 3 do
        SpawnMob("VoidWraith")
    end

    -- Bucle pasivo de contraataque ligero si el jugador está demasiado cerca
    task.spawn(function()
        while true do
            task.wait(1.5)
            local now = os.clock()
            for mobModel, state in pairs(ActiveMobs) do
                if not state.IsDead and mobModel.PrimaryPart then
                    local mobPos = mobModel.PrimaryPart.Position
                    for _, player in ipairs(Players:GetPlayers()) do
                        local char = player.Character
                        local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
                        local hum = char and char:FindFirstChildOfClass("Humanoid")
                        if root and hum and hum.Health > 0 then
                            local d = (root.Position - mobPos).Magnitude
                            if d <= 8.5 and (now - state.LastAttackTime) >= 2.5 then
                                state.LastAttackTime = now
                                hum:TakeDamage(12)
                                SpawnDamageNumber(root.Position + Vector3.new(0, 2, 0), 12, false, GameConfig.PALETTE.CRIMSON_SPARK)
                            end
                        end
                    end
                end
            end
        end
    end)
end

return MobService
