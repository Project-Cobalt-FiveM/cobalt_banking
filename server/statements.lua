local enums <const> = require 'shared.enums'
local DB <const> = require 'server.database'
local Accounts <const> = require 'server.accounts'

local DEFAULT_PAGE <const> = 20
local MAX_PAGE <const> = 50
local RECENT_RECIPIENTS <const> = 5

---@type table<string, BankStatementDirection>
local DIRECTIONS <const> = { all = 'all', ['in'] = 'in', out = 'out' }

---@class BankingStatements
local Statements <const> = {}

---@param accountType string?
---@param name string?
---@return string?
local function displayName(accountType, name)
    if accountType == enums.AccountType.SOCIETY and name then
        return Accounts.SocietyLabel(name)
    end

    return name
end

---@param row BankStatementRow
---@return BankingStatementEntry
local function toEntry(row)
    return {
        id = row.id,
        accountId = row.accountId,
        type = row.type,
        amount = row.amount,
        note = row.description,
        balanceAfter = row.balanceAfter,
        receipt = row.receipt,
        counterparty = row.counterpartyAccountId and {
            accountId = row.counterpartyAccountId,
            type = row.counterpartyType,
            name = displayName(row.counterpartyType, row.counterpartyName),
        } or nil,
        initiator = row.initiatedBy and {
            citizenid = row.initiatedBy,
            name = row.initiatorName,
        } or nil,
        createdAt = row.createdAt,
    }
end

---@param value any
---@return integer
local function pageSize(value)
    if math.type(value) ~= 'integer' then
        return DEFAULT_PAGE
    end

    return math.max(1, math.min(value, MAX_PAGE))
end

---@param citizenid string
---@param accountId any
---@param query? BankingStatementQuery
---@return BankingStatementPage|BankingRefusal
function Statements.Page(citizenid, accountId, query)
    if type(accountId) ~= 'string' then
        return { ok = false, reason = 'not_found' }
    end

    if not Accounts.HasAccess(accountId, citizenid) then
        return { ok = false, reason = 'no_permission' }
    end

    local limit <const> = pageSize(query?.limit)
    local before <const> = query and math.type(query.before) == 'integer' and query.before or nil
    local rows <const> = DB.GetStatement(accountId, limit + 1, before, DIRECTIONS[query?.direction] or 'all')
    local entries <const> = {}

    for i = 1, math.min(#rows, limit) do
        entries[i] = toEntry(rows[i])
    end

    return {
        ok = true,
        entries = entries,
        nextCursor = #rows > limit and entries[limit].id or nil,
    }
end

---@param citizenid string
---@param transactionId any
---@return { ok: true, entry: BankingStatementEntry }|BankingRefusal
function Statements.Entry(citizenid, transactionId)
    local row <const> = math.type(transactionId) == 'integer' and DB.GetStatementRow(transactionId)

    if not row then
        return { ok = false, reason = 'not_found' }
    end

    if not Accounts.HasAccess(row.accountId, citizenid) then
        return { ok = false, reason = 'no_permission' }
    end

    return { ok = true, entry = toEntry(row) }
end

---@param query any account number or citizen ID
---@return BankingRecipient?
function Statements.FindRecipient(query)
    if type(query) ~= 'string' then return end

    local trimmed <const> = query:match('^%s*(.-)%s*$')

    if trimmed == '' or #trimmed > 64 then return end

    local holder <const> = Accounts.FindHolder(trimmed)

    if not holder then return end

    return {
        accountId = holder.accountId,
        type = holder.type,
        label = holder.label,
        name = displayName(holder.type, holder.holder) or holder.accountId,
    }
end

---@param citizenid string
---@param limit? integer
---@return BankingRecipient[]
function Statements.RecentRecipients(citizenid, limit)
    local recipients <const> = {}
    local wanted <const> = math.type(limit) == 'integer' and limit --[[@as integer]]
    local count <const> = wanted and math.max(1, math.min(wanted, 20)) or RECENT_RECIPIENTS

    for i, row in ipairs(DB.GetRecentRecipients(citizenid, count)) do
        recipients[i] = {
            accountId = row.accountId,
            type = row.type,
            name = displayName(row.type, row.holder) or row.accountId,
            lastAt = row.lastAt,
        }
    end

    return recipients
end

return Statements
