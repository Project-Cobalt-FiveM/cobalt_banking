local config <const> = require 'config'
local enums <const> = require 'shared.enums'
local DB <const> = require 'server.database'
local Accounts <const> = require 'server.accounts'
local Transactions <const> = require 'server.transactions'
local Cash <const> = require 'server.cash'
local Log <const> = require 'server.log'

local Cobalt <const> = exports.cobalt_core:GetCoreObject()

local TransactionType <const> = enums.TransactionType

local DEFAULT_LIMIT <const> = 50
local MAX_LIMIT <const> = 500
local MAX_DUE_DAYS <const> = 365
local TOTALS_WINDOW <const> = 7 * 86400

local SELECT <const> = ([[
    SELECT i.id, i.issuer, i.citizenid, %s AS payerName, i.payee,
        i.issuer_citizenid AS issuerCitizenid, i.issuer_name AS issuerName, i.summary, i.amount,
        IF(i.status = 'unpaid' AND i.due_at < NOW(), 'overdue', i.status) AS status, i.data,
        UNIX_TIMESTAMP(i.due_at) AS dueAt, UNIX_TIMESTAMP(i.created_at) AS createdAt,
        UNIX_TIMESTAMP(i.declined_at) AS declinedAt, UNIX_TIMESTAMP(i.paid_at) AS paidAt,
        i.void_reason AS voidReason
    FROM invoices i
    JOIN players p ON p.citizenid = i.citizenid
]]):format(DB.PlayerName('p'))

local INSERT <const> = [[
    INSERT INTO invoices (issuer, citizenid, payee, issuer_citizenid, issuer_name, summary, amount, data, due_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW() + INTERVAL ? DAY)
]]

local MARK_PAID <const> = "UPDATE invoices SET status = 'paid', paid_at = NOW() WHERE id = ? AND status = 'unpaid'"
local MARK_DECLINED <const> = "UPDATE invoices SET declined_at = NOW() WHERE id = ? AND status = 'unpaid'"
local MARK_VOID <const> = "UPDATE invoices SET status = 'void', void_reason = ? WHERE id = ? AND status = 'unpaid'"

local TOTALS <const> = [[
    SELECT
        CAST(COALESCE(SUM(IF(i.status = 'unpaid', i.amount, 0)), 0) AS SIGNED) AS unpaid,
        CAST(COALESCE(SUM(i.status = 'unpaid'), 0) AS SIGNED) AS unpaidCount,
        CAST(COALESCE(SUM(IF(i.status = 'unpaid' AND i.due_at < NOW(), i.amount, 0)), 0) AS SIGNED) AS overdue,
        CAST(COALESCE(SUM(i.status = 'unpaid' AND i.due_at < NOW()), 0) AS SIGNED) AS overdueCount,
        CAST(COALESCE(SUM(IF(i.status <> 'void' AND i.created_at >= FROM_UNIXTIME(?), i.amount, 0)), 0) AS SIGNED)
            AS billed,
        CAST(COALESCE(SUM(IF(i.status = 'paid' AND i.paid_at >= FROM_UNIXTIME(?), i.amount, 0)), 0) AS SIGNED)
            AS paid
    FROM invoices i
]]

local OWED <const> = 'SELECT i.citizenid, CAST(SUM(i.amount) AS SIGNED) AS owed FROM invoices i'

local STATUS_FILTER <const> = {
    unpaid = "i.status = 'unpaid'",
    overdue = "i.status = 'unpaid' AND i.due_at < NOW()",
    paid = "i.status = 'paid'",
    void = "i.status = 'void'",
}

local DATA_VALUE <const> = { string = true, number = true, boolean = true }

---@class BankingInvoices
local Invoices <const> = {}

---@param reason BankingFailure
---@return BankingRefusal
local function refuse(reason)
    return { ok = false, reason = reason }
end

---@param value any
---@return integer?
local function toId(value)
    local id <const> = math.tointeger(tonumber(value))

    return id and id > 0 and id or nil
end

---@param value any
---@param maxLength integer
---@return string? text trimmed, nil when empty or longer than `maxLength`
local function parseText(value, maxLength)
    if type(value) ~= 'string' then return end

    local text <const> = value:match('^%s*(.-)%s*$')

    if text == '' or #text > maxLength then return end

    return text
end

---@param id integer
---@return string
local function invoiceNumber(id)
    return ('INV-%d'):format(id)
end

---@param invoice BankingInvoice
---@return string
local function statementNote(invoice)
    return invoice.summary ~= '' and invoice.summary or locale('statement.invoice', invoiceNumber(invoice.id))
end

---@param value any
---@return boolean
local function isCitizenFilter(value)
    if type(value) == 'string' then
        return value ~= ''
    end

    if type(value) ~= 'table' or #value == 0 then return false end

    for _, citizenid in ipairs(value) do
        if type(citizenid) ~= 'string' then return false end
    end

    return true
end

---@param query BankingInvoiceQuery
---@return string[]? conditions nil when a filter is malformed
---@return any[] params
local function filterConditions(query)
    local conditions <const>, params <const> = {}, {}

    if query.citizenid ~= nil then
        if not isCitizenFilter(query.citizenid) then
            return nil, params
        end

        conditions[#conditions + 1] = 'i.citizenid IN (?)'
        params[#params + 1] = query.citizenid
    end

    if query.issuer ~= nil then
        if type(query.issuer) ~= 'string' then
            return nil, params
        end

        conditions[#conditions + 1] = 'i.issuer = ?'
        params[#params + 1] = query.issuer
    end

    if query.status ~= nil then
        local status <const> = STATUS_FILTER[query.status]

        if not status then
            return nil, params
        end

        conditions[#conditions + 1] = status
    end

    if query.data ~= nil then
        if type(query.data) ~= 'table' then
            return nil, params
        end

        for key, value in pairs(query.data) do
            if type(key) ~= 'string' or not key:match('^[%a_][%w_]*$') then
                return nil, params
            end

            if not DATA_VALUE[type(value)] then
                return nil, params
            end

            conditions[#conditions + 1] = 'JSON_VALUE(i.data, ?) = ?'
            params[#params + 1] = '$.' .. key
            params[#params + 1] = tostring(math.type(value) == 'float' and math.tointeger(value) or value)
        end
    end

    return conditions, params
end

---@param conditions string[]
---@return string
local function where(conditions)
    return #conditions > 0 and ' WHERE ' .. table.concat(conditions, ' AND ') or ''
end

---@param row table
---@return BankingInvoice
local function toInvoice(row)
    row.data = json.decode(row.data) or {}

    return row
end

---@param id any
---@return BankingInvoice?
function Invoices.Get(id)
    local invoiceId <const> = toId(id)
    local row <const> = invoiceId and MySQL.single.await(SELECT .. ' WHERE i.id = ?', { invoiceId })

    return row and toInvoice(row) or nil
end

---@param filter? BankingInvoiceQuery
---@return BankingInvoice[]
function Invoices.List(filter)
    local query <const> = type(filter) == 'table' and filter or {}
    local conditions <const>, params <const> = filterConditions(query)

    if not conditions then
        return {}
    end

    local before <const> = toId(query.before)

    if before then
        conditions[#conditions + 1] = 'i.id < ?'
        params[#params + 1] = before
    end

    params[#params + 1] = math.max(1, math.min(math.tointeger(query.limit) or DEFAULT_LIMIT, MAX_LIMIT))

    local rows <const> = MySQL.query.await(SELECT .. where(conditions) .. ' ORDER BY i.id DESC LIMIT ?', params) or {}

    for i, row in ipairs(rows) do
        rows[i] = toInvoice(row)
    end

    return rows
end

---@param citizenid string|string[]
---@param issuer? string
---@return table<string, integer>
local function owedBy(citizenid, issuer)
    local unpaid <const> = { citizenid = citizenid, issuer = issuer, status = 'unpaid' }
    local conditions <const>, params <const> = filterConditions(unpaid)
    local owed <const> = {}

    if not conditions then
        return owed
    end

    for _, row in ipairs(MySQL.query.await(OWED .. where(conditions) .. ' GROUP BY i.citizenid', params) or {}) do
        owed[row.citizenid] = row.owed
    end

    return owed
end

---@param filter? BankingInvoiceTotalsQuery
---@return BankingInvoiceTotals
function Invoices.Totals(filter)
    local query <const> = type(filter) == 'table' and filter or {}
    local conditions <const>, params <const> = filterConditions({ citizenid = query.citizenid, issuer = query.issuer })

    if not conditions then
        return { unpaid = 0, unpaidCount = 0, overdue = 0, overdueCount = 0, billed = 0, paid = 0, owed = {} }
    end

    local since <const> = math.tointeger(query.since) or os.time() - TOTALS_WINDOW
    local totals <const> = MySQL.single.await(TOTALS .. where(conditions), { since, since, table.unpack(params) })

    totals.owed = query.citizenid ~= nil and owedBy(query.citizenid, query.issuer) or {}

    return totals
end

---@param input BankingInvoiceInput
---@return BankingInvoiceResult
function Invoices.Create(input)
    if type(input) ~= 'table' then
        return refuse('invalid_invoice')
    end

    local issuer <const> = parseText(input.issuer, 32)
    local summary <const> = (input.summary == nil or input.summary == '') and '' or parseText(input.summary, 255)
    local issuerName = input.issuerName ~= nil and parseText(input.issuerName, 120) or nil
    local dueDays <const> = input.dueDays == nil and config.InvoiceDueDays or math.tointeger(input.dueDays)
    local data <const> = input.data == nil and {} or input.data

    if not issuer or not summary or type(data) ~= 'table' then
        return refuse('invalid_invoice')
    end

    if input.issuerName ~= nil and not issuerName then
        return refuse('invalid_invoice')
    end

    if not dueDays or dueDays < 1 or dueDays > MAX_DUE_DAYS then
        return refuse('invalid_invoice')
    end

    local amount <const> = Transactions.ParseAmount(input.amount)

    if not amount then
        return refuse('invalid_amount')
    end

    local payer <const> = type(input.citizenid) == 'string' and DB.FindPlayer(input.citizenid)
    local payee <const> = Accounts.Resolve(input.payee or ('society_' .. issuer))

    if not payer or not payee then
        return refuse('not_found')
    end

    local issuerCitizenid <const> = input.issuerCitizenid

    if issuerCitizenid ~= nil then
        local writer <const> = type(issuerCitizenid) == 'string' and DB.FindPlayer(issuerCitizenid)

        if not writer then
            return refuse('not_found')
        end

        issuerName = issuerName or writer.name
    end

    local id <const> = MySQL.insert.await(INSERT, {
        issuer,
        payer.citizenid,
        payee.accountId,
        issuerCitizenid,
        issuerName,
        summary,
        amount,
        next(data) and json.encode(data) or '{}',
        dueDays,
    })

    if not id then
        return refuse('invalid_invoice')
    end

    return { ok = true, invoice = Invoices.Get(id) }
end

---@param id integer
---@return BankingRefusal
local function refuseClosed(id)
    return refuse(Invoices.Get(id) and 'settled' or 'not_found')
end

---@param invoice BankingInvoice
---@return BankingInvoicePaidWith? paidWith
---@return BankingFailure? reason
local function payByBank(invoice)
    local account <const> = Accounts.GetPrimaryAccount(invoice.citizenid)

    if not account then
        return nil, 'not_found'
    end

    local number <const> = invoiceNumber(invoice.id)
    local note <const> = statementNote(invoice)
    ---@type BankingFailure
    local failure = 'insufficient_funds'

    local committed <const> = DB.Atomic(function(tx)
        if tx:exec(MARK_PAID, { invoice.id }) == 0 then
            failure = 'settled'
            return false
        end

        local debited <const> = tx:move(account.accountId, -invoice.amount, {
            type = TransactionType.BILL_PAID,
            description = note,
            receipt = number,
            initiated_by = invoice.citizenid,
            counterparty = invoice.payee,
        })

        if not debited then return false end

        local credited <const> = tx:move(invoice.payee, invoice.amount, {
            type = TransactionType.BILL_RECEIVED,
            description = note,
            receipt = number,
            initiated_by = invoice.citizenid,
            counterparty = account.accountId,
        })

        if not credited then
            failure = 'not_found'
            return false
        end

        return true
    end)

    if committed then
        return 'bank'
    end

    if failure == 'insufficient_funds' then
        MySQL.update.await(MARK_DECLINED, { invoice.id })
    end

    return nil, failure
end

---@param invoice BankingInvoice
---@return BankingInvoicePaidWith? paidWith
---@return BankingFailure? reason
local function payByCash(invoice)
    local source <const> = Cobalt.Functions.GetPlayerByCitizenId(invoice.citizenid)?.PlayerData.source

    if not source then
        return nil, 'payer_offline'
    end

    local number <const> = invoiceNumber(invoice.id)

    if not Cash.RemoveCash(source, invoice.amount, ('invoice %s'):format(number)) then
        return nil, 'insufficient_funds'
    end

    ---@type BankingFailure
    local failure = 'not_found'

    local committed <const> = DB.Atomic(function(tx)
        if tx:exec(MARK_PAID, { invoice.id }) == 0 then
            failure = 'settled'
            return false
        end

        return tx:move(invoice.payee, invoice.amount, {
            type = TransactionType.BILL_RECEIVED,
            description = locale('statement.invoice_cash', statementNote(invoice)),
            receipt = number,
            initiated_by = invoice.citizenid,
        }) ~= nil
    end)

    if committed then
        return 'cash'
    end

    Cash.AddCash(source, invoice.amount, ('invoice %s refund'):format(number))

    return nil, failure
end

---@type table<BankingInvoiceMethod, fun(invoice: BankingInvoice): BankingInvoicePaidWith?, BankingFailure?>
local PAYMENT_METHODS <const> = {
    bank = payByBank,
    cash = payByCash,
    cash_or_bank = function(invoice)
        local paidWith <const>, reason <const> = payByCash(invoice)

        if paidWith or reason == 'settled' or reason == 'not_found' then
            return paidWith, reason
        end

        return payByBank(invoice)
    end,
    manual = function(invoice)
        if MySQL.update.await(MARK_PAID, { invoice.id }) == 0 then
            return nil, 'settled'
        end

        return 'manual'
    end,
}

---@param id any
---@param payment? BankingInvoicePayment
---@return BankingInvoiceResult
function Invoices.Pay(id, payment)
    local method <const> = type(payment) == 'table' and payment.method or 'bank'
    local pay <const> = PAYMENT_METHODS[method]

    if not pay then
        return refuse('invalid_invoice')
    end

    local invoice <const> = Invoices.Get(id)

    if not invoice then
        return refuse('not_found')
    end

    if invoice.status == 'paid' or invoice.status == 'void' then
        return refuse('settled')
    end

    local paidWith <const>, reason <const> = pay(invoice)

    if not paidWith then
        return refuse(reason --[[@as BankingFailure]])
    end

    local paid <const> = Invoices.Get(invoice.id) --[[@as BankingInvoice]]

    Log.Invoice(paid, paidWith)
    TriggerEvent('cobalt_banking:invoicePaid', paid, paidWith)

    return { ok = true, invoice = paid }
end

---@param id any
---@return BankingInvoiceResult
function Invoices.Decline(id)
    local invoiceId <const> = toId(id)

    if not invoiceId then
        return refuse('not_found')
    end

    if MySQL.update.await(MARK_DECLINED, { invoiceId }) == 0 then
        return refuseClosed(invoiceId)
    end

    return { ok = true, invoice = Invoices.Get(invoiceId) }
end

---@param id any
---@param reason any
---@return BankingInvoiceResult
function Invoices.Void(id, reason)
    local invoiceId <const> = toId(id)
    local text <const> = parseText(reason, 255)

    if not invoiceId then
        return refuse('not_found')
    end

    if not text then
        return refuse('invalid_invoice')
    end

    if MySQL.update.await(MARK_VOID, { text, invoiceId }) == 0 then
        return refuseClosed(invoiceId)
    end

    return { ok = true, invoice = Invoices.Get(invoiceId) }
end

return Invoices
