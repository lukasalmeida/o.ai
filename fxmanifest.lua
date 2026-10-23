fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Senior FiveM Developer'
description 'Sistema Multicharacter & Criação de Personagem - Tema Laranja'
version '1.0.0'

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

ui_page 'web/ui.html'

files {
    'web/ui.html',
    'web/style.css',
    'web/script.js'
}

shared_scripts {
    'config.lua'
}

dependencies {
    'oxmysql'
}

escrow_ignore {
    'config.lua',
    'client/main.lua',
    'server/main.lua',
    'web/**/*'
}