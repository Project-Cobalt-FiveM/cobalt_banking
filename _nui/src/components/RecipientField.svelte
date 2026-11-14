<script lang="ts">
  import CheckCircleIcon from 'phosphor-svelte/lib/CheckCircleIcon';
  import { recipientAccount, recipientName } from '../lib/accounts';
  import { initials } from '../lib/format';
  import { nui } from '../lib/nui';
  import { t } from '../lib/locale.svelte';
  import type { Recipient } from '../lib/types';
  import { focusRing, motion } from '../lib/ui';
  import ErrorText from './ErrorText.svelte';
  import TextInput from './TextInput.svelte';

  type LookupStatus = 'idle' | 'searching' | 'missing';

  interface Props {
    id: string;
    fromId: string;
    recipient: Recipient | null;
    onresolve: (recipient: Recipient | null) => void;
  }

  let { id, fromId, recipient, onresolve }: Props = $props();

  const lookupDelay = 350;

  let query = $state('');
  let status = $state<LookupStatus>('idle');
  let refocus = $state(false);

  $effect(() => {
    const text = query.trim();
    const from = fromId;
    if (text.length < 2) {
      status = 'idle';
      return;
    }

    status = 'searching';
    let current = true;
    const timer = setTimeout(async () => {
      const found = await nui('lookup', text);
      if (!current) return;
      if (found && found.accountId !== from) {
        status = 'idle';
        onresolve(found);
      } else {
        status = 'missing';
      }
    }, lookupDelay);

    return () => {
      current = false;
      clearTimeout(timer);
    };
  });

  function change(): void {
    refocus = true;
    onresolve(null);
  }
</script>

{#if recipient}
  {@const name = recipientName(recipient)}
  <button
    type="button"
    aria-label={t('ui.recipient.change', name)}
    onclick={change}
    class="flex h-13 shrink-0 animate-fade items-center gap-2.5 rounded-md border border-input px-3 text-left hover:bg-muted {focusRing} {motion}"
  >
    <span class="flex size-7.5 shrink-0 items-center justify-center rounded-full bg-secondary text-xs font-semibold text-foreground">
      {initials(name)}
    </span>
    <span class="flex min-w-0 grow flex-col gap-0.5">
      <span class="truncate text-sm font-medium text-foreground">{name}</span>
      <span class="truncate text-xs text-muted-foreground tabular-nums">{recipient.accountId} · {recipientAccount(recipient)}</span>
    </span>
    <CheckCircleIcon size={16} weight="fill" class="shrink-0 text-success" aria-label={t('ui.recipient.verified')} />
  </button>
{:else}
  <TextInput {id} bind:value={query} maxlength={64} placeholder={t('ui.recipient.placeholder')} height="h-13" autofocus={refocus} />
  {#if status === 'searching'}
    <span class="text-xs text-muted-foreground" aria-live="polite">{t('ui.recipient.searching')}</span>
  {/if}
  <ErrorText message={status === 'missing' ? t('ui.recipient.missing') : null} />
{/if}
