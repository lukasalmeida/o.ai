-- nopolicia | servidor
-- Guarda o estado global (policia bloqueada/liberada) e distribui para os clientes.

local bloqueado = true

-- group.admin tem 'command allow' no server.cfg, que cobre command.police
local function isAdmin(src)
    if src == 0 then return true end
    return IsPlayerAceAllowed(src, 'command.police') or IsPlayerAceAllowed(src, 'nopolicia.use')
end

local function nomeDe(src)
    if src == 0 then return 'CONSOLE' end
    return GetPlayerName(src) or ('Jogador %s'):format(src)
end

-- Manda o estado atual para todos os clientes conectados
local function aplicarParaTodos()
    for _, id in ipairs(GetPlayers()) do
        TriggerClientEvent('nopolicia:set', tonumber(id), bloqueado)
    end
end

-- Alterna o bloqueio e avisa todo mundo
local function alternar(src)
    bloqueado = not bloqueado
    aplicarParaTodos()

    print(('[nopolicia] %s alternou o bloqueio da policia NPC (%s)'):format(
        nomeDe(src), bloqueado and 'BLOQUEADA' or 'LIBERADA'))

    local mensagem = ('Policia NPC %s por %s.'):format(
        bloqueado and 'BLOQUEADA' or 'LIBERADA', nomeDe(src))

    for _, id in ipairs(GetPlayers()) do
        TriggerClientEvent('chat:addMessage', tonumber(id), {
            color = bloqueado and { 80, 255, 120 } or { 255, 200, 80 },
            args = { 'Policia', mensagem }
        })
    end

    return bloqueado
end

-- O cliente pede o estado ao entrar
RegisterNetEvent('nopolicia:requestState', function()
    TriggerClientEvent('nopolicia:set', source, bloqueado)
end)

-- /police - alterna o bloqueio (somente admins)
RegisterNetEvent('nopolicia:toggle', function()
    local src = source

    if not isAdmin(src) then
        TriggerClientEvent('chat:addMessage', src, {
            color = { 255, 80, 80 },
            args = { 'Policia', 'Sem permissao. Este comando e exclusivo para admins.' }
        })
        return
    end

    alternar(src)
end)

-- Usado pelo cpanel (roda no servidor, nao pelo cliente)
exports('getState', function()
    return bloqueado
end)

exports('setState', function(estado)
    bloqueado = estado and true or false
    aplicarParaTodos()
    return bloqueado
end)

exports('toggle', function(src)
    src = tonumber(src) or 0
    return alternar(src)
end)
