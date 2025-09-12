local RSGCore = exports['rsg-core']:GetCoreObject()
local Config = load(LoadResourceFile(GetCurrentResourceName(), 'config.lua'))()
local SERVER_OWNER_CITIZENID = Config.ServerOwnerCitizenId
local Props = {}

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

-- Load all props from DB on resource start
CreateThread(function()
    exports.oxmysql:fetch('SELECT * FROM ds_props', {}, function(result)
        if result then
            for i = 1, #result do
                local propData = nil
                local success, err = pcall(function()
                    propData = json.decode(result[i].properties)
                end)
                if success and propData and propData.id then
                    Props[propData.id] = propData
                else
                    print('[ds-propplacer] Error decoding propData:', err, result[i])
                end
            end
        end
    end)
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

    local PropData = {
        proptype = proptype,
        x = position.x,
        y = position.y,
        z = position.z,
        h = heading,
        hash = hash,
        builder = Player.PlayerData.citizenid,
        buildttime = os.time()
    }

    exports.oxmysql:insert('INSERT INTO ds_props (properties, citizenid, proptype) VALUES (?, ?, ?)', {
        json.encode(PropData),
        Player.PlayerData.citizenid,
        proptype
    }, function(insertId)
        if insertId then
            Props[insertId] = PropData
            TriggerClientEvent('ds-propplacer:client:propPlaced', src, insertId)
            TriggerClientEvent('ox_lib:notify', src, {title = 'Prop Placed! ID: '..insertId, type = 'success', duration = 7000})
            TriggerClientEvent('ds-propplacer:client:updatePropData', -1, { [insertId] = PropData })
        else
            TriggerClientEvent('ox_lib:notify', src, {title = 'DB error: Could not place prop.', type = 'error', duration = 7000})
        end
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
        if result then
            Props[propid] = nil
            TriggerClientEvent('ds-propplacer:client:removePropObject', -1, propid)
            TriggerClientEvent('ds-propplacer:client:updatePropData', -1, { [propid] = false })
        else
            print('[ds-propplacer] Error deleting prop:', propid)
            TriggerClientEvent('ox_lib:notify', src, {title = 'DB error: Could not delete prop.', type = 'error', duration = 7000 })
        end
    end)
end)
