-- tx_hud | servidor
-- Mantem o contador de jogadores online e repassa dados do HUD para os clients.

local playerData = {} -- [serverId] = { name=, level=, xp={current,needed}, money={cash,bank} }

-- ---------------------------------------------------------------------
-- Contador de jogadores online (envia a cada 5s)
-- ---------------------------------------------------------------------
CreateThread(function()
    while true do
        local players = GetPlayers()
        TriggerClientEvent('txhud:players', -1, #players)
        Wait(5000)
    end
end)

-- ---------------------------------------------------------------------
-- Dados do jogador
-- ---------------------------------------------------------------------
AddEventHandler('playerDropped', function()
    playerData[source] = nil
end)

RegisterNetEvent('txhud:slotChanged', function(slot)
    -- hook: reenvie o slot selecionado para o inventario (tx_inventory, etc.)
    TriggerEvent('tx:hud:slotChanged', source, slot)
end)

RegisterNetEvent('txhud:setMoney', function(cash, bank)
    local id = source
    local data = playerData[id] or {}
    data.money = { cash = cash or 0, bank = bank or 0 }
    playerData[id] = data
    TriggerClientEvent('txhud:playerData', id, data)
end)

RegisterNetEvent('txhud:setXp', function(level, current, needed)
    local id = source
    local data = playerData[id] or {}
    data.level = level or 1
    data.xp = { current = current or 0, needed = needed or 100 }
    playerData[id] = data
    TriggerClientEvent('txhud:playerData', id, data)
end)

RegisterNetEvent('txhud:setSlots', function(slots)
    TriggerClientEvent('txhud:slots', source, slots)
end)

RegisterNetEvent('txhud:setTasks', function(tasks)
    TriggerClientEvent('txhud:tasks', source, tasks)
end)

RegisterNetEvent('txhud:alert', function(text, danger)
    TriggerClientEvent('txhud:alert', source, text, danger)
end)

-- ---------------------------------------------------------------------
-- Exports para outros recursos (server)
-- ---------------------------------------------------------------------
exports('GetPlayerHudData', function(serverId)
    return playerData[serverId]
end)

exports('SetPlayerHudData', function(serverId, data)
    playerData[serverId] = data
    TriggerClientEvent('txhud:playerData', serverId, data)
end)

exports('BroadcastHudTasks', function(tasks)
    TriggerClientEvent('txhud:tasks', -1, tasks)
end)

exports('BroadcastHudAlert', function(text, danger)
    TriggerClientEvent('txhud:alert', -1, text, danger)
end)
