--!strict
-- SoundUtil: Reproductor centralizado de audio con variación de pitch y catálogo de efectos sonoros AAA
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local SoundUtil = {}

-- Diccionario de sonidos autorizados de Roblox
SoundUtil.SOUNDS = {
    HIT = "rbxassetid://566593606",          -- Impacto de combate cuerpo a cuerpo
    CRIT = "rbxassetid://3932505023",        -- Golpe crítico demoledor
    AURA_ACTIVATE = "rbxassetid://9119713951",-- Activación de Aura / Power-up cósmico
    LEVEL_UP = "rbxassetid://4612373815",    -- Subida de nivel de Aura / Compra exitosa
    DASH = "rbxassetid://200632875",         -- Dash / Esquiva rápida con estela
    KILL = "rbxassetid://5066021887",        -- Eliminación en Skywars / Caída al vacío
    HOVER = "rbxassetid://6895079853",       -- Micro-interacción hover en botón UI
    CLICK = "rbxassetid://6042053626",       -- Clic interactivo en UI
    BUILD = "rbxassetid://4612373815",       -- Pop-in de construcción de isla/tycoon
    PLACE_BLOCK = "rbxassetid://9114223171", -- Colocación de puente / bloque en Skywars
}

-- Reproduce un sonido en 2D (interfaz o sonido global del jugador) con variación de pitch
function SoundUtil.Play2D(soundId: string, volume: number?, pitchVariation: boolean?)
    local s = Instance.new("Sound")
    s.SoundId = soundId
    s.Volume = volume or 0.65
    if pitchVariation ~= false then
        s.PlaybackSpeed = math.random(92, 108) / 100
    else
        s.PlaybackSpeed = 1.0
    end
    s.Parent = SoundService
    s:Play()
    s.Ended:Connect(function()
        s:Destroy()
    end)
    task.delay(4, function()
        if s and s.Parent then s:Destroy() end
    end)
    return s
end

-- Reproduce un sonido en el espacio 3D (atado a una pieza o posición)
function SoundUtil.Play3D(soundId: string, parent: Instance, volume: number?, rollOffMaxDistance: number?)
    local s = Instance.new("Sound")
    s.SoundId = soundId
    s.Volume = volume or 0.75
    s.PlaybackSpeed = math.random(90, 110) / 100
    s.RollOffMaxDistance = rollOffMaxDistance or 120
    s.RollOffMinDistance = 10
    s.RollOffMode = Enum.RollOffMode.InverseTapered
    s.Parent = parent
    s:Play()
    s.Ended:Connect(function()
        s:Destroy()
    end)
    task.delay(4, function()
        if s and s.Parent then s:Destroy() end
    end)
    return s
end

return SoundUtil
