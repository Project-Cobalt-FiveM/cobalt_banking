local enums <const> = require 'shared.enums'

local Cobalt <const> = exports.cobalt_core:GetCoreObject()

---@class BankingDB
local DB <const> = {}

---@alias AccountId string

---@alias BankAccount BankingAccount

---@class BankTxEntry
---@field type string
---@field description? string
---@field reference_id? string
---@field initiated_by? string
---@field counterparty? AccountId
---@field receipt? string

local ACCOUNT_COLUMNS <const> = [[
    account_id AS id, account_id AS accountId, type, label, balance, owner_cid AS ownerCid, frozen,
    UNIX_TIMESTAMP(created_at) AS createdAt
]]

local INSERT_TRANSACTION <const> = [[
    INSERT INTO bank_transactions
        (account_id, counterparty_account_id, type, amount, description, balance_after, reference_id, receipt, initiated_by)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
]]

local MOVE <const> = [[
    UPDATE bank_accounts SET balance = balance + ?, last_updated = CURRENT_TIMESTAMP
    WHERE account_id = ? AND balance + ? >= 0
]]
local MOVE_UNFROZEN <const> = MOVE .. ' AND frozen = 0'

---@param accountId AccountId
local function syncPlayerDataBank(accountId)
    local row <const> = MySQL.single.await('SELECT type, owner_cid, balance FROM bank_accounts WHERE account_id = ?', { accountId })
    if not row or row.type ~= 'personal' or not row.owner_cid then return end

    local player <const> = Cobalt.Functions.GetPlayerByCitizenId(row.owner_cid)

    if not player or player.Offline then return end

    player.Functions.SyncBank(row.balance)
end

---@class BankTx
---@field query fun(sql: string, params?: table): any
---@field touched table<AccountId, integer>
local BankTx <const> = {}
BankTx.__index = BankTx

---@param sql string
---@param params? table
---@return integer affectedRows
function BankTx:exec(sql, params)
    return self.query(sql, params).affectedRows
end

---@param sql string
---@param params? table
---@return integer insertId
function BankTx:insert(sql, params)
    return self.query(sql, params).insertId
end

---@param accountId AccountId
---@param entry BankTxEntry
---@param balanceAfter integer?
---@return integer transactionId
function BankTx:record(accountId, entry, balanceAfter)
    return self:insert(INSERT_TRANSACTION, {
        accountId, entry.counterparty, entry.type, entry.amount, entry.description,
        balanceAfter, entry.reference_id, entry.receipt, entry.initiated_by,
    })
end

---Moves `delta` in or out of an account; refuses a frozen account unless `ignoreFrozen`, and never lets the balance go below zero.
---@param accountId AccountId
---@param delta integer
---@param entry BankTxEntry
---@param ignoreFrozen? boolean
---@return integer? balanceAfter
---@return integer? transactionId
function BankTx:move(accountId, delta, entry, ignoreFrozen)
    if self:exec(ignoreFrozen and MOVE or MOVE_UNFROZEN, { delta, accountId, delta }) == 0 then return end

    local balanceAfter <const> = self.query('SELECT balance FROM bank_accounts WHERE account_id = ?', { accountId })[1].balance
    local transactionId <const> = self:record(accountId, {
        type = entry.type,
        amount = delta,
        description = entry.description,
        reference_id = entry.reference_id,
        receipt = entry.receipt,
        initiated_by = entry.initiated_by,
        counterparty = entry.counterparty,
    }, balanceAfter)
    self.touched[accountId] = balanceAfter
    return balanceAfter, transactionId
end

---@param steps fun(tx: BankTx): boolean
---@return boolean committed
function DB.Atomic(steps)
    local touched <const> = {}
    local committed <const> = MySQL.startTransaction(function(query)
        return steps(setmetatable({ query = query, touched = touched }, BankTx)) == true
    end)
    if not committed then return false end

    for accountId, balance in pairs(touched) do
        syncPlayerDataBank(accountId)
        TriggerEvent('cobalt_banking:balanceChanged', accountId, balance)
    end

    return true
end

---@param accountId AccountId
---@param delta integer
---@param entry BankTxEntry
---@param ignoreFrozen? boolean
---@return integer? balanceAfter
function DB.Move(accountId, delta, entry, ignoreFrozen)
    local balanceAfter
    DB.Atomic(function(tx)
        balanceAfter = tx:move(accountId, delta, entry, ignoreFrozen)
        return balanceAfter ~= nil
    end)
    return balanceAfter
end

---@param accountId AccountId
---@return BankAccount?
function DB.GetAccount(accountId)
    return MySQL.single.await('SELECT ' .. ACCOUNT_COLUMNS .. ' FROM bank_accounts WHERE account_id = ?', { accountId })
end


---@param accounts BankAccount[]
---@return BankAccount[]
local function withMembers(accounts)
    if #accounts == 0 then return accounts end
    local byId <const>, ids <const> = {}, {}

    for i, account in ipairs(accounts) do
        account.members = {}
        byId[account.accountId] = account
        ids[i] = account.accountId
    end
    local rows <const> = MySQL.query.await([[
        SELECT account_id, citizenid AS cid, role, UNIX_TIMESTAMP(added_at) AS addedAt
        FROM bank_account_members WHERE account_id IN (?) ORDER BY id
    ]], { ids })

    for _, row in ipairs(rows) do
        local members <const> = byId[row.account_id].members
        members[#members + 1] = { cid = row.cid, role = row.role, addedAt = row.addedAt }
    end

    return accounts
end

---@param citizenid string
---@return BankAccount[]
function DB.GetPlayerAccounts(citizenid)
    return withMembers(MySQL.query.await('SELECT ' .. ACCOUNT_COLUMNS .. [[
        FROM bank_accounts
        WHERE owner_cid = ?
           OR account_id IN (SELECT account_id FROM bank_account_members WHERE citizenid = ?)
        ORDER BY id
    ]], { citizenid, citizenid }))
end

---@param citizenid string
---@param accountType string
---@return BankAccount[]
function DB.GetAccountsByType(citizenid, accountType)
    return MySQL.query.await(
        'SELECT ' .. ACCOUNT_COLUMNS .. ' FROM bank_accounts WHERE owner_cid = ? AND type = ? ORDER BY id',
        { citizenid, accountType }
    )
end

---@param citizenids string[]
---@param accountType string
---@return table<string, BankAccount> accounts each citizenid's first account of that type
function DB.GetFirstAccountsByType(citizenids, accountType)
    local first <const> = {}

    if #citizenids == 0 then return first end

    local rows <const> = MySQL.query.await(
        'SELECT ' .. ACCOUNT_COLUMNS .. ' FROM bank_accounts WHERE type = ? AND owner_cid IN (?) ORDER BY id',
        { accountType, citizenids }
    ) or {}

    for _, row in ipairs(rows) do first[row.ownerCid] = first[row.ownerCid] or row end

    return first
end

---@param accounts [AccountId, string][]
function DB.EnsureSocietyAccounts(accounts)
    if #accounts == 0 then return end
    MySQL.prepare.await([[
        INSERT INTO bank_accounts (account_id, type, label) VALUES (?, 'society', ?)
        ON DUPLICATE KEY UPDATE account_id = account_id
    ]], accounts)
end

---@param accountId AccountId
---@param newOwnerCid string
function DB.SetOwner(accountId, newOwnerCid)
    MySQL.update.await('UPDATE bank_accounts SET owner_cid = ?, last_updated = CURRENT_TIMESTAMP WHERE account_id = ?',
        { newOwnerCid, accountId })
end

---@param accountId AccountId
---@param citizenid string
function DB.RemoveMember(accountId, citizenid)
    MySQL.update.await('DELETE FROM bank_account_members WHERE account_id = ? AND citizenid = ?', { accountId, citizenid })
end

---@param accountId AccountId
---@param citizenid string
---@return string?
function DB.GetMemberRole(accountId, citizenid)
    return MySQL.scalar.await('SELECT role FROM bank_account_members WHERE account_id = ? AND citizenid = ?',
        { accountId, citizenid })
end

---@param fromAccountId AccountId
---@param toAccountId AccountId
---@param amount integer
---@param description string
---@param initiatedBy string
---@param types? { out: string, ['in']: string }
---@return integer? fromBalance
function DB.Transfer(fromAccountId, toAccountId, amount, description, initiatedBy, types)
    local fromBalance
    DB.Atomic(function(tx)
        fromBalance = tx:move(fromAccountId, -amount, {
            type = types?.out or enums.TransactionType.TRANSFER_OUT,
            description = description,
            reference_id = toAccountId,
            initiated_by = initiatedBy,
            counterparty = toAccountId,
        })
        if not fromBalance then return false end

        return tx:move(toAccountId, amount, {
            type = types and types['in'] or enums.TransactionType.TRANSFER_IN,
            description = description,
            reference_id = fromAccountId,
            initiated_by = initiatedBy,
            counterparty = fromAccountId,
        }) ~= nil
    end)
    return fromBalance
end

local PLAYER_NAME <const> = "CONCAT_WS(' ', JSON_VALUE(%s.charinfo, '$.firstname'), JSON_VALUE(%s.charinfo, '$.lastname'))"

---@param alias string
---@return string
local function playerName(alias)
    return PLAYER_NAME:format(alias, alias)
end

---@param tx BankTx
---@param data { accountId: AccountId, type: string, label: string, ownerCid: string, balance?: integer }
function DB.InsertAccount(tx, data)
    tx:exec([[
        INSERT INTO bank_accounts (account_id, type, label, balance, owner_cid)
        VALUES (?, ?, ?, ?, ?)
    ]], { data.accountId, data.type, data.label, data.balance or 0, data.ownerCid })
end

local LOCK_PLAYERS <const> = 'SELECT citizenid FROM players WHERE citizenid IN (?) ORDER BY citizenid FOR UPDATE'
local COUNT_OWNED <const> = 'SELECT COUNT(*) AS total FROM bank_accounts WHERE owner_cid = ? AND type = ?'

---@param tx BankTx
---@param citizenid string
---@param accountType string
---@param limit integer
---@param members? string[] citizenids joining the account, locked with the owner in one sorted pass
---@return boolean free true while the character owns fewer than `limit` accounts of that type
function DB.HasAccountSlot(tx, citizenid, accountType, limit, members)
    local locked <const> = { citizenid }

    for _, member in ipairs(members or {}) do locked[#locked + 1] = member end

    tx.query(LOCK_PLAYERS, { locked })

    return tx.query(COUNT_OWNED, { citizenid, accountType })[1].total < limit
end

---@param tx BankTx
---@param accountId AccountId
---@param citizenid string
---@param role string
function DB.InsertMember(tx, accountId, citizenid, role)
    tx:exec('INSERT INTO bank_account_members (account_id, citizenid, role) VALUES (?, ?, ?)', { accountId, citizenid, role })
end

---@param tx BankTx
---@param citizenid string
---@param amount integer
---@param limit integer
---@return boolean claimed
function DB.ClaimWithdrawLimit(tx, citizenid, amount, limit)
    tx:exec('INSERT IGNORE INTO bank_withdraw_limits (citizenid, day, used) VALUES (?, CURDATE(), 0)', { citizenid })
    return tx:exec([[
        UPDATE bank_withdraw_limits SET used = used + ?
        WHERE citizenid = ? AND day = CURDATE() AND used + ? <= ?
    ]], { amount, citizenid, amount, limit }) == 1
end

---@param citizenid string
---@return integer
function DB.GetWithdrawnToday(citizenid)
    return MySQL.scalar.await('SELECT used FROM bank_withdraw_limits WHERE citizenid = ? AND day = CURDATE()', { citizenid }) or 0
end

function DB.PruneWithdrawLimits()
    MySQL.update.await('DELETE FROM bank_withdraw_limits WHERE day < CURDATE()')
end

---@param accountId AccountId
---@param days integer
---@return { daysAgo: integer, incoming: integer, outgoing: integer }[]
function DB.GetDailyTotals(accountId, days)
    return MySQL.query.await([[
        SELECT DATEDIFF(CURDATE(), DATE(created_at)) AS daysAgo,
            CAST(SUM(GREATEST(amount, 0)) AS SIGNED) AS incoming,
            CAST(SUM(LEAST(amount, 0)) AS SIGNED) AS outgoing
        FROM bank_transactions
        WHERE account_id = ? AND created_at >= CURDATE() - INTERVAL ? DAY
        GROUP BY daysAgo ORDER BY daysAgo
    ]], { accountId, days })
end

---@class BankActivity
---@field id integer
---@field type string
---@field amount integer
---@field description string?
---@field counterparty string?
---@field counterpartyType string?
---@field receipt string?
---@field timestamp string

---@param accountId AccountId
---@param limit integer
---@return BankActivity[]
function DB.GetActivity(accountId, limit)
    return MySQL.query.await(([[
        SELECT t.id, t.type, t.amount, t.description, t.receipt,
            IF(c.type = 'personal', %s, c.label) AS counterparty, c.type AS counterpartyType,
            DATE_FORMAT(t.created_at, '%%Y-%%m-%%dT%%T') AS timestamp
        FROM bank_transactions t
        LEFT JOIN bank_accounts c ON c.account_id = t.counterparty_account_id
        LEFT JOIN players p ON p.citizenid = c.owner_cid
        WHERE t.account_id = ?
        ORDER BY t.created_at DESC, t.id DESC LIMIT ?
    ]]):format(playerName('p')), { accountId, limit })
end

---@param citizenid string
---@return { citizenid: string, name: string }?
function DB.FindPlayer(citizenid)
    return MySQL.single.await(
        'SELECT citizenid, ' .. playerName('players') .. ' AS name FROM players WHERE citizenid = ?',
        { citizenid }
    )
end

---@param accountId AccountId
---@return { accountId: AccountId, label: string?, type: string, frozen: 0|1, holder: string? }?
function DB.GetAccountHolder(accountId)
    return MySQL.single.await(([[
        SELECT a.account_id AS accountId, a.label, a.type, a.frozen,
            IF(a.type = 'personal', %s, a.label) AS holder
        FROM bank_accounts a
        LEFT JOIN players p ON p.citizenid = a.owner_cid
        WHERE a.account_id = ?
    ]]):format(playerName('p')), { accountId })
end

---@class BankStatementRow
---@field id integer
---@field accountId AccountId
---@field type string
---@field amount integer
---@field description string?
---@field balanceAfter integer?
---@field receipt string?
---@field counterpartyAccountId AccountId?
---@field counterpartyType string?
---@field counterpartyName string?
---@field initiatedBy string?
---@field initiatorName string?
---@field createdAt integer epoch seconds

local STATEMENT_SELECT <const> = ([[
    SELECT t.id, t.account_id AS accountId, t.type, t.amount, t.description,
        t.balance_after AS balanceAfter, t.receipt,
        t.counterparty_account_id AS counterpartyAccountId, c.type AS counterpartyType,
        IF(c.type = 'personal', %s, c.label) AS counterpartyName,
        t.initiated_by AS initiatedBy, %s AS initiatorName,
        UNIX_TIMESTAMP(t.created_at) AS createdAt
    FROM bank_transactions t
    LEFT JOIN bank_accounts c ON c.account_id = t.counterparty_account_id
    LEFT JOIN players p ON p.citizenid = c.owner_cid
    LEFT JOIN players i ON i.citizenid = t.initiated_by
]]):format(playerName('p'), playerName('i'))

local DIRECTION_FILTER <const> = {
    all = '',
    ['in'] = ' AND t.amount > 0',
    out = ' AND t.amount < 0',
}

---@alias BankStatementDirection 'all'|'in'|'out'

---@param accountId AccountId
---@param limit integer
---@param beforeId? integer
---@param direction BankStatementDirection
---@return BankStatementRow[]
function DB.GetStatement(accountId, limit, beforeId, direction)
    return MySQL.query.await(STATEMENT_SELECT .. [[
        WHERE t.account_id = ? AND (? = 0 OR t.id < ?)]] .. DIRECTION_FILTER[direction] .. [[
        ORDER BY t.id DESC LIMIT ?
    ]], { accountId, beforeId or 0, beforeId or 0, limit })
end

---@param transactionId integer
---@return BankStatementRow?
function DB.GetStatementRow(transactionId)
    return MySQL.single.await(STATEMENT_SELECT .. ' WHERE t.id = ?', { transactionId })
end

---@class BankRecipientRow
---@field accountId AccountId
---@field type string
---@field label string?
---@field holder string?
---@field lastAt integer epoch seconds

---@param citizenid string
---@param limit integer
---@return BankRecipientRow[]
function DB.GetRecentRecipients(citizenid, limit)
    return MySQL.query.await(([[
        SELECT t.counterparty_account_id AS accountId, c.type, c.label,
            IF(c.type = 'personal', %s, c.label) AS holder,
            UNIX_TIMESTAMP(MAX(t.created_at)) AS lastAt
        FROM bank_transactions t
        JOIN bank_accounts c ON c.account_id = t.counterparty_account_id
        LEFT JOIN players p ON p.citizenid = c.owner_cid
        WHERE t.initiated_by = ? AND t.type = 'transfer_out' AND c.frozen = 0
          AND (c.owner_cid IS NULL OR c.owner_cid <> ?)
        GROUP BY t.counterparty_account_id, c.type, c.label, p.charinfo
        ORDER BY MAX(t.id) DESC LIMIT ?
    ]]):format(playerName('p')), { citizenid, citizenid, limit })
end

---@param accountId AccountId
---@return { citizenid: string, role: string, name: string }[]
function DB.GetMembers(accountId)
    return MySQL.query.await(([[
        SELECT m.citizenid, m.role, %s AS name
        FROM bank_account_members m
        JOIN players p ON p.citizenid = m.citizenid
        WHERE m.account_id = ?
        ORDER BY m.id
    ]]):format(playerName('p')), { accountId })
end

local LOCK_ACCOUNT <const> = 'SELECT account_id FROM bank_accounts WHERE account_id = ? FOR UPDATE'

local INSERT_MEMBER_UNDER_LIMIT <const> = [[
    INSERT INTO bank_account_members (account_id, citizenid, role)
    SELECT ?, p.citizenid, ?
    FROM players p
    CROSS JOIN (
        SELECT COUNT(*) AS total, COALESCE(SUM(citizenid = ?), 0) AS present
        FROM bank_account_members
        WHERE account_id = ?
    ) m
    WHERE p.citizenid = ? AND m.present = 0 AND m.total <= ?
]]

---@param accountId AccountId
---@param citizenid string
---@param role string
---@param maxOthers integer members allowed besides the owner
---@return boolean added false when the account is full or the character is already on it
function DB.AddMemberUnderLimit(accountId, citizenid, role, maxOthers)
    return MySQL.startTransaction(function(query)
        if not query(LOCK_ACCOUNT, { accountId })[1] then return false end

        local inserted <const> = query(INSERT_MEMBER_UNDER_LIMIT, {
            accountId,
            role,
            citizenid,
            accountId,
            citizenid,
            maxOthers,
        })

        return inserted.affectedRows == 1
    end) == true
end

return DB
