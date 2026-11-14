<script lang="ts">
  import { t } from '../lib/locale.svelte';
</script>

<div aria-busy="true" aria-label={t('ui.loading')} class="flex min-h-0 grow animate-fade flex-col gap-6">
  <div class="flex h-50 shrink-0 flex-col gap-2.5 rounded-lg border border-border px-4 pt-3.5 pb-2.5">
    <div class="flex flex-col gap-2">
      <div class="h-3 w-32 rounded-sm bg-secondary"></div>
      <div class="h-5 w-24 rounded-sm bg-secondary"></div>
    </div>
    <div class="grow rounded-md bg-muted"></div>
  </div>
  <div class="flex flex-col gap-3">
    <div class="h-4.5 w-28 rounded-sm bg-secondary"></div>
    {#each [0, 1, 2] as row (row)}
      <div class="h-14 rounded-md border border-border bg-muted"></div>
    {/each}
  </div>
</div>
