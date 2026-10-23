-- ==========================================================
--  TX_INVENTORY | CATÁLOGO DE ITENS
--  Compartilhado entre cliente e servidor.
--
--  Campos disponíveis:
--    label       -> nome exibido na UI
--    desc        -> descrição (tooltip)
--    type        -> consumable | weapon | tool | phone | backpack | ammo | key | doc
--    weight      -> peso em KG por unidade
--    maxStack    -> quantidade máxima por slot
--    stackable   -> false para itens que não podem ser empilhados (armas)
--    image       -> arquivo dentro de html/img (opcional, tem fallback automático)
--    glyph       -> emoji/texto usado como fallback quando a imagem não existe
--    effects     -> consumível: { heal=, armor=, hunger=, thirst= }
--    weapon      -> nome da arma (WEAPON_...)
--    ammoType    -> tipo de munição (para compatibilidade com frameworks)
--    prop        -> modelo spawnado no chão ao dropar
--    slotsBonus  -> (backpack) slots extras
--    weightBonus -> (backpack) kg extras de capacidade
-- ==========================================================

TXINV = TXINV or {}

TXINV.Items = {

    -- ------------------------------------------------------
    --  CONSUMÍVEIS
    -- ------------------------------------------------------
    ['water'] = {
        label = 'Água', type = 'consumable', weight = 0.5, maxStack = 10,
        desc = 'Um copo de água. Mata a sede.', image = 'water.svg', glyph = '💧',
        effects = { thirst = 25.0 }, prop = 'prop_cs_water_bottle',
    },
    ['coffee'] = {
        label = 'Café', type = 'consumable', weight = 0.3, maxStack = 10,
        desc = 'Café forte da manhã.', image = 'coffee.svg', glyph = '☕',
        effects = { thirst = 15.0, hunger = 5.0 }, prop = 'prop_cs_coffee_cup',
    },
    ['bread'] = {
        label = 'Pão', type = 'consumable', weight = 0.4, maxStack = 10,
        desc = 'Pão fresco. Mata a fome.', image = 'bread.svg', glyph = '🍞',
        effects = { hunger = 20.0 }, prop = 'prop_cs_bread_01',
    },
    ['burger'] = {
        label = 'Hambúrguer', type = 'consumable', weight = 0.8, maxStack = 5,
        desc = 'Um hambúrguer sujo, mas honesto.', image = 'burger.svg', glyph = '🍔',
        effects = { hunger = 45.0, thirst = -5.0 }, prop = 'prop_cs_burger_01',
    },
    ['protein'] = {
        label = 'Proteína', type = 'consumable', weight = 1.0, maxStack = 5,
        desc = 'Restaura a vida e a fome.', image = 'protein.svg', glyph = '🥤',
        effects = { heal = 20.0, hunger = 30.0 },
    },
    ['bandage'] = {
        label = 'Bandagem', type = 'consumable', weight = 0.2, maxStack = 10,
        desc = 'Estanca hemorragias e cura ferimentos leves.', image = 'bandage.svg', glyph = '🩹',
        effects = { heal = 15.0 },
    },
    ['medkit'] = {
        label = 'Kit Médico', type = 'consumable', weight = 1.5, maxStack = 3,
        desc = 'Restaura toda a vida.', image = 'medkit.svg', glyph = '🧰',
        effects = { heal = 100.0, armor = 25.0 },
    },
    ['energy'] = {
        label = 'Energético', type = 'consumable', weight = 0.6, maxStack = 5,
        desc = 'Dá um gás. Curto prazo.', image = 'energy.svg', glyph = '🥫',
        effects = { hunger = 15.0, thirst = 15.0, heal = 5.0 },
    },

    -- ------------------------------------------------------
    --  ARMAS
    -- ------------------------------------------------------
    ['pistol'] = {
        label = 'Pistola', type = 'weapon', weapon = 'WEAPON_PISTOL', weight = 1.2,
        maxStack = 1, stackable = false, image = 'weapon_pistol.svg', glyph = '🔫',
        desc = 'Uma pistola comum.', prop = 'prop_cs_heist_bag_02',
    },
    ['revolver'] = {
        label = 'Revólver', type = 'weapon', weapon = 'WEAPON_REVOLVER', weight = 1.5,
        maxStack = 1, stackable = false, image = 'weapon_revolver.svg', glyph = '🔫',
        desc = 'Revólver .357. Barulhento.', prop = 'prop_cs_heist_bag_02',
    },
    ['smg'] = {
        label = 'Submetralhadora', type = 'weapon', weapon = 'WEAPON_SMG', weight = 3.0,
        maxStack = 1, stackable = false, image = 'weapon_smg.svg', glyph = '🔫',
        desc = 'Submetralhadora compacta.', prop = 'prop_cs_heist_bag_02',
    },
    ['rifle'] = {
        label = 'Rifle', type = 'weapon', weapon = 'WEAPON_RIFLE', weight = 4.0,
        maxStack = 1, stackable = false, image = 'weapon_rifle.svg', glyph = '🔫',
        desc = 'Rifle de assalto.', prop = 'prop_cs_heist_bag_02',
    },
    ['shotgun'] = {
        label = 'Escopeta', type = 'weapon', weapon = 'WEAPON_PUMPSHOTGUN', weight = 4.5,
        maxStack = 1, stackable = false, image = 'weapon_shotgun.svg', glyph = '🔫',
        desc = 'Escopeta de cano duplo.', prop = 'prop_cs_heist_bag_02',
    },
    ['knife'] = {
        label = 'Faca', type = 'weapon', weapon = 'WEAPON_KNIFE', weight = 0.4,
        maxStack = 1, stackable = false, image = 'weapon_knife.svg', glyph = '🔪',
        desc = 'Faca de combate.', prop = 'prop_cs_knife_01',
    },

    -- ------------------------------------------------------
    --  MUNIÇÃO
    -- ------------------------------------------------------
    ['ammo_pistol'] = {
        label = 'Munição de Pistola', type = 'ammo', weight = 0.02, maxStack = 200,
        image = 'ammo_pistol.svg', glyph = '🔩', ammoType = 'Pistol',
        desc = 'Munição para pistolas.',
    },
    ['ammo_rifle'] = {
        label = 'Munição de Rifle', type = 'ammo', weight = 0.02, maxStack = 200,
        image = 'ammo_rifle.svg', glyph = '🔩', ammoType = 'Rifle',
        desc = 'Munição para rifles.',
    },

    -- ------------------------------------------------------
    --  FERRAMENTAS / UTILIDADES
    -- ------------------------------------------------------
    ['lockpick'] = {
        label = 'Chave de micha', type = 'tool', weight = 0.2, maxStack = 5,
        image = 'lockpick.svg', glyph = '🗝️', desc = 'Abre fechaduras.',
        prop = 'prop_crowbar_01',
    },
    ['crowbar'] = {
        label = 'Pé de cabra', type = 'tool', weight = 1.8, maxStack = 1,
        stackable = false, image = 'crowbar.svg', glyph = '🔧',
        desc = 'Abre portas e quebra coisas.', prop = 'prop_crowbar_01',
    },
    ['phone'] = {
        label = 'Celular', type = 'phone', weight = 0.6, maxStack = 1, stackable = false,
        image = 'phone.svg', glyph = '📱', desc = 'Um celular velho, mas funciona.',
        prop = 'prop_cs_phone_01',
    },
    ['radio'] = {
        label = 'Rádio', type = 'tool', weight = 0.7, maxStack = 1, stackable = false,
        image = 'radio.svg', glyph = '📻', desc = 'Rádio comunicador.', prop = 'prop_walkie_talkie_01',
    },
    ['flashlight'] = {
        label = 'Lanterna', type = 'tool', weight = 0.3, maxStack = 1, stackable = false,
        image = 'flashlight.svg', glyph = '🔦', desc = 'Ilumina o escuro.', prop = 'prop_flashlight_01',
    },
    ['carkey'] = {
        label = 'Chave do Carro', type = 'key', weight = 0.1, maxStack = 5,
        image = 'carkey.svg', glyph = '🔑', desc = 'Chave de um veículo.',
        prop = 'prop_carkey_01',
    },

    -- ------------------------------------------------------
    --  MOCHILAS (aumentam a capacidade)
    -- ------------------------------------------------------
    ['backpack'] = {
        label = 'Mochila', type = 'backpack', weight = 2.0, maxStack = 1, stackable = false,
        slotsBonus = 10, weightBonus = 10.0, image = 'backpack.svg', glyph = '🎒',
        desc = 'Mochila de lona. +10 slots e +10kg de capacidade.',
        prop = 'prop_sport_bag_01',
    },
    ['duffelbag'] = {
        label = 'Mala de Viagem', type = 'backpack', weight = 4.0, maxStack = 1, stackable = false,
        slotsBonus = 20, weightBonus = 25.0, image = 'duffelbag.svg', glyph = '💼',
        desc = 'Mala grande. +20 slots e +25kg de capacidade.',
        prop = 'prop_duffelbag_01',
    },

    -- ------------------------------------------------------
    --  DOCUMENTOS
    -- ------------------------------------------------------
    ['identity'] = {
        label = 'Documento', type = 'doc', weight = 0.05, maxStack = 5,
        image = 'identity.svg', glyph = '📄', desc = 'Documento de identidade.',
    },
    ['licence'] = {
        label = 'Carteira de Habilitação', type = 'doc', weight = 0.05, maxStack = 5,
        image = 'licence.svg', glyph = '🪪', desc = 'Carteira de habilitação.',
    },
}

-- Ordem de exibição padrão na UI (itens fora da lista vão para o final)
TXINV.ItemOrder = {
    'bread', 'water', 'coffee', 'burger', 'protein', 'energy', 'bandage', 'medkit',
    'pistol', 'revolver', 'smg', 'rifle', 'shotgun', 'knife',
    'ammo_pistol', 'ammo_rifle', 'lockpick', 'crowbar', 'phone', 'radio',
    'flashlight', 'carkey', 'backpack', 'duffelbag', 'identity', 'licence',
}

-- Retorna a definição de um item (nunca nil)
function TXINV.GetItem(name)
    return TXINV.Items[name] or {
        label = name or 'Desconhecido',
        type  = 'unknown',
        weight = 0.1,
        maxStack = 1,
        glyph = '📦',
    }
end
