--!strict
-- CombatService: Armas estilizadas procedurales, combate escalado por Nivel de Aura y orbes
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("OverchargedShared")
local Types = require(Shared.Types.GameTypes)
local GameConfig = require(Shared.Config.GameConfig)

local DataService = require(script.Parent.DataService)
local IslandService = require(script.Parent.IslandService)
local AuraService = require(script.Parent.AuraService)
local FormatNumber = require(Shared.Utils.FormatNumber)

local CombatService = {}
local BoosterFolder: Folder
local TitanCurrentHP: number = GameConfig.TITAN.MaxHealth
local IsTitanDefeated: boolean = false

-- Encuentra la mejor arma disponible según el nivel de aura
local function GetBestWeaponForLevel(level: number): Types.WeaponDefinition
    local best = GameConfig.WEAPONS[1]
    for _, weapon in ipairs(GameConfig.WEAPONS) do
        if level >= weapon.RequiredAuraLevel then
            best = weapon
        end
    end
    return best
end

-- Ajusta las estadísticas de combate del personaje (Salud y Velocidad) según su Aura y Nivel
function CombatService.ApplyAuraStats(player: Player)
    local character = player.Character
    if not character then return end

    local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
    if not humanoid then return end

    local profile = DataService.GetProfile(player)
    if not profile then return end

    local auraDef = AuraService.GetAuraByName(profile.CurrentAura)
    local level = profile.AuraLevel or 1

    -- Bono de salud: Base + Bono de Aura + Escalado por Nivel (2 HP por nivel)
    local levelHealthBonus = math.floor(level * 2)
    humanoid.MaxHealth = 100 + auraDef.HealthBonus + levelHealthBonus
    humanoid.Health = humanoid.MaxHealth

    -- Bono de velocidad escalado
    local levelSpeedBonus = math.clamp(math.floor(level * 0.05), 0, 15)
    humanoid.WalkSpeed = 16 + auraDef.SpeedBonus + levelSpeedBonus
end

-- EFECTO VISUAL STARBURST DE IMPACTO ESTILIZADO (Estilo Cómic / Cero Sangre)
local function SpawnImpactStarburst(position: Vector3, colorA: Color3, colorB: Color3)
    local emitterPart = Instance.new("Part")
    emitterPart.Name = "ImpactEffect"
    emitterPart.Size = Vector3.new(0.5, 0.5, 0.5)
    emitterPart.Position = position
    emitterPart.Transparency = 1
    emitterPart.Anchored = true
    emitterPart.CanCollide = false
    emitterPart.Parent = Workspace

    local attachment = Instance.new("Attachment", emitterPart)

    -- Partículas de chispas estelares (Comic Stars)
    local stars = Instance.new("ParticleEmitter")
    stars.Rate = 0
    stars.Speed = NumberRange.new(15, 30)
    stars.Lifetime = NumberRange.new(0.2, 0.45)
    stars.SpreadAngle = Vector2.new(180, 180)
    stars.Color = ColorSequence.new(colorA, colorB)
    stars.LightEmission = 0.8
    stars.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1.2),
        NumberSequenceKeypoint.new(0.4, 1.8),
        NumberSequenceKeypoint.new(1, 0),
    })
    stars.Parent = attachment
    stars:Emit(18)

    -- Anillo de choque luminoso en expansión
    local ring = Instance.new("Part")
    ring.Shape = Enum.PartType.Cylinder
    ring.Size = Vector3.new(0.2, 1.5, 1.5)
    ring.CFrame = CFrame.new(position) * CFrame.Angles(math.random() * math.pi, math.random() * math.pi, math.random() * math.pi)
    ring.Material = Enum.Material.Neon
    ring.Color = colorA
    ring.Transparency = 0.2
    ring.Anchored = true
    ring.CanCollide = false
    ring.Parent = Workspace

    TweenService:Create(ring, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.1, 9, 9),
        Transparency = 1,
    }):Play()

    task.delay(0.5, function()
        if emitterPart and emitterPart.Parent then emitterPart:Destroy() end
        if ring and ring.Parent then ring:Destroy() end
    end)
end

-- NÚMEROS DE DAÑO FLOTANTES ESTILIZADOS
local function SpawnFloatingDamageNumber(position: Vector3, damage: number, isCritical: boolean, accentColor: Color3)
    local tagPart = Instance.new("Part")
    tagPart.Size = Vector3.new(1, 1, 1)
    tagPart.Position = position + Vector3.new(math.random(-1, 1) * 0.8, 1.5, math.random(-1, 1) * 0.8)
    tagPart.Transparency = 1
    tagPart.Anchored = true
    tagPart.CanCollide = false
    tagPart.Parent = Workspace

    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.fromScale(4.5, 2.2)
    billboard.AlwaysOnTop = true
    billboard.Adornee = tagPart
    billboard.MaxDistance = 100
    billboard.Parent = tagPart

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.FredokaOne
    label.Text = isCritical and string.format("💥 -%d CRIT!", damage) or string.format("-%d", damage)
    label.TextColor3 = isCritical and GameConfig.PALETTE.CRIMSON_SPARK or GameConfig.PALETTE.ENERGY_GOLD
    label.TextScaled = true
    label.Parent = billboard

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2.5
    stroke.Color = Color3.new(0, 0, 0)
    stroke.Parent = label

    TweenService:Create(tagPart, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = tagPart.Position + Vector3.new(0, 4.5, 0),
    }):Play()

    TweenService:Create(label, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        TextTransparency = 1,
    }):Play()

    task.delay(0.7, function()
        if tagPart and tagPart.Parent then tagPart:Destroy() end
    end)
end

-- Construye un arma estilizada en 3D (Silueta Chunky, Bordes Biselados, PBR Vinilo y Neón)
local function BuildProceduralWeapon(weaponDef: Types.WeaponDefinition, auraDef: Types.AuraDefinition): Tool
    local tool = Instance.new("Tool")
    tool.Name = "AuraWeapon"
    tool.ToolTip = string.format("[%s] %s [Nv. %d+] - %d Daño", weaponDef.RarityName or "Común", weaponDef.Name, weaponDef.RequiredAuraLevel, weaponDef.Damage)
    tool.RequiresHandle = true
    tool.CanBeDropped = false

    local palette = GameConfig.PALETTE

    -- Empuñadura Principal Chunky (Handle de vinilo mate reforzado)
    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.new(0.7, 2.0, 0.7)
    handle.Material = Enum.Material.SmoothPlastic
    handle.Color = palette.DEEP_SLATE
    handle.CanCollide = false
    handle.Massless = true
    handle.Parent = tool

    -- Grip ergonómico en la mano derecha
    tool.GripPos = Vector3.new(0, -0.6, 0)
    tool.GripForward = Vector3.new(0, 1, 0)
    tool.GripRight = Vector3.new(1, 0, 0)
    tool.GripUp = Vector3.new(0, 0, 1)

    local function CreateToolWeld(p0: BasePart, p1: BasePart, c0: CFrame): Weld
        local weld = Instance.new("Weld")
        weld.Part0 = p0
        weld.Part1 = p1
        weld.C0 = c0
        weld.Parent = p1
        return weld
    end

    -- Pomo inferior biselado
    local pommel = Instance.new("Part")
    pommel.Shape = Enum.PartType.Ball
    pommel.Size = Vector3.new(1.1, 1.1, 1.1)
    pommel.Material = Enum.Material.Neon
    pommel.Color = weaponDef.AccentColor
    pommel.CanCollide = false
    pommel.Massless = true
    pommel.Parent = tool
    CreateToolWeld(handle, pommel, CFrame.new(0, -1.1, 0))

    -- Guarda ancha estilizada (Crossguard angular)
    local guard = Instance.new("Part")
    guard.Size = Vector3.new(2.6, 0.6, 1.1)
    guard.Material = Enum.Material.SmoothPlastic
    guard.Color = palette.DEEP_SLATE
    guard.CanCollide = false
    guard.Massless = true
    guard.Parent = tool
    CreateToolWeld(handle, guard, CFrame.new(0, 1.0, 0))

    -- Inlays luminosos en la guardia
    local guardCore = Instance.new("Part")
    guardCore.Size = Vector3.new(2.2, 0.35, 1.2)
    guardCore.Material = Enum.Material.Neon
    guardCore.Color = weaponDef.AccentColor
    guardCore.CanCollide = false
    guardCore.Massless = true
    guardCore.Parent = tool
    CreateToolWeld(guard, guardCore, CFrame.new(0, 0, 0))

    -- Dimensiones de la hoja según el arquetipo de silueta
    local bladeLength = 4.0
    local bladeWidth = 1.0
    if weaponDef.WeaponType == "Dagger" then
        bladeLength = 3.2
        bladeWidth = 1.3
    elseif weaponDef.WeaponType == "Katana" then
        bladeLength = 6.2
        bladeWidth = 1.0
    elseif weaponDef.WeaponType == "Greatsword" then
        bladeLength = 8.5
        bladeWidth = 2.4
    elseif weaponDef.WeaponType == "Scythe" then
        bladeLength = 7.0
        bladeWidth = 1.2
    elseif weaponDef.WeaponType == "CosmicGlaive" then
        bladeLength = 7.8
        bladeWidth = 1.6
    end

    -- Filo exterior estilizado tipo cristal/vinilo
    local blade = Instance.new("Part")
    blade.Name = "BladePart"
    blade.Size = Vector3.new(0.4, bladeLength, bladeWidth)
    blade.Material = Enum.Material.Glass
    blade.Transparency = 0.15
    blade.Color = weaponDef.AccentColor
    blade.CanCollide = false
    blade.Massless = true
    blade.Parent = tool
    CreateToolWeld(handle, blade, CFrame.new(0, 1.0 + (bladeLength / 2), 0))

    -- Núcleo interno de plasma brillante en el centro del filo
    local coreVein = Instance.new("Part")
    coreVein.Size = Vector3.new(0.2, bladeLength * 0.88, bladeWidth * 0.45)
    coreVein.Material = Enum.Material.Neon
    coreVein.Color = auraDef.RarityColor
    coreVein.CanCollide = false
    coreVein.Massless = true
    coreVein.Parent = tool
    CreateToolWeld(blade, coreVein, CFrame.new(0, 0, 0))

    -- Detalle especial: Corona lunar para Guadaña
    if weaponDef.WeaponType == "Scythe" then
        local scytheHead = Instance.new("Part")
        scytheHead.Size = Vector3.new(0.4, 1.6, 5.2)
        scytheHead.Material = Enum.Material.Glass
        scytheHead.Transparency = 0.2
        scytheHead.Color = auraDef.RarityColor
        scytheHead.CanCollide = false
        scytheHead.Massless = true
        scytheHead.Parent = tool
        CreateToolWeld(blade, scytheHead, CFrame.new(0, bladeLength / 2, -2.2) * CFrame.Angles(0, 0, math.rad(28)))

        -- Aureola solar giratoria flotante
        local halo = Instance.new("Part")
        halo.Shape = Enum.PartType.Cylinder
        halo.Size = Vector3.new(0.3, 3.2, 3.2)
        halo.Material = Enum.Material.Neon
        halo.Color = palette.ENERGY_GOLD
        halo.CanCollide = false
        halo.Massless = true
        halo.Parent = tool
        CreateToolWeld(blade, halo, CFrame.new(0, (bladeLength / 2) - 1, 0) * CFrame.Angles(0, 0, math.pi/2))
    end

    -- Luz suave equilibrada
    local light = Instance.new("PointLight")
    light.Range = 10
    light.Brightness = 0.7
    light.Color = weaponDef.AccentColor
    light.Parent = blade

    -- Partículas sutiles de estela en el filo
    local att = Instance.new("Attachment", blade)
    local particles = Instance.new("ParticleEmitter")
    particles.Rate = 10
    particles.Speed = NumberRange.new(1.5, 3)
    particles.Lifetime = NumberRange.new(0.2, 0.4)
    particles.Color = ColorSequence.new(weaponDef.AccentColor, auraDef.RarityColor)
    particles.LightEmission = 0.4
    particles.Size = NumberSequence.new(0.45, 0)
    particles.Parent = att

    -- Script de cliente interactivo para animación inmediata y sonido de tajo
    local localScript = Instance.new("LocalScript")
    localScript.Name = "WeaponClient"
    localScript.Source = [[
        local tool = script.Parent :: Tool
        local TweenService = game:GetService("TweenService")
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local player = game:GetService("Players").LocalPlayer

        local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
        local RequestAttack = remotes and remotes:WaitForChild("RequestAttack", 10) :: RemoteEvent?

        local slashSound = Instance.new("Sound")
        slashSound.Name = "SlashSound"
        slashSound.SoundId = "rbxassetid://9114223171"
        slashSound.Volume = 0.75
        slashSound.Pitch = 1.15
        slashSound.Parent = tool

        local canSwing = true

        tool.Activated:Connect(function()
            if not canSwing then return end
            canSwing = false

            slashSound:Play()

            -- Animación de movimiento del brazo derecho al blandir
            local char = player.Character
            if char then
                local rightArm = char:FindFirstChild("Right Arm") or char:FindFirstChild("RightHand")
                local torso = char:FindFirstChild("Torso") or char:FindFirstChild("RightUpperArm")
                if rightArm and torso then
                    local joint = rightArm:FindFirstChildOfClass("Motor6D") or torso:FindFirstChildOfClass("Motor6D")
                    if joint then
                        local origC0 = joint.C0
                        TweenService:Create(joint, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                            C0 = origC0 * CFrame.Angles(math.rad(65), math.rad(-25), 0)
                        }):Play()

                        task.delay(0.12, function()
                            TweenService:Create(joint, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                                C0 = origC0
                            }):Play()
                        end)
                    end
                end
            end

            if RequestAttack then
                RequestAttack:FireServer()
            end

            task.wait(0.25)
            canSwing = true
        end)
    ]]
    localScript.Parent = tool

    return tool
end

local AttackCooldowns: { [number]: number } = {}

-- EFECTO DE ONDA DE TAJO (Slash Wave Luminosa)
local function SpawnSlashWave(rootCFrame: CFrame, color: Color3)
    local wave = Instance.new("Part")
    wave.Name = "SlashArc"
    wave.Shape = Enum.PartType.Cylinder
    wave.Size = Vector3.new(0.2, 5.5, 5.5)
    wave.CFrame = rootCFrame * CFrame.new(0, 0, -3.2) * CFrame.Angles(math.rad(15), 0, math.rad(90))
    wave.Material = Enum.Material.Neon
    wave.Color = color
    wave.Transparency = 0.2
    wave.Anchored = true
    wave.CanCollide = false
    wave.Parent = Workspace

    TweenService:Create(wave, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.05, 12, 12),
        Transparency = 1,
        CFrame = wave.CFrame * CFrame.new(0, 2.5, 0),
    }):Play()

    task.delay(0.25, function()
        if wave and wave.Parent then wave:Destroy() end
    end)
end

-- Ejecuta el ataque autoritativo de un jugador (golpea mobs, cofres, jefe o jugadores)
function CombatService.ProcessPlayerAttack(player: Player)
    local character = player.Character
    if not character then return end
    local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not root then return end

    local profile = DataService.GetProfile(player)
    if not profile then return end

    local weaponDef = GetBestWeaponForLevel(profile.AuraLevel or 1)
    local now = os.clock()
    local lastAttack = AttackCooldowns[player.UserId] or 0
    if (now - lastAttack) < (weaponDef.Cooldown * 0.7) then
        return
    end
    AttackCooldowns[player.UserId] = now

    local auraDef = AuraService.GetAuraByName(profile.CurrentAura)
    local baseDamage = math.floor(weaponDef.Damage * auraDef.Multiplier)

    -- Multiplicador por Buff de Frenesí (Cofres carmesí)
    local CrateService = require(script.Parent.CrateService)
    if CrateService.HasFrenzyBuff(player) then
        baseDamage = math.floor(baseDamage * 2.0)
    end

    -- Efecto de tajo visual frontal (se produce en cualquier zona donde blandas el arma)
    SpawnSlashWave(root.CFrame, weaponDef.AccentColor)

    local attackCFrame = root.CFrame * CFrame.new(0, 0, -(weaponDef.Range / 2))

    -- 1. DETECCIÓN DE IMPACTO EN MOBS EN EL MAPA
    local MobService = require(script.Parent.MobService)
    local hitMobs = MobService.GetMobsInRange(attackCFrame.Position, weaponDef.Range + 5)
    for _, mob in ipairs(hitMobs) do
        local mobPos = mob.PrimaryPart and mob.PrimaryPart.Position or attackCFrame.Position
        MobService.DamageMob(mob, baseDamage, player)
        SpawnImpactStarburst(mobPos, weaponDef.AccentColor, auraDef.RarityColor)
    end

    -- 2. DETECCIÓN DE IMPACTO EN COFRES Y CAJAS
    local hitCrates = CrateService.GetCratesInRange(attackCFrame.Position, weaponDef.Range + 5)
    for _, crate in ipairs(hitCrates) do
        local cratePos = crate.PrimaryPart and crate.PrimaryPart.Position or attackCFrame.Position
        CrateService.DamageCrate(crate, player)
        SpawnImpactStarburst(cratePos, weaponDef.AccentColor, GameConfig.PALETTE.ENERGY_GOLD)
    end

    -- 3. DETECCIÓN DE IMPACTO EN EL TITÁN DE SOBRECARGA
    local titanWeakspot = Workspace:FindFirstChild("Map")
        and Workspace.Map:FindFirstChild("CentralIsland")
        and Workspace.Map.CentralIsland:FindFirstChild("TitanBoss")
        and Workspace.Map.CentralIsland.TitanBoss:FindFirstChild("TitanWeakspot") :: BasePart?

    if titanWeakspot and not IsTitanDefeated then
        local distToTitan = (titanWeakspot.Position - attackCFrame.Position).Magnitude
        if distToTitan <= (weaponDef.Range + 16) then
            local bossDamage = math.floor(baseDamage * GameConfig.TITAN.WeakspotMultiplier)
            TitanCurrentHP = math.max(0, TitanCurrentHP - bossDamage)
            UpdateTitanHUD()

            SpawnImpactStarburst(titanWeakspot.Position, weaponDef.AccentColor, GameConfig.PALETTE.ENERGY_GOLD)
            SpawnFloatingDamageNumber(titanWeakspot.Position + Vector3.new(0, 4, 0), bossDamage, true, GameConfig.PALETTE.ENERGY_GOLD)

            profile.Energy += GameConfig.TITAN.BaseEnergyReward
            profile.OverchargeMeter = math.clamp(profile.OverchargeMeter + 12, 0, profile.MaxOvercharge)
            local ReactorService = require(script.Parent.ReactorService)
            ReactorService.AddAuraXP(player, GameConfig.TITAN.BaseXPReward)

            local StateReplicated = game:GetService("ReplicatedStorage").Remotes.StateReplicated :: RemoteEvent
            StateReplicated:FireClient(player, profile)

            if TitanCurrentHP <= 0 then
                OnTitanDefeated()
            end
        end
    end

    -- 4. DETECCIÓN DE IMPACTO EN OTROS JUGADORES EN ARENA PVP
    if IslandService.IsInPvPZone(root.Position) then
        for _, otherPlayer in ipairs(Players:GetPlayers()) do
            if otherPlayer ~= player and otherPlayer.Character then
                local otherRoot = otherPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                local otherHumanoid = otherPlayer.Character:FindFirstChildOfClass("Humanoid")

                if otherRoot and otherHumanoid and otherHumanoid.Health > 0 then
                    if IslandService.IsInPvPZone(otherRoot.Position) then
                        local distance = (otherRoot.Position - attackCFrame.Position).Magnitude
                        if distance <= weaponDef.Range then
                            otherHumanoid:TakeDamage(baseDamage)
                            SpawnImpactStarburst(otherRoot.Position, weaponDef.AccentColor, auraDef.RarityColor)
                            SpawnFloatingDamageNumber(otherRoot.Position + Vector3.new(0, 3, 0), baseDamage, false, weaponDef.AccentColor)

                            local knockback = (otherRoot.Position - root.Position).Unit
                            otherRoot.AssemblyLinearVelocity = (knockback * 65) + Vector3.new(0, 25, 0)

                            local ReactorService = require(script.Parent.ReactorService)
                            ReactorService.AddAuraXP(player, 20)
                        end
                    end
                end
            end
        end
    end
end

-- Otorga el arma correspondiente al nivel del jugador
function CombatService.GiveAuraBlade(player: Player)
    local profile = DataService.GetProfile(player)
    if not profile then return end

    local auraDef = AuraService.GetAuraByName(profile.CurrentAura)
    local weaponDef = GetBestWeaponForLevel(profile.AuraLevel or 1)
    local backpack = player:WaitForChild("Backpack")

    -- Remover arma previa
    for _, old in ipairs(backpack:GetChildren()) do
        if old:IsA("Tool") then old:Destroy() end
    end
    if player.Character then
        local oldCharTool = player.Character:FindFirstChildOfClass("Tool")
        if oldCharTool then oldCharTool:Destroy() end
    end

    -- Construir y configurar nueva arma estilizada
    local tool = BuildProceduralWeapon(weaponDef, auraDef)

    -- Fallback de servidor si se activa directamente
    tool.Activated:Connect(function()
        CombatService.ProcessPlayerAttack(player)
    end)

    tool.Parent = backpack

    -- Auto-equipar inmediatamente el arma en la mano del jugador
    task.spawn(function()
        local character = player.Character or player.CharacterAdded:Wait()
        local humanoid = character:WaitForChild("Humanoid", 6) :: Humanoid?
        if humanoid and tool and (tool.Parent == backpack or tool.Parent == character) then
            task.wait(0.1)
            pcall(function()
                humanoid:EquipTool(tool)
            end)
        end
    end)
end

-- Funciones auxiliares del Jefe Titán de Sobrecarga
local function GetTitanModel(): Model?
    local map = Workspace:FindFirstChild("Map")
    local central = map and map:FindFirstChild("CentralIsland")
    return central and central:FindFirstChild("TitanBoss") :: Model?
end

function UpdateTitanHUD()
    local titan = GetTitanModel()
    if not titan then return end
    local torso = titan:FindFirstChild("TitanTorso") :: BasePart?
    if not torso then return end
    local bossHUD = torso:FindFirstChild("TitanBossHUD") :: BillboardGui?
    if not bossHUD then return end

    local hpBg = bossHUD:FindFirstChild("BossHPBg") :: Frame?
    if hpBg then
        local hpFill = hpBg:FindFirstChild("BossHPFill") :: Frame?
        local hpText = hpBg:FindFirstChild("BossHPText") :: TextLabel?

        if hpFill then
            local ratio = math.clamp(TitanCurrentHP / GameConfig.TITAN.MaxHealth, 0, 1)
            TweenService:Create(hpFill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.fromScale(ratio, 1)
            }):Play()
        end
        if hpText then
            if IsTitanDefeated then
                hpText.Text = "⚡ DERROTADO - RENACIENDO..."
            else
                hpText.Text = string.format("%s / %s HP (Punto Débil: Ojo)", FormatNumber.FormatCompact(TitanCurrentHP), FormatNumber.FormatCompact(GameConfig.TITAN.MaxHealth))
            end
        end
    end
end

-- Genera un Cristal de Hipercarga al derrotar al Titán
local function SpawnHyperchargeCrystal(position: Vector3)
    if not BoosterFolder then return end

    local crystal = Instance.new("Part")
    crystal.Name = "HyperchargeCrystal"
    crystal.Size = Vector3.new(2.8, 4.2, 2.8)
    crystal.Position = position
    crystal.Material = Enum.Material.Neon
    crystal.Color = GameConfig.PALETTE.ENERGY_GOLD
    crystal.CanCollide = false
    crystal.Anchored = true
    crystal.Parent = BoosterFolder

    local pLight = Instance.new("PointLight")
    pLight.Range = 16
    pLight.Brightness = 1.8
    pLight.Color = GameConfig.PALETTE.ENERGY_GOLD
    pLight.Parent = crystal

    -- Animación de giro suave
    task.spawn(function()
        while crystal and crystal.Parent do
            crystal.CFrame = crystal.CFrame * CFrame.Angles(0, math.rad(4), 0)
            task.wait(0.03)
        end
    end)

    local collected = false
    crystal.Touched:Connect(function(hit)
        if collected then return end
        local player = Players:GetPlayerFromCharacter(hit.Parent)
        if player then
            collected = true
            local profile = DataService.GetProfile(player)
            if profile then
                local ReactorService = require(script.Parent.ReactorService)
                profile.Energy += 1500
                profile.OverchargeMeter = math.clamp(profile.OverchargeMeter + 40, 0, profile.MaxOvercharge)
                ReactorService.AddAuraXP(player, 80)

                SpawnImpactStarburst(crystal.Position, GameConfig.PALETTE.ENERGY_GOLD, GameConfig.PALETTE.CYAN_PLASMA)
                SpawnFloatingDamageNumber(crystal.Position + Vector3.new(0, 3, 0), 1500, true, GameConfig.PALETTE.ENERGY_GOLD)

                local StateReplicated = game:GetService("ReplicatedStorage").Remotes.StateReplicated :: RemoteEvent
                StateReplicated:FireClient(player, profile)
            end
            crystal:Destroy()
        end
    end)

    task.delay(28, function()
        if crystal and crystal.Parent then crystal:Destroy() end
    end)
end

-- Se ejecuta al derrotar completamente al Titán de Sobrecarga
function OnTitanDefeated()
    if IsTitanDefeated then return end
    IsTitanDefeated = true
    TitanCurrentHP = 0
    UpdateTitanHUD()

    local titan = GetTitanModel()
    local weakspot = titan and titan:FindFirstChild("TitanWeakspot") :: BasePart?
    local center = Vector3.new(0, GameConfig.ISLAND_HEIGHT + 3, 0)
    local weakPos = weakspot and weakspot.Position or center

    -- Estallido estelar de victoria
    SpawnImpactStarburst(weakPos, GameConfig.PALETTE.ENERGY_GOLD, GameConfig.PALETTE.CYAN_PLASMA)
    SpawnImpactStarburst(weakPos + Vector3.new(0, 5, 0), GameConfig.PALETTE.MINT_OASIS, GameConfig.PALETTE.ELECTRIC_COBALT)

    -- Notificación global a todos los jugadores
    local NotificationEvent = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("NotificationEvent") :: RemoteEvent
    NotificationEvent:FireAllClients({
        Type = "BossDefeated",
        Title = "👑 ¡TITÁN DE SOBRECARGA DERROTADO! ¡LLUVIA DE CRISTALES!",
        Color = GameConfig.PALETTE.ENERGY_GOLD,
    })

    -- Recompensa a todos los jugadores en la arena
    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
        if root and IslandService.IsInPvPZone(root.Position) then
            local profile = DataService.GetProfile(player)
            if profile then
                local ReactorService = require(script.Parent.ReactorService)
                profile.Energy += 3000
                ReactorService.AddAuraXP(player, 250)
                SpawnFloatingDamageNumber(root.Position + Vector3.new(0, 4, 0), 3000, true, GameConfig.PALETTE.ENERGY_GOLD)

                local StateReplicated = game:GetService("ReplicatedStorage").Remotes.StateReplicated :: RemoteEvent
                StateReplicated:FireClient(player, profile)
            end
        end
    end

    -- Lluvia de 12 cristales en la arena
    for i = 1, 12 do
        local angle = (i / 12) * math.pi * 2 + (math.random() * 0.4)
        local dist = math.random(12, GameConfig.CENTER_ISLAND_RADIUS - 16)
        local dropPos = center + Vector3.new(math.cos(angle) * dist, 1.5, math.sin(angle) * dist)
        SpawnHyperchargeCrystal(dropPos)
    end

    -- Apagar ojo temporalmente
    if weakspot then
        weakspot.Color = Color3.fromRGB(60, 65, 80)
    end

    -- Tiempo de reaparición del Titán (25s)
    task.delay(25, function()
        TitanCurrentHP = GameConfig.TITAN.MaxHealth
        IsTitanDefeated = false
        if weakspot then
            weakspot.Color = GameConfig.PALETTE.CYAN_PLASMA
        end
        UpdateTitanHUD()
        NotificationEvent:FireAllClients({
            Type = "BossRespawn",
            Title = "⚡ ¡EL TITÁN DE SOBRECARGA HA RESUCITADO!",
            Color = GameConfig.PALETTE.CYAN_PLASMA,
        })
    end)
end

-- Onda de choque periódica (Mecánica de esquiva por salto activo)
local function TriggerShockwaveAttack()
    if IsTitanDefeated then return end

    local titan = GetTitanModel()
    if not titan then return end
    local weakspot = titan:FindFirstChild("TitanWeakspot") :: BasePart?

    -- Comprobar jugadores en la arena
    local playersInArena: {Player} = {}
    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
        if root and IslandService.IsInPvPZone(root.Position) then
            table.insert(playersInArena, player)
        end
    end
    if #playersInArena == 0 then return end

    -- 1. FASE DE TELEGRAFÍA (Aviso luminoso 1.3s)
    if weakspot then
        weakspot.Color = GameConfig.PALETTE.CRIMSON_SPARK
    end

    local NotificationEvent = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("NotificationEvent") :: RemoteEvent
    for _, p in ipairs(playersInArena) do
        NotificationEvent:FireClient(p, {
            Type = "BossWarning",
            Title = "⚠ ¡ONDA EXPANSIVA EN CAMINO! ¡SALTA PARA ESQUIVAR!",
            Color = GameConfig.PALETTE.CRIMSON_SPARK,
        })
    end

    task.wait(1.3)
    if IsTitanDefeated then return end

    -- 2. FASE DE IMPACTO Y ONDA EXPANSIVA
    local center = Vector3.new(0, GameConfig.ISLAND_HEIGHT + 1.2, 0)

    -- Anillo de choque visual en el suelo
    local shockRing = Instance.new("Part")
    shockRing.Name = "ShockwaveFloorRing"
    shockRing.Shape = Enum.PartType.Cylinder
    shockRing.Size = Vector3.new(0.4, 4, 4)
    shockRing.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
    shockRing.Material = Enum.Material.Neon
    shockRing.Color = GameConfig.PALETTE.CRIMSON_SPARK
    shockRing.Transparency = 0.2
    shockRing.Anchored = true
    shockRing.CanCollide = false
    shockRing.Parent = Workspace

    TweenService:Create(shockRing, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.4, 150, 150),
        Transparency = 1,
    }):Play()

    -- Detección de salto o impacto para cada jugador en la arena
    for _, player in ipairs(playersInArena) do
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if root and hum and hum.Health > 0 then
            local isAirborne = (hum.FloorMaterial == Enum.Material.Air)
                or (root.Position.Y > (GameConfig.ISLAND_HEIGHT + 3.2))

            if isAirborne then
                -- ¡ESQUIVA PERFECTA!
                local ReactorService = require(script.Parent.ReactorService)
                ReactorService.AddAuraXP(player, 45)
                SpawnFloatingDamageNumber(root.Position + Vector3.new(0, 3, 0), 45, true, GameConfig.PALETTE.MINT_OASIS)
            else
                -- ¡GOLPEADO POR LA ONDA!
                hum:TakeDamage(25)
                root.AssemblyLinearVelocity = Vector3.new(root.Position.X, 35, root.Position.Z).Unit * 35 + Vector3.new(0, 30, 0)
                SpawnFloatingDamageNumber(root.Position + Vector3.new(0, 3, 0), 25, false, GameConfig.PALETTE.CRIMSON_SPARK)
            end
        end
    end

    task.delay(1.4, function()
        if shockRing and shockRing.Parent then shockRing:Destroy() end
        if weakspot and not IsTitanDefeated then
            weakspot.Color = GameConfig.PALETTE.CYAN_PLASMA
        end
    end)
end

-- Genera orbes potenciadores en la Isla Central
local function SpawnCentralBooster()
    local center = Vector3.new(0, GameConfig.ISLAND_HEIGHT + 2, 0)
    local randomAngle = math.random() * math.pi * 2
    local randomDist = math.random(15, GameConfig.CENTER_ISLAND_RADIUS - 15)
    local spawnPos = center + Vector3.new(math.cos(randomAngle) * randomDist, 3, math.sin(randomAngle) * randomDist)

    local isEnergy = math.random() > 0.4
    local orb = Instance.new("Part")
    orb.Name = isEnergy and "EnergyOrb" or "OverchargeOrb"
    orb.Shape = Enum.PartType.Ball
    orb.Size = Vector3.new(3, 3, 3)
    orb.Position = spawnPos
    orb.Material = Enum.Material.Neon
    orb.Color = isEnergy and Color3.fromRGB(255, 220, 40) or Color3.fromRGB(0, 255, 200)
    orb.Anchored = true
    orb.CanCollide = false
    orb.Parent = BoosterFolder

    local collected = false
    orb.Touched:Connect(function(hit)
        if collected then return end
        local player = Players:GetPlayerFromCharacter(hit.Parent)
        if player then
            collected = true
            local profile = DataService.GetProfile(player)
            if profile then
                local ReactorService = require(script.Parent.ReactorService)
                if isEnergy then
                    profile.Energy += 350
                    ReactorService.AddAuraXP(player, 25)
                else
                    profile.OverchargeMeter = math.clamp(profile.OverchargeMeter + 25, 0, profile.MaxOvercharge)
                    ReactorService.AddAuraXP(player, 40)
                end
                local StateReplicated = game:GetService("ReplicatedStorage").Remotes.StateReplicated :: RemoteEvent
                StateReplicated:FireClient(player, profile)
            end
            orb:Destroy()
        end
    end)

    task.delay(25, function()
        if orb and orb.Parent then orb:Destroy() end
    end)
end

function CombatService.StartCataclysmLoop()
    task.spawn(function()
        local shockwaveTimer = 0
        while true do
            task.wait(1.5)
            shockwaveTimer += 1.5

            -- 1. Pulso pasivo Rey del Núcleo (cada 3 segundos para quienes dominan el centro)
            for _, player in ipairs(Players:GetPlayers()) do
                local char = player.Character
                local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
                if root and IslandService.IsInPvPZone(root.Position) then
                    local distToCore = (Vector2.new(root.Position.X, root.Position.Z) - Vector2.new(0, 0)).Magnitude
                    if distToCore <= 24 then
                        local profile = DataService.GetProfile(player)
                        if profile then
                            local ReactorService = require(script.Parent.ReactorService)
                            profile.Energy += 35
                            ReactorService.AddAuraXP(player, 8)
                            local StateReplicated = game:GetService("ReplicatedStorage").Remotes.StateReplicated :: RemoteEvent
                            StateReplicated:FireClient(player, profile)
                        end
                    end
                end
            end

            -- 2. Onda expansiva periódica cada ~15 segundos
            if shockwaveTimer >= 14 then
                shockwaveTimer = 0
                TriggerShockwaveAttack()
            end
        end
    end)
end

function CombatService.StartBoosterLoop()
    BoosterFolder = Instance.new("Folder")
    BoosterFolder.Name = "ArenaBoosters"
    BoosterFolder.Parent = Workspace

    task.spawn(function()
        while true do
            task.wait(6)
            if #BoosterFolder:GetChildren() < 8 then
                SpawnCentralBooster()
            end
        end
    end)

    CombatService.StartCataclysmLoop()
end

-- Coloca un bloque de puente Skywars en el servidor con validación de distancia y audio
function CombatService.PlaceBridgeBlock(player: Player, targetPos: Vector3)
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not root then return end

    if (root.Position - targetPos).Magnitude > 24 then return end

    local mapFolder = Workspace:FindFirstChild("Map") or Workspace
    local bridgesFolder = mapFolder:FindFirstChild("PlayerPlacedBridges")
    if not bridgesFolder then
        bridgesFolder = Instance.new("Folder")
        bridgesFolder.Name = "PlayerPlacedBridges"
        bridgesFolder.Parent = mapFolder
    end

    local block = Instance.new("Part")
    block.Name = "PlacedBridgeBlock"
    block.Size = Vector3.new(4, 1.4, 4)
    block.Position = targetPos
    block.Material = Enum.Material.SmoothPlastic
    block.Color = Color3.fromRGB(36, 44, 62)
    block.Anchored = true
    block.CanCollide = true
    block.TopSurface = Enum.SurfaceType.Smooth
    block.BottomSurface = Enum.SurfaceType.Smooth
    block.Parent = bridgesFolder

    local trim = Instance.new("Part")
    trim.Name = "Trim"
    trim.Size = Vector3.new(4.05, 0.2, 4.05)
    trim.Position = targetPos + Vector3.new(0, 0.65, 0)
    trim.Material = Enum.Material.Neon
    trim.Color = GameConfig.PALETTE.CYAN_PLASMA
    trim.Transparency = 0.5
    trim.Anchored = true
    trim.CanCollide = false
    trim.Parent = block

    local SoundUtil = require(Shared.Utils.SoundUtil)
    SoundUtil.Play3D(SoundUtil.SOUNDS.PLACE_BLOCK, block, 0.65)
end

return CombatService
