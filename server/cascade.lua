local DB <const> = require 'server.database'

---@param accountId AccountId
---@param citizenid string
local function handOver(accountId, citizenid)
    local heir <const> = MySQL.scalar.await([[
        SELECT citizenid FROM bank_account_members
        WHERE account_id = ? AND citizenid <> ? ORDER BY added_at, id LIMIT 1
    ]], { accountId, citizenid })

    if heir then
        DB.SetOwner(accountId, heir)
    else
        MySQL.update.await('DELETE FROM bank_accounts WHERE account_id = ?', { accountId })
    end
end

---@param citizenid string
---@param reason? string
local function archiveCharacterBanking(citizenid, reason)
    if type(citizenid) ~= 'string' or citizenid == '' then return end

    for _, account in ipairs(MySQL.query.await('SELECT account_id FROM bank_accounts WHERE owner_cid = ?', { citizenid })) do
        handOver(account.account_id, citizenid)
    end

    MySQL.update.await(
        "UPDATE bank_transactions SET initiated_by_archived = initiated_by, initiated_by = '__deleted__' WHERE initiated_by = ?",
        { citizenid }
    )

    lib.print.info(('Archived banking for %s (%s)'):format(citizenid, reason or 'voluntary'))
end

AddEventHandler('cobalt_core:characterDeleting', archiveCharacterBanking)

lib.cron.new('0 4 * * *', function()
    MySQL.update.await('DELETE FROM bank_transactions WHERE created_at < CURRENT_TIMESTAMP - INTERVAL 180 DAY')
end)
