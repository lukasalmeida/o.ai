-- Só admins com a permissão 'command.god' podem usar o /god
-- (no server.cfg, group.admin já tem 'command allow', que cobre command.*)
RegisterNetEvent('god:toggle', function()
    local src = source

    if IsPlayerAceAllowed(src, 'command.god') then
        TriggerClientEvent('god:toggleClient', src)
    else
        TriggerClientEvent('chat:addMessage', src, {
            color = { 255, 80, 80 },
            args = { 'God', 'Sem permissão. Este comando é exclusivo para admins.' }
        })
    end
end)
