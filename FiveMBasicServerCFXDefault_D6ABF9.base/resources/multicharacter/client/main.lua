local inLobby = false
local isSpawning = false
local currentPed = nil
local lobbyCam = nil
local characters = {}
local maxSlots = 3
local currentCharId = nil
local creatingCharId = nil
local appearanceMode = false

local Appearance = nil

-- =====================
-- UTILS
-- =====================
local function LoadModel(model)
    if type(model) ~= 'string' then return end
    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) and timeout < 1000 do
        Wait(10)
        timeout = timeout + 10
    end
end

local function DeleteCurrentPed()
    if currentPed and DoesEntityExist(currentPed) then
        DeleteEntity(currentPed)
    end
    currentPed = nil
end

local function Clamp(v, min, max)
    if v < min then return min end
    if v > max then return max end
    return v
end

-- =====================
-- APPEARANCE DEFAULTS
-- =====================
local function DefaultAppearance(sex)
    local model = (sex == 'female') and Config.Models.female or Config.Models.male
    local app = {
        model = model,
        sex = sex or 'male',
        headBlend = {
            shapeFirst = 0, shapeSecond = 0, skinFirst = 0, skinSecond = 0,
            shapeMix = 0.5, skinMix = 0.5
        },
        faceFeatures = {},
        hair = { style = 0, color = 0, highlight = 0 },
        eyebrows = { style = 0, color = 0, opacity = 1.0 },
        beard = { style = -1, color = 0, opacity = 1.0 },
        components = {
            [3] = { drawable = 0, texture = 0 },  -- torso
            [4] = { drawable = 0, texture = 0 },  -- legs
            [5] = { drawable = 0, texture = 0 },  -- bags
            [6] = { drawable = 0, texture = 0 },  -- shoes
            [7] = { drawable = 0, texture = 0 },  -- accessories
            [8] = { drawable = 0, texture = 0 },  -- undershirt
            [9] = { drawable = 0, texture = 0 },  -- armor
            [11] = { drawable = 0, texture = 0 } -- tops
        },
        props = {
            [0] = { drawable = -1, texture = 0 }, -- hat
            [1] = { drawable = -1, texture = 0 }, -- glasses
            [2] = { drawable = -1, texture = 0 }, -- ears
            [6] = { drawable = -1, texture = 0 }, -- watch
            [7] = { drawable = -1, texture = 0 }  -- bracelet
        }
    }
    for i = 0, 19 do
        app.faceFeatures[i] = 0.0
    end
    if sex == 'female' then
        app.beard.style = -1
    end
    return app
end

-- =====================
-- APPLY APPEARANCE
-- =====================
function ApplyAppearance(ped, a)
    if not ped or not DoesEntityExist(ped) or not a then return end

    -- head blend
    local hb = a.headBlend
    SetPedHeadBlendData(ped,
        hb.shapeFirst or 0, hb.shapeSecond or 0, 0,
        hb.skinFirst or 0, hb.skinSecond or 0, 0,
        hb.shapeMix or 0.5, hb.skinMix or 0.5, 0.0
    )

    -- face features
    for i = 0, 19 do
        SetPedFaceFeature(ped, i, (a.faceFeatures and a.faceFeatures[i]) or 0.0)
    end

    -- hair
    SetPedComponentVariation(ped, 2, (a.hair and a.hair.style) or 0, 0, 0)
    SetPedHairColor(ped, (a.hair and a.hair.color) or 0, (a.hair and a.hair.highlight) or 0)

    -- eyebrows (overlay 2)
    if a.eyebrows then
        SetPedHeadOverlay(ped, 2, a.eyebrows.style or 0, a.eyebrows.opacity or 1.0)
        SetPedHeadOverlayColor(ped, 2, 1, a.eyebrows.color or 0, a.eyebrows.color or 0)
    end

    -- beard (overlay 1)
    if a.beard then
        if (a.beard.style or -1) >= 0 then
            SetPedHeadOverlay(ped, 1, a.beard.style, a.beard.opacity or 1.0)
            SetPedHeadOverlayColor(ped, 1, 1, a.beard.color or 0, a.beard.color or 0)
        else
            SetPedHeadOverlay(ped, 1, 255, 0.0)
        end
    end

    -- components
    if a.components then
        for comp, data in pairs(a.components) do
            SetPedComponentVariation(ped, comp, data.drawable or 0, data.texture or 0, 0)
        end
    end

    -- props
    if a.props then
        for prop, data in pairs(a.props) do
            if (data.drawable or -1) == -1 then
                ClearPedProp(ped, prop)
            else
                SetPedPropIndex(ped, prop, data.drawable, data.texture or 0, true)
            end
        end
    end
end

-- =====================
-- SPAWN LOBBY PED
-- =====================
local function SpawnLobbyPed(model, skin)
    DeleteCurrentPed()
    LoadModel(model)
    local c = Config.Lobby.ped
    currentPed = CreatePed(4, model, c.x, c.y, c.z - 1.0, c.w, false, true)
    SetEntityInvincible(currentPed, true)
    FreezeEntityPosition(currentPed, true)
    SetBlockingOfNonTemporaryEvents(currentPed, true)
    SetPedDefaultComponentVariation(currentPed)
    if skin then
        -- ensure model matches skin model
        ApplyAppearance(currentPed, skin)
    end
    SetModelAsNoLongerNeeded(model)
end

-- =====================
-- CAMERA
-- =====================
local camFocusMode = 'body'

local function GetPedCenter(ped)
    return GetEntityCoords(ped)
end

local function UpdateCamFocus()
    if not lobbyCam or not currentPed or not DoesEntityExist(currentPed) then return end
    local pedPos = GetEntityCoords(currentPed)
    local fwd = GetEntityForwardVector(currentPed)
    local dist, height, lookH
    if camFocusMode == 'face' then
        dist = 0.9; height = 0.55; lookH = 0.62
    elseif camFocusMode == 'body' then
        dist = 2.0; height = 0.15; lookH = 0.45
    elseif camFocusMode == 'feet' then
        dist = 1.6; height = -0.55; lookH = -0.25
    else
        dist = 2.0; height = 0.15; lookH = 0.45
    end
    local camPos = vector3(pedPos.x + fwd.x * dist, pedPos.y + fwd.y * dist, pedPos.z + height)
    SetCamCoord(lobbyCam, camPos.x, camPos.y, camPos.z)
    PointCamAtCoord(lobbyCam, pedPos.x, pedPos.y, pedPos.z + lookH)
end

local function CreateLobbyCam()
    lobbyCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    local p = Config.Lobby.ped
    SetCamCoord(lobbyCam, p.x, p.y + 2.0, p.z + 0.6)
    PointCamAtCoord(lobbyCam, p.x, p.y, p.z + 0.5)
    SetCamFov(lobbyCam, Config.Lobby.fov or 38.0)
    SetCamActive(lobbyCam, true)
    local ok, err = pcall(function()
        RenderScriptCams(true, false, 0, true, true)
    end)
    if not ok then print('[MULTICHAR] RenderScriptCams true error: ' .. tostring(err)) end
    UpdateCamFocus()
end

local function DestroyCam()
    if lobbyCam then
        local cam = lobbyCam
        lobbyCam = nil
        CreateThread(function()
            Wait(0)
            SetCamActive(cam, false)
            Wait(0)
            DestroyCam(cam, false)
            Wait(0)
            RenderScriptCams(false, false, 0, true, true)
        end)
    end
end

-- =====================
-- LOBBY OPEN
-- =====================
local function EnterLobby()
    inLobby = true
    appearanceMode = false
    local ped = PlayerPedId()
    SetEntityVisible(ped, false)
    FreezeEntityPosition(ped, true)
    SetPlayerControl(PlayerId(), false, 0)

    -- bucket privado
    TriggerServerEvent('multichar:server:setBucket', Config.LobbyBucket)

    CreateLobbyCam()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openLobby', data = { characters = characters, maxSlots = maxSlots } })
end

local function LeaveLobbyToCity(char)
    inLobby = false
    appearanceMode = false
    DestroyCam()
    DeleteCurrentPed()

    local model = (char.skin and char.skin.model) or Config.Models.male
    LoadModel(model)
    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)
    Wait(100)
    local ped = PlayerPedId()
    ApplyAppearance(ped, char.skin or DefaultAppearance('male'))
    SetEntityVisible(ped, true)
    FreezeEntityPosition(ped, false)
    SetPlayerControl(PlayerId(), true, 0)

    local pos = char.position
    local sx, sy, sz, sh = nil, nil, nil, nil
    if type(pos) == 'vector4' then
        sx, sy, sz, sh = pos.x, pos.y, pos.z, pos.w
    elseif type(pos) == 'table' then
        sx, sy, sz = pos.x, pos.y, pos.z
        sh = pos.w or pos[4]
    end
    if not sx or not sy or not sz then
        sx, sy, sz, sh = Config.DefaultSpawn.x, Config.DefaultSpawn.y, Config.DefaultSpawn.z, Config.DefaultSpawn.w
    end
    SetEntityCoords(ped, sx, sy, sz, false, false, false, true)
    SetEntityHeading(ped, sh or 0.0)

    TriggerServerEvent('multichar:server:setBucket', 0)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })

    currentCharId = char.id

    -- save position loop
    CreateThread(function()
        while currentCharId do
            Wait(60000)
            if currentCharId then
                local c = GetEntityCoords(PlayerPedId())
                local h = GetEntityHeading(PlayerPedId())
                TriggerServerEvent('multichar:server:savePosition', currentCharId, { x = c.x, y = c.y, z = c.z, w = h })
            end
        end
    end)
end

-- =====================
-- MODIFY APPEARANCE
-- =====================
local function ModifyAppearance(part, delta)
    if not Appearance then return end
    delta = delta or 0

    -- headBlend
    if part == 'hb_shapeFirst' then
        Appearance.headBlend.shapeFirst = Clamp(Appearance.headBlend.shapeFirst + delta, 0, 45)
    elseif part == 'hb_shapeSecond' then
        Appearance.headBlend.shapeSecond = Clamp(Appearance.headBlend.shapeSecond + delta, 0, 45)
    elseif part == 'hb_skinFirst' then
        Appearance.headBlend.skinFirst = Clamp(Appearance.headBlend.skinFirst + delta, 0, 45)
    elseif part == 'hb_skinSecond' then
        Appearance.headBlend.skinSecond = Clamp(Appearance.headBlend.skinSecond + delta, 0, 45)
    elseif part == 'hb_shapeMix' then
        Appearance.headBlend.shapeMix = Clamp(Appearance.headBlend.shapeMix + delta, 0.0, 1.0)
    elseif part == 'hb_skinMix' then
        Appearance.headBlend.skinMix = Clamp(Appearance.headBlend.skinMix + delta, 0.0, 1.0)

    -- face features
    elseif part:match('^ff_(%d+)$') then
        local idx = tonumber(part:match('^ff_(%d+)$'))
        if idx then
            Appearance.faceFeatures[idx] = Clamp((Appearance.faceFeatures[idx] or 0.0) + delta, -1.0, 1.0)
        end

    -- hair
    elseif part == 'hair_style' then
        local max = GetNumberOfPedDrawableVariations(currentPed, 2) - 1
        if max < 0 then max = 0 end
        local v = Appearance.hair.style + delta
        if v < 0 then v = max elseif v > max then v = 0 end
        Appearance.hair.style = v
    elseif part == 'hair_color' then
        Appearance.hair.color = Clamp(Appearance.hair.color + delta, 0, 63)
    elseif part == 'hair_highlight' then
        Appearance.hair.highlight = Clamp(Appearance.hair.highlight + delta, 0, 63)

    -- eyebrows
    elseif part == 'eb_style' then
        local max = 33
        local v = Appearance.eyebrows.style + delta
        if v < 0 then v = max elseif v > max then v = 0 end
        Appearance.eyebrows.style = v
    elseif part == 'eb_color' then
        Appearance.eyebrows.color = Clamp(Appearance.eyebrows.color + delta, 0, 63)
    elseif part == 'eb_opacity' then
        Appearance.eyebrows.opacity = Clamp(Appearance.eyebrows.opacity + delta, 0.0, 1.0)

    -- beard
    elseif part == 'beard_style' then
        local max = 28
        local v = Appearance.beard.style + delta
        if Appearance.beard.style == -1 and delta > 0 then v = 0 end
        if v > max then v = -1 end
        if v < -1 then v = max end
        Appearance.beard.style = v
    elseif part == 'beard_color' then
        Appearance.beard.color = Clamp(Appearance.beard.color + delta, 0, 63)
    elseif part == 'beard_opacity' then
        Appearance.beard.opacity = Clamp(Appearance.beard.opacity + delta, 0.0, 1.0)

    -- components
    elseif part:match('^comp_(%d+)$') then
        local comp = tonumber(part:match('^comp_(%d+)$'))
        if comp and Appearance.components[comp] then
            local d = Appearance.components[comp]
            local max = GetNumberOfPedDrawableVariations(currentPed, comp) - 1
            if max < 0 then max = 0 end
            local v = d.drawable + delta
            if v < 0 then v = max elseif v > max then v = 0 end
            d.drawable = v
            d.texture = 0
        end
    elseif part:match('^comp_(%d+)_tex$') then
        local comp = tonumber(part:match('^comp_(%d+)_tex$'))
        if comp and Appearance.components[comp] then
            local d = Appearance.components[comp]
            local max = GetNumberOfPedTextureVariations(currentPed, comp, d.drawable) - 1
            if max < 0 then max = 0 end
            local v = d.texture + delta
            if v < 0 then v = max elseif v > max then v = 0 end
            d.texture = v
        end

    -- props
    elseif part:match('^prop_(%d+)$') then
        local prop = tonumber(part:match('^prop_(%d+)$'))
        if prop and Appearance.props[prop] then
            local d = Appearance.props[prop]
            local max = GetNumberOfPedPropDrawableVariations(currentPed, prop) - 1
            if max < 0 then max = -1 end
            local v = d.drawable + delta
            if d.drawable == -1 and delta > 0 then v = 0 end
            if v > max then v = -1 end
            if v < -1 then v = max end
            d.drawable = v
            d.texture = 0
        end
    elseif part:match('^prop_(%d+)_tex$') then
        local prop = tonumber(part:match('^prop_(%d+)_tex$'))
        if prop and Appearance.props[prop] then
            local d = Appearance.props[prop]
            if d.drawable >= 0 then
                local max = GetNumberOfPedPropTextureVariations(currentPed, prop, d.drawable) - 1
                if max < 0 then max = 0 end
                local v = d.texture + delta
                if v < 0 then v = max elseif v > max then v = 0 end
                d.texture = v
            end
        end
    end

    ApplyAppearance(currentPed, Appearance)
    SendNUIMessage({ action = 'appearanceState', data = Appearance })
end

-- =====================
-- NUI CALLBACKS
-- =====================
RegisterNUICallback('close', function(data, cb)
    cb('ok')
end)

RegisterNUICallback('previewCharacter', function(data, cb)
    if data and data.id then
        for _, c in ipairs(characters) do
            if c.id == data.id then
                local model = (c.skin and c.skin.model) or Config.Models.male
                SpawnLobbyPed(model, c.skin)
                SendNUIMessage({ action = 'characterInfo', data = c })
                break
            end
        end
    else
        DeleteCurrentPed()
        SendNUIMessage({ action = 'characterInfo', data = nil })
    end
    cb('ok')
end)

RegisterNUICallback('enterWorld', function(data, cb)
    if isSpawning then cb('ok'); return end
    print('[MULTICHAR] enterWorld id=' .. tostring(data and data.id))
    if data and data.id then
        isSpawning = true
        TriggerServerEvent('multichar:server:selectCharacter', data.id)
    end
    cb('ok')
end)

RegisterNUICallback('createNew', function(data, cb)
    SendNUIMessage({ action = 'openRegister' })
    cb('ok')
end)

RegisterNUICallback('submitRegister', function(data, cb)
    if not data then cb('error'); return end
    local age = tonumber(data.age) or 0
    if age < Config.MinAge then
        SendNUIMessage({ action = 'registerError', data = 'Idade minima: ' .. Config.MinAge .. ' anos.' })
        cb('error')
        return
    end
    if not data.firstname or data.firstname == '' or not data.lastname or data.lastname == '' then
        SendNUIMessage({ action = 'registerError', data = 'Preencha nome e sobrenome.' })
        cb('error')
        return
    end
    TriggerServerEvent('multichar:server:createCharacter', {
        firstname = data.firstname,
        lastname = data.lastname,
        age = age,
        sex = data.sex or 'male'
    })
    cb('ok')
end)

RegisterNUICallback('appearanceChange', function(data, cb)
    if data and data.part then
        ModifyAppearance(data.part, data.delta or 0)
    end
    cb('ok')
end)

RegisterNUICallback('appearanceModel', function(data, cb)
    local sex = (data and data.sex) or 'male'
    Appearance = DefaultAppearance(sex)
    local model = Appearance.model
    SpawnLobbyPed(model, Appearance)
    ApplyAppearance(currentPed, Appearance)
    -- reset cam focus
    UpdateCamFocus()
    SendNUIMessage({ action = 'appearanceState', data = Appearance })
    cb('ok')
end)

RegisterNUICallback('appearanceFocus', function(data, cb)
    if data and data.focus then
        camFocusMode = data.focus
        UpdateCamFocus()
    end
    cb('ok')
end)

RegisterNUICallback('appearanceRotate', function(data, cb)
    if currentPed and DoesEntityExist(currentPed) then
        local h = GetEntityHeading(currentPed)
        local delta = (data and data.delta) or 0
        SetEntityHeading(currentPed, h + delta)
        UpdateCamFocus()
    end
    cb('ok')
end)

RegisterNUICallback('appearanceSave', function(data, cb)
    if not Appearance then cb('error'); return end
    Appearance.sex = Appearance.sex or 'male'
    if creatingCharId then
        TriggerServerEvent('multichar:server:saveSkin', creatingCharId, Appearance)
    end
    cb('ok')
end)

-- =====================
-- SERVER EVENTS
-- =====================
RegisterNetEvent('multichar:client:loadCharacters')
AddEventHandler('multichar:client:loadCharacters', function(chars, slots)
    characters = chars or {}
    maxSlots = slots or Config.MaxSlots
    -- request open lobby after a tick
    CreateThread(function()
        Wait(500)
        EnterLobby()
    end)
end)

RegisterNetEvent('multichar:client:characterCreated')
AddEventHandler('multichar:client:characterCreated', function(id, data)
    creatingCharId = id
    -- open appearance
    local sex = (data and data.sex) or 'male'
    Appearance = DefaultAppearance(sex)
    appearanceMode = true
    -- spawn ped
    SpawnLobbyPed(Appearance.model, Appearance)
    ApplyAppearance(currentPed, Appearance)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openAppearance', data = { appearance = Appearance } })
    UpdateCamFocus()
end)

RegisterNetEvent('multichar:client:skinSaved')
AddEventHandler('multichar:client:skinSaved', function(charId)
    -- spawn into city
    TriggerServerEvent('multichar:server:selectCharacter', charId)
end)

RegisterNetEvent('multichar:client:spawnCharacter')
AddEventHandler('multichar:client:spawnCharacter', function(char)
    if not isSpawning then
        -- could be duplicate; ignore extra
    end
    print('[MULTICHAR] spawnCharacter received id=' .. tostring(char and char.id))
    LeaveLobbyToCity(char)
    isSpawning = false
end)

-- bucket setter from server (optional)
RegisterNetEvent('multichar:client:setBucketDone')
AddEventHandler('multichar:client:setBucketDone', function() end)

-- =====================
-- INIT
-- =====================
local requestedChars = false
AddEventHandler('playerSpawned', function()
    if requestedChars then return end
    requestedChars = true
    local ped = PlayerPedId()
    SetEntityVisible(ped, false)
    FreezeEntityPosition(ped, true)
    TriggerServerEvent('multichar:server:requestCharacters')
end)

-- Position save ack not needed

-- Keep cam focus updated in appearance mode
CreateThread(function()
    while true do
        Wait(0)
        if inLobby and appearanceMode then
            UpdateCamFocus()
        end
    end
end)