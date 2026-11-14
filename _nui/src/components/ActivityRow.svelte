<script lang="ts" module>
  import ArrowDownLeftIcon from 'phosphor-svelte/lib/ArrowDownLeftIcon';
  import ArrowUpRightIcon from 'phosphor-svelte/lib/ArrowUpRightIcon';
  import ArrowsLeftRightIcon from 'phosphor-svelte/lib/ArrowsLeftRightIcon';
  import ReceiptIcon from 'phosphor-svelte/lib/ReceiptIcon';
  import type { Icon } from '../lib/accounts';
  import { t } from '../lib/locale.svelte';
  import type { Activity } from '../lib/types';

  function activityTitle(entry: Activity): string {
    if (entry.type === 'transfer_in' && entry.counterparty) return t('ui.activity.transfer_from', entry.counterparty);
    if (entry.type === 'transfer_out' && entry.counterparty) return t('ui.activity.transfer_to', entry.counterparty);
    if (entry.type === 'paycheck' && entry.amount > 0 && entry.counterparty) return t('ui.activity.paycheck_from', entry.counterparty);
    if (entry.type === 'bill_paid') return entry.description || t('ui.activity.bill_paid');
    if (entry.type === 'bill_received') return entry.description || t('ui.activity.bill_received');
    return entry.description || t('ui.activity.fallback');
  }

  function activityIcon(entry: Activity): Icon {
    if (entry.type === 'bill_paid' || entry.type === 'bill_received') return ReceiptIcon;
    if (entry.amount > 0) return ArrowDownLeftIcon;
    return entry.type === 'transfer_out' ? ArrowsLeftRightIcon : ArrowUpRightIcon;
  }
</script>

<script lang="ts">
  import { formatSigned, formatWhen } from '../lib/format';

  interface Props {
    entry: Activity;
  }

  let { entry }: Props = $props();

  const incoming = $derived(entry.amount > 0);
  const RowIcon = $derived(activityIcon(entry));
</script>

<li class="flex h-14 shrink-0 items-center gap-3.5 rounded-md border border-border px-3.5">
  <RowIcon size={16} weight="fill" class="shrink-0 {incoming ? 'text-success' : 'text-muted-foreground'}" />
  <div class="flex min-w-0 grow basis-0 flex-col gap-0.5">
    <span class="truncate text-sm font-medium text-foreground">{activityTitle(entry)}</span>
    <span class="text-xs text-muted-foreground tabular-nums">{formatWhen(entry.timestamp)}</span>
  </div>
  <span class="text-sm font-semibold tabular-nums {incoming ? 'text-success' : 'text-foreground'}">{formatSigned(entry.amount)}</span>
</li>
