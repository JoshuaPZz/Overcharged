--!strict
-- Módulo utilitario para formatear números en notación abreviada (1K, 1M, 1B...)
local FormatNumber = {}

local SUFFIXES = {
    "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"
}

function FormatNumber.FormatCompact(value: number): string
    if value < 1000 then
        return string.format("%.0f", math.floor(value))
    end

    local magnitude = math.floor(math.log10(math.max(1, value)) / 3)
    local suffixIndex = math.min(magnitude + 1, #SUFFIXES)
    local suffix = SUFFIXES[suffixIndex]

    local scaled = value / (10 ^ ((suffixIndex - 1) * 3))
    return string.format("%.2f%s", scaled, suffix)
end

function FormatNumber.FormatCommas(value: number): string
    local formatted = tostring(math.floor(value))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then
            break
        end
    end
    return formatted
end

return FormatNumber
