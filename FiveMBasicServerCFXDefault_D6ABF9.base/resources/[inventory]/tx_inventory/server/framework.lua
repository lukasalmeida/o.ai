-- ==========================================================
--  TX_INVENTORY | ADAPTER DE FRAMEWORK (servidor)
--  ----------------------------------------------------------
--  Suporta: standalone | ESX | QBCore | vRP
--  O núcleo do inventário NÃO depende do framework: apenas
--  este arquivo precisa ser ajustado caso você use um
--  framework muito customizado.
-- ==========================================================

TXFW = {}

TXFW.type      = 'standalone'
TXFW.ready     = false
TXFW.players   = {}   -- [src] = dados do framework (nome, cargo, dinheiro)

-- ==========================================================
--  DETECÇÃO
-- ==========================================================
CreateThread(function()
    while true do
        local wanted = Config.Framework

        if wanted == 'auto' then
            if GetResourceState('es_extended') == 'started' then
                wanted = 'esx'
            elseif GetResourceState('qb-core') == 'started' then
                wanted = 'qbcore'
            elseif GetResourceState('vRP') == 'started' then
                wanted = 'vrp'
            else
                wanted = 'standalone'
            end
        end

        if wanted == 'esx' and GetResourceState('es_extended') == 'started' then
            ESX = exports['es_extended']:getSharedObject()
            TXFW.type = 'esx'

        elseif wanted == 'qbcore' and GetResourceState('qb-core') == 'started' then
            QBCore = exports['qb-core']:GetCoreObject()
            TXFW.type = 'qbcore'

        elseif wanted == 'vrp' and GetResourceState('vRP') == 'started' then
            TXFW.type = 'vrp'
        end

        TXFW.ready = true
        print(('[tx_inventory] framework detectado: %s'):format(TXFW.type))
        break
    end
end)

-- ==========================================================
--  HELPERS
-- ==========================================================
--- Identificador principal do jogador (license > steam > id)
function TXFW.GetIdentifier(src)
    local ids = GetPlayerIdentifiers(src) or {}
    for i = 1, #ids do
        if ids[i]:sub(1, 8) == 'license:' then return ids[i] end
    end
    for i = 1, #ids do
        if ids[i]:sub(1, 6) == 'steam:' then return ids[i] end
    end
    return ids[1] or ('unknown:' .. tostring(src))
end

--- Nome do jogador
function TXFW.GetName(src)
    if TXFW.type == 'esx' and ESX then
        local p = ESX.GetPlayerFromId(src)
        if p then return p.getName() end
    elseif TXFW.type == 'qbcore' and QBCore then
        local p = QBCore.Functions.GetPlayer(src)
        if p then return p.PlayerData.charinfo.firstname .. ' ' .. p.PlayerData.charinfo.lastname end
    end
    return GetPlayerName(src) or ('Jogador ' .. src)
end

--- Dinheiro do jogador (usado só na UI)
function TXFW.GetMoney(src)
    if TXFW.type == 'esx' and ESX then
        local p = ESX.GetPlayerFromId(src)
        if p then return p.getMoney() or 0 end
    elseif TXFW.type == 'qbcore' and QBCore then
        local p = QBCore.Functions.GetPlayer(src)
        if p then return p.PlayerData.money['cash'] or 0 end
    end
    return 0
end

--- Cargo/emprego do jogador
function TXFW.GetJob(src)
    if TXFW.type == 'esx' and ESX then
        local p = ESX.GetPlayerFromId(src)
        if p then return p.getJob().label or p.getJob().name end
    elseif TXFW.type == 'qbcore' and QBCore then
        local p = QBCore.Functions.GetPlayer(src)
        if p then return p.PlayerData.job.label or p.PlayerData.job.name end
    end
    return 'Desempregado'
end

--- Valor em dinheiro formatado
function TXFW.FormatMoney(value)
    local v = tonumber(value) or 0
    if TXFW.type == 'qbcore' and QBCore then
        return ('$%s'):format(Comma(v))
    end
    return ('$%s'):format(Comma(v))
end

function Comma(n)
    local s = tostring(math.floor((tonumber(n) or 0) + 0.5))
    local formatted = s:reverse():gsub('(%d%d%d)', '%1,'):reverse()
    return (formatted:gsub('^,', ''))
end

-- ==========================================================
--  HOOKS DE LOAD / UNLOAD (otimização: carrega antes do uso)
--  O inventário também é carregado sob demanda, então mesmo
--  sem framework funciona normalmente.
-- ==========================================================
RegisterNetEvent('txinv:framework:loaded', function(src)
    src = tonumber(src) or source
    TriggerEvent('txinv:playerLoaded', src)
end)

if TXFW.type == 'esx' then
    AddEventHandler('esx:playerLoaded', function(playerId)
        TriggerEvent('txinv:playerLoaded', playerId)
    end)
    AddEventHandler('esx:playerLogout', function(playerId)
        TriggerEvent('txinv:playerUnloaded', playerId)
    end)
end

AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    if player and player.PlayerData then
        TriggerEvent('txinv:playerLoaded', player.PlayerData.source)
    end
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    TriggerEvent('txinv:playerUnloaded', src)
end)
