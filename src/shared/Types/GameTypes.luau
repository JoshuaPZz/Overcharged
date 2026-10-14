--!strict
-- Definición estricta de tipos de datos para "Overcharged: Idle-Action Merge"
local GameTypes = {}

-- Configuración de cada mejora en la tienda
export type UpgradeDefinition = {
    Name: string,
    DisplayName: string,
    Description: string,
    BaseCost: number,
    CostMultiplier: number,
    PowerPerLevel: number,
    Category: "Click" | "Passive" | "Overcharge" | "Luck",
}

-- Datos de una mejora en el perfil del jugador
export type PlayerUpgradeData = {
    Level: number,
}

-- Definición de una Aura (Gacha / Flex social / Combate)
export type AuraDefinition = {
    Id: string,
    Name: string,
    Chance: number,              -- 1 en N de probabilidad
    RarityColor: Color3,         -- Color primario para UI y partículas
    SecondaryColor: Color3,      -- Color de brillo o resplandor
    Title: string,               -- Título que aparece sobre la cabeza del jugador
    ParticleEffect: string,      -- Identificador de tipo de partícula
    Multiplier: number,          -- Multiplicador pasivo de ganancias
    HealthBonus: number,         -- Vida adicional otorgada en combate
    Damage: number,              -- Daño base del arma de aura
    SpeedBonus: number,          -- Velocidad de movimiento adicional
}

-- Definición de Armas de Combate escaladas por Nivel de Aura
export type WeaponDefinition = {
    Id: string,
    Name: string,
    Rarity: "Common" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Godly",
    RarityName: string,
    RequiredAuraLevel: number,   -- Nivel de aura requerido para portarla
    Damage: number,              -- Daño base
    Range: number,               -- Alcance del golpe en studs
    Cooldown: number,            -- Tiempo de recarga entre ataques
    WeaponType: "Dagger" | "Katana" | "Greatsword" | "Scythe" | "CosmicGlaive",
    Description: string,
    AccentColor: Color3,
}

-- Perfil completo persistente del jugador
export type PlayerProfile = {
    Energy: number,
    TotalClicks: number,
    OverchargeMeter: number,
    MaxOvercharge: number,
    CurrentAura: string,
    UnlockedAuras: { [string]: boolean },
    Upgrades: { [string]: PlayerUpgradeData },
    AssignedIsland: number,      -- Número de isla asignada (1 al 6)

    -- Sistema de Niveles de Aura (1 a 500+)
    AuraLevel: number,
    AuraXP: number,
    AuraXPNext: number,
    EquippedWeapon: string,

    -- Construcción de Isla & Automatizadores
    HouseLevel: number,          -- Nivel de casa (0 a 3)
    TeslaTowers: number,         -- Cantidad de torres Tesla colocadas (0 a 3)
}

return GameTypes
