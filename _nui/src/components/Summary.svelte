<script lang="ts" module>
  export type SummaryRow = readonly [label: string, value: string];
</script>

<script lang="ts">
  interface Props {
    rows: SummaryRow[];
    total?: SummaryRow;
  }

  let { rows, total }: Props = $props();
</script>

<div class="flex flex-col gap-2.5 rounded-md border border-border bg-background p-3.5">
  {#each rows as [label, value] (label)}
    <div class="flex justify-between gap-4">
      <span class="shrink-0 text-13/4 text-muted-foreground">{label}</span>
      <span class="truncate text-13/4 font-medium text-foreground tabular-nums">{value}</span>
    </div>
  {/each}
  {#if total}
    <div class="h-px shrink-0 bg-border"></div>
    <div class="flex justify-between gap-4">
      <span class="text-13/4 text-muted-foreground">{total[0]}</span>
      <span class="text-sm/4 font-semibold text-foreground tabular-nums">{total[1]}</span>
    </div>
  {/if}
</div>
