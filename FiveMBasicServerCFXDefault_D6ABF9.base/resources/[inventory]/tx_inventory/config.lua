-- ==========================================================
--  TX_INVENTORY | CONFIGURAÇÃO
--  Altere aqui os valores do seu servidor.
-- ==========================================================

Config = {}

-- ==========================================================
--  GERAL
-- ==========================================================
Config.Debug       = false
-- 'auto' detecta ESX / QBCore automaticamente.
-- 'standalone' funciona sem framework (usa o playerId do FiveM).
Config.Framework   = 'auto'

-- Banco de dados: 'auto' | 'oxmysql' | 'ghmattimysql'
Config.Database    = 'auto'

-- Nomes das tabelas no banco
Config.Table       = 'player_items'
Config.GroundTable = 'ground_items'

-- ==========================================================
--  CAPACIDADE
-- ==========================================================
Config.MaxWeight    = 30.0   -- kg (soma dos pesos dos itens)
Config.BackpackSlots = 30    -- slots da mochila principal
Config.HotbarSlots   = 5     -- slots de acesso rápido (teclas 1-5)

-- Itens do tipo 'backpack' somam capacidade extra automaticamente.
-- O peso do próprio item já conta; 'weightBonus' é capacidade adicional.

-- ==========================================================
--  DISTÂNCIAS (metros)
-- ==========================================================
Config.DropDistance      = 4.0  -- distância máxima do drop no chão
Config.GiveDistance      = 3.0  -- distância máxima entre jogadores no "dar item"
Config.PickupDistance    = 2.5  -- distância máxima para pegar do chão
Config.GroundItemDistance = 8.0 -- alcance da listagem de itens no chão (NUI)
Config.UseDistance       = 2.0  -- distância para usar/equipar item no mundo

-- ==========================================================
--  COMPORTAMENTO
-- ==========================================================
Config.AllowDelete        = true  -- permite arrastar para o LIXO (destruir item)
Config.AllowSplit         = true  -- permite dividir stacks
Config.AllowGive          = true  -- permite dar item a outro jogador
Config.MaxStack           = 100   -- limite máximo por stack
Config.GroundItemExpire   = 30    -- minutos até o item do chão sumir (0 = nunca)
Config.AntiSpamMs         = 250   -- intervalo mínimo entre ações do mesmo jogador
Config.DefaultGroundProp  = 'prop_med_bag_01'
Config.EnableHotbarHud    = false  -- mostra a hotbar na tela mesmo com o inventário fechado (DESABILITADO: usa tx_hud)
Config.ShowGroundItems    = true  -- lista itens do chão no NUI

-- ==========================================================
--  ITENS INICIAIS (entregue na primeira vez que o jogador entra)
-- ==========================================================
Config.StartingItems = {
    { name = 'water',  amount = 2,  slot = 1 },
    { name = 'bread',  amount = 3,  slot = 2 },
    { name = 'phone',  amount = 1,  slot = 3 },
    { name = 'pistol', amount = 1,  slot = 4 },
}

-- ==========================================================
--  ANIMAÇÕES
--  (se o dict/clip não existir no seu GTA, a animação é ignorada
--   sem quebrar o sistema — ajuste para o que você utiliza)
-- ==========================================================
Config.Animations = {
    drop   = { dict = 'anim@pickup@pickup_medium', clip = 'pickup_cash', dur = 900 },
    pickup = { dict = 'anim@pickup@pickup_medium', clip = 'pickup_cash', dur = 900 },
    give   = { dict = 'missfinale_c2mcs_1',          clip = 'fin_c2_mcs_1_camman', dur = 1300 },
}

-- ==========================================================
--  EFEITOS / STATUS
-- ==========================================================
Config.EnableStatus    = true
Config.HungerPerHour   = 4.0
Config.ThirstPerHour  = 6.0
Config.LowStatusDamage = 1.0   -- dano por segundo quando status zerado

-- ==========================================================
--  TECLAS
--  (podem ser remapeadas em: Configurações > Mapeamento de teclas)
-- ==========================================================
-- O mapper KEYBOARD do FiveM resolve o parametro para um codigo VK do Windows, e o
-- VK da tecla ' depende do LAYOUT do teclado do jogador:
--   PT-BR (00000416): a tecla ' e o VK 0xC0 -> parametro 'OEM_3'  (padrao, Brasil)
--   US    (00000409): a tecla ' e o VK 0xDE -> parametro 'OEM_7' / 'APOSTROPHE'
-- No layout BR o VK 0xDE e a tecla do '~', por isso 'APOSTROPHE' nunca disparava.
Config.InventoryKey    = 'OEM_3'   -- tecla ' (apostrofo) - layout PT-BR
Config.InventoryKeyAlt = 'OEM_7'   -- tecla ' (apostrofo) - layout US (fallback)
Config.PickupKey       = 'E'       -- pegar item do chão no mundo 3D
