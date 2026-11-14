<script lang="ts">
  import { accountName } from '../lib/accounts';
  import { createAction } from '../lib/action.svelte';
  import { formatMoney } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import type { Account, Member } from '../lib/types';
  import AmountInput from './AmountInput.svelte';
  import Dialog from './Dialog.svelte';
  import DialogActions from './DialogActions.svelte';
  import ErrorText from './ErrorText.svelte';
  import FieldLabel from './FieldLabel.svelte';
  import MemberField from './MemberField.svelte';
  import TextInput from './TextInput.svelte';

  interface Props {
    primary: Account | undefined;
    maxMembers: number;
    onclose: () => void;
    ondone: (accountId: string) => void;
  }

  let { primary, maxMembers, onclose, ondone }: Props = $props();

  let label = $state('');
  let members = $state<Member[]>([]);
  let deposit = $state(0);

  const action = createAction('createAccount', (result) => ondone(result.accountId));

  const overBalance = $derived(primary ? deposit > primary.balance : deposit > 0);
  const valid = $derived(label.trim().length > 0 && !overBalance);

  function submit(): void {
    if (!valid) return;
    void action.submit({
      label: label.trim(),
      members: members.map((member) => member.citizenid),
      deposit,
    });
  }
</script>

<Dialog title={t('ui.new_account.title')} description={t('ui.new_account.description', maxMembers)} {onclose} onsubmit={submit}>
  <div class="flex flex-col gap-1.5">
    <FieldLabel for="account-name">{t('ui.new_account.name')}</FieldLabel>
    <TextInput id="account-name" bind:value={label} maxlength={32} placeholder={t('ui.new_account.name_placeholder')} autofocus />
  </div>

  <div class="flex flex-col gap-1.5">
    <FieldLabel for="account-members">{t('ui.new_account.members')}</FieldLabel>
    <MemberField id="account-members" bind:members {maxMembers} />
  </div>

  <div class="flex flex-col gap-1.5">
    <FieldLabel for="account-deposit" aside={primary ? t('ui.new_account.from', accountName(primary)) : undefined}>{t('ui.new_account.deposit')}</FieldLabel>
    <AmountInput id="account-deposit" size="sm" bind:value={deposit} />
    <ErrorText message={overBalance && primary ? t('ui.dialog.only_has', accountName(primary), formatMoney(primary.balance)) : action.error} />
  </div>

  {#snippet footer()}
    <DialogActions label={t('ui.new_account.submit')} disabled={!valid || action.busy} {onclose} />
  {/snippet}
</Dialog>
