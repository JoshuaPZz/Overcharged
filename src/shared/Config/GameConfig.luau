--!strict
-- Configuración de balance económico, mejoras, niveles de Aura y catálogo de Armas
local Types = require(script.Parent.Parent.Types.GameTypes)

local GameConfig = {}

-- Constantes del Game Loop
GameConfig.CLICK_COOLDOWN = 0.07 -- Máximo ~14 clics por segundo (anti-exploit/macros)
GameConfig.BASE_OVERCHARGE_PER_CLICK = 4
GameConfig.DEFAULT_MAX_OVERCHARGE = 100
GameConfig.OVERCHARGE_BURST_MULTIPLIER = 30 -- Bonificación inmediata de energía al detonar

-- Catálogo de Mejoras
GameConfig.UPGRADES = {
    Turbine = {
        Name = "Turbine",
        DisplayName = "Turbina de Inducción",
        Description = "+1 Energía por clic",
        BaseCost = 15,
        CostMultiplier = 1.35,
        PowerPerLevel = 1,
        Category = "Click",
    },
    AutoExtractor = {
        Name = "AutoExtractor",
        DisplayName = "Extractor Automatizado",
        Description = "+2 Energía pasiva cada segundo",
        BaseCost = 50,
        CostMultiplier = 1.4,
        PowerPerLevel = 2,
        Category = "Passive",
    },
    FluxCapacitor = {
        Name = "FluxCapacitor",
        DisplayName = "Condensador de Flujo",
        Description = "+1% de sobrecarga por clic",
        BaseCost = 150,
        CostMultiplier = 1.6,
        PowerPerLevel = 1,
        Category = "Overcharge",
    },
    ResonanceAmplifier = {
        Name = "ResonanceAmplifier",
        DisplayName = "Amplificador de Resonancia",
        Description = "Aumenta la suerte de Auras raras",
        BaseCost = 500,
        CostMultiplier = 2.0,
        PowerPerLevel = 0.15,
        Category = "Luck",
    },
} :: { [string]: Types.UpgradeDefinition }

-- Configuración de Islas y Topología del Mapa
GameConfig.ISLAND_COUNT = 6
GameConfig.ORBIT_RADIUS = 360        -- Distancia desde el centro hasta las islas de los jugadores
GameConfig.PLAYER_ISLAND_RADIUS = 45 -- Tamaño de cada isla personal
GameConfig.CENTER_ISLAND_RADIUS = 210 -- Tamaño de la gran isla central de batalla
GameConfig.ISLAND_HEIGHT = 60        -- Elevación sobre el vacío (Y)

-- Catálogo de Mobs en la Gran Isla Central (Tier 1, 2 y 3)
GameConfig.MOBS = {
    Sentinel = {
        Id = "cobalt_sentinel",
        Name = "Centinela de Cobalto",
        MaxHealth = 80,
        EnergyReward = 150,
        XPReward = 18,
        OverchargeReward = 6,
        MinRadius = 135,
        MaxRadius = 195,
        RespawnTime = 12,
        Color = Color3.fromHex("#2575FC"),
        Accent = Color3.fromHex("#00D2D3"),
    },
    PlasmaGolem = {
        Id = "plasma_golem",
        Name = "Golem de Plasma",
        MaxHealth = 280,
        EnergyReward = 450,
        XPReward = 40,
        OverchargeReward = 15,
        MinRadius = 75,
        MaxRadius = 135,
        RespawnTime = 16,
        Color = Color3.fromHex("#10AC84"),
        Accent = Color3.fromHex("#2ED573"),
    },
    VoidWraith = {
        Id = "void_wraith",
        Name = "Espectro del Vacío",
        MaxHealth = 750,
        EnergyReward = 1200,
        XPReward = 85,
        OverchargeReward = 30,
        MinRadius = 30,
        MaxRadius = 75,
        RespawnTime = 22,
        Color = Color3.fromHex("#8854D0"),
        Accent = Color3.fromHex("#B400FF"),
    },
}

-- Catálogo de Cofres y Cajas Destruibles en la Arena Central
GameConfig.CHESTS = {
    EnergyChest = {
        Id = "energy_chest",
        Name = "Cofre de Energía",
        MaxHealth = 3,
        EnergyReward = 850,
        XPReward = 25,
        Color = Color3.fromHex("#FFA502"),
        RespawnTime = 15,
    },
    AuraChest = {
        Id = "aura_chest",
        Name = "Cofre de Aura Mística",
        MaxHealth = 4,
        EnergyReward = 1500,
        XPReward = 140,
        OverchargeReward = 50,
        Color = Color3.fromHex("#00D2D3"),
        RespawnTime = 20,
    },
    FrenzyChest = {
        Id = "frenzy_chest",
        Name = "Cofre de Frenesí Carmesí",
        MaxHealth = 3,
        EnergyReward = 600,
        XPReward = 35,
        BuffDuration = 25,
        Color = Color3.fromHex("#FF4757"),
        RespawnTime = 25,
    },
}

-- Catálogo de Auras (RNG Flex social y Escalamiento de Poder de Combate)
GameConfig.AURAS = {
    {
        Id = "spark",
        Name = "Kinetic Spark",
        Chance = 1, -- Común base
        RarityColor = Color3.fromRGB(180, 180, 180),
        SecondaryColor = Color3.fromRGB(220, 220, 220),
        Title = "⚡ Chispa Cinética (1/1)",
        ParticleEffect = "Sparkles",
        Multiplier = 1.0,
        HealthBonus = 0,
        Damage = 15,
        SpeedBonus = 0,
    },
    {
        Id = "overclock",
        Name = "Overclocked Blue",
        Chance = 6,
        RarityColor = Color3.fromRGB(0, 170, 255),
        SecondaryColor = Color3.fromRGB(100, 220, 255),
        Title = "🔷 Sobrecarga Azul (1/6)",
        ParticleEffect = "BlueFlame",
        Multiplier = 1.25,
        HealthBonus = 30,
        Damage = 25,
        SpeedBonus = 2,
    },
    {
        Id = "plasma",
        Name = "Neon Plasma",
        Chance = 35,
        RarityColor = Color3.fromRGB(0, 255, 130),
        SecondaryColor = Color3.fromRGB(180, 255, 200),
        Title = "🧪 Plasma Neón (1/35)",
        ParticleEffect = "PlasmaRings",
        Multiplier = 1.75,
        HealthBonus = 80,
        Damage = 45,
        SpeedBonus = 4,
    },
    {
        Id = "solar_flare",
        Name = "Solar Flare",
        Chance = 200,
        RarityColor = Color3.fromRGB(255, 120, 0),
        SecondaryColor = Color3.fromRGB(255, 230, 100),
        Title = "🔥 Fulgor Solar (1/200)",
        ParticleEffect = "SolarRays",
        Multiplier = 2.5,
        HealthBonus = 180,
        Damage = 75,
        SpeedBonus = 7,
    },
    {
        Id = "singularity",
        Name = "Singularity Void",
        Chance = 1500,
        RarityColor = Color3.fromRGB(180, 0, 255),
        SecondaryColor = Color3.fromRGB(240, 150, 255),
        Title = "🌌 Singularidad del Vacío (1/1,500)",
        ParticleEffect = "VoidAura",
        Multiplier = 5.0,
        HealthBonus = 400,
        Damage = 130,
        SpeedBonus = 11,
    },
    {
        Id = "supernova",
        Name = "Infinite Supernova",
        Chance = 15000,
        RarityColor = Color3.fromRGB(255, 215, 0),
        SecondaryColor = Color3.fromRGB(255, 255, 255),
        Title = "⭐ ¡SUPERNOVA INFINITA! (1/15,000)",
        ParticleEffect = "SupernovaWings",
        Multiplier = 15.0,
        HealthBonus = 1200,
        Damage = 350,
        SpeedBonus = 18,
    },
} :: { Types.AuraDefinition }

-- PALETA MAESTRA DEL DIRECTOR DE ARTE (5 Hex + 1 Acento)
GameConfig.PALETTE = {
    DEEP_SLATE = Color3.fromHex("#1E2337"),      -- Bases, fondos de UI, contrastes oscuros
    ELECTRIC_COBALT = Color3.fromHex("#2575FC"), -- Botones primarios, reactor, Común
    CYAN_PLASMA = Color3.fromHex("#00F2FE"),     -- Líneas de energía, XP, Raro
    MINT_OASIS = Color3.fromHex("#2ED573"),      -- Zona segura, compras disponibles, Épico
    ENERGY_GOLD = Color3.fromHex("#FFA502"),     -- Mejoras, energía, progreso, Legendario
    CRIMSON_SPARK = Color3.fromHex("#FF4757"),   -- Acento: Zona PvP peligro, Mítico, alertas
}

-- Configuración del Monolito / Titán de Sobrecarga en la Arena Central
GameConfig.TITAN = {
    Name = "Titán de Sobrecarga",
    Title = "⚡ TITÁN DEL CATACLISMO ⚡",
    MaxHealth = 50000,
    BaseXPReward = 35,
    BaseEnergyReward = 150,
    WeakspotMultiplier = 2.0,
}

-- Catálogo de Armas Stylized por Nivel de Aura (5 Rarezas + Mítica + Divina)
-- Siluetas exageradas, bordes biselados, estética de plástico PBR/vinilo y cero sangre
GameConfig.WEAPONS = {
    {
        Id = "kinetic_dagger",
        Name = "Daga de Cobalto",
        Rarity = "Common",
        RarityName = "Común",
        RequiredAuraLevel = 1,
        Damage = 25,
        Range = 7.0,
        Cooldown = 0.35,
        WeaponType = "Dagger",
        Description = "Daga ágil de vinilo reforzado con micro-descargas de cobalto.",
        AccentColor = Color3.fromHex("#2575FC"), -- Electric Cobalt
    },
    {
        Id = "neon_katana",
        Name = "Sable de Plasma Neón",
        Rarity = "Rare",
        RarityName = "Raro",
        RequiredAuraLevel = 25,
        Damage = 60,
        Range = 9.5,
        Cooldown = 0.42,
        WeaponType = "Katana",
        Description = "Filo láser curvo con tsuba flotante de plasma cian.",
        AccentColor = Color3.fromHex("#00F2FE"), -- Cyan Plasma
    },
    {
        Id = "plasma_greatsword",
        Name = "Mandoble Sónico Esmeralda",
        Rarity = "Epic",
        RarityName = "Épico",
        RequiredAuraLevel = 75,
        Damage = 145,
        Range = 13.0,
        Cooldown = 0.65,
        WeaponType = "Greatsword",
        Description = "Mandoble colosal con doble canal de energía resonante verde menta.",
        AccentColor = Color3.fromHex("#2ED573"), -- Mint Oasis
    },
    {
        Id = "solar_scythe",
        Name = "Guadaña Solar del Cataclismo",
        Rarity = "Legendary",
        RarityName = "Legendario",
        RequiredAuraLevel = 150,
        Damage = 320,
        Range = 15.0,
        Cooldown = 0.58,
        WeaponType = "Scythe",
        Description = "Cosechadora de estrellas con hoja lunar y aureola solar giratoria.",
        AccentColor = Color3.fromHex("#FFA502"), -- Energy Gold
    },
    {
        Id = "void_glaive",
        Name = "Alabarda del Vacío Carmesí",
        Rarity = "Mythic",
        RarityName = "Mítico",
        RequiredAuraLevel = 250,
        Damage = 680,
        Range = 17.0,
        Cooldown = 0.6,
        WeaponType = "CosmicGlaive",
        Description = "Arma titánica de asalto con alas de plasma rojo y núcleo de gravedad.",
        AccentColor = Color3.fromHex("#FF4757"), -- Crimson Spark
    },
    {
        Id = "god_slayer",
        Name = "⭐ Rompegalaxias Cósmico ⭐",
        Rarity = "Godly",
        RarityName = "Divino",
        RequiredAuraLevel = 500,
        Damage = 2200,
        Range = 24.0,
        Cooldown = 0.48,
        WeaponType = "Greatsword",
        Description = "El arma legendaria definitiva forjada en el centro del cataclismo.",
        AccentColor = Color3.fromHex("#FFA502"), -- Gold con destellos Crimson
    },
} :: { Types.WeaponDefinition }

-- Fórmula de XP para alcanzar el siguiente Nivel de Aura (Progresión exponencial suave)
function GameConfig.GetXPForLevel(level: number): number
    return math.floor(40 * (level ^ 1.32)) + 30
end

-- Rango y Título de Prestigio según el Nivel de Aura
function GameConfig.GetAuraRank(level: number): (string, Color3)
    if level < 25 then
        return "Iniciado de Energía", Color3.fromRGB(180, 180, 190)
    elseif level < 75 then
        return "🔷 Guardián de Plasma", Color3.fromRGB(0, 170, 255)
    elseif level < 150 then
        return "🧪 Maestro de Sobrecarga", Color3.fromRGB(0, 255, 140)
    elseif level < 250 then
        return "🔥 Señor Solar", Color3.fromRGB(255, 130, 20)
    elseif level < 500 then
        return "🌌 Arconte de la Singularidad", Color3.fromRGB(200, 30, 255)
    else
        return "⚡ OMNIPOTENTE CELESTIAL ⚡", Color3.fromRGB(255, 215, 0)
    end
end

-- Catálogo de Construcción y Mejoras de Casa en la Parcela
GameConfig.HOUSE_UPGRADES = {
    [1] = {
        Level = 1,
        Name = "Cabaña de Energía",
        Cost = 450,
        Multiplier = 1.25, -- +25%
        Description = "Cabaña rústica con chimenea de plasma. +25% a toda la energía.",
    },
    [2] = {
        Level = 2,
        Name = "Laboratorio Tecnológico",
        Cost = 3500,
        Multiplier = 1.75, -- +75%
        Description = "Complejo de 2 pisos con balcón y radar. +75% a toda la energía.",
    },
    [3] = {
        Level = 3,
        Name = "Santuario Cósmico",
        Cost = 25000,
        Multiplier = 3.0, -- +200%
        Description = "Mansión celestial con columnas de mármol y cúpula estelar. +200% a toda la energía.",
    },
}

-- Configuración de Torres Tesla Automatizadoras en la Isla
GameConfig.TESLA_TOWER = {
    BaseCost = 600,
    CostMultiplier = 2.4,
    MaxCount = 3,
    EnergyPerStrike = 60,
    XPPerStrike = 12,
    StrikeInterval = 3.5, -- Segundos entre descargas
}

return GameConfig
