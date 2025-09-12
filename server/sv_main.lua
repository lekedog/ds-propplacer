local RSGCore = exports['rsg-core']:GetCoreObject()
local SERVER_OWNER_CITIZENID = "########" -- Server owner citizenid <-- CHANGE THIS TO YOUR CITIZENID
local Props = {}

-- Load all props from DB on resource start
CreateThread(function()
    exports.oxmysql:fetch('SELECT * FROM ds_props', {}, function(result)
        if result then
            for i = 1, #result do
                local propData = json.decode(result[i].properties)
                Props[propData.id] = propData
            end
        end
    end)
end)

-- Send all props to client on request
RegisterNetEvent('ds-propplacer:server:getProps')
AddEventHandler('ds-propplacer:server:getProps', function()
    local src = source
    TriggerClientEvent('ds-propplacer:client:updatePropData', src, Props)
end)

-- Place new prop
RegisterServerEvent('ds-propplacer:server:newProp')
AddEventHandler('ds-propplacer:server:newProp', function(proptype, position, heading, hash)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or Player.PlayerData.citizenid ~= SERVER_OWNER_CITIZENID then
        TriggerClientEvent('ox_lib:notify', src, {title = 'No permission to place props.', type = 'error', duration = 7000 })
        return
    end
    local propId = math.random(111111, 999999)
    local citizenid = Player.PlayerData.citizenid
    local PropData = {
        id = propId,
        proptype = proptype,
        x = position.x,
        y = position.y,
        z = position.z,
        h = heading,
        hash = hash,
        builder = citizenid,
        buildttime = os.time()
    }
    Props[propId] = PropData
    local insertData = {
        ['@properties'] = json.encode(PropData),
        ['@propid'] = propId,
        ['@citizenid'] = citizenid,
        ['@proptype'] = proptype,
    }
    print('[ds-propplacer] SQL Query: INSERT INTO ds_props (properties, propid, citizenid, proptype) VALUES (@properties, @propid, @citizenid, @proptype)')
    print('[ds-propplacer] Parameters:', json.encode(insertData))
    -- Check for duplicate propid before insert
    exports.oxmysql:fetch('SELECT propid FROM ds_props WHERE propid = @propid', {['@propid'] = propId}, function(rows)
        if rows and #rows > 0 then
            print('[ds-propplacer] Duplicate propid detected:', propId)
        else
            exports.oxmysql:execute('INSERT INTO ds_props (properties, propid, citizenid, proptype) VALUES (@properties, @propid, @citizenid, @proptype)', insertData, function(result)
                print('[ds-propplacer] Insert result:', result)
            end)
        end
    end)
    TriggerClientEvent('ds-propplacer:client:propPlaced', src, propId)
    TriggerClientEvent('ox_lib:notify', src, {title = 'Prop Placed! ID: '..propId, type = 'success', duration = 7000})
    TriggerClientEvent('ds-propplacer:client:updatePropData', -1, Props)
end)

-- Remove prop
RegisterServerEvent('ds-propplacer:server:removeProp')
AddEventHandler('ds-propplacer:server:removeProp', function(propid)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or Player.PlayerData.citizenid ~= SERVER_OWNER_CITIZENID then
        TriggerClientEvent('ox_lib:notify', src, {title = 'No permission to delete props.', type = 'error', duration = 7000 })
        return
    end
    Props[propid] = nil
    exports.oxmysql:execute('DELETE FROM ds_props WHERE propid = @propid', {['@propid'] = propid})
    TriggerClientEvent('ds-propplacer:client:removePropObject', -1, propid)
    TriggerClientEvent('ds-propplacer:client:updatePropData', -1, Props)
end)