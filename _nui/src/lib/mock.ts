import { bank } from './bank.svelte';
import { installMock, type MockHandlers } from './nui';
import type { AccountDetail, DialogKind, Overview } from './types';

const params = new URLSearchParams(window.location.search);
const atm = params.get('atm') === '1';
const dialogKinds: readonly DialogKind[] = ['deposit', 'withdraw', 'transfer', 'newAccount'];
const requestedDialog = dialogKinds.find((kind) => kind === params.get('dialog')) ?? null;

const hoursAgo = (hours: number): string => new Date(Date.now() - hours * 3600000).toISOString();

const overview: Overview = {
  atm,
  cash: 350,
  withdrawLimit: 5000,
  withdrawnToday: 1750,
  transferFeePercent: 0,
  maxSharedMembers: 8,
  accounts: [
    { id: 'CB 4821 0093', label: 'Personal Account', type: 'personal', balance: 55000, frozen: false, primary: true, members: 1, owner: true },
    { id: 'CB 3309 5120', label: 'House fund', type: 'shared', balance: 3200, frozen: false, primary: false, members: 3, owner: true },
    { id: 'society_police', label: 'LSPD', type: 'society', balance: 482150, frozen: false, primary: false, members: 0, owner: false },
  ],
};

const detail: AccountDetail = {
  history: { points: [53140, 53420, 53310, 55400, 55080, 57550, 55000], start: 53060.4, incoming: 3050, outgoing: 1460.4 },
  activity: [
    { id: 1, type: 'paycheck', amount: 2500, description: 'Paycheck from LSPD', counterparty: 'LSPD', receipt: null, timestamp: hoursAgo(1) },
    { id: 2, type: 'withdrawal', amount: -200, description: 'Cash withdrawal', counterparty: null, receipt: null, timestamp: hoursAgo(1.3) },
    { id: 3, type: 'bill_paid', amount: -350, description: 'Invoice: Pillbox medical', counterparty: null, receipt: null, timestamp: hoursAgo(2) },
    { id: 4, type: 'transfer_out', amount: -1000, description: 'Rent share', counterparty: 'House fund', receipt: 'TX-11023-0612', timestamp: hoursAgo(3) },
    { id: 5, type: 'transfer_in', amount: 200, description: 'Dinner', counterparty: 'Maya Chen', receipt: 'TX-55021-0611', timestamp: hoursAgo(20) },
    { id: 6, type: 'bill_received', amount: 150, description: 'Invoice: Towing on Route 68', counterparty: null, receipt: null, timestamp: hoursAgo(30) },
    { id: 7, type: 'withdrawal', amount: -500, description: 'Cash withdrawal', counterparty: null, receipt: null, timestamp: hoursAgo(50) },
  ],
};

const handlers: MockHandlers = {
  overview: () => overview,
  account: () => detail,
  close: () => true,
  findPlayer: (citizenid) => (citizenid.toUpperCase() === 'MAYA' ? { citizenid: 'MAYA', name: 'Maya Chen' } : false),
  lookup: (query) =>
    query.toUpperCase().startsWith('MAYA') || query.startsWith('CB 7710')
      ? { accountId: 'CB 7710 2284', label: 'Personal Account', type: 'personal', name: 'Maya Chen' }
      : false,
  deposit: () => ({ ok: true, balance: 0 }),
  withdraw: () => ({ ok: true, balance: 0 }),
  transfer: () => ({ ok: true, balance: 0, receipt: 'TX-84213-0612', fee: 0 }),
  createAccount: () => ({ ok: false, error: 'You already have the most shared accounts allowed' }),
};

installMock(handlers);
document.body.style.background = '#3B4A3A';

setTimeout(() => {
  window.postMessage({ action: 'open', atm });
  if (requestedDialog) setTimeout(() => (bank.dialog = requestedDialog), 400);
}, 50);
