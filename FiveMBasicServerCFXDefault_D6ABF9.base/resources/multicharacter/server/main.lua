local CurrentCharacter = {} -- src -> charId

local function GetIdentifier(src)
    local identifiers = GetPlayerIdentifiers(src)
    for _, id in ipairs(identifiers) do
        if string.find(id, 'license:') then
            return id
        end
    end
    for _, id in ipairs(identifiers) do
        if string.find(id, 'steam:') then
            return id
        end
    end
    if #identifiers > 0 then return identifiers[1] end
    return nil
end

-- bucket setter
RegisterNetEvent('multichar:server:setBucket')
AddEventHandler('multichar:server:setBucket', function(bucket)
    local src = source
    SetPlayerRoutingBucket(src, bucket or 0)
end)

-- request characters
RegisterNetEvent('multichar:server:requestCharacters')
AddEventHandler('multichar:server:requestCharacters', function()
    local src = source
    local identifier = GetIdentifier(src)
    if not identifier then return end

    MySQL.query('SELECT * FROM characters WHERE identifier = ?', { identifier }, function(result)
        local chars = result or {}
        for _, c in ipairs(chars) do
            if c.skin and c.skin ~= '' and type(c.skin) == 'string' then
                local ok, decoded = pcall(json.decode, c.skin)
                if ok then c.skin = decoded end
            else
                c.skin = nil
            end
            if c.position and c.position ~= '' and type(c.position) == 'string' then
                local ok, decoded = pcall(json.decode, c.position)
                if ok then c.position = decoded end
            else
                c.position = nil
            end
        end
        TriggerClientEvent('multichar:client:loadCharacters', src, chars, Config.MaxSlots)
    end)
end)

-- create character
RegisterNetEvent('multichar:server:createCharacter')
AddEventHandler('multichar:server:createCharacter', function(data)
    local src = source
    local identifier = GetIdentifier(src)
    if not identifier or not data then return end

    MySQL.query('SELECT COUNT(*) as cnt FROM characters WHERE identifier = ?', { identifier }, function(res)
        local count = (res and res[1] and res[1].cnt) or 0
        if count >= Config.MaxSlots then
            TriggerClientEvent('multichar:client:createFailed', src, 'Sem slots disponiveis.')
            return
        end

        local slot = GetNextAvailableSlot(identifier) or 1
        MySQL.insert('INSERT INTO characters (identifier, firstname, lastname, age, sex, skin, position, money, bank, job, last_location, `slot`) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)', {
            identifier,
            data.firstname,
            data.lastname,
            data.age,
            data.sex or 'male',
            nil,
            nil,
            Config.StartMoney,
            Config.StartBank,
            Config.StartJob,
            'Aeroporto Internacional',
            slot
        }, function(id)
            local charData = {
                id = id,
                firstname = data.firstname,
                lastname = data.lastname,
                age = data.age,
                sex = data.sex or 'male'
            }
            TriggerClientEvent('multichar:client:characterCreated', src, id, charData)
        end)
    end)
end)

-- save skin
RegisterNetEvent('multichar:server:saveSkin')
AddEventHandler('multichar:server:saveSkin', function(charId, skin)
    local src = source
    local identifier = GetIdentifier(src)
    if not identifier or not charId then return end

    MySQL.update('UPDATE characters SET skin = ? WHERE id = ? AND identifier = ?', {
        json.encode(skin), charId, identifier
    }, function()
        TriggerClientEvent('multichar:client:skinSaved', src, charId)
    end)
end)

-- select character / spawn
RegisterNetEvent('multichar:server:selectCharacter')
AddEventHandler('multichar:server:selectCharacter', function(charId)
    print('[MULTICHAR] server selectCharacter id=' .. tostring(charId))
    local src = source
    local identifier = GetIdentifier(src)
    if not identifier or not charId then return end

    MySQL.query('SELECT * FROM characters WHERE id = ? AND identifier = ?', { charId, identifier }, function(res)
        if res and res[1] then
            local char = res[1]
            if char.skin and type(char.skin) == 'string' then
                local ok, decoded = pcall(json.decode, char.skin)
                if ok then char.skin = decoded end
            end
            if char.position and type(char.position) == 'string' then
                local ok, decoded = pcall(json.decode, char.position)
                if ok then char.position = decoded end
            end
            CurrentCharacter[src] = char.id
            SetPlayerRoutingBucket(src, 0)
            TriggerClientEvent('multichar:client:spawnCharacter', src, char)
        end
    end)
end)

-- save position
RegisterNetEvent('multichar:server:savePosition')
AddEventHandler('multichar:server:savePosition', function(charId, pos)
    local src = source
    local identifier = GetIdentifier(src)
    if not identifier or not charId or not pos then return end
    -- validate ownership
    MySQL.update('UPDATE characters SET position = ? WHERE id = ? AND identifier = ?', {
        json.encode(pos), charId, identifier
    })
end)

-- ensure table
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS characters (
            id INT AUTO_INCREMENT PRIMARY KEY,
            identifier VARCHAR(60) NOT NULL,
            firstname VARCHAR(50) NOT NULL,
            lastname VARCHAR(50) NOT NULL,
            age INT NOT NULL,
            sex VARCHAR(10) NOT NULL,
            skin LONGTEXT,
            position LONGTEXT,
            money INT DEFAULT 0,
            bank INT DEFAULT 0,
            job VARCHAR(50) DEFAULT 'unemployed',
            last_location VARCHAR(100) DEFAULT 'Aeroporto Internacional',
            `slot` INT NOT NULL DEFAULT 1,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_identifier (identifier)
        )
    ]])
end)

-- cleanup on drop
AddEventHandler('playerDropped', function()
    local src = source
    CurrentCharacter[src] = nil
end)