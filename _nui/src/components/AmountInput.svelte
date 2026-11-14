<script lang="ts" module>
  export type AmountSize = 'lg' | 'md' | 'sm';
</script>

<script lang="ts">
  import { formatDigits, parseDigits } from '../lib/format';
  import { focusOnMount, motion } from '../lib/ui';

  interface Props {
    id: string;
    value: number;
    size?: AmountSize;
  }

  let { id, value = $bindable(), size = 'lg' }: Props = $props();

  const looks: Record<AmountSize, { box: string; sign: string; text: string }> = {
    lg: { box: 'h-16 gap-1.5 px-4', sign: 'text-[1.75rem]/8 font-medium', text: 'text-[1.75rem]/8 font-semibold' },
    md: { box: 'h-11 gap-1 px-3', sign: 'text-base', text: 'text-base font-semibold' },
    sm: { box: 'h-10 gap-1 px-3', sign: 'text-sm', text: 'text-sm font-medium' },
  };

  const look = $derived(looks[size]);
  const display = (amount: number): string => (amount ? formatDigits(amount) : '');

  function oninput(event: Event & { currentTarget: HTMLInputElement }): void {
    value = parseDigits(event.currentTarget.value);
    event.currentTarget.value = display(value);
  }
</script>

<label
  for={id}
  class="flex shrink-0 cursor-text items-center rounded-md border border-input focus-within:ring-2 focus-within:ring-cobalt {look.box} {motion}"
>
  <span class="text-muted-foreground {look.sign}">$</span>
  <input
    {id}
    inputmode="numeric"
    autocomplete="off"
    placeholder="0"
    value={display(value)}
    {oninput}
    {@attach size === 'lg' && focusOnMount}
    class="w-full min-w-0 bg-transparent text-foreground tabular-nums caret-cobalt outline-none placeholder:text-muted-foreground {look.text}"
  />
</label>
