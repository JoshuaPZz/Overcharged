--!strict
-- AuraVFXModule: Motor procedural de Auras estilo Sol's RNG / Anime AAA
-- Versión mejorada: pilar de energía, orbes orbitales, onda de equipamiento,
-- emisores duales y anillos de poder escalados por nivel.
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local AuraVFXModule = {}

-- Texturas nativas oficiales integradas en el motor de Roblox (100% funcionales y transparentes)
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

-- Devuelve un segundo color seguro para el degradado
local function SecondaryColor(auraDef: any): Color3
    return auraDef.SecondaryColor or Color3.fromRGB(255, 255, 255)
end

-- Limpia cualquier efecto de Aura previo en el personaje
function AuraVFXModule.ClearAuraVFX(character: Model)
    local existingFolder = character:FindFirstChild("AuraVFXContainer")
    if existingFolder then
        existingFolder:Destroy()
    end

    local existingHighlight = character:FindFirstChild("AuraHighlight")
    if existingHighlight then
        existingHighlight:Destroy()
    end

    -- Limpieza genérica de adjuntos/efectos anclados al HumanoidRootPart
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp then
        for _, child in ipairs(hrp:GetChildren()) do
            if child.Name:sub(1, 4) == "Aura" then
                child:Destroy()
            end
        end
    end
end

-- Construye un anillo de energía neón (cilindro achatado) en el personaje
local function CreatePowerRing(hrp: BasePart, name: string, color: Color3, diameter: number, thickness: number, transparency: number): Part
    local ring = Instance.new("Part")
    ring.Name = name
    ring.Shape = Enum.PartType.Cylinder
    ring.Size = Vector3.new(thickness, diameter, diameter)
    ring.Material = Enum.Material.Neon
    ring.Color = color
    ring.Transparency = transparency
    ring.CanCollide = false
    ring.Massless = true
    ring.Anchored = false
    ring.CastShadow = false
    ring.Parent = hrp
    return ring
end

-- Inyecta los efectos visuales completos del Aura en el personaje
function AuraVFXModule.AttachAuraVFX(character: Model, auraDef: any, level: number)
    AuraVFXModule.ClearAuraVFX(character)

    local hrp = character:WaitForChild("HumanoidRootPart", 4) :: BasePart?
    if not hrp then return end

    local colorA: Color3 = auraDef.RarityColor or Color3.fromRGB(0, 210, 255)
    local colorB: Color3 = SecondaryColor(auraDef)

    -- Factor de intensidad escalado por nivel (0..1 aprox.)
    local intensity = math.clamp(level / 200, 0, 1)

    local container = Instance.new("Folder")
    container.Name = "AuraVFXContainer"
    container.Parent = character

    -- 1. LUZ SUAVE EN EL SUELO (PointLight brillante según tier)
    local pLight = Instance.new("PointLight")
    pLight.Name = "AuraPointLight"
    pLight.Color = colorA
    pLight.Brightness = 2.0 + intensity * 0.8
    pLight.Range = 14 + intensity * 6
    pLight.Shadows = false
    pLight.Parent = hrp

    -- 2. HIGHLIGHT NATIVO (SILUETA CELESTIAL ANIME CON PROFUNDIDAD OCLUIDA)
    local highlight = Instance.new("Highlight")
    highlight.Name = "AuraHighlight"
    highlight.Adornee = character
    highlight.FillColor = colorA
    highlight.FillTransparency = 0.75
    highlight.OutlineColor = colorB
    highlight.OutlineTransparency = 0.15
    highlight.DepthMode = Enum.HighlightDepthMode.Occluded
    highlight.Parent = character

    -- 3. PILAR DE ENERGÍA VERTICAL (Columna de luz suave que sube desde los pies)
    local pillarBottom = Instance.new("Attachment")
    pillarBottom.Name = "AuraPillar_Bottom"
    pillarBottom.Position = Vector3.new(0, -2.6, 0)
    pillarBottom.Parent = hrp

    local pillarTop = Instance.new("Attachment")
    pillarTop.Name = "AuraPillar_Top"
    pillarTop.Position = Vector3.new(0, 4.2, 0)
    pillarTop.Parent = hrp

    local pillar = Instance.new("Beam")
    pillar.Name = "AuraPillar"
    pillar.Attachment0 = pillarBottom
    pillar.Attachment1 = pillarTop
    pillar.Color = ColorSequence.new(colorA, colorB)
    pillar.LightEmission = 1
    pillar.FaceCamera = false
    pillar.Segments = 10
    pillar.Width0 = 1.4 + intensity * 1.0
    pillar.Width1 = 1.0 + intensity * 0.8
    pillar.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.85),
        NumberSequenceKeypoint.new(0.35, 0.45),
        NumberSequenceKeypoint.new(0.75, 0.65),
        NumberSequenceKeypoint.new(1, 1),
    })
    pillar.Parent = hrp

    -- Núcleo interior brillante del pilar
    local pillarCore = Instance.new("Beam")
    pillarCore.Name = "AuraPillarCore"
    pillarCore.Attachment0 = pillarBottom
    pillarCore.Attachment1 = pillarTop
    pillarCore.Color = ColorSequence.new(colorB, colorA)
    pillarCore.LightEmission = 1
    pillarCore.FaceCamera = false
    pillarCore.Segments = 10
    pillarCore.Width0 = 0.35 + intensity * 0.3
    pillarCore.Width1 = 0.25 + intensity * 0.25
    pillarCore.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.55),
        NumberSequenceKeypoint.new(0.5, 0.15),
        NumberSequenceKeypoint.new(1, 0.9),
    })
    pillarCore.Parent = hrp

    -- 4. CHISPAS ASCENDENTES NÍTIDAS (Sol's RNG Sparkles con Squash dinámico)
    local hrpAttachment = Instance.new("Attachment")
    hrpAttachment.Name = "AuraRootAttachment"
    hrpAttachment.Position = Vector3.new(0, -1.8, 0)
    hrpAttachment.Parent = hrp

    local sparkEmitter = Instance.new("ParticleEmitter")
    sparkEmitter.Name = "AuraSparks"
    sparkEmitter.Texture = SPARKLE_TEXTURE
    sparkEmitter.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, colorA),
        ColorSequenceKeypoint.new(0.5, colorB),
        ColorSequenceKeypoint.new(1, colorA),
    })
    sparkEmitter.LightEmission = 1
    sparkEmitter.Rate = math.clamp(16 + math.floor(level * 0.35), 16, 45)
    sparkEmitter.Speed = NumberRange.new(3 + intensity * 3, 7 + intensity * 5)
    sparkEmitter.SpreadAngle = Vector2.new(24, 24)
    sparkEmitter.Lifetime = NumberRange.new(0.6, 1.2)
    sparkEmitter.Squash = NumberSequence.new({
        NumberSequenceKeypoint.new(0, -0.6),
        NumberSequenceKeypoint.new(0.4, 0.2),
        NumberSequenceKeypoint.new(1, 0),
    })
    sparkEmitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.25),
        NumberSequenceKeypoint.new(0.5, 0.65),
        NumberSequenceKeypoint.new(1, 0),
    })
    sparkEmitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(0.7, 0.05),
        NumberSequenceKeypoint.new(1, 1),
    })
    sparkEmitter.EmissionDirection = Enum.NormalId.Top
    sparkEmitter.Parent = hrpAttachment

    -- Capa 3: Estelas de movimiento en extremidades (Hands & Feet Trails)
    local limbParts = {
        character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"),
        character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm"),
        character:FindFirstChild("RightFoot") or character:FindFirstChild("Right Leg"),
        character:FindFirstChild("LeftFoot") or character:FindFirstChild("Left Leg"),
    }
    for _, limb in ipairs(limbParts) do
        if limb and limb:IsA("BasePart") then
            local a0 = Instance.new("Attachment")
            a0.Name = "AuraLimb_Att0"
            a0.Position = Vector3.new(0, 0.4, 0)
            a0.Parent = limb

            local a1 = Instance.new("Attachment")
            a1.Name = "AuraLimb_Att1"
            a1.Position = Vector3.new(0, -0.4, 0)
            a1.Parent = limb

            local limbTrail = Instance.new("Trail")
            limbTrail.Name = "AuraLimb_Trail"
            limbTrail.Attachment0 = a0
            limbTrail.Attachment1 = a1
            limbTrail.Color = ColorSequence.new(colorA, colorB)
            limbTrail.Lifetime = 0.24
            limbTrail.LightEmission = 1
            limbTrail.FaceCamera = true
            limbTrail.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.25),
                NumberSequenceKeypoint.new(1, 1),
            })
            limbTrail.Parent = limb
        end
    end

    -- 5. ESCALADO POR RAREZA Y NIVEL (Halo en la cabeza para tiers superiores)
    local mult = auraDef.Multiplier or 1
    local tier = mult >= 15 and 5 or mult >= 6 and 4 or mult >= 3 and 3 or mult >= 1.5 and 2 or 1
    tier = math.max(tier, math.clamp(math.floor(level / 25) + 1, 1, 5))

    if tier >= 3 then
        local halo = Instance.new("Part")
        halo.Name = "AuraHalo"
        halo.Shape = Enum.PartType.Cylinder
        halo.Size = Vector3.new(0.12, 2.4, 2.4)
        halo.Material = Enum.Material.Neon
        halo.Color = colorB
        halo.Transparency = 0.35
        halo.CanCollide = false
        halo.Massless = true
        halo.CastShadow = false
        halo.Parent = container

        local wHalo = Instance.new("Weld")
        wHalo.Part0 = hrp
        wHalo.Part1 = halo
        wHalo.C0 = CFrame.new(0, 3.2, 0) * CFrame.Angles(0, 0, math.rad(90))
        wHalo.Parent = halo
    end

    -- 6. POLVO ETÉREO AMBIENTAL (Partículas que envuelven al avatar)
    local dustAttachment = Instance.new("Attachment")
    dustAttachment.Name = "AuraDustAttachment"
    dustAttachment.Position = Vector3.new(0, 0.5, 0)
    dustAttachment.Parent = hrp

    local dustEmitter = Instance.new("ParticleEmitter")
    dustEmitter.Name = "AuraDust"
    dustEmitter.Texture = SMOKE_TEXTURE
    dustEmitter.Color = ColorSequence.new(colorA, colorB)
    dustEmitter.LightEmission = 0.35
    dustEmitter.Rate = math.clamp(6 + math.floor(level * 0.1), 6, 18)
    dustEmitter.Speed = NumberRange.new(0.4, 1.4)
    dustEmitter.SpreadAngle = Vector2.new(180, 180)
    dustEmitter.Lifetime = NumberRange.new(1.4, 2.6)
    dustEmitter.Rotation = NumberRange.new(0, 360)
    dustEmitter.RotSpeed = NumberRange.new(-25, 25)
    dustEmitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1.2),
        NumberSequenceKeypoint.new(0.5, 2.4 + intensity),
        NumberSequenceKeypoint.new(1, 0),
    })
    dustEmitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.75),
        NumberSequenceKeypoint.new(0.5, 0.55),
        NumberSequenceKeypoint.new(1, 1),
    })
    dustEmitter.Parent = dustAttachment

    -- 7. ANILLOS DE PODER A LOS PIES (Ground Power Rings, contra-rotatorios)
    local floorRing = CreatePowerRing(hrp, "AuraFloorRing", colorA, 4.6, 0.08, 0.4)
    floorRing.Parent = container

    local wFloor = Instance.new("Weld")
    wFloor.Part0 = hrp
    wFloor.Part1 = floorRing
    wFloor.C0 = CFrame.new(0, -2.8, 0) * CFrame.Angles(0, 0, math.rad(90))
    wFloor.Parent = floorRing

    local outerRing = CreatePowerRing(hrp, "AuraFloorRingOuter", colorB, 6.1, 0.05, 0.55)
    outerRing.Parent = container

    local wOuter = Instance.new("Weld")
    wOuter.Part0 = hrp
    wOuter.Part1 = outerRing
    wOuter.C0 = CFrame.new(0, -2.7, 0) * CFrame.Angles(0, 0, math.rad(90))
    wOuter.Parent = outerRing

    -- 7. ORBES DE ENERGÍA ORBITALES (Escalan con el nivel)
    local orbCount = math.clamp(2 + math.floor(level / 100), 2, 5)
    local orbs: { { Part: Part, Weld: Weld, Radius: number, Height: number, Speed: number, Phase: number } } = {}
    for i = 1, orbCount do
        local orb = Instance.new("Part")
        orb.Name = "AuraOrb" .. tostring(i)
        orb.Shape = Enum.PartType.Ball
        orb.Size = Vector3.new(0.55, 0.55, 0.55)
        orb.Material = Enum.Material.Neon
        orb.Color = (i % 2 == 0) and colorB or colorA
        orb.CanCollide = false
        orb.Massless = true
        orb.CastShadow = false
        orb.Parent = container

        -- Chispa que escapa del orbe
        local orbAtt = Instance.new("Attachment", orb)
        local orbSpark = Instance.new("ParticleEmitter")
        orbSpark.Texture = SPARKLE_TEXTURE
        orbSpark.Color = ColorSequence.new(orb.Color)
        orbSpark.LightEmission = 1
        orbSpark.Rate = 8
        orbSpark.Speed = NumberRange.new(0.5, 1.5)
        orbSpark.Lifetime = NumberRange.new(0.3, 0.6)
        orbSpark.Size = NumberSequence.new(0.25, 0)
        orbSpark.Parent = orbAtt

        local wOrb = Instance.new("Weld")
        wOrb.Part0 = hrp
        wOrb.Part1 = orb
        wOrb.C0 = CFrame.new(2.6, 0, 0)
        wOrb.Parent = orb

        table.insert(orbs, {
            Part = orb,
            Weld = wOrb,
            Radius = 2.6 + (i % 2) * 0.5,
            Height = -0.4 + (i * 0.9),
            Speed = 1.4 + i * 0.25,
            Phase = (i / orbCount) * math.pi * 2,
        })
    end

    -- 8. ONDA DE EQUIPAMIENTO (Shockwave expansiva al recibir el aura)
    local shock = Instance.new("Part")
    shock.Name = "AuraEquipShock"
    shock.Shape = Enum.PartType.Cylinder
    shock.Size = Vector3.new(0.2, 2, 2)
    shock.CFrame = hrp.CFrame * CFrame.new(0, -2.4, 0) * CFrame.Angles(0, 0, math.rad(90))
    shock.Material = Enum.Material.Neon
    shock.Color = colorA
    shock.Transparency = 0.25
    shock.CanCollide = false
    shock.Massless = true
    shock.Anchored = true
    shock.CastShadow = false
    shock.Parent = container

    TweenService:Create(shock, TweenInfo.new(0.7, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.2, 18, 18),
        Transparency = 1,
    }):Play()
    Debris:AddItem(shock, 0.8)

    -- Bucle único: rota anillos y orbita los orbes (cero interferencia con la física)
    task.spawn(function()
        local ang = 0
        while hrp.Parent do
            ang += 1.8
            if wFloor.Parent then
                wFloor.C0 = CFrame.new(0, -2.8, 0) * CFrame.Angles(0, math.rad(ang), math.rad(90))
            end
            if wOuter.Parent then
                wOuter.C0 = CFrame.new(0, -2.7, 0) * CFrame.Angles(0, math.rad(-ang * 0.7), math.rad(90))
            end

            for _, orb in ipairs(orbs) do
                if orb.Weld.Parent and orb.Part.Parent then
                    local theta = math.rad(ang) * orb.Speed + orb.Phase
                    orb.Weld.C0 = CFrame.new(
                        math.cos(theta) * orb.Radius,
                        orb.Height,
                        math.sin(theta) * orb.Radius
                    )
                end
            end

            task.wait(0.03)
        end
    end)
end

return AuraVFXModule
