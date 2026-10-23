local Config = Config

RegisterNetEvent('multicharacter:server:SetRoutingBucket')
AddEventHandler('multicharacter:server:SetRoutingBucket', function(bucket)
    SetPlayerRoutingBucket(source, bucket or 0)
end)

local function GetIdentifier(source)
    for _, id in ipairs(GetPlayerIdentifiers(source)) do
        if string.sub(id, 1, string.len('license:')) == 'license:' then
            return id
        end
    end
    for _, id in ipairs(GetPlayerIdentifiers(source)) do
        if string.sub(id, 1, string.len('steam:')) == 'steam:' then
            return id
        end
    end
    return GetPlayerIdentifiers(source)[1]
end

local function GetPlayerCharacters(identifier)
    local query = string.format([[
        SELECT id, firstname, lastname, age, sex, skin, position, bank, job, last_location, `slot`
        FROM %s
        WHERE identifier = ?
        ORDER BY `slot` ASC
    ]], Config.Database.table)

    local result = MySQL.query.await(query, { identifier })
    return result or {}
end

local function CreateCharacter(data)
    local query = string.format([[
        INSERT INTO %s (identifier, firstname, lastname, age, sex, skin, position, bank, job, last_location, `slot`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], Config.Database.table)

    local skinJson = json.encode(data.skin)
    local positionJson = json.encode(data.position)

    local result = MySQL.insert.await(query, {
        data.identifier,
        data.firstname,
        data.lastname,
        data.age,
        data.sex,
        skinJson,
        positionJson,
        data.bank or 5000,
        data.job or 'unemployed',
        data.last_location or 'Aeroporto Internacional',
        data.slot
    })

    return result
end

local function UpdateCharacter(charId, data)
    local query = string.format([[
        UPDATE %s SET
        firstname = ?, lastname = ?, age = ?, sex = ?, skin = ?, position = ?, bank = ?, job = ?, last_location = ?
        WHERE id = ?
    ]], Config.Database.table)

    local skinJson = json.encode(data.skin)
    local positionJson = json.encode(data.position)

    MySQL.update.await(query, {
        data.firstname,
        data.lastname,
        data.age,
        data.sex,
        skinJson,
        positionJson,
        data.bank,
        data.job,
        data.last_location,
        charId
    })
end

local function DeleteCharacter(charId)
    local query = string.format('DELETE FROM %s WHERE id = ?', Config.Database.table)
    MySQL.update.await(query, { charId })
end

local function GetNextAvailableSlot(identifier)
    local characters = GetPlayerCharacters(identifier)
    local usedSlots = {}
    for _, char in ipairs(characters) do
        usedSlots[char.slot] = true
    end

    for i = 1, Config.MaxCharacters do
        if not usedSlots[i] then
            return i
        end
    end
    return nil
end

RegisterNetEvent('multicharacter:server:GetCharacters')
AddEventHandler('multicharacter:server:GetCharacters', function()
    local src = source
    local identifier = GetIdentifier(src)

    Config.Log('Fetching characters for: ' .. identifier)

    local characters = GetPlayerCharacters(identifier)

    local formattedChars = {}
    for _, char in ipairs(characters) do
        local skin = {}
        if char.skin then skin = json.decode(char.skin) or {} end
        local position = {}
        if char.position then position = json.decode(char.position) or {} end

        table.insert(formattedChars, {
            id = char.id,
            slot = char.slot,
            firstname = char.firstname,
            lastname = char.lastname,
            fullname = char.firstname .. ' ' .. char.lastname,
            age = char.age,
            sex = char.sex,
            bank = char.bank or 0,
            job = char.job or 'unemployed',
            last_location = char.last_location or 'Desconhecido',
            skin = skin,
            position = position,
            model = skin.model or (char.sex == 'M' and 'mp_m_freemode_01' or 'mp_f_freemode_01')
        })
    end

    TriggerClientEvent('multicharacter:client:ReceiveCharacters', src, formattedChars)
end)

RegisterNetEvent('multicharacter:server:CreateCharacter')
AddEventHandler('multicharacter:server:CreateCharacter', function(data)
    local src = source
    local identifier = GetIdentifier(src)

    Config.Log('Creating character for: ' .. identifier)

    if not data.firstname or not data.lastname or not data.age or not data.sex then
        TriggerClientEvent('multicharacter:client:CreationResponse', src, false, 'Dados incompletos')
        return
    end

    if string.len(data.firstname) < Config.Validation.minNameLength or string.len(data.firstname) > Config.Validation.maxNameLength then
        TriggerClientEvent('multicharacter:client:CreationResponse', src, false, 'Nome inválido (2-20 caracteres)')
        return
    end

    if string.len(data.lastname) < Config.Validation.minNameLength or string.len(data.lastname) > Config.Validation.maxNameLength then
        TriggerClientEvent('multicharacter:client:CreationResponse', src, false, 'Sobrenome inválido (2-20 caracteres)')
        return
    end

    if not string.match(data.firstname, Config.Validation.allowedChars) or not string.match(data.lastname, Config.Validation.allowedChars) then
        TriggerClientEvent('multicharacter:client:CreationResponse', src, false, 'Nome/Sobrenome contém caracteres inválidos')
        return
    end

    if data.age < Config.Validation.minAge or data.age > Config.Validation.maxAge then
        TriggerClientEvent('multicharacter:client:CreationResponse', src, false, 'Idade deve ser entre 18 e 100 anos')
        return
    end

    if data.sex ~= 'M' and data.sex ~= 'F' then
        TriggerClientEvent('multicharacter:client:CreationResponse', src, false, 'Sexo inválido')
        return
    end

    local slot = GetNextAvailableSlot(identifier)
    if not slot then
        TriggerClientEvent('multicharacter:client:CreationResponse', src, false, 'Slots cheios (máx. ' .. Config.MaxCharacters .. ')')
        return
    end

    local characterData = {
        identifier = identifier,
        firstname = data.firstname,
        lastname = data.lastname,
        age = data.age,
        sex = data.sex,
        skin = data.skin,
        position = data.position or Config.DefaultSpawn.coords,
        bank = 5000,
        job = 'unemployed',
        last_location = 'Aeroporto Internacional',
        slot = slot
    }

    local charId = CreateCharacter(characterData)

    if charId then
        Config.Log('Character created with ID: ' .. charId)
        TriggerClientEvent('multicharacter:client:CreationResponse', src, true, 'Personagem criado com sucesso!', {
            id = charId,
            slot = slot,
            firstname = data.firstname,
            lastname = data.lastname,
            age = data.age,
            sex = data.sex,
            skin = data.skin,
            position = data.position
        })
    else
        TriggerClientEvent('multicharacter:client:CreationResponse', src, false, 'Erro ao salvar no banco de dados')
    end
end)

RegisterNetEvent('multicharacter:server:SelectCharacter')
AddEventHandler('multicharacter:server:SelectCharacter', function(charId)
    print('[MULTICHAR] server SelectCharacter charId=' .. tostring(charId))
    local src = source
    local identifier = GetIdentifier(src)

    Config.Log('Selecting character: ' .. charId .. ' for ' .. identifier)

    local query = string.format('SELECT * FROM %s WHERE id = ? AND identifier = ?', Config.Database.table)
    local result = MySQL.query.await(query, { charId, identifier })
    local character = (result and result[1]) or nil

    if character then
        local skin = {}
        if character.skin then skin = json.decode(character.skin) or {} end
        local position = {}
        if character.position then position = json.decode(character.position) or {} end

        TriggerClientEvent('multicharacter:client:SpawnCharacter', src, {
            id = character.id,
            firstname = character.firstname,
            lastname = character.lastname,
            age = character.age,
            sex = character.sex,
            skin = skin,
            position = position,
            model = skin.model or (character.sex == 'M' and 'mp_m_freemode_01' or 'mp_f_freemode_01'),
            bank = character.bank,
            job = character.job
        })
    else
        TriggerClientEvent('multicharacter:client:SpawnCharacter', src, nil)
    end
end)

RegisterNetEvent('multicharacter:server:DeleteCharacter')
AddEventHandler('multicharacter:server:DeleteCharacter', function(charId)
    local src = source
    local identifier = GetIdentifier(src)

    Config.Log('Deleting character: ' .. charId)

    local query = string.format('SELECT id FROM %s WHERE id = ? AND identifier = ?', Config.Database.table)
    local character = MySQL.single.await(query, { charId, identifier })

    if character then
        DeleteCharacter(charId)
        TriggerClientEvent('multicharacter:client:DeletionResponse', src, true)
    else
        TriggerClientEvent('multicharacter:client:DeletionResponse', src, false)
    end
end)

RegisterNetEvent('multicharacter:server:UpdateLastPosition')
AddEventHandler('multicharacter:server:UpdateLastPosition', function(position, locationName)
    local src = source
    local identifier = GetIdentifier(src)

    local query = string.format([[
        UPDATE %s SET position = ?, last_location = ? WHERE identifier = ? AND position IS NOT NULL
        ORDER BY `slot` LIMIT 1
    ]], Config.Database.table)

    MySQL.update.await(query, { json.encode(position), locationName or 'Desconhecido', identifier })
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        Config.Log('Resource started - Multicharacter System Ready')
        
        MySQL.query.await(string.format([[
            CREATE TABLE IF NOT EXISTS %s (
                id INT AUTO_INCREMENT PRIMARY KEY,
                identifier VARCHAR(60) NOT NULL,
                firstname VARCHAR(50) NOT NULL,
                lastname VARCHAR(50) NOT NULL,
                age INT NOT NULL,
                sex VARCHAR(1) NOT NULL,
                skin LONGTEXT,
                position LONGTEXT,
                bank INT DEFAULT 5000,
                job VARCHAR(50) DEFAULT 'unemployed',
                last_location VARCHAR(100) DEFAULT 'Aeroporto Internacional',
                `slot` INT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                INDEX idx_identifier (identifier),
                INDEX idx_slot (identifier, `slot`)
            )
        ]], Config.Database.table))
    end
end)

RegisterCommand('reloadchars', function(source)
    if source == 0 then
        TriggerClientEvent('multicharacter:client:RequestCharacters', -1)
    end
end, true)