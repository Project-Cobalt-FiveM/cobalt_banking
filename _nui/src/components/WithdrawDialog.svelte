<script lang="ts">
  import { accountLine, accountName } from '../lib/accounts';
  import { createAction } from '../lib/action.svelte';
  import { formatMoney, formatWholeMoney } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import type { Account } from '../lib/types';
  import AmountInput from './AmountInput.svelte';
  import Chips from './Chips.svelte';
  import Dialog from './Dialog.svelte';
  import DialogActions from './DialogActions.svelte';
  import ErrorText from './ErrorText.svelte';
  import FieldLabel from './FieldLabel.svelte';
  import LimitMeter from './LimitMeter.svelte';
  import Summary from './Summary.svelte';

  interface Props {
    account: Account;
    limit: number;
    used: number;
    onclose: () => void;
    ondone: () => void;
  }

  let { account, limit, used, onclose, ondone }: Props = $props();

  const chips = [100, 500, 1000, 5000].map((value) => ({ value, label: formatWholeMoney(value) }));

  let amount = $state(0);
  const action = createAction('withdraw', () => ondone());

  const name = $derived(accountName(account));
  const remaining = $derived(Math.max(limit - used, 0));
  const overLimit = $derived(amount > remaining);
  const overBalance = $derived(amount > account.balance);
  const valid = $derived(amount > 0 && !overLimit && !overBalance);
  const pending = $derived(Math.min(amount, remaining));

  const limitNote = $derived(
    amount > 0 && !overLimit
      ? t('ui.withdraw.limit_after', formatWholeMoney(remaining - amount))
      : t('ui.withdraw.limit_left', formatWholeMoney(remaining)),
  );

  const problem = $derived.by(() => {
    if (overBalance) return t('ui.dialog.only_has', name, formatMoney(account.balance));
    if (overLimit) return t('ui.withdraw.over_limit', formatWholeMoney(remaining));
    return action.error;
  });

  function submit(): void {
    if (valid) void action.submit({ accountId: account.id, amount });
  }
</script>

<Dialog title={t('ui.withdraw.title')} description={t('ui.withdraw.description', name)} {onclose} onsubmit={submit}>
  <div class="flex flex-col gap-1.5">
    <FieldLabel for="withdraw-amount" aside={t('ui.withdraw.available', formatMoney(account.balance))}>{t('ui.dialog.amount')}</FieldLabel>
    <AmountInput id="withdraw-amount" bind:value={amount} />
    <Chips options={chips} bind:value={amount} />
    <ErrorText message={problem} />
  </div>
  <LimitMeter {limit} {used} {pending} note={limitNote} />
  <Summary
    rows={[
      [t('ui.dialog.from'), accountLine(account)],
      [t('ui.dialog.to'), t('ui.dialog.cash')],
    ]}
    total={[t('ui.dialog.new_balance'), formatMoney(account.balance - (valid ? amount : 0))]}
  />
  {#snippet footer()}
    <DialogActions label={t('ui.withdraw.submit', formatMoney(amount))} disabled={!valid || action.busy} {onclose} />
  {/snippet}
</Dialog>
