local DB <const> = require 'server.database'
local Accounts <const> = require 'server.accounts'
local Log <const> = require 'server.log'

local Cobalt <const> = exports.cobalt_core:GetCoreObject()

---@class BankingAdmin
local Admin <const> = {}

---@param amount integer
---@return string
local function signed(amount)
    return (amount >= 0 and '+' or '') .. tostring(amount)
end

---Credits or debits an account without letting its balance go below zero.
---@param account string
---@param amount number a whole amount; negative debits
---@param details? BankingDetails
---@return boolean ok
---@return integer|string balanceOrError
function Admin.AdjustBalance(account, amount, details)
    local delta <const> = math.tointeger(tonumber(amount))

    if not delta then return false, locale('error.invalid_delta') end

    local target <const> = Accounts.Resolve(account)

    if not target then return false, locale('error.account_not_found') end
    if delta == 0 then return true, target.balance end

    local initiator <const> = details?.initiator or 'system'
    local reason <const> = details?.note or locale('statement.admin_adjustment')
    local newBalance <const> = DB.Move(target.accountId, delta, {
        type = delta > 0 and 'admin_credit' or 'admin_debit',
        description = reason,
        initiated_by = initiator,
    })

    if not newBalance then return false, locale('error.insufficient_funds') end

    Log.AdminAction(initiator, 'Adjust Balance', target.accountId,
        ('%s (reason: %s), new balance: %d'):format(signed(delta), reason, newBalance))

    return true, newBalance
end

lib.addCommand('bankadjust', {
    help = locale('command.bankadjust.help'),
    params = {
        { name = 'accountId', type = 'string', help = locale('command.bankadjust.account') },
        { name = 'amount', type = 'number', help = locale('command.bankadjust.amount') },
        { name = 'reason', type = 'longString', help = locale('command.bankadjust.reason'), optional = true },
    },
    restricted = 'group.admin',
}, function(source, args)
    local adminCid <const> = Cobalt.Functions.GetPlayer(source)?.PlayerData.citizenid or 'console'
    local reason <const> = args.reason or locale('statement.admin_adjustment')
    local ok <const>, result <const> = Admin.AdjustBalance(args.accountId, args.amount, {
        note = reason,
        initiator = adminCid,
    })

    if not ok then
        exports.cobalt_core:Notify(source, {
            description = locale('notify.adjust_failed', result),
            type = 'error',
        })
        return
    end

    exports.cobalt_core:Notify(source, {
        description = locale('notify.adjusted', args.accountId, signed(math.tointeger(args.amount)), result),
        type = 'success',
    })
end)

return Admin
