<script lang="ts" module>
  export interface SegmentOption<T extends string> {
    value: T;
    label: string;
  }
</script>

<script lang="ts" generics="T extends string">
  import { focusRing, motion } from '../lib/ui';

  interface Props {
    options: readonly SegmentOption<T>[];
    value: T;
    label: string;
    role: 'tablist' | 'radiogroup';
    id?: string;
    fill?: boolean;
  }

  let { options, value = $bindable(), label, role, id, fill = false }: Props = $props();

  const isTabs = $derived(role === 'tablist');

  function step(event: KeyboardEvent): void {
    const offset = event.key === 'ArrowRight' ? 1 : event.key === 'ArrowLeft' ? -1 : 0;
    if (offset === 0) return;
    event.preventDefault();
    const index = options.findIndex((option) => option.value === value);
    const next = options[(index + offset + options.length) % options.length];
    if (!next) return;
    value = next.value;
    const group = event.currentTarget instanceof HTMLElement ? event.currentTarget.parentElement : null;
    group?.querySelector<HTMLElement>(`[data-value="${next.value}"]`)?.focus();
  }
</script>

<div {id} {role} aria-label={label} class="flex gap-1 {fill ? 'h-9 shrink-0 rounded-md border border-border p-0.75' : ''}">
  {#each options as option (option.value)}
    {@const selected = option.value === value}
    <button
      type="button"
      role={isTabs ? 'tab' : 'radio'}
      aria-selected={isTabs ? selected : undefined}
      aria-checked={isTabs ? undefined : selected}
      data-value={option.value}
      tabindex={selected ? 0 : -1}
      onclick={() => (value = option.value)}
      onkeydown={step}
      class="flex items-center justify-center rounded-sm text-13/4 {fill ? 'grow basis-0' : 'h-7 px-2.5'} {selected
        ? 'bg-primary font-semibold text-primary-foreground'
        : 'font-medium text-muted-foreground hover:bg-muted hover:text-foreground'} {focusRing} {motion}"
    >
      {option.label}
    </button>
  {/each}
</div>
