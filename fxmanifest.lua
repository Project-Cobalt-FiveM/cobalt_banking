fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'cobalt_banking'
author 'Citgo'
description 'Cobalt Bank: personal, shared and society accounts, deposits, withdrawals, transfers and payroll'
version '1.0.0'

dependencies {
    'cobalt_mysql',
    'ox_lib',
    'ox_target',
    'cobalt_core',
}

shared_script '@ox_lib/init.lua'

ox_libs { 'locale' }

client_script 'client/main.lua'

server_scripts {
    '@cobalt_mysql/lib/MySQL.lua',
    '@cobalt_core/server/migrationgate.lua',
    'server/main.lua',
}

ui_page '_nui/build/index.html'

files {
    'config.lua',
    'locales/*.json',
    'client/atm.lua',
    'client/cashpoints.lua',
    '_nui/build/index.html',
    '_nui/build/assets/*',
}
