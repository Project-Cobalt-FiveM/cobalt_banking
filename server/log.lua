local config <const> = require 'config'

---@class BankingLog
local Log <const> = {}

local TRANSACTIONS <const> = {
    deposit = { flag = 'deposits', message = 'Deposited $%d' },
    withdrawal = { flag = 'withdrawals', message = 'Withdrew $%d' },
    transfer_out = { flag = 'transfers', message = 'Transferred $%d' },
}

---@param source integer
---@param txType 'deposit'|'withdrawal'|'transfer_out'
---@param amount integer
---@param accountId AccountId
function Log.Transaction(source, txType, amount, accountId)
    local transaction <const> = TRANSACTIONS[txType]
    if not config.Logs[transaction.flag] then return end

    local level <const> = amount >= config.Logs.suspiciousThreshold and 'security' or 'info'

    exports.cobalt_core:LogPlayer(source, 'banking.' .. txType, transaction.message:format(amount), {
        accountId = accountId,
        amount = amount,
    }, level)
end

---@param invoice BankingInvoice
---@param paidWith BankingInvoicePaidWith
function Log.Invoice(invoice, paidWith)
    if not config.Logs.invoices then return end

    local level <const> = invoice.amount >= config.Logs.suspiciousThreshold and 'security' or 'info'
    local message <const> = ('Invoice %d paid by %s, $%d'):format(invoice.id, paidWith, invoice.amount)

    exports.cobalt_core:Log('banking.invoice', message, {
        invoiceId = invoice.id,
        issuer = invoice.issuer,
        citizenid = invoice.citizenid,
        payee = invoice.payee,
        amount = invoice.amount,
        paidWith = paidWith,
    }, level)
end

---@param adminCitizenid string
---@param action string
---@param accountId AccountId
---@param details? string
function Log.AdminAction(adminCitizenid, action, accountId, details)
    if not config.Logs.adminActions then return end

    exports.cobalt_core:Log('banking.admin', action, {
        admin = adminCitizenid,
        accountId = accountId,
        details = details,
    }, 'security')
end

return Log
