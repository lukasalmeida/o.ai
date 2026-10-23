-- cpanel | cliente
-- Logica do painel: NUI, noclip, godmode, veiculos, armas e teleportes

local panelOpen = false
local god = false
local invis = false
local noclip = false
local escBlockUntil = 0

---------------------------------------------------------------------
-- Notificacoes (toast no painel / feed nativo fora dele)
---------------------------------------------------------------------
local function notify(message, ntype)
    ntype = ntype or 'info'
    if panelOpen then
        SendNUIMessage({ action = 'notify', ntype = ntype, message = message })
    else
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(message)
        EndTextCommandThefeedPostTicker(false, true)
    end
end

local function pushStatus()
    SendNUIMessage({ action = 'status', god = god, noclip = noclip, invis = invis })
end

---------------------------------------------------------------------
-- Godmode (revive automaticamente se estiver morto)
---------------------------------------------------------------------
local function revivePlayer()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, GetEntityHeading(ped), true, true, false)
    ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetPedArmour(ped, 100)
    ClearPedTasksImmediately(ped)
end

local function setGod(enabled)
    god = enabled
    local ped = PlayerPedId()
    SetEntityInvincible(ped, enabled)
    SetPlayerInvincible(PlayerId(), enabled)
    if enabled then
        SetEntityHealth(ped, GetEntityMaxHealth(ped))
        notify('Godmode ATIVADO.', 'success')
    else
        notify('Godmode DESATIVADO.', 'info')
    end
    pushStatus()
end

CreateThread(function()
    while true do
        if god then
            local ped = PlayerPedId()
            SetEntityInvincible(ped, true)
            SetPlayerInvincible(PlayerId(), true)
            Wait(400)
        else
            Wait(500)
        end
    end
end)

---------------------------------------------------------------------
-- Invisivel
---------------------------------------------------------------------
local function setInvisible(enabled)
    invis = enabled
    SetEntityVisible(PlayerPedId(), not enabled, false)
    notify(enabled and 'Voce ficou INVISIVEL.' or 'Voce ficou visivel.', enabled and 'success' or 'info')
    pushStatus()
end

---------------------------------------------------------------------
-- Noclip
---------------------------------------------------------------------
local function toggleNoclip()
    noclip = not noclip
    local ped = PlayerPedId()
    SetEntityCollision(ped, not noclip, not noclip)
    if not noclip then
        SetEntityVelocity(ped, 0.0, 0.0, 0.0)
    end
    notify(noclip and 'Noclip ATIVADO (W/A/S/D, E sobe, Q desce, Shift acelera).' or 'Noclip DESATIVADO.', noclip and 'success' or 'info')
    pushStatus()
end

CreateThread(function()
    while true do
        if noclip and not panelOpen then
            local ped = PlayerPedId()
            local rot = GetGameplayCamRot(0)
            local radZ = math.rad(rot.z)
            local cosX = math.abs(math.cos(math.rad(rot.x)))
            local sinX = math.sin(math.rad(rot.x))

            local fwdX = -math.sin(radZ) * cosX
            local fwdY = math.cos(radZ) * cosX
            local fwdZ = sinX
            local rgtX = math.cos(radZ)
            local rgtY = math.sin(radZ)

            local speed = IsControlPressed(0, 21) and 0.65 or 0.14
            local pos = GetEntityCoords(ped)
            local nx, ny, nz = pos.x, pos.y, pos.z

            if IsControlPressed(0, 32) then nx = nx + fwdX * speed; ny = ny + fwdY * speed; nz = nz + fwdZ * speed end
            if IsControlPressed(0, 33) then nx = nx - fwdX * speed; ny = ny - fwdY * speed; nz = nz - fwdZ * speed end
            if IsControlPressed(0, 34) then nx = nx - rgtX * speed; ny = ny - rgtY * speed end
            if IsControlPressed(0, 35) then nx = nx + rgtX * speed; ny = ny + rgtY * speed end
            if IsControlPressed(0, 38) then nz = nz + speed end -- E: subir
            if IsControlPressed(0, 44) then nz = nz - speed end -- Q: descer

            SetEntityVelocity(ped, 0.0, 0.0, 0.0)
            SetEntityCoordsNoOffset(ped, nx, ny, nz, false, false, false)
            SetEntityHeading(ped, rot.z)

            BeginTextCommandDisplayHelp('STRING')
            AddTextComponentSubstringPlayerName('~e~NOCLIP~s~  W/A/S/D move  |  E sobe  |  Q desce  |  Shift acelera')
            EndTextCommandDisplayHelp(0, false, true, -1)

            Wait(0)
        else
            Wait(400)
        end
    end
end)

---------------------------------------------------------------------
-- Veiculos
---------------------------------------------------------------------
local function spawnCar(model, occupantPed)
    local hash = joaat(model)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        notify(('Veiculo invalido: %s'):format(model), 'error')
        return false
    end

    RequestModel(hash)
    local tries = 0
    while not HasModelLoaded(hash) and tries < 500 do
        Wait(10)
        tries = tries + 1
    end
    if not HasModelLoaded(hash) then
        notify(('Nao foi possivel carregar o modelo: %s'):format(model), 'error')
        return false
    end

    local ped = occupantPed or PlayerPedId()
    local coords = GetEntityCoords(ped)
    local veh = CreateVehicle(hash, coords.x, coords.y, coords.z + 1.0, GetEntityHeading(ped), true, false)
    SetVehicleOnGroundProperly(veh)
    SetVehicleNumberPlateText(veh, 'CPANEL')
    SetPedIntoVehicle(ped, veh, -1)
    SetModelAsNoLongerNeeded(hash)
    return true
end

---------------------------------------------------------------------
-- Remocao de veiculos (/dv e /dvall)
---------------------------------------------------------------------
local function deleteVehicle(veh)
    SetEntityAsMissionEntity(veh, true, true)
    if DoesEntityExist(veh) then
        DeleteVehicle(veh)
    end
end

local function deleteNearestVehicle()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local veh = GetVehiclePedIsIn(ped, false)

    if veh == 0 then
        local closest, closestDist = nil, 10.0
        for _, v in ipairs(GetGamePool('CVehicle')) do
            local d = #(pos - GetEntityCoords(v))
            if d < closestDist then
                closest, closestDist = v, d
            end
        end
        veh = closest
    end

    if veh then
        deleteVehicle(veh)
        notify('Veiculo removido.', 'success')
    else
        notify('Nenhum veiculo por perto.', 'error')
    end
end

local function deleteVehiclesInRadius(radius)
    radius = math.floor(tonumber(radius) or 100)
    if radius < 1 then radius = 1 end
    if radius > 500 then radius = 500 end

    local pos = GetEntityCoords(PlayerPedId())
    local count = 0
    for _, v in ipairs(GetGamePool('CVehicle')) do
        if #(pos - GetEntityCoords(v)) <= radius then
            deleteVehicle(v)
            count = count + 1
        end
    end
    notify(('%d veiculo(s) removido(s) em %dm.'):format(count, radius), 'success')
end

---------------------------------------------------------------------
-- Armas
---------------------------------------------------------------------
local WEAPON_ALIAS = {
    pistol = 'WEAPON_PISTOL',
    combatpistol = 'WEAPON_COMBATPISTOL',
    pistol50 = 'WEAPON_PISTOL50',
    heavypistol = 'WEAPON_HEAVYPISTOL',
    smg = 'WEAPON_SMG',
    microsmg = 'WEAPON_MICROSMG',
    assaultrifle = 'WEAPON_ASSAULTRIFLE',
    ak = 'WEAPON_ASSAULTRIFLE',
    carbinerifle = 'WEAPON_CARBINERIFLE',
    m4 = 'WEAPON_CARBINERIFLE',
    specialcarbine = 'WEAPON_SPECIALCARBINE',
    pumpshotgun = 'WEAPON_PUMPSHOTGUN',
    shotgun = 'WEAPON_PUMPSHOTGUN',
    sawnoff = 'WEAPON_SAWNOFFSHOTGUN',
    sniperrifle = 'WEAPON_SNIPERRIFLE',
    heavysniper = 'WEAPON_HEAVYSNIPER',
    musket = 'WEAPON_MUSKET',
    rpg = 'WEAPON_RPG',
    grenade = 'WEAPON_GRENADE',
    molotov = 'WEAPON_MOLOTOV',
    knife = 'WEAPON_KNIFE',
    bat = 'WEAPON_BAT',
    hatchet = 'WEAPON_HATCHET',
    taser = 'WEAPON_STUNGUN',
}

local WEAPON_KIT = {
    'WEAPON_PISTOL', 'WEAPON_SMG', 'WEAPON_ASSAULTRIFLE',
    'WEAPON_PUMPSHOTGUN', 'WEAPON_SNIPERRIFLE', 'WEAPON_KNIFE',
}

local function resolveWeapon(name)
    name = string.lower(name)
    if WEAPON_ALIAS[name] then return WEAPON_ALIAS[name] end
    local upper = string.upper(name)
    if string.sub(upper, 1, 7) ~= 'WEAPON_' then
        upper = 'WEAPON_' .. upper
    end
    return upper
end

local function giveWeapon(weapon, ammo)
    ammo = math.floor(tonumber(ammo) or 250)
    if ammo < 0 then ammo = 0 end
    if ammo > 9999 then ammo = 9999 end

    local ped = PlayerPedId()

    if string.lower(weapon) == 'all' then
        for _, w in ipairs(WEAPON_KIT) do
            GiveWeaponToPed(ped, joaat(w), ammo, false, true)
        end
        notify(('Kit de armas recebido (%d munições cada).'):format(ammo), 'success')
        return true
    end

    local hash = joaat(resolveWeapon(weapon))
    if not IsWeaponValid(hash) then
        notify(('Arma invalida: %s'):format(weapon), 'error')
        return false
    end
    GiveWeaponToPed(ped, hash, ammo, false, true)
    notify(('Arma recebida (%d munições).'):format(ammo), 'success')
    return true
end

---------------------------------------------------------------------
-- Acoes em si mesmo (via comando ou painel)
---------------------------------------------------------------------
RegisterNetEvent('cpanel:selfAction', function(action, data)
    data = data or {}
    local ped = PlayerPedId()

    if action == 'spawnCar' then
        if spawnCar(data.model) then
            notify(('Veiculo %s criado.'):format(data.model), 'success')
        end

    elseif action == 'toggleGod' then
        if IsEntityDead(ped) then
            revivePlayer()
            setGod(true)
            return
        end
        setGod(not god)

    elseif action == 'toggleNoclip' then
        toggleNoclip()

    elseif action == 'toggleInvis' then
        setInvisible(not invis)

    elseif action == 'heal' then
        SetEntityHealth(ped, GetEntityMaxHealth(ped))
        SetPedArmour(ped, 100)
        notify('Vida e colete restaurados.', 'success')

    elseif action == 'kill' then
        SetEntityHealth(ped, 0)
        notify('Voce se matou.', 'info')

    elseif action == 'deleteNearest' then
        deleteNearestVehicle()

    elseif action == 'deleteRadius' then
        deleteVehiclesInRadius(data.radius)

    elseif action == 'fix' then
        local veh = GetVehiclePedIsIn(ped, false)
        if veh == 0 then
            notify('Voce nao esta em um veiculo.', 'error')
        else
            SetVehicleFixed(veh)
            SetVehicleDeformationFixed(veh)
            SetVehicleDirtLevel(veh, 0.0)
            SetVehicleEngineOn(veh, true, true, false)
            notify('Veiculo consertado.', 'success')
        end

    elseif action == 'giveWeapon' then
        giveWeapon(data.weapon or 'pistol', data.ammo)
    end
end)

---------------------------------------------------------------------
-- Acoes em jogadores alvo
---------------------------------------------------------------------
RegisterNetEvent('cpanel:targetAction', function(action, data, byId)
    data = data or {}
    local ped = PlayerPedId()
    local isAdminHere = byId ~= nil

    if action == 'kill' then
        SetEntityHealth(ped, 0)
        if isAdminHere then notify('Voce foi morto por um administrador.', 'error') end

    elseif action == 'heal' then
        SetEntityHealth(ped, GetEntityMaxHealth(ped))
        SetPedArmour(ped, 100)
        if isAdminHere then notify('Voce foi curado por um administrador.', 'success') end

    elseif action == 'god' then
        if IsEntityDead(ped) then
            revivePlayer()
            setGod(true)
        else
            setGod(not god)
        end

    elseif action == 'freeze' then
        local frozen = not IsEntityPositionFrozen(ped)
        FreezeEntityPosition(ped, frozen)
        notify(frozen and 'Voce foi CONGELADO por um administrador.' or 'Voce foi DESCONGELADO.', frozen and 'warning' or 'success')

    elseif action == 'weapon' then
        giveWeapon(data.weapon or 'pistol', data.ammo)

    elseif action == 'car' then
        if spawnCar(data.model, ped) then
            notify('Um administrador spawnou um veiculo para voce.', 'success')
        end
    end
end)

---------------------------------------------------------------------
-- Teleport
---------------------------------------------------------------------
RegisterNetEvent('cpanel:teleport', function(coords)
    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z + 1.0, false, false, false)
    SetEntityHeading(ped, GetEntityHeading(ped))
end)

---------------------------------------------------------------------
-- Anuncio
---------------------------------------------------------------------
RegisterNetEvent('cpanel:announce', function(message, author)
    TriggerEvent('chat:addMessage', {
        color = { 255, 92, 56 },
        multiline = true,
        args = { 'ADMIN', message },
    })
    notify(('Anuncio de %s: %s'):format(author or 'admin', message), 'warning')
end)

---------------------------------------------------------------------
-- Notificacao geral (vinda do servidor)
---------------------------------------------------------------------
RegisterNetEvent('cpanel:notify', function(message, ntype)
    notify(message, ntype)
end)

---------------------------------------------------------------------
-- Painel (NUI)
---------------------------------------------------------------------
local function closePanel()
    if not panelOpen then return end
    panelOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
    -- evita que o mesmo ESC abra o menu de pausa do GTA logo apos fechar
    escBlockUntil = GetGameTimer() + 350
end

RegisterNetEvent('cpanel:open', function()
    if panelOpen then return end
    panelOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        myId = GetPlayerServerId(PlayerId()),
        status = { god = god, noclip = noclip, invis = invis },
    })
    TriggerServerEvent('cpanel:requestPlayers')
end)

-- Fecha pelo botao do painel / ESC (via NUI)
RegisterNUICallback('close', function(_, cb)
    closePanel()
    cb({ ok = true })
end)

-- ESC de seguranca: enquanto o painel estiver aberto, bloqueia o menu de
-- pausa do GTA e fecha o painel por qualquer um dos caminhos do ESC:
--   1) NUI (keydown/keyup Escape -> callback "close")
--   2) input do jogo: IsDisabledControlJustPressed continua registrando o
--      pressionamento mesmo com o control desabilitado (o IsControlJustPressed
--      NAO registra - por isso o ESC "antigo" nao fechava nada)
--   3) menu de pausa aberto (caso o ESC tenha sido consumido pelo jogo)
CreateThread(function()
    while true do
        if panelOpen or GetGameTimer() < escBlockUntil then
            DisableControlAction(0, 199, true)
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 202, true)
            DisableControlAction(0, 322, true)

            if panelOpen then
                if IsPauseMenuActive() then
                    closePanel()
                    SetFrontendActive(false)
                elseif IsDisabledControlJustPressed(0, 322)
                    or IsDisabledControlJustPressed(0, 200)
                    or IsDisabledControlJustPressed(0, 202) then
                    closePanel()
                end
            end
            Wait(0)
        else
            Wait(100)
        end
    end
end)

RegisterNUICallback('refreshPlayers', function(_, cb)
    TriggerServerEvent('cpanel:requestPlayers')
    cb({ ok = true })
end)

RegisterNUICallback('execute', function(data, cb)
    if data and data.action then
        TriggerServerEvent('cpanel:execute', data.action, data.data or {})
    end
    cb({ ok = true })
end)

RegisterNetEvent('cpanel:receivePlayers', function(list)
    local my = GetEntityCoords(PlayerPedId())
    SendNUIMessage({ action = 'players', list = list, my = { x = my.x, y = my.y, z = my.z } })
end)

---------------------------------------------------------------------
-- Comando principal + sugestoes do chat
---------------------------------------------------------------------
RegisterCommand('cpanel', function()
    if panelOpen then
        closePanel()
    else
        TriggerServerEvent('cpanel:requestOpen')
    end
end, false)

local SUGGESTIONS = {
    { '/cpanel', 'Abrir o painel admin in-game' },
    { '/car', 'Spawnar um veiculo', { { name = 'modelo', help = 'ex: adder, sultan, police' } } },
    { '/god', 'Ativar/desativar godmode' },
    { '/arma', 'Receber uma arma', { { name = 'arma', help = 'ex: pistol, ak, rpg, all' }, { name = 'munição', help = 'padrao 250' } } },
    { '/hp', 'Restaurar vida e colete' },
    { '/kill', 'Matar a si mesmo', { { name = 'id', help = 'opcional: matar outro jogador' } } },
    { '/tp', 'Teleportar ate um jogador', { { name = 'id', help = 'ID do jogador' } } },
    { '/bring', 'Trazer um jogador ate voce', { { name = 'id', help = 'ID do jogador' } } },
    { '/freeze', 'Congelar/descongelar um jogador', { { name = 'id', help = 'ID do jogador' } } },
    { '/invis', 'Ativar/desativar invisibilidade' },
    { '/noclip', 'Ativar/desativar noclip' },
    { '/fix', 'Consertar o veiculo atual' },
    { '/dv', 'Remover o veiculo mais proximo (ate 10m)' },
    { '/dvall', 'Remover todos os veiculos num raio', { { name = 'raio', help = 'metros, ex: 100 (max 500)' } } },
    { '/police', 'Ligar/desligar o bloqueio da policia NPC' },
    { '/anuncio', 'Enviar anuncio para todos', { { name = 'mensagem', help = 'texto do anuncio' } } },
}

CreateThread(function()
    Wait(1500)
    for _, s in ipairs(SUGGESTIONS) do
        TriggerEvent('chat:addSuggestion', s[1], s[2], s[3])
    end
end)

---------------------------------------------------------------------
-- Limpeza ao parar o recurso
---------------------------------------------------------------------
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    SetEntityCollision(PlayerPedId(), true, true)
    SetEntityVisible(PlayerPedId(), true, false)
    SetEntityInvincible(PlayerPedId(), false)
    SetPlayerInvincible(PlayerId(), false)
end)
