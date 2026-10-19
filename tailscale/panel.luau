local icons = require("./icons.luau")
local draft = nil
local advanced = false
local serial = 0
local labels = {Running = "Connected", Stopped = "Disconnected", NeedsLogin = "Sign in required", NeedsMachineAuth = "Awaiting admin approval", Starting = "Connecting…", Loading = "Loading…", Unavailable = "Service unavailable"}
local function request(action, value)
    if noctalia.state.get("busy") then return end
    serial = serial + 1
    noctalia.state.set("request", {action = action, value = value or "", serial = serial})
end
local function openUrl(url)
    local accepted = noctalia.runAsync({"xdg-open", url}, function(result)
        if result.exitCode ~= 0 then
            noctalia.state.set("error", "Could not open your browser. Copy the login link instead. " .. (result.stderr or ""))
        end
    end)
    if not accepted then noctalia.state.set("error", "Could not start your browser. Copy the login link instead.") end
end
local function button(text, action, value, enabled, glyph, selected, key)
    return ui.button({key = key, text = text, enabled = enabled, glyph = glyph, selected = selected,
        contentAlign = "start", controlSize = "sm", variant = "ghost",
        onClick = function() request(action, value) end})
end
local function toggle(label, key, checked, enabled)
    return ui.row({key = key, gap = 12, align = "center", paddingV = 3}, {
        ui.label({text = label, flexGrow = 1}),
        ui.toggle({checked = checked == true, enabled = enabled, onChange = function(v) request(key, v) end}),
    })
end
function update()
    local s = noctalia.state.get("status") or {state = "Loading", ips = {}, exits = {}}
    local busy = noctalia.state.get("busy") == true
    local connected = s.state == "Running"
    local ready = not busy and s.state ~= "Unavailable" and s.state ~= "Loading"
    local prefsReady = ready and (s.prefsError or "") == ""
    local needsLogin = s.state == "NeedsLogin" or s.state == "NoState"
    local title = s.hostname or ""
    if title == "" then title = "Tailscale" end
    local hero = {}
    local icon = icons.path(connected)
    if icon then table.insert(hero, ui.image({path = icon, width = 36, height = 36, opacity = connected and 1 or 0.5})) end
    table.insert(hero, ui.column({gap = 3, flexGrow = 1}, {
        ui.label({text = title, fontSize = 20, fontWeight = "bold"}),
        ui.label({text = busy and "Working…" or (labels[s.state] or s.state), color = "on_surface_variant", fontSize = 12}),
    }))
    table.insert(hero, ui.toggle({checked = connected, enabled = ready, onChange = function(value)
        request(value == "true" and "connect" or "disconnect")
    end}))
    local rows = {ui.row({gap = 14, paddingV = 8, align = "center"}, hero)}
    local err = noctalia.state.get("error") or ""
    if (s.prefsError or "") ~= "" then err = err .. "\n" .. s.prefsError end
    if err ~= "" then
        table.insert(rows, ui.label({key = "error", text = err, color = "error", maxLines = 6, fontSize = 12}))
    end
    if #(s.ips or {}) > 0 then
        table.insert(rows, ui.button({text = s.ips[1], glyph = "copy", variant = "ghost", contentAlign = "start", controlSize = "sm",
            tooltip = "Copy Tailscale addresses", onClick = function() noctalia.copyToClipboard(table.concat(s.ips, "\n"), "text/plain") end}))
    end
    local auth = s.authUrl or ""
    if auth == "" and not connected then auth = noctalia.state.get("authUrl") or "" end
    if auth ~= "" and not connected then
        -- The URL itself is clickable as well as the explicit browser button.
        table.insert(rows, ui.button({key = "auth-link", text = auth, glyph = "external-link", variant = "ghost", contentAlign = "start",
            tooltip = auth, onClick = function() openUrl(auth) end}))
        table.insert(rows, ui.row({gap = 8}, {
            ui.button({text = "Open login link", glyph = "external-link", variant = "primary", flexGrow = 1, onClick = function() openUrl(auth) end}),
            ui.button({text = "Copy link", glyph = "copy", onClick = function() noctalia.copyToClipboard(auth, "text/plain") end}),
        }))
    elseif needsLogin then
        table.insert(rows, ui.button({text = "Sign in to Tailscale", glyph = "login", enabled = ready, variant = "primary",
            onClick = function() request("login") end}))
    end
    table.insert(rows, ui.separator({}))
    table.insert(rows, ui.label({text = "EXIT NODE", fontSize = 11, fontWeight = "bold", color = "on_surface_variant"}))
    local hasExit = false
    for _, peer in ipairs(s.exits or {}) do if peer.selected then hasExit = true end end
    table.insert(rows, button("Direct connection", "exit", "", ready, hasExit and "world" or "check", not hasExit))
    for _, peer in ipairs(s.exits or {}) do
        -- DNS names distinguish devices which share the same host name.
        local name = peer.name .. "  ·  " .. peer.ip
        if not peer.online then name = name .. " · offline" end
        local node = button(name, "exit", peer.ip, ready and peer.online, peer.selected and "check" or "server", peer.selected, "exit-" .. peer.ip)
        table.insert(rows, node)
    end
    table.insert(rows, toggle("Allow local network", "allowLan", s.allowLan, prefsReady and hasExit))
    table.insert(rows, toggle("Accept subnet routes", "acceptRoutes", s.acceptRoutes, prefsReady))
    table.insert(rows, ui.separator({}))
    table.insert(rows, ui.button({text = "Advanced settings", glyph = advanced and "chevron-up" or "chevron-down", variant = "ghost", contentAlign = "start",
        onClick = function() advanced = not advanced; update() end}))
    if advanced then
        table.insert(rows, toggle("Use Tailscale DNS", "acceptDns", s.acceptDns, prefsReady))
        table.insert(rows, toggle("Block incoming connections", "shieldsUp", s.shieldsUp, prefsReady))
        table.insert(rows, toggle("Advertise as exit node", "advertiseExit", s.advertiseExit, prefsReady))
        table.insert(rows, ui.label({text = "Advertised subnets", color = "on_surface_variant", fontSize = 12}))
        table.insert(rows, ui.input({key = "routes", value = draft or s.routes or "", placeholder = "192.168.1.0/24, fd00::/64", enabled = prefsReady,
            onChange = function(v) draft = v end}))
        table.insert(rows, ui.button({text = "Apply subnet routes", enabled = prefsReady, onClick = function() request("routes", draft or s.routes or "") end}))
        table.insert(rows, ui.label({text = "Advertising routes requires IP forwarding and admin approval.", maxLines = 2, color = "on_surface_variant", fontSize = 12}))
    end
    for _, warning in ipairs(s.health or {}) do
        if warning ~= "Tailscale is stopped." then table.insert(rows, ui.label({text = warning, maxLines = 3, fontSize = 12, color = "on_surface_variant"})) end
    end
    table.insert(rows, ui.row({gap = 8}, {
        ui.button({text = "Admin console", glyph = "external-link", variant = "ghost", controlSize = "sm", flexGrow = 1,
            onClick = function() openUrl("https://login.tailscale.com/admin/machines") end}),
        ui.button({text = "Close", variant = "ghost", controlSize = "sm", onClick = function() panel.close() end}),
    }))
    panel.render(ui.scroll({key = "panel", flexGrow = 1, padding = 14, gap = 10}, rows))
end
function onOpen()
    draft = nil
    update()
end
-- IPC uses the same request path as the controls for live integration checks.
function onIpc(event, payload)
    if event == "connect" or event == "disconnect" or event == "login" then request(event)
    elseif event == "refresh" then update() end
end
noctalia.state.watch("status", function() update() end)
noctalia.state.watch("busy", function() update() end)
noctalia.state.watch("error", function() update() end)
noctalia.state.watch("authUrl", function() update() end)
