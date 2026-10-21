local noclip = false
local speed = 1.0          -- velocidade base (ajustável com o scroll do mouse)
local minSpeed = 0.1
local maxSpeed = 10.0
local speedStep = 0.1

-- Avisa no chat (F8/chat)
local function notify(msg)
    TriggerEvent('chat:addMessage', {
        color = { 0, 200, 255 },
        args = { 'NoClip', msg }
    })
end

-- Converte a rotação da câmera em um vetor direção
local function rotToDir(rot)
    local radZ = math.rad(rot.z)
    local radX = math.rad(rot.x)
    local cosX = math.cos(radX)
    return vector3(-math.sin(radZ) * cosX, math.cos(radZ) * cosX, math.sin(radX))
end

local function toggleNoclip()
    local ped = PlayerPedId()
    noclip = not noclip

    if noclip then
        FreezeEntityPosition(ped, true)
        SetEntityCollision(ped, false, false)
        SetEntityVisible(ped, false, false)
        SetLocalPlayerVisibleLocally(false)
        notify(('ativado | velocidade %.1f (scroll do mouse para ajustar)'):format(speed))
    else
        FreezeEntityPosition(ped, false)
        SetEntityCollision(ped, true, true)
        SetEntityVisible(ped, true, false)
        SetLocalPlayerVisibleLocally(true)

        -- Aterra o jogador na posição atual
        local pos = GetEntityCoords(ped)
        SetEntityCoords(ped, pos.x, pos.y, pos.z, false, false, false, false)

        notify('desativado')
    end
end

-- O comando pede permissão ao servidor antes de alternar
RegisterCommand('nc', function()
    TriggerServerEvent('noclip:toggle')
end, false)

-- O servidor autoriza e manda alternar de volta
RegisterNetEvent('noclip:toggleClient', function()
    toggleNoclip()
end)

-- Sugestão no chat
TriggerEvent('chat:addSuggestion', '/nc', 'Alterna o modo noclip (admins)')

CreateThread(function()
    while true do
        if noclip then
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local camRot = GetGameplayCamRot(2)

            local fwd = rotToDir(camRot)
            local radZ = math.rad(camRot.z)
            local right = vector3(math.cos(radZ), math.sin(radZ), 0.0)

            -- Ajuste de velocidade com o scroll do mouse
            if IsControlPressed(0, 241) then -- scroll up
                speed = math.min(maxSpeed, speed + speedStep)
                notify(('velocidade: %.1f'):format(speed))
            elseif IsControlPressed(0, 242) then -- scroll down
                speed = math.max(minSpeed, speed - speedStep)
                notify(('velocidade: %.1f'):format(speed))
            end

            -- Direção do movimento (câmera como referência)
            local move = vector3(0.0, 0.0, 0.0)
            if IsControlPressed(0, 32) then move = move + fwd end          -- W
            if IsControlPressed(0, 33) then move = move - fwd end          -- S
            if IsControlPressed(0, 34) then move = move - right end        -- A
            if IsControlPressed(0, 35) then move = move + right end        -- D
            if IsControlPressed(0, 38) then move = move + vector3(0,0,1) end -- E (subir)
            if IsControlPressed(0, 44) then move = move - vector3(0,0,1) end -- Q (descer)

            -- SHIFT = turbo (4x)
            local mult = speed
            if IsControlPressed(0, 21) then mult = mult * 4.0 end

            local len = #move
            if len > 0.0 then
                move = (move / len) * (mult * GetFrameTime() * 10.0)
                SetEntityCoordsNoOffset(ped, pos + move, false, false, false)

                -- Alinha o corpo com a câmera
                SetEntityHeading(ped, (360.0 - camRot.z) % 360.0)
            end

            -- Bloqueia ações de combate enquanto está no noclip
            DisableControlAction(0, 24, true)  -- atacar
            DisableControlAction(0, 25, true)  -- mirar
            DisableControlAction(0, 47, true)  -- granada
            DisableControlAction(0, 58, true)  -- arremessar
            DisableControlAction(0, 68, true)  -- trocar arma
            DisableControlAction(0, 69, true)  -- atirar (veículos)
            DisableControlAction(0, 70, true)
            DisableControlAction(0, 91, true)
            DisableControlAction(0, 92, true)
            DisableControlAction(0, 106, true)

            Wait(0)
        else
            Wait(250)
        end
    end
end)
