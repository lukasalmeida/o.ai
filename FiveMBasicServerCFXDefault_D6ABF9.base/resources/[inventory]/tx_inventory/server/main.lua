-- ==========================================================
--  TX_INVENTORY | NÚCLEO DO SERVIDOR
--  ----------------------------------------------------------
--  Toda alteração de item acontece AQUI. O cliente apenas
--  pede ações; o servidor valida e responde com o novo
--  estado. Isso evita exploits de duplicação/teleporte.
-- ==========================================================

math.randomseed(os.time())

local invs       = {}   -- [src]   = inventario em memória
local positions  = {}   -- [src]   = última posição conhecida {x,y,z}
local lastAction = {}   -- [src]   = timestamp da última ação
local groundEnts = {}   -- [instance] = entidade do objeto no chão
local equippedW  = {}   -- [src]   = id do item de arma equipada

-- Faixas de slot (o ID do slot é global e persistente no banco):
--   1  .. 30   -> mochila base
--   31 .. 35   -> hotbar (acesso rápido) - SEMPRE fixa
--   36 .. 36+  -> slots extras liberados por mochilas equipadas
local BACKPACK_MIN, BACKPACK_MAX = 1, Config.BackpackSlots
local HOTBAR_MIN, HOTBAR_MAX = Config.BackpackSlots + 1, Config.BackpackSlots + Config.HotbarSlots
local EXTRA_MIN = HOTBAR_MAX + 1

-- ==========================================================
--  UTILITÁRIOS
-- ==========================================================
local function log(msg)
    if Config.Debug then print(('[tx_inventory] %s'):format(msg)) end
end

local function dist3(ax, ay, az, bx, by, bz)
    local dx, dy, dz = ax - bx, ay - by, az - bz
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function encodeMeta(meta)
    if not meta or next(meta) == nil then return nil end
    local ok, res = pcall(json.encode, meta)
    return ok and res or nil
end

local function decodeMeta(str)
    if not str or str == '' then return {} end
    local ok, res = pcall(json.decode, str)
    if ok and type(res) == 'table' then return res end
    return {}
end

--- Quantidade de slots extras liberados pelas mochilas
local function GetExtraSlots(maxSlots)
    return math.max(0, maxSlots - Config.BackpackSlots)
end

local function ExtraMax(maxSlots)
    return HOTBAR_MAX + GetExtraSlots(maxSlots)
end

local function IsValidSlot(slot, maxSlots)
    slot = tonumber(slot) or 0
    if slot < BACKPACK_MIN then return false end
    if slot <= BACKPACK_MAX then return true end                 -- mochila base
    if slot >= HOTBAR_MIN and slot <= HOTBAR_MAX then return true end -- hotbar
    if slot >= EXTRA_MIN and slot <= ExtraMax(maxSlots) then return true end -- extras
    return false
end

local function RateLimited(src)
    local now = GetGameTimer()
    if lastAction[src] and (now - lastAction[src]) < Config.AntiSpamMs then
        return true
    end
    lastAction[src] = now
    return false
end

-- ==========================================================
--  PERSISTÊNCIA
-- ==========================================================
local function SaveItem(item)
    TXDB.Execute(
        ('UPDATE `%s` SET `item_name` = ?, `slot` = ?, `amount` = ?, `metadata` = ?, `equipped` = ? WHERE `id` = ?')
            :format(Config.Table),
        { item.name, item.slot or 0, item.amount or 1, encodeMeta(item.metadata), item.equipped and 1 or 0, item.id }
    )
end

local function DeleteItemRow(id)
    TXDB.Execute(('DELETE FROM `%s` WHERE `id` = ?'):format(Config.Table), { id })
end

local function InsertItem(identifier, name, slot, amount, metadata, equipped)
    local id = TXDB.Insert(
        ('INSERT INTO `%s` (`identifier`, `item_name`, `slot`, `amount`, `metadata`, `equipped`) VALUES (?, ?, ?, ?, ?, ?)')
            :format(Config.Table),
        { identifier, name, slot or 0, amount or 1, encodeMeta(metadata), equipped and 1 or 0 }
    )
    return id
end

-- ==========================================================
--  INVENTÁRIO EM MEMÓRIA
-- ==========================================================
local function RecalcWeight(inv)
    local w = 0.0
    for _, it in pairs(inv.items) do
        local def = TXINV.GetItem(it.name)
        w = w + (def.weight or 0.1) * (it.amount or 1)
    end
    inv.weight = w
    return w
end

--- Retorna slots totais e peso máximo considerando as mochilas equipadas
local function GetCapacity(inv)
    local slots, weight = Config.BackpackSlots, Config.MaxWeight
    for _, it in pairs(inv.items) do
        local def = TXINV.GetItem(it.name)
        if def.type == 'backpack' then
            slots  = slots  + (def.slotsBonus  or 0)
            weight = weight + (def.weightBonus or 0)
        end
    end
    return slots, weight
end

--- Procura um slot livre (mochila -> extras -> hotbar)
local function FindFreeSlot(inv, allowHotbar)
    local maxSlots = GetCapacity(inv)
    for s = BACKPACK_MIN, BACKPACK_MAX do
        if not inv.slots[s] then return s end
    end
    for s = EXTRA_MIN, ExtraMax(maxSlots) do
        if not inv.slots[s] then return s end
    end
    if allowHotbar ~= false then
        for s = HOTBAR_MIN, HOTBAR_MAX do
            if not inv.slots[s] then return s end
        end
    end
    return nil
end

local function GiveStartingItems(src, inv)
    for _, s in ipairs(Config.StartingItems or {}) do
        local def = TXINV.GetItem(s.name)
        local meta = {}
        if def.type == 'weapon' then
            meta.serial = ('%05d'):format(math.random(10000, 99999))
        end
        local slot = s.slot
        if not slot or inv.slots[slot] then slot = FindFreeSlot(inv) end
        if slot then
            local id = InsertItem(inv.identifier, s.name, slot, s.amount or 1, meta, false)
            if id and id > 0 then
                inv.items[id] = { id = id, name = s.name, slot = slot, amount = s.amount or 1, metadata = meta, equipped = false }
                inv.slots[slot] = id
            end
        end
    end
    RecalcWeight(inv)
end

--- Carrega (ou retorna) o inventário do jogador
local function EnsureInventory(src)
    if invs[src] then return invs[src] end

    -- Aguarda o driver de banco ficar pronto (evita inventário vazio)
    local timeout = 0
    while not TXDB.IsReady() and timeout < 30000 do
        Wait(200)
        timeout = timeout + 200
    end

    local identifier = TXFW.GetIdentifier(src)
    local rows = TXDB.Query(
        ('SELECT * FROM `%s` WHERE `identifier` = ?'):format(Config.Table),
        { identifier }
    ) or {}

    local inv = { identifier = identifier, items = {}, slots = {}, weight = 0 }

    for i = 1, #rows do
        local r = rows[i]
        local item = {
            id       = r.id,
            name     = r.item_name,
            slot     = tonumber(r.slot) or 0,
            amount   = tonumber(r.amount) or 1,
            metadata = decodeMeta(r.metadata),
            equipped = tonumber(r.equipped) == 1,
        }
        inv.items[item.id] = item
        if item.slot > 0 and not inv.slots[item.slot] then
            inv.slots[item.slot] = item.id
        end
        if item.equipped then equippedW[src] = item.id end
    end

    invs[src] = inv
    RecalcWeight(inv)

    if #rows == 0 then
        GiveStartingItems(src, inv)
    end

    return inv
end

-- ==========================================================
--  ITENS NO CHÃO
-- ==========================================================
local function SpawnGroundProp(model, x, y, z)
    local okHash, hash = pcall(GetHashKey, model or Config.DefaultGroundProp)
    if not okHash or not hash then hash = GetHashKey(Config.DefaultGroundProp) end

    local okValid = pcall(IsModelValid, hash)
    if not okValid or not IsModelValid(hash) then
        hash = GetHashKey(Config.DefaultGroundProp)
        if not IsModelValid(hash) then return 0 end
    end

    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 3000 do
        Wait(10)
        timeout = timeout + 10
    end
    if not HasModelLoaded(hash) then return 0 end

    local ok, obj = pcall(CreateObject, hash, x, y, z, true, true)
    if not ok or not obj or obj == 0 then return 0 end

    SetEntityAsMissionEntity(obj, true, true)
    SetEntityInvincible(obj, true)
    FreezeEntityPosition(obj, true)
    return obj
end

local function RemoveGroundProp(instance)
    local ent = groundEnts[instance]
    if ent and DoesEntityExist(ent) then
        DeleteEntity(ent)
    end
    groundEnts[instance] = nil
end

--- Itens do chão próximos do jogador
local function GetNearbyGround(src)
    if not Config.ShowGroundItems then return {} end
    local pos = positions[src]
    if not pos then return {} end

    local r = Config.GroundItemDistance
    local rows = TXDB.Query(
        ('SELECT * FROM `%s` WHERE `x` BETWEEN ? AND ? AND `y` BETWEEN ? AND ? AND `z` BETWEEN ? AND ?')
            :format(Config.GroundTable),
        { pos.x - r, pos.x + r, pos.y - r, pos.y + r, pos.z - r, pos.z + r }
    ) or {}

    local out = {}
    for i = 1, #rows do
        local row = rows[i]
        local d = dist3(row.x, row.y, row.z, pos.x, pos.y, pos.z)
        if d <= r then
            out[#out + 1] = {
                instance = row.instance,
                name     = row.item_name,
                amount   = row.amount,
                metadata = decodeMeta(row.metadata),
                x = row.x, y = row.y, z = row.z,
                distance = math.floor(d * 10) / 10,
            }
        end
    end
    table.sort(out, function(a, b) return a.distance < b.distance end)
    return out
end

-- ==========================================================
--  ESTADO / REFRESH
-- ==========================================================
local function BuildState(src)
    local inv = EnsureInventory(src)
    local items = {}

    for _, it in pairs(inv.items) do
        items[#items + 1] = {
            id       = it.id,
            name     = it.name,
            slot     = it.slot,
            amount   = it.amount,
            metadata = it.metadata or {},
            equipped = it.equipped and true or false,
        }
    end
    table.sort(items, function(a, b) return (a.slot or 0) < (b.slot or 0) end)

    local maxSlots, maxWeight = GetCapacity(inv)

    return {
        items  = items,
        weight = { current = RecalcWeight(inv), max = maxWeight },
        slots  = { backpack = maxSlots, hotbar = Config.HotbarSlots, base = Config.BackpackSlots },
        ground = GetNearbyGround(src),
        player = {
            name  = TXFW.GetName(src),
            money = TXFW.GetMoney(src),
            job   = TXFW.GetJob(src),
        },
    }
end

local function Refresh(src)
    local ok, state = pcall(BuildState, src)
    if ok and state then
        TriggerClientEvent('txinv:client:refresh', src, state)
    end
end

-- ==========================================================
--  AÇÕES
-- ==========================================================
--- Move / troca item entre slots
local function MoveItem(src, itemId, toSlot)
    local inv = EnsureInventory(src)
    local item = inv.items[itemId]
    if not item then return false end
    if not IsValidSlot(toSlot, GetCapacity(inv)) then return false end

    if item.slot == toSlot then return true end

    local occId = inv.slots[toSlot]

    -- Empilha quando é o mesmo item
    if occId and occId ~= itemId then
        local other = inv.items[occId]
        local dA, dB = TXINV.GetItem(item.name), TXINV.GetItem(other.name)
        if dA.stackable ~= false and dB.stackable ~= false and item.name == other.name then
            local maxStack = dA.maxStack or Config.MaxStack
            if (other.amount + item.amount) <= maxStack then
                other.amount = other.amount + item.amount
                SaveItem(other)
                DeleteItemRow(itemId)
                inv.items[itemId] = nil
                inv.slots[item.slot] = nil
                RecalcWeight(inv)
                return true
            end
        end

        -- Troca os dois de lugar
        local fromSlot = item.slot
        item.slot, other.slot = toSlot, fromSlot
        inv.slots[toSlot] = itemId
        inv.slots[fromSlot] = occId
        SaveItem(item)
        SaveItem(other)
        return true
    end

    local fromSlot = item.slot
    inv.slots[fromSlot] = nil
    inv.slots[toSlot] = itemId
    item.slot = toSlot
    SaveItem(item)
    return true
end

--- Joga o item no chão
local function DropItem(src, itemId, amount, coords)
    local inv = EnsureInventory(src)
    local item = inv.items[itemId]
    if not item then return false end
    if not coords then return false end

    amount = math.floor(tonumber(amount) or 1)
    if amount < 1 then amount = 1 end
    if amount > item.amount then amount = item.amount end

    -- Valida a distância do drop (anti-teleporte)
    local pos = positions[src]
    if pos then
        local d = dist3(coords.x, coords.y, coords.z, pos.x, pos.y, pos.z)
        if d > Config.DropDistance then
            TriggerClientEvent('txinv:notify', src, 'drop_too_far', 'error')
            return false
        end
    end

    local def = TXINV.GetItem(item.name)
    local instance = ('%s-%s-%s-%s'):format(os.time(), src, math.random(100000, 999999), math.random(1000, 9999))

    -- Remove da mochila
    local droppedMeta = item.metadata
    if amount >= item.amount then
        DeleteItemRow(itemId)
        inv.items[itemId] = nil
        if inv.slots[item.slot] == itemId then inv.slots[item.slot] = nil end
        if equippedW[src] == itemId then equippedW[src] = nil end
    else
        item.amount = item.amount - amount
        SaveItem(item)
    end
    RecalcWeight(inv)

    -- Cria no chão
    TXDB.Execute(
        ('INSERT INTO `%s` (`instance`, `item_name`, `amount`, `metadata`, `x`, `y`, `z`, `created_at`, `expires_at`) VALUES (?, ?, ?, ?, ?, ?, ?, NOW(), %s)')
            :format(Config.GroundTable, Config.GroundItemExpire > 0 and 'DATE_ADD(NOW(), INTERVAL ' .. tonumber(Config.GroundItemExpire) .. ' MINUTE)' or 'NULL'),
        { instance, item.name, amount, encodeMeta(droppedMeta), coords.x, coords.y, coords.z }
    )

    local ent = SpawnGroundProp(def.prop, coords.x, coords.y, coords.z)
    if ent ~= 0 then
        groundEnts[instance] = ent
    else
        -- Fallback: sem OneSync o servidor cria o objeto no cliente
        TriggerClientEvent('txinv:client:spawnGroundProp', -1, instance, def.prop, coords.x, coords.y, coords.z)
    end

    TriggerClientEvent('txinv:client:droppedItem', src, instance)
    TriggerClientEvent('txinv:notify', src, 'drop_success', 'success')
    return true
end

--- Pega item do chão
local function PickupGround(src, instance)
    local row = TXDB.Single(
        ('SELECT * FROM `%s` WHERE `instance` = ?'):format(Config.GroundTable),
        { instance }
    )
    if not row then return false end

    local pos = positions[src]
    if pos then
        local d = dist3(row.x, row.y, row.z, pos.x, pos.y, pos.z)
        if d > (Config.PickupDistance + 1.0) then
            TriggerClientEvent('txinv:notify', src, 'too_far', 'error')
            return false
        end
    end

    local inv = EnsureInventory(src)
    local def = TXINV.GetItem(row.item_name)

    -- Peso
    local maxSlots, maxWeight = GetCapacity(inv)
    local add = (def.weight or 0.1) * row.amount
    if (RecalcWeight(inv) + add) > maxWeight then
        TriggerClientEvent('txinv:notify', src, 'inventory.full_weight', 'error')
        return false
    end

    -- Slot
    local slot = FindFreeSlot(inv)
    if not slot then
        TriggerClientEvent('txinv:notify', src, 'inventory.full_slots', 'error')
        return false
    end

    local meta = decodeMeta(row.metadata)
    if def.type == 'weapon' and not meta.serial then
        meta.serial = ('%05d'):format(math.random(10000, 99999))
    end

    local id = InsertItem(inv.identifier, row.item_name, slot, row.amount, meta, false)
    if id and id > 0 then
        inv.items[id] = { id = id, name = row.item_name, slot = slot, amount = row.amount, metadata = meta, equipped = false }
        inv.slots[slot] = id
    end

    TXDB.Execute(('DELETE FROM `%s` WHERE `instance` = ?'):format(Config.GroundTable), { instance })
    RemoveGroundProp(instance)
    TriggerClientEvent('txinv:client:removeGroundProp', -1, instance)

    TriggerClientEvent('txinv:notify', src, 'pickup_success', 'success')
    return true
end

--- Dá item para outro jogador
local function GiveItem(src, itemId, amount, targetSrc)
    if not Config.AllowGive then return false end
    targetSrc = tonumber(targetSrc)
    if not targetSrc or targetSrc == src then return false end
    if not GetPlayerName(targetSrc) then return false end

    local inv = EnsureInventory(src)
    local item = inv.items[itemId]
    if not item then return false end

    amount = math.floor(tonumber(amount) or 1)
    if amount < 1 then amount = 1 end
    if amount > item.amount then amount = item.amount end

    -- Distância entre os jogadores
    local p1, p2 = positions[src], positions[targetSrc]
    if p1 and p2 then
        local d = dist3(p1.x, p1.y, p1.z, p2.x, p2.y, p2.z)
        if d > Config.GiveDistance then
            TriggerClientEvent('txinv:notify', src, 'give_too_far', 'error')
            return false
        end
    end

    local tInv = EnsureInventory(targetSrc)
    local def = TXINV.GetItem(item.name)

    -- Peso do alvo
    local _, maxWeight = GetCapacity(tInv)
    local add = (def.weight or 0.1) * amount
    if (RecalcWeight(tInv) + add) > maxWeight then
        TriggerClientEvent('txinv:notify', src, 'target_full_weight', 'error')
        TriggerClientEvent('txinv:notify', targetSrc, 'inventory.full_weight', 'error')
        return false
    end

    -- Slot do alvo
    local slot = FindFreeSlot(tInv)
    if not slot then
        TriggerClientEvent('txinv:notify', src, 'target_full_slots', 'error')
        TriggerClientEvent('txinv:notify', targetSrc, 'inventory.full_slots', 'error')
        return false
    end

    local meta = item.metadata

    if amount >= item.amount then
        -- move a linha inteira para o alvo
        TXDB.Execute(
            ('UPDATE `%s` SET `identifier` = ?, `slot` = ?, `equipped` = 0 WHERE `id` = ?'):format(Config.Table),
            { tInv.identifier, slot, itemId }
        )
        inv.items[itemId] = nil
        if inv.slots[item.slot] == itemId then inv.slots[item.slot] = nil end
        if equippedW[src] == itemId then equippedW[src] = nil end
    else
        item.amount = item.amount - amount
        SaveItem(item)
        local newId = InsertItem(tInv.identifier, item.name, slot, amount, meta, false)
        if newId and newId > 0 then
            tInv.items[newId] = { id = newId, name = item.name, slot = slot, amount = amount, metadata = meta, equipped = false }
            tInv.slots[slot] = newId
        end
    end

    RecalcWeight(inv)
    RecalcWeight(tInv)

    TriggerClientEvent('txinv:client:giveEffect', src, item.name)
    TriggerClientEvent('txinv:notify', src, 'give_success', 'success')
    TriggerClientEvent('txinv:notify', targetSrc, 'receive_item', 'success')
    Refresh(src)
    Refresh(targetSrc)
    return true
end

--- Usa / consome / equipa um item
local function UseItem(src, itemId)
    local inv = EnsureInventory(src)
    local item = inv.items[itemId]
    if not item then return false end

    local def = TXINV.GetItem(item.name)
    local typ = def.type

    if typ == 'consumable' then
        item.amount = item.amount - 1
        if item.amount <= 0 then
            DeleteItemRow(itemId)
            inv.items[itemId] = nil
            if inv.slots[item.slot] == itemId then inv.slots[item.slot] = nil end
        else
            SaveItem(item)
        end
        RecalcWeight(inv)
        TriggerClientEvent('txinv:client:useEffect', src, def.effects or {}, item.name)
        TriggerClientEvent('txinv:notify', src, 'used_item', 'success')
        return true

    elseif typ == 'weapon' then
        -- desequipa a arma anterior
        local oldId = equippedW[src]
        if oldId and oldId ~= itemId then
            local old = inv.items[oldId]
            if old then
                old.equipped = false
                SaveItem(old)
            end
        end
        item.equipped = true
        equippedW[src] = itemId
        SaveItem(item)
        TriggerClientEvent('txinv:client:equipWeapon', src, def.weapon, item.metadata or {})
        TriggerClientEvent('txinv:notify', src, 'weapon_equipped', 'success')
        return true

    elseif typ == 'backpack' then
        TriggerClientEvent('txinv:client:useGeneric', src, item.name)
        TriggerClientEvent('txinv:notify', src, 'used_item', 'success')
        return true

    else
        TriggerClientEvent('txinv:client:useGeneric', src, item.name)
        TriggerClientEvent('txinv:notify', src, 'used_item', 'success')
        return true
    end
end

--- Desequipa a arma
local function UnequipWeapon(src)
    local id = equippedW[src]
    if not id then return false end
    local inv = EnsureInventory(src)
    local item = inv.items[id]
    if item then
        item.equipped = false
        SaveItem(item)
    end
    equippedW[src] = nil
    TriggerClientEvent('txinv:client:unequipWeapon', src)
    return true
end

--- Divide um stack
local function SplitItem(src, itemId, amount)
    if not Config.AllowSplit then return false end
    local inv = EnsureInventory(src)
    local item = inv.items[itemId]
    if not item then return false end

    amount = math.floor(tonumber(amount) or 1)
    if amount < 1 or amount >= item.amount then return false end

    local slot = FindFreeSlot(inv)
    if not slot then
        TriggerClientEvent('txinv:notify', src, 'inventory.full_slots', 'error')
        return false
    end

    item.amount = item.amount - amount
    SaveItem(item)

    local newId = InsertItem(inv.identifier, item.name, slot, amount, item.metadata, false)
    if newId and newId > 0 then
        inv.items[newId] = { id = newId, name = item.name, slot = slot, amount = amount, metadata = item.metadata, equipped = false }
        inv.slots[slot] = newId
    end
    RecalcWeight(inv)
    TriggerClientEvent('txinv:notify', src, 'split_success', 'success')
    return true
end

--- Destrói o item (área de lixo)
local function DeleteItem(src, itemId)
    if not Config.AllowDelete then return false end
    local inv = EnsureInventory(src)
    local item = inv.items[itemId]
    if not item then return false end

    DeleteItemRow(itemId)
    inv.items[itemId] = nil
    if inv.slots[item.slot] == itemId then inv.slots[item.slot] = nil end
    if equippedW[src] == itemId then
        equippedW[src] = nil
        TriggerClientEvent('txinv:client:unequipWeapon', src)
    end
    RecalcWeight(inv)
    TriggerClientEvent('txinv:notify', src, 'item_deleted', 'error')
    return true
end

-- ==========================================================
--  EVENTOS DE REDE
-- ==========================================================
RegisterNetEvent('txinv:server:requestState', function()
    local src = source
    EnsureInventory(src)
    Refresh(src)
end)

RegisterNetEvent('txinv:server:open', function()
    local src = source
    if RateLimited(src) then return end
    print(('[tx_inventory] inventario aberto (src=%s)'):format(src))
    EnsureInventory(src)
    local state = BuildState(src)
    TriggerClientEvent('txinv:client:open', src, state)
end)

RegisterNetEvent('txinv:server:move', function(itemId, toSlot)
    local src = source
    if RateLimited(src) then return end
    if MoveItem(src, tonumber(itemId), tonumber(toSlot)) then
        Refresh(src)
    end
end)

RegisterNetEvent('txinv:server:drop', function(itemId, amount, coords)
    local src = source
    if RateLimited(src) then return end
    if type(coords) ~= 'table' then return end
    if DropItem(src, tonumber(itemId), tonumber(amount), {
        x = tonumber(coords.x) or 0,
        y = tonumber(coords.y) or 0,
        z = tonumber(coords.z) or 0,
    }) then
        Refresh(src)
    end
end)

RegisterNetEvent('txinv:server:pickup', function(instance)
    local src = source
    if RateLimited(src) then return end
    if PickupGround(src, instance) then
        Refresh(src)
    end
end)

RegisterNetEvent('txinv:server:give', function(itemId, amount, target)
    local src = source
    if RateLimited(src) then return end
    if GiveItem(src, tonumber(itemId), tonumber(amount), tonumber(target)) then
        Refresh(src)
    end
end)

RegisterNetEvent('txinv:server:use', function(itemId)
    local src = source
    if RateLimited(src) then return end
    if UseItem(src, tonumber(itemId)) then
        Refresh(src)
    end
end)

RegisterNetEvent('txinv:server:unequip', function()
    local src = source
    if RateLimited(src) then return end
    if UnequipWeapon(src) then
        Refresh(src)
    end
end)

RegisterNetEvent('txinv:server:split', function(itemId, amount)
    local src = source
    if RateLimited(src) then return end
    if SplitItem(src, tonumber(itemId), tonumber(amount)) then
        Refresh(src)
    end
end)

RegisterNetEvent('txinv:server:delete', function(itemId)
    local src = source
    if RateLimited(src) then return end
    if DeleteItem(src, tonumber(itemId)) then
        Refresh(src)
    end
end)

--- Usa o item que está no slot N da hotbar (teclas 1-5)
RegisterNetEvent('txinv:server:hotbar', function(index)
    local src = source
    if RateLimited(src) then return end
    index = math.floor(tonumber(index) or 0)
    if index < 1 or index > Config.HotbarSlots then return end

    local inv = EnsureInventory(src)
    local slot = HOTBAR_MIN + index - 1
    local itemId = inv.slots[slot]
    if not itemId then return end

    if UseItem(src, itemId) then
        Refresh(src)
    end
end)

--- Heartbeat de posição (anti-cheat de distância)
RegisterNetEvent('txinv:server:position', function(x, y, z)
    local src = source
    if type(x) ~= 'number' or type(y) ~= 'number' or type(z) ~= 'number' then return end
    positions[src] = { x = x, y = y, z = z }
end)

-- ==========================================================
--  CICLO DE VIDA DO JOGADOR
-- ==========================================================
AddEventHandler('txinv:playerLoaded', function(src)
    src = tonumber(src) or source
    EnsureInventory(src)
    Refresh(src)
end)

AddEventHandler('playerDropped', function()
    local src = source
    invs[src] = nil
    positions[src] = nil
    lastAction[src] = nil
    equippedW[src] = nil
end)

-- ==========================================================
--  LIMPEZA DE ITENS EXPIRADOS NO CHÃO
-- ==========================================================
CreateThread(function()
    while true do
        Wait(60000)
        if TXDB.IsReady() then
            local rows = TXDB.Query(
                ('SELECT `instance` FROM `%s` WHERE `expires_at` IS NOT NULL AND `expires_at` < NOW()'):format(Config.GroundTable)
            ) or {}
            for i = 1, #rows do
                RemoveGroundProp(rows[i].instance)
                TriggerClientEvent('txinv:client:removeGroundProp', -1, rows[i].instance)
            end
            if #rows > 0 then
                TXDB.Execute(('DELETE FROM `%s` WHERE `expires_at` IS NOT NULL AND `expires_at` < NOW()'):format(Config.GroundTable))
            end
        end
    end
end)

-- ==========================================================
--  API PÚBLICA (para outros scripts)
-- ==========================================================
exports('GetInventory', function(src)
    return invs[tonumber(src) or source] or {}
end)

exports('GetItemCount', function(src, name)
    local inv = EnsureInventory(tonumber(src) or source)
    local total = 0
    for _, it in pairs(inv.items) do
        if it.name == name then total = total + it.amount end
    end
    return total
end)

exports('AddItem', function(src, name, amount, slot)
    local srcId = tonumber(src) or source
    local inv = EnsureInventory(srcId)
    amount = math.floor(tonumber(amount) or 1)
    local def = TXINV.GetItem(name)
    local targetSlot = slot or FindFreeSlot(inv)
    if not targetSlot then return false end

    local meta = {}
    if def.type == 'weapon' then meta.serial = ('%05d'):format(math.random(10000, 99999)) end

    local id = InsertItem(inv.identifier, name, targetSlot, amount, meta, false)
    if id and id > 0 then
        inv.items[id] = { id = id, name = name, slot = targetSlot, amount = amount, metadata = meta, equipped = false }
        inv.slots[targetSlot] = id
        RecalcWeight(inv)
        Refresh(srcId)
        return true
    end
    return false
end)

exports('RemoveItem', function(src, name, amount)
    local srcId = tonumber(src) or source
    local inv = EnsureInventory(srcId)
    amount = math.floor(tonumber(amount) or 1)
    local removed = 0
    for id, it in pairs(inv.items) do
        if it.name == name and removed < amount then
            local take = math.min(it.amount, amount - removed)
            it.amount = it.amount - take
            removed = removed + take
            if it.amount <= 0 then
                DeleteItemRow(id)
                inv.items[id] = nil
                if inv.slots[it.slot] == id then inv.slots[it.slot] = nil end
            else
                SaveItem(it)
            end
        end
    end
    RecalcWeight(inv)
    Refresh(srcId)
    return removed
end)
