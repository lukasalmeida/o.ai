-- Só quem tem a permissão 'command.car' pode usar o /car
-- (no server.cfg, group.admin já tem 'command allow', que cobre command.*)
RegisterNetEvent('car:spawn', function(model)
    local src = source

    if not IsPlayerAceAllowed(src, 'command.car') then
        TriggerClientEvent('chat:addMessage', src, {
            color = { 255, 80, 80 },
            args = { 'Car', 'Sem permissão. Este comando é exclusivo para admins.' }
        })
        return
    end

    -- Sanitiza o nome do modelo: só letras, números e "_"
    model = tostring(model or ''):lower():gsub('[^%w_]', '')

    if model == '' then
        TriggerClientEvent('chat:addMessage', src, {
            color = { 255, 80, 80 },
            args = { 'Car', 'Uso: /car <nome_do_carro>  (ex: /car adder)' }
        })
        return
    end

    TriggerClientEvent('car:spawnClient', src, model)
end)

-- /dv - remove o veículo mais próximo
RegisterNetEvent('car:deleteNearest', function()
    local src = source

    if not IsPlayerAceAllowed(src, 'command.dv') then
        TriggerClientEvent('chat:addMessage', src, {
            color = { 255, 80, 80 },
            args = { 'Car', 'Sem permissão. Este comando é exclusivo para admins.' }
        })
        return
    end

    TriggerClientEvent('car:deleteNearestClient', src)
end)

-- /dvall <raio> - remove todos os veículos dentro do raio informado (em metros)
RegisterNetEvent('car:deleteRadius', function(radius)
    local src = source

    if not IsPlayerAceAllowed(src, 'command.dv') then
        TriggerClientEvent('chat:addMessage', src, {
            color = { 255, 80, 80 },
            args = { 'Car', 'Sem permissão. Este comando é exclusivo para admins.' }
        })
        return
    end

    radius = tonumber(radius)

    if not radius or radius ~= math.floor(radius) or radius < 1 or radius > 500 then
        TriggerClientEvent('chat:addMessage', src, {
            color = { 255, 80, 80 },
            args = { 'Car', 'Uso: /dvall <raio em metros>  (ex: /dvall 100)' }
        })
        return
    end

    TriggerClientEvent('car:deleteRadiusClient', src, radius)
end)
