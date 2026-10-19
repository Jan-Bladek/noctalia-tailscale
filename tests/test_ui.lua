-- Contract smoke tests using host API stubs. These do not replace a live shell test.
local state, watchers, tree, text = {}, {}, nil, nil
noctalia = {
    state = {
        get = function(key) return state[key] end,
        set = function(key, value) state[key] = value end,
        watch = function(key, callback) watchers[key] = callback end,
    },
    togglePanel = function(id) assert(id == 'Jan-Bladek/tailscale:panel') end,
    copyToClipboard = function() end,
    runAsync = function() return true end,
}
ui = setmetatable({}, {__index = function(_, kind)
    return function(props, children) return {kind=kind, props=props, children=children} end
end})
panel = {render = function(value) tree = value end, close = function() end}
barWidget = {setText = function(value) text = value end}
dofile('tailscale/widget.luau')
assert(text == 'TS · Loading')
state.status = {state='Running', ips={'100.64.0.1'}, exits={
    {name='gateway', ip='100.64.0.2', online=true, selected=true},
    {name='offline', ip='100.64.0.3', online=false},
}}
update()
assert(text == 'TS · On')
onClick()
dofile('tailscale/panel.luau')
onOpen()
assert(tree.kind == 'scroll')
local function find(node, label)
    if node.props.text == label then return node end
    for _, child in ipairs(node.children or {}) do
        local found = find(child, label)
        if found then return found end
    end
end
assert(find(tree, 'offline · offline').props.enabled == false)
find(tree, '✓ gateway').props.onClick()
assert(state.request.action == 'exit' and state.request.value == '100.64.0.2')
state.busy = true
update()
assert(find(tree, 'Disconnect').props.enabled == false)
state.busy = false
state.status.state = 'NeedsLogin'
state.status.authUrl = 'https://login.tailscale.com/a/test'
update()
assert(find(tree, 'Open login link'))
print('UI contracts passed')
