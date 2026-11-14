local config <const> = require 'config'
local enums <const> = require 'shared.enums'
local DB <const> = require 'server.database'
local Accounts <const> = require 'server.accounts'

local core <const> = exports.cobalt_core
local Cobalt <const> = core:GetCoreObject()

local INTERVAL_SECONDS <const> = config.PaycheckInterval * 60

---@class PayrollMember
---@field source integer
---@field citizenid string
---@field job ManagementJob

---@class PaycheckDue : PayrollMember
---@field amount integer
---@field accountId AccountId

---@class PayrollJob
---@field label string
---@field members PayrollMember[]

---@class BankingPayroll
local Payroll <const> = {}

local nextPayday = os.time() + INTERVAL_SECONDS

---@param source integer
---@param description string
---@param kind 'success'|'error'
local function notify(source, description, kind)
    core:Notify(source, { description = description, type = kind, duration = 5000 })
end

---@param job ManagementJob
---@return integer
local function paymentOf(job)
    if job.onduty == false then return 0 end

    return job.grade?.payment or 0
end

---@return table<string, PayrollJob>
local function jobsOnline()
    local jobs <const> = {}

    for _, source in ipairs(core:GetPlayers()) do
        local citizenid <const> = Cobalt.Functions.GetPlayer(source)?.PlayerData.citizenid
        local job <const> = citizenid and exports.cobalt_management:GetJob(source)

        if job and job.name ~= 'unemployed' then
            jobs[job.name] = jobs[job.name] or { label = job.label or job.name, members = {} }

            local members <const> = jobs[job.name].members

            members[#members + 1] = { source = source, citizenid = citizenid, job = job }
        end
    end

    return jobs
end

---@param members PayrollMember[]
---@return PaycheckDue[]
local function payableDues(members)
    local dues <const> = {}
    local citizenids <const> = {}

    for i, member in ipairs(members) do citizenids[i] = member.citizenid end

    local accounts <const> = DB.GetFirstAccountsByType(citizenids, enums.AccountType.PERSONAL)

    for _, member in ipairs(members) do
        local amount <const> = paymentOf(member.job)
        local account <const> = amount > 0 and accounts[member.citizenid]

        if account then
            dues[#dues + 1] = {
                source = member.source,
                citizenid = member.citizenid,
                job = member.job,
                amount = amount,
                accountId = account.accountId,
            }
        end
    end

    return dues
end

---@param society BankAccount
---@param label string
---@param dues PaycheckDue[]
---@return boolean paid
local function payFromSociety(society, label, dues)
    local total = 0

    for _, due in ipairs(dues) do
        total += due.amount
    end

    local description <const> = #dues == 1 and locale('statement.payday_one') or locale('statement.payday_many', #dues)

    return DB.Atomic(function(tx)
        local debited <const> = tx:move(society.accountId, -total, {
            type = enums.TransactionType.PAYCHECK,
            description = description,
            initiated_by = 'payroll',
        })

        if not debited then return false end

        for _, due in ipairs(dues) do
            local credited <const> = tx:move(due.accountId, due.amount, {
                type = enums.TransactionType.PAYCHECK,
                description = locale('statement.paycheck', label),
                initiated_by = due.citizenid,
                counterparty = society.accountId,
            })

            if not credited then return false end
        end

        return true
    end)
end

---@param jobName string
---@param payroll PayrollJob
local function payJob(jobName, payroll)
    local society <const> = Accounts.GetSocietyAccount(jobName)

    if not society then return end

    local dues <const> = payableDues(payroll.members)

    if #dues == 0 then return end

    if not payFromSociety(society, payroll.label, dues) then
        for _, due in ipairs(dues) do
            notify(due.source, locale('notify.payday_unpaid'), 'error')
        end

        return
    end

    for _, due in ipairs(dues) do
        notify(due.source, locale('notify.paycheck', due.amount), 'success')
    end
end

local function payday()
    nextPayday = os.time() + INTERVAL_SECONDS

    for jobName, payroll in pairs(jobsOnline()) do
        payJob(jobName, payroll)
    end
end

---@return integer epoch seconds of the next payday
function Payroll.NextPayday()
    return nextPayday
end

SetInterval(payday, INTERVAL_SECONDS * 1000)

return Payroll
