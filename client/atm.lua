local config <const> = require 'config'

local CARD_MODEL <const> = `prop_cs_credit_card`
local HAND_BONE <const> = 28422
local WALK_TIMEOUT <const> = 3000
local ARRIVE_DISTANCE <const> = 0.15
local LEAVE_DISTANCE <const> = 0.8
local INSERT_MIN <const> = 2000
local INSERT_MAX <const> = 3000
local CARD_IN_AT <const> = 0.55
local CARD_OUT_AT <const> = 0.35
local PROGRESS_START_TIMEOUT <const> = 1000

---@class AtmAnims
---@field enter string
---@field base string
---@field exit string

---@class AtmVisit
---@field anims AtmAnims
---@field coords vector3
---@field heading number
---@field card? integer

---@class BankingAtm
local Atm <const> = {}

---@type AtmVisit?
local visit
local approaching = false

---@param ped integer
---@return AtmAnims
local function animsFor(ped)
    local set <const> = IsPedMale(ped) and 'male' or 'female'

    return {
        enter = ('amb@prop_human_atm@%s@enter'):format(set),
        base = ('amb@prop_human_atm@%s@base'):format(set),
        exit = ('amb@prop_human_atm@%s@exit'):format(set),
    }
end

---@param anims AtmAnims
local function loadAssets(anims)
    lib.requestAnimDict(anims.enter)
    lib.requestAnimDict(anims.base)
    lib.requestAnimDict(anims.exit)
    lib.requestModel(CARD_MODEL)
end

---@param anims AtmAnims
local function releaseAssets(anims)
    RemoveAnimDict(anims.enter)
    RemoveAnimDict(anims.base)
    RemoveAnimDict(anims.exit)
    SetModelAsNoLongerNeeded(CARD_MODEL)
end

---@param current AtmVisit
local function showCard(current)
    if current.card then return end

    local ped <const> = cache.ped
    local coords <const> = GetEntityCoords(ped)
    local card <const> = CreateObject(CARD_MODEL, coords.x, coords.y, coords.z, false, false, false)

    SetEntityCollision(card, false, false)
    AttachEntityToEntity(
        card, ped, GetPedBoneIndex(ped, HAND_BONE),
        0.1, 0.02, -0.03, -90.0, 0.0, 0.0,
        true, true, false, false, 2, true
    )
    current.card = card
end

---@param current AtmVisit
local function hideCard(current)
    if not current.card then return end

    DeleteEntity(current.card)
    current.card = nil
end

---@param current AtmVisit
---@param dict string
---@param clip string
---@param flag integer
local function play(current, dict, clip, flag)
    local coords <const> = current.coords

    TaskPlayAnimAdvanced(
        cache.ped, dict, clip,
        coords.x, coords.y, coords.z, 0.0, 0.0, current.heading,
        4.0, -4.0, -1, flag, 0.0, 2, 0
    )
end

---@param dict string
---@param clip string
---@return integer milliseconds
local function clipLength(dict, clip)
    return math.floor(GetAnimDuration(dict, clip) * 1000)
end

---@param coords vector3
---@param heading number
local function walkTo(coords, heading)
    local ped <const> = cache.ped

    TaskGoStraightToCoord(ped, coords.x, coords.y, coords.z, 1.0, WALK_TIMEOUT, heading, 0.05)

    local deadline <const> = GetGameTimer() + WALK_TIMEOUT

    while GetGameTimer() < deadline and #(GetEntityCoords(ped).xy - coords.xy) > ARRIVE_DISTANCE do
        Wait(0)
    end

    SetEntityHeading(ped, heading)
end

---@param current AtmVisit
---@return boolean
local function leftTheMachine(current)
    if GetDisabledControlNormal(0, 30) ~= 0.0 or GetDisabledControlNormal(0, 31) ~= 0.0 then return true end

    return #(GetEntityCoords(cache.ped) - current.coords) > LEAVE_DISTANCE
end

---@param current AtmVisit
local function cancelWhenLeft(current)
    CreateThread(function()
        local progress <const> = exports.cobalt_core
        local deadline <const> = GetGameTimer() + PROGRESS_START_TIMEOUT

        while visit == current and not progress:progressActive() and GetGameTimer() < deadline do
            Wait(0)
        end

        while visit == current and progress:progressActive() do
            if leftTheMachine(current) then
                progress:cancelProgress()
                return
            end

            Wait(0)
        end
    end)
end

---@return boolean
function Atm.Busy()
    return visit ~= nil or approaching
end

---@param entity integer the ATM prop
---@return boolean inserted
function Atm.Insert(entity)
    if Atm.Busy() or not DoesEntityExist(entity) then return false end

    local ped <const> = cache.ped
    local heading <const> = GetEntityHeading(entity)
    local offset <const> = config.ATMStandOffset

    approaching = true
    walkTo(GetOffsetFromEntityInWorldCoords(entity, offset.x, offset.y, offset.z), heading)
    approaching = false

    local current <const> = { anims = animsFor(ped), coords = GetEntityCoords(ped), heading = heading }

    visit = current
    loadAssets(current.anims)
    showCard(current)
    play(current, current.anims.enter, 'enter', 2)

    local duration <const> = math.max(INSERT_MIN, math.min(INSERT_MAX, clipLength(current.anims.enter, 'enter')))

    SetTimeout(math.floor(duration * CARD_IN_AT), function() hideCard(current) end)
    cancelWhenLeft(current)

    local inserted <const> = exports.cobalt_core:Progressbar({
        label = locale('progress.inserting_card'),
        duration = duration,
        icon = 'credit-card',
        canCancel = false,
        disable = { combat = true, car = true },
    })

    if visit ~= current then return false end

    if not inserted then
        Atm.Leave()
        return false
    end

    play(current, current.anims.base, 'base', 1)

    return true
end

function Atm.Leave()
    local current <const> = visit

    if not current then return end

    visit = nil

    CreateThread(function()
        local length <const> = clipLength(current.anims.exit, 'exit')

        play(current, current.anims.exit, 'exit', 0)
        Wait(math.floor(length * CARD_OUT_AT))
        showCard(current)
        Wait(math.floor(length * (1 - CARD_OUT_AT)))
        hideCard(current)
        releaseAssets(current.anims)
    end)
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource or not visit then return end

    hideCard(visit)
    ClearPedTasks(cache.ped)
end)

return Atm
