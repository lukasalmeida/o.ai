-- ==========================================================
--  TX_INVENTORY | EFEITOS DE CONSUMÍVEIS + STATUS
--  ----------------------------------------------------------
--  Sistema simples de fome/sede com suporte a integrate
--  com frameworks (a vida máxima é limitada pelo status).
-- ==========================================================

TXStatus = {
    hunger = 100.0,
    thirst = 100.0,
    alive = true,
}

-- ==========================================================
--  HELPERS
-- ==========================================================
local function GetPed()
    return PlayerPedId()
end

--- Aplica um conjunto de efeitos { heal, armor, hunger, thirst }
function TXStatus.ApplyEffects(effects)
    if not effects then return end
    local ped = GetPed()

    if effects.heal then
        local maxHealth = GetEntityMaxHealth(ped)
        local health = GetEntityHealth(ped)
        local newHealth = math.min(maxHealth, health + math.floor(effects.heal))
        SetEntityHealth(ped, newHealth)
    end

    if effects.armor then
        local pedArmor = GetPedArmour(ped)
        local pedMaxArmor = GetPedMaxArmor(ped)
        SetPedArmour(ped, math.min(pedMaxArmor, pedArmor + math.floor(effects.armor)))
    end

    if effects.hunger then
        TXStatus.hunger = math.max(0, math.min(100, TXStatus.hunger + effects.hunger))
    end

    if effects.thirst then
        TXStatus.thirst = math.max(0, math.min(100, TXStatus.thirst + effects.thirst))
    end

    TXStatus.Save()
    TXStatus.Send()
end

--- Envia o status para o NUI (barra de status opcional)
function TXStatus.Send()
    SendNUIMessage({
        action = 'status',
        data = {
            hunger = TXStatus.hunger,
            thirst = TXStatus.thirst,
        },
    })
end

--- Salva o status (pode ser挂钩 no framework para persistir)
function TXStatus.Save()
    -- Hook: integre aqui o salvamento no framework (ESX/QBCore)
end

-- ==========================================================
--  LOOP DE STATUS
-- ==========================================================
CreateThread(function()
    if not Config.EnableStatus then return end
    local timer = 0
    while true do
        Citizen.Wait(1000)
        timer = timer + 1

        local ped = GetPed()
        if IsEntityDead(ped) then
            TXStatus.alive = false
        else
            TXStatus.alive = true
        end

        -- 1 segundo de jogo = 1 segundo real (ajuste conforme necessário)
        if timer % 60 == 0 then
            TXStatus.hunger = math.max(0, TXStatus.hunger - (Config.HungerPerHour / 60))
            TXStatus.thirst = math.max(0, TXStatus.thirst - (Config.ThirstPerHour / 60))
            TXStatus.Save()
        end

        -- Dano por status zerado
        if TXStatus.hunger <= 0 or TXStatus.thirst <= 0 then
            if not IsEntityDead(ped) and TXStatus.alive then
                ApplyDamage(ped, Config.LowStatusDamage)
            end
        end

        if timer % 5 == 0 then
            TXStatus.Send()
        end
    end
end)

function ApplyDamage(ped, amount)
    if amount <= 0 then return end
    local health = GetEntityHealth(ped)
    if health > 0 then
        SetEntityHealth(ped, health - amount)
    end
end

-- ==========================================================
--  EVENTOS DO SERVIDOR
-- ==========================================================
RegisterNetEvent('txinv:client:useEffect', function(effects, itemName)
    TXStatus.ApplyEffects(effects or {})
    if itemName then
        local def = TXINV.GetItem(itemName)
        if def.effects and def.effects.heal then
            -- já aplicado acima
        end
    end
end)
