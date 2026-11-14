return {
    -- Account types a player can open
    AccountTypes = {
        personal = { maxPerPlayer = 1 }, -- personal accounts each character can own
        shared = { maxPerPlayer = 5 }, -- shared accounts each character can own
    },

    -- Limits and fees
    DailyWithdrawLimit = 5000, -- dollars a character can withdraw as cash per day
    TransferFeePercent = 0, -- percent of each transfer taken as a fee; 0 for none
    MaxSharedMembers = 8, -- members a shared account can have besides its owner
    InteractionRange = 10.0, -- meters a player can move from the bank or ATM before the open session closes
    BankRange = 6.0, -- meters from a branch counter within which the server lets the player open the bank
    PaycheckInterval = 15, -- minutes between paydays for on-duty job members

    -- What gets sent to the server logs
    Logs = {
        deposits = true, -- log cash deposits
        withdrawals = true, -- log cash withdrawals
        transfers = true, -- log transfers between accounts
        adminActions = true, -- log staff actions such as freezing an account
        suspiciousThreshold = 500000, -- dollars at or above which a logged movement is marked as a security event
    },

    -- ATMs
    ATMModels = { 'prop_atm_01', 'prop_atm_02', 'prop_atm_03', 'prop_fleeca_atm' }, -- world props that work as ATMs
    ATMStandOffset = vec3(0.0, -0.55, 0.0), -- where the player stands relative to the ATM, in meters (negative y is in front)
    ATMRange = 5.0, -- meters from a listed ATM position within which the server lets the player open an ATM
    ATMLocations = { -- world positions of every ATM that works; add the ones custom maps place, or they report out of service
        vec3(-386.73, 6045.95, 31.50),
        vec3(-110.75, 6467.70, 31.78),
        vec3(155.43, 6641.99, 31.78),
        vec3(174.67, 6637.22, 31.78),
        vec3(1703.14, 6426.78, 32.73),
        vec3(1735.11, 6411.03, 35.16),
        vec3(1702.84, 4933.59, 42.05),
        vec3(1967.33, 3744.29, 32.27),
        vec3(1174.53, 2705.28, 38.03),
        vec3(2564.40, 2585.10, 38.02),
        vec3(2558.68, 349.60, 108.05),
        vec3(2558.05, 389.48, 108.66),
        vec3(1077.69, -775.80, 58.22),
        vec3(1139.02, -469.89, 66.79),
        vec3(1168.97, -457.24, 66.64),
        vec3(1153.88, -326.54, 69.25),
        vec3(236.46, 217.47, 106.84),
        vec3(265.00, 212.17, 106.78),
        vec3(-164.57, 233.51, 94.92),
        vec3(-1827.04, 785.52, 138.02),
        vec3(-1409.39, -99.26, 52.47),
        vec3(-1215.64, -332.23, 37.88),
        vec3(-2072.41, -316.96, 13.35),
        vec3(-2975.72, 379.77, 14.99),
        vec3(-2962.60, 482.19, 15.76),
        vec3(-3144.13, 1127.41, 20.87),
        vec3(-1305.40, -706.24, 25.35),
        vec3(-717.61, -915.88, 19.27),
        vec3(-526.57, -1222.90, 18.43),
        vec3(149.46, -1038.95, 29.37),
        vec3(-846.30, -340.40, 38.69),
        vec3(-56.19, -1752.53, 29.45),
        vec3(-273.00, -2025.60, 30.20),
        vec3(314.19, -278.62, 54.17),
        vec3(-351.53, -49.53, 49.04),
        vec3(-1570.20, -546.65, 34.95),
        vec3(33.23, -1347.85, 29.50),
        vec3(129.22, -1292.35, 29.27),
        vec3(289.01, -1256.55, 29.44),
        vec3(1686.75, 4815.81, 42.01),
        vec3(-302.41, -829.95, 32.42),
        vec3(5.13, -919.95, 29.56),
        vec3(-284.04, 6224.39, 31.19),
        vec3(-135.16, 6365.74, 31.10),
        vec3(-94.97, 6455.30, 31.78),
        vec3(1821.92, 3683.48, 34.24),
        vec3(540.04, 2671.01, 42.18),
        vec3(381.28, 323.25, 103.27),
        vec3(285.20, 143.57, 104.97),
        vec3(157.77, 233.54, 106.45),
        vec3(-1205.35, -325.58, 37.87),
        vec3(-2955.70, 488.72, 15.49),
        vec3(-3044.22, 595.24, 7.59),
        vec3(-3241.10, 996.69, 12.50),
        vec3(-3241.11, 1009.15, 12.88),
        vec3(-538.23, -854.42, 29.23),
        vec3(-711.16, -818.96, 23.77),
        vec3(-256.83, -719.65, 33.44),
        vec3(-203.55, -861.59, 30.20),
        vec3(112.41, -776.16, 31.43),
        vec3(112.93, -818.71, 31.39),
        vec3(119.90, -883.83, 31.19),
        vec3(-261.69, -2012.64, 30.12),
        vec3(-254.11, -692.48, 33.62),
        vec3(-1415.91, -211.82, 46.50),
        vec3(-1430.12, -211.01, 46.50),
        vec3(287.64, -1282.65, 29.66),
        vec3(295.84, -895.64, 29.22),
        vec3(-1315.73, -834.89, 16.96),
        vec3(89.75, 2.35, 68.31),
        vec3(1167.02, -456.32, 66.79),
        vec3(-1204.35, -324.39, 37.88),
        vec3(24.59, -946.06, 29.36),
    },

    -- Map blip for each bank branch
    Blip = {
        sprite = 108, -- blip icon id
        colour = 2, -- blip colour id
        scale = 0.7, -- blip size
        category = 12, -- map legend category id
    },

    -- Fleeca branches: id (its name is branch.<id> in locales/en.json), the counter the player walks up to and the way they face
    Banks = {
        {
            id = 'legion_square',
            coords = vector3(149.47, -1042.08, 29.37), heading = 340.0,
        },
        {
            id = 'alta',
            coords = vector3(313.82, -280.64, 54.16), heading = 340.0,
        },
        {
            id = 'burton',
            coords = vector3(-351.53, -51.53, 49.04), heading = 340.0,
        },
        {
            id = 'rockford_hills',
            coords = vector3(-1212.98, -331.26, 37.79), heading = 27.0,
        },
        {
            id = 'banham_canyon',
            coords = vector3(-2962.58, 483.0, 15.7), heading = 87.0,
        },
        {
            id = 'harmony',
            coords = vector3(1175.07, 2708.23, 38.09), heading = 0.0,
        },
    },
}
