import { nui } from './nui';
import type { AccountDetail, DialogKind, Overview } from './types';

export type LoadedDetail = AccountDetail & { accountId: string };

const closeMs = 150;

function defaultAccountId(overview: Overview, current: string | null): string | null {
  if (current && overview.accounts.some((account) => account.id === current)) return current;
  return (overview.accounts.find((account) => account.primary) ?? overview.accounts[0])?.id ?? null;
}

class Bank {
  visible = $state(false);
  closing = $state(false);
  atm = $state(false);
  overview = $state<Overview | null>(null);
  selectedId = $state<string | null>(null);
  detail = $state<LoadedDetail | null>(null);
  dialog = $state<DialogKind | null>(null);
  #closeTimer: ReturnType<typeof setTimeout> | undefined;

  selected = $derived(this.overview?.accounts.find((account) => account.id === this.selectedId) ?? null);
  primary = $derived(this.overview?.accounts.find((account) => account.primary));
  selectedDetail = $derived(this.detail && this.detail.accountId === this.selectedId ? this.detail : null);

  open(atm: boolean): void {
    clearTimeout(this.#closeTimer);
    this.visible = true;
    this.closing = false;
    this.atm = atm;
    void this.loadOverview();
  }

  async loadOverview(): Promise<void> {
    const next = await nui('overview', {});
    if (!next) return;
    this.overview = next;
    this.atm = next.atm;
    this.selectedId = defaultAccountId(next, this.selectedId);
  }

  async loadDetail(accountId: string): Promise<void> {
    const next = await nui('account', accountId);
    if (next) this.detail = { ...next, accountId };
  }

  refresh(): void {
    void this.loadOverview();
    if (this.selectedId) void this.loadDetail(this.selectedId);
  }

  finishDialog(): void {
    this.dialog = null;
    this.refresh();
  }

  async finishNewAccount(accountId: string): Promise<void> {
    this.dialog = null;
    await this.loadOverview();
    if (accountId) this.selectedId = accountId;
  }

  reset(): void {
    this.visible = false;
    this.closing = false;
    this.dialog = null;
    this.overview = null;
    this.selectedId = null;
    this.detail = null;
  }

  close(): void {
    this.closing = true;
    void nui('close', {});
    this.#closeTimer = setTimeout(() => this.reset(), closeMs);
  }

  escape(): void {
    if (this.dialog) this.dialog = null;
    else this.close();
  }
}

export const bank = new Bank();
