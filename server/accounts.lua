local config <const> = require 'config'
local startingBank <const> = require '@cobalt_core.config.shared'.money.starting.bank or 0
local enums <const> = require 'shared.enums'
local DB <const> = require 'server.database'

local Cobalt <const> = exports.cobalt_core:GetCoreObject()

local ROLE_RANK <const> = { owner = 4, admin = 3, member = 2, viewer = 1 }

---@class BankingAccounts
local Accounts <const> = {}

---@return AccountId
function Accounts.GenerateAccountNumber()
    local number <const> = ('CB %04d %04d'):format(math.random(0, 9999), math.random(0, 9999))

    if DB.GetAccount(number) then return Accounts.GenerateAccountNumber() end

    return number
end

---Reads `CB12345678`, `cb 1234 5678` and other spacings as the stored `CB 1234 5678`.
---@param value string
---@return string
local function canonicalNumber(value)
    local first <const>, second <const> = value:upper():match('^%s*CB%s*(%d%d%d%d)%s*(%d%d%d%d)%s*$')

    return first and ('CB %s %s'):format(first, second) or value
end

---@param citizenid string
---@param accountType? string
---@param label? string
---@return AccountId? accountId
---@return string? error
function Accounts.Create(citizenid, accountType, label)
    accountType = accountType or enums.AccountType.PERSONAL

    local typeDef <const> = config.AccountTypes[accountType]

    if not typeDef then return nil, locale('error.invalid_account_type') end

    local accountId <const> = Accounts.GenerateAccountNumber()
    local committed <const> = DB.Atomic(function(tx)
        if not DB.HasAccountSlot(tx, citizenid, accountType, typeDef.maxPerPlayer) then return false end

        DB.InsertAccount(tx, {
            accountId = accountId,
            type = accountType,
            label = label,
            balance = accountType == enums.AccountType.PERSONAL and startingBank or 0,
            ownerCid = citizenid,
        })
        DB.InsertMember(tx, accountId, citizenid, enums.MemberRole.OWNER)

        return true
    end)

    if not committed then return nil, locale('error.account_limit') end

    return accountId
end

---@param account any an account id, or a citizenid for that character's personal account
---@return BankAccount?
function Accounts.Resolve(account)
    if type(account) ~= 'string' or account == '' then return end

    return DB.GetAccount(canonicalNumber(account)) or Accounts.GetPrimaryAccount(account)
end

---@param orgName string
---@return AccountId
local function societyAccountId(orgName)
    return 'society_' .. orgName
end

---@param source? integer
---@return BankAccount[]
local function visibleSocietyAccounts(source)
    if not source or GetResourceState('cobalt_management') ~= 'started' then return {} end

    local management <const> = exports.cobalt_management
    local visible <const> = {}

    for _, org in ipairs({ management:GetJob(source), management:GetGang(source) }) do
        local account <const> = org?.name and Accounts.GetSocietyAccount(org.name)

        if account then visible[#visible + 1] = account end
    end

    return visible
end

---@return string[]
local function societyOrgNames()
    local names <const> = {}

    for _, definitions in ipairs({ exports.cobalt_core:GetShared('Jobs'), exports.cobalt_core:GetShared('Gangs') }) do
        for name, definition in pairs(definitions) do
            if definition.society then names[#names + 1] = name end
        end
    end

    return names
end

function Accounts.EnsureSocietyAccounts()
    local accounts <const> = {}

    for i, orgName in ipairs(societyOrgNames()) do
        accounts[i] = { societyAccountId(orgName), orgName }
    end

    DB.EnsureSocietyAccounts(accounts)
end

---@param orgName string
---@return BankAccount?
function Accounts.GetSocietyAccount(orgName)
    if type(orgName) ~= 'string' or orgName == '' then return end

    return DB.GetAccount(societyAccountId(orgName))
end

---@param citizenid string
---@param source? integer
---@return BankAccount[]
function Accounts.GetPlayerAccounts(citizenid, source)
    local accounts <const> = DB.GetPlayerAccounts(citizenid)
    local seen <const> = {}

    for _, account in ipairs(accounts) do
        seen[account.accountId] = true
    end

    for _, account in ipairs(visibleSocietyAccounts(source)) do
        if not seen[account.accountId] then
            accounts[#accounts + 1] = account
            seen[account.accountId] = true
        end
    end

    return accounts
end

---@param citizenid string
---@return BankAccount?
function Accounts.GetPrimaryAccount(citizenid)
    return DB.GetAccountsByType(citizenid, enums.AccountType.PERSONAL)[1]
end

---The player's job or gang whose name is `orgName`, if they hold it.
---@param source integer
---@param orgName string
---@return { name: string, isboss: boolean }?
local function membershipIn(source, orgName)
    local management <const> = exports.cobalt_management
    local job <const> = management:GetJob(source)

    if job?.name == orgName then return job end

    local gang <const> = management:GetGang(source)

    if gang?.name == orgName then return gang end
end

---@param account BankAccount
---@param citizenid string
---@return BankingMemberRole?
local function societyRole(account, citizenid)
    if account.type ~= enums.AccountType.SOCIETY or not account.label then return end
    if GetResourceState('cobalt_management') ~= 'started' then return end

    local source <const> = Cobalt.Functions.GetPlayerByCitizenId(citizenid)?.PlayerData.source

    if not source then return end

    local orgName <const> = account.label --[[@as string]]
    local membership <const> = membershipIn(source, orgName)

    if membership?.isboss then
        return enums.MemberRole.OWNER
    end

    if exports.cobalt_management:HasPermission(source, orgName, 'society') then
        return enums.MemberRole.MEMBER
    end

    if membership then
        return enums.MemberRole.VIEWER
    end
end

---@param account BankAccount
---@param citizenid string
---@return BankingMemberRole?
function Accounts.RoleOf(account, citizenid)
    if account.ownerCid == citizenid then
        return enums.MemberRole.OWNER
    end

    return DB.GetMemberRole(account.accountId, citizenid) or societyRole(account, citizenid)
end

---@param role? string
---@param requiredRole? string
---@return boolean
function Accounts.RoleAllows(role, requiredRole)
    if not role then return false end

    return not requiredRole or (ROLE_RANK[role] or 0) >= (ROLE_RANK[requiredRole] or 0)
end

---@param accountId AccountId
---@param citizenid string
---@param requiredRole? string
---@return boolean
function Accounts.HasAccess(accountId, citizenid, requiredRole)
    local account <const> = DB.GetAccount(accountId)

    return account ~= nil and Accounts.RoleAllows(Accounts.RoleOf(account, citizenid), requiredRole)
end

---@param orgName string
---@return string
function Accounts.SocietyLabel(orgName)
    local org <const> = exports.cobalt_core:GetShared('Jobs')[orgName] or exports.cobalt_core:GetShared('Gangs')[orgName]

    return org?.label or orgName
end

---@param query string account number or citizen ID
---@return { accountId: AccountId, label: string?, type: string, frozen: 0|1, holder: string? }?
function Accounts.FindHolder(query)
    local holder <const> = DB.GetAccountHolder(canonicalNumber(query))

    if holder then
        return holder
    end

    local player <const> = DB.FindPlayer(query)
    local primary <const> = player and Accounts.GetPrimaryAccount(player.citizenid)

    return primary and DB.GetAccountHolder(primary.accountId)
end

---@param account BankAccount members loaded by DB.GetPlayerAccounts
---@param citizenid string
---@return BankingMemberRole?
local function loadedRole(account, citizenid)
    if account.ownerCid == citizenid then
        return enums.MemberRole.OWNER
    end

    for _, member in ipairs(account.members or {}) do
        if member.cid == citizenid then
            return member.role --[[@as BankingMemberRole]]
        end
    end

    return societyRole(account, citizenid)
end

---@param citizenid string
---@return BankingAccessibleAccount[]
function Accounts.ListFor(citizenid)
    local source <const> = Cobalt.Functions.GetPlayerByCitizenId(citizenid)?.PlayerData.source
    local primaryId <const> = Accounts.GetPrimaryAccount(citizenid)?.accountId
    local list <const> = {}

    for _, account in ipairs(Accounts.GetPlayerAccounts(citizenid, source)) do
        local role <const> = loadedRole(account, citizenid)

        if role then
            local isSociety <const> = account.type == enums.AccountType.SOCIETY

            list[#list + 1] = {
                accountId = account.accountId,
                type = account.type,
                name = isSociety and Accounts.SocietyLabel(account.label or '') or account.label or account.accountId,
                balance = account.balance,
                frozen = account.frozen == 1,
                primary = account.accountId == primaryId,
                role = role,
            }
        end
    end

    return list
end

---@param citizenid string
---@return BankAccount? account
---@return boolean isNew
function Accounts.EnsurePlayerAccount(citizenid)
    local primary <const> = Accounts.GetPrimaryAccount(citizenid)

    if primary then return primary, false end

    local accountId <const> = Accounts.Create(citizenid, enums.AccountType.PERSONAL, locale('account.personal'))

    return Accounts.GetPrimaryAccount(citizenid), accountId ~= nil
end

return Accounts
