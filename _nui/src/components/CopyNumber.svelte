<script lang="ts">
  import CheckIcon from 'phosphor-svelte/lib/CheckIcon';
  import CopyIcon from 'phosphor-svelte/lib/CopyIcon';
  import { focusRing, motion } from '../lib/ui';
  import { t } from '../lib/locale.svelte';

  interface Props {
    value: string;
  }

  let { value }: Props = $props();

  let copied = $state(false);

  $effect(() => {
    if (!copied) return;
    const timer = setTimeout(() => (copied = false), 1500);
    return () => clearTimeout(timer);
  });

  function copy(): void {
    const area = document.createElement('textarea');
    area.value = value;
    document.body.appendChild(area);
    area.select();
    document.execCommand('copy');
    area.remove();
    copied = true;
  }
</script>

<button
  type="button"
  aria-label={copied ? t('ui.copy.copied') : t('ui.copy.copy')}
  onclick={copy}
  class="group flex items-center gap-2 rounded-md {focusRing}"
>
  <span class="text-13/4 text-muted-foreground tabular-nums">{value}</span>
  {#if copied}
    <CheckIcon size={14} weight="fill" class="animate-fade text-success" />
  {:else}
    <CopyIcon size={14} weight="fill" class="text-muted-foreground group-hover:text-foreground {motion}" />
  {/if}
</button>
