-- ==========================================================
--  TX_INVENTORY | Sistema de Inventário + Mochila + Hotbar
--  Compatível com: Standalone | ESX | QBCore | vRP (via adapter)
--  Banco de dados:  oxmysql (padrão) | ghmattimysql (fallback)
-- ==========================================================

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'tx_inventory'
author 'TX Studio'
description 'Inventário completo com mochila, hotbar, drag & drop, chão 3D e troca de itens.'
version '1.0.2'

ui_page 'html/index.html'

-- ----------------------------------------------------------
--  Shared (servidor + cliente)
-- ----------------------------------------------------------
shared_scripts {
    'config.lua',
    'shared/items.lua',
}

-- ----------------------------------------------------------
--  Cliente
-- ----------------------------------------------------------
client_scripts {
    'client/animations.lua',
    'client/effects.lua',
    'client/main.lua',
}

-- ----------------------------------------------------------
--  Servidor
-- ----------------------------------------------------------
server_scripts {
    'server/database.lua',
    'server/framework.lua',
    'server/main.lua',
    'server/validate.lua',
}

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/img/*',
}
