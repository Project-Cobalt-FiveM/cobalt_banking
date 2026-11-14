<script lang="ts">
  import MoneyIcon from 'phosphor-svelte/lib/MoneyIcon';
  import PlusSquareIcon from 'phosphor-svelte/lib/PlusSquareIcon';
  import { accountGroups } from '../lib/accounts';
  import { formatWholeMoney } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import type { Account } from '../lib/types';
  import { focusRing, motion } from '../lib/ui';
  import AccountRow from './AccountRow.svelte';
  import BankMark from './BankMark.svelte';

  interface Props {
    cash: number;
    accounts: Account[];
    atm: boolean;
    selectedId: string | null;
    onselect: (id: string) => void;
    onnewaccount: () => void;
  }

  let { cash, accounts, atm, selectedId, onselect, onnewaccount }: Props = $props();

  const groups = $derived(
    accountGroups
      .map((group) => ({ group, members: accounts.filter((account) => group.types.includes(account.type)) }))
      .filter(({ members }) => members.length > 0),
  );
</script>

<aside class="flex h-175 w-80 shrink-0 flex-col gap-4 rounded-lg border border-border bg-card p-4">
  <div class="flex h-8 shrink-0 items-center gap-2.5">
    <BankMark />
    <h1 class="flex grow basis-0 items-baseline gap-2 text-base font-semibold text-foreground">
      {t('ui.bank.title')}
      {#if atm}<span class="text-xs font-medium text-muted-foreground">{t('ui.bank.atm')}</span>{/if}
    </h1>
    <MoneyIcon size={16} weight="fill" class="shrink-0 text-muted-foreground" aria-hidden="true" />
    <span class="text-sm font-semibold text-foreground tabular-nums" aria-label={t('ui.bank.cash_on_hand', formatWholeMoney(cash))}>{formatWholeMoney(cash)}</span>
  </div>

  <nav aria-label={t('ui.bank.accounts')} class="scroll-none flex min-h-0 grow basis-0 flex-col gap-4 overflow-y-auto">
    {#each groups as { group, members } (group.key)}
      <section class="flex flex-col gap-1.5">
        <h2 class="px-1 text-xs font-medium text-muted-foreground">{t(group.titleKey)}</h2>
        {#each members as account (account.id)}
          <AccountRow {account} selected={account.id === selectedId} onselect={() => onselect(account.id)} />
        {/each}
      </section>
    {/each}
  </nav>

  {#if !atm}
    <button
      type="button"
      onclick={onnewaccount}
      class="flex h-10 shrink-0 items-center justify-center gap-2 rounded-md border border-input bg-secondary text-sm font-medium text-foreground hover:bg-input {focusRing} {motion}"
    >
      <PlusSquareIcon size={16} weight="fill" class="text-muted-foreground" />
      {t('ui.bank.new_shared')}
    </button>
  {/if}
</aside>
