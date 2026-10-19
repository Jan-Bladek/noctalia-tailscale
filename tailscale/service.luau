local busy = false
local polling = false
local function publishError(message)
    noctalia.state.set("error", message)
end
local function invoke(action, value, callback)
    local accepted = noctalia.runAsync({"python3", noctalia.pluginDir() .. "/backend.py", action, value or ""}, function(result)
        local data = noctalia.json.decode(result.stdout or "")
        if not data then data = {error = result.stderr or "Invalid backend response"} end
        callback(data)
    end)
    if not accepted then callback({error = "Could not start Tailscale backend"}) end
end
function update()
    if polling or busy then return end
    polling = true
    invoke("status", nil, function(data)
        polling = false
        if data.error then
            noctalia.state.set("status", {state = "Unavailable", ips = {}, exits = {}})
            publishError(data.error)
        else
            noctalia.state.set("status", data)
            if data.state == "Running" then noctalia.state.set("authUrl", "") end
        end
    end)
end
noctalia.state.watch("request", function(request)
    if not request or busy then return end
    busy = true
    noctalia.state.set("busy", true)
    publishError("")
    invoke(request.action, request.value, function(data)
        busy = false
        noctalia.state.set("busy", false)
        if data.error then publishError(data.error) end
        if data.authUrl then noctalia.state.set("authUrl", data.authUrl) end
        update()
    end)
end)
noctalia.setUpdateInterval(3000)
update()
