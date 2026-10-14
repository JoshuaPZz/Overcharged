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

    -- CAPAS POR RAREZA (1 Común .. 5 Mítica)
    local mult = auraDef.Multiplier or 1
    local tier = mult >= 15 and 5 or mult >= 6 and 4 or mult >= 3 and 3 or mult >= 1.5 and 2 or 1
    tier = math.max(tier, math.clamp(math.floor(level / 25) + 1, 1, 5))

    local animated: { { w: Weld, base: CFrame, spin: Vector3 } } = {}
    local function Layer(size: Vector3, shape: Enum.PartType, transp: number, base: CFrame, spin: Vector3, color: Color3?)
        local p = Instance.new("Part")
        p.Shape = shape
        p.Size = size
        p.Material = Enum.Material.Neon
        p.Color = color or colorA
        p.Transparency = transp
        p.CanCollide = false
        p.CanQuery = false
        p.CanTouch = false
        p.Massless = true
        p.CastShadow = false
        p.Parent = container
        local w = Instance.new("Weld")
        w.Part0 = hrp
        w.Part1 = p
        w.C0 = base
        w.Parent = p
        table.insert(animated, { w = w, base = base, spin = spin })
    end

    if tier >= 2 then -- anillos orbitando
        Layer(Vector3.new(0.08, 5.2, 5.2), Enum.PartType.Cylinder, 0.55, CFrame.Angles(0, 0, math.rad(70)), Vector3.new(0, 2.2, 0))
        Layer(Vector3.new(0.08, 4.6, 4.6), Enum.PartType.Cylinder, 0.6, CFrame.Angles(math.rad(60), 0, 0), Vector3.new(1.6, 0, 0), colorB)
    end
    if tier >= 3 then -- halo sobre la cabeza
        Layer(Vector3.new(0.12, 2.2, 2.2), Enum.PartType.Cylinder, 0.25, CFrame.new(0, 3.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0, 1.2, 0), colorB)
    end
    if tier >= 4 then -- columna de luz
        Layer(Vector3.new(30, 3.2, 3.2), Enum.PartType.Cylinder, 0.88, CFrame.new(0, 12, 0) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0, 0.5, 0))
        pLight.Brightness = 1.6
        pLight.Range = 18
    end
    if tier >= 5 then -- espiral de estrellas
        local spiral = sparkEmitter:Clone()
        spiral.Rate = 40
        spiral.Speed = NumberRange.new(10, 14)
        spiral.SpreadAngle = Vector2.new(5, 5)
        spiral.RotSpeed = NumberRange.new(200, 360)
        spiral.LightEmission = 0.8
        spiral.Parent = hrpAttachment
        for i = 1, 3 do
            Layer(Vector3.new(0.5, 0.5, 0.5), Enum.PartType.Ball, 0.1,
                CFrame.Angles(0, math.rad(i * 120), 0) * CFrame.new(3.2, 0, 0), Vector3.new(0, 3, 0), colorB)
        end
    end

    if #animated > 0 then
        task.spawn(function()
            local t = 0
            while container.Parent do
                t += 0.03
                for _, a in ipairs(animated) do
                    if a.w.Parent then
                        a.w.C0 = CFrame.Angles(a.spin.X * t, a.spin.Y * t, a.spin.Z * t) * a.base
                    end
                end
                task.wait(0.03)
            end
        end)
    end

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
