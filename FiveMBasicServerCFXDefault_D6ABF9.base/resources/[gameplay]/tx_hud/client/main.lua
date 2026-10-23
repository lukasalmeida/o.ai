-- tx_hud | cliente
-- Coleta o estado do jogador/veiculo e envia para a NUI do HUD.
-- Eventos expostos para integracao com outros recursos:
--   TriggerServerEvent('txhud:setMoney', cash, bank)
--   TriggerServerEvent('txhud:setXp', level, current, needed)
--   TriggerServerEvent('txhud:setSlots', slots)   -- slots = { {icon='i-food', label='Frango', count=3}, ... }
--   TriggerServerEvent('txhud:setTasks', tasks)   -- tasks = { {title=..., desc=..., key='F', dist='1km', reward='$5.000', progress=40, done=false}, ... }

local hudVisible = true
local activeSlot = 1
local seatbelt = false
local inVehicle = false
local lastState = {}

-- Zonas seguras (x, y, raio em metros)
local safeZones = {
    { x = -810.0, y = 175.0, r = 90.0 },   -- Maze Bank (Legion)
    { x = 448.0,  y = -1698.0, r = 80.0 }, -- Hospital principal
    { x = -247.0, y = 6331.0, r = 70.0 },  -- Cassino
}

local weaponNames = {
    [GetHashKey('WEAPON_PISTOL')] = 'PISTOLA',
    [GetHashKey('WEAPON_PISTOL_MK2')] = 'PISTOLA MK II',
    [GetHashKey('WEAPON_COMBATPISTOL')] = 'PISTOLA DE COMBATE',
    [GetHashKey('WEAPON_SMG')] = 'SUBMETRALHADORA',
    [GetHashKey('WEAPON_MICROSMG')] = 'MICRO SMG',
    [GetHashKey('WEAPON_CARBINERINE')] = 'FUZIL',
    [GetHashKey('WEAPON_RIFLE')] = 'RIFLE',
    [GetHashKey('WEAPON_SPECIALCARBINE')] = 'FUZIL ESPECIAL',
    [GetHashKey('WEAPON_SHOTGUN')] = 'ESPINGARDA',
    [GetHashKey('WEAPON_PUMPSHOTGUN')] = 'ESPINGARDA DE CANO DUPLO',
    [GetHashKey('WEAPON_ASSAULTSHOTGUN')] = 'ESPINGARDA DE ASSALTO',
    [GetHashKey('WEAPON_SNIPERRIFLE')] = 'RIFLE DE PRECISAO',
    [GetHashKey('WEAPON_HEAVYSNIPER')] = 'RIFLE PESADO',
    [GetHashKey('WEAPON_ADVANCEDRIFLE')] = 'RIFLE AVANCADO',
    [GetHashKey('WEAPON_MACHINEGUN')] = 'METRALHADORA',
    [GetHashKey('WEAPON_MINIGUN')] = 'MINIGUN',
    [GetHashKey('WEAPON_REVOLVER')] = 'REVOLVER',
    [GetHashKey('WEAPON_DOUBLEACTION')] = 'REVOLVER DUPLA ACAO',
    [GetHashKey('WEAPON_DEAGLE')] = 'DESERT EAGLE',
    [GetHashKey('WEAPON_HAZARDCAN')] = 'SINALIZADOR',
    [GetHashKey('WEAPON_STUNGUN')] = 'TASER',
    [GetHashKey('WEAPON_FLARE')] = 'SINALIZADOR',
    [GetHashKey('WEAPON_PETROLCAN')] = 'GALAO DE GASOLINA',
    [GetHashKey('WEAPON_FIREEXTINGUISHER')] = 'EXTINTOR',
    [GetHashKey('WEAPON_BALL')] = 'BOLA',
}

-- ---------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------
local function isNearSafeZone(coords)
    for i = 1, #safeZones do
        local z = safeZones[i]
        local dx = coords.x - z.x
        local dy = coords.y - z.y
        if (dx * dx + dy * dy) <= (z.r * z.r) then
            return true
        end
    end
    return false
end

local function getZoneName(coords)
    local name = GetNameOfZone(coords.x, coords.y)
    local label = GetLabelText(GetHashKey(name))
    if label and label ~= 'NULL' and label ~= '' then
        return label:upper()
    end
    return (name or 'DESCONHECIDO'):upper()
end

local function getWeaponInfo(ped)
    local hash = GetSelectedPedWeapon(ped)
    if hash == GetHashKey('WEAPON_UNARMED') then
        return { name = 'DESARMADO', ammo = 0, reserve = 0, unarmed = true }
    end
    local name = weaponNames[hash]
    if not name then
        local label = GetLabelText(hash)
        name = (label and label ~= 'NULL') and label:upper() or 'DESCONHECIDA'
    end
    local ammo = GetAmmoInPedWeapon(ped, hash)
    local reserve = GetMaxAmmoInPedWeapon(ped, hash)
    return { name = name, ammo = ammo, reserve = reserve, unarmed = false }
end

local function getTimeString()
    local h, m = GetClockTime()
    return string.format('%02d:%02d', h, m)
end

local function getDateString()
    return os.date('%d/%m/%Y')
end

-- ---------------------------------------------------------------------
-- Envio do estado completo para a NUI
-- ---------------------------------------------------------------------
local function pushState(force)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local veh = GetVehiclePedIsIn(ped, false)

    local vehicle = {
        active = veh ~= 0,
        speed = 0,
        maxSpeed = 220,
        fuel = 0,
        rpm = 0,
        rpmValue = 0,
        gear = 1,
        engine = false,
        lights = false,
        locked = false,
        seatbelt = seatbelt,
    }

    if veh ~= 0 then
        local maxSpeed = GetVehicleMaxSpeed(veh) * 3.6
        local rpm = GetVehicleCurrentRpm(veh)
        vehicle.speed = GetEntitySpeed(veh) * 3.6
        vehicle.maxSpeed = maxSpeed > 0 and maxSpeed or 220
        vehicle.fuel = GetVehicleFuelLevel(veh)
        vehicle.rpm = rpm * 100
        vehicle.rpmValue = math.floor(rpm * 70) / 10
        vehicle.gear = GetVehicleCurrentGear(veh)
        vehicle.engine = GetIsVehicleEngineRunning(veh)
        vehicle.lights = GetVehicleLightsState(veh) == 1
        vehicle.locked = GetVehicleDoorLockStatus(veh) == 2
    end

    local payload = {
        action = 'hud',
        health = math.floor(GetEntityHealth(ped) - 100),
        armor = math.floor(GetPedArmour(ped)),
        stamina = math.floor(GetPlayerStamina(PlayerId())),
        weapon = getWeaponInfo(ped),
        vehicle = vehicle,
        zone = {
            safe = isNearSafeZone(coords),
            name = getZoneName(coords),
            x = coords.x,
            y = coords.y,
            heading = GetEntityHeading(ped),
        },
        server = {
            time = getTimeString(),
            date = getDateString(),
            playerId = GetPlayerServerId(PlayerId()),
        },
        activeSlot = activeSlot,
        hudVisible = hudVisible,
    }

    -- Evita spam: so envia se algo relevante mudou (ou se for forcado)
    local signature = table.concat({
        payload.health, payload.armor, payload.stamina,
        payload.weapon.name, payload.weapon.ammo,
        tostring(vehicle.active), tostring(math.floor(vehicle.speed)),
        tostring(math.floor(vehicle.fuel)), tostring(vehicle.gear),
        tostring(vehicle.engine), tostring(vehicle.lights), tostring(vehicle.locked),
        payload.zone.name, tostring(payload.zone.safe), tostring(math.floor(payload.zone.heading)),
        payload.server.time, tostring(activeSlot), tostring(hudVisible),
    }, '|')

    if force or signature ~= lastState.signature then
        lastState.signature = signature
        SendNUIMessage(payload)
    end
end

-- ---------------------------------------------------------------------
-- Loop principal
-- ---------------------------------------------------------------------
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        inVehicle = veh ~= 0

        pushState(false)

        -- atualiza a data 1x por minuto
        local now = GetGameTimer()
        if not lastState.minute or (now - lastState.minute) > 60000 then
            lastState.minute = now
            SendNUIMessage({ action = 'hud', server = { date = getDateString() } })
        end

        Wait(inVehicle and 80 or 220)
    end
end)

-- ---------------------------------------------------------------------
-- Alerta de cinto
-- ---------------------------------------------------------------------
CreateThread(function()
    while true do
        if inVehicle and not seatbelt then
            SendNUIMessage({ action = 'alert', text = 'Cinto de seguranca nao colocado' })
        end
        Wait(3000)
    end
end)

-- ---------------------------------------------------------------------
-- Comandos e teclas
-- ---------------------------------------------------------------------
RegisterCommand('hud', function()
    hudVisible = not hudVisible
    pushState(true)
end, false)

RegisterCommand('txhud_toggle', function()
    hudVisible = not hudVisible
    pushState(true)
end, false)

RegisterCommand('txhud_seatbelt', function()
    if not inVehicle then return end
    seatbelt = not seatbelt
    SendNUIMessage({
        action = 'alert',
        text = seatbelt and 'Cinto de seguranca colocado' or 'Cinto de seguranca removido',
    })
    pushState(true)
end, false)

for i = 1, 6 do
    RegisterCommand('txhud_slot_' .. i, function()
        activeSlot = i
        pushState(true)
        TriggerServerEvent('txhud:slotChanged', i)
    end, false)
end

-- Atalhos de teclado (as teclas padrao podem ser trocadas nas opcoes do FiveM)
RegisterKeyMapping('txhud_toggle', 'Alternar HUD', 'keyboard', 'F7')
RegisterKeyMapping('txhud_seatbelt', 'Colocar/remover cinto', 'keyboard', 'B')
for i = 1, 6 do
    RegisterKeyMapping('txhud_slot_' .. i, 'Slot ' .. i, 'keyboard', tostring(i))
end

-- ---------------------------------------------------------------------
-- Recebe dados do servidor
-- ---------------------------------------------------------------------
RegisterNetEvent('txhud:players')
AddEventHandler('txhud:players', function(players)
    SendNUIMessage({ action = 'hud', server = { players = players } })
end)

RegisterNetEvent('txhud:playerData')
AddEventHandler('txhud:playerData', function(data)
    SendNUIMessage({
        action = 'hud',
        name = data.name,
        level = data.level,
        xp = data.xp,
        money = data.money,
    })
end)

RegisterNetEvent('txhud:slots')
AddEventHandler('txhud:slots', function(slots)
    SendNUIMessage({ action = 'slots', slots = slots, activeSlot = activeSlot })
end)

RegisterNetEvent('txhud:tasks')
AddEventHandler('txhud:tasks', function(tasks)
    SendNUIMessage({ action = 'tasks', tasks = tasks })
end)

RegisterNetEvent('txhud:alert')
AddEventHandler('txhud:alert', function(text, danger)
    SendNUIMessage({ action = 'alert', text = text, danger = danger })
end)

RegisterNetEvent('txhud:voice')
AddEventHandler('txhud:voice', function(enabled)
    SendNUIMessage({ action = 'talking', enabled = enabled })
end)

-- ---------------------------------------------------------------------
-- Hook: avisa quando o jogador entra/sai de um veiculo
-- ---------------------------------------------------------------------
AddEventHandler('gameEventTriggered', function(name, args)
    if name == 'CEventNetworkPlayerEnteredVehicle' or name == 'CEventNetworkPlayerExitedVehicle' then
        pushState(true)
    end
end)
