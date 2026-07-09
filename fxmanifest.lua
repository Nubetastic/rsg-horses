fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

description 'rsg-horses'
version '2.2.5'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'shared/functions.lua',
    'shared/training_config.lua',
}

client_scripts {
    'client/client.lua',
    'client/npcs.lua',
    'client/horses.lua',
    'client/action.lua',
    'client/horseinfo.lua',
    'client/dataview.lua',
    'client/training_client.lua',
}

files {
    'shared/horse_settings.lua',
    'shared/horse_comp.lua',
    'locales/*.json',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua',
    'server/versionchecker.lua',
    'server/training_server.lua'
}

dependencies {
    'rsg-core',
    'ox_lib',
}

lua54 'yes'

export 'CheckHorseLevel'
export 'CheckHorseBondingLevel'
export 'CheckActiveHorse'
