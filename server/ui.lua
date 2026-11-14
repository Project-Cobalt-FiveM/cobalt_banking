local config <const> = require 'config'
local enums <const> = require 'shared.enums'
local DB <const> = require 'server.database'
local Log <const> = require 'server.log'
local Accounts <const> = require 'server.accounts'
local Transactions <const> = require 'server.transactions'
local Cash <const> = require 'server.cash'
local Statements <const> = require 'server.statements'

local core <const> = exports.cobalt_core

local TransactionType <const> = enums.TransactionType
local MemberRole <const> = enums.MemberRole

local ACTIVITY_LIMIT <const> = 30
local HISTORY_DAYS <const> = 7

---@class BankSession
---@field coords vector3
---@field atm boolean

---@type table<integer, BankSession>
local sessions <const> = {}

---@type table<string, integer>
local withdrawn <const> = {}
local withdrawDay = os.date('%Y-%m-%d') --[[@as string]]

---@param citizenid string
---@return integer
local function withdrawnToday(citizenid)
    local day <const> = os.date('%Y-%m-%d') --[[@as string]]

    if day ~= withdrawDay then
        withdrawDay = day
        table.wipe(withdrawn)
    end

    return withdrawn[citizenid] or 0
end

---@param citizenid string
---@param amount integer
---@return string? day the day the amount counts against, nil when it would pass the daily limit
local function claimWithdrawal(citizenid, amount)
    local used <const> = withdrawnToday(citizenid) + amount

    if used > config.DailyWithdrawLimit then return end

    withdrawn[citizenid] = used

    return withdrawDay
end

---@param citizenid string
---@param amount integer
---@param day string the day `claimWithdrawal` returned
local function releaseWithdrawal(citizenid, amount, day)
    if day ~= withdrawDay or not withdrawn[citizenid] then return end

    withdrawn[citizenid] = math.max(withdrawn[citizenid] - amount, 0)
end

---@class BankResult
---@field ok boolean
---@field error? string

---@param message? string
---@return BankResult
local function fail(message)
    return { ok = false, error = message }
end

---@type vector3[]
local bankCounters <const> = {}

for i, bank in ipairs(config.Banks) do
    bankCounters[i] = bank.coords
end

---@param coords vector3
---@param points vector3[]
---@param range number
---@return boolean
local function within(coords, points, range)
    for _, point in ipairs(points) do
        if #(coords - point) <= range then return true end
    end

    return false
end

---@param coords vector3
---@param atm boolean
---@return boolean
local function nearCashPoint(coords, atm)
    if atm then return within(coords, config.ATMLocations, config.ATMRange) end

    return within(coords, bankCounters, config.BankRange)
end

---@param source integer
---@return vector3
local function playerCoords(source)
    return GetEntityCoords(GetPlayerPed(source))
end

---@class BankingUI
local UI <const> = {}

---@param source integer
---@param atm boolean
function UI.Grant(source, atm)
    sessions[source] = { coords = playerCoords(source), atm = atm }
end

---@param source integer
---@return string? citizenid
---@return BankSession? session
local function context(source)
    local session <const> = sessions[source]

    if not session then return end

    if #(playerCoords(source) - session.coords) > config.InteractionRange then
        sessions[source] = nil
        return
    end

    return Cash.GetCitizenId(source), session
end

---@param value any
---@param maxLength integer
---@return string?
local function parseText(value, maxLength)
    if type(value) ~= 'string' then return end
    local text <const> = value:gsub('^%s+', ''):gsub('%s+$', '')

    if text == '' or #text > maxLength then return end
    return text
end

---@param account BankAccount
---@param citizenid string
---@param primaryId AccountId?
local function accountView(account, citizenid, primaryId)
    return {
        id = account.accountId,
        label = account.label,
        type = account.type,
        balance = account.balance,
        primary = account.accountId == primaryId,
        members = account.members and #account.members or 0,
        owner = account.ownerCid == citizenid,
    }
end

---@param balance integer
---@param totals { daysAgo: integer, incoming: integer, outgoing: integer }[]
local function balanceHistory(balance, totals)
    local netByDay <const> = {}
    local incoming, outgoing = 0, 0

    for _, day in ipairs(totals) do
        netByDay[day.daysAgo] = day.incoming + day.outgoing
        incoming += day.incoming
        outgoing -= day.outgoing
    end

    local points <const> = {}
    local running = balance

    for daysAgo = 0, HISTORY_DAYS - 1 do
        points[HISTORY_DAYS - daysAgo] = running
        running -= netByDay[daysAgo] or 0
    end

    return { points = points, start = running, incoming = incoming, outgoing = outgoing }
end

---@param activity BankActivity[]
---@return BankActivity[]
local function withSocietyNames(activity)
    for _, entry in ipairs(activity) do
        if entry.counterpartyType == enums.AccountType.SOCIETY then
            entry.counterparty = Accounts.SocietyLabel(entry.counterparty)
        end
    end

    return activity
end

---@param citizenid string
---@param accountId any
---@return BankAccount|nil account
---@return string? error
local function movableAccount(citizenid, accountId)
    if type(accountId) ~= 'string' then return nil, locale('error.account_not_found') end

    if not Accounts.HasAccess(accountId, citizenid, MemberRole.MEMBER) then
        return nil, locale('error.no_permission')
    end

    local account <const> = DB.GetAccount(accountId)

    if not account then return nil, locale('error.account_not_found') end

    return account
end

lib.callback.register('cobalt_banking:open', function(source, atm)
    local atAtm <const> = atm == true

    if not nearCashPoint(playerCoords(source), atAtm) then
        if atAtm then
            core:Notify(source, { description = locale('notify.atm_out_of_service'), type = 'error' })
        end

        return false
    end

    UI.Grant(source, atAtm)

    return true
end)

RegisterNetEvent('cobalt_banking:server:close', function()
    sessions[source] = nil
end)

AddEventHandler('playerDropped', function()
    sessions[source] = nil
end)

lib.callback.register('cobalt_banking:overview', function(source)
    local citizenid <const>, session <const> = context(source)

    if not citizenid or not session then return end

    local primaryId <const> = Accounts.GetPrimaryAccount(citizenid)?.accountId
    local accounts <const> = {}

    for i, account in ipairs(Accounts.GetPlayerAccounts(citizenid, source)) do
        accounts[i] = accountView(account, citizenid, primaryId)
    end

    return {
        atm = session.atm,
        cash = Cash.GetCashAmount(source),
        accounts = accounts,
        withdrawLimit = config.DailyWithdrawLimit,
        withdrawnToday = withdrawnToday(citizenid),
        transferFeePercent = config.TransferFeePercent,
        maxSharedMembers = config.MaxSharedMembers,
    }
end)

lib.callback.register('cobalt_banking:account', function(source, accountId)
    local citizenid <const> = context(source)

    if not citizenid or type(accountId) ~= 'string' then return end
    if not Accounts.HasAccess(accountId, citizenid) then return end

    local account <const> = DB.GetAccount(accountId)

    if not account then return end

    return {
        history = balanceHistory(account.balance, DB.GetDailyTotals(accountId, HISTORY_DAYS - 1)),
        activity = withSocietyNames(DB.GetActivity(accountId, ACTIVITY_LIMIT)),
    }
end)

lib.callback.register('cobalt_banking:findPlayer', function(source, value)
    if not context(source) then return end

    local citizenid <const> = parseText(value, 50)

    if not citizenid then return end

    return DB.FindPlayer(citizenid)
end)

lib.callback.register('cobalt_banking:lookup', function(source, value)
    if not context(source) then return end

    return Statements.FindRecipient(value)
end)

lib.callback.register('cobalt_banking:deposit', function(source, data)
    local citizenid <const> = context(source)

    if not citizenid or type(data) ~= 'table' then
        return fail(locale('error.walk_up'))
    end

    local amount <const> = Transactions.ParseAmount(data.amount)

    if not amount then
        return fail(locale('error.invalid_amount'))
    end

    local account <const>, err <const> = movableAccount(citizenid, data.accountId)

    if not account then
        return fail(err)
    end

    local cash <const> = Cash.GetCashAmount(source)

    if not Cash.RemoveCash(source, amount, 'Bank deposit') then
        return fail(locale('error.not_enough_cash', cash))
    end

    local ok <const>, balance <const> = Transactions.Deposit(account.accountId, amount, {
        note = locale('statement.cash_deposit'),
        initiator = citizenid,
    })

    if not ok then
        Cash.AddCash(source, amount, 'Bank deposit refund')
        return fail(balance --[[@as string]])
    end

    Log.Transaction(source, 'deposit', amount, account.accountId)
    core:Notify(source, { description = locale('notify.deposited', amount), type = 'success' })

    return { ok = true, balance = balance }
end)

lib.callback.register('cobalt_banking:withdraw', function(source, data)
    local citizenid <const> = context(source)

    if not citizenid or type(data) ~= 'table' then
        return fail(locale('error.walk_up'))
    end

    local amount <const> = Transactions.ParseAmount(data.amount)

    if not amount then
        return fail(locale('error.invalid_amount'))
    end

    local account <const>, err <const> = movableAccount(citizenid, data.accountId)

    if not account then
        return fail(err)
    end

    local day <const> = claimWithdrawal(citizenid, amount)

    if not day then
        local left <const> = config.DailyWithdrawLimit - withdrawnToday(citizenid)
        return fail(locale('error.daily_limit', math.max(left, 0)))
    end

    local balance <const> = DB.Move(account.accountId, -amount, {
        type = TransactionType.WITHDRAWAL,
        description = locale('statement.cash_withdrawal'),
        initiated_by = citizenid,
    })

    if not balance then
        releaseWithdrawal(citizenid, amount, day)
        return fail(locale('error.insufficient_funds'))
    end

    if not Cash.AddCash(source, amount, 'Bank withdrawal') then
        DB.Move(account.accountId, amount, {
            type = TransactionType.DEPOSIT,
            description = locale('statement.withdrawal_refund'),
            initiated_by = citizenid,
        })
        releaseWithdrawal(citizenid, amount, day)

        return fail(locale('error.cash_handover_failed'))
    end

    Log.Transaction(source, 'withdrawal', amount, account.accountId)
    core:Notify(source, { description = locale('notify.withdrew', amount), type = 'success' })

    return { ok = true, balance = balance }
end)

lib.callback.register('cobalt_banking:transfer', function(source, data)
    local citizenid <const> = context(source)

    if not citizenid or type(data) ~= 'table' then
        return fail(locale('error.walk_up'))
    end

    local amount <const> = Transactions.ParseAmount(data.amount)

    if not amount then
        return fail(locale('error.invalid_amount'))
    end

    local result <const> = Transactions.Send(citizenid, {
        from = data.from,
        to = data.to,
        amount = amount,
        note = data.reference,
    })

    if not result.ok then
        return fail(locale(('transfer_error.%s'):format(result.reason)))
    end

    return { ok = true, balance = result.balance, receipt = result.receipt, fee = result.fee }
end)

---@param citizenid string
---@param value any
---@return string[]|nil members
---@return string? error
local function parseMembers(citizenid, value)
    if type(value) ~= 'table' then
        return {}
    end

    if #value > config.MaxSharedMembers then
        return nil, locale('error.member_limit', config.MaxSharedMembers)
    end

    local members <const>, seen <const> = {}, { [citizenid] = true }
    for _, entry in ipairs(value) do
        local memberId <const> = parseText(entry, 50)
        if memberId and not seen[memberId] then
            if not DB.FindPlayer(memberId) then
                return nil, locale('error.no_state_id', memberId)
            end

            seen[memberId] = true
            members[#members + 1] = memberId
        end
    end
    return members
end

---@param value any
---@return integer?
local function openingDeposit(value)
    if not value or value == 0 or value == '' then return 0 end

    return Transactions.ParseAmount(value)
end

lib.callback.register('cobalt_banking:createAccount', function(source, data)
    local citizenid <const>, session <const> = context(source)

    if not citizenid or not session or type(data) ~= 'table' then
        return fail(locale('error.walk_up'))
    end

    if session.atm then return fail(locale('error.atm_new_account')) end

    local label <const> = parseText(data.label, 32)

    if not label then
        return fail(locale('error.account_name'))
    end

    local members <const>, err <const> = parseMembers(citizenid, data.members)

    if not members then return fail(err) end

    local deposit <const> = openingDeposit(data.deposit)

    if not deposit then return fail(locale('error.invalid_opening_deposit')) end

    local primary <const> = Accounts.GetPrimaryAccount(citizenid)

    if deposit > 0 and not primary then
        return fail(locale('error.no_checking'))
    end

    local accountType <const> = enums.AccountType.SHARED
    local accountId <const> = Accounts.GenerateAccountNumber()
    local receipt <const> = Transactions.NewReceipt()
    local atLimit = false
    local committed <const> = DB.Atomic(function(tx)
        if not DB.HasAccountSlot(tx, citizenid, accountType, config.AccountTypes.shared.maxPerPlayer, members) then
            atLimit = true
            return false
        end

        DB.InsertAccount(tx, {
            accountId = accountId,
            type = accountType,
            label = label,
            ownerCid = citizenid,
        })
        DB.InsertMember(tx, accountId, citizenid, MemberRole.OWNER)

        for _, memberId in ipairs(members) do
            DB.InsertMember(tx, accountId, memberId, MemberRole.MEMBER)
        end

        if deposit == 0 or not primary then return true end

        return tx:move(primary.accountId, -deposit, {
            type = TransactionType.TRANSFER_OUT,
            description = locale('statement.opening_deposit'),
            reference_id = accountId,
            receipt = receipt,
            initiated_by = citizenid,
            counterparty = accountId,
        }) ~= nil and tx:move(accountId, deposit, {
            type = TransactionType.TRANSFER_IN,
            description = locale('statement.opening_deposit'),
            reference_id = primary.accountId,
            receipt = receipt,
            initiated_by = citizenid,
            counterparty = primary.accountId,
        }) ~= nil
    end)

    if atLimit then
        return fail(locale('error.shared_limit'))
    end

    if not committed then
        return fail(locale('error.opening_deposit_short'))
    end

    return { ok = true, accountId = accountId }
end)

return UI
