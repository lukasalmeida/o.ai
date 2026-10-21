fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Olezele'
description 'Painel admin in-game inspirado no txAdmin - abra com /cpanel'
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
