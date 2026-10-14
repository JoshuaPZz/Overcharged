--!strict
-- DataService: Gestión autoritativa del estado de los jugadores y persistencia
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("OverchargedShared")
local Types = require(Shared.Types.GameTypes)
local GameConfig = require(Shared.Config.GameConfig)

local DataService = {}
local Profiles: { [number]: Types.PlayerProfile } = {}

-- Identificador del DataStore
local DATA_STORE_NAME = "Overcharged_UserData_v1"
local UserDataStore = nil

-- Protegemos la inicialización del DataStore si estamos en Studio sin API access
pcall(function()
    UserDataStore = DataStoreService:GetDataStore(DATA_STORE_NAME)
end)

-- Crea un perfil predeterminado para jugadores nuevos
local function CreateDefaultProfile(): Types.PlayerProfile
    local upgrades: { [string]: Types.PlayerUpgradeData } = {}
    for upgradeKey, _ in pairs(GameConfig.UPGRADES) do
        upgrades[upgradeKey] = { Level = 0 }
    end
    -- Nivel inicial de la turbina para poder hacer clics
    if upgrades["Turbine"] then
        upgrades["Turbine"].Level = 1
    end

    return {
        Energy = 0,
        TotalClicks = 0,
        OverchargeMeter = 0,
        MaxOvercharge = GameConfig.DEFAULT_MAX_OVERCHARGE,
        CurrentAura = "Kinetic Spark",
        UnlockedAuras = { ["Kinetic Spark"] = true },
        Upgrades = upgrades,
        AssignedIsland = 0,
        AuraLevel = 1,
        AuraXP = 0,
        AuraXPNext = GameConfig.GetXPForLevel(1),
        EquippedWeapon = "kinetic_dagger",
        HouseLevel = 0,
        TeslaTowers = 0,
    }
end

-- Carga o inicializa el perfil de un jugador
function DataService.LoadProfile(player: Player): Types.PlayerProfile
    local userId = player.UserId
    local profile: Types.PlayerProfile? = nil

    if UserDataStore then
        local success, savedData = pcall(function()
            return UserDataStore:GetAsync("User_" .. tostring(userId))
        end)

        if success and typeof(savedData) == "table" then
            profile = savedData :: Types.PlayerProfile
        end
    end

    if not profile then
        profile = CreateDefaultProfile()
    else
        -- Reconciliación: Asegurar que existan todas las mejoras y claves nuevas
        local defaultProfile = CreateDefaultProfile()
        for key, defUpgrade in pairs(defaultProfile.Upgrades) do
            if not profile.Upgrades[key] then
                profile.Upgrades[key] = defUpgrade
            end
        end
        if not profile.UnlockedAuras then
            profile.UnlockedAuras = { ["Kinetic Spark"] = true }
        end
        if not profile.AuraLevel or profile.AuraLevel < 1 then
            profile.AuraLevel = 1
            profile.AuraXP = 0
            profile.AuraXPNext = GameConfig.GetXPForLevel(1)
        end
        if not profile.EquippedWeapon then
            profile.EquippedWeapon = "kinetic_dagger"
        end
        if not profile.HouseLevel then
            profile.HouseLevel = 0
        end
        if not profile.TeslaTowers then
            profile.TeslaTowers = 0
        end
    end

    Profiles[userId] = profile
    return profile
end

-- Obtiene el perfil activo en memoria
function DataService.GetProfile(player: Player): Types.PlayerProfile?
    return Profiles[player.UserId]
end

-- Guarda los datos del jugador de manera asíncrona y segura
function DataService.SaveProfile(player: Player)
    local userId = player.UserId
    local profile = Profiles[userId]
    if not profile or not UserDataStore then return end

    pcall(function()
        UserDataStore:SetAsync("User_" .. tostring(userId), profile)
    end)
end

-- Libera la memoria al salir el jugador
function DataService.RemoveProfile(player: Player)
    DataService.SaveProfile(player)
    Profiles[player.UserId] = nil
end

return DataService
