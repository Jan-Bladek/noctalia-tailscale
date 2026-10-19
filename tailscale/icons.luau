-- Theme-aware Tailscale dot grid, with a slash when disconnected.
local M = {}
local cached = {}
function M.path(connected)
    local color = noctalia.getColor("on_surface") or "#ffffff"
    local key = color .. (connected and "-on" or "-off")
    if cached[key] then return cached[key] end
    local dir = noctalia.pluginDataDir()
    if not dir then return nil end
    local svg = '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">'
    for row = 0, 2 do
        for col = 0, 2 do
            local active = row == 1 or (row == 2 and col == 1)
            svg = svg .. '<circle cx="' .. (5 + col * 7) .. '" cy="' .. (5 + row * 7)
                .. '" r="2.5" fill="' .. color .. '" opacity="' .. (active and "1" or "0.24") .. '"/>'
        end
    end
    if not connected then
        svg = svg .. '<path d="M3 21L21 3" stroke="' .. color .. '" stroke-width="2.5" stroke-linecap="round"/>'
    end
    svg = svg .. '</svg>'
    local path = dir .. "/tailscale-" .. key:gsub("#", "") .. ".svg"
    if noctalia.fileExists(path) or noctalia.writeFile(path, svg) then
        cached[key] = path
        return path
    end
    return nil
end
return M
