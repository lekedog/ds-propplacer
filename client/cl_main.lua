local RSGCore = exports['rsg-core']:GetCoreObject()
local Props = {}
local SpawnedProps = {}
local PromptPlacerGroup = GetRandomIntInRange(0, 0xffffff)
local CancelPrompt, SetPrompt, RotateLeftPrompt, RotateRightPrompt

-- Utility: Register prompts
local function RegisterPrompt(name, control, holdMode, standardMode)
    Citizen.CreateThread(function()
        local prompt = PromptRegisterBegin()
        PromptSetControlAction(prompt, control)
        local str = CreateVarString(10, 'LITERAL_STRING', name)
        PromptSetText(prompt, str)
        PromptSetEnabled(prompt, true)
        PromptSetVisible(prompt, true)
        if holdMode then PromptSetHoldMode(prompt, true) end
        if standardMode then PromptSetStandardMode(prompt, true) end
        PromptSetGroup(prompt, PromptPlacerGroup)
        PromptRegisterEnd(prompt)
        if name == "Cancel" then CancelPrompt = prompt
        elseif name == "Set" then SetPrompt = prompt
        elseif name == "Rotate Left" then RotateLeftPrompt = prompt
        elseif name == "Rotate Right" then RotateRightPrompt = prompt
        end
    end)
end

Citizen.CreateThread(function()
    RegisterPrompt('Set', 0x07CE1E61, true, false)
    RegisterPrompt('Cancel', 0xF84FA74F, true, false)
    RegisterPrompt('Rotate Left', 0xA65EBAB4, false, true)
    RegisterPrompt('Rotate Right', 0xDEB34313, false, true)
end)

local function RequestAndLoadModel(model)
    RequestModel(model)
    local timeout = 10000
    local waited = 0
    while not HasModelLoaded(model) do
        Wait(50)
        waited = waited + 50
        if waited >= timeout then
            print('[ds-propplacer] Model load timeout:', model)
            return false
        end
    end
    return true
end

function PropPlacer(proptype, ObjectModel)
    local myPed = PlayerPedId()
    local pHead = GetEntityHeading(myPed)
    local pos = GetEntityCoords(myPed)
    local PropHash = GetHashKey(ObjectModel)
    local coords = GetEntityCoords(myPed)
    local _x, _y, _z = table.unpack(coords)
    local forward = GetEntityForwardVector(myPed)
    local x, y, z = table.unpack(pos - forward * -2.0)
    local ox, oy, oz = x - _x, y - _y, z - _z
    local heading = 0.0

    SetCurrentPedWeapon(myPed, -1569615261, true)
    if not RequestAndLoadModel(PropHash) then
        exports['ox_lib']:notify({title = 'Could not load model: '..ObjectModel, type = 'error', duration = 5000})
        return
    end

    local tempObj = CreateObject(PropHash, pos.x, pos.y, pos.z, false, false, false)
    local tempObj2 = CreateObject(PropHash, pos.x, pos.y, pos.z, false, false, false)
    AttachEntityToEntity(tempObj2, myPed, 0, ox, oy, 0.5, 0.0, 0.0, 0, true, false, false, false, false)
    SetEntityAlpha(tempObj, 180)
    SetEntityAlpha(tempObj2, 0)

    while true do
        Wait(5)
        local PropPlacerGroupName = CreateVarString(10, 'LITERAL_STRING', "PropPlacer")
        PromptSetActiveGroupThisFrame(PromptPlacerGroup, PropPlacerGroupName)
        AttachEntityToEntity(tempObj, myPed, 0, ox, oy, -0.8, 0.0, 0.0, heading, true, false, false, false, false)

        if IsControlPressed(1, 0xA65EBAB4) then
            heading = heading - 1
        end
        if IsControlPressed(1, 0xDEB34313) then
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
        end

        if PromptHasHoldModeCompleted(CancelPrompt) then
            DeleteEntity(tempObj2)
            DeleteEntity(tempObj)
            SetModelAsNoLongerNeeded(PropHash)
            break
        end
    end
end

RegisterNetEvent('ds-propplacer:client:propPlaced', function(propId)
    exports['ox_lib']:notify({title = 'Prop placed! ID: '..tostring(propId), type = 'success', duration = 7000})
end)
--------------------------------------------------------
--place prop command
--------------------------------------------------------
RegisterCommand('placeprop', function(_, args)
    local proptype = args[1] or 'default'
    local model = args[2]
    if not model then
        exports['ox_lib']:notify({title = 'Usage: /placeprop [type] [model]', type = 'error', duration = 5000})
        return
    end
    PropPlacer(proptype, model)
end)
--------------------------------------------------------
--remove prop command
--------------------------------------------------------
RegisterCommand('removeprop', function(source, args, rawCommand)
    local propid = args[1]
    if propid then
        TriggerServerEvent('ds-propplacer:server:removeProp', propid)
    else
        exports['ox_lib']:notify({title = 'Usage: /removeprop [propid]', type = 'error', duration = 5000})
    end
end)
--------------------------------------------------------
--list props command
--------------------------------------------------------
RegisterCommand('listprops', function()
    for id, propData in pairs(Props) do
        print('Prop ID:', id, 'Type:', propData.proptype, 'Model:', propData.hash or propData.model)
    end
end)

RegisterNetEvent('ds-propplacer:client:updatePropData', function(props)
    Props = props
    for id, obj in pairs(SpawnedProps) do
        if DoesEntityExist(obj) then
            DeleteEntity(obj)
        end
        SpawnedProps[id] = nil
    end
    for id, propData in pairs(Props) do
        if type(propData) == "boolean" then goto continue end
        local model = propData.hash or propData.model
        if model and RequestAndLoadModel(model) then
            local groundZ = propData.z
            local found, z = GetGroundZFor_3dCoord(propData.x, propData.y, propData.z)
            if found then groundZ = z end
            local obj = CreateObject(model, propData.x, propData.y, groundZ, false, false, false)
            SetEntityHeading(obj, propData.h or 0.0)
            SpawnedProps[id] = obj
        end
        ::continue::
    end
end)

RegisterNetEvent('ds-propplacer:client:removePropObject', function(propid)
    Props[propid] = nil
    if SpawnedProps[propid] and DoesEntityExist(SpawnedProps[propid]) then
        DeleteEntity(SpawnedProps[propid])
        SpawnedProps[propid] = nil
    end
end)
