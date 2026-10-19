function update()
    local s = noctalia.state.get("status") or {state = "Loading"}
    barWidget.setText(s.state == "Running" and "TS · On" or "TS · " .. s.state)
end
function onClick()
    noctalia.togglePanel("Jan-Bladek/tailscale:panel")
end
noctalia.state.watch("status", function() update() end)
update()
