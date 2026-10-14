--!strict
-- IslandService: Gestión de asignación de islas personales, safezones y propiedad
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("OverchargedShared")
local Types = require(Shared.Types.GameTypes)
local GameConfig = require(Shared.Config.GameConfig)

local DataService = require(script.Parent.DataService)
local MapService = require(script.Parent.MapService)

local IslandService = {}

-- Estado de ocupación de las 6 islas: [islandIndex] = Player?
local IslandOccupants: { [number]: Player? } = {}

-- Busca la primera isla vacía disponible (1 al 6)
local function FindAvailableIsland(): number
    for i = 1, GameConfig.ISLAND_COUNT do
        if IslandOccupants[i] == nil then
            return i
        end
    end
    return 1 -- Fallback
end

-- Asigna una isla a un jugador y actualiza los indicadores visuales
function IslandService.AssignIsland(player: Player): number
    local profile = DataService.GetProfile(player)
    if not profile then return 1 end

    local islandIndex = profile.AssignedIsland
    -- Si la isla previa no es válida o está ocupada por otro, asignar nueva
    if islandIndex == 0 or IslandOccupants[islandIndex] ~= nil then
        islandIndex = FindAvailableIsland()
        profile.AssignedIsland = islandIndex
    end

    IslandOccupants[islandIndex] = player

    -- Actualizar letrero de propiedad en la isla 3D
    local islandFolder = MapService.GetIslandFolder(islandIndex)
    if islandFolder then
        local signPart = islandFolder:FindFirstChild("OwnerSignPart")
        if signPart then
            local tag = signPart:FindFirstChild("IslandOwnerTag")
            if tag then
                local label = tag:FindFirstChild("OwnerText") :: TextLabel?
                if label then
                    label.Text = "🏠 Isla de: " .. player.DisplayName
                    label.TextColor3 = Color3.fromRGB(80, 255, 120)
                end
            end
        end

        -- Enlazar clic del núcleo físico en la isla
        local core = islandFolder:FindFirstChild("WorldReactorCore")
        if core then
            local clickDetector = core:FindFirstChildOfClass("ClickDetector")
            if clickDetector then
                clickDetector.MouseClick:Connect(function(clickingPlayer)
                    if clickingPlayer == player then
                        local ReactorService = require(script.Parent.ReactorService)
                        ReactorService.ProcessClick(player)
                    end
                end)
            end
        end

        -- Animación de compresión y onda expansiva en los pads de compra
        local function AnimatePadPress(padInner: BasePart, color: Color3)
            local origPos = padInner.Position
            TweenService:Create(padInner, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Position = origPos - Vector3.new(0, 0.22, 0)
            }):Play()
            task.delay(0.22, function()
                if padInner and padInner.Parent then
                    TweenService:Create(padInner, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                        Position = origPos
                    }):Play()
                end
            end)

            local ring = Instance.new("Part")
            ring.Name = "PadEnergyRing"
            ring.Shape = Enum.PartType.Cylinder
            ring.Size = Vector3.new(0.08, 1.8, 1.8)
            ring.CFrame = CFrame.new(origPos + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.pi/2)
            ring.Material = Enum.Material.Neon
            ring.Color = color
            ring.Transparency = 0.25
            ring.Anchored = true
            ring.CanCollide = false
            ring.Parent = Workspace

            TweenService:Create(ring, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = Vector3.new(0.04, 12, 12),
                Transparency = 1,
            }):Play()
            task.delay(0.5, function() if ring and ring.Parent then ring:Destroy() end end)
        end

        -- Enlazar Pads físicos de compra de la isla (Tycoon Pads)
        local housePad = islandFolder:FindFirstChild("HouseUpgradePad")
        if housePad then
            local padInner = housePad:FindFirstChild("PadInner") :: BasePart?
            if padInner then
                local debounce = 0
                padInner.Touched:Connect(function(hit)
                    local hitPlayer = Players:GetPlayerFromCharacter(hit.Parent)
                    if hitPlayer == player then
                        local now = os.clock()
                        if now - debounce > 1.2 then
                            debounce = now
                            AnimatePadPress(padInner, padInner.Color)
                            local HouseService = require(script.Parent.HouseService)
                            HouseService.UpgradeHouse(player)
                        end
                    end
                end)
            end
        end

        local teslaPad = islandFolder:FindFirstChild("TeslaTowerPad")
        if teslaPad then
            local padInner = teslaPad:FindFirstChild("PadInner") :: BasePart?
            if padInner then
                local debounce = 0
                padInner.Touched:Connect(function(hit)
                    local hitPlayer = Players:GetPlayerFromCharacter(hit.Parent)
                    if hitPlayer == player then
                        local now = os.clock()
                        if now - debounce > 1.2 then
                            debounce = now
                            AnimatePadPress(padInner, padInner.Color)
                            local HouseService = require(script.Parent.HouseService)
                            HouseService.BuyTeslaTower(player)
                        end
                    end
                end)
            end
        end
    end

    return islandIndex
end

-- Teletransporta al jugador de forma segura a su isla asignada
function IslandService.TeleportToIsland(player: Player)
    local profile = DataService.GetProfile(player)
    if not profile or profile.AssignedIsland == 0 then return end

    local islandFolder = MapService.GetIslandFolder(profile.AssignedIsland)
    if not islandFolder then return end

    local spawnLocation = islandFolder:FindFirstChild("IslandSpawn") :: SpawnLocation?
    local character = player.Character
    if not spawnLocation or not character then return end

    local root = character:WaitForChild("HumanoidRootPart", 6) :: BasePart?
    if root and spawnLocation then
        character:PivotTo(spawnLocation.CFrame + Vector3.new(0, 4, 0))
    end
end

-- Libera la isla al salir el jugador
function IslandService.ReleaseIsland(player: Player)
    for i = 1, GameConfig.ISLAND_COUNT do
        if IslandOccupants[i] == player then
            IslandOccupants[i] = nil
            local islandFolder = MapService.GetIslandFolder(i)
            if islandFolder then
                local signPart = islandFolder:FindFirstChild("OwnerSignPart")
                if signPart then
                    local tag = signPart:FindFirstChild("IslandOwnerTag")
                    if tag then
                        local label = tag:FindFirstChild("OwnerText") :: TextLabel?
                        if label then
                            label.Text = "⚡ Isla #" .. tostring(i) .. " (Disponible)"
                            label.TextColor3 = Color3.fromRGB(240, 240, 255)
                        end
                    end
                end
            end
            break
        end
    end
end

-- Verifica si una posición está en la Zona Central de Combate (PvP)
function IslandService.IsInPvPZone(position: Vector3): boolean
    local center = Vector3.new(0, GameConfig.ISLAND_HEIGHT, 0)
    local horizontalDistance = (Vector2.new(position.X, position.Z) - Vector2.new(center.X, center.Z)).Magnitude
    return horizontalDistance <= (GameConfig.CENTER_ISLAND_RADIUS + 5)
end

-- Verifica si un jugador está en su propia isla segura (Safezone)
function IslandService.IsInSafezone(player: Player): boolean
    local character = player.Character
    if not character then return true end

    local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not root then return true end

    -- Si está en la isla central, NO es zona segura
    if IslandService.IsInPvPZone(root.Position) then
        return false
    end

    -- En cualquier otra parte (islas privadas), es zona segura
    return true
end

-- Bucle de protección perimetral y safezone
function IslandService.StartProtectionLoop()
    task.spawn(function()
        while true do
            task.wait(0.2)
            for _, player in ipairs(Players:GetPlayers()) do
                local character = player.Character
                if character then
                    local humanoid = character:FindFirstChildOfClass("Humanoid")
                    local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?

                    if humanoid and root then
                        -- En zona segura no se puede morir
                        if IslandService.IsInSafezone(player) then
                            if humanoid.Health < humanoid.MaxHealth then
                                humanoid.Health = humanoid.MaxHealth
                            end
                        end

                        -- Verificar si un jugador invade la isla de otro jugador
                        for i = 1, GameConfig.ISLAND_COUNT do
                            local owner = IslandOccupants[i]
                            if owner and owner ~= player then
                                local islandFolder = MapService.GetIslandFolder(i)
                                if islandFolder then
                                    local floor = islandFolder:FindFirstChild("IslandFloor") :: BasePart?
                                    if floor then
                                        local dist = (Vector2.new(root.Position.X, root.Position.Z) - Vector2.new(floor.Position.X, floor.Position.Z)).Magnitude
                                        -- Si invade la isla de otro, empujarlo suavemente hacia afuera
                                        if dist < (GameConfig.PLAYER_ISLAND_RADIUS - 2) then
                                            local pushDir = (root.Position - floor.Position).Unit
                                            root.AssemblyLinearVelocity = Vector3.new(pushDir.X * 120, 40, pushDir.Z * 120)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
end

return IslandService
