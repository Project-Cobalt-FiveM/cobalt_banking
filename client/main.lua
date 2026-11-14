local config <const> = require 'config'
local Atm <const> = require 'client.atm'
require 'client.cashpoints'

local CALLBACKS <const> = {
    'overview',
    'account',
    'findPlayer',
    'lookup',
    'deposit',
    'withdraw',
    'transfer',
    'createAccount',
}

local isBankOpen = false

---@type table<string, string>?
local uiStrings

---@return table<string, string>
local function uiLocales()
    if uiStrings then return uiStrings end

    local strings <const> = {}

    for key, value in pairs(lib.getLocales()) do
        if key:sub(1, 3) == 'ui.' then
            strings[key] = value
        end
    end

    uiStrings = strings

    return strings
end

for _, name in ipairs(CALLBACKS) do
    RegisterNUICallback(name, function(data, cb)
        cb(lib.callback.await('cobalt_banking:' .. name, false, data) or false)
    end)
end

---@param atm boolean
local function showBanking(atm)
    isBankOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', atm = atm, locales = uiLocales() })
end

---@param fromUi? boolean the page asked to close and is already playing its exit
local function closeBanking(fromUi)
    if not isBankOpen then return end

    isBankOpen = false
    SetNuiFocus(false, false)

    if not fromUi then SendNUIMessage({ action = 'close' }) end

    TriggerServerEvent('cobalt_banking:server:close')
    Atm.Leave()
end

---@param atm? boolean
local function openBanking(atm)
    if isBankOpen then return end

    local atAtm <const> = atm == true

    if not lib.callback.await('cobalt_banking:open', false, atAtm) then return end

    showBanking(atAtm)
end

---@param entity integer
local function openAtm(entity)
    if isBankOpen or not Atm.Insert(entity) then return end

    if not lib.callback.await('cobalt_banking:open', false, true) then
        Atm.Leave()
        return
    end

    showBanking(true)
end

---@return boolean
local function canInteract()
    return not isBankOpen and not Atm.Busy()
end

RegisterNUICallback('close', function(_, cb)
    closeBanking(true)
    cb(true)
end)

---@param value any
local function closeWhenRestrained(_, _, value)
    if value then closeBanking() end
end

AddStateBagChangeHandler('isDead', ('player:%s'):format(cache.serverId), closeWhenRestrained)
AddStateBagChangeHandler('cuffed', ('player:%s'):format(cache.serverId), closeWhenRestrained)

RegisterNetEvent('cobalt_core:Client:OnPlayerUnload', function() closeBanking() end)

local ATM_OPTION <const> = 'cobalt_banking:atm'

---@param index integer
---@return string
local function bankZoneName(index)
    return 'cobalt_banking:bank_' .. index
end

exports.ox_target:addModel(config.ATMModels, {
    {
        name = ATM_OPTION,
        label = locale('target.use_atm'),
        icon = 'fas fa-money-check-dollar',
        distance = 3.0,
        canInteract = canInteract,
        onSelect = function(data) openAtm(data.entity) end,
    },
})

for i, bank in ipairs(config.Banks) do
    local zone <const> = bankZoneName(i)

    exports.ox_target:addSphereZone({
        name = zone,
        coords = bank.coords,
        radius = 3.0,
        options = {
            {
                name = zone .. ':open',
                label = locale('target.access_banking'),
                icon = 'fas fa-building-columns',
                distance = 3.0,
                canInteract = canInteract,
                onSelect = function() openBanking(false) end,
            },
        },
    })
end

---@param bank { id: string, coords: vector3 }
local function createBankBlip(bank)
    local blip <const> = AddBlipForCoord(bank.coords.x, bank.coords.y, bank.coords.z)

    SetBlipSprite(blip, config.Blip.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, config.Blip.scale)
    SetBlipColour(blip, config.Blip.colour)
    SetBlipAsShortRange(blip, true)
    SetBlipCategory(blip, config.Blip.category)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(locale(('branch.%s'):format(bank.id)))
    EndTextCommandSetBlipName(blip)
end

AddTextEntry(('BLIP_CAT_%d'):format(config.Blip.category), locale('blip.category'))

for _, bank in ipairs(config.Banks) do
    createBankBlip(bank)
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    exports.ox_target:removeModel(config.ATMModels, ATM_OPTION)

    for i in ipairs(config.Banks) do
        exports.ox_target:removeZone(bankZoneName(i), true)
    end

    if isBankOpen then SetNuiFocus(false, false) end
end)
