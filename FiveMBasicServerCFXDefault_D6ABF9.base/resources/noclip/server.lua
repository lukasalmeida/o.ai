-- Só admins com a permissão 'command.noclip' podem usar o /nc
RegisterNetEvent('noclip:toggle', function()
    local src = source

    if IsPlayerAceAllowed(src, 'command.noclip') then
        TriggerClientEvent('noclip:toggleClient', src)
    else
        TriggerClientEvent('chat:addMessage', src, {
            color = { 255, 80, 80 },
            args = { 'NoClip', 'Sem permissão. Este comando é exclusivo para admins.' }
        })
    end
end)
