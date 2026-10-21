-- Avisa no chat (F8/chat)
local function notify(msg, color)
    TriggerEvent('chat:addMessage', {
        color = color or { 0, 200, 255 },
        args = { 'Arma', msg }
    })
end

-- Aceita "pistol" ou "weapon_pistol" e valida no jogo
local function normalizeWeapon(name)
    name = name:lower()
    if not name:find('^weapon_') then
        name = 'weapon_' .. name
    end
    return joaat(name)
end

local function giveWeapon(weaponName, ammo)
    local hash = normalizeWeapon(weaponName)

    if not IsWeaponValid(hash) then
        notify(('arma inválida: %s'):format(weaponName), { 255, 80, 80 })
        return
    end

    local ped = PlayerPedId()

    GiveWeaponToPed(ped, hash, ammo, false, true)
    SetPedAmmo(ped, hash, ammo)
    SetCurrentPedWeapon(ped, hash, true)

    notify(('recebida: %s (%d munição)'):format(weaponName:gsub('^weapon_', ''), ammo))
end

-- O comando pede permissão ao servidor antes de spawnar
RegisterCommand('arma', function(_, args)
    local weaponName = args[1]
    if not weaponName then
        notify('Uso: /arma <nome_da_arma> [munição]  (ex: /arma pistol 200)', { 255, 200, 80 })
        return
    end
    TriggerServerEvent('arma:give', weaponName, args[2])
end, false)

-- O servidor autoriza e manda spawnar no cliente
RegisterNetEvent('arma:giveClient', function(weaponName, ammo)
    giveWeapon(weaponName, ammo)
end)

-- Sugestão no chat
TriggerEvent('chat:addSuggestion', '/arma', 'Dá uma arma (admins)', {
    { name = 'nome_da_arma', help = 'Ex: pistol, smg, carbinerifle' },
    { name = 'municao', help = 'Quantidade de munição (padrão: 120)' }
})
