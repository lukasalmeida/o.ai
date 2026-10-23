local Config = Config

local currentCamera = nil
local currentPed = nil
local isInCharacterSelection = false
local isInCreation = false
local currentViewMode = 'body'
local rotationAngle = 0.0
local zoomLevel = 1.0

local function Log(msg)
    Config.Log(msg)
end

local function CreateCamera(coords, rotation, fov)
    if currentCamera then
        DestroyCam(currentCamera, false)
    end

    currentCamera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(currentCamera, coords.x, coords.y, coords.z)
    SetCamRot(currentCamera, rotation.x, rotation.y, rotation.z, 2)
    SetCamFov(currentCamera, fov)
    RenderScriptCams(true, false, 0, true, true)

    return currentCamera
end

local function TransitionCamera(newCoords, newRotation, newFov, duration)
    if not currentCamera then return end

    local startTime = GetGameTimer()
    local startCoords = GetCamCoord(currentCamera)
    local startRot = GetCamRot(currentCamera, 2)
    local startFov = GetCamFov(currentCamera)

    CreateThread(function()
        while GetGameTimer() - startTime < duration do
            local progress = (GetGameTimer() - startTime) / duration
            local eased = 1 - math.pow(1 - progress, 3)

            local x = startCoords.x + (newCoords.x - startCoords.x) * eased
            local y = startCoords.y + (newCoords.y - startCoords.y) * eased
            local z = startCoords.z + (newCoords.z - startCoords.z) * eased

            local rx = startRot.x + (newRotation.x - startRot.x) * eased
            local ry = startRot.y + (newRotation.y - startRot.y) * eased
            local rz = startRot.z + (newRotation.z - startRot.z) * eased

            local fov = startFov + (newFov - startFov) * eased

            SetCamCoord(currentCamera, x, y, z)
            SetCamRot(currentCamera, rx, ry, rz, 2)
            SetCamFov(currentCamera, fov)

            Wait(0)
        end

        SetCamCoord(currentCamera, newCoords.x, newCoords.y, newCoords.z)
        SetCamRot(currentCamera, newRotation.x, newRotation.y, newRotation.z, 2)
        SetCamFov(currentCamera, newFov)
    end)
end

local function DestroyCamera()
    if currentCamera then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(currentCamera, false)
        currentCamera = nil
    end
end

local function CreatePedForSelection(model, coords, heading)
    if currentPed then
        DeleteEntity(currentPed)
    end

    local modelHash = type(model) == 'string' and GetHashKey(model) or model
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do Wait(10) end

    currentPed = CreatePed(4, modelHash, coords.x, coords.y, coords.z, heading, false, true)
    SetEntityInvincible(currentPed, true)
    SetEntityVisible(currentPed, true)
    FreezeEntityPosition(currentPed, true)
    SetBlockingOfNonTemporaryEvents(currentPed, true)
    SetPedCanBeTargetted(currentPed, false)

    return currentPed
end

local function ApplySkinToPed(ped, skin)
    if not skin then return end

    if skin.model then
        local modelHash = GetHashKey(skin.model)
        if IsModelInCdimage(modelHash) then
            SetEntityModel(ped, modelHash)
            Wait(100)
        end
    end

    if skin.face then
        SetPedHeadBlendData(ped,
            skin.face.mom or 21, skin.face.dad or 23, 0,
            skin.face.mom or 21, skin.face.dad or 23, 0,
            skin.face.shapeMix or 0.5, skin.face.skinMix or 0.5, 0.0, false)

        if skin.face.eyes then SetPedEyeColor(ped, skin.face.eyes) end
    end

    if skin.hair then
        SetPedComponentVariation(ped, 2, skin.hair.style or 0, 0, 2)
        SetPedHairColor(ped, skin.hair.color or 0, skin.hair.highlight or 0)
    end

    if skin.facialHair then
        SetPedHeadOverlay(ped, 1, skin.facialHair.style or 0, skin.facialHair.opacity or 0.0)
        SetPedHeadOverlayColor(ped, 1, 1, skin.facialHair.color or 0, 0)
    end

    if skin.eyebrows then
        SetPedHeadOverlay(ped, 2, skin.eyebrows.style or 0, skin.eyebrows.opacity or 1.0)
        SetPedHeadOverlayColor(ped, 2, 1, skin.eyebrows.color or 0, 0)
    end

    if skin.makeup then
        if type(skin.makeup.blush) == 'table' then
            SetPedHeadOverlay(ped, 5, skin.makeup.blush.style or 0, skin.makeup.blush.opacity or 0.0)
            SetPedHeadOverlayColor(ped, 5, 2, skin.makeup.blush.color or 0, 0)
        elseif skin.makeup.blush and skin.makeup.blush ~= 0 then
            SetPedHeadOverlay(ped, 5, skin.makeup.blush, 1.0)
        end
        if type(skin.makeup.lipstick) == 'table' then
            SetPedHeadOverlay(ped, 8, skin.makeup.lipstick.style or 0, skin.makeup.lipstick.opacity or 0.0)
            SetPedHeadOverlayColor(ped, 8, 2, skin.makeup.lipstick.color or 0, 0)
        elseif skin.makeup.lipstick and skin.makeup.lipstick ~= 0 then
            SetPedHeadOverlay(ped, 8, skin.makeup.lipstick, 1.0)
        end
    end

    if skin.age then SetPedHeadOverlay(ped, 3, skin.age, 1.0) end
    if skin.blemishes then SetPedHeadOverlay(ped, 0, skin.blemishes, 1.0) end
    if skin.complexion then SetPedHeadOverlay(ped, 6, skin.complexion, 1.0) end
    if skin.sunDamage then SetPedHeadOverlay(ped, 7, skin.sunDamage, 1.0) end

    if skin.clothes then
        for component, data in pairs(skin.clothes) do
            local compId = GetPedComponentId(component)
            if compId >= 0 then
                SetPedComponentVariation(ped, compId, data.drawable or 0, data.texture or 0, 2)
            end
        end
    end

    if skin.props then
        for prop, data in pairs(skin.props) do
            local propId = GetPedPropId(prop)
            if propId >= 0 then
                if data.drawable == -1 then
                    ClearPedProp(ped, propId)
                else
                    SetPedPropIndex(ped, propId, data.drawable, data.texture, true)
                end
            end
        end
    end
end

local function GetPedSkin(ped)
    local skin = {
        model = GetEntityModel(ped),
        face = {},
        hair = {},
        facialHair = {},
        eyebrows = {},
        makeup = {},
        clothes = {},
        props = {}
    }

    local mom, dad, shapeMix, skinMix = 0, 0, 0.5, 0.5
    -- Note: Getting head blend data back is limited in FiveM

    for i = 0, 11 do
        local drawable = GetPedDrawableVariation(ped, i)
        local texture = GetPedTextureVariation(ped, i)
        if drawable > 0 then
            skin.clothes[GetComponentName(i)] = { drawable = drawable, texture = texture }
        end
    end

    for i = 0, 7 do
        local drawable = GetPedPropIndex(ped, i)
        local texture = GetPedPropTextureIndex(ped, i)
        if drawable >= 0 then
            skin.props[GetPropName(i)] = { drawable = drawable, texture = texture }
        end
    end

    return skin
end

local function GetComponentName(id)
    local names = {
        [0] = 'hat', [1] = 'mask', [2] = 'hair', [3] = 'torso', [4] = 'legs',
        [5] = 'bags', [6] = 'shoes', [7] = 'accessories', [8] = 'undershirt',
        [9] = 'armor', [10] = 'decals', [11] = 'tops'
    }
    return names[id] or 'comp_' .. id
end

local function GetPropName(id)
    local names = {
        [0] = 'hat', [1] = 'glasses', [2] = 'ears', [6] = 'watch', [7] = 'bracelet'
    }
    return names[id] or 'prop_' .. id
end

local function GetPedComponentId(name)
    if type(name) == 'number' then return name end
    local map = {
        hat = 0, mask = 1, hair = 2, torso = 3, legs = 4, bags = 5, shoes = 6,
        accessories = 7, undershirt = 8, armor = 9, decals = 10, tops = 11,
        -- StartingClothes keys
        tshirt_1 = 8, tshirt_2 = 8, torso_1 = 11, torso_2 = 11, decals_1 = 10, decals_2 = 10,
        arms = 3, arms_2 = 3, pants_1 = 4, pants_2 = 4, shoes_1 = 6, shoes_2 = 6,
        helmet_1 = 0, helmet_2 = 0, glasses_1 = 7, glasses_2 = 7, ears_1 = 7, ears_2 = 7,
        mask_1 = 1, mask_2 = 1, bags_1 = 5, bags_2 = 5, chain_1 = 7, chain_2 = 7,
        bracelets_1 = 7, bracelets_2 = 7
    }
    return map[name] or -1
end

local function GetPedPropId(name)
    if type(name) == 'number' then return name end
    local map = {
        hat = 0, glasses = 1, ears = 2, watch = 6, bracelet = 7
    }
    return map[name] or -1
end

local function SetRoutingBucket(bucket)
    TriggerServerEvent('multicharacter:server:SetRoutingBucket', bucket)
end

local function SetEntityRoutingBucket(entity, bucket)
    SetEntityRoutingBucket(entity, bucket)
end

local function ShowNUI(state, data)
    SetNuiFocus(state, state)
    SendNUIMessage({
        action = state and 'show' or 'hide',
        data = data
    })
    isInCharacterSelection = state
end

RegisterNetEvent('multicharacter:client:ReceiveCharacters')
AddEventHandler('multicharacter:client:ReceiveCharacters', function(characters)
    Log('Received ' .. #characters .. ' characters')
    ShowNUI(true, {
        type = 'selection',
        characters = characters,
        maxSlots = Config.MaxCharacters,
        theme = Config.Theme
    })

    local camData = Config.CameraLocations.characterSelection
    CreateCamera(camData.coords, camData.rotation, camData.fov)
    SetRoutingBucket(1)

    local previewPed = CreatePedForSelection(
        characters[1] and characters[1].model or 'mp_m_freemode_01',
        vector3(camData.coords.x, camData.coords.y + 1.5, camData.coords.z - 1.0),
        180.0
    )

    if characters[1] and characters[1].skin then
        ApplySkinToPed(previewPed, characters[1].skin)
    end
end)

RegisterNetEvent('multicharacter:client:CreationResponse')
AddEventHandler('multicharacter:client:CreationResponse', function(success, message, character)
    if success then
        ShowNUI(false)
        TriggerEvent('multicharacter:client:SpawnCharacter', character)
    else
        SendNUIMessage({
            action = 'creationError',
            message = message
        })
    end
end)

RegisterNetEvent('multicharacter:client:SpawnCharacter')
AddEventHandler('multicharacter:client:SpawnCharacter', function(character)
    print('[MULTICHAR] SpawnCharacter event received')
    ShowNUI(false)
    DestroyCamera()
    SetRoutingBucket(0)

    if not character then
        print('[MULTICHAR] character nil')
        Config.Log('SpawnCharacter: character nil')
        return
    end
    print('[MULTICHAR] character id=' .. tostring(character.id) .. ' model=' .. tostring(character.model))

    Log('Spawning character: ' .. character.firstname .. ' ' .. character.lastname)

    ShowNUI(false)
    DestroyCamera()
    SetRoutingBucket(0)

    local playerPed = PlayerPedId()
    local model = character.model

    if type(model) == 'string' then model = GetHashKey(model) end
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end

    SetPlayerModel(PlayerId(), model)
    playerPed = PlayerPedId()

    Wait(500)

    if character.skin then
        ApplySkinToPed(playerPed, character.skin)
    end

    local spawnPos = character.position
    local sx, sy, sz, sh = nil, nil, nil, nil
    if type(spawnPos) == 'vector4' then
        sx, sy, sz, sh = spawnPos.x, spawnPos.y, spawnPos.z, spawnPos.w
    elseif type(spawnPos) == 'table' then
        sx, sy, sz = spawnPos.x, spawnPos.y, spawnPos.z
        sh = spawnPos.w or spawnPos.heading or spawnPos.h
    end

    if not sx or not sy or not sz then
        sx, sy, sz, sh = Config.DefaultSpawn.coords.x, Config.DefaultSpawn.coords.y, Config.DefaultSpawn.coords.z, Config.DefaultSpawn.coords.w
    end

    SetEntityCoords(playerPed, sx, sy, sz, false, false, false, true)
    SetEntityHeading(playerPed, sh or 0.0)

    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    SetEntityVisible(playerPed, true)
    FreezeEntityPosition(playerPed, false)
    SetEntityInvincible(playerPed, false)

    TriggerEvent('multicharacter:onCharacterSpawned', character)
    TriggerServerEvent('multicharacter:server:CharacterSpawned', character.id)
end)

RegisterNetEvent('multicharacter:client:DeletionResponse')
AddEventHandler('multicharacter:client:DeletionResponse', function(success)
    SendNUIMessage({
        action = 'deletionResponse',
        success = success
    })

    if success then
        TriggerServerEvent('multicharacter:server:GetCharacters')
    end
end)

RegisterNUICallback('selectCharacter', function(data, cb)
    print('[MULTICHAR] selectCharacter NUI callback, charId=' .. tostring(data.charId))
    TriggerServerEvent('multicharacter:server:SelectCharacter', data.charId)
    cb('ok')
end)

RegisterNUICallback('createNewCharacter', function(data, cb)
    isInCreation = true
    ShowNUI(true, {
        type = 'creation',
        step = 'identity',
        theme = Config.Theme
    })

    local camData = Config.CameraLocations.creation
    TransitionCamera(camData.coords, camData.rotation, camData.fov, Config.AnimationDurations.cameraTransition)

    local model = data.sex == 'F' and 'mp_f_freemode_01' or 'mp_m_freemode_01'
    local ped = CreatePedForSelection(model,
        vector3(camData.coords.x, camData.coords.y + 2.0, camData.coords.z - 1.0),
        180.0
    )

    if Config.StartingClothes[data.sex == 'F' and 'female' or 'male'] then
        local clothes = Config.StartingClothes[data.sex == 'F' and 'female' or 'male']
        for comp, val in pairs(clothes) do
            local compId = GetPedComponentId(comp)
            if compId >= 0 then
                SetPedComponentVariation(ped, compId, val, 0, 2)
            end
        end
    end

    cb('ok')
end)

RegisterNUICallback('submitIdentity', function(data, cb)
    if not data.firstname or not data.lastname or not data.age or not data.sex then
        cb({ success = false, message = 'Preencha todos os campos' })
        return
    end

    if string.len(data.firstname) < Config.Validation.minNameLength or string.len(data.firstname) > Config.Validation.maxNameLength then
        cb({ success = false, message = 'Nome deve ter entre 2 e 20 caracteres' })
        return
    end

    if string.len(data.lastname) < Config.Validation.minNameLength or string.len(data.lastname) > Config.Validation.maxNameLength then
        cb({ success = false, message = 'Sobrenome deve ter entre 2 e 20 caracteres' })
        return
    end

    if not string.match(data.firstname, Config.Validation.allowedChars) or not string.match(data.lastname, Config.Validation.allowedChars) then
        cb({ success = false, message = 'Apenas letras, espaços e hífens são permitidos' })
        return
    end

    local age = tonumber(data.age)
    if not age or age < Config.Validation.minAge or age > Config.Validation.maxAge then
        cb({ success = false, message = 'Idade deve ser entre 18 e 100 anos' })
        return
    end

    if data.sex ~= 'M' and data.sex ~= 'F' then
        cb({ success = false, message = 'Sexo inválido' })
        return
    end

    ShowNUI(true, {
        type = 'creation',
        step = 'customization',
        identity = data,
        theme = Config.Theme
    })

    local camData = Config.CameraLocations.customization.face
    TransitionCamera(camData.coords, camData.rotation, camData.fov, Config.AnimationDurations.cameraTransition)

    cb({ success = true })
end)

RegisterNUICallback('changeViewMode', function(data, cb)
    currentViewMode = data.mode
    local camData = Config.CameraLocations.customization[data.mode] or Config.CameraLocations.customization.body
    TransitionCamera(camData.coords, camData.rotation, camData.fov, 500)
    cb('ok')
end)

RegisterNUICallback('rotatePed', function(data, cb)
    if currentPed then
        rotationAngle = rotationAngle + (data.direction == 'left' and 15.0 or -15.0)
        SetEntityHeading(currentPed, rotationAngle)
    end
    cb('ok')
end)

RegisterNUICallback('updateSkin', function(data, cb)
    if currentPed then
        local skin = json.decode(data.skin) or {}
        ApplySkinToPed(currentPed, skin)
    end
    cb('ok')
end)

RegisterNUICallback('finishCreation', function(data, cb)
    local skin = {}
    if data.skin then skin = json.decode(data.skin) or {} end
    local identity = data.identity or {}

    if not identity.firstname or not identity.lastname then
        -- try to fallback from form not available; abort
        cb({ success = false, message = 'Dados de identidade ausentes' })
        return
    end

    skin.model = identity.sex == 'F' and 'mp_f_freemode_01' or 'mp_m_freemode_01'

    local sp = Config.DefaultSpawn.coords
    TriggerServerEvent('multicharacter:server:CreateCharacter', {
        firstname = identity.firstname,
        lastname = identity.lastname,
        age = identity.age,
        sex = identity.sex,
        skin = skin,
        position = { x = sp.x, y = sp.y, z = sp.z, w = sp.w }
    })

    cb('ok')
end)

RegisterNUICallback('deleteCharacter', function(data, cb)
    TriggerServerEvent('multicharacter:server:DeleteCharacter', data.charId)
    cb('ok')
end)

RegisterNUICallback('previewCharacter', function(data, cb)
    if currentPed and data.skin then
        ApplySkinToPed(currentPed, data.skin)
    end
    cb('ok')
end)

RegisterNUICallback('closeUI', function(data, cb)
    ShowNUI(false)
    DestroyCamera()
    SetRoutingBucket(0)
    if currentPed then
        DeleteEntity(currentPed)
        currentPed = nil
    end
    cb('ok')
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        Wait(1000)
        SetRoutingBucket(1)
        TriggerServerEvent('multicharacter:server:GetCharacters')
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        ShowNUI(false)
        DestroyCamera()
        SetRoutingBucket(0)
        if currentPed then
            DeleteEntity(currentPed)
        end
    end
end)

RegisterCommand('opencharmenu', function()
    TriggerServerEvent('multicharacter:server:GetCharacters')
end, false)

RegisterKeyMapping('opencharmenu', 'Abrir Menu de Personagens', 'keyboard', 'F10')