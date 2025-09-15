description 'RSG Core Prop Placer'
author 'LekedogTV'

version '1.0.2'

dependency 'rsg-core'

fx_version "adamant"
games {"rdr3"}
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

shared_scripts {
   'config.lua'
}

client_scripts {
   'client/cl_main.lua'
}

server_scripts {
   'server/sv_main.lua',
   'server/versionchecker.lua'
}
