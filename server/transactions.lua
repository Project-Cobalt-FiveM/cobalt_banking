local config <const> = require 'config'
local enums <const> = require 'shared.enums'
local DB <const> = require 'server.database'
local Accounts <const> = require 'server.accounts'
local Log <const> = require 'server.log'

local Cobalt <const> = exports.cobalt_core:GetCoreObject()

local TransactionType <const> = enums.TransactionType

local MAX_AMOUNT <const> = 1000000000
local RECEIPT_ALPHABET <const> = '0123456789ABCDEFGHJKLMNPQRSTUVWXYZ'

---@class BankingTransactions
local Transactions <const> = {}

---@param accountId AccountId
---@param delta integer
---@param entry BankTxEntry
---@param failure string
---@return boolean ok
---@return integer|string balanceOrError
local function applyChange(accountId, delta, entry, failure)
    local balanceAfter <const> = DB.Move(accountId, delta, entry)

    if not balanceAfter then return false, failure end

    return true, balanceAfter
end

local NOTE_LENGTH <const> = 60

---A whole amount above 0 and at most `MAX_AMOUNT`, from a number or a numeric string.
---@param value any
---@return integer?
function Transactions.ParseAmount(value)
    local amount <const> = math.tointeger(tonumber(value))

    return amount and amount > 0 and amount <= MAX_AMOUNT and amount or nil
end

---@param value any
---@return string? note trimmed, nil when empty or longer than `NOTE_LENGTH`
local function parseNote(value)
    if type(value) ~= 'string' then return end

    local text <const> = value:match('^%s*(.-)%s*$')

    if text == '' or #text > NOTE_LENGTH then return end

    return text
end

---@param account string
---@param value number a whole amount above 0
---@param details? BankingDetails
---@return boolean ok
---@return integer|string balanceOrError
function Transactions.Deposit(account, value, details)
    local amount <const> = Transactions.ParseAmount(value)

    if not amount then return false, locale('error.invalid_amount') end

    local target <const> = Accounts.Resolve(account)

    if not target then return false, locale('error.account_not_found') end

    return applyChange(target.accountId, amount, {
        type = TransactionType.DEPOSIT,
        description = details?.note or locale('statement.cash_deposit'),
        initiated_by = details?.initiator,
    }, locale('error.deposit_failed'))
end

---@param account string
---@param value number a whole amount above 0
---@param details? BankingDetails
---@return boolean ok
---@return integer|string balanceOrError
function Transactions.Withdraw(account, value, details)
    local amount <const> = Transactions.ParseAmount(value)

    if not amount then return false, locale('error.invalid_amount') end

    local target <const> = Accounts.Resolve(account)

    if not target then return false, locale('error.account_not_found') end

    return applyChange(target.accountId, -amount, {
        type = TransactionType.WITHDRAWAL,
        description = details?.note or locale('statement.cash_withdrawal'),
        initiated_by = details?.initiator,
    }, locale('error.insufficient_funds'))
end

local BILL_TYPES <const> = { out = TransactionType.BILL_PAID, ['in'] = TransactionType.BILL_RECEIVED }

---@param from string
---@param to string
---@param value number a whole amount above 0
---@param details? BankingTransferDetails
---@return boolean ok
---@return integer|string fromBalanceOrError
function Transactions.Transfer(from, to, value, details)
    local amount <const> = Transactions.ParseAmount(value)

    if not amount then return false, locale('error.invalid_amount') end

    local payer <const> = Accounts.Resolve(from)
    local payee <const> = Accounts.Resolve(to)

    if not payer or not payee then return false, locale('error.account_not_found') end
    if payer.accountId == payee.accountId then return false, locale('error.same_account') end

    local fromBalance <const> = DB.Transfer(
        payer.accountId,
        payee.accountId,
        amount,
        details?.note or locale('statement.transfer'),
        details?.initiator,
        details?.bill and BILL_TYPES or nil
    )

    if not fromBalance then return false, locale('error.insufficient_funds') end

    return true, fromBalance
end

---@return string
function Transactions.NewReceipt()
    local code <const> = {}

    for i = 1, 4 do
        local index <const> = math.random(1, #RECEIPT_ALPHABET)
        code[i] = RECEIPT_ALPHABET:sub(index, index)
    end

    return ('FL-%s-%04d'):format(table.concat(code), math.random(0, 9999))
end

---@param reason BankingFailure
---@return BankingRefusal
local function refuse(reason)
    return { ok = false, reason = reason }
end

---@param citizenid string
---@param request BankingTransferRequest
---@return BankingTransferResult
function Transactions.Send(citizenid, request)
    if type(request) ~= 'table' then
        return refuse('invalid_amount')
    end

    local amount <const> = Transactions.ParseAmount(request.amount)

    if not amount then
        return refuse('invalid_amount')
    end

    local from <const> = type(request.from) == 'string' and DB.GetAccount(request.from)

    if not from then
        return refuse('not_found')
    end

    if not Accounts.RoleAllows(Accounts.RoleOf(from, citizenid), enums.MemberRole.MEMBER) then
        return refuse('no_permission')
    end

    local to <const> = type(request.to) == 'string' and Accounts.FindHolder(request.to)

    if not to then
        return refuse('not_found')
    end

    if to.accountId == from.accountId then
        return refuse('same_account')
    end

    local fee <const> = math.floor(amount * config.TransferFeePercent / 100)

    if from.balance < amount + fee then
        return refuse('insufficient_funds')
    end

    local note <const> = parseNote(request.note) or locale('statement.transfer')
    local receipt <const> = Transactions.NewReceipt()
    local balance, transactionId

    local committed <const> = DB.Atomic(function(tx)
        balance, transactionId = tx:move(from.accountId, -amount, {
            type = TransactionType.TRANSFER_OUT,
            description = note,
            reference_id = to.accountId,
            receipt = receipt,
            initiated_by = citizenid,
            counterparty = to.accountId,
        })

        if not balance then return false end

        if fee > 0 then
            balance = tx:move(from.accountId, -fee, {
                type = TransactionType.FEE,
                description = locale('statement.transfer_fee'),
                receipt = receipt,
                initiated_by = citizenid,
            })

            if not balance then return false end
        end

        return tx:move(to.accountId, amount, {
            type = TransactionType.TRANSFER_IN,
            description = note,
            reference_id = from.accountId,
            receipt = receipt,
            initiated_by = citizenid,
            counterparty = from.accountId,
        }) ~= nil
    end)

    if not committed then
        return refuse('insufficient_funds')
    end

    local source <const> = Cobalt.Functions.GetPlayerByCitizenId(citizenid, true)?.PlayerData.source

    if source then Log.Transaction(source, 'transfer_out', amount, from.accountId) end

    return {
        ok = true,
        balance = balance,
        fee = fee,
        receipt = receipt,
        transactionId = transactionId,
        toAccountId = to.accountId,
    }
end

return Transactions
