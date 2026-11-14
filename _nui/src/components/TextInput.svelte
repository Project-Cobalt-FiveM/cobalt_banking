<script lang="ts">
  import { focusOnMount, motion } from '../lib/ui';

  interface Props {
    id: string;
    value: string;
    maxlength: number;
    placeholder: string;
    height?: string;
    autofocus?: boolean;
    disabled?: boolean;
    oninput?: () => void;
    onenter?: () => void;
  }

  let { id, value = $bindable(), maxlength, placeholder, height = 'h-10', autofocus = false, disabled = false, oninput, onenter }: Props = $props();

  function onkeydown(event: KeyboardEvent): void {
    if (event.key !== 'Enter' || !onenter) return;
    event.preventDefault();
    onenter();
  }
</script>

<input
  {id}
  {maxlength}
  {placeholder}
  {disabled}
  {oninput}
  {onkeydown}
  bind:value
  autocomplete="off"
  {@attach autofocus && focusOnMount}
  class="w-full shrink-0 rounded-md border border-input bg-transparent px-3 text-sm text-foreground caret-cobalt outline-none placeholder:text-muted-foreground focus-visible:ring-2 focus-visible:ring-cobalt {height} {motion}"
/>
