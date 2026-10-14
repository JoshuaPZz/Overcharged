--!strict
-- AuraVFXModule: Motor procedural de Auras estilo Sol's RNG / Anime AAA (Limpio, nítido y sin artefactos blancos)
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local AuraVFXModule = {}

-- Textura nativa oficial integrada en el motor de Roblox (Garantizada 100% funcional y transparente)
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

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

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp then
        local oldLight = hrp:FindFirstChild("AuraPointLight")
        if oldLight then oldLight:Destroy() end
        local oldAtt = hrp:FindFirstChild("AuraRootAttachment")
        if oldAtt then oldAtt:Destroy() end
    end
end

-- Inyecta los efectos visuales completos del Aura en el personaje
function AuraVFXModule.AttachAuraVFX(character: Model, auraDef: any, level: number)
    AuraVFXModule.ClearAuraVFX(character)

    local hrp = character:WaitForChild("HumanoidRootPart", 4) :: BasePart?
    local torso = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
    if not hrp or not torso then return end

    local colorA: Color3 = auraDef.RarityColor or Color3.fromRGB(0, 210, 255)
    local colorB: Color3 = auraDef.SecondaryColor or Color3.fromRGB(255, 255, 255)

    local container = Instance.new("Folder")
    container.Name = "AuraVFXContainer"
    container.Parent = character

    -- 1. POINTLIGHT SUAVE EN EL SUELO (Iluminación ambiental, no cegadora)
    local pLight = Instance.new("PointLight")
    pLight.Name = "AuraPointLight"
    pLight.Color = colorA
    pLight.Brightness = 0.8
    pLight.Range = 12
    pLight.Shadows = false
    pLight.Parent = hrp

    -- 2. HIGHLIGHT NATIVO DE ROBLOX (SILUETA CELESTIAL ANIME CON PROFUNDIDAD OCLUIDA)
    local highlight = Instance.new("Highlight")
    highlight.Name = "AuraHighlight"
    highlight.Adornee = character
    highlight.FillColor = colorA
    highlight.FillTransparency = 0.88 -- Muy transparente para que la ropa y cara del avatar sean 100% nítidas
    highlight.OutlineColor = colorA
    highlight.OutlineTransparency = 0.25
    highlight.DepthMode = Enum.HighlightDepthMode.Occluded -- ¡NUNCA AlwaysOnTop para evitar desteñir al personaje!
    highlight.Parent = character

    -- 3. CHISPAS ASCENDENTES NÍTIDAS (Sol's RNG Sparkles con textura nativa alpha-transparente)
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
    sparkEmitter.LightEmission = 0.4
    sparkEmitter.Rate = math.clamp(10 + math.floor(level * 0.2), 10, 22)
    sparkEmitter.Speed = NumberRange.new(3, 7)
    sparkEmitter.SpreadAngle = Vector2.new(20, 20)
    sparkEmitter.Lifetime = NumberRange.new(0.6, 1.1)
    sparkEmitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.25),
        NumberSequenceKeypoint.new(0.5, 0.55),
        NumberSequenceKeypoint.new(1, 0),
    })
    sparkEmitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(0.7, 0.1),
        NumberSequenceKeypoint.new(1, 1),
    })
    sparkEmitter.EmissionDirection = Enum.NormalId.Top
    sparkEmitter.Parent = hrpAttachment

    -- 4. CÍRCULO RÚNICO / ANILLO DE PODER A LOS PIES DEL AVATAR (Ground Power Ring)
    local floorRing = Instance.new("Part")
    floorRing.Name = "AuraFloorRing"
    floorRing.Shape = Enum.PartType.Cylinder
    floorRing.Size = Vector3.new(0.06, 4.4, 4.4)
    floorRing.Material = Enum.Material.Neon
    floorRing.Color = colorA
    floorRing.Transparency = 0.45
    floorRing.CanCollide = false
    floorRing.Parent = container

    local wFloor = Instance.new("Weld")
    wFloor.Part0 = hrp
    wFloor.Part1 = floorRing
    wFloor.C0 = CFrame.new(0, -2.8, 0) * CFrame.Angles(0, 0, math.rad(90))
    wFloor.Parent = floorRing

    -- Giro suave del anillo de energía rotando el offset del Weld (Cero interferencia con la física del jugador)
    task.spawn(function()
        local ang = 0
        while floorRing and floorRing.Parent and wFloor and wFloor.Parent do
            ang += 1.8
            wFloor.C0 = CFrame.new(0, -2.8, 0) * CFrame.Angles(0, math.rad(ang), math.rad(90))
            task.wait(0.03)
        end
    end)
end

return AuraVFXModule
