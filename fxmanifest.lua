fx_version 'cerulean'
game 'gta5'

name 'Advanced Garage System'
description 'Système de garage complet pour serveur FiveM RP'
author 'Expert Lua Developer'
version '1.0.0'

shared_scripts {
    '@es_extended/imports.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/ui.lua',
    'client/utils.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/commands.lua',
    'server/webhooks.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/images/*.png'
}

dependencies {
    'es_extended',
    'oxmysql'
}

lua54 'yes'