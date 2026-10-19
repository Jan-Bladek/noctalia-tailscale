local draft = nil
local serial = 0
local function request(action, value)
    serial = serial + 1
    noctalia.state.set("request", {action = action, value = value or "", serial = serial})
end
local function button(text, action, value, enabled)
    return ui.button({text = text, enabled = enabled, onClick = function() request(action, value) end})
end
local function toggle(label, key, checked, enabled)
    return ui.row({gap = 10, align = "center"}, {
        ui.label({text = label, flexGrow = 1}),
        ui.toggle({checked = checked == true, enabled = enabled, onChange = function(v) request(key, v) end}),
    })
end
function update()
    local s = noctalia.state.get("status") or {state = "Loading", ips = {}, exits = {}}
    local busy = noctalia.state.get("busy") == true
    local ready = not busy and s.state ~= "Unavailable" and s.state ~= "Loading"
    local prefsReady = ready and (s.prefsError or "") == ""
    local rows = {
        ui.row({align = "center"}, {
            ui.label({text = "Tailscale", fontSize = 24, fontWeight = "bold", flexGrow = 1}),
            ui.button({text = "×", onClick = function() panel.close() end}),
        }),
        ui.label({text = (s.hostname or "") .. " · " .. s.state .. (busy and " · Working…" or "")}),
        ui.button({text = table.concat(s.ips or {}, "  "), enabled = #(s.ips or {}) > 0,
            onClick = function() noctalia.copyToClipboard(table.concat(s.ips or {}, "\n"), "text/plain") end}),
        ui.row({gap = 8}, {
            button(s.state == "Running" and "Disconnect" or "Connect", s.state == "Running" and "disconnect" or "connect", nil, ready),
            button("Sign in / Get login link", "login", nil, ready and s.state ~= "Running"),
        }),
    }
    local auth = s.authUrl or ""
    if auth == "" and s.state ~= "Running" then auth = noctalia.state.get("authUrl") or "" end
    if auth ~= "" and s.state ~= "Running" then
        table.insert(rows, ui.label({text = auth, maxLines = 3}))
        table.insert(rows, ui.row({gap = 8}, {
            ui.button({text = "Open login link", onClick = function() noctalia.runAsync({"xdg-open", auth}) end}),
            ui.button({text = "Copy link", onClick = function() noctalia.copyToClipboard(auth, "text/plain") end}),
        }))
    end
    table.insert(rows, ui.separator({}))
    table.insert(rows, ui.label({text = "Exit node", fontWeight = "bold"}))
    table.insert(rows, button("None — use direct connection", "exit", "", ready))
    for _, peer in ipairs(s.exits or {}) do
        table.insert(rows, button((peer.selected and "✓ " or "") .. peer.name .. (peer.online and "" or " · offline"), "exit", peer.ip, ready and peer.online))
    end
    table.insert(rows, toggle("Allow LAN while using exit node", "allowLan", s.allowLan, prefsReady))
    table.insert(rows, ui.separator({}))
    table.insert(rows, toggle("Accept subnet routes", "acceptRoutes", s.acceptRoutes, prefsReady))
    table.insert(rows, toggle("Use Tailscale DNS", "acceptDns", s.acceptDns, prefsReady))
    table.insert(rows, toggle("Block incoming connections", "shieldsUp", s.shieldsUp, prefsReady))
    table.insert(rows, toggle("Advertise this device as exit node", "advertiseExit", s.advertiseExit, prefsReady))
    table.insert(rows, ui.label({text = "Advertised subnets (CIDR, comma separated)"}))
    table.insert(rows, ui.input({key = "routes", value = draft or s.routes or "", placeholder = "192.168.1.0/24, fd00::/64", enabled = prefsReady,
        onChange = function(v) draft = v end}))
    table.insert(rows, ui.button({text = "Apply subnet routes", enabled = prefsReady, onClick = function() request("routes", draft or s.routes or "") end}))
    table.insert(rows, ui.label({text = "Advertising routes requires IP forwarding and approval in the Tailscale admin console.", maxLines = 3, color = "on_surface_variant"}))
    table.insert(rows, ui.button({text = "Open admin console", onClick = function() noctalia.runAsync({"xdg-open", "https://login.tailscale.com/admin/machines"}) end}))
    for _, warning in ipairs(s.health or {}) do table.insert(rows, ui.label({text = warning, maxLines = 4})) end
    local err = noctalia.state.get("error") or ""
    if (s.prefsError or "") ~= "" then err = err .. "\n" .. s.prefsError end
    if err ~= "" then table.insert(rows, ui.label({text = err, color = "error", maxLines = 6})) end
    panel.render(ui.scroll({padding = 16, gap = 10}, rows))
end
function onOpen()
    draft = nil
    update()
end
noctalia.state.watch("status", function() update() end)
noctalia.state.watch("busy", function() update() end)
noctalia.state.watch("error", function() update() end)
noctalia.state.watch("authUrl", function() update() end)
