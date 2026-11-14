local Cobalt <const> = exports.cobalt_core:GetCoreObject()

---@class BankingCash
local Cash <const> = {}

---@param source integer
---@return integer
function Cash.GetCashAmount(source)
    local player <const> = Cobalt.Functions.GetPlayer(source)

    if not player then return 0 end

    return player.Functions.GetMoney('cash')
end

---@param source integer
---@param amount integer
---@param reason? string
---@return boolean
function Cash.AddCash(source, amount, reason)
    if amount <= 0 then return false end

    local player <const> = Cobalt.Functions.GetPlayer(source)

    if not player then return false end

    return player.Functions.AddMoney('cash', amount, reason or 'bank')
end

---@param source integer
---@param amount integer
---@param reason? string
---@return boolean
function Cash.RemoveCash(source, amount, reason)
    if amount <= 0 then return false end

    local player <const> = Cobalt.Functions.GetPlayer(source)

    if not player then return false end

    return player.Functions.RemoveMoney('cash', amount, reason or 'bank')
end

---@param source integer
---@return string?
function Cash.GetCitizenId(source)
    return Cobalt.Functions.GetPlayer(source)?.PlayerData.citizenid
end

return Cash
