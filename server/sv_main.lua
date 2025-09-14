local RSGCore = exports['rsg-core']:GetCoreObject()
local Config = load(LoadResourceFile(GetCurrentResourceName(), 'config.lua'))()
local SERVER_OWNER_CITIZENID = Config.ServerOwnerCitizenId
local Props = {}
local PropsLoaded = false
local AllProps = {}

-- propid will be integer autoincrement from DB

local function hasPermission(Player, action)
    if not Player or not Player.PlayerData then return false end
    local group = Player.PlayerData.group
    local cid = Player.PlayerData.citizenid
    print('[ds-propplacer] Player group:', group, 'CitizenID:', cid)
    if action == "place" or action == "remove" then
        -- Allow if player is admin, god, or matches configured CitizenID
        if group == "admin" or group == "god" or cid == SERVER_OWNER_CITIZENID then
            return true
        end
    end
    return false
end


-- Helper function to sync all props to all clients
local function SyncPropsToClients()
    TriggerClientEvent('ds-propplacer:client:updatePropData', -1, AllProps)
end

-- Periodically sync props to all clients
CreateThread(function()
    while true do
        Wait(5000)
        if PropsLoaded then
            SyncPropsToClients()
        end
    end
end)

-- Load all props from DB on resource start
CreateThread(function()
    exports.oxmysql:query('SELECT * FROM ds_props', {}, function(result)
        AllProps = {}
        if not result or not result[1] then
            SyncPropsToClients()
            PropsLoaded = true
            return
        end
        for i = 1, #result do
            local propData = nil
            local success, err = pcall(function()
                propData = json.decode(result[i].properties)
            end)
            if success and propData then
                propData.id = result[i].propid
                AllProps[#AllProps + 1] = propData
            else
                print('[ds-propplacer] Error decoding propData:', err, result[i])
            end
        end
        SyncPropsToClients()
        PropsLoaded = true
    end)
end)

-- Sync props to player when they are fully loaded (RSGCore event)
RegisterNetEvent('RSGCore:PlayerLoaded')
AddEventHandler('RSGCore:PlayerLoaded', function()
    local src = source
    TriggerClientEvent('ds-propplacer:client:updatePropData', src, AllProps)
end)

-- Load all props from DB and store in Props table
RegisterServerEvent('ds-propplacer:server:getProps')
AddEventHandler('ds-propplacer:server:getProps', function()
    Props = {}
    local result = exports.oxmysql:query_async('SELECT * FROM ds_props', {})
    if not result or not result[1] then
        SyncPropsToClients()
        return
    end
    for i = 1, #result do
        local propData = nil
        local success, err = pcall(function()
            propData = json.decode(result[i].properties)
        end)
        if success and propData then
            local id = propData.id or result[i].propid
            propData.id = id
            Props[id] = propData
        else
            print('[ds-propplacer] Error decoding propData:', err, result[i])
        end
    end
    SyncPropsToClients()
end)

RegisterNetEvent('ds-propplacer:server:getProps')
AddEventHandler('ds-propplacer:server:getProps', function()
    local src = source
    TriggerClientEvent('ds-propplacer:client:updatePropData', src, Props)
end)

RegisterServerEvent('ds-propplacer:server:newProp')
AddEventHandler('ds-propplacer:server:newProp', function(proptype, position, heading, hash)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not hasPermission(Player, "place") then
        TriggerClientEvent('ox_lib:notify', src, {title = 'No permission to place props.', type = 'error', duration = 7000})
        return
    end

    local propId = math.random(111111, 999999)
    local PropData = {
        id = propId,
        proptype = proptype or "unknown",
        x = position and position.x or 0.0,
        y = position and position.y or 0.0,
        z = position and position.z or 0.0,
        h = heading or 0.0,
        hash = hash or 0,
        builder = Player.PlayerData.citizenid or "unknown",
        buildttime = os.time()
    }

    table.insert(AllProps, PropData)
    exports.oxmysql:insert('INSERT INTO ds_props (properties, propid, citizenid, proptype) VALUES (?, ?, ?, ?)', {
        json.encode(PropData),
        propId,
        Player.PlayerData.citizenid,
        proptype
    }, function(insertId)
        TriggerClientEvent('ds-propplacer:client:propPlaced', src, propId)
        SyncPropsToClients()
    end)
end)

RegisterServerEvent('ds-propplacer:server:removeProp')
AddEventHandler('ds-propplacer:server:removeProp', function(propid)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not hasPermission(Player, "remove") then
        TriggerClientEvent('ox_lib:notify', src, {title = 'No permission to delete props.', type = 'error', duration = 7000 })
        return
    end
    exports.oxmysql:execute('DELETE FROM ds_props WHERE propid = @propid', {['@propid'] = propid}, function(result)
        for k, v in pairs(AllProps) do
            if v.id == propid then
                table.remove(AllProps, k)
            end
        end
        TriggerClientEvent('ds-propplacer:client:removePropObject', -1, propid)
        SyncPropsToClients()
    end)
end)
