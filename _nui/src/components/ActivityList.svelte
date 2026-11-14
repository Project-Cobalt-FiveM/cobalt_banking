<script lang="ts" module>
  import type { Activity } from '../lib/types';

  type Filter = 'all' | 'in' | 'out';

  const filterKeys: readonly { value: Filter; key: string }[] = [
    { value: 'all', key: 'ui.activity.all' },
    { value: 'in', key: 'ui.activity.in' },
    { value: 'out', key: 'ui.activity.out' },
  ];

  const filterTests: Record<Filter, (entry: Activity) => boolean> = {
    all: () => true,
    in: (entry) => entry.amount > 0,
    out: (entry) => entry.amount < 0,
  };
</script>

<script lang="ts">
  import { t } from '../lib/locale.svelte';
  import ActivityRow from './ActivityRow.svelte';
  import Segmented from './Segmented.svelte';

  interface Props {
    activity: Activity[];
  }

  let { activity }: Props = $props();

  let filter = $state<Filter>('all');

  const rows = $derived(activity.filter(filterTests[filter]));
  const filters = $derived(filterKeys.map(({ value, key }) => ({ value, label: t(key) })));
</script>

<section class="flex min-h-0 grow basis-0 flex-col gap-3">
  <div class="flex items-center justify-between">
    <h3 class="text-base font-semibold text-foreground">{t('ui.activity.title')}</h3>
    <Segmented options={filters} bind:value={filter} label={t('ui.activity.filter_label')} role="tablist" />
  </div>
  {#if rows.length === 0}
    <p class="flex grow items-center justify-center text-13/4 text-muted-foreground">
      {activity.length === 0 ? t('ui.activity.empty') : t('ui.activity.empty_filter')}
    </p>
  {:else}
    {#key filter}
      <ul class="scroll-none flex min-h-0 animate-fade flex-col gap-1 overflow-y-auto">
        {#each rows as entry (entry.id)}
          <ActivityRow {entry} />
        {/each}
      </ul>
    {/key}
  {/if}
</section>
