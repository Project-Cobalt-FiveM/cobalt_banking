---@meta

---@alias BankingAccountId string

---@alias BankingAccountType 'personal'|'shared'|'society'

---@alias BankingMemberRole 'owner'|'admin'|'member'|'viewer'

---@alias BankingTransactionType
---| 'deposit'
---| 'withdrawal'
---| 'transfer_in'
---| 'transfer_out'
---| 'fee'
---| 'paycheck'
---| 'bill_paid' a character paying an org's bill through `Transfer` with `bill = true`
---| 'bill_received' the org's side of that bill
---| 'admin_credit'
---| 'admin_debit'

---@class BankingAccountMember
---@field cid string
---@field role BankingMemberRole
---@field addedAt integer epoch seconds

---@class BankingAccount
---@field id BankingAccountId
---@field accountId BankingAccountId
---@field type BankingAccountType
---@field label string?
---@field balance integer
---@field ownerCid string?
---@field frozen 0|1
---@field createdAt integer epoch seconds
---@field members? BankingAccountMember[] only on rows the bank app loads with their members

---@alias BankingAccountRef BankingAccountId|string an account id (`CB 1234 5678`, also read without spaces, or `society_<org>`), or a citizenid for that character's personal account

---@class BankingDetails
---@field note? string the line shown on the statement
---@field initiator? string recorded as `initiated_by`: a citizenid, or a system tag such as `payroll` or `ems`, which statements show with no name

---@class BankingTransferDetails: BankingDetails
---@field bill? boolean record `bill_paid` and `bill_received` instead of `transfer_out` and `transfer_in`

---@alias BankingFailure
---| 'invalid_amount'
---| 'not_found'
---| 'no_permission'
---| 'same_account'
---| 'insufficient_funds'
---| 'account_frozen'
---| 'recipient_frozen'
---| 'already_member'
---| 'member_limit'

---@class BankingRefusal
---@field ok false
---@field reason BankingFailure

---@class BankingAccessibleAccount
---@field accountId BankingAccountId
---@field type BankingAccountType
---@field name string the account label, or the org's label for a society account
---@field balance integer
---@field frozen boolean
---@field primary boolean
---@field role BankingMemberRole on a society account: `owner` for a boss, `member` with the `society` rank permission, `viewer` for the rest of the org

---@class BankingParty
---@field accountId BankingAccountId
---@field type BankingAccountType?
---@field name string?

---@class BankingStatementEntry
---@field id integer
---@field accountId BankingAccountId
---@field type BankingTransactionType
---@field amount integer negative for money out
---@field note string?
---@field balanceAfter integer?
---@field receipt string?
---@field counterparty BankingParty?
---@field initiator { citizenid: string, name: string? }? `name` is nil for system initiators such as `payroll`
---@field createdAt integer epoch seconds

---@class BankingStatementQuery
---@field limit? integer 1 to 50, default 20
---@field before? integer the `nextCursor` of the previous page
---@field direction? 'all'|'in'|'out'

---@class BankingStatementPage
---@field ok true
---@field entries BankingStatementEntry[] newest first
---@field nextCursor integer?

---@class BankingRecipient
---@field accountId BankingAccountId
---@field type BankingAccountType
---@field label? string the account's own label, on `FindRecipient` results
---@field name string
---@field lastAt? integer epoch seconds of the last transfer, on `GetRecentRecipients` rows

---@class BankingTransferRequest
---@field from BankingAccountId
---@field to string account number or citizen ID, which sends to that character's personal account
---@field amount integer
---@field note? string

---@class BankingTransferReceipt
---@field ok true
---@field balance integer the source account's balance after the transfer and fee
---@field fee integer
---@field receipt string
---@field transactionId integer the source account's `transfer_out` entry
---@field toAccountId BankingAccountId

---@alias BankingTransferResult BankingTransferReceipt|BankingRefusal

---@class BankingMember
---@field citizenid string
---@field name string
---@field role BankingMemberRole
---@field rank? string the org rank, on society members

---@class BankingMemberList
---@field ok true
---@field accountId BankingAccountId
---@field type BankingAccountType
---@field role BankingMemberRole the caller's role
---@field canManage boolean
---@field maxMembers integer
---@field members BankingMember[]

---@class BankingCashPointView
---@field x number
---@field y number
---@field z number
---@field label string
---@field atm boolean

---@class CobaltBankingExports
local CobaltBankingExports = {}

---**Server.** The account behind an account id or a citizenid.
---@param account BankingAccountRef
---@return BankingAccount?
function CobaltBankingExports:GetAccount(account) end

---**Server.** 0 when the account doesn't exist. Cash is not a bank balance: read it from cobalt_core's player.
---@param account BankingAccountRef
---@return integer
function CobaltBankingExports:GetBalance(account) end

---**Server.**
---@param account BankingAccountRef
---@param amount number a whole amount from 1 to 1000000000
---@param details? BankingDetails
---@return boolean ok
---@return integer|string balanceOrError
function CobaltBankingExports:Deposit(account, amount, details) end

---**Server.** Refuses when the balance can't cover it.
---@param account BankingAccountRef
---@param amount number a whole amount from 1 to 1000000000
---@param details? BankingDetails
---@return boolean ok
---@return integer|string balanceOrError
function CobaltBankingExports:Withdraw(account, amount, details) end

---**Server.** Moves money between two accounts in one transaction, without a fee or a permission check; player-initiated transfers go through `SendTransfer`.
---@param from BankingAccountRef
---@param to BankingAccountRef
---@param amount number a whole amount from 1 to 1000000000
---@param details? BankingTransferDetails
---@return boolean ok
---@return integer|string fromBalanceOrError
function CobaltBankingExports:Transfer(from, to, amount, details) end

---**Server.** Credits or debits an account, frozen or not, and logs it to FiveMesh. Refuses a debit the balance can't cover.
---@param account BankingAccountRef
---@param delta number a whole amount; positive credits, negative debits
---@param details? BankingDetails `initiator` defaults to `system`
---@return boolean ok
---@return integer|string balanceOrError
function CobaltBankingExports:AdjustBalance(account, delta, details) end

---**Server.** When the next paycheck cycle runs. Society orgs pay it from their society account.
---@return integer epoch seconds
---@return integer minutes between paydays
function CobaltBankingExports:GetNextPayday() end

---**Server.** Accounts the character can see, with their role. Society accounts need the character online.
---@param citizenid string
---@return BankingAccessibleAccount[]
function CobaltBankingExports:GetAccessibleAccounts(citizenid) end

---**Server.** A page of an account's entries with counterparty and initiator names, for a character with any role on it.
---@param citizenid string
---@param accountId BankingAccountId
---@param query? BankingStatementQuery
---@return BankingStatementPage|BankingRefusal
function CobaltBankingExports:GetStatement(citizenid, accountId, query) end

---**Server.** One entry, for a character with any role on its account.
---@param citizenid string
---@param transactionId integer
---@return { ok: true, entry: BankingStatementEntry }|BankingRefusal
function CobaltBankingExports:GetStatementEntry(citizenid, transactionId) end

---**Server.** The account behind an account number or citizen ID; nil when there is none or it is frozen.
---@param query string
---@return BankingRecipient?
function CobaltBankingExports:FindRecipient(query) end

---**Server.** Other people's accounts the character sent money to, latest first.
---@param citizenid string
---@param limit? integer default 5
---@return BankingRecipient[]
function CobaltBankingExports:GetRecentRecipients(citizenid, limit) end

---**Server.** Moves money in one transaction with the configured fee, for a character with `member` or higher on the source. Logs to FiveMesh.
---@param citizenid string
---@param request BankingTransferRequest
---@return BankingTransferResult
function CobaltBankingExports:SendTransfer(citizenid, request) end

---**Server.** Members of a shared account, or the org roster of a society account.
---@param citizenid string
---@param accountId BankingAccountId
---@return BankingMemberList|BankingRefusal
function CobaltBankingExports:GetAccountMembers(citizenid, accountId) end

---**Server.** Adds a character to a shared account as `member`; the caller needs `admin` or higher.
---@param citizenid string
---@param accountId BankingAccountId
---@param targetCitizenid string
---@return { ok: true, member: BankingMember }|BankingRefusal
function CobaltBankingExports:InviteMember(citizenid, accountId, targetCitizenid) end

---**Server.** Removes a member other than the owner from a shared account; the caller needs `admin` or higher.
---@param citizenid string
---@param accountId BankingAccountId
---@param targetCitizenid string
---@return { ok: true }|BankingRefusal
function CobaltBankingExports:RevokeMember(citizenid, accountId, targetCitizenid) end

---**Client.** The closest streamed-in ATM or bank branch to the player.
---@return BankingCashPointView?
function CobaltBankingExports:FindNearestCashPoint() end

exports.cobalt_banking = CobaltBankingExports
