-- Host contract tests; live shell checks are also needed.
local state, watchers, tree, text, image, browser = {}, {}, nil, nil, nil, nil
local files = {}
noctalia = {
    state = {
        get = function(key) return state[key] end,
        set = function(key, value) state[key] = value end,
        watch = function(key, callback) watchers[key] = callback end,
    },
    getColor = function() return '#e0d6ca' end,
    pluginDataDir = function() return '/test' end,
    fileExists = function(path) return files[path] ~= nil end,
    writeFile = function(path, content) files[path] = content; return true end,
    togglePanel = function(id) assert(id == 'Jan-Bladek/tailscale:panel') end,
    copyToClipboard = function() end,
    runAsync = function(argv, callback) browser = argv; if callback then callback({exitCode=0}) end; return true end,
}
local originalRequire = require
require = function(path)
    if path == './icons.luau' then return dofile('tailscale/icons.luau') end
    return originalRequire(path)
end
ui = setmetatable({}, {__index = function(_, kind)
    return function(props, children) return {kind=kind, props=props, children=children} end
end})
panel = {render = function(value) tree = value end, close = function() end}
barWidget = {
    setText = function(value) text = value end,
    setImage = function(path) image = path end,
    setGlyph = function() error('Image rendering should be available') end,
    setTooltip = function() end,
}
dofile('tailscale/widget.luau')
assert(text == '' and image:match('off.svg$'))
local off = files[image]
assert(off:match('<path') and off:match('#e0d6ca'))
state.status = {state='Running', ips={'100.64.0.1'}, exits={
    {name='gateway', ip='100.64.0.2', online=true, selected=true},
    {name='offline', ip='100.64.0.3', online=false},
}}
update()
assert(text == '' and image:match('on.svg$'))
assert(not files[image]:match('<path'))
onClick()
onRightClick()
assert(state.request.action == 'disconnect')
dofile('tailscale/panel.luau')
onOpen()
assert(tree.kind == 'scroll' and tree.props.flexGrow == 1)
local function find(node, label)
    if node.props.text == label then return node end
    for _, child in ipairs(node.children or {}) do
        local found = find(child, label)
        if found then return found end
    end
end
assert(find(tree, 'offline  ·  100.64.0.3 · offline').props.enabled == false)
find(tree, 'gateway  ·  100.64.0.2').props.onClick()
assert(state.request.action == 'exit' and state.request.value == '100.64.0.2')
state.busy = true
update()
assert(find(tree, 'gateway  ·  100.64.0.2').props.enabled == false)
state.busy = false
state.status.state = 'NeedsLogin'
state.status.authUrl = 'https://login.tailscale.com/a/test'
update()
find(tree, 'Open login link').props.onClick()
assert(browser[1] == 'xdg-open' and browser[2] == state.status.authUrl)
find(tree, state.status.authUrl).props.onClick()
assert(browser[2] == state.status.authUrl)
assert(not find(tree, 'Advertise as exit node'))
find(tree, 'Advanced settings').props.onClick()
assert(find(tree, 'Advertise as exit node'))
onIpc('connect')
assert(state.request.action == 'connect')
print('UI contracts passed: themed icons, busy state, exit selection, clickable URL, advanced settings')
