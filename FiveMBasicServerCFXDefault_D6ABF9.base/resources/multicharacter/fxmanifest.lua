fx_version 'cerulean'
game 'gta5'

name 'multicharacter_orange'
author 'Senior Dev'
description 'Orange-themed Multicharacter + Character Creation Lobby'
version '1.0.0'

ui_page 'web/ui.html'

files {
    'web/ui.html',
    'web/style.css',
    'web/script.js'
}

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependencies {
    'oxmysql'
}