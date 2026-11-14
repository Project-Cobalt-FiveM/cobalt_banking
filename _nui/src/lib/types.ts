export type AccountType = 'personal' | 'shared' | 'society';

export type TransactionType =
  | 'deposit'
  | 'withdrawal'
  | 'transfer_in'
  | 'transfer_out'
  | 'fee'
  | 'paycheck'
  | 'bill_paid'
  | 'bill_received';

export interface Account {
  id: string;
  label: string | null;
  type: AccountType;
  balance: number;
  frozen: boolean;
  primary: boolean;
  members: number;
  owner: boolean;
}

export interface Overview {
  atm: boolean;
  cash: number;
  accounts: Account[];
  withdrawLimit: number;
  withdrawnToday: number;
  transferFeePercent: number;
  maxSharedMembers: number;
}

export interface History {
  points: number[];
  start: number;
  incoming: number;
  outgoing: number;
}

export interface Activity {
  id: number;
  type: TransactionType;
  amount: number;
  description: string | null;
  counterparty: string | null;
  receipt: string | null;
  timestamp: string;
}

export interface AccountDetail {
  history: History;
  activity: Activity[];
}

export interface Recipient {
  accountId: string;
  label: string | null;
  type: AccountType;
  name: string | null;
}

export interface Member {
  citizenid: string;
  name: string;
}

export interface CashArgs {
  accountId: string;
  amount: number;
}

export interface TransferArgs {
  from: string;
  to: string;
  amount: number;
  reference: string;
}

export interface CreateAccountArgs {
  label: string;
  members: string[];
  deposit: number;
}

export interface ActionFailure {
  ok: false;
  error: string;
}

export type ActionResult<T extends object> = ({ ok: true } & T) | ActionFailure;

export type EmptyArgs = Record<string, never>;

export interface NuiCallbacks {
  overview: { args: EmptyArgs; result: Overview | false };
  account: { args: string; result: AccountDetail | false };
  findPlayer: { args: string; result: Member | false };
  lookup: { args: string; result: Recipient | false };
  deposit: { args: CashArgs; result: ActionResult<{ balance: number }> };
  withdraw: { args: CashArgs; result: ActionResult<{ balance: number }> };
  transfer: { args: TransferArgs; result: ActionResult<{ balance: number; receipt: string; fee: number }> };
  createAccount: { args: CreateAccountArgs; result: ActionResult<{ accountId: string }> };
  close: { args: EmptyArgs; result: true };
}

export type ActionName = 'deposit' | 'withdraw' | 'transfer' | 'createAccount';

export type NuiMessage = { action: 'open'; atm: boolean; locales?: Record<string, string> } | { action: 'close' };

export type DialogKind = 'deposit' | 'withdraw' | 'transfer' | 'newAccount';
