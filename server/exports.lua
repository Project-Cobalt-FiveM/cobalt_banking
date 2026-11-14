local config <const> = require 'config'
local Accounts <const> = require 'server.accounts'
local Admin <const> = require 'server.admin'
local Transactions <const> = require 'server.transactions'
local Payroll <const> = require 'server.payroll'
local Statements <const> = require 'server.statements'
local Members <const> = require 'server.members'
local Invoices <const> = require 'server.invoices'

exports('GetAccount', Accounts.Resolve)
exports('GetBalance', function(account)
    return Accounts.Resolve(account)?.balance or 0
end)
exports('Deposit', Transactions.Deposit)
exports('Withdraw', Transactions.Withdraw)
exports('Transfer', Transactions.Transfer)
exports('AdjustBalance', Admin.AdjustBalance)
exports('GetNextPayday', function()
    return Payroll.NextPayday(), config.PaycheckInterval
end)

exports('GetAccessibleAccounts', Accounts.ListFor)
exports('GetStatement', Statements.Page)
exports('GetStatementEntry', Statements.Entry)
exports('FindRecipient', Statements.FindRecipient)
exports('GetRecentRecipients', Statements.RecentRecipients)
exports('SendTransfer', Transactions.Send)
exports('GetAccountMembers', Members.List)
exports('InviteMember', Members.Invite)
exports('RevokeMember', Members.Revoke)

exports('CreateInvoice', Invoices.Create)
exports('GetInvoice', Invoices.Get)
exports('GetInvoices', Invoices.List)
exports('GetInvoiceTotals', Invoices.Totals)
exports('PayInvoice', Invoices.Pay)
exports('DeclineInvoice', Invoices.Decline)
exports('VoidInvoice', Invoices.Void)
