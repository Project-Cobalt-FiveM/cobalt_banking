<script lang="ts" module>
  export interface Chip {
    value: number;
    label: string;
  }
</script>

<script lang="ts">
  import { focusRing, motion } from '../lib/ui';

  interface Props {
    options: Chip[];
    value: number;
  }

  let { options, value = $bindable() }: Props = $props();
</script>

<div class="flex gap-1.5">
  {#each options as option (option.label)}
    {@const active = option.value === value && value > 0}
    <button
      type="button"
      aria-pressed={active}
      disabled={option.value <= 0}
      onclick={() => (value = option.value)}
      class="flex h-8 grow basis-0 items-center justify-center rounded-md border text-13/4 tabular-nums disabled:cursor-not-allowed disabled:text-muted-foreground {active
        ? 'border-input bg-secondary font-semibold text-foreground'
        : 'border-border font-medium text-muted-foreground hover:bg-muted hover:text-foreground'} {focusRing} {motion}"
    >
      {option.label}
    </button>
  {/each}
</div>
