---@class BankingEnums
local enums <const> = {
    AccountType = {
        PERSONAL = 'personal',
        SHARED = 'shared',
        SOCIETY = 'society',
    },

    TransactionType = {
        DEPOSIT = 'deposit',
        WITHDRAWAL = 'withdrawal',
        TRANSFER_IN = 'transfer_in',
        TRANSFER_OUT = 'transfer_out',
        FEE = 'fee',
        PAYCHECK = 'paycheck',
        BILL_PAID = 'bill_paid',
        BILL_RECEIVED = 'bill_received',
    },

    MemberRole = {
        OWNER = 'owner',
        ADMIN = 'admin',
        MEMBER = 'member',
        VIEWER = 'viewer',
    },
}

return enums
