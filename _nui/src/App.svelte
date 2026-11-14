<script lang="ts">
  import AccountView from './components/AccountView.svelte';
  import DepositDialog from './components/DepositDialog.svelte';
  import NewAccountDialog from './components/NewAccountDialog.svelte';
  import Sidebar from './components/Sidebar.svelte';
  import TransferDialog from './components/TransferDialog.svelte';
  import WithdrawDialog from './components/WithdrawDialog.svelte';
  import { bank } from './lib/bank.svelte';
  import { setLocales, t } from './lib/locale.svelte';
  import { onNuiMessage } from './lib/nui';

  $effect(() =>
    onNuiMessage((message) => {
      if (message.action === 'open') {
        setLocales(message.locales);
        bank.open(message.atm);
      } else bank.reset();
    }),
  );

  $effect(() => {
    if (bank.visible && bank.selectedId) void bank.loadDetail(bank.selectedId);
  });

  function onKeydown(event: KeyboardEvent): void {
    if (!bank.visible || event.key !== 'Escape' || event.defaultPrevented) return;
    bank.escape();
  }

  const closeDialog = () => (bank.dialog = null);
</script>

<svelte:window onkeydown={onKeydown} />

{#if bank.visible && bank.overview}
  {@const overview = bank.overview}
  {@const account = bank.selected}
  <div class="fixed inset-0 flex items-center justify-center">
    <div class="flex gap-3 transition-[opacity,translate] duration-150 ease-cobalt {bank.closing ? 'translate-y-1 opacity-0' : 'animate-enter'}">
      <Sidebar
        cash={overview.cash}
        accounts={overview.accounts}
        atm={bank.atm}
        selectedId={bank.selectedId}
        onselect={(id) => (bank.selectedId = id)}
        onnewaccount={() => (bank.dialog = 'newAccount')}
      />

      <main class="relative flex h-175 w-197 flex-col rounded-lg border border-border bg-card p-6">
        {#if account}
          {#key account.id}
            <AccountView {account} detail={bank.selectedDetail} onaction={(kind) => (bank.dialog = kind)} />
          {/key}
        {:else}
          <p class="m-auto text-sm text-muted-foreground">{t('ui.bank.no_account')}</p>
        {/if}

        {#if bank.dialog}
          <div class="absolute inset-0 flex items-center justify-center">
            {#if bank.dialog === 'deposit' && account}
              <DepositDialog {account} cash={overview.cash} onclose={closeDialog} ondone={() => bank.finishDialog()} />
            {:else if bank.dialog === 'withdraw' && account}
              <WithdrawDialog
                {account}
                limit={overview.withdrawLimit}
                used={overview.withdrawnToday}
                onclose={closeDialog}
                ondone={() => bank.finishDialog()}
              />
            {:else if bank.dialog === 'transfer' && account}
              <TransferDialog
                accounts={overview.accounts}
                initial={account}
                feePercent={overview.transferFeePercent}
                onclose={closeDialog}
                ondone={() => bank.refresh()}
              />
            {:else if bank.dialog === 'newAccount' && !bank.atm}
              <NewAccountDialog
                primary={bank.primary}
                maxMembers={overview.maxSharedMembers}
                onclose={closeDialog}
                ondone={(accountId) => void bank.finishNewAccount(accountId)}
              />
            {/if}
          </div>
        {/if}
      </main>
    </div>
  </div>
{/if}
