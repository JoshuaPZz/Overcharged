--!strict
-- CameraController: Sistema dinámico de FOV, Camera Shake procedural con math.noise y Hitstop
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Camera = Workspace.CurrentCamera
local CameraController = {}

local BaseFOV = 70
local CurrentTargetFOV = 70

-- Estado de Camera Shake
local ShakeIntensity = 0
local ShakeDuration = 0
local ShakeElapsed = 0
local ShakeFrequency = 24

-- Efecto de Hitstop / Impact Frames
local hitstopEffect: ColorCorrectionEffect?

-- Inicializa el controlador de cámara
function CameraController.Initialize()
    Camera = Workspace.CurrentCamera
    Camera.FieldOfView = BaseFOV

    -- Crear efecto de destello de impacto
    hitstopEffect = Instance.new("ColorCorrectionEffect")
    hitstopEffect.Name = "HitstopFlash"
    hitstopEffect.Brightness = 0
    hitstopEffect.Contrast = 0
    hitstopEffect.Parent = Lighting

    -- Bucle de renderizado procedural de sacudida
    RunService.RenderStepped:Connect(function(dt: number)
        if ShakeElapsed < ShakeDuration and ShakeIntensity > 0 then
            ShakeElapsed += dt
            local progress = 1 - (ShakeElapsed / ShakeDuration)
            local currentMagnitude = ShakeIntensity * progress

            local time = os.clock() * ShakeFrequency
            local shakeX = (math.noise(time, 0, 0) - 0.5) * 2 * currentMagnitude
            local shakeY = (math.noise(0, time, 0) - 0.5) * 2 * currentMagnitude
            local shakeZ = (math.noise(0, 0, time) - 0.5) * 2 * currentMagnitude

            Camera.CFrame = Camera.CFrame * CFrame.Angles(
                math.rad(shakeX * 1.2),
                math.rad(shakeY * 1.2),
                math.rad(shakeZ * 0.8)
            )
        end
    end)
end

-- Interpola suavemente el FOV (82-88 en sprint/dash, 70 normal)
function CameraController.SetTargetFOV(targetFOV: number, duration: number?)
    CurrentTargetFOV = targetFOV
    local d = duration or 0.25
    TweenService:Create(Camera, TweenInfo.new(d, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        FieldOfView = targetFOV,
    }):Play()
end

-- Sacudida de cámara proporcional al impacto
function CameraController.Shake(intensity: number, duration: number, frequency: number?)
    ShakeIntensity = intensity
    ShakeDuration = duration
    ShakeElapsed = 0
    ShakeFrequency = frequency or 24
end

-- Hitstop / Impact Frames: destello blanco instantáneo de 0.05s y micro-sacudida
function CameraController.ApplyHitstop()
    if not hitstopEffect then return end

    hitstopEffect.Brightness = 0.45
    hitstopEffect.Contrast = 0.35

    CameraController.Shake(1.4, 0.18, 32)

    task.delay(0.05, function()
        if hitstopEffect then
            TweenService:Create(hitstopEffect, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Brightness = 0,
                Contrast = 0,
            }):Play()
        end
    end)
end

return CameraController
