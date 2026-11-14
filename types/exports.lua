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
---| 'bill_paid' a character paying an invoice, or a `Transfer` with `bill = true`
---| 'bill_received' the payee's side of that bill
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
---| 'already_member'
---| 'member_limit'
---| 'invalid_invoice' a malformed invoice, filter, payment method or void reason
---| 'settled' the invoice is already paid or void
---| 'payer_offline' a cash payment needs the payer online

---@class BankingRefusal
---@field ok false
---@field reason BankingFailure

---@class BankingAccessibleAccount
---@field accountId BankingAccountId
---@field type BankingAccountType
---@field name string the account label, or the org's label for a society account
---@field balance integer
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

---@alias BankingInvoiceStatus
---| 'unpaid'
---| 'overdue' unpaid past `dueAt`
---| 'paid'
---| 'void'

---@alias BankingInvoiceMethod
---| 'bank' from the payer's personal account; a short balance records `declinedAt`
---| 'cash' from the payer's pocket; needs them online
---| 'cash_or_bank' cash when they're online and carry enough, the bank otherwise
---| 'manual' marks it paid without moving money, for payment taken some other way

---@alias BankingInvoicePaidWith 'bank'|'cash'|'manual'

---@class BankingInvoiceLine
---@field label string
---@field amount integer

---@class BankingInvoiceData
---@field lines? BankingInvoiceLine[] the itemized charges behind `amount`
---@field reportId? integer the issuer's report the invoice bills for
---@field [string] any anything else the issuer keeps on it

---@class BankingInvoice
---@field id integer
---@field issuer string the job, gang or kind that sent it, such as `ambulance`
---@field citizenid string the character who owes it
---@field payerName string
---@field payee BankingAccountId the account it pays into
---@field issuerCitizenid string? the character who wrote it; nil when the system sent it or that character was deleted
---@field issuerName string?
---@field summary string what it's for, shown on the bank statement; may be empty
---@field amount integer
---@field status BankingInvoiceStatus
---@field data BankingInvoiceData
---@field dueAt integer epoch seconds
---@field createdAt integer epoch seconds
---@field declinedAt integer? epoch seconds the payer last turned it down or their bank couldn't cover it
---@field paidAt integer? epoch seconds
---@field voidReason string?

---@class BankingInvoiceInput
---@field issuer string the job, gang or kind sending it, up to 32 characters
---@field citizenid string the character who owes it
---@field amount number a whole amount from 1 to 1000000000
---@field summary? string up to 255 characters
---@field payee? BankingAccountRef the account it pays into; defaults to `society_<issuer>`
---@field issuerCitizenid? string the character writing it
---@field issuerName? string up to 120 characters; defaults to the name of `issuerCitizenid`
---@field dueDays? integer 1 to 365; defaults to `InvoiceDueDays` in the config
---@field data? BankingInvoiceData

---@class BankingInvoiceQuery
---@field citizenid? string|string[]
---@field issuer? string
---@field status? BankingInvoiceStatus `unpaid` includes overdue ones
---@field data? table<string, string|number|boolean> top-level `data` keys that must equal these values
---@field limit? integer 1 to 500, default 50
---@field before? integer an invoice id; returns older ones, for paging

---@class BankingInvoiceTotalsQuery
---@field citizenid? string|string[] also fills `owed` for these characters
---@field issuer? string
---@field since? integer epoch seconds that start the `billed` and `paid` window; default 7 days ago

---@class BankingInvoiceTotals
---@field unpaid integer dollars on unpaid invoices, overdue ones included
---@field unpaidCount integer
---@field overdue integer
---@field overdueCount integer
---@field billed integer dollars invoiced since `since`, void ones excluded
---@field paid integer dollars paid since `since`
---@field owed table<string, integer> unpaid dollars per citizenid in the filter, for those who owe any

---@class BankingInvoicePayment
---@field method? BankingInvoiceMethod default `bank`

---@alias BankingInvoiceResult { ok: true, invoice: BankingInvoice }|BankingRefusal

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

---**Server.** Credits or debits an account and logs it to FiveMesh. Refuses a debit the balance can't cover.
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

---**Server.** The account behind an account number or citizen ID.
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

---**Server.** Sends a character an invoice that pays into `society_<issuer>` unless `payee` says otherwise. Notifies no one.
---@param invoice BankingInvoiceInput
---@return BankingInvoiceResult
function CobaltBankingExports:CreateInvoice(invoice) end

---**Server.**
---@param id integer
---@return BankingInvoice?
function CobaltBankingExports:GetInvoice(id) end

---**Server.** Invoices matching every filter given, newest first. A malformed filter matches nothing.
---@param filter? BankingInvoiceQuery
---@return BankingInvoice[]
function CobaltBankingExports:GetInvoices(filter) end

---**Server.** What's owed, overdue, billed and paid across the invoices matching the filter.
---@param filter? BankingInvoiceTotalsQuery
---@return BankingInvoiceTotals
function CobaltBankingExports:GetInvoiceTotals(filter) end

---**Server.** Pays an unpaid invoice into its payee in one transaction, as `bill_paid` and `bill_received` statement entries with the receipt `INV-<id>`. Logs to FiveMesh and triggers the server event `cobalt_banking:invoicePaid` with the paid `BankingInvoice` and its `BankingInvoicePaidWith`.
---@param id integer
---@param payment? BankingInvoicePayment
---@return BankingInvoiceResult
function CobaltBankingExports:PayInvoice(id, payment) end

---**Server.** Records that the payer turned an unpaid invoice down; it stays unpaid with `declinedAt` set.
---@param id integer
---@return BankingInvoiceResult
function CobaltBankingExports:DeclineInvoice(id) end

---**Server.** Cancels an unpaid invoice.
---@param id integer
---@param reason string up to 255 characters
---@return BankingInvoiceResult
function CobaltBankingExports:VoidInvoice(id, reason) end

---**Client.** The closest streamed-in ATM or bank branch to the player.
---@return BankingCashPointView?
function CobaltBankingExports:FindNearestCashPoint() end

exports.cobalt_banking = CobaltBankingExports
