-- nopolicia | cliente
-- Impede que a policia NPC (patrulhas, viaturas despachadas e cops de cenario)
-- persiga ou atire nos jogadores.

local bloqueado = true

-- Tipos de "dispatch" que pertencem a policia (ver ENABLE_DISPATCH_SERVICE).
--   1 = carro  | 2 = helicoptero | 4 = swat      | 6 = motociclista
--   7 = veiculo solicitado | 8 = barreira      | 9/10 = patrulha
--   13 = swat helicoptero   | 14 = barco       | 15 = exercito
-- 3 (bombeiros), 5 (ambulancia) e 11 (gangues) NAO sao bloqueados.
local DISPATCH_POLICIA = { 1, 2, 4, 6, 7, 8, 9, 10, 13, 14, 15 }

-- Raio (em metros) usado para limpar a policia que ja chegou no jogador
local RAIO_LIMPEZA = 150.0

-- Avisa no chat (F8/chat)
local function notify(msg, color)
    TriggerEvent('chat:addMessage', {
        color = color or { 0, 200, 255 },
        args = { 'Policia', msg }
    })
end

-- Liga o bloqueio: policia nao nasce, nao e despachada e ignora o jogador
local function aplicarBloqueio()
    local pid = PlayerId()

    -- Impede o nascimento de policia aleatoria (patrulhas e cops de cenario)
    SetCreateRandomCops(false)
    SetCreateRandomCopsNotOnScenarios(false)
    SetCreateRandomCopsOnScenarios(false)

    -- Nenhuma viatura e despachada para este jogador
    SetDispatchCopsForPlayer(pid, false)

    -- A policia ignora o jogador (nao reage a crimes e nao pede reforco)
    SetPoliceIgnorePlayer(pid, true)

    -- Sem nivel de procurado -> sem motivo para a policia aparecer
    SetMaxWantedLevel(0)
    ClearPlayerWantedLevel(pid)

    -- Desliga os tipos de dispatch da policia
    for _, tipo in ipairs(DISPATCH_POLICIA) do
        EnableDispatchService(tipo, false)
    end
end

-- Desfaz o bloqueio (usado quando o admin libera a policia)
local function aplicarLiberacao()
    local pid = PlayerId()

    SetCreateRandomCops(true)
    SetCreateRandomCopsNotOnScenarios(true)
    SetCreateRandomCopsOnScenarios(true)

    SetDispatchCopsForPlayer(pid, true)
    SetPoliceIgnorePlayer(pid, false)

    SetMaxWantedLevel(5)

    for _, tipo in ipairs(DISPATCH_POLICIA) do
        EnableDispatchService(tipo, true)
    end
end

-- O servidor manda o estado (bloqueado = true/false)
RegisterNetEvent('nopolicia:set', function(estado)
    bloqueado = estado and true or false

    if bloqueado then
        aplicarBloqueio()
        notify('Policia NPC bloqueada.', { 80, 255, 120 })
    else
        aplicarLiberacao()
        notify('Policia NPC liberada.', { 255, 200, 80 })
    end
end)

-- Mantem o bloqueio ativo: os natives sao reassertados de tempos em tempos
-- (outros sistemas do jogo podem reativar o wanted level) e a policia que
-- ja estava chegando no jogador e removida da area.
CreateThread(function()
    while true do
        if bloqueado then
            aplicarBloqueio()

            local pos = GetEntityCoords(PlayerPedId())
            ClearAreaOfCops(pos.x, pos.y, pos.z, RAIO_LIMPEZA, true)

            Wait(1000)
        else
            Wait(2000)
        end
    end
end)

-- Pega o estado atual assim que entra no servidor
CreateThread(function()
    Wait(1000)
    TriggerServerEvent('nopolicia:requestState')
end)

-- O comando pede permissao ao servidor antes de alternar
RegisterCommand('police', function()
    TriggerServerEvent('nopolicia:toggle')
end, false)

-- Sugestao no chat
TriggerEvent('chat:addSuggestion', '/police', 'Liga/desliga o bloqueio da policia NPC (admins)')

-- Ao parar o recurso, devolve a policia ao normal
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    aplicarLiberacao()
end)
