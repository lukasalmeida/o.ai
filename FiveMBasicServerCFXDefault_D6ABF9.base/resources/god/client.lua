local godMode = false

-- Avisa no chat (F8/chat)
local function notify(msg, color)
    TriggerEvent('chat:addMessage', {
        color = color or { 0, 200, 255 },
        args = { 'God', msg }
    })
end

-- Liga/desliga a invencibilidade
local function setGod(enabled)
    godMode = enabled

    local ped = PlayerPedId()

    if ped ~= -1 then
        SetEntityInvincible(ped, enabled)
        SetPlayerInvincible(PlayerId(), enabled)
    end
end

-- Revive o jogador no exato lugar onde morreu
local function revivePlayer()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    -- mesmo native usado pelo spawnmanager para nascer de volta
    NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, heading, true, true, false)

    ped = PlayerPedId()

    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetPedArmour(ped, 100)
    ClearPedTasksImmediately(ped)
end

-- O comando pede permissão ao servidor antes de alternar
RegisterCommand('god', function()
    TriggerServerEvent('god:toggle')
end, false)

-- O servidor autoriza e manda alternar de volta
RegisterNetEvent('god:toggleClient', function()
    -- morto: revive e liga o modo god
    if IsEntityDead(PlayerPedId()) then
        revivePlayer()
        setGod(true)
        notify('revivido | modo god ATIVADO', { 80, 255, 120 })
        return
    end

    setGod(not godMode)

    if godMode then
        notify('modo god ATIVADO', { 80, 255, 120 })
    else
        notify('modo god DESATIVADO', { 255, 200, 80 })
    end
end)

-- Sugestão no chat
TriggerEvent('chat:addSuggestion', '/god', 'Revive (se morto) e alterna o modo god (admins)')

-- Mantém a invencibilidade ligada enquanto o modo estiver ativo
-- (o spawnmanager desliga a invencibilidade ao terminar o respawn)
CreateThread(function()
    while true do
        if godMode then
            local ped = PlayerPedId()

            if ped ~= -1 then
                SetEntityInvincible(ped, true)
                SetPlayerInvincible(PlayerId(), true)
            end

            Wait(0)
        else
            Wait(500)
        end
    end
end)
