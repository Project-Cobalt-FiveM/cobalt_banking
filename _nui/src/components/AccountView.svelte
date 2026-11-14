<script lang="ts">
  import ArrowDownLeftIcon from 'phosphor-svelte/lib/ArrowDownLeftIcon';
  import ArrowUpRightIcon from 'phosphor-svelte/lib/ArrowUpRightIcon';
  import ArrowsLeftRightIcon from 'phosphor-svelte/lib/ArrowsLeftRightIcon';
  import { accountGroup, accountName, type Icon } from '../lib/accounts';
  import type { LoadedDetail } from '../lib/bank.svelte';
  import { formatMoney } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import type { Account, DialogKind } from '../lib/types';
  import ActivityList from './ActivityList.svelte';
  import BalanceChart from './BalanceChart.svelte';
  import Button from './Button.svelte';
  import CopyNumber from './CopyNumber.svelte';
  import DetailSkeleton from './DetailSkeleton.svelte';

  interface Props {
    account: Account;
    detail: LoadedDetail | null;
    onaction: (kind: DialogKind) => void;
  }

  let { account, detail, onaction }: Props = $props();

  const actions: { kind: DialogKind; labelKey: string; icon: Icon }[] = [
    { kind: 'deposit', labelKey: 'ui.view.deposit', icon: ArrowDownLeftIcon },
    { kind: 'withdraw', labelKey: 'ui.view.withdraw', icon: ArrowUpRightIcon },
    { kind: 'transfer', labelKey: 'ui.view.transfer', icon: ArrowsLeftRightIcon },
  ];
</script>

<div class="flex min-h-0 grow animate-fade flex-col gap-6">
  <header class="flex items-start justify-between gap-6">
    <div class="flex min-w-0 flex-col gap-1.5">
      <h2 class="truncate text-2xl font-semibold tracking-tight text-foreground">{accountName(account)}</h2>
      <div class="flex items-center gap-2">
        <span class="flex h-5.5 items-center rounded-sm bg-secondary px-2 text-xs font-medium text-foreground">{accountGroup(account)}</span>
        <CopyNumber value={account.id} />
      </div>
    </div>
    <div class="flex flex-col items-end gap-0.5">
      <span class="text-xs font-medium text-muted-foreground">{account.frozen ? t('ui.view.account_frozen') : t('ui.view.available')}</span>
      <span class="text-[2.5rem]/11 font-semibold tracking-tight text-foreground tabular-nums">{formatMoney(account.balance)}</span>
    </div>
  </header>

  <div class="flex gap-2">
    {#each actions as { kind, labelKey, icon: ActionIcon }, index (kind)}
      <Button tone={index === 0 ? 'primary' : 'secondary'} size="lg" grow disabled={account.frozen} onclick={() => onaction(kind)}>
        <ActionIcon size={16} weight="fill" />
        {t(labelKey)}
      </Button>
    {/each}
  </div>

  {#if detail}
    <BalanceChart history={detail.history} balance={account.balance} />
    <ActivityList activity={detail.activity} />
  {:else}
    <DetailSkeleton />
  {/if}
</div>
