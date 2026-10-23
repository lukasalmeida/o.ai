fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'TX Studio'
description 'HUD completo para FiveM RP - tema dark glass com acento laranja (minimapa, status, velocimetro, quickbar, missoes e info do servidor)'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}
