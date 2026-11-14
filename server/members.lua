local config <const> = require 'config'
local enums <const> = require 'shared.enums'
local DB <const> = require 'server.database'
local Accounts <const> = require 'server.accounts'

local MemberRole <const> = enums.MemberRole

---@class BankingMembers
local Members <const> = {}

---@param reason BankingFailure
---@return BankingRefusal
local function refuse(reason)
    return { ok = false, reason = reason }
end

---@param employee ManagementEmployee
---@param orgName string
---@return BankingMemberRole
local function employeeRole(employee, orgName)
    if employee.isBoss then
        return MemberRole.OWNER
    end

    local source <const> = employee.source

    if source and exports.cobalt_management:HasPermission(source, orgName, 'society') then
        return MemberRole.MEMBER
    end

    return MemberRole.VIEWER
end

---@param orgName string
---@return BankingMember[]
local function societyMembers(orgName)
    if GetResourceState('cobalt_management') ~= 'started' then
        return {}
    end

    local members <const> = {}

    for i, employee in ipairs(exports.cobalt_management:GetEmployees(orgName)) do
        members[i] = {
            citizenid = employee.citizenid,
            name = employee.name,
            role = employeeRole(employee, orgName),
            rank = employee.rank,
        }
    end

    return members
end

---@param accountId AccountId
---@return BankingMember[]
local function accountMembers(accountId)
    local members <const> = {}

    for i, row in ipairs(DB.GetMembers(accountId)) do
        members[i] = { citizenid = row.citizenid, name = row.name, role = row.role }
    end

    return members
end

---@param citizenid string
---@param accountId any
---@return BankingMemberList|BankingRefusal
function Members.List(citizenid, accountId)
    local account <const> = type(accountId) == 'string' and DB.GetAccount(accountId)

    if not account then
        return refuse('not_found')
    end

    local role <const> = Accounts.RoleOf(account, citizenid)

    if not role then
        return refuse('no_permission')
    end

    local isSociety <const> = account.type == enums.AccountType.SOCIETY

    return {
        ok = true,
        accountId = account.accountId,
        type = account.type,
        role = role,
        canManage = not isSociety and Accounts.RoleAllows(role, MemberRole.ADMIN),
        maxMembers = config.MaxSharedMembers + 1,
        members = isSociety and societyMembers(account.label) or accountMembers(account.accountId),
    }
end

---@param citizenid string
---@param accountId any
---@return BankAccount? account
---@return BankingFailure? reason
local function manageable(citizenid, accountId)
    local account <const> = type(accountId) == 'string' and DB.GetAccount(accountId)

    if not account then
        return nil, 'not_found'
    end

    if account.type ~= enums.AccountType.SHARED then
        return nil, 'no_permission'
    end

    if not Accounts.RoleAllows(Accounts.RoleOf(account, citizenid), MemberRole.ADMIN) then
        return nil, 'no_permission'
    end

    return account
end

---@param citizenid string
---@param accountId any
---@param targetCitizenid any
---@return { ok: true, member: BankingMember }|BankingRefusal
function Members.Invite(citizenid, accountId, targetCitizenid)
    local account <const>, reason <const> = manageable(citizenid, accountId)

    if not account then
        return refuse(reason --[[@as BankingFailure]])
    end

    local target <const> = type(targetCitizenid) == 'string' and DB.FindPlayer(targetCitizenid:upper())

    if not target then
        return refuse('not_found')
    end

    if DB.GetMemberRole(account.accountId, target.citizenid) then
        return refuse('already_member')
    end

    if not DB.AddMemberUnderLimit(account.accountId, target.citizenid, MemberRole.MEMBER, config.MaxSharedMembers) then
        return refuse(DB.GetMemberRole(account.accountId, target.citizenid) and 'already_member' or 'member_limit')
    end

    return { ok = true, member = { citizenid = target.citizenid, name = target.name, role = MemberRole.MEMBER } }
end

---@param citizenid string
---@param accountId any
---@param targetCitizenid any
---@return { ok: true }|BankingRefusal
function Members.Revoke(citizenid, accountId, targetCitizenid)
    local account <const>, reason <const> = manageable(citizenid, accountId)

    if not account then
        return refuse(reason --[[@as BankingFailure]])
    end

    if type(targetCitizenid) ~= 'string' then
        return refuse('not_found')
    end

    if targetCitizenid == account.ownerCid then
        return refuse('no_permission')
    end

    if not DB.GetMemberRole(account.accountId, targetCitizenid) then
        return refuse('not_found')
    end

    DB.RemoveMember(account.accountId, targetCitizenid)

    return { ok = true }
end

return Members
