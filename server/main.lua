local Accounts <const> = require 'server.accounts'

require 'server.ui'
require 'server.admin'
require 'server.payroll'
require 'server.cascade'
require 'server.exports'

AddEventHandler('cobalt_core:server:jobsChanged', Accounts.EnsureSocietyAccounts)
AddEventHandler('cobalt_core:server:gangsChanged', Accounts.EnsureSocietyAccounts)
CreateThread(Accounts.EnsureSocietyAccounts)

AddEventHandler('cobalt_core:Server:PlayerLoaded', function(player)
    local account <const> = Accounts.EnsurePlayerAccount(player.PlayerData.citizenid)

    player.Functions.SyncBank(account?.balance or 0)
end)
