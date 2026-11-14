<script lang="ts">
  import { untrack } from 'svelte';
  import { accountName, recipientName } from '../lib/accounts';
  import { createAction } from '../lib/action.svelte';
  import { formatMoney } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import type { Account, Recipient } from '../lib/types';
  import AccountPicker from './AccountPicker.svelte';
  import AmountInput from './AmountInput.svelte';
  import Dialog from './Dialog.svelte';
  import DialogActions from './DialogActions.svelte';
  import ErrorText from './ErrorText.svelte';
  import FieldLabel from './FieldLabel.svelte';
  import RecipientField from './RecipientField.svelte';
  import Summary from './Summary.svelte';
  import TextInput from './TextInput.svelte';
  import TransferSent from './TransferSent.svelte';

  interface Props {
    accounts: Account[];
    initial: Account;
    feePercent: number;
    onclose: () => void;
    ondone: () => void;
  }

  let { accounts, initial, feePercent, onclose, ondone }: Props = $props();

  let fromId = $state(untrack(() => initial.id));
  let recipient = $state<Recipient | null>(null);
  let amount = $state(0);
  let reference = $state('');
  let receipt = $state<string | null>(null);
  let round = $state(0);

  const action = createAction('transfer', (result) => {
    receipt = result.receipt;
    ondone();
  });

  const sources = $derived(accounts.filter((account) => !account.frozen));
  const from = $derived(accounts.find((account) => account.id === fromId) ?? initial);
  const fee = $derived(Math.floor((amount * feePercent) / 100));
  const overBalance = $derived(amount + fee > from.balance);
  const valid = $derived(amount > 0 && !overBalance && recipient !== null);
  const firstName = $derived(recipient ? (recipientName(recipient).split(' ')[0] ?? t('ui.transfer.recipient')) : t('ui.transfer.recipient'));

  function changeSource(account: Account): void {
    fromId = account.id;
    if (recipient?.accountId === account.id) recipient = null;
  }

  function submit(): void {
    if (valid && recipient) void action.submit({ from: from.id, to: recipient.accountId, amount, reference: reference.trim() });
  }

  function sendAnother(): void {
    receipt = null;
    recipient = null;
    amount = 0;
    reference = '';
    round += 1;
  }
</script>

{#if receipt !== null && recipient}
  <TransferSent {amount} {recipient} {from} reference={reference.trim()} {receipt} {onclose} onagain={sendAnother} />
{:else}
  {#key round}
    <Dialog title={t('ui.transfer.title')} description={t('ui.transfer.description')} {onclose} onsubmit={submit}>
      <div class="flex flex-col gap-1.5">
        <FieldLabel for="transfer-from">{t('ui.dialog.from')}</FieldLabel>
        <AccountPicker id="transfer-from" accounts={sources} value={from} onchange={changeSource} />
      </div>
      <div class="flex flex-col gap-1.5">
        <FieldLabel for="transfer-to" aside={t('ui.transfer.to_hint')}>{t('ui.dialog.to')}</FieldLabel>
        <RecipientField id="transfer-to" fromId={from.id} {recipient} onresolve={(next) => (recipient = next)} />
      </div>
      <div class="flex gap-2.5">
        <div class="flex grow basis-0 flex-col gap-1.5">
          <FieldLabel for="transfer-amount">{t('ui.dialog.amount')}</FieldLabel>
          <AmountInput id="transfer-amount" size="md" bind:value={amount} />
        </div>
        <div class="flex grow-[1.4] basis-0 flex-col gap-1.5">
          <FieldLabel for="transfer-reference">{t('ui.transfer.reference')}</FieldLabel>
          <TextInput id="transfer-reference" bind:value={reference} maxlength={60} placeholder={t('ui.transfer.reference_placeholder')} height="h-11" />
        </div>
      </div>
      <ErrorText message={overBalance ? t('ui.dialog.only_has', accountName(from), formatMoney(from.balance)) : action.error} />
      <Summary
        rows={[
          [t('ui.transfer.fee'), formatMoney(fee)],
          [t('ui.transfer.receives', firstName), formatMoney(amount)],
        ]}
        total={[t('ui.transfer.after', accountName(from)), formatMoney(from.balance - (overBalance ? 0 : amount + fee))]}
      />
      {#snippet footer()}
        <DialogActions label={t('ui.transfer.submit', formatMoney(amount))} disabled={!valid || action.busy} {onclose} />
      {/snippet}
    </Dialog>
  {/key}
{/if}
