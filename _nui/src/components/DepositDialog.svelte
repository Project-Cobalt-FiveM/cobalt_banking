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
  import Summary from './Summary.svelte';

  interface Props {
    account: Account;
    cash: number;
    onclose: () => void;
    ondone: () => void;
  }

  let { account, cash, onclose, ondone }: Props = $props();

  let amount = $state(0);
  const action = createAction('deposit', () => ondone());

  const overCash = $derived(amount > cash);
  const valid = $derived(amount > 0 && !overCash);
  const chips = $derived([
    { value: 50, label: formatWholeMoney(50) },
    { value: 100, label: formatWholeMoney(100) },
    { value: 250, label: formatWholeMoney(250) },
    { value: cash, label: t('ui.deposit.all_cash') },
  ]);

  function submit(): void {
    if (valid) void action.submit({ accountId: account.id, amount });
  }
</script>

<Dialog title={t('ui.deposit.title')} description={t('ui.deposit.description', accountName(account))} {onclose} onsubmit={submit}>
  <div class="flex flex-col gap-1.5">
    <FieldLabel for="deposit-amount" aside={t('ui.deposit.cash_on_hand', formatMoney(cash))}>{t('ui.dialog.amount')}</FieldLabel>
    <AmountInput id="deposit-amount" bind:value={amount} />
    <Chips options={chips} bind:value={amount} />
    <ErrorText message={overCash ? t('ui.deposit.over_cash', formatMoney(cash)) : action.error} />
  </div>
  <Summary
    rows={[
      [t('ui.dialog.from'), t('ui.dialog.cash')],
      [t('ui.dialog.to'), accountLine(account)],
    ]}
    total={[t('ui.dialog.new_balance'), formatMoney(account.balance + (overCash ? 0 : amount))]}
  />
  {#snippet footer()}
    <DialogActions label={t('ui.deposit.submit', formatMoney(amount))} disabled={!valid || action.busy} {onclose} />
  {/snippet}
</Dialog>
