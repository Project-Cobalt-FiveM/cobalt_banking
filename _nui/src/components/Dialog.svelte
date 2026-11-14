<script lang="ts">
  import type { Snippet } from 'svelte';
  import XIcon from 'phosphor-svelte/lib/XIcon';
  import { focusRing, motion } from '../lib/ui';
  import { t } from '../lib/locale.svelte';

  interface Props {
    title: string;
    description: string;
    onclose: () => void;
    onsubmit: () => void;
    children: Snippet;
    footer: Snippet;
  }

  let { title, description, onclose, onsubmit, children, footer }: Props = $props();

  function submit(event: SubmitEvent): void {
    event.preventDefault();
    onsubmit();
  }
</script>

<div role="dialog" aria-modal="true" aria-label={title} class="w-md animate-pop rounded-lg border border-border bg-popover p-6 shadow-lg">
<form onsubmit={submit} class="flex flex-col gap-5">
  <div class="flex items-start gap-3">
    <div class="flex grow basis-0 flex-col gap-1">
      <h2 class="text-base font-semibold text-foreground">{title}</h2>
      <p class="text-13/4 text-muted-foreground">{description}</p>
    </div>
    <button
      type="button"
      aria-label={t('ui.dialog.close')}
      onclick={onclose}
      class="-m-1.5 rounded-md p-1.5 text-muted-foreground hover:bg-muted hover:text-foreground {focusRing} {motion}"
    >
      <XIcon size={16} weight="fill" />
    </button>
  </div>
  {@render children()}
  <div class="flex justify-end gap-2">
    {@render footer()}
  </div>
</form>
</div>
