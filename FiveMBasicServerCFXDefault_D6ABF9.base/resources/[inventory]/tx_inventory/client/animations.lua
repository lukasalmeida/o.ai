-- ==========================================================
--  TX_INVENTORY | ANIMAÇÕES
--  Wrapper resiliente: se o dict/clip não existir no GTA do
--  servidor, a animação é ignorada sem quebrar o sistema.
-- ==========================================================

TXAnim = {}

--- Toca uma animação e devolve true se realmente rodou
---@param anim table { dict, clip, dur, flag }
---@return boolean
function TXAnim.Play(anim, ped)
    if not anim or not anim.dict or not anim.clip then return false end
    ped = ped or PlayerPedId()

    if not IsEntityAlive(ped) then return false end

    RequestAnimDict(anim.dict)
    local timeout = 0
    while not HasAnimDictLoaded(anim.dict) and timeout < 2000 do
        Citizen.Wait(10)
        timeout = timeout + 10
    end

    if not HasAnimDictLoaded(anim.dict) then
        if Config.Debug then
            print(('[tx_inventory] dict de animação não encontrado: %s'):format(anim.dict))
        end
        return false
    end

    TaskPlayAnim(ped, anim.dict, anim.clip, 3.0, -3.0, anim.dur or 800, anim.flag or 0.0, 0.0, 0.0, false, false, false, false, 0, false)
    return true
end

--- Espera a animação terminar (com timeout)
function TXAnim.WaitAnim(anim, ped)
    if not TXAnim.Play(anim, ped) then
        Citizen.Wait(400)
        return false
    end
    local timeout = 0
    local max = (anim.dur or 800) + 800
    while timeout < max do
        if not IsEntityPlayingAnim(ped, anim.dict, anim.clip, 3) then return true end
        Citizen.Wait(30)
        timeout = timeout + 30
    end
    return true
end

function TXAnim.Drop()
    return TXAnim.Play(Config.Animations.drop)
end

function TXAnim.Pickup()
    return TXAnim.Play(Config.Animations.pickup)
end

function TXAnim.Give()
    return TXAnim.Play(Config.Animations.give)
end
