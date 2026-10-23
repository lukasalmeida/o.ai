-- ==========================================================
--  TX_INVENTORY | CLIENTE (principal)
--  ----------------------------------------------------------
--  - NUI (abrir/fechar, foco do mouse)
--  - Tecla ' (toggle), teclas 1-5 (hotbar)
--  - Drag & drop -> chão 3D, lixeira, dar item
--  - Pegar itens do chão com animação
-- ==========================================================

-- ==========================================================
--  ESTADO
-- ==========================================================
local isOpen        = false
local state         = { items = {}, weight = { current = 0, max = 30 }, slots = { backpack = 30, hotbar = 5 }, ground = {}, player = {} }
local currentWeapon = nil
local propEntities  = {}   -- instance -> entity (fallback sem OneSync)
local lastPositions = nil

-- ==========================================================
--  MENSAGENS
-- ==========================================================
local Messages = {
    drop_success       = 'Item jogado no chão.',
    pickup_success     = 'Item recolhido.',
    give_success       = 'Item entregue.',
    receive_item       = 'Você recebeu um item.',
    used_item          = 'Item utilizado.',
    split_success      = 'Item dividido.',
    item_deleted       = 'Item destruído.',
    weapon_equipped    = 'Arma equipada.',
    too_far            = 'Você está longe demais.',
    drop_too_far       = 'Local inválido para dropar.',
    give_too_far       = 'O jogador está longe demais.',
    no_item_selected   = 'Selecione um item.',
    invalid_action     = 'Ação inválida.',
    -- chaves com ponto precisam de aspas (o servidor envia 'inventory.full_slots')
    ['inventory.full_slots']  = 'Mochila sem espaço.',
    ['inventory.full_weight'] = 'Mochila pesada demais.',
    ['inventory_full_slots']  = 'Mochila sem espaço.',
    ['inventory_full_weight'] = 'Mochila pesada demais.',
    target_full_slots  = 'O jogador não tem espaço.',
    target_full_weight = 'O jogador está pesado demais.',
}

--- Notificação no chat do GTA
local function Notify(key, kind)
    local text = Messages[key] or key or ''

    SetNotificationTextEntry('STRING')
    AddTextComponentSubstringPlayerName(text)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandThefeedPostTicker(false, false)
end
RegisterNetEvent('txinv:notify', function(key, kind)
    Notify(key, kind)
end)

-- ==========================================================
--  NUI
-- ==========================================================
local function SendNui(action, data)
    SendNUIMessage({ action = action, data = data })
end

local function OpenUI()
    isOpen = true
    SetNuiFocus(true, true)
    SendNui('open', state)
end

local function CloseUI()
    isOpen = false
    SetNuiFocus(false, false)
    SendNui('close')
end

local function ToggleUI()
    if isOpen then
        CloseUI()
    else
        TriggerServerEvent('txinv:server:open')
    end
end

RegisterNetEvent('txinv:client:open', function(payload)
    if payload then state = payload end
    OpenUI()
end)

RegisterNetEvent('txinv:client:refresh', function(payload)
    if payload then state = payload end
    SendNui('update', state)
end)

-- ==========================================================
--  CATÁLOGO PARA O NUI
-- ==========================================================
local function BuildCatalog()
    local cat = {}
    for name, def in pairs(TXINV.Items) do
        cat[name] = {
            label    = def.label or name,
            desc     = def.desc or '',
            type     = def.type or 'unknown',
            weight   = def.weight or 0,
            maxStack = def.maxStack or 1,
            image    = def.image,
            glyph    = def.glyph or '📦',
        }
    end
    return cat
end

-- ==========================================================
--  HELPERS
-- ==========================================================
--- Posição do drop: à frente do jogador, no chão
local function GetDropCoords()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local fwd = GetEntityForwardVector(ped)

    local x = coords.x + (fwd.x * 1.4)
    local y = coords.y + (fwd.y * 1.4)

    -- Raycast para encontrar o chão
    local found, groundZ = GetGroundZFor_3dCoord(x, y, coords.z + 2.0, false)
    local z
    if found and groundZ then
        z = groundZ + 0.05
    else
        z = coords.z - 0.85
    end

    return { x = x, y = y, z = z }
end

--- Jogador mais próximo (server id)
local function GetNearestPlayer()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return nil, 999.0 end
    local myCoords = GetEntityCoords(ped)

    local best, bestDist = nil, 999.0
    for _, player in ipairs(GetActivePlayers()) do
        local otherPed = GetPlayerPed(player)
        if otherPed ~= ped and DoesEntityExist(otherPed) then
            local dist = #(myCoords - GetEntityCoords(otherPed))
            if dist < bestDist then
                bestDist = dist
                best = GetPlayerServerId(player)
            end
        end
    end
    return best, bestDist
end

-- ==========================================================
--  CONTROLES DO NUI
-- ==========================================================
RegisterNUICallback('ready', function(_, cb)
    SendNui('catalog', BuildCatalog())
    SendNui('config', { hotbarHud = Config.EnableHotbarHud })
    TriggerServerEvent('txinv:server:requestState')
    cb('ok')
end)

RegisterNUICallback('close', function(_, cb)
    CloseUI()
    cb('ok')
end)

RegisterNUICallback('move', function(data, cb)
    TriggerServerEvent('txinv:server:move', data.itemId, data.slot)
    cb('ok')
end)

RegisterNUICallback('drop', function(data, cb)
    local coords = GetDropCoords()
    TriggerServerEvent('txinv:server:drop', data.itemId, data.amount or 1, coords)
    TXAnim.Drop()
    cb('ok')
end)

RegisterNUICallback('give', function(data, cb)
    local target, dist = GetNearestPlayer()
    if not target then
        Notify('give_too_far', 'error')
        cb('ok')
        return
    end
    TXAnim.Give()
    TriggerServerEvent('txinv:server:give', data.itemId, data.amount or 1, target)
    cb('ok')
end)

RegisterNUICallback('use', function(data, cb)
    TriggerServerEvent('txinv:server:use', data.itemId)
    cb('ok')
end)

RegisterNUICallback('unequip', function(_, cb)
    TriggerServerEvent('txinv:server:unequip')
    cb('ok')
end)

RegisterNUICallback('split', function(data, cb)
    TriggerServerEvent('txinv:server:split', data.itemId, data.amount)
    cb('ok')
end)

RegisterNUICallback('delete', function(data, cb)
    TriggerServerEvent('txinv:server:delete', data.itemId)
    cb('ok')
end)

RegisterNUICallback('pickup', function(data, cb)
    TriggerServerEvent('txinv:server:pickup', data.instance)
    TXAnim.Pickup()
    cb('ok')
end)

RegisterNUICallback('refresh', function(_, cb)
    TriggerServerEvent('txinv:server:requestState')
    cb('ok')
end)

-- ==========================================================
--  TECLAS
-- ==========================================================
RegisterCommand('+txinv', function()
    print('[tx_inventory] inventario acionado pela tecla')
    ToggleUI()
end, false)
RegisterKeyMapping('+txinv', 'Inventário (abrir/fechar)', 'keyboard', Config.InventoryKey)

-- Binding alternativo: em layout US a tecla ' e o VK 0xDE (OEM_7). Em layout
-- PT-BR o VK 0xDE e a tecla do '~', por isso o binding principal usa OEM_3.
if Config.InventoryKeyAlt and Config.InventoryKeyAlt ~= Config.InventoryKey then
    RegisterCommand('+txinv_alt', function()
        ToggleUI()
    end, false)
    RegisterKeyMapping('+txinv_alt', 'Inventário (abrir/fechar) [layout US]', 'keyboard', Config.InventoryKeyAlt)
end

print(('[tx_inventory] cliente pronto | tecla principal: %s | alternativa: %s'):format(
    tostring(Config.InventoryKey), tostring(Config.InventoryKeyAlt)))

-- Comandos alternativos pelo chat (/inv, /inventario) caso a tecla seja remapeada
RegisterCommand('inv', function()
    ToggleUI()
end, false)
RegisterCommand('inventario', function()
    ToggleUI()
end, false)

for i = 1, 5 do
    RegisterCommand('+txhotbar' .. i, function()
        TriggerServerEvent('txinv:server:hotbar', i)
    end, false)
    RegisterKeyMapping('+txhotbar' .. i, 'Hotbar ' .. i, 'keyboard', tostring(i))
end

-- ==========================================================
--  TRAVA DE MOVIMENTO ENQUANTO O INVENTÁRIO ESTÁ ABERTO
-- ==========================================================
CreateThread(function()
    while true do
        if isOpen then
            Wait(0)
            DisableControlAction(0, 1, true)   -- andar para frente
            DisableControlAction(0, 2, true)   -- andar para trás
            DisableControlAction(0, 3, true)   -- andar para a esquerda
            DisableControlAction(0, 4, true)   -- andar para a direita
            DisableControlAction(0, 5, true)   -- olhar
            DisableControlAction(0, 6, true)   -- olhar
            DisableControlAction(0, 14, true)  -- atacar
            DisableControlAction(0, 15, true)  -- atirar
            DisableControlAction(0, 16, true)  -- mirar
            DisableControlAction(0, 17, true)  -- segurar arma
            DisableControlAction(0, 24, true)  -- atacar
            DisableControlAction(0, 25, true)  -- atirar
            DisableControlAction(0, 47, true)  -- pegar
            DisableControlAction(0, 58, true)  -- duck
            DisableControlAction(0, 76, true)  -- rope
            DisableControlAction(0, 75, true)  -- sair do veículo
            DisableControlAction(0, 23, true)  -- entrar no veículo
            DisablePlayerFiring(PlayerId(), true)
            DisableControlAction(0, 200, true) -- digitação no chat
        else
            Wait(400)
        end
    end
end)

-- ==========================================================
--  POSIÇÃO (heartbeat anti-cheat)
-- ==========================================================
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if DoesEntityExist(ped) then
            local coords = GetEntityCoords(ped)
            lastPositions = { x = coords.x, y = coords.y, z = coords.z }
            TriggerServerEvent('txinv:server:position', coords.x, coords.y, coords.z)
        end
        Wait(isOpen and 1000 or 2000)
    end
end)

-- ==========================================================
--  ARMAS
-- ==========================================================
RegisterNetEvent('txinv:client:equipWeapon', function(weaponName, metadata)
    local ped = PlayerPedId()

    if currentWeapon and currentWeapon ~= weaponName then
        RemoveWeaponFromPed(ped, joaat(currentWeapon))
    end

    local hash = joaat(weaponName)
    GiveWeaponToPed(ped, hash, tonumber((metadata or {}).ammo) or 50, false, true)
    currentWeapon = weaponName

    -- Mira/animação opcional
    if Config.Debug then
        print(('[tx_inventory] arma equipada: %s'):format(weaponName))
    end
end)

RegisterNetEvent('txinv:client:unequipWeapon', function()
    local ped = PlayerPedId()
    if currentWeapon then
        RemoveWeaponFromPed(ped, joaat(currentWeapon))
    end
    currentWeapon = nil
end)

RegisterNetEvent('txinv:client:giveEffect', function(itemName)
    TXAnim.Give()
end)

RegisterNetEvent('txinv:client:droppedItem', function(instance)
    -- a animação já é tocada no callback da NUI (resposta imediata)
end)

-- ==========================================================
--  PROPS NO CHÃO (fallback quando o servidor não cria o objeto)
-- ==========================================================
RegisterNetEvent('txinv:client:spawnGroundProp', function(instance, model, x, y, z)
    if propEntities[instance] then return end
    local hash = joaat(model or Config.DefaultGroundProp)
    if not IsModelValid(hash) then return end

    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 3000 do
        Wait(10)
        timeout = timeout + 10
    end
    if not HasModelLoaded(hash) then return end

    local obj = CreateObject(hash, x, y, z, true, true)
    if obj and obj ~= 0 then
        SetEntityAsMissionEntity(obj, true, true)
        FreezeEntityPosition(obj, true)
        propEntities[instance] = obj
    end
end)

RegisterNetEvent('txinv:client:removeGroundProp', function(instance)
    local ent = propEntities[instance]
    if ent and DoesEntityExist(ent) then
        DeleteEntity(ent)
    end
    propEntities[instance] = nil
end)

-- ==========================================================
--  PEGAR ITEM DO CHÃO (no mundo 3D)
-- ==========================================================
local function DrawText3D(x, y, z, text)
    local onScreen, _ = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextCentre(true)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry('STRING')
    SetTextCentre(true)
    AddTextComponentString(text)
    DrawText(0.0, 1.65)
    SetTextScale(0.0, 0.0)
    SetTextFont(8)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 0)
    SetTextDropShadowPosition(0, 0)
    SetTextDropShadowColour(0, 0, 0, 0)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 1.65)
end

CreateThread(function()
    local closest = nil
    while true do
        local wait = 400
        local ped = PlayerPedId()

        if state.ground and #state.ground > 0 and not isOpen and DoesEntityExist(ped) then
            local coords = GetEntityCoords(ped)
            local best, bestDist = nil, Config.PickupDistance

            for i = 1, #state.ground do
                local g = state.ground[i]
                local d = #(coords - vector3(g.x, g.y, g.z))
                if d < bestDist then
                    bestDist = d
                    best = g
                end
            end

            if best then
                wait = 150
                local def = TXINV.GetItem(best.name)
                DrawText3D(best.x, best.y, best.z + 0.35,
                    ('~w~%s ~s~x%d ~w~[%s] pegar'):format(def.label, best.amount, Config.PickupKey))

                if IsControlJustReleased(0, 51) then
                    TXAnim.Pickup()
                    TriggerServerEvent('txinv:server:pickup', best.instance)
                    Citizen.Wait(400)
                end
            end
        end

        Citizen.Wait(wait)
    end
end)

-- ==========================================================
--  INICIALIZAÇÃO
-- ==========================================================
CreateThread(function()
    -- O NUI avisa quando está pronto (RegisterNUICallback 'ready')
    Citizen.Wait(1500)
    TriggerServerEvent('txinv:server:requestState')
end)

-- ==========================================================
--  SAÍDA DO JOGADOR
-- ==========================================================
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        SetNuiFocus(false, false)
    end
end)
