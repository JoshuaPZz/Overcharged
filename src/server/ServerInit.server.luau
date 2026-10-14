--!strict
-- ServerInit: Punto de entrada autoritativo del servidor
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 1. Asegurar la existencia de la carpeta de Remotes y sus eventos
local function EnsureRemote(parent: Instance, name: string): RemoteEvent
    local remote = parent:FindFirstChild(name)
    if not remote then
        remote = Instance.new("RemoteEvent")
        remote.Name = name
        remote.Parent = parent
    end
    return remote :: RemoteEvent
end

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
    remotesFolder = Instance.new("Folder")
    remotesFolder.Name = "Remotes"
    remotesFolder.Parent = ReplicatedStorage
end

local RequestClick = EnsureRemote(remotesFolder, "RequestClick")
local RequestUpgrade = EnsureRemote(remotesFolder, "RequestUpgrade")
local RequestHouseUpgrade = EnsureRemote(remotesFolder, "RequestHouseUpgrade")
local RequestBuyAutomator = EnsureRemote(remotesFolder, "RequestBuyAutomator")
local RequestAttack = EnsureRemote(remotesFolder, "RequestAttack")
local RequestPlaceBridgeBlock = EnsureRemote(remotesFolder, "RequestPlaceBridgeBlock")
local StateReplicated = EnsureRemote(remotesFolder, "StateReplicated")
local NotificationEvent = EnsureRemote(remotesFolder, "NotificationEvent")

-- 2. Cargar Servicios del Servidor
local DataService = require(script.Parent.Services.DataService)
local MapService = require(script.Parent.Services.MapService)
local IslandService = require(script.Parent.Services.IslandService)
local AuraService = require(script.Parent.Services.AuraService)
local ReactorService = require(script.Parent.Services.ReactorService)
local CombatService = require(script.Parent.Services.CombatService)
local HouseService = require(script.Parent.Services.HouseService)
local MobService = require(script.Parent.Services.MobService)
local CrateService = require(script.Parent.Services.CrateService)

-- 3. Construir el Mapa 3D (6 Islas en círculo + Gran Isla Central)
MapService.InitializeMap()

-- 4. Conectar Eventos de Red
RequestClick.OnServerEvent:Connect(function(player)
    ReactorService.ProcessClick(player)
end)

RequestAttack.OnServerEvent:Connect(function(player)
    CombatService.ProcessPlayerAttack(player)
end)

RequestPlaceBridgeBlock.OnServerEvent:Connect(function(player, targetPos)
    if typeof(targetPos) == "Vector3" then
        CombatService.PlaceBridgeBlock(player, targetPos)
    end
end)

RequestUpgrade.OnServerEvent:Connect(function(player, upgradeKey)
    if typeof(upgradeKey) == "string" then
        ReactorService.ProcessUpgrade(player, upgradeKey)
    end
end)

RequestHouseUpgrade.OnServerEvent:Connect(function(player)
    HouseService.UpgradeHouse(player)
end)

RequestBuyAutomator.OnServerEvent:Connect(function(player)
    HouseService.BuyTeslaTower(player)
end)

-- 5. Manejo del Ciclo de Vida de los Jugadores
Players.PlayerAdded:Connect(function(player)
    local profile = DataService.LoadProfile(player)

    -- Asignar una de las 6 islas personales al jugador
    local assignedIsland = IslandService.AssignIsland(player)

    -- Manejar la aparición del personaje (Spawn)
    player.CharacterAdded:Connect(function(character)
        character:WaitForChild("HumanoidRootPart", 6)
        task.wait(0.05)

        -- Teletransportar directamente a su isla privada
        IslandService.TeleportToIsland(player)

        -- Equipar Aura visual, estadísticas y arma
        local currentProfile = DataService.GetProfile(player)
        if currentProfile then
            AuraService.ApplyAuraToCharacter(player, currentProfile.CurrentAura)
            CombatService.ApplyAuraStats(player)
            CombatService.GiveAuraBlade(player)
            HouseService.BuildForPlayer(player)
        end
    end)

    -- Si el personaje ya cargó antes de enlazar el evento
    if player.Character then
        IslandService.TeleportToIsland(player)
        AuraService.ApplyAuraToCharacter(player, profile.CurrentAura)
        CombatService.ApplyAuraStats(player)
        CombatService.GiveAuraBlade(player)
        HouseService.BuildForPlayer(player)
    end

    -- Sincronizar estado inicial al cliente
    StateReplicated:FireClient(player, profile)
end)

Players.PlayerRemoving:Connect(function(player)
    IslandService.ReleaseIsland(player)
    DataService.RemoveProfile(player)
end)

-- Guardado de perfiles al cerrar el servidor
game:BindToClose(function()
    for _, player in ipairs(Players:GetPlayers()) do
        DataService.SaveProfile(player)
    end
end)

-- 6. Iniciar bucles de soporte
ReactorService.StartPassiveLoop()
IslandService.StartProtectionLoop()
CombatService.StartBoosterLoop()
HouseService.StartTeslaLoop()
MobService.Initialize()
CrateService.Initialize()

print("[Overcharged] Servidor, Gran Isla Central, Mobs, Cofres y Combate operativos.")
