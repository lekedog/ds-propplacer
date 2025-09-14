local RSGCore = exports['rsg-core']:GetCoreObject()
local Props = {}
local SpawnedProps = {}
local AllProps = {}
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
    print('[ds-propplacer] Remove prop command called with propid:', propid)
    if propid then
        TriggerServerEvent('ds-propplacer:server:removeProp', tonumber(propid))
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
    -- Build new AllProps table
    local newProps = {}
    local newPropIds = {}
    for id, propData in pairs(props) do
        if type(propData) == "boolean" then goto continue end
        propData.id = id
        newProps[#newProps + 1] = propData
        newPropIds[tostring(id)] = true
        ::continue::
    end

    -- Remove any spawned props that are no longer present
    for id, p in pairs(SpawnedProps) do
        if not newPropIds[tostring(id)] then
            if DoesEntityExist(p.obj) then
                DeleteEntity(p.obj)
            end
            SpawnedProps[id] = nil
        end
    end

    AllProps = newProps
end)

CreateThread(function()
    while true do
        Wait(150)
        local pos = GetEntityCoords(PlayerPedId())
        local InRange = false
        for i = 1, #AllProps do
            local prop = vector3(AllProps[i].x, AllProps[i].y, AllProps[i].z)
            local dist = #(pos - prop)
            if dist >= 50.0 then goto continue end
            local id = tostring(AllProps[i].id)
            if SpawnedProps[id] then goto continue end
            InRange = true
            local modelHash = AllProps[i].hash
            if not modelHash then goto continue end
            RequestAndLoadModel(modelHash)
            local data = {}
            local groundZ = AllProps[i].z
            local found, z = GetGroundZFor_3dCoord(AllProps[i].x, AllProps[i].y, AllProps[i].z)
            local attempts = 0
            while not found and attempts < 200 do -- up to 10 seconds
                Wait(50)
                found, z = GetGroundZFor_3dCoord(AllProps[i].x, AllProps[i].y, AllProps[i].z)
                attempts = attempts + 1
            end
            if found then groundZ = z end
            data.obj = CreateObject(modelHash, AllProps[i].x, AllProps[i].y, groundZ, false, false, false)
            SetEntityHeading(data.obj, AllProps[i].h or 0.0)
            SetEntityAsMissionEntity(data.obj, true)
            Wait(1000)
            FreezeEntityPosition(data.obj, true)
            SetModelAsNoLongerNeeded(data.obj)
            data.id = AllProps[i].id
            SpawnedProps[id] = data
            ::continue::
        end
        if not InRange then
            Wait(5000)
        end
    end
end)

RegisterNetEvent('ds-propplacer:client:removePropObject', function(propid)
    print('[ds-propplacer] Client removePropObject called with propid:', propid)
    local id = tostring(propid)
    local p = SpawnedProps[id]
    if p and DoesEntityExist(p.obj) then
        DeleteEntity(p.obj)
    end
    SpawnedProps[id] = nil
    exports['ox_lib']:notify({title = 'Prop removed successfully!', type = 'success', duration = 5000})
end)
