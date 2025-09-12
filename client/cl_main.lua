local RSGCore = exports['rsg-core']:GetCoreObject()
local Props = {}
local PromptPlacerGroup = GetRandomIntInRange(0, 0xffffff)
local CancelPrompt, SetPrompt, RotateLeftPrompt, RotateRightPrompt

Citizen.CreateThread(function()
    Set()
    Del()
    RotateLeft()
    RotateRight()
end)

function Del()
    Citizen.CreateThread(function()
        local str = 'Cancel'
        CancelPrompt = PromptRegisterBegin()
        PromptSetControlAction(CancelPrompt, 0xF84FA74F)
        str = CreateVarString(10, 'LITERAL_STRING', str)
        PromptSetText(CancelPrompt, str)
        PromptSetEnabled(CancelPrompt, true)
        PromptSetVisible(CancelPrompt, true)
        PromptSetHoldMode(CancelPrompt, true)
        PromptSetGroup(CancelPrompt, PromptPlacerGroup)
        PromptRegisterEnd(CancelPrompt)
    end)
end

function Set()
    Citizen.CreateThread(function()
        local str = 'Set'
        SetPrompt = PromptRegisterBegin()
        PromptSetControlAction(SetPrompt, 0x07CE1E61)
        str = CreateVarString(10, 'LITERAL_STRING', str)
        PromptSetText(SetPrompt, str)
        PromptSetEnabled(SetPrompt, true)
        PromptSetVisible(SetPrompt, true)
        PromptSetHoldMode(SetPrompt, true)
        PromptSetGroup(SetPrompt, PromptPlacerGroup)
        PromptRegisterEnd(SetPrompt)
    end)
end

function RotateLeft()
    Citizen.CreateThread(function()
        local str = 'Rotate Left'
        RotateLeftPrompt = PromptRegisterBegin()
        PromptSetControlAction(RotateLeftPrompt, 0xA65EBAB4)
        str = CreateVarString(10, 'LITERAL_STRING', str)
        PromptSetText(RotateLeftPrompt, str)
        PromptSetEnabled(RotateLeftPrompt, true)
        PromptSetVisible(RotateLeftPrompt, true)
        PromptSetStandardMode(RotateLeftPrompt, true)
        PromptSetGroup(RotateLeftPrompt, PromptPlacerGroup)
        PromptRegisterEnd(RotateLeftPrompt)
    end)
end

function RotateRight()
    Citizen.CreateThread(function()
        local str = 'Rotate Right'
        RotateRightPrompt = PromptRegisterBegin()
        PromptSetControlAction(RotateRightPrompt, 0xDEB34313)
        str = CreateVarString(10, 'LITERAL_STRING', str)
        PromptSetText(RotateRightPrompt, str)
        PromptSetEnabled(RotateRightPrompt, true)
        PromptSetVisible(RotateRightPrompt, true)
        PromptSetStandardMode(RotateRightPrompt, true)
        PromptSetGroup(RotateRightPrompt, PromptPlacerGroup)
        PromptRegisterEnd(RotateRightPrompt)
    end)
end

function modelrequest(model)
    Citizen.CreateThread(function()
        RequestModel(model)
    end)
end

function PropPlacer(proptype, ObjectModel)
    local myPed = PlayerPedId()
    local pHead = GetEntityHeading(myPed)
    local pos = GetEntityCoords(myPed)
    local PropHash = GetHashKey(ObjectModel)
    local coords = GetEntityCoords(myPed)
    local _x,_y,_z = table.unpack(coords)
    local forward = GetEntityForwardVector(myPed)
    local x, y, z = table.unpack(pos - forward * -2.0)
    local ox = x -_x
    local oy = y-_y
    local oz = z - _z
    local heading = 0.0

    SetCurrentPedWeapon(myPed, -1569615261, true)
    RequestModel(PropHash)
    while not HasModelLoaded(PropHash) do
        Wait(100)
    end
    local tempObj = CreateObject(PropHash, pos.x, pos.y, pos.z, false, false, false)
    local tempObj2 = CreateObject(PropHash, pos.x, pos.y, pos.z, false, false, false)
    AttachEntityToEntity(tempObj2, myPed, 0, ox, oy, 0.5, 0.0, 0.0, 0, true, false, false, false, false)
    SetEntityAlpha(tempObj, 180)
    SetEntityAlpha(tempObj2, 0)

    while true do
        Wait(5)
        local PropPlacerGroupName  = CreateVarString(10, 'LITERAL_STRING', "PropPlacer")
        PromptSetActiveGroupThisFrame(PromptPlacerGroup, PropPlacerGroupName)

        AttachEntityToEntity(tempObj, myPed, 0, ox, oy, -0.8, 0.0, 0.0, heading, true, false, false, false, false)
        if IsControlPressed( 1, 0xA65EBAB4) then
            heading = heading - 1
        end
        if IsControlPressed( 1, 0xDEB34313) then
            heading = heading + 1
        end

        local pPos = GetEntityCoords(tempObj2)

        if PromptHasHoldModeCompleted(SetPrompt) then
            FreezeEntityPosition(myPed, true)
            TriggerServerEvent('ds-propplacer:server:newProp', proptype, pPos, heading, PropHash)
            DeleteEntity(tempObj2)
            DeleteEntity(tempObj)
            FreezeEntityPosition(myPed, false)
            break
RegisterNetEvent('ds-propplacer:client:propPlaced', function(propId)
    exports['ox_lib']:notify({title = 'Prop placed! ID: '..propId, type = 'success', duration = 7000})
end)
        end

        if PromptHasHoldModeCompleted(CancelPrompt) then
            DeleteEntity(tempObj2)
            DeleteEntity(tempObj)
            SetModelAsNoLongerNeeded(PropHash)
            break
        end
    end
end


RegisterCommand('removeprop', function(source, args, rawCommand)
    local propid = tonumber(args[1])
    if propid then
        if Props[propid] then
            TriggerServerEvent('ds-propplacer:server:removeProp', propid)
            exports['ox_lib']:notify({title = 'Prop deleted: '..propid, type = 'success', duration = 5000})
        else
            exports['ox_lib']:notify({title = 'Invalid prop ID: '..tostring(propid), type = 'error', duration = 5000})
        end
    else
    exports['ox_lib']:notify({title = 'Usage: /removeprop [propid]', type = 'error', duration = 5000})
    end
end)

RegisterCommand('placeprop', function(source, args, rawCommand)
    local proptype = args[1] or 'default'
    local model = args[2]
    if not model then
        print('Usage: /placeprop [type] [model]')
        return
    end
    PropPlacer(proptype, model)
end)

local SpawnedProps = {}

RegisterNetEvent('ds-propplacer:client:updatePropData', function(props)
    Props = props
    -- Remove all currently spawned props
    for id, obj in pairs(SpawnedProps) do
        if DoesEntityExist(obj) then
            DeleteEntity(obj)
        end
        SpawnedProps[id] = nil
    end
    -- Spawn all props from Props table
    for id, propData in pairs(Props) do
        local model = propData.hash or propData.model
        if model then
            RequestModel(model)
            while not HasModelLoaded(model) do
                Wait(10)
            end
            local groundZ = propData.z
            local found, z = GetGroundZFor_3dCoord(propData.x, propData.y, propData.z)
            if found then groundZ = z end
            local obj = CreateObject(model, propData.x, propData.y, groundZ, false, false, false)
            SetEntityHeading(obj, propData.h or 0.0)
            SpawnedProps[id] = obj
        end
    end
end)

RegisterNetEvent('ds-propplacer:client:removePropObject', function(propid)
    Props[propid] = nil
    if SpawnedProps[propid] and DoesEntityExist(SpawnedProps[propid]) then
        DeleteEntity(SpawnedProps[propid])
        SpawnedProps[propid] = nil
    end
end)
RegisterCommand('listprops', function()
    for id, propData in pairs(Props) do
        print('Prop ID:', id, 'Type:', propData.proptype, 'Model:', propData.hash or propData.model)
    end
end)