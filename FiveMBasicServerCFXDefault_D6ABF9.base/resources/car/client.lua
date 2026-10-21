local currentVehicle = nil

-- Avisa no chat (F8/chat)
local function notify(msg, color)
    TriggerEvent('chat:addMessage', {
        color = color or { 0, 200, 255 },
        args = { 'Car', msg }
    })
end

local function spawnVehicle(modelName)
    local model = joaat(modelName)

    -- Verifica se o modelo existe e é um veículo
    if not IsModelInCdimage(model) or not IsModelAVehicle(model) then
        notify(('modelo inválido: %s'):format(modelName), { 255, 80, 80 })
        return
    end

    RequestModel(model)

    -- Espera o modelo carregar (máx. 5s)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) do
        if GetGameTimer() > timeout then
            notify('falha ao carregar o modelo.', { 255, 80, 80 })
            return
        end
        Wait(50)
    end

    local ped = PlayerPedId()
    local heading = GetEntityHeading(ped)

    -- Spawn um pouco à frente do jogador
    local spawn = GetOffsetFromEntityInWorldCoords(ped, 0.0, 5.0, 0.0)

    -- Remove o carro anterior spawnado por este comando
    if currentVehicle and DoesEntityExist(currentVehicle) then
        DeleteVehicle(currentVehicle)
    end

    local veh = CreateVehicle(model, spawn.x, spawn.y, spawn.z, heading, true, false)

    if not DoesEntityExist(veh) then
        notify('falha ao criar o veículo.', { 255, 80, 80 })
        SetModelAsNoLongerNeeded(model)
        return
    end

    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    SetVehicleNumberPlateText(veh, 'O.AI')
    SetPedIntoVehicle(ped, veh, -1) -- -1 = banco do motorista
    SetModelAsNoLongerNeeded(model)

    currentVehicle = veh
    notify(('spawnado: %s'):format(modelName))
end

-- O comando pede permissão ao servidor antes de spawnar
RegisterCommand('car', function(_, args)
    local modelName = args[1]
    if not modelName then
        notify('Uso: /car <nome_do_carro>  (ex: /car adder)', { 255, 200, 80 })
        return
    end
    TriggerServerEvent('car:spawn', modelName)
end, false)

-- O servidor autoriza e manda spawnar no cliente
RegisterNetEvent('car:spawnClient', function(modelName)
    spawnVehicle(modelName)
end)

-- Sugestão no chat
TriggerEvent('chat:addSuggestion', '/car', 'Spawna um veículo (admins)', {
    { name = 'nome_do_carro', help = 'Ex: adder, blazer, sanchez' }
})
TriggerEvent('chat:addSuggestion', '/dv', 'Remove o veículo mais próximo (admins)')
TriggerEvent('chat:addSuggestion', '/dvall', 'Remove todos os veículos no raio informado (admins)', {
    { name = 'raio', help = 'Raio em metros (ex: 100)' }
})

-- Remove um veículo com segurança
local function deleteVehicle(veh)
    SetEntityAsMissionEntity(veh, true, true)

    if DoesEntityExist(veh) then
        DeleteVehicle(veh)
    end
end

-- /dv - remove o veículo mais próximo
RegisterCommand('dv', function()
    TriggerServerEvent('car:deleteNearest')
end, false)

RegisterNetEvent('car:deleteNearestClient', function()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local veh = GetVehiclePedIsIn(ped, false) ~= 0 and GetVehiclePedIsIn(ped, false) or nil

    -- Se não estiver num veículo, procura o mais próximo
    if not veh then
        local vehicles = GetGamePool('CVehicle')
        local closest, closestDist = nil, 10.0 -- máx. 10m

        for _, v in ipairs(vehicles) do
            local dist = #(pos - GetEntityCoords(v))
            if dist < closestDist then
                closest, closestDist = v, dist
            end
        end

        veh = closest
    end

    if veh then
        deleteVehicle(veh)
        notify('veículo removido.')
    else
        notify('nenhum veículo por perto.', { 255, 200, 80 })
    end
end)

-- /dvall <raio> - remove todos os veículos dentro do raio
RegisterCommand('dvall', function(_, args)
    local radius = tonumber(args[1])
    if not radius then
        notify('Uso: /dvall <raio em metros>  (ex: /dvall 100)', { 255, 200, 80 })
        return
    end
    TriggerServerEvent('car:deleteRadius', radius)
end, false)

RegisterNetEvent('car:deleteRadiusClient', function(radius)
    local pos = GetEntityCoords(PlayerPedId())
    local vehicles = GetGamePool('CVehicle')
    local count = 0

    for _, v in ipairs(vehicles) do
        if #(pos - GetEntityCoords(v)) <= radius then
            deleteVehicle(v)
            count = count + 1
        end
    end

    notify(('%d veículo(s) removido(s) em %dm:'):format(count, radius))
end)
