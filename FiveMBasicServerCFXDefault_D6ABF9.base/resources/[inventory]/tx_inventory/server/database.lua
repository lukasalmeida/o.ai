-- ==========================================================
--  TX_INVENTORY | BANCO DE DADOS (oxmysql / ghmattimysql)
--  Camada de abstração: o resto do script não sabe qual
--  driver está rodando.
-- ==========================================================

TXDB = {}

local provider = nil

-- Espera o driver de banco ficar disponível
CreateThread(function()
    while true do
        if Config.Database == 'oxmysql' or Config.Database == 'auto' then
            if GetResourceState('oxmysql') == 'started' then
                provider = 'oxmysql'
                break
            end
        end
        if Config.Database == 'ghmattimysql' or Config.Database == 'auto' then
            if GetResourceState('ghmattimysql') == 'started' then
                provider = 'ghmattimysql'
                break
            end
        end
        Wait(1000)
    end
    print(('[tx_inventory] driver de banco de dados: %s'):format(provider))
end)

--- Verdadeiro quando o banco está pronto
function TXDB.IsReady()
    return provider ~= nil
end

--- O driver devolve um objeto de erro ({ code = ..., message = ... }) quando a query falha
local function IsErrorResult(res)
    return type(res) == 'table' and (res.error ~= nil or res.code ~= nil)
end

--- Executa uma query e devolve o resultado (table)
function TXDB.Query(sql, params)
    params = params or {}

    if provider == 'oxmysql' then
        local p = promise.new()
        exports.oxmysql:query(sql, params, function(res)
            if IsErrorResult(res) then
                p:resolve({})
            else
                p:resolve(res or {})
            end
        end)
        return Citizen.Await(p)

    elseif provider == 'ghmattimysql' then
        local p = promise.new()
        exports.ghmattimysql:execute(sql, params, function(res)
            if IsErrorResult(res) then
                p:resolve({})
            else
                p:resolve(res or {})
            end
        end)
        return Citizen.Await(p)
    end

    return {}
end

--- Primeira linha do resultado
function TXDB.Single(sql, params)
    local res = TXDB.Query(sql, params)
    if type(res) == 'table' then
        return res[1]
    end
    return nil
end

--- Executa INSERT e devolve o insertId
function TXDB.Insert(sql, params)
    local res = TXDB.Query(sql, params)
    if type(res) == 'table' then
        return res.insertId or res.lastInsertId or 0
    end
    return 0
end

--- UPDATE/DELETE — devolve affectedRows
function TXDB.Execute(sql, params)
    local res = TXDB.Query(sql, params)
    if type(res) == 'table' then
        return res.affectedRows or 0
    end
    return 0
end

-- ==========================================================
--  TESTE DE CONEXÃO
-- ==========================================================
CreateThread(function()
    while not TXDB.IsReady() do Wait(500) end

    local res = TXDB.Query('SELECT 1 AS ping')
    if type(res) == 'table' and res[1] and res[1].ping == 1 then
        print('[tx_inventory] conexão com o banco de dados OK.')
    else
        print('^1[tx_inventory]^7 falha ao conectar no banco de dados. '
            .. 'Verifique "set mysql_connection_string" no server.cfg e se o oxmysql está iniciado.')
    end
end)

-- ==========================================================
--  CRIAÇÃO AUTOMÁTICA DAS TABELAS
--  (evita depender de importação manual do .sql)
-- ==========================================================
CreateThread(function()
    while not TXDB.IsReady() do Wait(500) end
    Wait(1500)

    TXDB.Query([[
        CREATE TABLE IF NOT EXISTS `]] .. Config.Table .. [[` (
            `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `identifier` VARCHAR(64)  NOT NULL,
            `item_name`  VARCHAR(64)  NOT NULL,
            `slot`       TINYINT      NOT NULL DEFAULT 0,
            `amount`     INT UNSIGNED NOT NULL DEFAULT 1,
            `metadata`   TEXT         NULL,
            `equipped`   TINYINT(1)   NOT NULL DEFAULT 0,
            `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `idx_ident` (`identifier`),
            KEY `idx_ident_slot` (`identifier`, `slot`),
            KEY `idx_item` (`item_name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    TXDB.Query([[
        CREATE TABLE IF NOT EXISTS `]] .. Config.GroundTable .. [[` (
            `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `instance`   VARCHAR(64)  NOT NULL,
            `item_name`  VARCHAR(64)  NOT NULL,
            `amount`     INT UNSIGNED NOT NULL DEFAULT 1,
            `metadata`   TEXT         NULL,
            `x`          DOUBLE       NOT NULL DEFAULT 0,
            `y`          DOUBLE       NOT NULL DEFAULT 0,
            `z`          DOUBLE       NOT NULL DEFAULT 0,
            `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `expires_at` TIMESTAMP    NULL DEFAULT NULL,
            PRIMARY KEY (`id`),
            UNIQUE KEY `uniq_instance` (`instance`),
            KEY `idx_pos` (`x`,`y`,`z`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- SHOW TABLES LIKE exige aspas simples (o padrão é texto, não identificador)
    local check = TXDB.Query(('SHOW TABLES LIKE \'%s\''):format(Config.Table))
    if type(check) == 'table' and check[1] then
        print('[tx_inventory] tabelas verificadas/criadas com sucesso.')
    else
        print('^1[tx_inventory]^7 não foi possível criar/verificar as tabelas no banco. '
            .. 'Importe manualmente o arquivo sql/inventory.sql.')
    end
end)
