<script lang="ts">
  import { accountCaption, accountIcons, accountName } from '../lib/accounts';
  import { formatMoney } from '../lib/format';
  import type { Account } from '../lib/types';
  import { focusRing, motion } from '../lib/ui';

  interface Props {
    account: Account;
    selected: boolean;
    onselect: () => void;
  }

  let { account, selected, onselect }: Props = $props();

  const Icon = $derived(accountIcons[account.type] ?? accountIcons.personal);
</script>

<button
  type="button"
  aria-current={selected}
  onclick={onselect}
  class="flex items-center gap-3 rounded-md border p-3 text-left {selected
    ? 'border-cobalt bg-primary text-primary-foreground'
    : 'border-border text-foreground hover:bg-muted'} {focusRing} {motion}"
>
  <Icon size={18} weight="fill" class="shrink-0 {selected ? 'text-primary-foreground' : 'text-muted-foreground'}" />
  <span class="flex min-w-0 grow basis-0 flex-col gap-px">
    <span class="truncate text-sm font-medium">{accountName(account)}</span>
    <span class="text-xs {selected ? 'text-primary-foreground' : 'text-muted-foreground'}">{accountCaption(account)}</span>
  </span>
  <span class="text-sm font-semibold tabular-nums">{formatMoney(account.balance)}</span>
</button>
