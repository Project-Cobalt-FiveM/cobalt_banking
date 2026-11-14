<script lang="ts">
  import CheckCircleIcon from 'phosphor-svelte/lib/CheckCircleIcon';
  import { accountLine, recipientName } from '../lib/accounts';
  import { formatMoney } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import type { Account, Recipient } from '../lib/types';
  import { focusOnMount } from '../lib/ui';
  import Button from './Button.svelte';
  import Summary from './Summary.svelte';

  interface Props {
    amount: number;
    recipient: Recipient;
    from: Account;
    reference: string;
    receipt: string;
    onagain: () => void;
    onclose: () => void;
  }

  let { amount, recipient, from, reference, receipt, onagain, onclose }: Props = $props();
</script>

<div
  role="dialog"
  aria-modal="true"
  aria-label={t('ui.sent.title')}
  class="flex w-md animate-pop flex-col items-center gap-5 rounded-lg border border-border bg-popover px-6 pt-8 pb-6 shadow-lg"
>
  <CheckCircleIcon size={56} weight="fill" class="shrink-0 text-success" aria-hidden="true" />
  <div class="flex flex-col items-center gap-1.5">
    <span class="text-13/4 font-medium text-muted-foreground">{t('ui.sent.title')}</span>
    <span class="text-4xl font-semibold tracking-tight text-foreground tabular-nums">{formatMoney(amount)}</span>
    <span class="text-sm text-muted-foreground">{t('ui.sent.to', recipientName(recipient))}</span>
  </div>
  <div class="w-full">
    <Summary
      rows={[
        [t('ui.transfer.reference'), reference || t('ui.sent.default_reference')],
        [t('ui.dialog.from'), accountLine(from)],
        [t('ui.sent.receipt'), receipt],
      ]}
    />
  </div>
  <div class="flex w-full gap-2">
    <Button size="lg" grow onclick={onagain}>{t('ui.sent.again')}</Button>
    <Button tone="primary" size="lg" grow onclick={onclose} attach={focusOnMount}>{t('ui.sent.done')}</Button>
  </div>
</div>
