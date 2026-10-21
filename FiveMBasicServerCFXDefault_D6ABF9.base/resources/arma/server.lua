-- Só quem tem a permissão 'command.arma' pode usar o /arma
-- (no server.cfg, group.admin já tem 'command allow', que cobre command.*)
RegisterNetEvent('arma:give', function(weaponName, ammo)
    local src = source

    if not IsPlayerAceAllowed(src, 'command.arma') then
        TriggerClientEvent('chat:addMessage', src, {
            color = { 255, 80, 80 },
            args = { 'Arma', 'Sem permissão. Este comando é exclusivo para admins.' }
        })
        return
    end

    -- Sanitiza o nome da arma: só letras, números e "_"
    weaponName = tostring(weaponName or ''):lower():gsub('[^%w_]', '')

    if weaponName == '' then
        TriggerClientEvent('chat:addMessage', src, {
            color = { 255, 80, 80 },
            args = { 'Arma', 'Uso: /arma <nome_da_arma> [munição]  (ex: /arma pistol 200)' }
        })
        return
    end

    ammo = math.floor(tonumber(ammo) or 120)
    if ammo < 1 then ammo = 1 end
    if ammo > 9999 then ammo = 9999 end

    TriggerClientEvent('arma:giveClient', src, weaponName, ammo)
end)
