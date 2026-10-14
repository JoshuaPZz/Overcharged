--!strict
-- ReactorService: Lógica autoritativa de clics, cálculo de energía, mejoras y tiradas de Aura
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("OverchargedShared")
local Types = require(Shared.Types.GameTypes)
local GameConfig = require(Shared.Config.GameConfig)
local DataService = require(script.Parent.DataService)
local AuraService = require(script.Parent.AuraService)
local CombatService = require(script.Parent.CombatService)

local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local StateReplicated = RemotesFolder:WaitForChild("StateReplicated") :: RemoteEvent
local NotificationEvent = RemotesFolder:WaitForChild("NotificationEvent") :: RemoteEvent

local ReactorService = {}
local LastClickTimes: { [number]: number } = {}

-- Calcula el multiplicador de aura actual
local function GetAuraMultiplier(auraName: string): number
    local auraDef = AuraService.GetAuraByName(auraName)
    return auraDef.Multiplier
end

-- Calcula el multiplicador otorgado por la casa construida
local function GetHouseMultiplier(profile: Types.PlayerProfile): number
    local houseLevel = profile.HouseLevel or 0
    if houseLevel > 0 and GameConfig.HOUSE_UPGRADES[houseLevel] then
        return GameConfig.HOUSE_UPGRADES[houseLevel].Multiplier
    end
    return 1.0
end

-- Calcula la ganancia por clic basada en mejoras, aura y nivel de casa
local function CalculateClickPower(profile: Types.PlayerProfile): number
    local turbineLevel = profile.Upgrades["Turbine"] and profile.Upgrades["Turbine"].Level or 1
    local basePower = turbineLevel * GameConfig.UPGRADES.Turbine.PowerPerLevel
    local auraMultiplier = GetAuraMultiplier(profile.CurrentAura)
    local houseMultiplier = GetHouseMultiplier(profile)
    return math.max(1, math.floor(basePower * auraMultiplier * houseMultiplier))
end

-- Calcula el incremento de sobrecarga por clic
local function CalculateOverchargeGain(profile: Types.PlayerProfile): number
    local capacitorLevel = profile.Upgrades["FluxCapacitor"] and profile.Upgrades["FluxCapacitor"].Level or 0
    return GameConfig.BASE_OVERCHARGE_PER_CLICK + (capacitorLevel * GameConfig.UPGRADES.FluxCapacitor.PowerPerLevel)
end

-- Tira los dados para obtener una nueva Aura con la suerte del jugador
local function RollAura(profile: Types.PlayerProfile): Types.AuraDefinition
    local luckLevel = profile.Upgrades["ResonanceAmplifier"] and profile.Upgrades["ResonanceAmplifier"].Level or 0
    local luckMultiplier = 1 + (luckLevel * GameConfig.UPGRADES.ResonanceAmplifier.PowerPerLevel)

    local totalWeight = 0
    for _, aura in ipairs(GameConfig.AURAS) do
        -- A mayor suerte, mayor peso para las auras raras
        local effectiveChance = math.max(1, aura.Chance / luckMultiplier)
        totalWeight += (1 / effectiveChance)
    end

    local rand = math.random() * totalWeight
    local current = 0

    for _, aura in ipairs(GameConfig.AURAS) do
        local effectiveChance = math.max(1, aura.Chance / luckMultiplier)
        current += (1 / effectiveChance)
        if rand <= current then
            return aura
        end
    end

    return GameConfig.AURAS[1]
end

-- Otorga experiencia de Aura al jugador y procesa subidas de nivel
function ReactorService.AddAuraXP(player: Player, amount: number)
    local profile = DataService.GetProfile(player)
    if not profile then return end

    profile.AuraXP += amount
    local leveledUp = false

    while profile.AuraXP >= profile.AuraXPNext do
        profile.AuraXP -= profile.AuraXPNext
        profile.AuraLevel += 1
        profile.AuraXPNext = GameConfig.GetXPForLevel(profile.AuraLevel)
        leveledUp = true
    end

    if leveledUp then
        -- Actualizar efectos visuales, estadísticas de combate y arma si califica
        AuraService.ApplyAuraToCharacter(player, profile.CurrentAura)
        CombatService.ApplyAuraStats(player)
        CombatService.GiveAuraBlade(player)

        local rankTitle, rankColor = GameConfig.GetAuraRank(profile.AuraLevel)
        NotificationEvent:FireClient(player, {
            Type = "LevelUp",
            Title = "¡NIVEL DE AURA " .. tostring(profile.AuraLevel) .. "! [" .. rankTitle .. "]",
            Color = rankColor,
        })
    end

    StateReplicated:FireClient(player, profile)
end

-- Procesa un clic del jugador
function ReactorService.ProcessClick(player: Player)
    local now = os.clock()
    local lastTime = LastClickTimes[player.UserId] or 0

    -- Rate limiting estricto anti-autoclicker
    if (now - lastTime) < GameConfig.CLICK_COOLDOWN then
        return
    end
    LastClickTimes[player.UserId] = now

    local profile = DataService.GetProfile(player)
    if not profile then return end

    local power = CalculateClickPower(profile)
    profile.Energy += power
    profile.TotalClicks += 1
    profile.OverchargeMeter += CalculateOverchargeGain(profile)

    -- Otorgar XP de Aura por cada clic activo
    ReactorService.AddAuraXP(player, 4)

    -- ¿Se completó la sobrecarga?
    if profile.OverchargeMeter >= profile.MaxOvercharge then
        profile.OverchargeMeter = 0

        -- Bono masivo de energía instantáneo
        local burstEnergy = power * GameConfig.OVERCHARGE_BURST_MULTIPLIER
        profile.Energy += burstEnergy

        -- Tirada de Aura Gacha
        local newAura = RollAura(profile)
        profile.UnlockedAuras[newAura.Name] = true
        profile.CurrentAura = newAura.Name

        -- Otorgar gran bonificación de XP de Aura por sobrecarga exitosa
        ReactorService.AddAuraXP(player, 65 + (newAura.Chance * 2))

        -- Equipar visualmente en el personaje y actualizar estadísticas de combate
        AuraService.ApplyAuraToCharacter(player, newAura.Name)
        CombatService.ApplyAuraStats(player)
        CombatService.GiveAuraBlade(player)

        -- Si es de alta rareza, notificar a todo el servidor
        if newAura.Chance >= 200 then
            NotificationEvent:FireAllClients({
                Type = "GlobalRoll",
                PlayerName = player.DisplayName,
                AuraName = newAura.Name,
                Title = newAura.Title,
                Color = newAura.RarityColor,
            })
        else
            NotificationEvent:FireClient(player, {
                Type = "PersonalRoll",
                AuraName = newAura.Name,
                Title = newAura.Title,
                Color = newAura.RarityColor,
            })
        end
    end

    -- Sincronización al cliente
    StateReplicated:FireClient(player, profile)
end

-- Procesa la compra de una mejora
function ReactorService.ProcessUpgrade(player: Player, upgradeKey: string)
    local profile = DataService.GetProfile(player)
    if not profile then return end

    local upgradeDef = GameConfig.UPGRADES[upgradeKey]
    if not upgradeDef then return end

    local currentUpgrade = profile.Upgrades[upgradeKey]
    if not currentUpgrade then
        currentUpgrade = { Level = 0 }
        profile.Upgrades[upgradeKey] = currentUpgrade
    end

    -- Costo = BaseCost * (CostMultiplier ^ Level)
    local cost = math.floor(upgradeDef.BaseCost * (upgradeDef.CostMultiplier ^ currentUpgrade.Level))

    if profile.Energy >= cost then
        profile.Energy -= cost
        currentUpgrade.Level += 1
        StateReplicated:FireClient(player, profile)
    end
end

-- Bucle de producción pasiva (Auto-extractores) cada segundo
function ReactorService.StartPassiveLoop()
    task.spawn(function()
        while true do
            task.wait(1)
            for _, player in ipairs(Players:GetPlayers()) do
                local profile = DataService.GetProfile(player)
                if profile then
                    local autoLevel = profile.Upgrades["AutoExtractor"] and profile.Upgrades["AutoExtractor"].Level or 0
                    if autoLevel > 0 then
                        local multiplier = GetAuraMultiplier(profile.CurrentAura)
                        local passiveGain = math.floor(autoLevel * GameConfig.UPGRADES.AutoExtractor.PowerPerLevel * multiplier)
                        if passiveGain > 0 then
                            profile.Energy += passiveGain
                            StateReplicated:FireClient(player, profile)
                        end
                    end
                end
            end
        end
    end)
end

return ReactorService
