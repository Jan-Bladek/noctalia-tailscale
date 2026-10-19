local icons = require("./icons.luau")
function update()
    local s = noctalia.state.get("status") or {state = "Loading"}
    local connected = s.state == "Running"
    barWidget.setText("")
    local path = icons.path(connected)
    if path then barWidget.setImage(path, false, 16, 16)
    else barWidget.setGlyph(connected and "shield-check" or "shield-off") end
    barWidget.setTooltip("Tailscale · " .. s.state .. "\nLeft click: open panel · Right click: connect/disconnect")
end
function onClick()
    noctalia.togglePanel("Jan-Bladek/tailscale:panel")
end
function onRightClick()
    if noctalia.state.get("busy") then return end
    local s = noctalia.state.get("status") or {}
    noctalia.state.set("request", {action = s.state == "Running" and "disconnect" or "connect"})
end
noctalia.state.watch("status", function() update() end)
update()
