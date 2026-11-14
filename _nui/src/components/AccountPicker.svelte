<script lang="ts">
  import CaretDownIcon from 'phosphor-svelte/lib/CaretDownIcon';
  import CheckIcon from 'phosphor-svelte/lib/CheckIcon';
  import { accountIcons, accountName } from '../lib/accounts';
  import { formatMoney } from '../lib/format';
  import type { Account } from '../lib/types';
  import { t } from '../lib/locale.svelte';
  import { focusRing, motion } from '../lib/ui';

  interface Props {
    id: string;
    accounts: Account[];
    value: Account;
    onchange: (account: Account) => void;
  }

  let { id, accounts, value, onchange }: Props = $props();

  let open = $state(false);

  const ValueIcon = $derived(accountIcons[value.type] ?? accountIcons.personal);

  function onkeydown(event: KeyboardEvent): void {
    if (event.key !== 'Escape' || !open) return;
    event.preventDefault();
    event.stopPropagation();
    open = false;
  }

  function pick(account: Account): void {
    onchange(account);
    open = false;
  }
</script>

<div class="relative" role="presentation" {onkeydown}>
  <button
    {id}
    type="button"
    aria-haspopup="listbox"
    aria-expanded={open}
    onclick={() => (open = !open)}
    class="flex h-11 w-full shrink-0 items-center gap-2.5 rounded-md border border-input px-3 text-left hover:bg-muted {focusRing} {motion}"
  >
    <ValueIcon size={16} weight="fill" class="shrink-0 text-muted-foreground" />
    <span class="grow truncate text-sm font-medium text-foreground">{accountName(value)}</span>
    <span class="text-13/4 text-muted-foreground tabular-nums">{formatMoney(value.balance)}</span>
    <CaretDownIcon size={12} weight="fill" class="shrink-0 text-muted-foreground" />
  </button>
  {#if open}
    <ul
      role="listbox"
      aria-label={t('ui.transfer.send_from')}
      class="absolute inset-x-0 top-12 z-10 flex animate-pop flex-col rounded-lg border border-border bg-popover p-1 shadow-lg"
    >
      {#each accounts as account (account.id)}
        {@const OptionIcon = accountIcons[account.type] ?? accountIcons.personal}
        {@const selected = account.id === value.id}
        <li role="option" aria-selected={selected}>
          <button
            type="button"
            onclick={() => pick(account)}
            class="flex h-9 w-full items-center gap-2.5 rounded-md px-2 text-left hover:bg-muted {focusRing} {motion}"
          >
            <OptionIcon size={16} weight="fill" class={selected ? 'text-cobalt' : 'text-muted-foreground'} />
            <span class="grow truncate text-sm text-foreground">{accountName(account)}</span>
            <span class="text-13/4 text-muted-foreground tabular-nums">{formatMoney(account.balance)}</span>
            <CheckIcon size={12} weight="fill" class={selected ? 'text-cobalt' : 'invisible'} />
          </button>
        </li>
      {/each}
    </ul>
  {/if}
</div>
