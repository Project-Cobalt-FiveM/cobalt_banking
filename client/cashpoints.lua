local config <const> = require 'config'

local ATM_SEARCH_RADIUS <const> = 250.0

---@class BankingCashPoint
---@field coords vector3
---@field label string
---@field atm boolean

---@param origin vector3
---@return BankingCashPoint?
local function nearestAtm(origin)
    local best, bestDistance

    for _, model in ipairs(config.ATMModels) do
        local entity <const> = GetClosestObjectOfType(origin.x, origin.y, origin.z, ATM_SEARCH_RADIUS, joaat(model), false, false, false)

        if entity ~= 0 then
            local coords <const> = GetEntityCoords(entity)
            local distance <const> = #(origin - coords)

            if not bestDistance or distance < bestDistance then
                best, bestDistance = coords, distance
            end
        end
    end

    return best and { coords = best, label = locale('cashpoint.atm'), atm = true }
end

---@param origin vector3
---@return BankingCashPoint?
local function nearestBank(origin)
    local best, bestDistance

    for _, bank in ipairs(config.Banks) do
        local distance <const> = #(origin - bank.coords)

        if not bestDistance or distance < bestDistance then
            best, bestDistance = bank, distance
        end
    end

    return best and { coords = best.coords, label = locale(('branch.%s'):format(best.id)), atm = false }
end

---@param origin vector3
---@return BankingCashPoint?
local function nearestCashPoint(origin)
    local atm <const> = nearestAtm(origin)
    local bank <const> = nearestBank(origin)

    if not atm or not bank then
        return atm or bank
    end

    return #(origin - atm.coords) <= #(origin - bank.coords) and atm or bank
end

exports('FindNearestCashPoint', function()
    local point <const> = nearestCashPoint(GetEntityCoords(cache.ped))

    if not point then return end

    return { x = point.coords.x, y = point.coords.y, z = point.coords.z, label = point.label, atm = point.atm }
end)
