<script lang="ts">
  import type { Snippet } from 'svelte';

  interface Props {
    for: string;
    aside?: string;
    children: Snippet;
  }

  let { for: target, aside, children }: Props = $props();
</script>

<div class="flex items-baseline justify-between gap-4">
  <label for={target} class="text-sm font-medium text-foreground">{@render children()}</label>
  {#if aside}<span class="truncate text-xs text-muted-foreground tabular-nums">{aside}</span>{/if}
</div>
