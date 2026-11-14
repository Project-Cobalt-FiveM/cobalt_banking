<script lang="ts">
  import { formatWholeMoney } from '../lib/format';
  import { t } from '../lib/locale.svelte';

  interface Props {
    limit: number;
    used: number;
    pending: number;
    note: string;
  }

  let { limit, used, pending, note }: Props = $props();

  const share = (value: number): number => (limit > 0 ? Math.min((value / limit) * 100, 100) : 0);
</script>

<div class="flex flex-col gap-2">
  <div class="flex justify-between">
    <span class="text-sm font-medium text-foreground">{t('ui.limit.title')}</span>
    <span class="text-xs text-muted-foreground tabular-nums">{t('ui.limit.used', formatWholeMoney(used), formatWholeMoney(limit))}</span>
  </div>
  <div
    role="meter"
    aria-label={t('ui.limit.meter')}
    aria-valuemin={0}
    aria-valuemax={limit}
    aria-valuenow={used}
    class="flex h-1.5 shrink-0 overflow-hidden rounded-full bg-secondary"
  >
    <div class="bg-muted-foreground" style:width="{share(used)}%"></div>
    <div class="bg-cobalt transition-[width] duration-200 ease-cobalt" style:width="{share(pending)}%"></div>
  </div>
  <span class="text-xs text-muted-foreground tabular-nums">{note}</span>
</div>
