-- cpanel | servidor
-- Painel admin inspirado no txAdmin. Permissao via ace: cpanel.use

---------------------------------------------------------------------
-- Utilidades
---------------------------------------------------------------------
local function isAdmin(src)
    if src == 0 then return true end -- console
    return IsPlayerAceAllowed(src, 'cpanel.use')
end

local function notify(src, message, ntype)
    if src == 0 then
        print(('[cpanel] %s'):format(message))
    else
        TriggerClientEvent('cpanel:notify', src, message, ntype or 'info')
    end
end

local function logAction(src, action, detail)
    local name = (src == 0) and 'CONSOLE' or tostring(GetPlayerName(src))
    print(('[cpanel] %s (ID %s) executou: %s %s'):format(name, src, action, detail or ''))
end

local function broadcast(message, author)
    for _, id in ipairs(GetPlayers()) do
        TriggerClientEvent('cpanel:announce', tonumber(id), message, author)
    end
end

---------------------------------------------------------------------
-- Abrir o painel
---------------------------------------------------------------------
RegisterNetEvent('cpanel:requestOpen', function()
    local src = source
    if not isAdmin(src) then
        notify(src, 'Voce nao tem permissao para abrir o painel.', 'error')
        return
    end
    TriggerClientEvent('cpanel:open', src)
end)

---------------------------------------------------------------------
-- Lista de jogadores (para o painel)
---------------------------------------------------------------------
RegisterNetEvent('cpanel:requestPlayers', function()
    local src = source
    if not isAdmin(src) then return end

    local list = {}
    for _, id in ipairs(GetPlayers()) do
        local sid = tonumber(id)
        local ped = GetPlayerPed(sid)
        local coords = GetEntityCoords(ped)
        list[#list + 1] = {
            id = sid,
            name = GetPlayerName(sid) or ('Jogador %s'):format(sid),
            ping = GetPlayerPing(sid),
            coords = { x = coords.x, y = coords.y, z = coords.z },
        }
    end
    TriggerClientEvent('cpanel:receivePlayers', src, list)
end)

---------------------------------------------------------------------
-- Execucao de acoes vindas do painel
---------------------------------------------------------------------
local SELF_ACTIONS = {
    spawnCar = true,
    toggleGod = true,
    toggleNoclip = true,
    toggleInvis = true,
    heal = true,
    kill = true,
    fix = true,
    giveWeapon = true,
    deleteNearest = true,
    deleteRadius = true,
}

local TARGET_ACTIONS = {
    kill = true,
    heal = true,
    god = true,
    freeze = true,
    weapon = true,
    car = true,
}

RegisterNetEvent('cpanel:execute', function(action, data)
    local src = source
    if not isAdmin(src) then return end
    data = data or {}

    -- Acoes em si mesmo
    if action == 'self' then
        if not SELF_ACTIONS[data.action] then return end
        TriggerClientEvent('cpanel:selfAction', src, data.action, data)
        logAction(src, 'self:' .. tostring(data.action))
        return
    end

    -- Anuncio para todo o servidor
    if action == 'announce' then
        local msg = tostring(data.message or '')
        if msg == '' then
            notify(src, 'Escreva uma mensagem para o anuncio.', 'error')
            return
        end
        local author = (src == 0) and 'CONSOLE' or GetPlayerName(src)
        broadcast(msg, author)
        logAction(src, 'announce', msg)
        return
    end

    -- Acoes com alvo
    local target = tonumber(data.target)
    if not target or not GetPlayerName(target) then
        notify(src, 'Jogador nao encontrado.', 'error')
        return
    end
    local tname = GetPlayerName(target)

    if action == 'goto' then
        local ped = GetPlayerPed(target)
        if not ped or ped <= 0 then
            notify(src, 'Nao foi possivel obter a localizacao do jogador.', 'error')
            return
        end
        TriggerClientEvent('cpanel:teleport', src, GetEntityCoords(ped))
        notify(src, ('Teleportado ate %s.'):format(tname), 'success')
        logAction(src, 'goto', tname)

    elseif action == 'bring' then
        if src == 0 then
            notify(src, 'O console nao pode trazer jogadores.', 'error')
            return
        end
        local ped = GetPlayerPed(src)
        if not ped or ped <= 0 then
            notify(src, 'Nao foi possivel obter a sua localizacao.', 'error')
            return
        end
        TriggerClientEvent('cpanel:teleport', target, GetEntityCoords(ped))
        TriggerClientEvent('cpanel:notify', target, 'Um admin te trouxe ate a posicao dele.', 'warning')
        notify(src, ('%s trazido ate voce.'):format(tname), 'success')
        logAction(src, 'bring', tname)

    elseif TARGET_ACTIONS[action] then
        TriggerClientEvent('cpanel:targetAction', target, action, data, src)
        notify(src, ('Acao aplicada em %s.'):format(tname), 'success')
        logAction(src, action, tname)

    else
        notify(src, 'Acao desconhecida.', 'error')
    end
end)

---------------------------------------------------------------------
-- Comandos de chat
---------------------------------------------------------------------
local function adminCommand(name, handler)
    RegisterCommand(name, function(src, args, raw)
        if not isAdmin(src) then
            notify(src, ('Sem permissao para usar /%s'):format(name), 'error')
            return
        end
        handler(src, args, raw)
    end, false)
end

adminCommand('car', function(src, args)
    if src == 0 then
        notify(src, 'Use /car in-game (o console nao possui personagem).', 'error')
        return
    end
    if not args[1] then
        notify(src, 'Uso: /car <modelo>  |  ex: /car adder', 'error')
        return
    end
    TriggerClientEvent('cpanel:selfAction', src, 'spawnCar', { model = args[1] })
    logAction(src, '/car', args[1])
end)

adminCommand('god', function(src)
    if src == 0 then
        notify(src, 'Use /god in-game.', 'error')
        return
    end
    TriggerClientEvent('cpanel:selfAction', src, 'toggleGod', {})
    logAction(src, '/god')
end)

adminCommand('arma', function(src, args)
    if src == 0 then
        notify(src, 'Use /arma in-game.', 'error')
        return
    end
    if not args[1] then
        notify(src, 'Uso: /arma <arma> [munição]  |  ex: /arma pistol 250  (ou /arma all)', 'error')
        return
    end
    local ammo = tonumber(args[2]) or 250
    TriggerClientEvent('cpanel:selfAction', src, 'giveWeapon', { weapon = args[1], ammo = ammo })
    logAction(src, '/arma', args[1])
end)

adminCommand('hp', function(src)
    if src == 0 then
        notify(src, 'Use /hp in-game.', 'error')
        return
    end
    TriggerClientEvent('cpanel:selfAction', src, 'heal', {})
    logAction(src, '/hp')
end)

adminCommand('kill', function(src, args)
    if src == 0 then
        notify(src, 'Uso: /kill <id>', 'error')
        return
    end
    local target = tonumber(args[1])
    if target then
        if not GetPlayerName(target) then
            notify(src, 'Jogador nao encontrado.', 'error')
            return
        end
        TriggerClientEvent('cpanel:targetAction', target, 'kill', {}, src)
        notify(src, ('%s morto.'):format(GetPlayerName(target)), 'success')
        logAction(src, '/kill', args[1])
        return
    end
    TriggerClientEvent('cpanel:selfAction', src, 'kill', {})
    logAction(src, '/kill')
end)

adminCommand('invis', function(src)
    if src == 0 then
        notify(src, 'Use /invis in-game.', 'error')
        return
    end
    TriggerClientEvent('cpanel:selfAction', src, 'toggleInvis', {})
    logAction(src, '/invis')
end)

adminCommand('noclip', function(src)
    if src == 0 then
        notify(src, 'Use /noclip in-game.', 'error')
        return
    end
    TriggerClientEvent('cpanel:selfAction', src, 'toggleNoclip', {})
    logAction(src, '/noclip')
end)

adminCommand('fix', function(src)
    if src == 0 then
        notify(src, 'Use /fix in-game.', 'error')
        return
    end
    TriggerClientEvent('cpanel:selfAction', src, 'fix', {})
    logAction(src, '/fix')
end)

adminCommand('dv', function(src)
    if src == 0 then
        notify(src, 'Use /dv in-game.', 'error')
        return
    end
    TriggerClientEvent('cpanel:selfAction', src, 'deleteNearest', {})
    logAction(src, '/dv')
end)

adminCommand('dvall', function(src, args)
    if src == 0 then
        notify(src, 'Use /dvall in-game.', 'error')
        return
    end
    local radius = tonumber(args[1])
    if not radius then
        notify(src, 'Uso: /dvall <raio em metros>  |  ex: /dvall 100', 'error')
        return
    end
    TriggerClientEvent('cpanel:selfAction', src, 'deleteRadius', { radius = radius })
    logAction(src, '/dvall', args[1])
end)

adminCommand('tp', function(src, args)
    local target = tonumber(args[1])
    if not target then
        notify(src, 'Uso: /tp <id>', 'error')
        return
    end
    if not isAdmin(src) then return end
    local ped = GetPlayerPed(target)
    if not ped or ped <= 0 then
        notify(src, 'Jogador nao encontrado.', 'error')
        return
    end
    if src == 0 then
        notify(src, 'O console nao possui personagem para teleportar.', 'error')
        return
    end
    TriggerClientEvent('cpanel:teleport', src, GetEntityCoords(ped))
    notify(src, ('Teleportado ate %s.'):format(GetPlayerName(target)), 'success')
    logAction(src, '/tp', args[1])
end)

adminCommand('bring', function(src, args)
    local target = tonumber(args[1])
    if not target then
        notify(src, 'Uso: /bring <id>', 'error')
        return
    end
    if src == 0 then
        notify(src, 'O console nao pode trazer jogadores.', 'error')
        return
    end
    local tped = GetPlayerPed(target)
    local ped = GetPlayerPed(src)
    if not tped or tped <= 0 or not ped or ped <= 0 then
        notify(src, 'Jogador nao encontrado.', 'error')
        return
    end
    TriggerClientEvent('cpanel:teleport', target, GetEntityCoords(ped))
    TriggerClientEvent('cpanel:notify', target, 'Um admin te trouxe ate a posicao dele.', 'warning')
    notify(src, ('%s trazido ate voce.'):format(GetPlayerName(target)), 'success')
    logAction(src, '/bring', args[1])
end)

adminCommand('freeze', function(src, args)
    local target = tonumber(args[1])
    if not target or not GetPlayerName(target) then
        notify(src, 'Uso: /freeze <id> (jogador invalido)', 'error')
        return
    end
    TriggerClientEvent('cpanel:targetAction', target, 'freeze', {}, src)
    notify(src, ('Congelando/descongelando %s.'):format(GetPlayerName(target)), 'success')
    logAction(src, '/freeze', args[1])
end)

adminCommand('anuncio', function(src, args)
    local msg = table.concat(args, ' ')
    if msg == '' then
        notify(src, 'Uso: /anuncio <mensagem>', 'error')
        return
    end
    broadcast(msg, (src == 0) and 'CONSOLE' or GetPlayerName(src))
    logAction(src, '/anuncio', msg)
end)

print('^2[cpanel]^0 painel admin carregado. Comando: /cpanel  |  permissao ace: cpanel.use')
